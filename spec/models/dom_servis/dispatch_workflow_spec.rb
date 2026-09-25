# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::DispatchWorkflow do
  it 'describes transitions only between registered statuses', :aggregate_failures do
    expect(described_class::TRANSITIONS.keys).to match_array(described_class::STATUSES)
    expect(described_class::TRANSITIONS.values.flat_map(&:keys) - described_class::STATUSES).to be_empty
  end

  it 'requires only actions that the dispatch policy knows' do
    policy_actions   = DomServis::DispatchPolicy::ACTION_GROUPS.flat_map { |group| group[:items] }.pluck(:key)
    workflow_actions = described_class::TRANSITIONS.values.flat_map(&:values).compact.uniq

    expect(workflow_actions - policy_actions).to be_empty
  end

  it 'moves a job through the master workflow step by step', :aggregate_failures do
    expect(described_class.transition_allowed?('pool', 'taken')).to be(true)
    expect(described_class.transition_allowed?('taken', 'in_progress')).to be(true)
    expect(described_class.transition_allowed?('in_progress', 'done')).to be(true)
    expect(described_class.transition_allowed?('done', 'closed')).to be(true)

    expect(described_class.transition_allowed?('pool', 'done')).to be(false)
    expect(described_class.transition_allowed?('taken', 'done')).to be(false)
    expect(described_class.transition_allowed?('in_progress', 'closed')).to be(false)
  end

  it 'leaves entering taken to the take and assign actions', :aggregate_failures do
    expect(described_class.transition_allowed?('pool', 'taken')).to be(true)
    expect(described_class.action_for('pool', 'taken')).to be_nil
  end

  it 'requires the close action to close finished work' do
    expect(described_class.action_for('done', 'closed')).to eq('close_job')
  end

  it 'reopens done, closed and cancelled jobs into the pool', :aggregate_failures do
    %w[done closed cancelled].each do |status|
      expect(described_class.action_for(status, 'pool')).to eq('reopen_job')
    end
  end

  it 'releases only jobs a master is holding', :aggregate_failures do
    expect(described_class.releasable?('taken')).to be(true)
    expect(described_class.releasable?('in_progress')).to be(true)
    expect(described_class.releasable?('done')).to be(false)
    expect(described_class.releasable?('pool')).to be(false)
  end

  it 'keeps a partner transfer final' do
    expect(described_class::TRANSITIONS['transferred_to_partner']).to be_empty
  end

  it 'drops the master whenever a job enters the pool', :aggregate_failures do
    expect(described_class.transition_attributes('pool')).to eq(status: 'pool', assignee_id: nil, taken_at: nil)
    expect(described_class.transition_attributes('closed')).to eq(status: 'closed')
  end

  it 'requires a master exactly while the master owns the work', :aggregate_failures do
    expect(%w[taken in_progress done].map { |status| described_class.assignee_required?(status) }).to all(be(true))
    expect(%w[pool closed cancelled transferred_to_partner].map { |status| described_class.assignee_required?(status) }).to all(be(false))
    expect(described_class.assignee_forbidden?('pool')).to be(true)
  end

  it 'closes the backing ticket only once the job leaves the workflow', :aggregate_failures do
    expect(described_class.ticket_state_type('pool')).to eq('new')
    expect(described_class.ticket_state_type('done')).to eq('open')
    expect(described_class.ticket_state_type('closed')).to eq('closed')
    expect(described_class.ticket_state_type('cancelled')).to eq('closed')
    expect(described_class.ticket_state_type('transferred_to_partner')).to eq('closed')
  end
end
