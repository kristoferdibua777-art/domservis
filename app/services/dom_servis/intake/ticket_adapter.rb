# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Intake::TicketAdapter
  DEFAULT_CHANNEL_KEY = 'zammad_form'.freeze

  def initialize(ticket:, request_source:, source: 'form', channel_key: nil, source_reference: nil, request_source_origin: nil)
    @ticket = ticket
    @request_source = request_source
    @source = source.to_s
    @channel_key = channel_key.to_s
    @source_reference = source_reference
    @request_source_origin = request_source_origin
  end

  attr_reader :ticket, :request_source, :source, :channel_key, :source_reference
  attr_reader :request_source_origin

  def payload
    {
      source:             source,
      request_source_id:  request_source.id,
      source_reference:   source_reference.presence || ticket.number,
      channel_key:        channel_key.presence || request_source.transport_kind.presence || DEFAULT_CHANNEL_KEY,
      request_source_origin: request_source_origin.presence,
      raw_payload:        raw_payload,
      dispatch:           dispatch_attributes,
    }
  end

  private

  def dispatch_attributes
    {
      source:           source,
      request_source_id: request_source.id,
      organization_id:   request_source.organization_id,
      service_type:     ticket_value(:dom_servis_service_type).presence || ticket.title,
      address:          required_ticket_value(:dom_servis_address),
      client_name:      ticket_value(:dom_servis_client_name).presence || ticket.customer&.fullname || ticket.customer&.login || ticket.customer&.email,
      client_phone:     ticket_value(:dom_servis_client_phone).presence || ticket.customer&.phone,
      visit_day:        ticket_value(:dom_servis_visit_day).presence,
      visit_date:       ticket_value(:dom_servis_visit_date).presence,
      visit_time:       ticket_value(:dom_servis_visit_time).presence,
      priority:         ticket_value(:dom_servis_dispatch_priority).presence || 'medium',
      description:      ticket_value(:dom_servis_description).presence || ticket_body,
      comment:          ticket_value(:dom_servis_comment).presence,
      work_tags:        normalize_work_tags(ticket_value(:dom_servis_work_tags)),
    }.compact
  end

  def raw_payload
    {
      ticket_id:      ticket.id,
      ticket_number:  ticket.number,
      ticket_title:   ticket.title,
      ticket_body:    ticket_body,
      customer_id:    ticket.customer_id,
      request_source_id: request_source.id,
      organization_id:   request_source.organization_id,
      request_source_origin: request_source_origin.presence,
      request_source: {
        id:            request_source.id,
        partner_key:   request_source.partner_key,
        name:          request_source.name,
        transport_kind: request_source.transport_kind,
        status:        request_source.status,
      },
      form_fields:    {
        dom_servis_service_type:      ticket_value(:dom_servis_service_type),
        dom_servis_address:           ticket_value(:dom_servis_address),
        dom_servis_client_name:       ticket_value(:dom_servis_client_name),
        dom_servis_client_phone:      ticket_value(:dom_servis_client_phone),
        dom_servis_visit_day:         ticket_value(:dom_servis_visit_day),
        dom_servis_visit_date:        ticket_value(:dom_servis_visit_date),
        dom_servis_visit_time:        ticket_value(:dom_servis_visit_time),
        dom_servis_dispatch_priority: ticket_value(:dom_servis_dispatch_priority),
        dom_servis_description:       ticket_value(:dom_servis_description),
        dom_servis_comment:           ticket_value(:dom_servis_comment),
        dom_servis_work_tags:         ticket_value(:dom_servis_work_tags),
      },
    }
  end

  def ticket_body
    ticket.articles.reorder(:created_at, :id).last&.body.presence
  end

  def required_ticket_value(field_name)
    value = ticket_value(field_name).presence
    return value if value.present?

    raise Exceptions::UnprocessableEntity, "Dom-Servis intake requires the '#{field_name}' field."
  end

  def ticket_value(field_name)
    return nil if !ticket.respond_to?(field_name)

    ticket.public_send(field_name)
  end

  def normalize_work_tags(value)
    tags =
      case value
      when Array
        value
      when String
        value.split(',')
      else
        []
      end

    tags.filter_map do |tag_name|
      normalized = tag_name.to_s.strip
      normalized.presence
    end.uniq.first(10)
  end
end
