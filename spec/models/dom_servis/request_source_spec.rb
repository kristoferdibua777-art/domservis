# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::RequestSource, current_user_id: 1 do
  describe '#embed_url' do
    it 'includes the embed token and a release cache bust' do
      source = described_class.create!(
        name:               'Partner A Form',
        partner_key:        'partner-a',
        transport_kind:     'zammad_form',
        status:             'paused',
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
      expect(source.embed_js_snippet).to include(url.to_json)
      expect(source.embed_js_snippet).to include('dom-servis:resize')
    end
  end

  describe '#client_form_url' do
    it 'points to the standalone client page with the source token' do
      source = described_class.create!(
        name:           'Client Link',
        partner_key:    'client-link',
        transport_kind: 'zammad_form',
        status:         'paused',
      )

      url = source.client_form_url

      expect(url).to include('/assets/form/dom-servis-client-request.html?')
      expect(url).to include("request_source_token=#{CGI.escape(source.embed_token)}")
      expect(source.attributes_with_association_ids.with_indifferent_access[:client_form_url]).to eq(url)
    end
  end
end
