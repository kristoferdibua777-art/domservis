# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class CreateDomServisDispatchTables < ActiveRecord::Migration[7.2]
  def change
    create_table :dom_servis_dispatch_jobs do |t|
      t.references :created_by, foreign_key: { to_table: :users }
      t.references :updated_by, foreign_key: { to_table: :users }
      t.references :assignee,   foreign_key: { to_table: :users }
      t.references :ticket,     foreign_key: true

      t.string :status,       null: false, default: 'pool'
      t.string :priority,     null: false, default: 'medium'
      t.string :service_type, null: false
      t.string :client_name
      t.string :client_phone
      t.string :address,      null: false
      t.string :visit_date
      t.string :visit_time
      t.text   :description
      t.text   :comment
      t.string :source,       null: false, default: 'manual'
      t.datetime :published_at
      t.datetime :taken_at
      t.datetime :completed_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :dom_servis_dispatch_jobs, :status
    add_index :dom_servis_dispatch_jobs, :priority
    add_index :dom_servis_dispatch_jobs, :source
    add_index :dom_servis_dispatch_jobs, :visit_date
    add_index :dom_servis_dispatch_jobs, %i[status assignee_id], name: 'idx_dom_servis_dispatch_jobs_on_status_and_assignee'

    create_table :dom_servis_dispatch_events do |t|
      t.references :dispatch_job, null: false, foreign_key: { to_table: :dom_servis_dispatch_jobs }
      t.references :actor_user, foreign_key: { to_table: :users }
      t.string :event_type, null: false
      t.jsonb :meta, null: false, default: {}

      t.timestamps
    end

    add_index :dom_servis_dispatch_events, :event_type
    add_index :dom_servis_dispatch_events, %i[dispatch_job_id created_at], name: 'idx_dom_servis_dispatch_events_on_job_and_created_at'
  end
end
