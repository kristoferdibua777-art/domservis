# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::BackingTicket::SyncFromDispatch
  def initialize(dispatch_job:, operator:, changes: {})
    @dispatch_job = dispatch_job
    @operator = operator
    @changes = changes
  end

  attr_reader :dispatch_job, :operator, :changes

  def execute
    ticket = dispatch_job.ticket || DomServis::Dispatch::BackingTicket::Create.new(dispatch_job:, operator:, changes:).execute
    resolver = DomServis::Dispatch::BackingTicket::Resolver.new(dispatch_job:, operator:)
    mapper   = DomServis::Dispatch::BackingTicket::Mapper.new(dispatch_job:, resolver:)

    update_data = filter_unchanged(ticket, mapper.update_attributes)
    article     = mapper.change_article(changes)
    tags_changed = ticket.tag_list.sort != Array(dispatch_job.work_tags).sort

    return ticket if update_data.blank? && article.blank? && !tags_changed

    UserInfo.with_user_id(resolver.actor_user.id) do
      Transaction.execute do
        ticket.screen = 'edit' if ticket.respond_to?(:screen=)
        ticket.update!(update_data) if update_data.present?
        reassert_dispatch_organization!(ticket)
        ticket.tag_update(dispatch_job.work_tags, resolver.actor_user.id) if tags_changed

        if article.present?
          Service::Ticket::Article::Create
            .new(current_user: resolver.article_user)
            .execute(article_data: article, ticket: ticket)
        end

        ticket.reload
      end
    end
  end

  private

  # rubocop:disable Rails/SkipsModelValidations -- see the identical method in
  # DomServis::Dispatch::BackingTicket::Create for the full rationale: the
  # shared dispatch-board customer belongs to no organization, so Zammad's
  # own check_default_organization callback resets organization_id back to
  # nil on every ticket.update! that touches it, not just at creation time.
  def reassert_dispatch_organization!(ticket)
    return if dispatch_job.organization_id.blank?
    return if ticket.organization_id == dispatch_job.organization_id

    ticket.update_column(:organization_id, dispatch_job.organization_id)
  end
  # rubocop:enable Rails/SkipsModelValidations

  def filter_unchanged(ticket, attributes)
    attributes.each_with_object({}) do |(key, value), memo|
      next if !ticket.has_attribute?(key)
      next if ticket.public_send(key) == value

      memo[key] = value
    end
  end
end
