# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Turns a client message pasted on the dispatch board into a draft of the new
# job form and checks it (decision 2026-10-14: the AI prepares and checks the
# draft, a person creates the job).
#
# The text is read by the rules of DomServis::Intake::TextParser and, when an
# admin enabled it, by GigaChat. A value from GigaChat is used only when it is
# found in the text, so the model cannot slip in an invented phone or address.
# The checks compare the draft with the clients and open jobs in the database.
class DomServis::Intake::TextDraft
  MAX_LENGTH = 6000
  OPEN_STATUSES = %w[pool taken in_progress done].freeze
  PRIORITY_RANK = %w[low medium high critical].freeze
  STATUS_LABELS = {
    'pool'        => 'на стенде',
    'taken'       => 'взята мастером',
    'in_progress' => 'в работе',
    'done'        => 'выполнена, не закрыта',
  }.freeze

  DATE_HINT = %r{сегодня|завтра|понедельник|вторник|сред[уа]|четверг|пятниц|суббот|воскресен|\d{1,2}\.\d{1,2}|\d{1,2}[ \t]+(?:январ|феврал|март|апрел|ма[йя]|июн|июл|август|сентябр|октябр|ноябр|декабр)|числ}i
  TIME_HINT = %r{\d{1,2}[:.]\d{2}|утр|вечер|дн[её]м|обед|час|(?<!\p{L})(?:после|до|с|в|к)[ \t]+\d}i
  VISIT_TIME_FORMAT = %r{\A\d{2}:\d{2}(?:-\d{2}:\d{2})?\z}

  def initialize(text:, today: nil, ai_settings: nil)
    @text = text.to_s.strip
    @today = today || Time.use_zone(Setting.get('timezone_default').presence || 'UTC') { Time.zone.today }
    @ai_settings = ai_settings || DomServis::Intake::AISettings.current
    @checks = []
  end

  attr_reader :text, :today, :ai_settings, :checks

  def call
    rules = DomServis::Intake::TextParser.new(text, today:).call
    ai = ai_suggestion
    draft = merge(rules, ai || {})
    client = check_draft(draft, rules[:phones])
    Array(ai&.dig(:missing)).each { |item| add_check('info', nil, "Уточнить: #{item}") }

    {
      draft:  draft.compact,
      filled: draft.compact.keys,
      phones: rules[:phones],
      checks: checks,
      client: client,
      ai:     ai_status,
    }
  end

  private

  def add_check(level, field, message)
    checks << { level:, field:, text: message }
  end

  def ai_suggestion
    return if !ai_settings.usable?

    DomServis::Intake::AIParser.new(text:, today:, settings: ai_settings).call
  rescue DomServis::Intake::AIError => e
    @ai_error = e.message
    nil
  rescue => e
    Rails.logger.error "Dom-Servis text draft: AI reading failed: #{e.class}: #{e.message}"
    @ai_error = 'Ошибка при разборе ответа ИИ.'
    nil
  end

  def ai_status
    {
      enabled: ai_settings.usable?,
      used:    ai_settings.usable? && @ai_error.nil?,
      model:   ai_settings.usable? ? ai_settings.model : nil,
      error:   @ai_error,
    }
  end

  def merge(rules, suggestion)
    visit_date = ai_visit_date(suggestion[:visit_date], rules) || rules[:visit_date]
    draft = {
      client_phone: verified_phone(suggestion[:client_phone], rules[:phones]),
      client_name:  verified_name(suggestion[:client_name]) || rules[:client_name],
      address:      verified_address(suggestion[:address]) || rules[:address],
      service_type: suggestion[:service_type] || rules[:service_type],
      priority:     higher_priority(suggestion[:priority], rules[:priority]),
      visit_date:   visit_date,
      visit_day:    visit_date && DomServis::Intake::TextParser::VISIT_DAYS[Date.parse(visit_date).wday],
      visit_time:   ai_visit_time(suggestion[:visit_time], rules) || rules[:visit_time],
      description:  suggestion[:description] || rules[:description],
    }
    # The description leaves out the contacts and greetings; the job keeps
    # the whole message in case something was cut out by mistake.
    draft[:comment] = "Исходный текст:\n#{text}" if draft[:description] != text
    draft
  end

  # The digits of a phone from GigaChat have to be in the text.
  def verified_phone(value, phones)
    return phones.first if value.blank?

    phone = DomServis::Dispatch::ClientResolver.normalize_phone(value.to_s.gsub(%r{[^\d+]}, ''))
    return phone if phone && text.gsub(%r{\D}, '').include?(phone.last(10))

    add_check('warning', 'client_phone', "ИИ предложил номер #{value}, которого нет в тексте, — номер не подставлен.")
    phones.first
  end

  def verified_name(value)
    return if value.blank?
    return value if value.split.all? { |word| text.downcase.include?(word.downcase) }

    add_check('warning', 'client_name', "ИИ предложил имя «#{value}», которого нет в тексте, — имя не подставлено.")
    nil
  end

  # Every number of the address and at least one of its words (by the first
  # four letters, so "ул. Ленина" and "улица Ленина" both match) are in the text.
  def verified_address(value)
    return if value.blank?

    source = text.downcase
    numbers = value.scan(%r{\d+})
    words = value.downcase.scan(%r{\p{L}{4,}})
    return value if numbers.all? { |number| text.scan(%r{\d+}).include?(number) } && (words.empty? || words.any? { |word| source.include?(word.first(4)) })

    add_check('warning', 'address', 'Адрес от ИИ не найден в тексте — взят адрес, найденный по правилам.')
    nil
  end

  def higher_priority(*values)
    values.compact.select { |value| PRIORITY_RANK.include?(value) }.max_by { |value| PRIORITY_RANK.index(value) }
  end

  # A date from GigaChat counts only when the text speaks of a date at all.
  def ai_visit_date(value, rules)
    return if value.blank? || (rules[:visit_date].blank? && !text.match?(DATE_HINT))

    date = Date.iso8601(value)
    date.iso8601 if date.between?(today - 1, today + 120)
  rescue Date::Error
    nil
  end

  def ai_visit_time(value, rules)
    return if value.blank? || (rules[:visit_time].blank? && !text.match?(TIME_HINT))

    compact = value.delete(' ').tr('–—', '--')
    compact if compact.match?(VISIT_TIME_FORMAT)
  end

  def check_draft(draft, phones)
    check_phone(draft, phones)
    client = check_client(draft)
    add_check('warning', 'client_name', 'Имя клиента не найдено — спросите у клиента.') if draft[:client_name].blank?
    check_address(draft)
    add_check('warning', 'service_type', 'Не понятно, какие работы нужны, — укажите тип работ.') if draft[:service_type].blank?
    check_visit_date(draft)
    add_ai_check
    client
  end

  def check_phone(draft, phones)
    if draft[:client_phone].blank?
      add_check('error', 'client_phone', 'Телефон клиента не найден — без него заявку не создать.')
    elsif phones.size > 1
      add_check('warning', 'client_phone', "В тексте несколько номеров: #{phones.join(', ')}. Выбран #{draft[:client_phone]} — проверьте.")
    end
  end

  def check_address(draft)
    if draft[:address].blank?
      add_check('error', 'address', 'Адрес не найден — уточните у клиента.')
    elsif !draft[:address].match?(%r{\d})
      add_check('warning', 'address', 'В адресе нет номера дома.')
    end
  end

  def check_visit_date(draft)
    return if draft[:visit_date].blank? || Date.parse(draft[:visit_date]) >= today

    add_check('warning', 'visit_date', "Дата визита #{Date.parse(draft[:visit_date]).strftime('%d.%m.%Y')} уже прошла.")
  end

  def add_ai_check
    if @ai_error
      add_check('warning', nil, "ИИ не ответил: #{@ai_error} Поля заполнены по правилам — проверьте их.")
    elsif ai_settings.usable?
      add_check('ok', nil, "Текст проверен ИИ (#{ai_settings.model}).")
    end
  end

  # Looks the phone up among the clients and earlier jobs: a known client,
  # a phone shared by several clients, the last address, open jobs.
  def check_client(draft)
    phone = draft[:client_phone]
    return if phone.blank?

    users = DomServis::Dispatch::ClientResolver.users_with_phone(phone)
    jobs = jobs_for_phone(phone)
    check_users(draft, users)
    check_jobs(draft, jobs)
    return if users.empty? && jobs.empty?

    {
      name:         users.one? ? users.first.fullname : nil,
      jobs_count:   jobs.size,
      last_address: jobs.find { |job| job.address.present? }&.address,
    }
  end

  def check_users(draft, users)
    if users.empty?
      add_check('info', 'client_name', 'Новый клиент — он появится в базе, когда заявка будет создана.')
    elsif users.many?
      names = users.map { |user| "#{user.fullname} (##{user.id})" }.join(', ')
      add_check('error', 'client_phone', "Номер записан у нескольких клиентов: #{names}. Исправьте их карточки — иначе заявка не сохранится.")
    else
      known_client(draft, users.first)
    end
  end

  def known_client(draft, user)
    add_check('ok', 'client_name', "Клиент есть в базе: #{user.fullname}.")

    if draft[:client_name].blank?
      draft[:client_name] = user.fullname
    elsif !same_name?(draft[:client_name], user.fullname)
      add_check('warning', 'client_name', "В базе клиент записан как «#{user.fullname}», в тексте — «#{draft[:client_name]}».")
    end
  end

  def same_name?(left, right)
    left.downcase.split.intersect?(right.downcase.split)
  end

  def check_jobs(draft, jobs)
    last_address = jobs.find { |job| job.address.present? }&.address
    if last_address && normalized_address(last_address) != normalized_address(draft[:address])
      add_check('info', 'address', "Прошлый адрес клиента: #{last_address}.")
    end

    jobs.select { |job| OPEN_STATUSES.include?(job.status) }.first(3).each do |job|
      add_check('warning', nil, "У клиента уже есть открытая заявка № #{job.ticket&.number || job.job_code} (#{STATUS_LABELS[job.status]}): #{job.service_type}.")
    end
  end

  def normalized_address(value)
    value.to_s.downcase.gsub(%r{[^\p{L}\d]}, '')
  end

  # Jobs keep the phone as typed, so the database narrows them down by the
  # last ten digits and the exact normalization runs on these few.
  def jobs_for_phone(phone)
    DomServis::DispatchJob
      .where("RIGHT(REGEXP_REPLACE(COALESCE(client_phone, ''), '[^0-9]', '', 'g'), 10) = :tail", tail: phone.delete_prefix('+').last(10))
      .includes(:ticket)
      .reorder(created_at: :desc, id: :desc)
      .limit(50)
      .select { |job| DomServis::Dispatch::ClientResolver.normalize_phone(job.client_phone) == phone }
  end
end
