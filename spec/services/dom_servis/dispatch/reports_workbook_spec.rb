# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Dispatch::ReportsWorkbook, current_user_id: 1 do
  subject(:workbook) { described_class.new(from: today - 1, to: today + 1) }

  let(:today)   { Time.zone.today }
  let(:master)  { create(:agent, firstname: 'Ivan', lastname: 'Master') }
  let(:partner) { create(:organization, name: 'ZIP Partner') }

  def create_job(**attributes)
    DomServis::DispatchJob.create!(
      service_type: 'Газовый котёл: Не греет',
      address:      'Калининград, ул. Ленина 1',
      client_name:  'Ирина',
      client_phone: '+79001234567',
      visit_day:    'mon',
      source:       'manual',
      priority:     'medium',
      status:       'in_progress',
      assignee:     master,
      work_tags:    ['Газовый котёл', 'Не греет'],
      **attributes,
    )
  end

  def report_for(job, payment_method: 'cash')
    Store.create!(object: 'DomServis::DispatchJob', o_id: job.id, data: 'photo', filename: 'photo.jpg', preferences: { 'Content-Type' => 'image/jpeg', 'dom_servis_kind' => 'diagnostic_photo' })
    report = job.build_report(master:, work_summary: 'Почистил теплообменник', recommendations: 'ТО через год', payment_method:, amount_paid: 3900)
    report.items.build(kind: 'work', name: 'Чистка теплообменника', quantity: 1, list_price: 2500, price: 3000)
    report.items.build(kind: 'part', name: 'Термопара', quantity: 2, price: 450, bought_by_master: true)
    report.apply_rates
    report.save!
    report
  end

  before do
    DomServis::MasterRate.create!(user: master, work_percent: 40)
    DomServis::PartnerRate.create!(organization: partner, percent: 10, base: 'works')
  end

  it 'lists every job of the period with the summary of its report', :aggregate_failures do
    reported = create_job(organization_id: partner.id)
    report_for(reported)
    create_job(status: 'pool', assignee: nil, service_type: 'Сантехника: Засор', work_tags: ['Сантехника'])

    rows = workbook.jobs.map { |job| workbook.job_row(job) }

    expect(rows.size).to eq(2)
    expect(rows.first.size).to eq(described_class::JOB_COLUMNS.size)
    expect(rows.first.values_at(4, 8, 15, 20)).to eq(['ZIP Partner', 'Газовый котёл', 'Ivan Master', 'сдан'])
    expect(rows.first[22]).to eq('Чистка теплообменника × 1 = 3000; Термопара × 2 = 900')
    expect(rows.first.values_at(25, 26, 27, 28, 29)).to eq([3000, 900, 3900, 'Наличными мастеру', 3900])
    expect(rows.first.values_at(31, 32, 33, 34, 35)).to eq([1200, 900, 2100, 3900, -1800])
    expect(rows.first.values_at(36, 37, 38, 39, 40)).to eq([10, 'от работ', 300, 1500, 'да'])
    expect(rows.second.values_at(8, 16, 20)).to eq(['Сантехника', 'На стенде', 'нет'])
    expect(rows.second[25..39]).to all(be_nil)
  end

  it 'lists the report lines with the price list price' do
    report_for(create_job)

    rows = workbook.item_rows.map { |row| row.values_at(5, 6, 9, 10, 11, 12, 13) }

    expect(rows).to eq([
                         ['Работа', 'Чистка теплообменника', 2500, 3000, 3000, 'да', nil],
                         ['Запчасть', 'Термопара', nil, 450, 900, nil, 'да'],
                       ])
  end

  it 'sums the reported jobs by master, partner and direction', :aggregate_failures do
    report_for(create_job(organization_id: partner.id))
    report_for(create_job, payment_method: 'card')
    create_job(status: 'pool', assignee: nil)

    expect(workbook.master_rows).to eq([['Ivan Master', 2, 6000, 1800, 7800, 3900, 2400, 1800, 4200, 3900, 300]])
    expect(workbook.partner_rows).to eq([['ZIP Partner', 1, 3900, 300, 1500], ['Без организации', 1, 3900, 0, 1800]])
    expect(workbook.direction_rows).to eq([['Газовый котёл', 3, 2, 7800, 3300]])
  end

  it 'takes jobs by the day they were finished when asked' do
    create_job

    expect(described_class.new(from: today - 1, to: today + 1, date_field: 'completed').jobs).to be_empty
  end

  it 'refuses a period that ends before it starts' do
    expect { described_class.new(from: today, to: today - 1) }.to raise_error(Exceptions::UnprocessableEntity)
  end

  it 'builds an xlsx file', :aggregate_failures do
    report_for(create_job)

    expect(workbook.content).to start_with('PK')
    expect(workbook.filename).to eq("dom-servis-reports-#{(today - 1).iso8601}-#{(today + 1).iso8601}.xlsx")
  end
end
