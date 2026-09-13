# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddIntakeMetadataToDomServisDispatchJobs < ActiveRecord::Migration[7.2]
  def up
    add_column :dom_servis_dispatch_jobs, :source_reference, :string
    add_column :dom_servis_dispatch_jobs, :intake_channel_key, :string
    add_column :dom_servis_dispatch_jobs, :intake_payload, :jsonb, null: false, default: {}

    add_index :dom_servis_dispatch_jobs, %i[source intake_channel_key source_reference], unique: true, name: 'idx_dom_servis_dispatch_jobs_on_source_channel_and_reference'
    add_index :dom_servis_dispatch_jobs, :source_reference
    add_index :dom_servis_dispatch_jobs, :intake_channel_key
  end

  def down
    remove_index :dom_servis_dispatch_jobs, :intake_channel_key
    remove_index :dom_servis_dispatch_jobs, :source_reference
    remove_index :dom_servis_dispatch_jobs, name: 'idx_dom_servis_dispatch_jobs_on_source_channel_and_reference'

    remove_column :dom_servis_dispatch_jobs, :intake_payload
    remove_column :dom_servis_dispatch_jobs, :intake_channel_key
    remove_column :dom_servis_dispatch_jobs, :source_reference
  end
end
