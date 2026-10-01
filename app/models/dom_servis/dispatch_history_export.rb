# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# One Excel export of the job history (decision 2026-09-28). An export holds
# every event up to last_event_id; after its file was downloaded, the admin
# may allow removing exactly those events.
class DomServis::DispatchHistoryExport < ApplicationModel
  self.table_name = 'dom_servis_dispatch_history_exports'

  # Admins are reminded to export when the last downloaded export (or, before
  # the first one, the oldest event) is this many days old.
  REMINDER_DAYS = 30

  belongs_to :created_by, class_name: 'User'
  belongs_to :purged_by, class_name: 'User', optional: true

  def self.due?
    return false if !DomServis::DispatchEvent.exists?

    since = where.not(downloaded_at: nil).maximum(:downloaded_at) || DomServis::DispatchEvent.minimum(:created_at)
    since <= REMINDER_DAYS.days.ago
  end

  def self.status
    {
      event_count:   DomServis::DispatchEvent.count,
      due:           due?,
      reminder_days: REMINDER_DAYS,
      last_export:   reorder(:id).last&.status,
    }
  end

  # The events this export holds that are still stored.
  def events
    DomServis::DispatchEvent.where(id: ..last_event_id)
  end

  def purged?
    purged_at.present?
  end

  def purgeable?
    downloaded_at.present? && !purged?
  end

  def status
    {
      id:              id,
      created_at:      created_at,
      created_by_name: created_by&.fullname,
      last_event_id:   last_event_id,
      event_count:     event_count,
      downloaded_at:   downloaded_at,
      purged_at:       purged_at,
      purged_by_name:  purged_by&.fullname,
      purged_count:    purged_count,
      purgeable:       purgeable?,
    }
  end
end
