# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Intake::DispatchJobCreator
  SOURCES = %w[manual form email webhook ai].freeze

  def initialize(payload:, ticket: nil, actor_user: nil)
    @payload = payload.to_h.deep_symbolize_keys
    @ticket = ticket
    @actor_user = actor_user
  end

  attr_reader :payload, :ticket

  def execute
    validate_payload!

    if (job = existing_dispatch_job).present?
      mark_request_source_used!
      return job
    end

    UserInfo.with_user_id(actor_user.id) do
      dispatch_job = DomServis::DispatchJob.create!(dispatch_attributes)
      sync_backing_ticket!(dispatch_job) if ticket.present?
      mark_request_source_used!
      dispatch_job
    end
  end

  private

  def validate_payload!
    raise Exceptions::UnprocessableEntity, 'Dom-Servis intake payload is missing dispatch attributes.' if payload[:dispatch].blank?
    raise Exceptions::UnprocessableEntity, 'Dom-Servis intake payload requires a source.' if normalized_source.blank?
    raise Exceptions::UnprocessableEntity, "Dom-Servis intake payload uses unknown source '#{normalized_source}'." if !SOURCES.include?(normalized_source)
    raise Exceptions::UnprocessableEntity, 'Dom-Servis intake payload requires a source reference.' if normalized_source_reference.blank?
    raise Exceptions::UnprocessableEntity, 'Dom-Servis intake payload requires a request source.' if normalized_request_source_id.blank?
    raise Exceptions::UnprocessableEntity, 'Dom-Servis intake payload requires a channel key.' if payload[:channel_key].blank?
    raise Exceptions::UnprocessableEntity, 'Dom-Servis intake payload requires a partner organization.' if request_source.organization_id.blank?
    raise Exceptions::Forbidden, 'Dom-Servis request source is paused.' if request_source.paused?

    dispatch = payload[:dispatch]
    raise Exceptions::UnprocessableEntity, 'Dom-Servis intake payload requires service type.' if dispatch[:service_type].blank?
    raise Exceptions::UnprocessableEntity, 'Dom-Servis intake payload requires address.' if dispatch[:address].blank?
  end

  def existing_dispatch_job
    @existing_dispatch_job ||= begin
      if ticket.present?
        DomServis::DispatchJob.find_by(ticket_id: ticket.id)
      elsif normalized_source_reference.present?
        DomServis::DispatchJob.find_by(
          request_source_id: normalized_request_source_id,
          source_reference:  normalized_source_reference,
        )
      end
    end
  end

  def dispatch_attributes
    payload[:dispatch].merge(
      source:             normalized_source,
      request_source_id:   normalized_request_source_id,
      source_reference:    normalized_source_reference,
      organization_id:     request_source.organization_id,
      intake_channel_key:  payload[:channel_key].presence,
      intake_payload:      payload[:raw_payload].presence || {},
      ticket_id:           ticket&.id,
      created_by_id:       actor_user.id,
      updated_by_id:       actor_user.id,
    )
  end

  def sync_backing_ticket!(dispatch_job)
    metadata = intake_metadata(dispatch_job)
    ticket.update!(preferences: (ticket.preferences || {}).merge('dom_servis_intake' => metadata))

    DomServis::Dispatch::BackingTicket::SyncFromDispatch
      .new(dispatch_job: dispatch_job, operator: actor_user, changes: {})
      .execute
  end

  def intake_metadata(dispatch_job)
    {
      source:             normalized_source,
      source_reference:    normalized_source_reference,
      request_source_id:   normalized_request_source_id,
      partner_org_id:      request_source.organization_id,
      request_source_key:  request_source.partner_key,
      request_source_name: request_source.name,
      request_source_origin: payload[:request_source_origin].presence || payload.dig(:raw_payload, :request_source_origin).presence,
      channel_key:         payload[:channel_key],
      dispatch_job_id:     dispatch_job.id,
      ticket_id:           ticket.id,
      raw_payload:         payload[:raw_payload],
    }.compact
  end

  def normalized_source
    @normalized_source ||= payload[:source].to_s.strip
  end

  def normalized_organization_id
    @normalized_organization_id ||= request_source.organization_id
  end

  def normalized_source_reference
    @normalized_source_reference ||= payload[:source_reference].presence || payload.dig(:raw_payload, :ticket_number).presence
  end

  def normalized_request_source_id
    @normalized_request_source_id ||= payload[:request_source_id].presence || payload.dig(:dispatch, :request_source_id).presence || payload.dig(:raw_payload, :request_source_id).presence
  end

  def request_source
    @request_source ||= DomServis::RequestSource.find_by(id: normalized_request_source_id) || raise(Exceptions::UnprocessableEntity, 'Dom-Servis intake requires a valid request source.')
  end

  def actor_user
    @actor_user ||= User.order(:id).detect { |user| user.permissions?('ticket.agent') } || raise(Exceptions::UnprocessableEntity, 'Dom-Servis intake requires an available ticket agent user.')
  end

  def mark_request_source_used!
    request_source.touch(:last_used_at)
  rescue StandardError => e
    Rails.logger.warn("Dom-Servis request source usage tracking failed for #{request_source.id}: #{e.message}")
  end
end
