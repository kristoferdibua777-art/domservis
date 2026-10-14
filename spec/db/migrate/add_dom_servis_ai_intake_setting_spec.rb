# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe AddDomServisAiIntakeSetting, type: :db_migration do
  let(:name) { 'dom_servis_ai_intake_config' }

  it 'finds the setting already created by the seeds of a fresh install' do
    expect(Setting.exists?(name:)).to be(true)
  end

  context 'when a set-up system lacks the setting' do
    before do
      Setting.where(name:).destroy_all
    end

    it 'creates it for Dom-Servis admins only', :aggregate_failures do
      expect { migrate }.to change { Setting.exists?(name:) }.from(false).to(true)
      expect(Setting.find_by(name:)).to have_attributes(frontend: false, preferences: include(permission: ['dom_servis.admin']))
    end
  end

  context 'when the setting holds a key' do
    it 'keeps it' do
      DomServis::Intake::AiSettings.update!('enabled' => true, 'auth_key' => 'a2V5OnNlY3JldGtleTEyMzQ=')

      migrate

      expect(DomServis::Intake::AiSettings.current.auth_key).to eq('a2V5OnNlY3JldGtleTEyMzQ=')
    end
  end

  it 'is left out of the system report' do
    expect(SystemReport::Plugin::Setting.new.fetch.pluck(:name)).not_to include(name)
  end
end
