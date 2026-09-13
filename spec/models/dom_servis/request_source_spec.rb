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
end
