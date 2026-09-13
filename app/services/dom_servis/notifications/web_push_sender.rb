# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Delivers a single Web Push message to one stored subscription.
#
# Wraps the `web-push` gem (RFC 8291 + VAPID) and translates push-service
# failures into subscription deactivation so stale endpoints are not
# retried forever. Instances are single-use: one payload, one
# subscription, one delivery attempt.
class DomServis::Notifications::WebPushSender
  class ConfigurationError < StandardError; end

  # Default Time-To-Live for a push message (seconds). The push service
  # stores the message for this long if the device is offline.
  DEFAULT_TTL = 241_920 # 28 days

  def initialize(subscription:, payload:)
    @subscription = subscription
    @payload = payload
  end

  attr_reader :subscription, :payload

  def deliver
    ensure_configured!

    WebPush.payload_send(
      message:    serialized_payload,
      endpoint:   subscription.endpoint,
      p256dh:     subscription.p256dh_key,
      auth:       subscription.auth_key,
      vapid:      vapid_credentials,
      ttl:        DEFAULT_TTL,
      urgency:    'normal',
      ssl_timeout: 5,
      open_timeout: 5,
      read_timeout: 5,
    )

    :delivered
  rescue WebPush::ExpiredSubscription,
         WebPush::InvalidSubscription,
         WebPush::SubscriptionNotFoundError => e
    # Push service confirmed the subscription is gone. Deactivate it
    # so subsequent dispatches skip it without an HTTP round-trip.
    subscription.update!(active: false)
    Rails.logger.info("[dom_servis.web_push] deactivated stale subscription id=#{subscription.id}: #{e.class}")
    :expired
  rescue WebPush::ResponseError => e
    if e.response.is_a?(Net::HTTPResponse) && e.response.code.to_i.in?(404, 410)
      subscription.update!(active: false)
      Rails.logger.info("[dom_servis.web_push] deactivated gone subscription id=#{subscription.id}: HTTP #{e.response.code}")
      return :expired
    end

    Rails.logger.warn("[dom_servis.web_push] push service error for subscription id=#{subscription.id}: #{e.class}: #{e.message}")
    :failed
  rescue => e
    Rails.logger.error("[dom_servis.web_push] delivery failed for subscription id=#{subscription.id}: #{e.class}: #{e.message}")
    :failed
  end

  private

  def serialized_payload
    return payload.to_json if payload.is_a?(Hash)

    payload.to_s
  end

  def vapid_credentials
    {
      subject:     Setting.get('dom_servis_webpush_subject').presence || 'mailto:admin@example.com',
      public_key:  Setting.get('dom_servis_webpush_vapid_public_key'),
      private_key: Setting.get('dom_servis_webpush_vapid_private_key'),
    }
  end

  def ensure_configured!
    return if Setting.get('dom_servis_webpush_vapid_public_key').present? &&
              Setting.get('dom_servis_webpush_vapid_private_key').present?

    raise ConfigurationError, 'Dom-Servis Web Push VAPID keys are not configured. Run `rake dom_servis:webpush:generate_keys`.'
  end
end
