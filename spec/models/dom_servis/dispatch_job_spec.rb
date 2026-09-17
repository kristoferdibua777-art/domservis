# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'
require 'models/contexts/factory_context'

RSpec.describe DomServis::DispatchJob, type: :model, current_user_id: 1 do
  self.use_transactional_tests = false

  include_context 'factory'

  # The 'factory' shared context (spec/models/contexts/factory_context.rb)
  # adds a bare `it 'saves successfully' do expect(subject).to be_persisted
  # end` and relies on the describing spec to define what `subject` is -
  # mirrors the same explicit-subject pattern used by the other consumers of
  # that shared context (e.g. spec/models/knowledge_base/locale_spec.rb's
  # `subject { create(:knowledge_base_locale) }`).
  subject { described_class.create!(dispatch_job_attrs) }

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
