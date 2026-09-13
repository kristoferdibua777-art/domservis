class CreateDomServisRequestSources < ActiveRecord::Migration[7.2]
  LEGACY_REQUEST_SOURCE_KEY = 'legacy-zammad-form'.freeze

  def up
    create_table :dom_servis_request_sources do |t|
      t.string :name, null: false
      t.string :partner_key, null: false
      t.string :embed_token, null: false
      t.references :organization, foreign_key: true
      t.string :transport_kind, null: false, default: 'zammad_form'
      t.string :status, null: false, default: 'paused'
      t.jsonb :allowed_domains, null: false, default: []
      t.jsonb :settings, null: false, default: {}
      t.text :notes
      t.datetime :token_rotated_at
      t.datetime :last_used_at
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }

      t.timestamps null: false
    end

    add_index :dom_servis_request_sources, :partner_key, unique: true
    add_index :dom_servis_request_sources, :embed_token, unique: true
    add_index :dom_servis_request_sources, :transport_kind
    add_index :dom_servis_request_sources, :status

    add_reference :dom_servis_dispatch_jobs, :request_source, foreign_key: { to_table: :dom_servis_request_sources }

    remove_index :dom_servis_dispatch_jobs, name: 'idx_dom_servis_dispatch_jobs_on_source_channel_and_reference'
    add_index :dom_servis_dispatch_jobs, %i[request_source_id source_reference], unique: true, name: 'idx_dom_servis_dispatch_jobs_on_request_source_and_reference'

    create_legacy_request_source
    backfill_existing_dispatch_jobs
  end

  def down
    remove_index :dom_servis_dispatch_jobs, name: 'idx_dom_servis_dispatch_jobs_on_request_source_and_reference'
    add_index :dom_servis_dispatch_jobs, %i[source intake_channel_key source_reference], unique: true, name: 'idx_dom_servis_dispatch_jobs_on_source_channel_and_reference'
    remove_reference :dom_servis_dispatch_jobs, :request_source, foreign_key: { to_table: :dom_servis_request_sources }

    drop_table :dom_servis_request_sources
  end

  private

  def create_legacy_request_source
    organization_id = Setting.get('dom_servis_form_organization_id').presence
    intake_enabled = Setting.get('dom_servis_form_intake_enabled') == true
    return if organization_id.blank? && !intake_enabled

    system_user = User.order(:id).first
    return if system_user.blank?

    request_source = DomServis::RequestSource.find_or_initialize_by(partner_key: LEGACY_REQUEST_SOURCE_KEY)
    request_source.name = 'Legacy Zammad Form' if request_source.name.blank?
    request_source.embed_token = 'legacy-zammad-form-token' if request_source.embed_token.blank?
    request_source.organization_id = organization_id if request_source.organization_id.blank? && organization_id.present?
    request_source.created_by_id ||= system_user.id
    request_source.updated_by_id ||= system_user.id
    request_source.transport_kind = 'zammad_form'
    request_source.status = intake_enabled && organization_id.present? ? 'active' : 'paused'
    request_source.allowed_domains = request_source.allowed_domains.presence || []
    request_source.settings = request_source.settings.presence || {}
    request_source.save!
  end

  def backfill_existing_dispatch_jobs
    request_source = DomServis::RequestSource.find_by(partner_key: LEGACY_REQUEST_SOURCE_KEY)
    return if request_source.blank?

    DomServis::DispatchJob.where(request_source_id: nil, source: 'form').find_each do |job|
      job.update_columns(
        request_source_id: request_source.id,
        updated_at: Time.zone.now,
      )
    end
  end
end
