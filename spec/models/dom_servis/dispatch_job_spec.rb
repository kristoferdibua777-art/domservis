# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'
require 'models/contexts/factory_context'

RSpec.describe DomServis::DispatchJob, current_user_id: 1, type: :model do
  self.use_transactional_tests = false

  # The 'factory' shared context (spec/models/contexts/factory_context.rb)
  # adds a bare `it 'saves successfully' do expect(subject).to be_persisted
  # end` and relies on the describing spec to define what `subject` is -
  # mirrors the same explicit-subject pattern used by the other consumers of
  # that shared context (e.g. spec/models/knowledge_base/locale_spec.rb's
  # `subject { create(:knowledge_base_locale) }`).
  subject { described_class.create!(dispatch_job_attrs) }

  include_context 'factory'

  let(:private_organization) { create(:organization, name: 'Частный заказ') }
  let(:dispatch_job_attrs) do
    {
      service_type: 'Boiler repair',
      address:      'Lenina 10',
      client_phone: '+79001234567',
      visit_day:    'mon',
      visit_date:   '2026-03-23',
      priority:     'medium',
      status:       'pool',
      source:       'manual',
    }
  end

  before do
    private_organization
    allow(PushMessages).to receive(:send)
  end

  after do
    described_class.delete_all
    DomServis::DispatchEvent.delete_all
    private_organization.delete if private_organization.persisted?
  end

  it 'sends an authenticated push after create commit' do
    job = described_class.create!(dispatch_job_attrs)

    expect(PushMessages).to have_received(:send).with(hash_including(
                                                        type:    'authenticated',
                                                        message: hash_including(
                                                          event: 'DomServisDispatchJob:create',
                                                          data:  hash_including(id: job.id, updated_at: job.updated_at),
                                                        ),
                                                      ))
  end

  it 'sends an authenticated push after update commit' do
    job = described_class.create!(dispatch_job_attrs)

    job.update!(priority: 'high')

    expect(PushMessages).to have_received(:send).with(hash_including(
                                                        type:    'authenticated',
                                                        message: hash_including(
                                                          event: 'DomServisDispatchJob:update',
                                                          data:  hash_including(id: job.id, updated_at: job.updated_at),
                                                        ),
                                                      ))
  end

  describe 'status workflow' do
    before do
      allow(DomServis::Notifications::Dispatcher).to receive(:new).and_return(instance_double(DomServis::Notifications::Dispatcher, deliver: nil))
    end

    it 'does not keep a master on a pool job', :aggregate_failures do
      job = described_class.new(dispatch_job_attrs.merge(assignee_id: 1))

      expect(job).not_to be_valid
      expect(job.errors[:assignee_id]).to be_present
    end

    it 'requires a master for a taken job', :aggregate_failures do
      job = described_class.new(dispatch_job_attrs.merge(status: 'taken'))

      expect(job).not_to be_valid
      expect(job.errors[:assignee_id]).to be_present
    end

    it 'rejects status changes outside the workflow graph' do
      job = described_class.create!(dispatch_job_attrs)

      expect { job.update!(status: 'done', assignee_id: 1) }.to raise_error(ActiveRecord::RecordInvalid, %r{cannot change from 'pool' to 'done'})
    end

    it 'keeps the completion time and stamps the closing time when a done job is closed' do
      job = described_class.create!(dispatch_job_attrs.merge(status: 'in_progress', assignee_id: 1))
      job.update!(status: 'done')
      completed_at = job.reload.completed_at

      job.update!(status: 'closed')

      expect(job.reload).to have_attributes(completed_at: completed_at, closed_at: be_present, assignee_id: 1)
    end
  end

  it 'sends an authenticated push after destroy commit' do
    job = described_class.create!(dispatch_job_attrs)
    job_id = job.id
    updated_at = job.updated_at

    job.destroy!

    expect(PushMessages).to have_received(:send).with(hash_including(
                                                        type:    'authenticated',
                                                        message: hash_including(
                                                          event: 'DomServisDispatchJob:destroy',
                                                          data:  hash_including(id: job_id, updated_at: updated_at),
                                                        ),
                                                      ))
  end
end
