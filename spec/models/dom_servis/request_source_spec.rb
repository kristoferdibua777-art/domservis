# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::RequestSource do
  describe '#embed_url' do
    it 'includes the embed token and a release cache bust' do
      source = described_class.create!(
        name:           'Partner A Form',
        partner_key:    'partner-a',
        transport_kind: 'zammad_form',
        status:         'paused',
        privacy_policy_url: 'https://partner-a.example.com/privacy',
      )

      allow(Version).to receive(:get).and_return('7.1.x-4e27e342.docker')

      url = source.embed_url

      expect(url).to include('request_source_token=')
      expect(url).to include(source.embed_token)
      expect(url).to include(CGI.escape('https://partner-a.example.com/privacy'))
      expect(url).to include('v=7.1.x-4e27e342.docker')
      expect(source.embed_snippet).to include(CGI.escapeHTML(url))
      expect(source.embed_snippet).to include('data-dom-servis-partner-embed="true"')
      expect(source.embed_snippet).to include('dom-servis:resize')
      expect(source.embed_snippet).to include('height: 640px')
      expect(source.embed_js_snippet).to include(url)
      expect(source.embed_js_snippet).to include('dom-servis:resize')
    end
  end

  describe '#public_embed_id' do
    it 'is generated automatically on create' do
      source = described_class.create!(
        name:        'Partner B',
        partner_key: 'partner-b',
        status:      'paused',
      )

      expect(source.public_embed_id).to be_present
    end

    it 'is unique across request sources' do
      described_class.create!(
        name:            'Partner C',
        partner_key:     'partner-c',
        status:          'paused',
        public_embed_id: 'fixed-value',
      )

      duplicate = described_class.new(
        name:            'Partner D',
        partner_key:     'partner-d',
        status:          'paused',
        public_embed_id: 'fixed-value',
      )

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:public_embed_id]).to be_present
    end

    it 'is left untouched on update once already present' do
      source = described_class.create!(
        name:        'Partner E',
        partner_key: 'partner-e',
        status:      'paused',
      )
      original = source.public_embed_id

      source.update!(name: 'Partner E Renamed')

      expect(source.public_embed_id).to eq(original)
    end
  end

  describe '#credential_version' do
    it 'defaults to 1' do
      source = described_class.create!(
        name:        'Partner F',
        partner_key: 'partner-f',
        status:      'paused',
      )

      expect(source.credential_version).to eq(1)
    end

    it 'rejects a non-positive value' do
      source = described_class.new(
        name:              'Partner G',
        partner_key:       'partner-g',
        status:            'paused',
        credential_version: 0,
      )

      expect(source).not_to be_valid
      expect(source.errors[:credential_version]).to be_present
    end
  end

  describe '#rate_limit_config' do
    it 'accepts a well-formed configuration' do
      source = described_class.new(
        name:             'Partner H',
        partner_key:      'partner-h',
        status:           'paused',
        rate_limit_config: { 'per_minute' => 30, 'burst' => 10 },
      )

      expect(source).to be_valid
    end

    it 'rejects an unknown key' do
      source = described_class.new(
        name:             'Partner I',
        partner_key:      'partner-i',
        status:           'paused',
        rate_limit_config: { 'unknown_key' => 1 },
      )

      expect(source).not_to be_valid
      expect(source.errors[:rate_limit_config]).to be_present
    end

    it 'rejects a negative value' do
      source = described_class.new(
        name:             'Partner J',
        partner_key:      'partner-j',
        status:           'paused',
        rate_limit_config: { 'per_minute' => -1 },
      )

      expect(source).not_to be_valid
      expect(source.errors[:rate_limit_config]).to be_present
    end
  end

  describe 'status' do
    it 'accepts revoked as a valid status' do
      source = described_class.new(
        name:        'Partner K',
        partner_key: 'partner-k',
        status:      'revoked',
      )

      expect(source).to be_valid
    end

    it 'treats a revoked source as paused (not usable for intake)' do
      source = described_class.new(status: 'revoked')

      expect(source.paused?).to be(true)
      expect(source.active?).to be(false)
    end

    describe '#revoked?' do
      it 'is true only for the revoked status' do
        expect(described_class.new(status: 'revoked').revoked?).to be(true)
        expect(described_class.new(status: 'active').revoked?).to be(false)
        expect(described_class.new(status: 'paused').revoked?).to be(false)
      end
    end
  end
end
