# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# A job's history outlives the job (decision 2026-09-28): when a job is
# deleted its events stay, detached from the job, and keep the job code so
# an export can still tell which job they belonged to. Existing events are
# not changed; the job code is written only when a job is deleted.
class KeepDomServisDispatchEventsAfterJobDeletion < ActiveRecord::Migration[7.2]
  def up
    change_column_null :dom_servis_dispatch_events, :dispatch_job_id, true
    add_column :dom_servis_dispatch_events, :job_code, :string if !column_exists?(:dom_servis_dispatch_events, :job_code)
    DomServis::DispatchEvent.reset_column_information
  end

  def down
    detached = select_value('SELECT COUNT(*) FROM dom_servis_dispatch_events WHERE dispatch_job_id IS NULL').to_i
    if detached.positive?
      raise "#{detached} Dom-Servis dispatch event(s) belong to deleted jobs and cannot be linked to a job again. " \
            'Nothing was changed. Export and remove that history first, then roll back again.'
    end

    remove_column :dom_servis_dispatch_events, :job_code if column_exists?(:dom_servis_dispatch_events, :job_code)
    change_column_null :dom_servis_dispatch_events, :dispatch_job_id, false
    DomServis::DispatchEvent.reset_column_information
  end
end
