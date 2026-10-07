# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Notifications::WebPushSender do
  subject(:sender) { described_class.new(subscription:, payload: { title: 'Новая заявка на стенде' }) }

  let(:subscription) do
    DomServis::PushSubscription.create!(
      user:       create(:agent),
      endpoint:   'https://fcm.googleapis.com/fcm/send/abc',
      p256dh_key: 'p256dh',
      auth_key:   'auth',
      active:     true,
    )
  end

  def http_response(klass, code)
    response = klass.new('1.1', code, '')
    allow(response).to receive(:body).and_return('')
    response
  end

  before do
    Setting.set('dom_servis_webpush_vapid_public_key', 'public')
    Setting.set('dom_servis_webpush_vapid_private_key', 'private')
  end

  it 'sends a high urgency message so FCM does not hold it while Android is in Doze' do
    allow(WebPush).to receive(:payload_send)

    expect(sender.deliver).to eq(:delivered)
    expect(WebPush).to have_received(:payload_send).with(
      hash_including(
        message:  { title: 'Новая заявка на стенде' }.to_json,
        endpoint: 'https://fcm.googleapis.com/fcm/send/abc',
        urgency:  'high',
        ttl:      described_class::DEFAULT_TTL,
      )
    )
  end

  it 'deactivates a subscription the push service reports as expired' do
    allow(WebPush).to receive(:payload_send)
      .and_raise(WebPush::ExpiredSubscription.new(http_response(Net::HTTPGone, '410'), 'fcm.googleapis.com'))

    expect(sender.deliver).to eq(:expired)
    expect(subscription.reload.active).to be(false)
  end

  it 'keeps the subscription on a temporary push service error' do
    allow(WebPush).to receive(:payload_send)
      .and_raise(WebPush::ResponseError.new(http_response(Net::HTTPServiceUnavailable, '503'), 'fcm.googleapis.com'))

    expect(sender.deliver).to eq(:failed)
    expect(subscription.reload.active).to be(true)
  end

  it 'does not call the push service without VAPID keys' do
    Setting.set('dom_servis_webpush_vapid_private_key', '')
    allow(WebPush).to receive(:payload_send)

    expect(sender.deliver).to eq(:failed)
    expect(WebPush).not_to have_received(:payload_send)
  end
end
