# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Single entry point for dispatching board notifications across channels.
#
# Given a dispatch job, an event type and a list of recipients, this
# service fans out to every configured channel:
#
#   - in-app bell (OnlineNotification) so the badge counter updates
#     even when the user is logged in but the PWA is in the background
#   - Web Push to every active push subscription the recipient owns,
#     so the device vibrates / shows a system notification
#
# Both channels are independent: if Web Push is not configured yet,
# in-app notifications still go through. Likewise, a recipient with no
# push subscription still gets the in-app bell.
class DomServis::Notifications::Dispatcher
  # Maps dispatch lifecycle events to human-readable online notification
  # type names. These become TypeLookup entries in Zammad's notification
  # vocabulary and are shown in the notification dropdown.
  NOTIFICATION_TYPES = {
    new_pool_job:        'create',           # a job entered the shared pool
    assigned_to_you:     'Assigned to you',  # a job was assigned to this master
    job_taken:           'update',           # someone claimed a pool job
    job_released:        'update',           # a claimed job was returned to pool
    job_unclaimed:       'reminder_reached', # escalation: still in pool past the deadline
    job_cancelled:       'update',
    job_done:            'update',
  }.freeze

  def initialize(job:, event_type:, recipients:, actor: nil)
    @job = job
    @event_type = event_type.to_sym
    @recipients = Array(recipients)
    @actor = actor
  end

  attr_reader :job, :event_type, :recipients, :actor

  def deliver
    return if recipients.blank?

    recipients.each do |user|
      deliver_in_app(user)
      deliver_web_push(user)
    end
  end

  private

  def deliver_in_app(user)
    OnlineNotification.add(
      type:          online_notification_type,
      object:        'DomServis::DispatchJob',
      o_id:          job.id,
      seen:          false,
      user_id:       user.id,
      created_by_id: actor&.id || job.created_by_id || 1,
      updated_by_id: actor&.id || job.updated_by_id || 1,
    )
  rescue => e
    # OnlineNotification failures must not break the dispatch flow.
    Rails.logger.warn("[dom_servis.notifications] in-app delivery failed for user=#{user.id} job=#{job.id}: #{e.class}: #{e.message}")
  end

  def deliver_web_push(user)
    subscriptions = DomServis::PushSubscription.active.for_user(user)
    return if subscriptions.blank?

    payload = push_payload_for(user)

    subscriptions.each do |subscription|
      DomServis::Notifications::WebPushDeliveryJob
        .perform_later(subscription, payload)
    end
  rescue => e
    Rails.logger.warn("[dom_servis.notifications] web push enqueue failed for user=#{user.id} job=#{job.id}: #{e.class}: #{e.message}")
  end

  def push_payload_for(user)
    {
      title: push_title,
      body:  push_body(user),
      url:   "/dispatch/",
      tag:   "dom-servis-job-#{job.id}",
    }
  end

  def push_title
    case event_type
    when :new_pool_job, :job_released
      'Новая заявка в пуле'
    when :assigned_to_you
      'Вам назначена заявка'
    when :job_unclaimed
      'Заявка без исполнителя'
    when :job_cancelled
      'Заявка отменена'
    when :job_done
      'Заявка выполнена'
    else
      'Обновление заявки'
    end
  end

  def push_body(user)
    parts = [job.service_type, job.address].compact_blank
    parts << job.job_code if job.job_code.present?

    case event_type
    when :new_pool_job, :job_released
      parts.unshift('Взять заявку:')
    when :assigned_to_you
      parts.unshift('Открыть:')
    when :job_unclaimed
      parts.unshift('Срочно нужен исполнитель:')
    end

    parts.join(' · ')
  end

  def online_notification_type
    NOTIFICATION_TYPES.fetch(event_type, 'update')
  end

  # Returns the users who hold any of the given Dom-Servis permission keys
  # and are active. Used by callers to resolve recipient lists.
  def self.recipients_for_permissions(*permission_keys)
    role_ids = Role.with_permissions(permission_keys.flatten).pluck(:id)
    return User.none if role_ids.blank?

    User.joins(:roles).where(roles: { id: role_ids }, users: { active: true }).distinct
  end
end
