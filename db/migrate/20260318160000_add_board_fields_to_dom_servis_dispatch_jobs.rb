require 'set'

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

      job.update_columns(
        job_code:  generate_job_code(created_at, used_codes),
        visit_day: visit_day,
        work_tags: [],
      )
    end
  end

  def down
    remove_index :dom_servis_dispatch_jobs, :visit_day
    remove_index :dom_servis_dispatch_jobs, :job_code

    remove_column :dom_servis_dispatch_jobs, :work_tags
    remove_column :dom_servis_dispatch_jobs, :visit_day
    remove_column :dom_servis_dispatch_jobs, :job_code
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
      suffix = format('%04d', rand(10_000))
      code   = "#{prefix}-#{suffix}"
      next if used_codes.include?(code)

      used_codes << code
      return code
    end
  end
end
