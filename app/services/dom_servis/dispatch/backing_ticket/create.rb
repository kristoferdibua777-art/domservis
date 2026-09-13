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

    UserInfo.with_user_id(resolver.actor_user.id) do
      Transaction.execute do
        ticket = Ticket.new(mapper.create_attributes)
        ticket.screen = 'create_middle' if ticket.respond_to?(:screen=)
        ticket.save!
        sync_ticket_tags!(ticket, resolver)

        create_article!(resolver, mapper, ticket, mapper.creation_article)
        dispatch_job.update_column(:ticket_id, ticket.id)

        ticket
      end
    end
  end

  private

  def create_article!(resolver, mapper, ticket, article)
    return if article.blank?

    Service::Ticket::Article::Create
      .new(current_user: resolver.article_user)
      .execute(article_data: article, ticket: ticket)
  end

  def sync_ticket_tags!(ticket, resolver)
    ticket.tag_update(dispatch_job.work_tags, resolver.actor_user.id)
  end
end
