# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Notifications::Dispatcher, current_user_id: 1 do
  subject(:dispatcher) { described_class.new(job:, event_type: :assigned_to_you, recipients: []) }

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

  describe 'push body' do
    it 'names the job by its backing ticket number' do
      ticket = create(:ticket)
      job.update!(ticket_id: ticket.id)

      expect(dispatcher.send(:push_body, nil)).to eq("Открыть: · Boiler repair · Lenina 10 · #{ticket.number}")
    end

    it 'falls back to the job code before the backing ticket exists' do
      expect(dispatcher.send(:push_body, nil)).to eq("Открыть: · Boiler repair · Lenina 10 · #{job.job_code}")
    end
  end

  describe '.recipients_for_new_pool_job' do
    before { DomServis::DispatchRoleCatalog.sync!(actor_id: 1) }

    let!(:master_user)     { dispatch_user('Dom-Servis Master') }
    let!(:dispatcher_user) { dispatch_user('Dom-Servis Dispatcher') }
    let!(:admin_user)      { dispatch_user('Dom-Servis Admin') }
    let!(:other_agent)     { create(:agent) }

    def dispatch_user(role_name)
      create(:agent).tap { |user| user.roles << Role.find_by!(name: role_name) }
    end

    it 'tells masters, dispatchers and admins about a job from a request source', :aggregate_failures do
      # Intake attributes the job to a stand-in agent, here the admin.
      intake_job = DomServis::DispatchJob.new(request_source_id: 1, created_by_id: admin_user.id)

      recipients = described_class.recipients_for_new_pool_job(intake_job)

      expect(recipients).to include(master_user, dispatcher_user, admin_user)
      expect(recipients).not_to include(other_agent)
    end

    it 'leaves out the person who entered the job on the board', :aggregate_failures do
      board_job = DomServis::DispatchJob.new(created_by_id: dispatcher_user.id)

      recipients = described_class.recipients_for_new_pool_job(board_job)

      expect(recipients).to include(master_user, admin_user)
      expect(recipients).not_to include(dispatcher_user)
    end

    context 'when masters have directions and areas' do
      let!(:plumber)     { dispatch_user('Dom-Servis Master') }
      let!(:boiler_man)  { dispatch_user('Dom-Servis Master') }

      before do
        DomServis::MasterRate.create!(user: plumber, directions: ['Сантехника'])
        DomServis::MasterRate.create!(user: boiler_man, directions: ['Газовый котёл'], areas: ['Гурьевск'])
      end

      def recipients_for(tags)
        described_class.recipients_for_new_pool_job(DomServis::DispatchJob.new(request_source_id: 1, work_tags: tags))
      end

      it 'tells only the masters the job fits, and the staff', :aggregate_failures do
        recipients = recipients_for(%w[Сантехника Засор])

        expect(recipients).to include(plumber, master_user, dispatcher_user, admin_user)
        expect(recipients).not_to include(boiler_man)
      end

      it 'checks the area as well' do
        expect(recipients_for(['Газовый котёл', 'Калининград'])).not_to include(boiler_man)
      end

      it 'lets a job without a direction or an area reach everybody' do
        expect(recipients_for(['Ремонт'])).to include(plumber, boiler_man, master_user)
      end

      it 'tells every master when no master fits' do
        DomServis::MasterRate.create!(user: master_user, directions: ['Электрика'])

        expect(described_class.masters_for_job(DomServis::DispatchJob.new(work_tags: ['Бытовая техника']))).to contain_exactly(plumber, boiler_man, master_user)
      end
    end
  end
end
