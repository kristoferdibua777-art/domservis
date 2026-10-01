# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe EnsureDomServisSettings, type: :db_migration do
  let(:names) do
    %w[
      dom_servis_dispatch_policy
      dom_servis_webpush_vapid_public_key
      dom_servis_webpush_vapid_private_key
      dom_servis_webpush_subject
    ]
  end

  it 'finds the settings already created by the seeds of a fresh install' do
    expect(Setting.where(name: names).pluck(:name)).to match_array(names)
  end

  context 'when a set-up system lacks the settings' do
    before do
      Setting.where(name: names).destroy_all
    end

    it 'creates them' do
      expect { migrate }.to change { Setting.where(name: names).count }.from(0).to(names.size)
    end

    it 'restricts them to Dom-Servis admins' do
      migrate

      expect(Setting.where(name: names).map { |setting| setting.preferences[:permission] }.uniq).to eq([['dom_servis.admin']])
    end
  end

  context 'when the settings exist' do
    it 'keeps their values' do
      Setting.set('dom_servis_webpush_subject', 'mailto:ops@dom-servis.example')

      migrate

      expect(Setting.get('dom_servis_webpush_subject')).to eq('mailto:ops@dom-servis.example')
    end
  end

  context 'when the system is not set up yet', system_init_done: false do
    before do
      Setting.where(name: names).destroy_all
    end

    it 'leaves the settings to the seeds' do
      expect { migrate }.not_to change { Setting.where(name: names).count }.from(0)
    end
  end
end
