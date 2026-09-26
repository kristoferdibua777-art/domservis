# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Introduces the dispatcher-owned `closed` status (DomServis::DispatchWorkflow).
#
# Existing jobs that already break the status <-> master invariant are not
# repaired here: the migration stops before changing anything and lists them,
# so they can be fixed deliberately. The backing tickets are not touched; their
# projection is refreshed by the next dispatch operation on the job.
class AddClosedStatusToDomServisDispatchJobs < ActiveRecord::Migration[7.2]
  INVARIANT_VIOLATIONS = {
    'pool job(s) with a master'                 => "SELECT id FROM dom_servis_dispatch_jobs WHERE status = 'pool' AND assignee_id IS NOT NULL ORDER BY id",
    'taken/in_progress job(s) without a master' => "SELECT id FROM dom_servis_dispatch_jobs WHERE status IN ('taken', 'in_progress') AND assignee_id IS NULL ORDER BY id",
    'job(s) with an unknown status'             => "SELECT id FROM dom_servis_dispatch_jobs WHERE status NOT IN ('pool', 'taken', 'in_progress', 'done', 'cancelled', 'transferred_to_partner') ORDER BY id",
  }.freeze

  LISTED_IDS_LIMIT = 20

  def up
    ensure_no_invariant_violations!

    add_column :dom_servis_dispatch_jobs, :closed_at, :datetime, limit: 3 if !column_exists?(:dom_servis_dispatch_jobs, :closed_at)
    DomServis::DispatchJob.reset_column_information

    # Before the split `done` was the terminal state that also closed the
    # backing ticket, so those jobs are closed in the new model.
    execute <<~SQL.squish
      UPDATE dom_servis_dispatch_jobs
      SET status = 'closed', closed_at = COALESCE(completed_at, updated_at)
      WHERE status = 'done'
    SQL
  end

  def down
    execute "UPDATE dom_servis_dispatch_jobs SET status = 'done' WHERE status = 'closed'"

    remove_column :dom_servis_dispatch_jobs, :closed_at if column_exists?(:dom_servis_dispatch_jobs, :closed_at)
    DomServis::DispatchJob.reset_column_information
  end

  private

  def ensure_no_invariant_violations!
    violations = INVARIANT_VIOLATIONS.filter_map do |label, sql|
      ids = select_values(sql)
      next if ids.empty?

      listed = ids.first(LISTED_IDS_LIMIT).join(', ')
      listed = "#{listed}, ..." if ids.size > LISTED_IDS_LIMIT
      "#{ids.size} #{label} (ids: #{listed})"
    end
    return if violations.empty?

    raise "Dom-Servis dispatch jobs break the status/master invariant: #{violations.join('; ')}. " \
          'Nothing was changed. Fix these jobs, then run the migration again.'
  end
end
