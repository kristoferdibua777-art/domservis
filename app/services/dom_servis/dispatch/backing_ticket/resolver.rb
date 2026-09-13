# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::BackingTicket::Resolver
  DEFAULT_CUSTOMER_EMAIL = 'dispatch-board@dom-servis.example'.freeze

  PRIORITY_MATCHERS = {
    'low'      => [/low/i, /\b1\b/],
    'medium'   => [/normal/i, /medium/i, /\b2\b/],
    'high'     => [/high/i, /\b3\b/],
    'critical' => [/critical/i, /urgent/i, /\b4\b/],
  }.freeze

  def initialize(dispatch_job:, operator: nil)
    @dispatch_job = dispatch_job
    @operator = operator
  end

  attr_reader :dispatch_job, :operator

  def group
    @group ||= begin
      candidate_groups = [
        configured_group,
        operator_group,
        assignee_group,
        *accessible_active_groups,
      ].compact.uniq

      candidate_groups.find { |group| accessible_group?(group) } || raise('No accessible ticket group available for Dom-Servis backing tickets.')
    end
  end

  def customer
    @customer ||= begin
      email = Setting.get('dom_servis_dispatch_ticket_customer_email').presence || DEFAULT_CUSTOMER_EMAIL
      User.find_by(email: email.downcase) || User.create!(
        firstname: 'Dom-Servis',
        lastname:  'Dispatch',
        email:     email,
        password:  '',
        active:    true,
      )
    end
  end

  def actor_user
    operator || dispatch_job.updated_by || dispatch_job.created_by || article_user
  end

  def article_user
    return operator if operator&.permissions?('ticket.agent')

    @article_user ||= User.order(:id).detect { |user| user.permissions?('ticket.agent') } || raise('No ticket agent user available for Dom-Servis backing ticket articles.')
  end

  def ticket_state
    @ticket_state ||= begin
      case dispatch_job.status
      when 'pool'
        state_for_type('new') || Ticket::State.find_by(default_create: true) || Ticket::State.active.first
      when 'taken', 'in_progress'
        state_for_type('open') || Ticket::State.by_category(:open).active.first
      when 'done', 'cancelled', 'transferred_to_partner'
        Ticket::State.by_category(:closed).active.first
      else
        Ticket::State.find_by(default_create: true) || Ticket::State.active.first
      end
    end
  end

  def ticket_priority
    @ticket_priority ||= begin
      priorities = Ticket::Priority.where(active: true).to_a
      matchers = PRIORITY_MATCHERS.fetch(dispatch_job.priority, [])

      matchers.each do |matcher|
        match = priorities.find { |priority| priority.name.to_s.match?(matcher) }
        return match if match
      end

      Ticket::Priority.find_by(default_create: true) || priorities.first
    end
  end

  private

  def configured_group
    group_id = Setting.get('dom_servis_dispatch_backing_ticket_group_id').presence
    return if group_id.blank?

    Group.find_by(id: group_id)
  end

  def operator_group
    return if operator.blank?

    accessible_active_groups.detect do |group|
      operator.group_access?(group.id, 'create') || operator.group_access?(group.id, 'change') || operator.group_access?(group.id, 'full')
    end
  end

  def assignee_group
    return if dispatch_job.assignee.blank?

    accessible_active_groups.detect { |group| dispatch_job.assignee.group_access?(group.id, 'full') }
  end

  def state_for_type(type_name)
    Ticket::State
      .joins(:state_type)
      .where(active: true, ticket_state_types: { name: type_name })
      .reorder(:id)
      .first
  end

  def active_groups
    @active_groups ||= Group.where(active: true).sorted.to_a
  end

  def accessible_active_groups
    return active_groups if operator.blank?

    @accessible_active_groups ||= active_groups.select { |group| accessible_group?(group) }
  end

  def accessible_group?(group)
    return false if group.blank?
    return true if operator.blank?

    operator.group_access?(group.id, 'create') || operator.group_access?(group.id, 'change') || operator.group_access?(group.id, 'full')
  end
end
