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
    # rubocop:disable Zammad/ExistsResetColumnInformation -- this migration
    # never instantiates or queries the DispatchJob model, in either `up`
    # or `down`; it only issues raw add_column/remove_column/index DDL, so
    # there is no cached column state anywhere in this file that needs
    # resetting. Not adding an unused model shim here just to satisfy the
    # cop (see 20260318160000 and 20260321193000 for the pattern used
    # where a migration actually does read/write through the model).
    remove_column :dom_servis_dispatch_jobs, :source_reference
    # rubocop:enable Zammad/ExistsResetColumnInformation
  end
end
