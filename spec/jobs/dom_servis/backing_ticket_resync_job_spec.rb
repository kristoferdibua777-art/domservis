# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::BackingTicketResyncJob, type: :job do
  let(:ticket_sync) { instance_double(DomServis::Dispatch::BackingTicket::SyncFromDispatch) }
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

  before do
    allow(DomServis::Dispatch::BackingTicket::SyncFromDispatch).to receive(:new).and_return(ticket_sync)
  end

  it 'clears the failure when the retry succeeds' do
    allow(ticket_sync).to receive(:execute).and_return(true)
    job.record_ticket_sync_failure!(StandardError.new('ticket store down'))

    described_class.perform_now(job.id)

    expect(job.reload).to have_attributes(ticket_sync_failed_at: nil, ticket_sync_error: nil)
  end

  it 'keeps the failure recorded when the retry fails again' do
    allow(ticket_sync).to receive(:execute).and_raise(StandardError, 'still down')
    job.record_ticket_sync_failure!(StandardError.new('ticket store down'))

    described_class.perform_now(job.id)

    expect(job.reload.ticket_sync_error).to eq('StandardError: still down')
  end

  it 'does nothing for a job without a recorded failure' do
    allow(ticket_sync).to receive(:execute)

    described_class.perform_now(job.id)

    expect(ticket_sync).not_to have_received(:execute)
  end

  it 'does nothing for a deleted job' do
    allow(ticket_sync).to receive(:execute)

    described_class.perform_now(0)

    expect(ticket_sync).not_to have_received(:execute)
  end
end
