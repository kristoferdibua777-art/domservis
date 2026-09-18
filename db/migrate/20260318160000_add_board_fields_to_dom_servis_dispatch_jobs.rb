# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddBoardFieldsToDomServisDispatchJobs < ActiveRecord::Migration[7.2]
  class DispatchJob < ActiveRecord::Base
    self.table_name = 'dom_servis_dispatch_jobs'
  end

  VISIT_DAY_MAP = {
    1 => 'mon',
    2 => 'tue',
    3 => 'wed',
    4 => 'thu',
    5 => 'fri',
    6 => 'sat',
    0 => 'sun',
  }.freeze

  def up
    add_column :dom_servis_dispatch_jobs, :job_code, :string
    add_column :dom_servis_dispatch_jobs, :visit_day, :string
    add_column :dom_servis_dispatch_jobs, :work_tags, :jsonb, null: false, default: []

    add_index :dom_servis_dispatch_jobs, :job_code, unique: true
    add_index :dom_servis_dispatch_jobs, :visit_day

    DispatchJob.reset_column_information

    used_codes = Set.new

    DispatchJob.find_each do |job|
      created_at = job.created_at || Time.zone.now
      visit_day  = infer_visit_day(job.visit_date, created_at)

      # rubocop:disable Rails/SkipsModelValidations -- migration data
      # backfill: intentionally skips DispatchJob's validation/callback
      # chain for a one-time bulk update of historical rows.
      job.update_columns(
        job_code:  generate_job_code(created_at, used_codes),
        visit_day: visit_day,
        work_tags: [],
      )
      # rubocop:enable Rails/SkipsModelValidations
    end
  end

  def down
    remove_index :dom_servis_dispatch_jobs, :visit_day
    remove_index :dom_servis_dispatch_jobs, :job_code

    remove_column :dom_servis_dispatch_jobs, :work_tags
    remove_column :dom_servis_dispatch_jobs, :visit_day
    # rubocop:disable Zammad/ExistsResetColumnInformation -- `up` above
    # already calls DispatchJob.reset_column_information (this file's
    # migration-local shim, line 26) right before using the model; this
    # cop can't recognize that call because it string-matches the
    # receiver's unqualified constant name ("DispatchJob") against
    # `table_name.classify` ("DomServisDispatchJob") and the two never
    # match for a locally-scoped shim class. `down` here only drops
    # columns via raw DDL and never touches the model afterwards, so no
    # reset call is actually needed on this line either.
    remove_column :dom_servis_dispatch_jobs, :job_code
    # rubocop:enable Zammad/ExistsResetColumnInformation
  end

  private

  def infer_visit_day(visit_date, fallback_time)
    return VISIT_DAY_MAP[fallback_time.wday] if visit_date.blank?

    parsed_date = Date.parse(visit_date.to_s)
    VISIT_DAY_MAP[parsed_date.wday]
  rescue ArgumentError
    VISIT_DAY_MAP[fallback_time.wday]
  end

  def generate_job_code(timestamp, used_codes)
    prefix = timestamp.strftime('%Y%m%d')

    loop do
      # rubocop:disable Zammad/ForbidRand -- intentional: job_code must stay
      # a short, human-readable "YYYYMMDD-NNNN" code that dispatchers and
      # masters can read out over the phone, so a SecureRandom.uuid (the
      # cop's suggested alternative) is not an option here. `job_code` is
      # a brand-new column added earlier in this same migration, so there
      # is no pre-existing data to collide with; the `used_codes` Set plus
      # this retry loop already guarantees uniqueness across all rows
      # backfilled in this run, and the column has a unique DB index as a
      # hard backstop.
      suffix = format('%04d', rand(10_000))
      # rubocop:enable Zammad/ForbidRand
      code   = "#{prefix}-#{suffix}"
      next if used_codes.include?(code)

      used_codes << code
      return code
    end
  end
end
