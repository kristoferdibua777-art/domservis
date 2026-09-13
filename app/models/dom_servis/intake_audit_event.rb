# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::IntakeAuditEvent < ApplicationModel
  self.table_name = 'dom_servis_intake_audit_events'

  # Not yet written to by any code path (DB foundation only). Future
  # writers (ticket verification, rate limiting, challenge verification,
  # legacy intake logging) will use this fixed vocabulary so audit
  # queries/dashboards can rely on a closed set of values.
  DECISIONS = %w[
    accepted
    rejected_signature
    rejected_expired
    rejected_replay
    rejected_rate_limit
    rejected_challenge
    rejected_paused
    rejected_revoked
    rejected_tenant_mismatch
    rejected_unknown
    legacy_path
  ].freeze

  belongs_to :request_source, class_name: 'DomServis::RequestSource', optional: true
  belongs_to :organization, optional: true

  validates :decision, presence: true, inclusion: { in: DECISIONS }

  scope :ordered_recent, -> { order(created_at: :desc, id: :desc) }
end
