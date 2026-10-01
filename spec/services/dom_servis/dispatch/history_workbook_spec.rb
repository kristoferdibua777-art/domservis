# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Dispatch::HistoryWorkbook, :aggregate_failures do
  subject(:workbook) { described_class.new(export:, locale: 'ru-ru') }

  let(:admin)  { create(:admin) }
  let(:master) { create(:agent) }
  let(:job) do
    DomServis::DispatchJob.create!(
      service_type: 'Boiler repair',
      address:      'Lenina 10',
      client_phone: '+79001234567',
      visit_day:    'mon',
      visit_date:   '2026-03-23',
      priority:     'medium',
      status:       'pool',
      source:       'manual',
    )
  end

  let(:events) do
    [
      DomServis::DispatchEvent.create!(dispatch_job: job, actor_user: admin, event_type: 'created', meta: { source: 'manual' }),
      DomServis::DispatchEvent.create!(dispatch_job: job, actor_user: admin, event_type: 'assigned', meta: { from: nil, to: master.id, status: { from: 'pool', to: 'taken' } }),
      DomServis::DispatchEvent.create!(dispatch_job: job, actor_user: admin, event_type: 'updated', meta: { changes: { address: { from: 'Lenina 10', to: 'Mira 5' } } }),
      DomServis::DispatchEvent.create!(dispatch_job: job, actor_user: admin, event_type: 'comment_added', meta: { comment: 'Позвонить', from: nil }),
    ]
  end

  let(:export) do
    DomServis::DispatchHistoryExport.create!(created_by: admin, last_event_id: events.last.id, event_count: events.size)
  end

  it 'writes one row per event, oldest first, with the board labels' do
    rows = workbook.rows

    expect(rows.pluck(0)).to eq(events.map(&:id))
    expect(rows.pluck(2).uniq).to eq([job.job_code])
    expect(rows.pluck(4)).to eq(['Заявка создана', 'Назначен мастер', 'Изменены данные заявки', 'Изменён комментарий диспетчера'])
    expect(rows.pluck(5).uniq).to eq([admin.fullname])
    expect(rows.pluck(6)).to eq([
                                  'Источник: Вручную',
                                  "Исполнитель: — → #{master.fullname}; Статус: В пуле → Взята",
                                  'Адрес: Lenina 10 → Mira 5',
                                  'Комментарий диспетчера: — → Позвонить',
                                ])
    expect(workbook.row_count).to eq(4)
  end

  it 'leaves out events after the export' do
    export
    DomServis::DispatchEvent.create!(dispatch_job: job, event_type: 'published', meta: {})

    expect(workbook.row_count).to eq(4)
  end

  it 'keeps the job code and the snapshot of a deleted job' do
    events
    DomServis::DispatchEvent.create!(dispatch_job: job, actor_user: admin, event_type: 'deleted', meta: { job_code: job.job_code, status: 'pool', address: 'Lenina 10' })
    job_code = job.job_code
    job.destroy!
    deleted_export = DomServis::DispatchHistoryExport.create!(created_by: admin, last_event_id: DomServis::DispatchEvent.maximum(:id), event_count: 5)

    last_row = described_class.new(export: deleted_export, locale: 'ru-ru').rows.last

    expect(last_row[2]).to eq(job_code)
    expect(last_row[4]).to eq('Заявка удалена')
    expect(last_row[6]).to eq("Номер заявки: #{job_code}; Статус: В пуле; Адрес: Lenina 10")
  end

  it 'builds an xlsx file' do
    expect(workbook.content).to start_with('PK')
    expect(workbook.filename).to match(%r{\Adom-servis-history-\d{4}-\d{2}-\d{2}\.xlsx\z})
  end
end