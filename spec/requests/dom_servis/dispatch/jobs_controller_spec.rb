# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'
require 'models/contexts/factory_context'

RSpec.describe 'DomServis::Dispatch::JobsController', authenticated_as: :admin, current_user_id: 1, type: :request do
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

  include_context 'factory'

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

  let(:dispatcher_user) do
    create(:agent).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Dispatcher')
    end
  end

  def create_dispatch_job(status:, assignee: nil)
    DomServis::DispatchJob.create!(
      service_type: 'Boiler repair',
      address:      'Lenina 10',
      client_phone: '+79001234567',
      visit_day:    'mon',
      visit_date:   '2026-03-23',
      priority:     'medium',
      source:       'manual',
      status:       status,
      assignee:     assignee,
    )
  end

  def post_status(dispatch_job, status)
    post "/api/v1/dom_servis/dispatch/jobs/#{dispatch_job.id}/status", params: { status: status }, as: :json
  end

  describe 'POST /api/v1/dom_servis/dispatch/jobs', authenticated_as: :dispatcher_user do
    let(:create_params) do
      {
        service_type: 'Boiler repair',
        address:      'Lenina 10',
        client_phone: '+79001234567',
        visit_day:    'mon',
        visit_date:   '2026-03-23',
        priority:     'medium',
        status:       'pool',
      }
    end

    it 'creates the job unassigned in the pool', :aggregate_failures do
      post '/api/v1/dom_servis/dispatch/jobs', params: create_params, as: :json

      expect(response).to have_http_status(:created)

      created_job = DomServis::DispatchJob.find(json_response['id'])
      expect(created_job).to have_attributes(status: 'pool', assignee_id: nil)
      expect(created_job.events.pluck(:event_type)).to include('created', 'published')
    end

    it 'rejects a master passed on create', :aggregate_failures do
      assignee_id = master_user.id

      expect { post '/api/v1/dom_servis/dispatch/jobs', params: create_params.merge(assignee_id:), as: :json }.not_to change(DomServis::DispatchJob, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a status other than pool on create', :aggregate_failures do
      expect { post '/api/v1/dom_servis/dispatch/jobs', params: create_params.merge(status: 'taken'), as: :json }.not_to change(DomServis::DispatchJob, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects lifecycle timestamps on create', :aggregate_failures do
      expect { post '/api/v1/dom_servis/dispatch/jobs', params: create_params.merge(taken_at: '2026-03-23T10:00:00Z'), as: :json }.not_to change(DomServis::DispatchJob, :count)
      expect(response).to have_http_status(:unprocessable_entity)
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

    it 'does not assign a master to a closed job', :aggregate_failures do
      closed_job = create_dispatch_job(status: 'closed', assignee: master_user)

      post "/api/v1/dom_servis/dispatch/jobs/#{closed_job.id}/assign", params: { assignee_id: other_master_user.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(closed_job.reload.assignee_id).to eq(master_user.id)
    end

    context 'when logged in as a master', authenticated_as: -> { master_user } do
      it 'does not allow assigning other masters' do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/assign", params: { assignee_id: other_master_user.id }, as: :json

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /api/v1/dom_servis/dispatch/jobs/:id/take', authenticated_as: -> { master_user } do
    it 'takes a pool job', :aggregate_failures do
      post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/take", as: :json

      expect(response).to have_http_status(:ok)
      expect(job.reload).to have_attributes(status: 'taken', assignee_id: master_user.id)
    end

    it 'treats taking an own job again as a no-op', :aggregate_failures do
      own_job = create_dispatch_job(status: 'in_progress', assignee: master_user)

      post "/api/v1/dom_servis/dispatch/jobs/#{own_job.id}/take", as: :json

      expect(response).to have_http_status(:ok)
      expect(own_job.reload.status).to eq('in_progress')
    end

    context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
      it 'does not take a job outside the pool', :aggregate_failures do
        cancelled_job = create_dispatch_job(status: 'cancelled')

        post "/api/v1/dom_servis/dispatch/jobs/#{cancelled_job.id}/take", as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(cancelled_job.reload).to have_attributes(status: 'cancelled', assignee_id: nil)
      end
    end
  end

  describe 'POST /api/v1/dom_servis/dispatch/jobs/:id/release', authenticated_as: -> { master_user } do
    it 'returns a taken job to the pool without its master', :aggregate_failures do
      taken_job = create_dispatch_job(status: 'taken', assignee: master_user)

      post "/api/v1/dom_servis/dispatch/jobs/#{taken_job.id}/release", as: :json

      expect(response).to have_http_status(:ok)
      expect(taken_job.reload).to have_attributes(status: 'pool', assignee_id: nil, taken_at: nil)
    end

    it 'does not release finished work', :aggregate_failures do
      done_job = create_dispatch_job(status: 'done', assignee: master_user)

      post "/api/v1/dom_servis/dispatch/jobs/#{done_job.id}/release", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(done_job.reload).to have_attributes(status: 'done', assignee_id: master_user.id)
    end
  end

  describe 'PUT /api/v1/dom_servis/dispatch/jobs/:id' do
    it 'rejects raw assignee changes through the generic update endpoint' do
      put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { assignee_id: master_user.id }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(job.reload.assignee_id).to be_nil
    end

    context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
      it 'applies the workflow graph to status changes', :aggregate_failures do
        put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { status: 'done' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(job.reload.status).to eq('pool')
      end

      it 'drops the master when a job is moved back to the pool', :aggregate_failures do
        taken_job = create_dispatch_job(status: 'taken', assignee: master_user)

        put "/api/v1/dom_servis/dispatch/jobs/#{taken_job.id}", params: { status: 'pool' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(taken_job.reload).to have_attributes(status: 'pool', assignee_id: nil)
      end

      it 'requires the partner transfer action like the status endpoint', :aggregate_failures do
        allow(DomServis::DispatchPolicy).to receive(:action_allowed?).and_call_original
        allow(DomServis::DispatchPolicy).to receive(:action_allowed?).with(anything, 'transfer_to_partner').and_return(false)

        put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { status: 'transferred_to_partner' }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(job.reload.status).to eq('pool')
      end
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

    context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
      it 'does not skip the master workflow', :aggregate_failures do
        post_status(job, 'done')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(job.reload.status).to eq('pool')
      end

      it 'leaves moving a pool job to taken to the assign action', :aggregate_failures do
        post_status(job, 'taken')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(job.reload.status).to eq('pool')
      end

      it 'returns a taken job to the pool without its master', :aggregate_failures do
        taken_job = create_dispatch_job(status: 'taken', assignee: master_user)

        post_status(taken_job, 'pool')

        expect(response).to have_http_status(:ok)
        expect(taken_job.reload).to have_attributes(status: 'pool', assignee_id: nil, taken_at: nil)
      end

      it 'closes a done job', :aggregate_failures do
        done_job = create_dispatch_job(status: 'done', assignee: master_user)

        post_status(done_job, 'closed')

        expect(response).to have_http_status(:ok)
        expect(done_job.reload).to have_attributes(status: 'closed', assignee_id: master_user.id, closed_at: be_present, completed_at: be_present)
        expect(done_job.events.last.meta).to include('from' => 'done', 'to' => 'closed')
      end

      it 'reopens a closed job into the pool without its master', :aggregate_failures do
        closed_job = create_dispatch_job(status: 'closed', assignee: master_user)

        post_status(closed_job, 'pool')

        expect(response).to have_http_status(:ok)
        expect(closed_job.reload).to have_attributes(status: 'pool', assignee_id: nil, closed_at: nil)
      end

      it 'keeps a partner transfer final', :aggregate_failures do
        transferred_job = create_dispatch_job(status: 'transferred_to_partner')

        post_status(transferred_job, 'pool')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(transferred_job.reload.status).to eq('transferred_to_partner')
      end
    end

    context 'when logged in as a master', authenticated_as: -> { master_user } do
      it 'finishes the own job once it is in progress', :aggregate_failures do
        own_job = create_dispatch_job(status: 'in_progress', assignee: master_user)

        post_status(own_job, 'done')

        expect(response).to have_http_status(:ok)
        expect(own_job.reload).to have_attributes(status: 'done', completed_at: be_present)
      end

      it 'does not finish a job that was never started', :aggregate_failures do
        own_job = create_dispatch_job(status: 'taken', assignee: master_user)

        post_status(own_job, 'done')

        expect(response).to have_http_status(:unprocessable_entity)
        expect(own_job.reload.status).to eq('taken')
      end

      it 'does not close a job', :aggregate_failures do
        own_job = create_dispatch_job(status: 'done', assignee: master_user)

        post_status(own_job, 'closed')

        expect(response).to have_http_status(:forbidden)
        expect(own_job.reload.status).to eq('done')
      end
    end
  end
end
