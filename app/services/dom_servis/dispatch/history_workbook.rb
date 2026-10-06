# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The Excel file of a job history export: one row per event, oldest first,
# with the same Russian labels the board shows in the job card.
class DomServis::Dispatch::HistoryWorkbook
  HEADER = [
    { display: '№', width: 10 },
    { display: 'Дата и время', width: 20 },
    { display: 'Заявка', width: 16 },
    { display: 'Тикет', width: 12 },
    { display: 'Событие', width: 32 },
    { display: 'Кто', width: 24 },
    { display: 'Подробности', width: 90 },
  ].freeze

  EVENT_LABELS = {
    'created'              => 'Заявка создана',
    'published'            => 'Опубликована на стенд',
    'taken'                => 'Взята мастером',
    'assigned'             => 'Назначен мастер',
    'released'             => 'Возвращена на стенд',
    'status_changed'       => 'Изменён статус',
    'moved_weekday'        => 'Перенесён день визита',
    'priority_changed'     => 'Изменён приоритет',
    'organization_changed' => 'Изменён заказчик',
    'comment_added'        => 'Изменён комментарий диспетчера',
    'description_updated'  => 'Изменено описание',
    'tags_changed'         => 'Изменены теги работ',
    'attachment_added'     => 'Добавлено вложение',
    'attachment_removed'   => 'Удалено вложение',
    'updated'              => 'Изменены данные заявки',
    'ai_parsed'            => 'Заявка разобрана автоматически',
    'deleted'              => 'Заявка удалена',
  }.freeze

  FIELD_LABELS = {
    'job_code'          => 'Номер заявки',
    'ticket_number'     => 'Тикет',
    'source'            => 'Источник',
    'status'            => 'Статус',
    'priority'          => 'Приоритет',
    'visit_day'         => 'День недели',
    'visit_date'        => 'Дата визита',
    'visit_time'        => 'Время визита',
    'address'           => 'Адрес',
    'client_name'       => 'Клиент',
    'client_phone'      => 'Телефон',
    'service_type'      => 'Тип работ',
    'description'       => 'Описание задачи',
    'comment'           => 'Комментарий диспетчера',
    'work_tags'         => 'Теги работ',
    'assignee_id'       => 'Исполнитель',
    'assignee_name'     => 'Исполнитель',
    'organization_id'   => 'Заказчик',
    'attachment_id'     => 'Вложение',
    'kind'              => 'Тип вложения',
    'filename'          => 'Файл',
    'request_source_id' => 'Источник заявок',
    'channel_key'       => 'Канал',
    'source_reference'  => 'Внешний номер',
  }.freeze

  STATUS_LABELS = {
    'pool'                   => 'На стенде',
    'taken'                  => 'Взята',
    'in_progress'            => 'В работе',
    'done'                   => 'Готово',
    'closed'                 => 'Закрыта',
    'cancelled'              => 'Отменена',
    'transferred_to_partner' => 'Передана партнёру',
  }.freeze

  PRIORITY_LABELS = {
    'low'      => 'Низкий',
    'medium'   => 'Средний',
    'high'     => 'Высокий',
    'critical' => 'Критичный',
  }.freeze

  SOURCE_LABELS = {
    'manual'  => 'Вручную',
    'form'    => 'Форма Zammad',
    'email'   => 'Email',
    'webhook' => __('Webhook / API'),
    'ai'      => __('AI / разбор'),
  }.freeze

  # The field whose from/to an event's meta carries.
  EVENT_FIELDS = {
    'status_changed'       => 'status',
    'priority_changed'     => 'priority',
    'moved_weekday'        => 'visit_day',
    'organization_changed' => 'organization_id',
    'tags_changed'         => 'work_tags',
    'assigned'             => 'assignee_id',
    'released'             => 'assignee_id',
    'comment_added'        => 'comment',
    'description_updated'  => 'description',
  }.freeze

  attr_reader :export, :locale, :timezone

  def initialize(export:, locale:)
    @export             = export
    @locale             = locale
    @timezone           = Setting.get('timezone_default').presence || 'UTC'
    @user_names         = {}
    @organization_names = {}
  end

  def content
    ExcelSheet.new(title:, header: HEADER, records: rows, locale:, timezone:).content
  end

  def rows
    @rows ||= export.events.includes(:actor_user, dispatch_job: :ticket).find_each.map { |event| row(event) }
  end

  def row_count
    rows.size
  end

  def filename
    "dom-servis-history-#{export.created_at.in_time_zone(timezone).strftime('%Y-%m-%d')}.xlsx"
  end

  def details(event)
    meta  = (event.meta || {}).to_h.deep_stringify_keys
    field = EVENT_FIELDS[event.event_type]
    parts = []

    if meta['changes'].is_a?(Hash)
      ordered(meta['changes']).each { |name, change| parts << change_text(name, change) }
      meta = meta.except('changes')
    end

    if field && (meta.key?('from') || meta.key?('to') || meta.key?(field))
      parts << change_text(field, { 'from' => meta['from'], 'to' => meta.key?('to') ? meta['to'] : meta[field] })
      meta = meta.except('from', 'to', field)
    end

    ordered(meta).each do |name, value|
      parts << (transition?(value) ? change_text(name, value) : "#{label(name)}: #{value_text(name, value)}")
    end

    parts.join('; ')
  end

  private

  def title
    "История заявок Дом-Сервис, выгрузка от #{format_time(export.created_at)}"
  end

  def row(event)
    [
      event.id,
      format_time(event.created_at),
      event.job_code || event.dispatch_job&.job_code || '',
      ticket_number(event),
      EVENT_LABELS.fetch(event.event_type, event.event_type),
      event.actor_user&.fullname || '',
      details(event),
    ]
  end

  def ticket_number(event)
    (event.dispatch_job&.ticket&.number || event.meta.to_h.stringify_keys['ticket_number']).to_s
  end

  def format_time(time)
    time.in_time_zone(timezone).strftime('%Y-%m-%d %H:%M:%S')
  end

  # jsonb does not keep the key order; fields follow FIELD_LABELS, unknown
  # ones come last by name.
  def ordered(hash)
    hash.sort_by { |name, _value| [FIELD_LABELS.keys.index(name.to_s) || FIELD_LABELS.size, name.to_s] }
  end

  def transition?(value)
    value.is_a?(Hash) && (value.key?('from') || value.key?('to'))
  end

  def change_text(name, change)
    change = change.to_h.stringify_keys
    "#{label(name)}: #{value_text(name, change['from'])} → #{value_text(name, change['to'])}"
  end

  def label(name)
    FIELD_LABELS.fetch(name.to_s, name.to_s)
  end

  def value_text(name, value)
    case value
    when nil, '', []
      '—'
    when Array
      value.map { |item| value_text(name, item) }.join(', ')
    when Hash
      value.map { |key, item| "#{label(key)}: #{value_text(key, item)}" }.join(', ')
    else
      scalar_text(name.to_s, value)
    end
  end

  def scalar_text(name, value)
    case name
    when 'status'          then STATUS_LABELS.fetch(value.to_s, value.to_s)
    when 'priority'        then PRIORITY_LABELS.fetch(value.to_s, value.to_s)
    when 'source'          then SOURCE_LABELS.fetch(value.to_s, value.to_s)
    when 'visit_day'       then DomServis::DispatchJob::VISIT_DAY_LABELS.fetch(value.to_s, value.to_s)
    when 'assignee_id'     then user_name(value)
    when 'organization_id' then organization_name(value)
    else value.to_s
    end
  end

  def user_name(id)
    @user_names[id] ||= User.find_by(id:)&.fullname || "##{id}"
  end

  def organization_name(id)
    @organization_names[id] ||= Organization.find_by(id:)&.name || "##{id}"
  end
end
