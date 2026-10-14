# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Reads a client message the dispatcher pasted into the new job form, without
# any external service: a WhatsApp, Telegram or Avito chat, an SMS, an e-mail
# or several of them pasted one after another. It finds what a dispatch job
# needs - the client's phone numbers, name and address, the kind of work, the
# urgency and the wished visit day and time. Every value is a suggestion: the
# dispatcher checks the filled form before the job is created.
class DomServis::Intake::TextParser
  # Same names as the service tiles of the client request form, so jobs from
  # a pasted text and from the form read alike on the board.
  CATEGORIES = [
    ['Газовый котёл', %r{кот[её]л|котл[аеуоы]|горелк|теплообменник|отоплени}i],
    ['Бойлер, колонка', %r{бойлер|водонагреват|колонк}i],
    ['Бытовая техника', %r{стиральн|посудомо|холодильник|морозильн|(?<!\p{L})плит[аыуеой](?!\p{L})|варочн|духов|микроволн|сушильн}i],
    ['Электрика', %r{розетк|выключател|проводк|электрик|автомат|нет[ \t]+света|люстр|светильник|щиток|щитке}i],
    ['Сантехника', %r{сантех|смесител|(?<!\p{L})кран|унитаз|засор|канализац|раковин|сифон|(?<!\p{L})труб[аыуе]|радиатор|батаре|полотенцесуш|душев|ванн}i],
    ['Другое по дому', %r{(?<!\p{L})зам[ок]к|(?<!\p{L})двер|(?<!\p{L})окн[оа]|сборк|собрать|повесить|карниз|мелкий[ \t]+ремонт}i],
  ].freeze

  ISSUES = [
    ['Не греет', %r{не[ \t]+(?:гре[ею]т|нагрева)|холодн\p{L}*[ \t]+(?:батаре|радиатор)|(?:батаре|радиатор)\p{L}*[ \t]+холодн}i],
    ['Нет горячей воды', %r{нет[ \t]+горяч\p{L}*[ \t]+вод}i],
    ['Течёт', %r{теч[её]т|(?<!\p{L})теч[ьи](?!\p{L})|протек|протечк|капает|подтека}i],
    ['Не включается', %r{не[ \t]+(?:включа|запуска|работа)}i],
    ['Не зажигается', %r{не[ \t]+(?:зажига|разжига)|гаснет|тухнет}i],
    ['Шумит', %r{шумит|гудит|хлопа|стучит|свистит}i],
    ['Падает давление', %r{давлени\p{L}*[ \t]+(?:пада|упал)|пада\p{L}*[ \t]+давлени}i],
    ['Засор', %r{засор}i],
    ['Выбивает автомат', %r{выбива\p{L}*[ \t]+(?:автомат|пробк|узо)}i],
    ['Нет света', %r{нет[ \t]+света|пропал\p{L}*[ \t]+свет}i],
    ['Не сливает воду', %r{не[ \t]+слива}i],
    ['Плановое обслуживание', %r{(?i:обслуживан|чистк)|(?<!\p{L})ТО(?!\p{L})}],
    ['Установка или замена', %r{установ|подключ|замен|монтаж}i],
  ].freeze

  BRANDS = {
    'Baxi'       => %w[baxi бакси],
    'Navien'     => %w[navien навьен навиен],
    'Vaillant'   => %w[vaillant вайлант вайлан],
    'Buderus'    => %w[buderus будерус],
    'Bosch'      => %w[bosch бош],
    'Ariston'    => %w[ariston аристон],
    'Protherm'   => %w[protherm протерм],
    'Viessmann'  => %w[viessmann висман виссман],
    'Kiturami'   => %w[kiturami китурами],
    'Immergas'   => %w[immergas иммергаз],
    'Ferroli'    => %w[ferroli ферроли],
    'Beretta'    => %w[beretta беретта],
    'Junkers'    => %w[junkers юнкерс],
    'Rinnai'     => %w[rinnai риннай],
    'Daewoo'     => %w[daewoo дэу],
    'Kentatsu'   => %w[kentatsu кентатсу],
    'Electrolux' => %w[electrolux электролюкс],
    'Thermex'    => %w[thermex термекс],
    'Haier'      => %w[haier хайер],
    'Oasis'      => %w[oasis оазис],
    'Zanussi'    => %w[zanussi занусси],
    'Indesit'    => %w[indesit индезит],
    'Samsung'    => %w[samsung самсунг],
    'LG'         => %w[lg],
    'Whirlpool'  => %w[whirlpool вирлпул],
    'Gorenje'    => %w[gorenje горенье],
    'Candy'      => %w[candy канди],
    'Hotpoint'   => %w[hotpoint хотпоинт],
    'Beko'       => %w[beko беко],
    'Siemens'    => %w[siemens сименс],
    'Атлант'     => %w[атлант atlant],
    'Нева'       => %w[нева neva],
    'Лемакс'     => %w[лемакс lemax],
  }.freeze

  # Brands that make only gas boilers here: the brand alone tells the kind of work.
  BOILER_BRANDS = %w[Baxi Navien Vaillant Buderus Protherm Viessmann Kiturami Immergas Ferroli Beretta Junkers Rinnai Daewoo Kentatsu].freeze

  BRAND_PATTERNS = BRANDS.map do |brand, aliases|
    [brand, %r{(?<![\p{L}\d])(?:#{aliases.join('|')})(?!\p{L})(?<model>(?:[ \t]+[A-Za-z0-9][A-Za-z0-9+.-]*){0,3})}i]
  end.freeze

  # A Russian number with the 8/7/+7 prefix and ten digits, a mobile number
  # without the prefix, or another country's number written with a plus.
  PHONE_PATTERN = %r{
    (?<![\d+])
    (?:
      (?:\+\s?7|8|7)(?:[\s\-()]{0,3}\d){10}
      |
      \(?9\d{2}\)?(?:[\s\-]{0,3}\d){7}
      |
      \+\s?[1-689]\d{0,2}(?:[\s\-()]{0,3}\d){7,12}
    )
    (?!\d)
  }x

  # Chat headers carry the time a message was sent; they are not the wished
  # visit time and are left out before looking for dates and times.
  CHAT_HEADERS = [
    %r{^\[\d{1,2}[./]\d{1,2}[./]\d{2,4},?[ \t]+\d{1,2}:\d{2}(?::\d{2})?\][ \t]*[^:\n]{1,40}:[ \t]*}, # WhatsApp: [14.10.2026, 10:15] Ирина:
    %r{^\d{1,2}[./]\d{1,2}[./]\d{2,4},?[ \t]+\d{1,2}:\d{2}[ \t]+[-–][ \t]+[^:\n]{1,40}:[ \t]*},     # WhatsApp export: 14.10.2026, 10:15 - Ирина:
    %r{^[^,\n\[]{1,40},[ \t]*\[\d{1,2}[./]\d{1,2}[./]\d{2,4}[ \t]+\d{1,2}:\d{2}(?::\d{2})?\][ \t]*$}, # Telegram: Ирина, [14.10.2026 10:15]
  ].freeze

  NAME_WORD = '[А-ЯЁ][а-яё]+(?:-[А-ЯЁ][а-яё]+)?'.freeze

  NAME_PATTERNS = [
    %r{(?<!\p{L})(?:(?i:меня[ \t]+зовут|зовут|мо[её][ \t]+имя)[ \t]*[:\-–—,]?[ \t]*|(?i:имя|клиент|контакт(?:ное[ \t]+лицо)?|заказчик|покупатель|фио|ф\.и\.о\.)[ \t]*[:\-–—][ \t]*)(?<name>#{NAME_WORD}(?:[ \t]+#{NAME_WORD}){0,2})},
    %r{(?<!\p{L})(?i:это)[ \t]+(?<name>#{NAME_WORD})(?!\p{L})},
    %r{^[ \t]*(?<name>#{NAME_WORD}(?:[ \t]+#{NAME_WORD}){0,2})[ \t]*[,:\-–—]?[ \t]*(?:(?i:тел(?:ефон)?\.?)[ \t:]*)?(?=(?:\+[ \t]?7|8|7)[\s\-(]*\d)},
    %r{(?:\d[ \t\-)]*){10,11}[ \t]*[,\-–—]?[ \t]*(?<name>#{NAME_WORD}(?:[ \t]+#{NAME_WORD})?)[ \t]*$},
    %r{^\[[^\]\n]{6,25}\][ \t]*(?<name>[^:\n]{2,40}):},
    %r{^\d{1,2}[./]\d{1,2}[./]\d{2,4},?[ \t]+\d{1,2}:\d{2}[ \t]+[-–][ \t]+(?<name>[^:\n]{2,40}):},
    %r{^(?<name>[^,\n\[]{2,40}),[ \t]*\[\d{1,2}[./]\d{1,2}[./]\d{2,4}[ \t]+\d{1,2}:\d{2}},
  ].freeze

  KNOWN_CITIES = %w[
    Калининград Гурьевск Светлогорск Зеленоградск Пионерский Балтийск Светлый Черняховск Советск Гусев
    Багратионовск Полесск Правдинск Мамоново Ладушкин Янтарный Неман Озёрск Нестеров Славск Краснознаменск Приморск
  ].freeze

  NOT_A_NAME = (%w[
    Здравствуйте Добрый Доброе Привет Спасибо Пожалуйста Срочно Адрес Телефон Улица Котел Котёл Мастер
    Заявка Диспетчер Клиент Сегодня Завтра Послезавтра Ошибка Бойлер Колонка Сантехника Электрика
  ] + KNOWN_CITIES).freeze

  LABELLED_ADDRESS = %r{(?<!\p{L})(?:адрес(?:[ \t]+(?:клиента|выезда|объекта))?[ \t]*[:\-–—]|по[ \t]+адресу[ \t]*[:\-–—]?)[ \t]*(?<value>[^\n]+)}i

  STREET_MARKER = %r{(?<![\p{L}\d])(?:ул(?:ица|\.)?|пр(?:оспект|-т|-кт|осп\.?|\.)|пер(?:еулок|\.)?|бульвар|б-р|шоссе|ш\.|площадь|пл\.|наб(?:ережная|\.)?|мкр(?:н)?\.?|микрорайон|проезд|туп(?:ик|\.)|аллея|тракт|снт|днт)(?!\p{L})}i

  CITY_MARKER = %r{(?<![\p{L}\d])(?:(?i:г\.|гор\.|город|пос\.|пос[её]лок|п\.|пгт|дер\.|деревня)[ \t]*[А-ЯЁ]|(?:#{KNOWN_CITIES.join('|')})\p{L}{0,2}(?!\p{L}))}

  # A street without a marker: "Ленина 5-12", "Невского, 10".
  STREET_WITH_HOUSE = %r{(?<![\p{L}\d])[А-ЯЁ][а-яё]+(?:ая|ого|его|ова|ева|ина|ына|ской|цкой|ный|ной|ний|ский|цкий)[ \t]*,?[ \t]*(?:д(?:ом|\.)?[ \t]*)?\d{1,4}[а-яё]?(?:[ \t]*[/-][ \t]*\d{1,4})?(?![\d]|[ \t]*(?i:лет|год|руб|₽|квт|бар|°|градус|мин|час|шт))}

  ADDRESS_STOP = %r{(?<!\p{L})(?:тел(?:ефон|\.)?|моб(?:ильный|\.)?|имя|зовут|звон\p{L}*|контакт|код[ \t]+ошибки|ошибк\p{L}*|марка|модель)(?!\p{L})}i

  # Abbreviations whose period does not end the address.
  ADDRESS_ABBREVIATIONS = %w[ул д кв г гор пр просп пос п корп к стр эт под наб пер ш пл мкр мкрн тер туп пгт с дер б р].freeze

  ERROR_CODE_LABELLED = %r{(?<!\p{L})(?:ошибк\p{L}*|код[ \t]+ошибки|error|err)[ \t]*[:\-–№]?[ \t]*(?<code>[A-ZА-ЯЁ]{0,2}[ \t]?-?\d{1,3}[A-ZА-ЯЁ]?)(?![\p{L}\d])}i
  ERROR_CODE_BARE = %r{(?<![\p{L}\d])(?<code>[EFЕ][ \t]?-?\d{2,3})(?![\p{L}\d])}

  CRITICAL = %r{запах\p{L}*[ \t]+газ|пахнет[ \t]+газ|газом[ \t]+пахнет|утечк\p{L}*[ \t]+газ|авари|затоп|заливает|залил\p{L}*[ \t]+сосед|прорвал|прорыв|искрит|пожар|возгоран|плавит|задымл|(?<!\p{L})дым(?!\p{L})}i
  URGENT = %r{срочн|сегодня|как[ \t]+можно[ \t]+(?:скорее|быстрее)|побыстрее|не[ \t]+гре[ею]т|нет[ \t]+отоплени|нет[ \t]+горяч|холодно|замерза|реб[её]н|пожил|теч[её]т|(?<!\p{L})течь|протечк|капает}i

  RELATIVE_DAYS = [
    [%r{(?<!\p{L})послезавтра(?!\p{L})}i, 2],
    [%r{(?<!\p{L})завтра(?!\p{L})}i, 1],
    [%r{(?<!\p{L})сегодня(?!\p{L})}i, 0],
  ].freeze

  WEEKDAY_PATTERN = %r{(?<!\p{L})(?:в|во|на)[ \t]+(?<day>понедельник|вторник|среду|четверг|пятницу|субботу|воскресенье)(?!\p{L})}i
  WEEKDAY_NUMBERS = { 'понедельник' => 1, 'вторник' => 2, 'среду' => 3, 'четверг' => 4, 'пятницу' => 5, 'субботу' => 6, 'воскресенье' => 0 }.freeze

  NUMERIC_DATE = %r{(?<![\d.,])(?<!в[ \t]|к[ \t])(?<day>\d{1,2})\.(?<month>\d{2})(?:\.(?<year>\d{4}|\d{2}))?(?!\d|[.,]\d)}
  WORD_DATE = %r{(?<!\d)(?<day>\d{1,2})[ \t]+(?<month>январ|феврал|март|апрел|ма[йя]|июн|июл|август|сентябр|октябр|ноябр|декабр)\p{L}*}i
  MONTH_NUMBERS = {
    'январ'   => 1,
    'феврал'  => 2,
    'март'    => 3,
    'апрел'   => 4,
    'май'     => 5,
    'мая'     => 5,
    'июн'     => 6,
    'июл'     => 7,
    'август'  => 8,
    'сентябр' => 9,
    'октябр'  => 10,
    'ноябр'   => 11,
    'декабр'  => 12,
  }.freeze

  HOUR_PART = '(?<part>утра|дня|вечера|час\p{L}*|ч(?!\p{L}))'.freeze

  TIME_WINDOWS = [
    %r{(?<!\p{L})с[ \t]*(?<h1>\d{1,2})(?:[:.](?<m1>\d{2}))?[ \t]*(?:ч\.?|час\p{L}*)?[ \t]*до[ \t]*(?<h2>\d{1,2})(?:[:.](?<m2>\d{2}))?(?!\d)}i,
    %r{(?<![\d:.])(?<h1>\d{1,2})[:.](?<m1>\d{2})[ \t]*[-–—][ \t]*(?<h2>\d{1,2})[:.](?<m2>\d{2})(?!\d)},
    %r{(?<![\d:./])(?<h1>\d{1,2})[ \t]*[-–—][ \t]*(?<h2>\d{1,2})[ \t]*(?:ч(?!\p{L})|ч\.|час)}i,
  ].freeze

  EXACT_TIMES = [
    %r{(?<!\p{L})(?:в|к|на|около)[ \t]+(?<h1>\d{1,2})[:.](?<m1>\d{2})(?!\d)}i,
    %r{(?<!\p{L})(?:в|к|около)[ \t]+(?<h1>\d{1,2})[ \t]*#{HOUR_PART}}i,
    %r{(?<!\p{L})(?:к|около)[ \t]+(?<h1>\d{1,2})(?=[ \t]*(?:[,.!?;]|$))}i,
  ].freeze

  AFTER_TIME = %r{(?<!\p{L})после[ \t]+(?<h1>\d{1,2})(?:[:.](?<m1>\d{2}))?(?:[ \t]*#{HOUR_PART})?(?!\d|[.,]\d)}i
  BEFORE_TIME = %r{(?<!\p{L})до[ \t]+(?<h2>\d{1,2})(?:[:.](?<m2>\d{2}))?(?:[ \t]*#{HOUR_PART})?(?!\d|[.,]\d|[ \t]*(?i:этаж|лет|год|руб|кв|числ|мин))}i

  DAY_PARTS = [
    [%r{(?<!\p{L})после[ \t]+обеда(?!\p{L})}i, '13:00-17:00'],
    [%r{(?<!\p{L})(?:утром|с[ \t]+утра)(?!\p{L})}i, '08:00-12:00'],
    [%r{(?<!\p{L})(?:дн[её]м|в[ \t]+обед)(?!\p{L})}i, '12:00-16:00'],
    [%r{(?<!\p{L})вечером(?!\p{L})}i, '16:00-20:00'],
  ].freeze

  # The dispatcher calendar day (decision 2026-09-28: 08-20).
  DAY_START_HOUR = 8
  DAY_END_HOUR = 20

  VISIT_DAYS = %w[sun mon tue wed thu fri sat].freeze

  def initialize(text, today: Time.zone.today)
    @text = normalize_text(text)
    @body = strip_chat_headers(@text)
    @today = today
  end

  attr_reader :text, :body, :today

  def call
    name = extract_name
    visit_date = extract_visit_date

    {
      phones:       phones,
      client_phone: phones.first,
      client_name:  name,
      address:      extract_address(name),
      service_type: extract_service_type,
      priority:     extract_priority,
      visit_date:   visit_date&.iso8601,
      visit_day:    visit_date && VISIT_DAYS[visit_date.wday],
      visit_time:   extract_visit_time,
      description:  description,
    }
  end

  def phones
    @phones ||= text.scan(PHONE_PATTERN).filter_map { |candidate| normalize_found_phone(candidate) }.uniq
  end

  private

  def normalize_text(value)
    value.to_s
      .scrub('')
      .unicode_normalize(:nfc)
      .delete("​‎‏⁠﻿")
      .tr("   ", '   ')
      .gsub(%r{\r\n?}, "\n")
      .strip
  end

  def strip_chat_headers(value)
    CHAT_HEADERS.inject(value) { |result, pattern| result.gsub(pattern, '') }
  end

  def all_matches(pattern, source)
    source.enum_for(:scan, pattern).map { Regexp.last_match }
  end

  # Only Russian numbers of the 3xx/4xx/8xx/9xx ranges or a number written
  # with a foreign country code, so dates and order numbers are not taken.
  def normalize_found_phone(candidate)
    phone = DomServis::Dispatch::ClientResolver.normalize_phone(candidate.gsub(%r{[^\d+]}, ''))
    return if phone.blank?
    return phone if !phone.start_with?('+7')
    return phone if phone.length == 12 && '3489'.include?(phone[2])

    nil
  end

  def extract_name
    NAME_PATTERNS.each do |pattern|
      all_matches(pattern, text).each do |match|
        name = match[:name].to_s.squish
        return name if name?(name)
      end
    end

    nil
  end

  def name?(value)
    words = value.split
    return false if words.empty? || words.size > 3
    return false if NOT_A_NAME.include?(words.first)

    words.all? { |word| word.match?(%r{\A#{NAME_WORD}\z}) }
  end

  def extract_address(name)
    labelled = body.match(LABELLED_ADDRESS)
    if labelled
      value = clean_address(labelled[:value], name)
      return value if value.match?(%r{\d}) || value.match?(STREET_MARKER)
    end

    body.each_line do |line|
      start = [STREET_MARKER, CITY_MARKER].filter_map { |pattern| line.index(pattern) }.min
      next if start.nil?

      value = clean_address(line[start..], name)
      return value if value.match?(%r{\d})
    end

    start = body.index(STREET_WITH_HOUSE)
    start && clean_address(body[start..].lines.first, name).presence
  end

  # Cuts the address before the phone, the client name, a label like
  # "телефон" or the end of the sentence.
  def clean_address(value, name)
    fragment = value.to_s
    cuts = [fragment.index(PHONE_PATTERN), fragment.index(ADDRESS_STOP), sentence_end(fragment)]
    cuts << fragment.index(%r{[,;][ \t]*#{Regexp.escape(name.split.first)}(?!\p{L})}) if name.present?
    cut = cuts.compact.min
    fragment = fragment[0...cut] if cut

    fragment.squish.sub(%r{[\s,.;:\-–—]+\z}, '').truncate(200, omission: '')
  end

  def sentence_end(fragment)
    all_matches(%r{[.!?;](?=\s|\z)}, fragment).each do |match|
      position = match.begin(0)
      return position if match[0] != '.'

      word = fragment[0...position][%r{\p{L}+\z}].to_s.downcase
      return position if ADDRESS_ABBREVIATIONS.exclude?(word)
    end

    nil
  end

  def extract_service_type
    category = CATEGORIES.find { |_name, pattern| body.match?(pattern) }&.first
    issues = ISSUES.select { |_label, pattern| body.match?(pattern) }.map(&:first)
    code = error_code
    issues.unshift("Ошибка #{code}") if code
    brand = brand_model
    category ||= CATEGORIES.first.first if brand && BOILER_BRANDS.include?(brand.split.first)
    return if category.nil? && issues.empty? && brand.nil?

    label = category || 'Ремонт'
    label = "#{label}: #{issues.first(3).join(', ')}" if issues.any?
    label = "#{label} · #{brand}" if brand
    label
  end

  def error_code
    match = body.match(ERROR_CODE_LABELLED) || body.match(ERROR_CODE_BARE)
    return if !match

    match[:code].upcase.delete(" \t-").tr('АВЕКМНОРСТХ', 'ABEKMHOPCTX')
  end

  # A brand right after a street marker is a street name ("ул. Нева 1").
  def brand_model
    BRAND_PATTERNS.each do |brand, pattern|
      match = body.match(pattern)
      next if !match
      next if body[[match.begin(0) - 8, 0].max...match.begin(0)].match?(STREET_MARKER)

      model = match[:model].to_s.squish.delete_suffix('.')
      return [brand, model.presence].compact.join(' ')
    end

    nil
  end

  def extract_priority
    return 'critical' if body.match?(CRITICAL)
    return 'high' if body.match?(URGENT)

    nil
  end

  def extract_visit_date
    candidates = []

    RELATIVE_DAYS.each do |pattern, offset|
      match = body.match(pattern)
      candidates << [match.begin(0), today + offset] if match
    end

    weekday = body.match(WEEKDAY_PATTERN)
    candidates << [weekday.begin(0), next_weekday(WEEKDAY_NUMBERS[weekday[:day].downcase])] if weekday

    all_matches(NUMERIC_DATE, body).each do |match|
      date = build_date(match[:day], match[:month], match[:year])
      candidates << [match.begin(0), date] if date
    end

    all_matches(WORD_DATE, body).each do |match|
      date = build_date(match[:day], MONTH_NUMBERS[match[:month].downcase], nil)
      candidates << [match.begin(0), date] if date
    end

    candidates.min_by(&:first)&.last
  end

  def next_weekday(wday)
    days_ahead = (wday - today.wday) % 7
    today + (days_ahead.zero? ? 7 : days_ahead)
  end

  # Without a year the date is in the current year, unless it passed more
  # than a month ago - then it is next year's.
  def build_date(day, month, year)
    year = year.to_i
    year += 2000 if year.positive? && year < 100
    date = Date.new(year.positive? ? year : today.year, month.to_i, day.to_i)
    date = date.next_year if year.zero? && date < today - 30
    date
  rescue Date::Error
    nil
  end

  def extract_visit_time
    TIME_WINDOWS.each do |pattern|
      all_matches(pattern, body).each do |match|
        window = time_window([match[:h1], match[:m1]], [match[:h2], match[:m2]])
        return window if window
      end
    end

    exact_time || after_time || before_time || DAY_PARTS.find { |pattern, _window| body.match?(pattern) }&.last
  end

  def exact_time
    EXACT_TIMES.each do |pattern|
      all_matches(pattern, body).each do |match|
        part = match.names.include?('part') ? match[:part] : nil
        value = time_value(hour_with_part(match[:h1].to_i, part), match.names.include?('m1') ? match[:m1].to_i : 0)
        return value if value
      end
    end

    nil
  end

  def after_time
    match = body.match(AFTER_TIME)
    return if !match

    hour = hour_with_part(match[:h1].to_i, match[:part])
    start = time_value(hour, match[:m1].to_i)
    return if !start
    return start if hour >= DAY_END_HOUR

    "#{start}-#{time_value(DAY_END_HOUR, 0)}"
  end

  def before_time
    match = body.match(BEFORE_TIME)
    return if !match

    hour = hour_with_part(match[:h2].to_i, match[:part])
    return if hour <= DAY_START_HOUR || hour > 22

    finish = time_value(hour, match[:m2].to_i)
    finish && "#{time_value(DAY_START_HOUR, 0)}-#{finish}"
  end

  def hour_with_part(hour, part)
    part = part.to_s.downcase
    return hour + 12 if part.start_with?('вечер') && hour < 12
    return hour + 12 if part == 'дня' && hour < DAY_START_HOUR

    hour
  end

  def time_window(from, to)
    start = time_value(from[0].to_i, from[1].to_i)
    finish = time_value(to[0].to_i, to[1].to_i)
    return if !start || !finish || start >= finish

    "#{start}-#{finish}"
  end

  def time_value(hour, minute)
    return if !hour.between?(0, 23) || !minute.between?(0, 59)

    format('%<hour>02d:%<minute>02d', hour:, minute:)
  end

  def description
    body.lines.map(&:squish).compact_blank.join("\n").truncate(3000)
  end
end
