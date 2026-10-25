# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::DispatchReport, current_user_id: 1 do
  let(:master)  { create(:agent) }
  let(:partner) { create(:organization) }
  let(:job) do
    DomServis::DispatchJob.create!(
      service_type:    'Бытовая техника: Стиральная машина',
      address:         'ул. Мира 1',
      visit_day:       'mon',
      status:          'in_progress',
      assignee:        master,
      source:          'manual',
      priority:        'medium',
      organization_id: partner.id,
    )
  end

  def build_report(**attributes)
    report = job.build_report(master:, work_summary: 'Заменил насос', recommendations: 'нет', **attributes)
    report.items.build(kind: 'work', name: 'Замена насоса', quantity: 1, price: 2000)
    report.items.build(kind: 'work', name: 'Выезд', quantity: 1, price: 500)
    report.items.build(kind: 'part', name: 'Насос', quantity: 1, price: 1800, bought_by_master: true)
    report.items.build(kind: 'part', name: 'Хомут', quantity: 2, price: 50)
    report.apply_rates
    report
  end

  before do
    DomServis::MasterRate.create!(user: master, work_percent: 30)
    DomServis::PartnerRate.create!(organization: partner, percent: 5, base: 'total')
  end

  it 'calculates the sums and the shares', :aggregate_failures do
    report = build_report(payment_method: 'card', amount_paid: 4400)
    report.save!

    expect(report).to have_attributes(
      works_total:         2500,
      parts_total:         1900,
      total:               4400,
      master_percent:      30,
      master_amount:       750,
      parts_reimbursement: 1800,
      master_payout:       2550,
      partner_percent:     5,
      partner_base:        'total',
      partner_amount:      220,
      company_amount:      1630,
      money_at_master:     0,
      master_settlement:   2550,
    )
    expect(report.items.map(&:amount)).to eq([2000, 500, 1800, 100])
  end

  it 'counts cash paid to the master against his payout' do
    report = build_report(payment_method: 'cash', amount_paid: 4400)
    report.save!

    expect(report).to have_attributes(money_at_master: 4400, master_settlement: -1850)
  end

  it 'names what is missing before the job can be finished', :aggregate_failures do
    report = job.build_report(payment_method: 'cash')

    expect(report.missing).to eq([
                                   'добавьте хотя бы одну работу или запчасть',
                                   'напишите, что сделано',
                                   'напишите рекомендации клиенту (если их нет — «нет»)',
                                   'укажите сумму, полученную от клиента',
                                   'приложите фото результата или акт выполненных работ',
                                 ])
    expect(report.complete?).to be(false)
  end

  it 'needs no amount when the partner pays or nothing was paid' do
    report = build_report(payment_method: 'partner')

    expect(report.missing).to eq(['приложите фото результата или акт выполненных работ'])
  end

  it 'is complete with a photo or an act among the job attachments' do
    Store.create!(object: 'DomServis::DispatchJob', o_id: job.id, data: 'act', filename: 'act.pdf', preferences: { 'Content-Type' => 'application/pdf', 'dom_servis_kind' => 'completion_act' })

    expect(build_report(payment_method: 'transfer_company', amount_paid: 4400)).to be_complete
  end

  it 'marks a price changed from the price list' do
    item = DomServis::DispatchReportItem.new(name: 'Чистка', kind: 'work', quantity: 1, list_price: 2500, price: 3000)

    expect(item.price_changed_from_list?).to be(true)
  end
end
