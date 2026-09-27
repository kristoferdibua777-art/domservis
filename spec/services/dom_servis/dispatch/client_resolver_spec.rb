# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Dispatch::ClientResolver do
  let(:operator) { create(:agent) }

  describe '.normalize_phone' do
    it 'normalizes common Russian phone representations', :aggregate_failures do
      expect(described_class.normalize_phone('8 (900) 123-45-67')).to eq('+79001234567')
      expect(described_class.normalize_phone('900 123 45 67')).to eq('+79001234567')
      expect(described_class.normalize_phone('+7 900 123 45 67')).to eq('+79001234567')
      expect(described_class.normalize_phone('0049 30 123456')).to eq('+4930123456')
    end

    it 'preserves explicit international country codes', :aggregate_failures do
      expect(described_class.normalize_phone('+81 (90) 123-4567')).to eq('+81901234567')
      expect(described_class.normalize_phone('0081 (90) 123-4567')).to eq('+81901234567')
    end

    it 'rejects text, extensions and malformed prefixes instead of discarding them', :aggregate_failures do
      expect(described_class.normalize_phone('text79001234567')).to be_nil
      expect(described_class.normalize_phone('+79001234567 ext 12')).to be_nil
      expect(described_class.normalize_phone('7+9001234567')).to be_nil
      expect(described_class.normalize_phone('+0079001234567')).to be_nil
    end
  end

  describe '#resolve!' do
    it 'creates an active customer user with the normalized phone', :aggregate_failures do
      customer = described_class.new(name: 'Ivan Petrov', phone: '8 (900) 123-45-67', operator:).resolve!

      expect(customer).to have_attributes(
        firstname: 'Ivan',
        lastname:  'Petrov',
        phone:     '+79001234567',
        active:    true,
      )
      expect(customer.roles).to include(Role.find_by!(name: 'Customer'))
    end

    it 'reuses the one exact normalized match and ensures the customer role', :aggregate_failures do
      existing = create(:agent, mobile: '+7 (900) 123-45-67')

      customer = described_class.new(name: 'Snapshot Name', phone: '89001234567', operator:).resolve!

      expect(customer).to eq(existing)
      expect(customer.roles).to include(Role.find_by!(name: 'Customer'))
      expect(customer.firstname).not_to eq('Snapshot Name')
    end

    it 'rejects ambiguous exact matches without merging users' do
      create(:customer, phone: '+7 900 123-45-67')
      create(:customer, mobile: '8 (900) 123-45-67')

      resolver = described_class.new(name: 'Ivan Petrov', phone: '89001234567', operator:)

      expect { resolver.resolve! }
        .to raise_error(Exceptions::UnprocessableEntity, %r{More than one user})
    end

    it 'does not fuzzy-match a different phone number', :aggregate_failures do
      existing = create(:customer, phone: '+79001234567')

      customer = described_class.new(name: 'New Client', phone: '+79111234567', operator:).resolve!

      expect(customer).not_to eq(existing)
      expect(customer.phone).to eq('+79111234567')
    end

    it 'does not select a different customer by rewriting an international country code', :aggregate_failures do
      existing = create(:customer, phone: '+71901234567')

      customer = described_class.new(name: 'International Client', phone: '+81901234567', operator:).resolve!

      expect(customer).not_to eq(existing)
      expect(customer.phone).to eq('+81901234567')
    end

    it 'rejects a phone that cannot be normalized' do
      resolver = described_class.new(name: 'Ivan Petrov', phone: '12345', operator:)

      expect { resolver.resolve! }
        .to raise_error(Exceptions::UnprocessableEntity, %r{valid client phone})
    end
  end
end
