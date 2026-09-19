# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddPartnerIntakeFieldsToDomServisRequestSources < ActiveRecord::Migration[7.2]
  def up
    add_column :dom_servis_request_sources, :public_embed_id, :string
    add_column :dom_servis_request_sources, :credential_version, :integer, null: false, default: 1
    add_column :dom_servis_request_sources, :challenge_required, :boolean, null: false, default: true
    add_column :dom_servis_request_sources, :rate_limit_config, :jsonb, null: false, default: {}
    add_column :dom_servis_request_sources, :revoked_at, :datetime

    backfill_public_embed_id

    change_column_null :dom_servis_request_sources, :public_embed_id, false
    add_index :dom_servis_request_sources, :public_embed_id, unique: true
  end

  def down
    remove_index :dom_servis_request_sources, :public_embed_id
    remove_column :dom_servis_request_sources, :revoked_at
    remove_column :dom_servis_request_sources, :rate_limit_config
    remove_column :dom_servis_request_sources, :challenge_required
    remove_column :dom_servis_request_sources, :credential_version
    remove_column :dom_servis_request_sources, :public_embed_id
  end

  private

  # Backfills every pre-existing row with a unique, non-guessable public
  # embed id before the NOT NULL + unique index are applied. Runs a plain
  # UPDATE per row (table is expected to be small — one row per partner)
  # rather than a bulk statement, so each row gets its own random value.
  def backfill_public_embed_id
    connection.select_rows('SELECT id FROM dom_servis_request_sources').each do |(id)|
      connection.execute(
        "UPDATE dom_servis_request_sources SET public_embed_id = #{connection.quote(SecureRandom.uuid)} WHERE id = #{id.to_i}",
      )
    end
  end
end
