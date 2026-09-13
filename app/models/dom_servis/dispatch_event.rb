# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::DispatchEvent < ApplicationModel
  self.table_name = 'dom_servis_dispatch_events'

  EVENT_TYPES = %w[
    created
    published
    taken
    released
    assigned
    assignee_changed
    status_changed
    moved_weekday
    priority_changed
    tags_changed
    comment_added
    description_updated
    organization_changed
    attachment_added
    attachment_removed
    ai_parsed
    updated
  ].freeze

  belongs_to :dispatch_job,
             class_name: 'DomServis::DispatchJob',
             inverse_of: :events
  belongs_to :actor_user, class_name: 'User', optional: true

  validates :event_type, inclusion: { in: EVENT_TYPES }

  scope :ordered_recent, -> { order(created_at: :desc, id: :desc) }
end
