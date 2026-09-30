# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'DomServis::Dispatch::HistoryExportsController', :aggregate_failures, authenticated_as: :admin, type: :request do
  let(:exports_url) { '/api/v1/dom_servis/dispatch/history_exports' }

  # Zammad's 'Admin' role alone does not carry 'dom_servis.admin'; see the
  # same setup in spec/requests/dom_servis/dispatch/jobs_controller_spec.rb.
  let(:admin) do
    create(:admin).tap do |user|
      admin_role = Role.find_by(name: 'Dom-Servis Admin')
      user.roles << admin_role if admin_role && !user.roles.exists?(admin_role.id)
    end
  end

  let(:dispatcher_user) do
    create(:agent).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Dispatcher')
    end
  end

  let(:job) do
    DomServis::DispatchJob.create!(
      service_type: 'Boiler repair',
      address:      'Lenina 10',
      client_phone: '+79001234567',
      visit_day:    'mon',
      visit_date:   '2026-03-23',
      priority:     'medium',
      status:       'pool',
      source:       'manual',
    )
  end

  let(:created_event)  { DomServis::DispatchEvent.create!(dispatch_job: job, event_type: 'created', meta: { source: 'manual' }) }
  let(:priority_event) { DomServis::DispatchEvent.create!(dispatch_job: job, event_type: 'priority_changed', meta: { from: 'medium', to: 'high' }) }

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
    created_event
    priority_event
  end

  def export_and_download
    post exports_url, as: :json
    export_id = json_response['id']

    get "#{exports_url}/#{export_id}/download"

    export_id
  end

  describe 'GET /api/v1/dom_servis/dispatch/history_exports' do
    it 'reports the stored history and no reminder for fresh events' do
      get exports_url, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('event_count' => 2, 'due' => false, 'reminder_days' => 30, 'last_export' => nil)
    end

    it 'reminds when the history was not exported for 30 days' do
      travel 31.days

      get exports_url, as: :json

      expect(json_response['due']).to be(true)
    end

    it 'counts the reminder from the last downloaded export' do
      travel 20.days
      export_and_download
      travel 20.days

      get exports_url, as: :json

      expect(json_response['due']).to be(false)
      expect(json_response['last_export']).to include('event_count' => 2, 'purgeable' => true)
    end
  end

  describe 'export, download and purge' do
    it 'removes exactly the downloaded events once the admin allows it' do
      export_id = export_and_download

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq(ExcelSheet::CONTENT_TYPE)
      expect(response.headers['Content-Disposition']).to include('dom-servis-history-')
      expect(response.body).to start_with('PK')

      later_event = DomServis::DispatchEvent.create!(dispatch_job: job, event_type: 'comment_added', meta: { comment: 'Later' })

      post "#{exports_url}/#{export_id}/purge", as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('purged_count' => 2, 'purged_by_name' => admin.fullname, 'purgeable' => false)
      expect(DomServis::DispatchEvent.pluck(:id)).to eq([later_event.id])
    end

    it 'does not remove anything before the file was downloaded' do
      post exports_url, as: :json
      post "#{exports_url}/#{json_response['id']}/purge", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(DomServis::DispatchEvent.count).to eq(2)
    end

    it 'does not remove anything when the downloaded history changed' do
      export_id = export_and_download
      created_event.destroy!

      post "#{exports_url}/#{export_id}/purge", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(DomServis::DispatchEvent.pluck(:id)).to eq([priority_event.id])
    end

    it 'does not purge an export twice' do
      export_id = export_and_download
      post "#{exports_url}/#{export_id}/purge", as: :json
      post "#{exports_url}/#{export_id}/purge", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'refuses an export without history' do
      DomServis::DispatchEvent.delete_all

      post exports_url, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(DomServis::DispatchHistoryExport.count).to eq(0)
    end
  end

  context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
    it 'forbids the history export' do
      get exports_url, as: :json
      expect(response).to have_http_status(:forbidden)

      post exports_url, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(DomServis::DispatchHistoryExport.count).to eq(0)
    end
  end

  describe 'GET /api/v1/dom_servis/dispatch/policy' do
    it 'tells an admin when the history export is due' do
      travel 31.days

      get '/api/v1/dom_servis/dispatch/policy', as: :json

      expect(json_response['history_export_due']).to be(true)
    end

    context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
      it 'does not mention the history export' do
        travel 31.days

        get '/api/v1/dom_servis/dispatch/policy', as: :json

        expect(response).to have_http_status(:ok)
        expect(json_response).not_to have_key('history_export_due')
      end
    end
  end
end
