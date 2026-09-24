# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::BackingTicket::Create
  def initialize(dispatch_job:, operator:, changes: {})
    @dispatch_job = dispatch_job
    @operator = operator
    @changes = changes
  end

  attr_reader :dispatch_job, :operator, :changes

  def execute
    return dispatch_job.ticket if dispatch_job.ticket_id.present? && dispatch_job.ticket.present?

    resolver = DomServis::Dispatch::BackingTicket::Resolver.new(dispatch_job:, operator:)
    mapper   = DomServis::Dispatch::BackingTicket::Mapper.new(dispatch_job:, resolver:)

    ticket = UserInfo.with_user_id(resolver.actor_user.id) do
      Transaction.execute do
        ticket = Ticket.new(mapper.create_attributes)
        ticket.screen = 'create_middle' if ticket.respond_to?(:screen=)
        ticket.save!
        reassert_dispatch_organization!(ticket)
        sync_ticket_tags!(ticket, resolver)

        create_article!(resolver, mapper, ticket, mapper.creation_article)
        # rubocop:disable Rails/SkipsModelValidations -- deliberate: this is
        # an internal bookkeeping link (dispatch_job -> the ticket just
        # created above), not a user-facing edit. Using update! here would
        # re-run DispatchJob's before_validation chain (apply_defaults,
        # assign_job_code, normalize_work_tags, normalize_intake_metadata,
        # sync_lifecycle_timestamps) even though none of those fields are
        # changing, risking an unintended side effect from one of those
        # callbacks on an already-persisted, already-valid record. No
        # after_save/after_update callback exists on DispatchJob, so
        # skipping validations here does not skip any notification or
        # other side effect.
        dispatch_job.update_column(:ticket_id, ticket.id)
        # rubocop:enable Rails/SkipsModelValidations

        ticket
      end
    end

    # Transaction.execute's `ensure` runs the synchronous transaction
    # backends (Transaction::Trigger among them) *after* the block above
    # returns, and that backend re-fetches its own fresh Ticket instance by
    # id and may save it, running Ticket#check_defaults again and wiping the
    # organization_id reassert above a second time. Reassert once more here,
    # strictly after Transaction.execute (and everything it dispatches) has
    # finished, so nothing downstream can undo it again.
    reassert_dispatch_organization!(ticket)
    ticket
  end

  private

  def create_article!(resolver, _mapper, ticket, article)
    return if article.blank?

    Service::Ticket::Article::Create
      .new(current_user: resolver.article_user)
      .execute(article_data: article, ticket: ticket)
  end

  def sync_ticket_tags!(ticket, resolver)
    ticket.tag_update(dispatch_job.work_tags, resolver.actor_user.id)
  end

  # rubocop:disable Rails/SkipsModelValidations -- deliberate, same rationale
  # as dispatch_job.update_column(:ticket_id, ...) above: Ticket#check_defaults
  # (a before_create/before_update callback) calls check_default_organization,
  # which resets organization_id back to the customer's own organization
  # whenever it is not among the customer's known organizations. The shared
  # Dom-Servis dispatch-board customer (Resolver#customer) intentionally
  # belongs to no organization at all, since it is reused across every
  # partner, so that callback silently wipes out the partner organization_id
  # already set by Mapper#create_attributes - on every create, and again
  # whenever Transaction::Trigger (run from Transaction.execute's own
  # `ensure`, after this class's block has already returned) re-fetches its
  # own fresh Ticket instance and saves it. Called from two places for that
  # reason; always reassert unconditionally rather than short-circuiting on
  # ticket.organization_id already matching, since that in-memory value never
  # reflects a resave done by a different Ticket instance loaded elsewhere.
  def reassert_dispatch_organization!(ticket)
    return if dispatch_job.organization_id.blank?

    ticket.update_column(:organization_id, dispatch_job.organization_id)
  end
  # rubocop:enable Rails/SkipsModelValidations
end
