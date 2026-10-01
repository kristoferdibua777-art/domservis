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
end
