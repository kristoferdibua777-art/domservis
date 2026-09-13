# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Escalates a Dom-Servis dispatch job that has been sitting in the shared
# pool past its configured deadline (dispatch policy setting
# `deadline_warning_minutes`, default 120).
#
# Enqueued by DomServis::DispatchJob on creation with a delay equal to the
# deadline. When the job runs it re-checks whether the dispatch job is
# still unclaimed; if it has been taken in the meantime, the escalation
# is a no-op and is silently discarded.
#
# Uses HasActiveJobLock with :upsert_date so that re-publishing a job
# (e.g. after a release back to the pool) reschedules the existing
# pending escalation instead of stacking duplicates.
module DomServis
  class DispatchEscalationJob < ApplicationJob
    include HasActiveJobLock

    EXISTING_ACTIVE_JOB_LOCK_BEHAVIOUR = :upsert_date

    queue_as :default

    def perform(dispatch_job_id)
      job = DomServis::DispatchJob.find_by(id: dispatch_job_id)
      return if job.blank?

      # The job was taken, cancelled or transferred since the escalation
      # was scheduled — nothing to escalate anymore.
      return if job.status != 'pool'

      recipients = DomServis::Notifications::Dispatcher
        .recipients_for_permissions('dom_servis.dispatcher', 'dom_servis.admin')

      DomServis::Notifications::Dispatcher.new(
        job:        job,
        event_type: :job_unclaimed,
        recipients: recipients,
        actor:      job.created_by,
      ).deliver
    end

    private

    def lock_key
      "#{self.class.name}/#{arguments[0]}"
    end
  end
end
