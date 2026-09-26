# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Single source of the dispatch job lifecycle: the statuses, the transitions
# allowed between them, the policy action each transition requires, the
# status <-> assignee invariant and the projection onto the backing ticket.
#
# DispatchJob.status owns the status of a job. Ticket.state is derived from it
# and must never be treated as a second editable status.
class DomServis::DispatchWorkflow
  # assignee:          :forbidden - the job must not have a master,
  #                    :required  - the job must have a master,
  #                    :optional  - either is fine.
  # ticket_state_type: Ticket::StateType name the backing ticket is projected to.
  STATUS_REGISTRY = [
    { key: 'pool',                   label: 'Pool',                       assignee: :forbidden, ticket_state_type: 'new',    description: __('Shared pool state before a master claims the job.') },
    { key: 'taken',                  label: 'Taken',                      assignee: :required,  ticket_state_type: 'open',   description: __('Claimed by a worker but not yet started.') },
    { key: 'in_progress',            label: __('In progress'),            assignee: :required,  ticket_state_type: 'open',   description: __('Actively being worked on.') },
    { key: 'done',                   label: 'Done',                       assignee: :required,  ticket_state_type: 'open',   description: __('The master finished the work on site; waiting for the dispatcher to close the job.') },
    { key: 'closed',                 label: 'Closed',                     assignee: :optional,  ticket_state_type: 'closed', description: __('Closed by the dispatcher after checking the result, payment or documents.') },
    { key: 'cancelled',              label: 'Cancelled',                  assignee: :optional,  ticket_state_type: 'closed', description: __('Cancelled before completion.') },
    { key: 'transferred_to_partner', label: __('Transferred to partner'), assignee: :optional,  ticket_state_type: 'closed', description: __('Closed on the Dom-Servis board after handoff to a partner service.') },
  ].freeze

  STATUSES = STATUS_REGISTRY.pluck(:key).freeze

  # from => { to => policy action required for the transition }.
  # A nil action marks a transition that only the take/assign actions perform,
  # because it has to set the master together with the status.
  TRANSITIONS = {
    'pool'                   => { 'taken' => nil, 'cancelled' => 'cancel_job', 'transferred_to_partner' => 'transfer_to_partner' },
    'taken'                  => { 'in_progress' => 'set_status_in_progress', 'pool' => 'release_to_pool', 'cancelled' => 'cancel_job', 'transferred_to_partner' => 'transfer_to_partner' },
    'in_progress'            => { 'done' => 'set_status_done', 'pool' => 'release_to_pool', 'cancelled' => 'cancel_job', 'transferred_to_partner' => 'transfer_to_partner' },
    'done'                   => { 'closed' => 'close_job', 'pool' => 'reopen_job' },
    'closed'                 => { 'pool' => 'reopen_job' },
    'cancelled'              => { 'pool' => 'reopen_job' },
    'transferred_to_partner' => {},
  }.freeze

  # Statuses in which a master can be assigned or reassigned.
  ASSIGNABLE_STATUSES = %w[pool taken in_progress].freeze

  class << self
    def status?(status)
      STATUSES.include?(status.to_s)
    end

    def transition_allowed?(from, to)
      TRANSITIONS.fetch(from.to_s, {}).key?(to.to_s)
    end

    def action_for(from, to)
      TRANSITIONS.fetch(from.to_s, {})[to.to_s]
    end

    def assignable?(status)
      ASSIGNABLE_STATUSES.include?(status.to_s)
    end

    def releasable?(status)
      action_for(status, 'pool') == 'release_to_pool'
    end

    def assignee_required?(status)
      entry(status)&.dig(:assignee) == :required
    end

    def assignee_forbidden?(status)
      entry(status)&.dig(:assignee) == :forbidden
    end

    def ticket_state_type(status)
      entry(status)&.dig(:ticket_state_type)
    end

    def label(status)
      entry(status)&.dig(:label)
    end

    # Attributes that have to change together with the status so the job
    # keeps the status <-> assignee invariant.
    def transition_attributes(to)
      return { status: to.to_s } if !assignee_forbidden?(to)

      { status: to.to_s, assignee_id: nil, taken_at: nil }
    end

    private

    def entry(status)
      STATUS_REGISTRY.find { |item| item[:key] == status.to_s }
    end
  end
end
