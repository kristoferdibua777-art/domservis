# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# REST endpoint for browsers to register/unregister Web Push subscriptions
# against the Dom-Servis dispatch board.
#
# The browser calls these after the user grants notification permission and
# `pushManager.subscribe(...)` resolves a PushSubscription object. We persist
# one row per subscription so the backend can fan out push messages to every
# device a master has registered.
class DomServis::PushSubscriptionsController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  # POST /api/v1/dom_servis/push_subscriptions
  #
  # Body (form-encoded or JSON):
  #   endpoint        - push service URL (required)
  #   keys.p256dh     - client ECDH P-256 public key (required)
  #   keys.auth       - client auth secret (required)
  #   expiration_time - optional ISO 8601 timestamp
  def create
    attributes = subscription_attributes

    subscription = DomServis::PushSubscription.find_or_initialize_by(endpoint: attributes[:endpoint])
    is_new_record = subscription.new_record?

    subscription.assign_attributes(
      user_id:         current_user.id,
      p256dh_key:      attributes[:p256dh_key],
      auth_key:        attributes[:auth_key],
      expiration_time: attributes[:expiration_time],
      user_agent:      request.user_agent,
      active:          true,
    )

    authorize subscription, :create?

    if subscription.valid?
      subscription.save!

      render json: { status: 'ok', id: subscription.id }, status: (is_new_record ? :created : :ok)
    else
      raise Exceptions::UnprocessableEntity, subscription.errors.full_messages.to_sentence
    end
  end

  # DELETE /api/v1/dom_servis/push_subscriptions/:id
  def destroy
    subscription = DomServis::PushSubscription.find_by(id: params[:id])
    raise Exceptions::UnprocessableEntity, 'Unknown push subscription.' if subscription.blank?

    authorize subscription, :destroy?

    subscription.destroy!
    render json: { status: 'ok' }
  end

  # POST /api/v1/dom_servis/push_subscriptions/test
  #
  # Sends a test push notification to every active subscription owned by
  # the current user, so they can verify the channel works end-to-end.
  def test
    subscriptions = DomServis::PushSubscription.active.for_user(current_user)
    raise Exceptions::UnprocessableEntity, 'No active push subscriptions found for your user.' if subscriptions.blank?

    payload = {
      title: 'Дом-Сервис',
      body:  'Тестовое уведомление. Если вы видите это — пуши работают.',
      url:   '/dispatch/',
      tag:   'dom-servis-test',
    }

    subscriptions.each do |subscription|
      DomServis::Notifications::WebPushDeliveryJob.perform_later(subscription, payload)
    end

    render json: { status: 'ok', sent_to: subscriptions.size }
  end

  private

  # Normalizes the incoming PushSubscription payload (as produced by the
  # browser Push API) into a flat attribute hash.
  def subscription_attributes
    raw_keys = params[:keys].presence || {}
    raw_keys = raw_keys.permit! if raw_keys.respond_to?(:permit!)

    {
      endpoint:        params[:endpoint].presence,
      p256dh_key:      raw_keys[:p256dh].presence || params[:p256dh_key].presence,
      auth_key:        raw_keys[:auth].presence || params[:auth_key].presence,
      expiration_time: parse_expiration(params[:expiration_time].presence),
    }.tap do |attrs|
      raise Exceptions::UnprocessableEntity, 'Push subscription endpoint is required.' if attrs[:endpoint].blank?
      raise Exceptions::UnprocessableEntity, 'Push subscription p256dh key is required.' if attrs[:p256dh_key].blank?
      raise Exceptions::UnprocessableEntity, 'Push subscription auth key is required.' if attrs[:auth_key].blank?
    end
  end

  def parse_expiration(value)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
