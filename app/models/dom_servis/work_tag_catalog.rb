# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The dictionary of work tags (decision 2026-10-24): the kind of work, the
# fault, the equipment, the brand and the area of a job, plus marks the
# dispatcher sets by hand. A job from a form or a pasted text gets its tags
# from the words of the request (see .infer); on the board any tag can be
# added or removed. The tags are ordinary Zammad tags, so the backing ticket
# carries the same ones.
class DomServis::WorkTagCatalog
  # The service tiles of the client request form and the categories of the
  # pasted text reader; a tag name must not contain a comma.
  DIRECTION_TAGS = {
    'Газовый котёл'   => 'Газовый котёл',
    'Бойлер, колонка' => 'Бойлер и колонка',
    'Сантехника'      => 'Сантехника',
    'Электрика'       => 'Электрика',
    'Бытовая техника' => 'Бытовая техника',
    'Другое по дому'  => 'Работы по дому',
  }.freeze

  # Faults and works the pasted text reader already finds, by its labels.
  READER_ISSUE_TAGS = {
    'Не греет'              => 'Не греет',
    'Нет горячей воды'      => 'Нет горячей воды',
    'Течёт'                 => 'Течёт',
    'Не включается'         => 'Не включается',
    'Не зажигается'         => 'Не зажигается',
    'Шумит'                 => 'Шумит',
    'Падает давление'       => 'Падает давление',
    'Засор'                 => 'Засор',
    'Выбивает автомат'      => 'Выбивает автомат',
    'Нет света'             => 'Нет света',
    'Не сливает воду'       => 'Не сливает воду',
    'Плановое обслуживание' => 'Плановое ТО',
  }.freeze

  WORK_TAGS = {
    'Диагностика'        => %r{диагност}i,
    'Ремонт'             => %r{ремонт|почин}i,
    'Плановое ТО'        => nil,
    'Установка'          => %r{установ|подключ|(?<!де)монтаж}i,
    'Замена'             => %r{замен}i,
    'Чистка'             => %r{чистк|почист|промыв|накип}i,
    'Демонтаж'           => %r{демонтаж}i,
    'Гарантийный случай' => %r{гаранти}i,
    'Повторный выезд'    => %r{повторн\p{L}*[ \t]+(?:выезд|визит|ремонт)|(?:снова|опять)[ \t]+(?:сломал|не[ \t]+работ)}i,
    'Консультация'       => %r{консультац}i,
  }.freeze

  FAULT_TAGS = {
    'Не греет'          => nil,
    'Нет горячей воды'  => nil,
    'Течёт'             => nil,
    'Не включается'     => nil,
    'Не зажигается'     => nil,
    'Ошибка на дисплее' => %r{ошибк}i,
    'Шумит'             => nil,
    'Падает давление'   => nil,
    'Засор'             => nil,
    'Выбивает автомат'  => nil,
    'Нет света'         => nil,
    'Не сливает воду'   => nil,
    'Не отжимает'       => %r{не[ \t]+отжима}i,
    'Не морозит'        => %r{не[ \t]+(?:морозит|холодит|охлажда)}i,
    'Запах газа'        => %r{запах\p{L}*[ \t]+газ|пахнет[ \t]+газ|утечк\p{L}*[ \t]+газ}i,
    'Искрит'            => %r{искрит|искра|запах\p{L}*[ \t]+гар|плав\p{L}*[ \t]+(?:провод|розетк|вилк)}i,
  }.freeze

  EQUIPMENT_TAGS = {
    'Бойлер'                => %r{бойлер|водонагреват}i,
    'Газовая колонка'       => %r{колонк}i,
    'Радиатор отопления'    => %r{радиатор|батаре}i,
    'Тёплый пол'            => %r{т[её]пл\p{L}*[ \t]+пол}i,
    'Смеситель и кран'      => %r{смесител|(?<!\p{L})кран}i,
    'Унитаз'                => %r{унитаз|бач[ое]к|инсталляц}i,
    'Канализация'           => %r{канализац|сифон}i,
    'Трубы'                 => %r{(?<!\p{L})труб}i,
    'Розетка и выключатель' => %r{розетк|выключател}i,
    'Светильник'            => %r{люстр|светильник|(?<!\p{L})ламп}i,
    'Электрощиток'          => %r{(?<!\p{L})(?:электро)?щит(?:ок|ке|ка|е|у)?(?!\p{L})}i,
    'Проводка'              => %r{проводк}i,
    'Стиральная машина'     => %r{стиральн|стиралк}i,
    'Посудомоечная машина'  => %r{посудомо}i,
    'Холодильник'           => %r{холодильн|морозильн}i,
    'Плита'                 => %r{(?<!\p{L})плит[аыуеой](?!\p{L})|варочн|конфорк}i,
    'Духовой шкаф'          => %r{духов}i,
    'Микроволновка'         => %r{микроволн|(?<!\p{L})свч(?!\p{L})}i,
    'Сушильная машина'      => %r{сушильн}i,
    'Двери и замки'         => %r{(?<!\p{L})зам(?:ок|к)|(?<!\p{L})двер}i,
    'Окна'                  => %r{(?<!\p{L})окн[оаеу]|(?<!\p{L})окон}i,
    'Мебель'                => %r{мебел|сборк|собрать}i,
    'Навес и крепёж'        => %r{повесить|закрепить|карниз|кронштейн}i,
  }.freeze

  # Read from the address: Gurievsk first (its district names contain
  # "Калининградская"), then the towns of the region, then the city.
  AREA_TAGS = {
    'Гурьевск'                => %r{гурьевск}i,
    'Калининградская область' => %r{зеленоградск|светлогорск|пионерск|балтийск|янтарн|черняховск|(?<!\p{L})гусев|багратионовск|гвардейск|полесск|мамоново|ладушкин|приморск|(?<!\p{L})неман|озерск|правдинск|славск|нестеров|краснознаменск}i,
    'Калининград'             => %r{калининград(?!ск)}i,
  }.freeze

  # Set by the dispatcher or the master by hand, never read from a text.
  MARK_TAGS = [
    'Ждёт запчасть',
    'Нужна смета',
    'Согласовать с клиентом',
    'Нужен второй выезд',
    'Юрлицо',
    'Постоянный клиент',
    'Жалоба',
  ].freeze

  GROUPS = [
    { key: 'direction', label: 'Направление', tags: DIRECTION_TAGS.values },
    { key: 'work', label: 'Вид работ', tags: WORK_TAGS.keys },
    { key: 'fault', label: 'Неисправность', tags: FAULT_TAGS.keys },
    { key: 'equipment', label: 'Оборудование', tags: EQUIPMENT_TAGS.keys },
    { key: 'brand', label: 'Марка', tags: DomServis::Intake::TextParser::BRANDS.keys },
    { key: 'area', label: 'Район', tags: AREA_TAGS.keys },
    { key: 'mark', label: 'Отметки', tags: MARK_TAGS },
  ].freeze

  NAMES = GROUPS.flat_map { |group| group[:tags] }.uniq.freeze

  OTHER_GROUP = { key: 'other', label: 'Другие теги' }.freeze

  TEXT_PATTERNS = WORK_TAGS.merge(FAULT_TAGS).merge(EQUIPMENT_TAGS).compact.freeze

  class << self
    def groups
      GROUPS.map { |group| group.slice(:key, :label).merge(tags: group[:tags].dup) }
    end

    def names
      NAMES
    end

    def include?(name)
      names.include?(name.to_s.strip)
    end

    def group_key(name)
      GROUPS.find { |group| group[:tags].include?(name.to_s.strip) }&.dig(:key) || OTHER_GROUP[:key]
    end

    # Tags for a request from its words (the kind of work and the client's
    # description, without contacts) and its address. The dispatcher checks
    # them on the board like every other value read from a text.
    def infer(text:, address: nil)
      body = text.to_s
      tags = []

      if body.present?
        profile = DomServis::Intake::TextParser.new(body).work_profile
        tile = DIRECTION_TAGS.keys.find { |category| body.start_with?(category) }
        # The tile name itself ("Бойлер, колонка") is not a word of the client.
        words = tile ? body.delete_prefix(tile) : body

        tags << DIRECTION_TAGS[tile || profile[:category]]
        tags.concat(profile[:issues].filter_map { |issue| reader_issue_tag(issue) })
        tags.concat(TEXT_PATTERNS.select { |_name, pattern| words.match?(pattern) }.keys)
        tags << profile[:brand]&.split&.first
      end

      tags << area_tag(address)
      ordered(tags.compact.uniq)
    end

    # Creates the Zammad tags of the dictionary that do not exist yet, so they
    # are listed in Manage > Tags; tags missing there are still valid and are
    # created with their first use on a ticket.
    def sync!
      names.each { |name| Tag::Item.lookup_by_name_and_create(name) }
    end

    private

    def reader_issue_tag(issue)
      return 'Ошибка на дисплее' if issue.start_with?('Ошибка ')

      READER_ISSUE_TAGS[issue]
    end

    def area_tag(address)
      return if address.blank?

      AREA_TAGS.find { |_name, pattern| address.to_s.match?(pattern) }&.first
    end

    def ordered(tags)
      tags.sort_by { |name| names.index(name) || names.size }
    end
  end
end
