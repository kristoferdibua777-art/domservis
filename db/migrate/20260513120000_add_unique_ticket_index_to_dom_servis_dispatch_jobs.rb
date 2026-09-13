# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddUniqueTicketIndexToDomServisDispatchJobs < ActiveRecord::Migration[7.2]
  def change
    add_index :dom_servis_dispatch_jobs, :ticket_id, unique: true, name: 'idx_dom_servis_dispatch_jobs_on_ticket_id_unique'
  end
end
