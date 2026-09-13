# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'
require 'models/contexts/factory_context'

RSpec.describe 'DomServis::Dispatch::JobsController', authenticated_as: :admin, type: :request do
  include_context 'factory'

  let!(:private_organization) { Organization.find_or_create_by!(name: 'Частный заказ') }

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

  let(:master_user) do
    create(:agent).tap do |user|
      master_role = Role.find_by(name: 'Dom-Servis Master')
      user.roles << master_role if master_role && !user.roles.exists?(master_role.id)
    end
  end

  let(:other_master_user) do
    create(:agent).tap do |user|
      master_role = Role.find_by(name: 'Dom-Servis Master')
      user.roles << master_role if master_role && !user.roles.exists?(master_role.id)
    end
  end

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
    allow_any_instance_of(DomServis::Dispatch::JobsController).to receive(:sync_backing_ticket!).and_return(true)
  end

  describe 'POST /api/v1/dom_servis/dispatch/jobs/:id/assign' do
    it 'assigns a master and turns a pool job into taken' do
      post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/assign", params: { assignee_id: master_user.id }, as: :json

      expect(response).to have_http_status(:ok)

      job.reload

      expect(job.assignee_id).to eq(master_user.id)
      expect(job.status).to eq('taken')
      expect(job.taken_at).to be_present
      expect(job.events.last.event_type).to eq('assigned')
    end

    context 'when logged in as a master', authenticated_as: -> { master_user } do
      it 'does not allow assigning other masters' do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/assign", params: { assignee_id: other_master_user.id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /api/v1/dom_servis/dispatch/jobs/:id' do
    it 'rejects raw assignee changes through the generic update endpoint' do
      put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { assignee_id: master_user.id }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(job.reload.assignee_id).to be_nil
    end
  end

  describe 'POST /api/v1/dom_servis/dispatch/jobs/:id/status' do
    it 'allows closing the job as transferred to partner' do
      post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/status", params: { status: 'transferred_to_partner' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(job.reload.status).to eq('transferred_to_partner')
      expect(job.events.last.event_type).to eq('status_changed')
      expect(job.events.last.meta['to']).to eq('transferred_to_partner')
    end
  end
end
