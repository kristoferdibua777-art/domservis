# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::BaseController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # Personal data of the client (152-FZ data minimisation): a master sees who
  # the client is and how to reach them only once the job is theirs. Pool jobs
  # and jobs of other masters show the work and the address, not the contacts.
  CLIENT_CONTACT_FIELDS = %w[client_name client_phone].freeze

  private

  def dispatch_job_scope
    policy_scope(DomServis::DispatchJob)
  end

  def dispatch_staff_access?
    current_user.permissions?('dom_servis.admin') || current_user.permissions?('dom_servis.dispatcher')
  end

  def client_contacts_visible?(job)
    return true if dispatch_staff_access?

    job.assignee_id.present? && job.assignee_id == current_user.id
  end

  # Returns a copy of a job payload (string or symbol keys) without the
  # client's contacts, flagged so the board can explain why they are missing.
  def redact_client_contacts(payload, job)
    return payload if client_contacts_visible?(job)
    return payload if !payload.is_a?(Hash)

    redacted = payload.dup
    CLIENT_CONTACT_FIELDS.each do |field|
      redacted[field] = nil if redacted.key?(field)
      redacted[field.to_sym] = nil if redacted.key?(field.to_sym)
    end
    redacted['client_contacts_hidden'] = true
    redacted
  end

  # The same for an event of a job: field changes may carry old and new
  # contacts.
  def redact_event_client_contacts(event_payload, job)
    return event_payload if client_contacts_visible?(job)

    meta = event_payload['meta']
    return event_payload if !meta.is_a?(Hash)

    changes = meta['changes'] || meta[:changes]
    return event_payload if !changes.is_a?(Hash)

    cleaned = changes.reject { |field, _| CLIENT_CONTACT_FIELDS.include?(field.to_s) }
    return event_payload if cleaned.size == changes.size

    event_payload.merge('meta' => meta.merge('changes' => cleaned).except(:changes))
  end
end
