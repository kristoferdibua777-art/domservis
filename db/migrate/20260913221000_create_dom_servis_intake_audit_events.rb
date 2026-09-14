# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class CreateDomServisIntakeAuditEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :dom_servis_intake_audit_events do |t|
      t.references :request_source, foreign_key: { to_table: :dom_servis_request_sources, on_delete: :nullify }
      t.references :organization, foreign_key: true

      t.string :decision, null: false
      t.string :request_id
      t.string :ip_address
      t.string :claimed_domain
      t.string :origin_header
      t.string :referer_header
      t.string :challenge_result
      t.string :rate_limit_result
      t.string :ticket_validation_result
      t.string :nonce

      t.timestamps null: false
    end

    add_index :dom_servis_intake_audit_events, %i[request_source_id created_at], name: 'idx_dom_servis_intake_audit_events_on_source_and_created_at'
    add_index :dom_servis_intake_audit_events, %i[organization_id created_at], name: 'idx_dom_servis_intake_audit_events_on_org_and_created_at'
    add_index :dom_servis_intake_audit_events, :decision
    add_index :dom_servis_intake_audit_events, :nonce
  end
end
