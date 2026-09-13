# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Persists a per-user Web Push subscription for the Dom-Servis dispatch board.
#
# Created when a browser grants notification permission and registers a
# push subscription via the dispatch service worker. The backend fans out
# push messages to every active subscription a user owns (so a master can
# receive notifications on multiple devices simultaneously).
#
# Subscriptions are deactivated rather than destroyed when the push
# service reports them as expired or invalid, keeping an audit trail.
class DomServis::PushSubscription < ApplicationModel
  self.table_name = 'dom_servis_push_subscriptions'

  belongs_to :user, optional: true

  validates :endpoint, presence: true, uniqueness: { case_sensitive: true }
  validates :p256dh_key, presence: true
  validates :auth_key, presence: true

  before_validation :normalize_endpoint
  before_validation :strip_user_agent

  scope :active, -> { where(active: true) }
  scope :for_user, ->(user) { where(user_id: user.id) }

  # Returns true when this subscription can no longer be used to deliver
  # push messages (push service rejected it or it expired).
  def stale?(response_status: nil)
    return true if !active?
    return false if response_status.blank?

    # 404 (endpoint gone) and 410 (subscription expired) are permanent.
    response_status.to_i.in?(404, 410)
  end

  private

  def normalize_endpoint
    self.endpoint = endpoint.to_s.strip
  end

  def strip_user_agent
    self.user_agent = user_agent.to_s[0, 500]
  end
end
