# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Retries the backing ticket sync of a dispatch job once, a few minutes after
# it failed (DomServis::Dispatch::JobsController#sync_backing_ticket!). A
# transient failure heals by itself; a lasting one stays recorded on the job
# for the board and Dispatch Admin, where a dispatcher can retry it.
module DomServis
  class BackingTicketResyncJob < ApplicationJob
    include HasActiveJobLock

    RETRY_DELAY = 5.minutes

    queue_as :default

    def perform(dispatch_job_id)
      job = DomServis::DispatchJob.find_by(id: dispatch_job_id)
      return if job.blank? || job.ticket_sync_failed_at.blank?

      begin
        DomServis::Dispatch::BackingTicket::SyncFromDispatch
          .new(dispatch_job: job, operator: nil, changes: {})
          .execute
        job.clear_ticket_sync_failure!
      rescue => e
        Rails.logger.error("[dom_servis.backing_ticket] retry failed for job=#{job.id}: #{e.class}: #{e.message}")
        job.record_ticket_sync_failure!(e)
      end
    end

    private

    def lock_key
      "#{self.class.name}/#{arguments[0]}"
    end
  end
end
