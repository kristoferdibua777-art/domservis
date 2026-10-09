# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::PushSubscription do
  describe '#stale?' do
    subject(:subscription) { described_class.new(active: true) }

    it 'is not stale without a response status' do
      expect(subscription.stale?).to be(false)
    end

    it 'is stale when the push service reports the endpoint gone or expired', :aggregate_failures do
      expect(subscription.stale?(response_status: 404)).to be(true)
      expect(subscription.stale?(response_status: '410')).to be(true)
    end

    it 'is not stale on a temporary push service error' do
      expect(subscription.stale?(response_status: 503)).to be(false)
    end

    it 'is stale once deactivated' do
      subscription.active = false

      expect(subscription.stale?).to be(true)
    end
  end
end
