# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Job history is exported to Excel by an admin and removed only after that
# admin allows it (decision 2026-09-28). One row per export: which events it
# holds (every event up to last_event_id), when the file was downloaded and
# when, by whom and how many of its events were removed afterwards.
class CreateDomServisDispatchHistoryExports < ActiveRecord::Migration[7.2]
  def change
    create_table :dom_servis_dispatch_history_exports, id: :integer do |t|
      t.references :created_by, null: false, foreign_key: { to_table: :users }, type: :integer
      t.integer :last_event_id, null: false
      t.integer :event_count, null: false
      t.datetime :downloaded_at, limit: 3
      t.datetime :purged_at, limit: 3
      t.references :purged_by, foreign_key: { to_table: :users }, type: :integer
      t.integer :purged_count

      t.timestamps limit: 3, null: false
    end
  end
end