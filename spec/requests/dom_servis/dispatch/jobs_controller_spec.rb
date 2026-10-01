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

  describe 'GET /api/v1/dom_servis/dispatch/jobs', authenticated_as: :dispatcher_user do
    it 'returns the backing ticket number as the job number', :aggregate_failures do
      ticket = create(:ticket)
      job.update!(ticket_id: ticket.id)

      get '/api/v1/dom_servis/dispatch/jobs?expand=true', as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.find { |item| item['id'] == job.id }).to include('ticket_id' => ticket.id, 'ticket_number' => ticket.number)

      get "/api/v1/dom_servis/dispatch/jobs/#{job.id}", as: :json

      expect(json_response).to include('ticket_number' => ticket.number)
    end

    it 'has no ticket number before the backing ticket exists', :aggregate_failures do
      get "/api/v1/dom_servis/dispatch/jobs/#{job.id}", as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).not_to have_key('ticket_number')
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
      expect(job.events.last).to have_attributes(
        event_type: 'assigned',
        meta:       { 'from' => nil, 'to' => master_user.id, 'status' => { 'from' => 'pool', 'to' => 'taken' } },
      )
    end

    it 'does not assign a master to a closed job', :aggregate_failures do
      closed_job = create_dispatch_job(status: 'closed', assignee: master_user)

      post "/api/v1/dom_servis/dispatch/jobs/#{closed_job.id}/assign", params: { assignee_id: other_master_user.id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(closed_job.reload.assignee_id).to eq(master_user.id)
    end

    context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
      it 'assigns a master', :aggregate_failures do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/assign", params: { assignee_id: master_user.id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(job.reload).to have_attributes(status: 'taken', assignee_id: master_user.id)
        expect(job.events.last).to have_attributes(event_type: 'assigned', actor_user_id: dispatcher_user.id)
      end
    end

    context 'when logged in as a master', authenticated_as: -> { master_user } do
      it 'does not allow assigning other masters', :aggregate_failures do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/assign", params: { assignee_id: other_master_user.id }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(job.reload).to have_attributes(status: 'pool', assignee_id: nil)
      end
    end
  end

  describe 'POST /api/v1/dom_servis/dispatch/jobs/:id/move_day' do
    context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
      it 'moves the job to another day of the week', :aggregate_failures do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/move_day", params: { visit_day: 'wed', visit_date: '2026-03-25' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(job.reload).to have_attributes(visit_day: 'wed', visit_date: '2026-03-25')
        expect(job.events.find_by(event_type: 'moved_weekday')).to have_attributes(actor_user_id: dispatcher_user.id, meta: { 'from' => 'mon', 'to' => 'wed' })
        expect(job.events.find_by(event_type: 'updated').meta).to eq('changes' => { 'visit_date' => { 'from' => '2026-03-23', 'to' => '2026-03-25' } })
      end

      it 'rejects a date that does not match the requested weekday', :aggregate_failures do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/move_day", params: { visit_day: 'wed', visit_date: '2026-03-26' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(job.reload).to have_attributes(visit_day: 'mon', visit_date: '2026-03-23')
        expect(job.events.where(event_type: 'moved_weekday')).to be_empty
      end
    end

    context 'when logged in as a master', authenticated_as: -> { master_user } do
      it 'does not move the job', :aggregate_failures do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/move_day", params: { visit_day: 'wed', visit_date: '2026-03-25' }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(job.reload).to have_attributes(visit_day: 'mon', visit_date: '2026-03-23')
      end
    end
  end

  describe 'POST /api/v1/dom_servis/dispatch/jobs/:id/change_priority' do
    context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
      it 'changes the priority', :aggregate_failures do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/change_priority", params: { priority: 'high' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(job.reload.priority).to eq('high')
        expect(job.events.last).to have_attributes(event_type: 'priority_changed', actor_user_id: dispatcher_user.id)
      end
    end

    context 'when logged in as a master', authenticated_as: -> { master_user } do
      it 'does not change the priority', :aggregate_failures do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/change_priority", params: { priority: 'high' }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(job.reload.priority).to eq('medium')
      end
    end
  end

  describe 'backing ticket sync failures', :aggregate_failures, authenticated_as: :dispatcher_user, performs_jobs: true do
    let(:ticket_sync) { instance_double(DomServis::Dispatch::BackingTicket::SyncFromDispatch) }

    before do
      allow_any_instance_of(DomServis::Dispatch::JobsController).to receive(:sync_backing_ticket!).and_call_original
      allow(DomServis::Dispatch::BackingTicket::SyncFromDispatch).to receive(:new).and_return(ticket_sync)
    end

    it 'keeps the change, records the failure and retries it later' do
      allow(ticket_sync).to receive(:execute).and_raise(StandardError, 'ticket store down')

      expect do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/change_priority", params: { priority: 'high' }, as: :json
      end.to have_enqueued_job(DomServis::BackingTicketResyncJob).with(job.id)

      expect(response).to have_http_status(:ok)
      expect(job.reload.priority).to eq('high')
      expect(job.ticket_sync_failed_at).to be_present
      expect(job.ticket_sync_error).to eq('StandardError: ticket store down')
      expect(json_response['ticket_sync_error']).to eq('StandardError: ticket store down')
    end

    it 'clears a recorded failure once a later sync succeeds' do
      allow(ticket_sync).to receive(:execute).and_return(true)
      job.record_ticket_sync_failure!(StandardError.new('earlier failure'))

      post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/change_priority", params: { priority: 'high' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(job.reload).to have_attributes(ticket_sync_failed_at: nil, ticket_sync_error: nil)
    end

    it 'lets a dispatcher retry the sync' do
      allow(ticket_sync).to receive(:execute).and_return(true)
      job.record_ticket_sync_failure!(StandardError.new('earlier failure'))

      post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/resync_ticket", as: :json

      expect(response).to have_http_status(:ok)
      expect(job.reload.ticket_sync_failed_at).to be_nil
    end

    it 'reports a retry that fails again' do
      allow(ticket_sync).to receive(:execute).and_raise(StandardError, 'still down')
      job.record_ticket_sync_failure!(StandardError.new('earlier failure'))

      post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/resync_ticket", as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to include('still down')
      expect(job.reload.ticket_sync_error).to eq('StandardError: still down')
    end

    context 'when logged in as a master', authenticated_as: -> { master_user } do
      it 'does not let a master retry the sync' do
        post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/resync_ticket", as: :json

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

    it 'does not let a master take a job that already left the pool', :aggregate_failures do
      own_job = create_dispatch_job(status: 'in_progress', assignee: master_user)

      post "/api/v1/dom_servis/dispatch/jobs/#{own_job.id}/take", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(own_job.reload.status).to eq('in_progress')
    end

    context 'when logged in as a dispatcher', authenticated_as: :dispatcher_user do
      it 'treats taking an own job again as a no-op', :aggregate_failures do
        own_job = create_dispatch_job(status: 'in_progress', assignee: dispatcher_user)

        post "/api/v1/dom_servis/dispatch/jobs/#{own_job.id}/take", as: :json

        expect(response).to have_http_status(:ok)
        expect(own_job.reload).to have_attributes(status: 'in_progress', assignee_id: dispatcher_user.id)
      end

      it 'does not take a job outside the pool', :aggregate_failures do
        cancelled_job = create_dispatch_job(status: 'cancelled')

        post "/api/v1/dom_servis/dispatch/jobs/#{cancelled_job.id}/take", as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(cancelled_job.reload).to have_attributes(status: 'cancelled', assignee_id: nil)
      end
    end
  end

  describe 'DELETE /api/v1/dom_servis/dispatch/jobs/:id', authenticated_as: :dispatcher_user do
    it 'keeps the history of the deleted job', :aggregate_failures do
      DomServis::DispatchEvent.create!(dispatch_job: job, actor_user: master_user, event_type: 'created', meta: { source: 'manual' })
      job_id   = job.id
      job_code = job.job_code

      delete "/api/v1/dom_servis/dispatch/jobs/#{job_id}", as: :json

      expect(response).to have_http_status(:ok)
      expect(DomServis::DispatchJob.exists?(job_id)).to be(false)

      history = DomServis::DispatchEvent.where(job_code: job_code).reorder(:id)
      expect(history.pluck(:event_type)).to eq(%w[created deleted])
      expect(history.pluck(:dispatch_job_id)).to eq([nil, nil])
      expect(history.last.actor_user_id).to eq(dispatcher_user.id)
      expect(history.last.meta).to include(
        'job_code'     => job_code,
        'status'       => 'pool',
        'service_type' => 'Boiler repair',
        'address'      => 'Lenina 10',
        'visit_date'   => '2026-03-23',
      )
    end
  end

  describe 'POST /api/v1/dom_servis/dispatch/jobs/:id/release', authenticated_as: -> { master_user } do
    it 'returns a taken job to the pool without its master', :aggregate_failures do
      taken_job = create_dispatch_job(status: 'taken', assignee: master_user)

      post "/api/v1/dom_servis/dispatch/jobs/#{taken_job.id}/release", as: :json

      expect(response).to have_http_status(:ok)
      expect(taken_job.reload).to have_attributes(status: 'pool', assignee_id: nil, taken_at: nil)
      expect(taken_job.events.find_by(event_type: 'released').meta).to eq('from' => master_user.id, 'status' => { 'from' => 'taken', 'to' => 'pool' })
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

      it 'requires schedule permission to change the visit time', :aggregate_failures do
        allow(DomServis::DispatchPolicy).to receive(:action_allowed?).and_call_original
        allow(DomServis::DispatchPolicy).to receive(:action_allowed?).with(anything, 'move_job_day').and_return(false)

        put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { visit_time: '11:30' }, as: :json

        expect(response).to have_http_status(:forbidden)
        expect(job.reload.visit_time).to be_blank
      end

      it 'rejects a non-canonical visit time', :aggregate_failures do
        put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { visit_time: '25:00' }, as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(job.reload.visit_time).to be_blank
      end

      it 'records the old and new value of every changed field', :aggregate_failures do
        put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { address: 'Lenina 12', client_name: 'Ivan Petrov', visit_time: '09:00-11:30', priority: 'high' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(job.events.pluck(:event_type)).to contain_exactly('priority_changed', 'updated')
        expect(job.events.find_by(event_type: 'priority_changed')).to have_attributes(actor_user_id: dispatcher_user.id, meta: { 'from' => 'medium', 'to' => 'high' })
        expect(job.events.find_by(event_type: 'updated')).to have_attributes(
          actor_user_id: dispatcher_user.id,
          meta:          {
            'changes' => {
              'address'     => { 'from' => 'Lenina 10', 'to' => 'Lenina 12' },
              'client_name' => { 'from' => nil, 'to' => 'Ivan Petrov' },
              'visit_time'  => { 'from' => nil, 'to' => '09:00-11:30' },
            },
          },
        )
      end

      it 'keeps the previous dispatcher comment in the history', :aggregate_failures do
        job.update!(comment: 'Call before arrival')

        put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { comment: 'Gate code 1234' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(job.events.find_by(event_type: 'comment_added').meta).to eq('comment' => 'Gate code 1234', 'from' => 'Call before arrival')
        expect(job.events.where(event_type: 'updated')).to be_empty
      end

      it 'records nothing when nothing changed', :aggregate_failures do
        put "/api/v1/dom_servis/dispatch/jobs/#{job.id}", params: { address: 'Lenina 10' }, as: :json

        expect(response).to have_http_status(:ok)
        expect(job.events).to be_empty
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
        expect(taken_job.events.find_by(event_type: 'status_changed').meta).to eq('from' => 'taken', 'to' => 'pool')
        expect(taken_job.events.find_by(event_type: 'updated').meta).to eq('changes' => { 'assignee_id' => { 'from' => master_user.id, 'to' => nil } })
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

  describe 'GET /api/v1/dom_servis/dispatch/jobs/:job_id/events', authenticated_as: :dispatcher_user do
    it 'returns the history newest first with the actor name', :aggregate_failures do
      DomServis::DispatchEvent.create!(dispatch_job: job, actor_user: master_user, event_type: 'created', meta: { source: 'manual' })
      DomServis::DispatchEvent.create!(dispatch_job: job, actor_user: dispatcher_user, event_type: 'priority_changed', meta: { from: 'medium', to: 'high' })

      get "/api/v1/dom_servis/dispatch/jobs/#{job.id}/events", as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.pluck('event_type')).to eq(%w[priority_changed created])
      expect(json_response.first).to include(
        'actor_user_id' => dispatcher_user.id,
        'actor_name'    => dispatcher_user.fullname,
        'meta'          => { 'from' => 'medium', 'to' => 'high' },
      )
      expect(json_response.last['actor_name']).to eq(master_user.fullname)
    end
  end

  describe 'GET /api/v1/dom_servis/dispatch/jobs?visit_date=', authenticated_as: :dispatcher_user do
    it 'lists only the jobs of that day', :aggregate_failures do
      day_job = job
      next_day_job = DomServis::DispatchJob.create!(
        service_type: 'Boiler repair',
        address:      'Lenina 12',
        client_phone: '+79001234568',
        visit_day:    'tue',
        visit_date:   '2026-03-24',
        priority:     'medium',
        status:       'pool',
        source:       'manual',
      )

      get '/api/v1/dom_servis/dispatch/jobs?visit_date=2026-03-23&expand=true&per_page=500', as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response.pluck('id')).to include(day_job.id)
      expect(json_response.pluck('id')).not_to include(next_day_job.id)
    end
  end
end
