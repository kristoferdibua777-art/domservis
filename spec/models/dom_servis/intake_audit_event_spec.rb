# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::IntakeAuditEvent do
  describe 'validations' do
    it 'requires a decision from the known vocabulary' do
      event = described_class.new(decision: 'accepted')

      expect(event).to be_valid
    end

    it 'rejects a blank decision' do
      event = described_class.new(decision: nil)

      expect(event).not_to be_valid
      expect(event.errors[:decision]).to be_present
    end

    it 'rejects a decision outside the known vocabulary' do
      event = described_class.new(decision: 'something_unexpected')

      expect(event).not_to be_valid
      expect(event.errors[:decision]).to be_present
    end
  end

  describe 'associations' do
    it 'does not require a request_source' do
      event = described_class.new(decision: 'rejected_unknown', request_source: nil)

      expect(event).to be_valid
    end

    it 'does not require an organization' do
      event = described_class.new(decision: 'rejected_unknown', organization: nil)

      expect(event).to be_valid
    end

    it 'can be associated with an existing request source' do
      source = DomServis::RequestSource.create!(
        name:        'Partner Audit',
        partner_key: 'partner-audit',
        status:      'paused',
      )

      event = described_class.create!(decision: 'accepted', request_source: source)

      expect(event.reload.request_source).to eq(source)
    end
  end

  describe '.ordered_recent' do
    it 'orders events newest first' do
      older = described_class.create!(decision: 'accepted', created_at: 2.days.ago)
      newer = described_class.create!(decision: 'accepted', created_at: 1.hour.ago)

      expect(described_class.ordered_recent.pluck(:id)).to eq([newer.id, older.id])
    end
  end
end
