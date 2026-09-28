# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Dispatch::BackingTicket::Resolver do
  subject(:resolver) { described_class.new(dispatch_job:) }

  let(:dispatch_job)      { instance_double(DomServis::DispatchJob, priority: dispatch_priority) }
  let(:default_priority)  { Ticket::Priority.find_by!(default_create: true) }
  let(:high_priority)     { Ticket::Priority.find_by!(name: '3 high') }
  let(:dispatch_priority) { 'high' }

  it 'returns and memoizes the active matching priority instead of the default', :aggregate_failures do
    allow(Ticket::Priority).to receive(:where).with(active: true).and_call_original

    first_result = resolver.ticket_priority
    second_result = resolver.ticket_priority

    expect(first_result).to eq(high_priority)
    expect(second_result).to equal(first_result)
    expect(first_result).not_to eq(default_priority)
    expect(Ticket::Priority).to have_received(:where).with(active: true).once
  end

  context 'when no active priority matches' do
    let(:dispatch_priority) { 'critical' }

    it 'uses the default priority' do
      expect(resolver.ticket_priority).to eq(default_priority)
    end
  end

  context 'when only an inactive priority matches' do
    before do
      high_priority.update!(active: false)
    end

    it 'does not select the inactive priority' do
      expect(resolver.ticket_priority).to eq(default_priority)
    end
  end
end
