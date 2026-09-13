# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Intake::DispatchJobCreator do
  let(:group)         { create(:group, name: '000 Intake Group') }
  let(:dispatcher)    { create(:agent, groups: [group]) }
  let(:partner_org)   { create(:organization, name: 'Partner Org') }
  let(:partner_org_2) { create(:organization, name: 'Partner Org 2') }
  let(:customer)      { create(:customer) }
  let(:request_source) do
    DomServis::RequestSource.create!(
      name:           'Partner A Form',
      partner_key:    'partner-a',
      organization:   partner_org,
      transport_kind: 'zammad_form',
      status:         'active',
      allowed_domains: ['partner-a.example.com'],
    )
  end
  let(:request_source_2) do
    DomServis::RequestSource.create!(
      name:           'Partner B Form',
      partner_key:    'partner-b',
      organization:   partner_org_2,
      transport_kind: 'zammad_form',
      status:         'active',
      allowed_domains: ['partner-b.example.com'],
    )
  end
  let(:base_ticket) do
    Ticket.create!(
      group:               group,
      customer:            customer,
      title:               'Boiler repair request',
      preferences:         { form: { remote_ip: '127.0.0.1', fingerprint_md5: 'abc123' } },
      dom_servis_service_type:    'Boiler repair',
      dom_servis_address:         'Lenina 10',
      dom_servis_client_name:     'Ivan Petrov',
      dom_servis_client_phone:    '+79001234567',
      dom_servis_visit_day:       'mon',
      dom_servis_visit_date:      '2026-03-23',
      dom_servis_visit_time:      '10:00-12:00',
      dom_servis_dispatch_priority: 'high',
      dom_servis_description:     'Initial intake description',
      dom_servis_comment:         'Call before arrival',
      dom_servis_work_tags:       'boiler,urgent',
    )
  end
  let(:second_ticket) do
    Ticket.create!(
      group:               group,
      customer:            customer,
      title:               'Second boiler repair request',
      preferences:         { form: { remote_ip: '127.0.0.1', fingerprint_md5: 'abc124' } },
      dom_servis_service_type:    'Boiler repair',
      dom_servis_address:         'Lenina 11',
      dom_servis_client_name:     'Ivan Petrov',
      dom_servis_client_phone:    '+79001234567',
      dom_servis_visit_day:       'tue',
      dom_servis_visit_date:      '2026-03-24',
      dom_servis_visit_time:      '10:00-12:00',
      dom_servis_dispatch_priority: 'high',
      dom_servis_description:     'Initial intake description 2',
      dom_servis_comment:         'Call before arrival',
      dom_servis_work_tags:       'boiler,urgent',
    )
  end

  let(:payload) do
    DomServis::Intake::TicketAdapter.new(
      ticket:          base_ticket,
      request_source:  request_source,
      source:          'form',
      channel_key:     request_source.transport_kind,
      source_reference: base_ticket.number,
    ).payload
  end

  it 'creates a dispatch job from the canonical intake payload and syncs the ticket' do
    job = described_class.new(payload:, ticket: base_ticket, actor_user: dispatcher).execute

    expect(job).to be_persisted
    expect(job.ticket_id).to eq(base_ticket.id)
    expect(job.organization_id).to eq(partner_org.id)
    expect(job.request_source_id).to eq(request_source.id)
    expect(job.source).to eq('form')
    expect(job.source_reference).to eq(base_ticket.number)
    expect(job.intake_channel_key).to eq(request_source.transport_kind)
    expect(job.intake_payload).to be_a(Hash)
    expect(job.intake_payload['ticket_number']).to eq(base_ticket.number)
    expect(job.service_type).to eq('Boiler repair')
    expect(job.address).to eq('Lenina 10')
    expect(job.client_name).to eq('Ivan Petrov')
    expect(job.client_phone).to eq('+79001234567')
    expect(job.priority).to eq('high')
    expect(job.work_tags).to eq(%w[boiler urgent])

    ticket = base_ticket.reload
    expect(ticket.dom_servis_dispatch_source).to eq('form')
    expect(ticket.dom_servis_dispatch_priority).to eq('high')
    expect(ticket.dom_servis_service_type).to eq('Boiler repair')
    expect(ticket.preferences.dig('dom_servis_intake', 'source')).to eq('form')
    expect(ticket.preferences.dig('dom_servis_intake', 'partner_org_id')).to eq(partner_org.id)
    expect(ticket.preferences.dig('dom_servis_intake', 'request_source_id')).to eq(request_source.id)
    expect(ticket.preferences.dig('dom_servis_intake', 'request_source_key')).to eq('partner-a')
  end

  it 'is idempotent for the same ticket' do
    first = described_class.new(payload:, ticket: base_ticket, actor_user: dispatcher).execute
    second = described_class.new(payload:, ticket: base_ticket, actor_user: dispatcher).execute

    expect(second.id).to eq(first.id)
    expect(DomServis::DispatchJob.count).to eq(1)
  end

  it 'creates a direct dispatch job without a backing ticket for non-native sources' do
    payload = {
      source:             'ai',
      request_source_id:   request_source_2.id,
      channel_key:        'ai_service',
      source_reference:   'ai-request-001',
      raw_payload:        { input: 'Boiler leak in apartment 42', request_source_id: request_source_2.id },
      dispatch:           {
        source:            'ai',
        request_source_id: request_source_2.id,
        organization_id:   partner_org_2.id,
        service_type:      'Boiler repair',
        address:           'Lenina 10',
        client_name:       'Ivan Petrov',
        client_phone:      '+79001234567',
        priority:          'medium',
        description:       'Boiler leak in apartment 42',
      },
    }

    job = described_class.new(payload:, actor_user: dispatcher).execute

    expect(job).to be_persisted
    expect(job.ticket_id).to be_nil
    expect(job.source).to eq('ai')
    expect(job.source_reference).to eq('ai-request-001')
    expect(job.intake_channel_key).to eq('ai_service')
    expect(job.intake_payload).to eq({ 'input' => 'Boiler leak in apartment 42' })
    expect(job.organization_id).to eq(partner_org_2.id)
    expect(job.request_source_id).to eq(request_source_2.id)
    expect(job.service_type).to eq('Boiler repair')
    expect(job.address).to eq('Lenina 10')
  end

  it 'is idempotent for the same external source reference' do
    direct_payload = {
      source:             'webhook',
      request_source_id:   request_source_2.id,
      channel_key:        'partner_webhook',
      source_reference:   'webhook-request-001',
      raw_payload:        { ticket: 'external-123', request_source_id: request_source_2.id },
      dispatch:           {
        source:            'webhook',
        request_source_id: request_source_2.id,
        organization_id:   partner_org_2.id,
        service_type:      'Boiler repair',
        address:           'Lenina 10',
      },
    }

    first = described_class.new(payload: direct_payload, actor_user: dispatcher).execute
    second = described_class.new(payload: direct_payload, actor_user: dispatcher).execute

    expect(second.id).to eq(first.id)
    expect(DomServis::DispatchJob.count).to eq(1)
  end

  it 'rejects intake from a paused request source' do
    request_source_2.update!(status: 'paused')

    paused_payload = {
      source:             'webhook',
      request_source_id:   request_source_2.id,
      channel_key:        'partner_webhook',
      source_reference:   'webhook-request-paused',
      raw_payload:        { ticket: 'external-paused', request_source_id: request_source_2.id },
      dispatch:           {
        source:            'webhook',
        request_source_id: request_source_2.id,
        organization_id:   partner_org_2.id,
        service_type:      'Boiler repair',
        address:           'Lenina 10',
      },
    }

    expect do
      described_class.new(payload: paused_payload, actor_user: dispatcher).execute
    end.to raise_error(Exceptions::Forbidden, /paused/)
  end

  it 'keeps partner identity isolated across two sources using the same transport' do
    payload_a = DomServis::Intake::TicketAdapter.new(
      ticket:          base_ticket,
      request_source:  request_source,
      source:          'form',
      channel_key:     request_source.transport_kind,
      source_reference: 'partner-a-intake-001',
    ).payload

    payload_b = DomServis::Intake::TicketAdapter.new(
      ticket:          second_ticket,
      request_source:  request_source_2,
      source:          'form',
      channel_key:     request_source_2.transport_kind,
      source_reference: 'partner-b-intake-001',
    ).payload

    job_a = described_class.new(payload: payload_a, ticket: base_ticket, actor_user: dispatcher).execute
    job_b = described_class.new(payload: payload_b, actor_user: dispatcher).execute

    expect(job_a.request_source_id).to eq(request_source.id)
    expect(job_b.request_source_id).to eq(request_source_2.id)
    expect(job_a.organization_id).to eq(partner_org.id)
    expect(job_b.organization_id).to eq(partner_org_2.id)
    expect(job_a.source_reference).to eq('partner-a-intake-001')
    expect(job_b.source_reference).to eq('partner-b-intake-001')
  end
end
