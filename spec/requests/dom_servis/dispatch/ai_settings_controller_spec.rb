# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'DomServis::Dispatch::AISettingsController', type: :request do
  # Zammad's 'Admin' role alone does not carry 'dom_servis.admin'; see the
  # same setup in spec/requests/dom_servis/dispatch/jobs_controller_spec.rb.
  let(:admin) do
    create(:admin).tap do |user|
      admin_role = Role.find_by(name: 'Dom-Servis Admin')
      user.roles << admin_role if admin_role && !user.roles.exists?(admin_role.id)
    end
  end

  let(:dispatcher) do
    create(:agent).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Dispatcher')
    end
  end

  let(:auth_key) { 'a2V5OnNlY3JldGtleTEyMzQ=' }

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
  end

  context 'when logged in as a Dom-Servis admin', authenticated_as: :admin do
    it 'starts switched off without a key' do
      get '/api/v1/dom_servis/dispatch/ai_settings', as: :json

      expect(json_response).to include('enabled' => false, 'auth_key_set' => false, 'scope' => 'GIGACHAT_API_PERS', 'model' => 'GigaChat-2-Pro')
    end

    it 'stores the key without sending it back', :aggregate_failures do
      put '/api/v1/dom_servis/dispatch/ai_settings', params: { enabled: true, auth_key: " #{auth_key} ", scope: 'GIGACHAT_API_B2B', model: 'GigaChat-2' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('enabled' => true, 'auth_key_set' => true, 'scope' => 'GIGACHAT_API_B2B', 'model' => 'GigaChat-2')
      expect(response.body).not_to include(auth_key)
      expect(DomServis::Intake::AISettings.current).to have_attributes(auth_key: auth_key, usable?: true)
    end

    it 'keeps the saved key when none is sent and removes it on request', :aggregate_failures do
      DomServis::Intake::AISettings.update!('enabled' => true, 'auth_key' => auth_key)

      put '/api/v1/dom_servis/dispatch/ai_settings', params: { enabled: true, model: 'GigaChat-2-Max' }, as: :json
      expect(DomServis::Intake::AISettings.current).to have_attributes(auth_key: auth_key, model: 'GigaChat-2-Max')

      put '/api/v1/dom_servis/dispatch/ai_settings', params: { clear_auth_key: true }, as: :json
      expect(DomServis::Intake::AISettings.current).to have_attributes(auth_key: '', enabled?: false)
    end

    it 'rejects an unknown access type' do
      put '/api/v1/dom_servis/dispatch/ai_settings', params: { scope: 'SOMETHING' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'reports a failed connection check' do
      DomServis::Intake::AISettings.update!('enabled' => true, 'auth_key' => auth_key)
      allow_any_instance_of(DomServis::Intake::GigachatClient).to receive(:models).and_raise(DomServis::Intake::AIError, 'Не удалось связаться с GigaChat.')

      post '/api/v1/dom_servis/dispatch/ai_settings/check', as: :json

      expect(json_response).to eq('ok' => false, 'error' => 'Не удалось связаться с GigaChat.')
    end

    it 'reports the models of a working connection' do
      DomServis::Intake::AISettings.update!('enabled' => true, 'auth_key' => auth_key)
      allow_any_instance_of(DomServis::Intake::GigachatClient).to receive(:models).and_return(%w[GigaChat-2 GigaChat-2-Pro])

      post '/api/v1/dom_servis/dispatch/ai_settings/check', as: :json

      expect(json_response).to eq('ok' => true, 'models' => %w[GigaChat-2 GigaChat-2-Pro], 'model_available' => true)
    end
  end

  context 'when logged in as a dispatcher', authenticated_as: :dispatcher do
    it 'does not show the settings' do
      get '/api/v1/dom_servis/dispatch/ai_settings', as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
