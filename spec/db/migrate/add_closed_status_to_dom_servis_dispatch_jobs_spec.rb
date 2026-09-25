# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe AddClosedStatusToDomServisDispatchJobs, current_user_id: 1, type: :db_migration do
  let(:completed_at) { Time.zone.parse('2026-03-23 12:00:00') }

  # Jobs are written straight to the table to reproduce rows saved before the
  # workflow validations existed.
  def legacy_job(status:, assignee_id: nil, completed_at: nil)
    DomServis::DispatchJob.create!(
      service_type: 'Boiler repair',
      address:      'Lenina 10',
      client_phone: '+79001234567',
      visit_day:    'mon',
      visit_date:   '2026-03-23',
      priority:     'medium',
      source:       'manual',
      status:       'cancelled',
    ).tap do |job|
      job.update_columns(status:, assignee_id:, completed_at:)
    end
  end

  before do
    allow(PushMessages).to receive(:send)
    allow(DomServis::Notifications::Dispatcher).to receive(:new).and_return(instance_double(DomServis::Notifications::Dispatcher, deliver: nil))
  end

  it 'closes jobs finished under the single done status', :aggregate_failures do
    job = legacy_job(status: 'done', assignee_id: 1, completed_at:)

    migrate

    expect(job.reload).to have_attributes(status: 'closed', closed_at: completed_at, completed_at: completed_at, assignee_id: 1)
  end

  it 'stops without changing anything when a pool job keeps a master', :aggregate_failures do
    pool_job = legacy_job(status: 'pool', assignee_id: 1)
    done_job = legacy_job(status: 'done', assignee_id: 1, completed_at:)

    expect { migrate }.to raise_error(RuntimeError, %r{1 pool job\(s\) with a master \(ids: #{pool_job.id}\)})
    expect(pool_job.reload).to have_attributes(status: 'pool', assignee_id: 1)
    expect(done_job.reload.status).to eq('done')
  end

  it 'stops when a taken job has no master', :aggregate_failures do
    taken_job = legacy_job(status: 'taken')

    expect { migrate }.to raise_error(RuntimeError, %r{1 taken/in_progress job\(s\) without a master \(ids: #{taken_job.id}\)})
    expect(taken_job.reload).to have_attributes(status: 'taken', assignee_id: nil)
  end
end
