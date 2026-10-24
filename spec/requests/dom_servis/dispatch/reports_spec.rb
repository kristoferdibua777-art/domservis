# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe 'DomServis master reports', type: :request do
  let(:admin) do
    create(:admin).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Admin')
    end
  end
  let(:dispatcher_user) do
    create(:agent).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Dispatcher')
    end
  end
  let(:master_user) do
    create(:agent, firstname: 'Ivan', lastname: 'Master').tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Master')
    end
  end
  let(:other_master_user) do
    create(:agent).tap do |user|
      user.roles << Role.find_by!(name: 'Dom-Servis Master')
    end
  end
  let(:partner_org) { create(:organization, name: 'ZIP Partner') }
  let(:job) do
    DomServis::DispatchJob.create!(
      service_type:    'Газовый котёл: Не греет',
      address:         'Калининград, ул. Ленина 10',
      client_phone:    '+79001234567',
      visit_day:       'mon',
      visit_date:      '2026-10-26',
      priority:        'medium',
      source:          'manual',
      status:          'in_progress',
      assignee:        master_user,
      organization_id: partner_org.id,
    )
  end
  let(:price_item) { DomServis::PriceItem.create!(name: 'Чистка теплообменника', kind: 'work', direction: 'Газовый котёл', price: 2500) }
  let(:report_params) do
    {
      items:           [
        { price_item_id: price_item.id, quantity: 1, price: 3000 },
        { kind: 'part', name: 'Термопара', quantity: 2, unit: 'шт', price: '450,50', bought_by_master: true },
      ],
      work_summary:    'Почистил теплообменник, заменил термопару',
      recommendations: 'ТО через год',
      payment_method:  'cash',
      amount_paid:     3901,
    }
  end

  def report_url(dispatch_job = job)
    "/api/v1/dom_servis/dispatch/jobs/#{dispatch_job.id}/report"
  end

  def add_photo(dispatch_job = job)
    Store.create!(
      object:        'DomServis::DispatchJob',
      o_id:          dispatch_job.id,
      data:          'photo',
      filename:      'result.jpg',
      preferences:   { 'Content-Type' => 'image/jpeg', 'dom_servis_kind' => 'diagnostic_photo' },
      created_by_id: 1,
    )
  end

  before do
    DomServis::DispatchRoleCatalog.sync!(actor_id: 1)
    DomServis::MasterRate.create!(user: master_user, work_percent: 40)
    DomServis::PartnerRate.create!(organization: partner_org, percent: 10, base: 'works')
    allow_any_instance_of(DomServis::Dispatch::JobsController).to receive(:sync_backing_ticket!).and_return(true)
  end

  context 'when the master of the job reports', authenticated_as: -> { master_user } do
    it 'saves an unfinished report while the job is in progress', :aggregate_failures do
      put report_url, params: report_params.merge(recommendations: ''), as: :json

      expect(response).to have_http_status(:ok)
      expect(job.reload.status).to eq('in_progress')
      expect(json_response['report']).to include('complete' => false, 'total' => 3901.0, 'works_total' => 3000.0, 'parts_total' => 901.0)
      expect(json_response['report']['missing']).to include('напишите рекомендации клиенту (если их нет — «нет»)', 'приложите фото результата или акт выполненных работ')
      expect(job.events.last).to have_attributes(event_type: 'report_saved')
    end

    it 'keeps the price list price next to the changed price', :aggregate_failures do
      put report_url, params: report_params, as: :json

      item = json_response['report']['items'].first
      expect(item).to include('name' => 'Чистка теплообменника', 'list_price' => 2500.0, 'price' => 3000.0, 'price_changed' => true, 'kind' => 'work')
      expect(json_response['report']['items'].second).to include('amount' => 901.0, 'bought_by_master' => true)
    end

    it 'shows the master his own share and settlement, not the company sums', :aggregate_failures do
      put report_url, params: report_params, as: :json

      expect(json_response['report']).to include(
        'master_percent'      => 40.0,
        'master_amount'       => 1200.0,
        'parts_reimbursement' => 901.0,
        'master_payout'       => 2101.0,
        'money_at_master'     => 3901.0,
        'master_settlement'   => -1800.0,
      )
      expect(json_response['report']).not_to include('partner_amount', 'company_amount')
      expect(json_response['rates']).to eq('master_percent' => 40.0)
    end

    it 'finishes the job with a complete report', :aggregate_failures do
      add_photo

      put report_url, params: report_params.merge(finish: true), as: :json

      expect(response).to have_http_status(:ok)
      expect(job.reload).to have_attributes(status: 'done', completed_at: be_present)
      expect(job.report).to have_attributes(submitted_at: be_present, master_id: master_user.id)
      expect(json_response).to include('status' => 'done', 'can_finish' => false)
    end

    it 'goes through in progress when the job was only taken', :aggregate_failures do
      taken_job = DomServis::DispatchJob.create!(service_type: 'Сантехника', address: 'ул. Мира 1', visit_day: 'mon', status: 'taken', assignee: master_user, source: 'manual', priority: 'medium')
      add_photo(taken_job)

      put report_url(taken_job), params: report_params.merge(finish: true), as: :json

      expect(response).to have_http_status(:ok)
      expect(taken_job.reload.status).to eq('done')
      expect(taken_job.events.where(event_type: 'status_changed').reorder(:id).map { |event| event.meta['to'] }).to eq(%w[in_progress done])
    end

    it 'refuses to finish with an incomplete report', :aggregate_failures do
      put report_url, params: report_params.merge(finish: true), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to include('приложите фото результата или акт')
      expect(job.reload.status).to eq('in_progress')
      expect(job.report).to be_nil
    end

    it 'rejects an item without a quantity', :aggregate_failures do
      put report_url, params: report_params.merge(items: [{ name: 'Работа', quantity: 0, price: 100 }]), as: :json

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['error']).to include('Проверьте позиции 1 (Работа)')
    end

    it 'does not report on the job of another master' do
      other_job = DomServis::DispatchJob.create!(service_type: 'Сантехника', address: 'ул. Мира 1', visit_day: 'mon', status: 'in_progress', assignee: other_master_user, source: 'manual', priority: 'medium')

      put report_url(other_job), params: report_params, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'does not change the report of a closed job', :aggregate_failures do
      add_photo
      put report_url, params: report_params.merge(finish: true), as: :json
      job.reload.update!(status: 'closed')

      put report_url, params: report_params.merge(work_summary: 'Другое'), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(job.report.reload.work_summary).to eq('Почистил теплообменник, заменил термопару')
    end
  end

  context 'when a dispatcher reads the report', authenticated_as: :dispatcher_user do
    it 'shows the client sums without the shares', :aggregate_failures do
      add_photo
      DomServis::Dispatch::ReportSaver.new(job:, user: master_user, params: report_params.with_indifferent_access).save!

      get report_url, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['report']).to include('total' => 3901.0, 'payment_method_label' => 'Наличными мастеру', 'complete' => true, 'master_name' => 'Ivan Master')
      expect(json_response['report']).not_to include('master_amount', 'partner_amount', 'company_amount')
      expect(json_response['rates']).to eq({})
    end

    it 'cannot move the job to done without a report' do
      post "/api/v1/dom_servis/dispatch/jobs/#{job.id}/status", params: { status: 'done' }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  context 'when the admin reads the report', authenticated_as: :admin do
    it 'shows the partner share and what the company keeps', :aggregate_failures do
      DomServis::Dispatch::ReportSaver.new(job:, user: master_user, params: report_params.with_indifferent_access).save!

      get report_url, as: :json

      expect(json_response['report']).to include('partner_percent' => 10.0, 'partner_base' => 'works', 'partner_amount' => 300.0, 'company_amount' => 1500.0)
      expect(json_response['rates']).to include('master_percent' => 40.0, 'partner_percent' => 10.0)
    end

    it 'keeps the rates of a closed job', :aggregate_failures do
      add_photo
      DomServis::Dispatch::ReportSaver.new(job:, user: master_user, params: report_params.with_indifferent_access).save!(require_complete: true)
      job.update!(status: 'done')
      job.update!(status: 'closed')
      DomServis::MasterRate.find_by(user: master_user).update!(work_percent: 50)

      put report_url, params: report_params.merge(work_summary: 'Уточнено'), as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['report']).to include('work_summary' => 'Уточнено', 'master_percent' => 40.0)
    end
  end

  describe 'price list' do
    before do
      price_item
      DomServis::PriceItem.create!(name: 'Старая позиция', price: 100, active: false)
    end

    it 'lists the active lines for a master', authenticated_as: -> { master_user } do
      get '/api/v1/dom_servis/dispatch/price_list', as: :json

      expect(json_response['items'].pluck('name')).to eq(['Чистка теплообменника'])
    end

    it 'does not let a dispatcher change it', authenticated_as: -> { dispatcher_user } do
      put '/api/v1/dom_servis/dispatch/price_list', params: { items: [] }, as: :json

      expect(response).to have_http_status(:forbidden)
    end

    it 'is replaced by the admin', :aggregate_failures, authenticated_as: :admin do
      put '/api/v1/dom_servis/dispatch/price_list', params: { items: [
        { id: price_item.id, name: 'Чистка теплообменника', kind: 'work', direction: 'Газовый котёл', unit: 'шт', price: '2 700' },
        { name: 'Выезд мастера', kind: 'work', unit: 'выезд', price: 500 },
      ] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(DomServis::PriceItem.ordered.map { |item| [item.name, item.price.to_f] }).to eq([['Чистка теплообменника', 2700.0], ['Выезд мастера', 500.0]])
    end

    it 'rejects an unknown direction', authenticated_as: :admin do
      put '/api/v1/dom_servis/dispatch/price_list', params: { items: [{ name: 'Что-то', direction: 'Космос', price: 1 }] }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'finance rates' do
    it 'lists and saves the shares of masters and partners', :aggregate_failures, authenticated_as: :admin do
      put '/api/v1/dom_servis/dispatch/finance_rates', params: {
        masters:  [{ user_id: master_user.id, work_percent: '45,5' }],
        partners: [{ organization_id: partner_org.id, percent: 12, base: 'total' }],
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['masters'].find { |row| row['user_id'] == master_user.id }).to include('work_percent' => 45.5)
      expect(json_response['partners'].find { |row| row['organization_id'] == partner_org.id }).to include('percent' => 12.0, 'base' => 'total')
    end

    it 'is only for the admin', authenticated_as: -> { dispatcher_user } do
      get '/api/v1/dom_servis/dispatch/finance_rates', as: :json

      expect(response).to have_http_status(:forbidden)
    end
  end
end
