# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The table of jobs with their master reports for the admin (decision
# 2026-10-24), one Excel file with five sheets:
#
# - Заявки: a row per job with every job field and the summary of its report
#   (lines in short, what was done, sums, payment and shares);
# - Позиции: a row per work or part of the reports;
# - Мастера, Партнёры, Направления: the calculator of the reported jobs by
#   master, by partner organization and by direction tag.
#
# Jobs are taken by the day they were created or finished, in the time zone
# of the system; the sums are the ones the reports saved.
class DomServis::Dispatch::ReportsWorkbook
  DATE_FIELDS = { 'created' => :created_at, 'completed' => :completed_at }.freeze
  DATE_FIELD_LABELS = { 'created' => 'по дате создания', 'completed' => 'по дате выполнения' }.freeze
  MAX_DAYS = 366

  STATUS_LABELS   = DomServis::Dispatch::HistoryWorkbook::STATUS_LABELS
  PRIORITY_LABELS = DomServis::Dispatch::HistoryWorkbook::PRIORITY_LABELS
  SOURCE_LABELS   = DomServis::Dispatch::HistoryWorkbook::SOURCE_LABELS
  BASE_LABELS     = { 'works' => 'от работ', 'total' => 'от всей суммы' }.freeze

  JOB_COLUMNS = [
    { name: '№ заявки', width: 11 },
    { name: 'Создана', width: 17 },
    { name: 'Источник', width: 14 },
    { name: 'Канал приёма', width: 18 },
    { name: 'Партнёр / заказчик', width: 22 },
    { name: 'Клиент', width: 20 },
    { name: 'Телефон', width: 16 },
    { name: 'Адрес', width: 30 },
    { name: 'Направление', width: 18 },
    { name: 'Теги', width: 30 },
    { name: 'Тип работ', width: 30 },
    { name: 'Описание', width: 40 },
    { name: 'Приоритет', width: 11 },
    { name: 'Дата визита', width: 12 },
    { name: 'Время визита', width: 12 },
    { name: 'Мастер', width: 20 },
    { name: 'Статус', width: 14 },
    { name: 'Взята', width: 17 },
    { name: 'Выполнена', width: 17 },
    { name: 'Закрыта', width: 17 },
    { name: 'Отчёт', width: 10 },
    { name: 'Отчёт сдан', width: 17 },
    { name: 'Работы и запчасти кратко', width: 50 },
    { name: 'Что сделано', width: 40 },
    { name: 'Рекомендации клиенту', width: 30 },
    { name: 'Работы, ₽', width: 12, money: true },
    { name: 'Запчасти, ₽', width: 12, money: true },
    { name: 'Итого клиенту, ₽', width: 14, money: true },
    { name: 'Способ оплаты', width: 20 },
    { name: 'Получено, ₽', width: 12, money: true },
    { name: '% мастера', width: 10 },
    { name: 'Доля мастера, ₽', width: 13, money: true },
    { name: 'Возврат за запчасти, ₽', width: 13, money: true },
    { name: 'Мастеру всего, ₽', width: 13, money: true },
    { name: 'Деньги клиента у мастера, ₽', width: 14, money: true },
    { name: 'Расчёт с мастером, ₽ (+ выплатить, − сдать)', width: 16, money: true },
    { name: '% партнёра', width: 10 },
    { name: 'Партнёру считается', width: 14 },
    { name: 'Партнёру, ₽', width: 12, money: true },
    { name: 'Компании, ₽', width: 12, money: true },
    { name: 'Цены изменены', width: 10 },
  ].freeze

  ITEM_COLUMNS = [
    { name: '№ заявки', width: 11 },
    { name: 'Выполнена', width: 17 },
    { name: 'Мастер', width: 20 },
    { name: 'Партнёр / заказчик', width: 22 },
    { name: 'Направление', width: 18 },
    { name: 'Тип', width: 10 },
    { name: 'Наименование', width: 36 },
    { name: 'Кол-во', width: 8 },
    { name: 'Ед.', width: 7 },
    { name: 'Цена по прайсу, ₽', width: 13, money: true },
    { name: 'Цена, ₽', width: 12, money: true },
    { name: 'Сумма, ₽', width: 12, money: true },
    { name: 'Цена изменена', width: 10 },
    { name: 'Куплено мастером', width: 10 },
  ].freeze

  MASTER_COLUMNS = [
    { name: 'Мастер', width: 22 },
    { name: 'Заявок с отчётом', width: 10 },
    { name: 'Работы, ₽', width: 12, money: true },
    { name: 'Запчасти, ₽', width: 12, money: true },
    { name: 'Итого клиентам, ₽', width: 14, money: true },
    { name: 'Средний чек, ₽', width: 12, money: true },
    { name: 'Доля мастера, ₽', width: 13, money: true },
    { name: 'Возврат за запчасти, ₽', width: 13, money: true },
    { name: 'Мастеру всего, ₽', width: 13, money: true },
    { name: 'Деньги клиентов у мастера, ₽', width: 14, money: true },
    { name: 'Итог расчёта, ₽ (+ выплатить, − сдать)', width: 16, money: true },
  ].freeze

  PARTNER_COLUMNS = [
    { name: 'Партнёр / заказчик', width: 24 },
    { name: 'Заявок с отчётом', width: 10 },
    { name: 'Итого клиентам, ₽', width: 14, money: true },
    { name: 'Партнёру, ₽', width: 12, money: true },
    { name: 'Компании, ₽', width: 12, money: true },
  ].freeze

  DIRECTION_COLUMNS = [
    { name: 'Направление', width: 22 },
    { name: 'Заявок всего', width: 10 },
    { name: 'Заявок с отчётом', width: 10 },
    { name: 'Итого клиентам, ₽', width: 14, money: true },
    { name: 'Компании, ₽', width: 12, money: true },
  ].freeze

  attr_reader :from, :to, :date_field, :master_id, :timezone

  def initialize(from:, to:, date_field: 'created', master_id: nil)
    @from       = from
    @to         = to
    @date_field = DATE_FIELDS.key?(date_field.to_s) ? date_field.to_s : 'created'
    @master_id  = master_id.presence
    @timezone   = Setting.get('timezone_default').presence || 'UTC'

    raise Exceptions::UnprocessableEntity, 'Начало периода позже конца.' if from > to
    raise Exceptions::UnprocessableEntity, "Период больше #{MAX_DAYS} дней." if (to - from).to_i >= MAX_DAYS
  end

  def jobs
    @jobs ||= begin
      zone   = ActiveSupport::TimeZone[timezone] || Time.zone
      column = DATE_FIELDS[date_field]
      scope  = DomServis::DispatchJob
        .where(column => zone.local(from.year, from.month, from.day)..zone.local(to.year, to.month, to.day).end_of_day)
        .includes(:ticket, :assignee, :organization, :request_source, report: :items)
        .reorder(column => :asc, id: :asc)
      scope = scope.where(assignee_id: master_id) if master_id
      scope.to_a
    end
  end

  def filename
    "dom-servis-reports-#{from.iso8601}-#{to.iso8601}.xlsx"
  end

  def content
    require 'write_xlsx' # Only load this gem when it is really used.

    Tempfile.create(['dom-servis-reports', '.xlsx']) do |file|
      workbook = WriteXLSX.new(file.path)
      add_formats(workbook)
      write_sheet(workbook, 'Заявки', JOB_COLUMNS, jobs.map { |job| job_row(job) })
      write_sheet(workbook, 'Позиции', ITEM_COLUMNS, item_rows)
      write_sheet(workbook, 'Мастера', MASTER_COLUMNS, master_rows)
      write_sheet(workbook, 'Партнёры', PARTNER_COLUMNS, partner_rows)
      write_sheet(workbook, 'Направления', DIRECTION_COLUMNS, direction_rows)
      workbook.close
      File.binread(file.path)
    end
  end

  def job_row(job)
    report = job.report
    items  = report&.live_items || []

    [
      job.ticket&.number || job.job_code,
      time_text(job.created_at),
      SOURCE_LABELS.fetch(job.source.to_s, job.source.to_s),
      job.request_source&.display_name,
      job.organization&.name,
      job.client_name,
      job.client_phone,
      job.address,
      directions(job).join(', '),
      Array(job.work_tags).join(', '),
      job.service_type,
      job.description,
      PRIORITY_LABELS.fetch(job.priority.to_s, job.priority.to_s),
      job.visit_date,
      job.visit_time,
      job.assignee&.fullname,
      STATUS_LABELS.fetch(job.status.to_s, job.status.to_s),
      time_text(job.taken_at),
      time_text(job.completed_at),
      time_text(job.closed_at),
      report_state(report),
      time_text(report&.submitted_at),
      items.map { |item| "#{item.name} × #{number_text(item.quantity)} = #{number_text(item.line_amount)}" }.join('; ').presence,
      report&.work_summary,
      report&.recommendations,
      *report_sums(report),
      items.any?(&:price_changed_from_list?) ? 'да' : nil,
    ]
  end

  def item_rows
    jobs.flat_map do |job|
      Array(job.report&.live_items).map do |item|
        [
          job.ticket&.number || job.job_code,
          time_text(job.completed_at),
          job.report.master&.fullname,
          job.organization&.name,
          directions(job).join(', '),
          item.part? ? 'Запчасть' : 'Работа',
          item.name,
          item.quantity,
          item.unit,
          item.list_price,
          item.price,
          item.line_amount,
          item.price_changed_from_list? ? 'да' : nil,
          item.bought_by_master ? 'да' : nil,
        ]
      end
    end
  end

  def master_rows
    reported.group_by { |job| job.report.master&.fullname || 'Без мастера' }.sort_by(&:first).map do |name, list|
      reports = list.map(&:report)
      total   = sum(reports, :total)

      [
        name,
        reports.size,
        sum(reports, :works_total),
        sum(reports, :parts_total),
        total,
        (total / reports.size).round(2),
        sum(reports, :master_amount),
        sum(reports, :parts_reimbursement),
        sum(reports, :master_payout),
        sum(reports, :money_at_master),
        sum(reports, :master_settlement),
      ]
    end
  end

  def partner_rows
    reported.group_by { |job| job.organization&.name || 'Без организации' }.sort_by(&:first).map do |name, list|
      reports = list.map(&:report)

      [name, reports.size, sum(reports, :total), sum(reports, :partner_amount), sum(reports, :company_amount)]
    end
  end

  def direction_rows
    DomServis::WorkTagCatalog::DIRECTION_TAGS.values.push('Без направления').filter_map do |direction|
      list = jobs.select { |job| (directions(job).presence || ['Без направления']).include?(direction) }
      next if list.empty?

      reports = list.filter_map { |job| job.report if job.report&.complete? }
      [direction, list.size, reports.size, sum(reports, :total), sum(reports, :company_amount)]
    end
  end

  private

  def reported
    jobs.select { |job| job.report&.complete? }
  end

  def report_state(report)
    return 'нет' if !report

    report.complete? ? 'сдан' : 'черновик'
  end

  def report_sums(report)
    return Array.new(15) if !report

    [
      report.works_total,
      report.parts_total,
      report.total,
      report.payment_method_label,
      report.amount_paid,
      report.master_percent,
      report.master_amount,
      report.parts_reimbursement,
      report.master_payout,
      report.money_at_master,
      report.master_settlement,
      report.partner_percent,
      BASE_LABELS[report.partner_base],
      report.partner_amount,
      report.company_amount,
    ]
  end

  def directions(job)
    Array(job.work_tags) & DomServis::WorkTagCatalog::DIRECTION_TAGS.values
  end

  def sum(reports, attribute)
    reports.sum(BigDecimal('0')) { |report| report.public_send(attribute).to_d }
  end

  def title
    "Заявки и отчёты мастеров Дом-Сервис: #{from.strftime('%d.%m.%Y')}–#{to.strftime('%d.%m.%Y')}, #{DATE_FIELD_LABELS[date_field]}"
  end

  def time_text(time)
    time&.in_time_zone(timezone)&.strftime('%Y-%m-%d %H:%M')
  end

  def number_text(value)
    number = value.to_d.round(2)
    number.frac.zero? ? number.to_i.to_s : number.to_s('F')
  end

  def add_formats(workbook)
    @format_title  = workbook.add_format(bold: 1, size: 14)
    @format_header = workbook.add_format(bold: 1, bg_color: '#E7EEF7', text_wrap: 1, valign: 'top', border: 1)
    @format_money  = workbook.add_format(num_format: '#,##0.00')
    @format_number = workbook.add_format(num_format: '0.##')
  end

  # Values are written as numbers or plain strings: a text starting with "="
  # stays text and is never run as a formula.
  def write_sheet(workbook, name, columns, rows)
    sheet = workbook.add_worksheet(name)
    sheet.write_string(0, 0, title, @format_title)

    columns.each_with_index do |column, index|
      sheet.set_column(index, index, column[:width])
      sheet.write_string(2, index, column[:name], @format_header)
    end

    rows.each_with_index do |row, row_index|
      row.each_with_index { |value, index| write_cell(sheet, row_index + 3, index, value, columns[index]) }
    end

    sheet.freeze_panes(3, 0)
    sheet.autofilter(2, 0, rows.size + 2, columns.size - 1)
  end

  def write_cell(sheet, row, column, value, definition)
    case value
    when nil, ''
      nil
    when Numeric
      sheet.write_number(row, column, value.to_f, definition[:money] ? @format_money : @format_number)
    else
      sheet.write_string(row, column, value.to_s)
    end
  end
end
