# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'
require 'models/contexts/factory_context'

RSpec.describe 'DomServis::Dispatch::JobsController', authenticated_as: :admin, type: :request, current_user_id: 1 do
  include_context 'factory'

  # The 'factory' shared context (spec/models/contexts/factory_context.rb)
  # adds a bare `it 'saves successfully' do expect(subject).to be_persisted
  # end` and relies on the describing spec to define what `subject` is. This
  # describe block names the controller as a String (not a class), so there
  # is no implicit `described_class` to build one from - `job` below (via
  # `DomServis::DispatchJob.create!`) is what this file already treats as
  # its one canonical persisted record, so it doubles as `subject` here,
  # mirroring the explicit-subject pattern used by the other consumers of
  # this shared context (e.g. spec/models/knowledge_base/locale_spec.rb's
  # `subject { create(:knowledge_base_locale) }`).
  subject { job }

  before do
    Organization.find_or_create_by!(name: 'Частный заказ')
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
    allow_any_instance_of(DomServis::Dispatch::JobsController).to receive(:sync_backing_ticket!).and_return(true)
  end

  # `authenticated_as: :admin` above resolves via `send(:admin)`
  # (spec/support/authenticated_as.rb), which requires this file to define
  # its own `admin` - there is no repository-wide default (confirmed against
  # the many other specs that each define their own `let(:admin)`, e.g.
  # spec/requests/api_auth_spec.rb). A bare `create(:admin)` is also not
  # enough here on its own: Zammad's built-in 'Admin' role does not carry
  # 'dom_servis.admin' by itself (see
  # db/migrate/20260318214000_create_dom_servis_admin_permission.rb - that
  # permission is granted only to the dedicated 'Dom-Servis Admin' overlay
  # role). Without it, DomServis::DispatchPolicy.role_key_for falls through
  # to its 'master' default, and the controller actions this file exercises
  # (assign -> 'change_assignee', status -> 'transferred_to_partner') are
  # only granted to the 'dispatcher'/'admin' role keys, not 'master' - so
  # requests below would get 403 instead of the expected 200. Mirrors the
  # same explicit-role-assignment pattern already used for `master_user`/
  # `other_master_user` below.
  let(:admin) do
    create(:admin).tap do |user|
      admin_role = Role.find_by(name: 'Dom-Servis Admin')
      user.roles << admin_role if admin_role && !user.roles.exists?(admin_role.id)
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
