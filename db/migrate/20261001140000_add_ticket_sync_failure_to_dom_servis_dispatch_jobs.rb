# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The backing ticket is a projection of the dispatch job. When updating it
# fails, the job keeps its change; these columns remember the failure until
# a later sync succeeds, so the board and Dispatch Admin can show it and a
# dispatcher can retry. Existing jobs are not changed.
class AddTicketSyncFailureToDomServisDispatchJobs < ActiveRecord::Migration[7.2]
  def up
    add_column :dom_servis_dispatch_jobs, :ticket_sync_failed_at, :datetime, limit: 3 if !column_exists?(:dom_servis_dispatch_jobs, :ticket_sync_failed_at)
    add_column :dom_servis_dispatch_jobs, :ticket_sync_error, :string, limit: 500 if !column_exists?(:dom_servis_dispatch_jobs, :ticket_sync_error)
    DomServis::DispatchJob.reset_column_information
  end

  def down
    remove_column :dom_servis_dispatch_jobs, :ticket_sync_error if column_exists?(:dom_servis_dispatch_jobs, :ticket_sync_error)
    remove_column :dom_servis_dispatch_jobs, :ticket_sync_failed_at if column_exists?(:dom_servis_dispatch_jobs, :ticket_sync_failed_at)
    DomServis::DispatchJob.reset_column_information
  end
end
