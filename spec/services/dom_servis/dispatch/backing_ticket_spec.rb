# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'Dom-Servis backing ticket bridge' do
  let(:group)        { create(:group, name: '000 Bridge Group') }
  let(:dispatcher)   { create(:agent, groups: [group]) }
  let(:master)       { create(:agent, groups: [group]) }
  let(:organization) { create(:organization, name: 'Partner Org') }

  before do
    %w[boiler urgent waiting-parts gas].each do |tag_name|
      Tag::Item.lookup_by_name_and_create(tag_name)
    end
  end

  let(:dispatch_job) do
    DomServis::DispatchJob.create!(
      service_type:    'Boiler repair',
      address:         'Lenina 10',
      client_name:     'Ivan Petrov',
      client_phone:    '+79001234567',
      visit_day:       'mon',
      visit_date:      '2026-03-23',
      visit_time:      '10:00-12:00',
      priority:        'medium',
      organization:    organization,
      work_tags:       %w[boiler urgent],
      description:     'Initial intake description',
      comment:         'Call before arrival',
      status:          'taken',
      assignee:        master,
      source:          'manual',
      created_by:      dispatcher,
      updated_by:      dispatcher,
    )
  end

  it 'creates and links a backing ticket with dispatch projection fields' do
    ticket = DomServis::Dispatch::BackingTicket::Create
      .new(dispatch_job:, operator: dispatcher)
      .execute

    expect(ticket).to be_persisted
    expect(dispatch_job.reload.ticket_id).to eq(ticket.id)
    expect(ticket.group_id).to eq(group.id)
    expect(ticket.organization_id).to eq(organization.id)
    expect(ticket.owner_id).to eq(master.id)
    expect(ticket.title).to include(dispatch_job.job_code, 'Boiler repair', 'Lenina 10')
    expect(ticket.dom_servis_job_code).to eq(dispatch_job.job_code)
    expect(ticket.dom_servis_dispatch_status).to eq('taken')
    expect(ticket.dom_servis_dispatch_priority).to eq('medium')
    expect(ticket.dom_servis_assignee_name).to eq(master.fullname)
    expect(ticket.tag_list).to eq(%w[boiler urgent])
    expect(ticket.articles.last.body).to include('Created from Dom-Servis dispatch board.')
    expect(ticket.articles.last.body).to include('Call before arrival')
  end

  it 'falls back to an operator-accessible group when the configured backing group is unavailable' do
    accessible_group = create(:group, name: '001 Accessible Group')
    blocked_group    = create(:group, name: '999 Blocked Group')
    operator         = create(:agent, groups: [accessible_group])

    previous_group_setting = Setting.get('dom_servis_dispatch_backing_ticket_group_id')
    Setting.set('dom_servis_dispatch_backing_ticket_group_id', blocked_group.id, validate: false)

    fallback_job = DomServis::DispatchJob.create!(
      service_type: 'Washing machine repair',
      address:      'Moskovskaya 15',
      client_name:  'Olga Ivanova',
      client_phone: '+79002223344',
      visit_day:    'wed',
      visit_date:   '2026-03-25',
      priority:     'medium',
      organization: organization,
      work_tags:    %w[boiler],
      description:  'Needs a ticket in an accessible group.',
      status:       'pool',
      created_by:   operator,
      updated_by:   operator,
    )

    ticket = DomServis::Dispatch::BackingTicket::Create
      .new(dispatch_job: fallback_job, operator:)
      .execute

    expect(ticket).to be_persisted
    expect(ticket.group_id).to eq(accessible_group.id)
    expect(fallback_job.reload.ticket_id).to eq(ticket.id)
  ensure
    Setting.set('dom_servis_dispatch_backing_ticket_group_id', previous_group_setting, validate: false)
  end

  it 'syncs key dispatch changes into the existing backing ticket and appends an internal note' do
    ticket = DomServis::Dispatch::BackingTicket::Create
      .new(dispatch_job:, operator: dispatcher)
      .execute

    dispatch_job.update!(
      status:        'done',
      priority:      'high',
      visit_day:     'tue',
      work_tags:     %w[gas waiting-parts],
      comment:       'Work completed successfully',
      description:   'Updated completion details',
      updated_by_id: dispatcher.id,
    )

    described_class = DomServis::Dispatch::BackingTicket::SyncFromDispatch
    described_class
      .new(
        dispatch_job: dispatch_job,
        operator:     dispatcher,
        changes:      {
          'status_changed'     => { from: 'taken', to: 'done' },
          'priority_changed'   => { from: 'medium', to: 'high' },
          'moved_weekday'      => { from: 'mon', to: 'tue' },
          'tags_changed'       => { to: %w[gas waiting-parts] },
          'comment_added'      => { comment: 'Work completed successfully' },
          'description_updated'=> { description: 'Updated completion details' },
        }
      )
      .execute

    ticket.reload

    expect(ticket.dom_servis_dispatch_status).to eq('done')
    expect(ticket.dom_servis_dispatch_priority).to eq('high')
    expect(ticket.dom_servis_visit_day).to eq('tue')
    expect(ticket.dom_servis_comment).to eq('Work completed successfully')
    expect(ticket.dom_servis_description).to eq('Updated completion details')
    expect(ticket.tag_list).to eq(%w[gas waiting-parts])
    expect(ticket.state.state_type.name).to eq('closed')
    expect(ticket.articles.last.body).to include('Status: taken -> done.')
    expect(ticket.articles.last.body).to include('Current dispatch comment')
    expect(ticket.articles.last.body).to include('Updated completion details')
  end
end
