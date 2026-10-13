# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Turns a pasted request message into a draft of the board's create form:
# an SMS, a messenger text or a phone secretary transcript that carries the
# address, phone, client name, equipment with its model and the fault in any
# order. The work is split into positions: work type, equipment and fault.
#
# Rules, not a language model: a field the rules do not recognise stays empty
# and is listed in #missing. The dispatcher checks the draft before publishing;
# nothing here creates a job.
class DomServis::Intake::TextParser
  MAX_INPUT_LENGTH = 5000

  # The fields the dispatcher fills first. The ones the text does not give are
  # reported, so the form can point at them.
  KEY_FIELDS = %i[client_phone address client_name work_type equipment fault].freeze

  # The "Вид работ" positions; the create form offers the same list.
  WORK_TYPES = [
    'Котлы и отопление', 'Водонагреватели и колонки', 'Сантехника', 'Электрика',
    'Бытовая техника', 'Кондиционеры', 'Мелкий ремонт'
  ].freeze

  # Consumed parts of the text are overwritten with this character, which keeps
  # offsets stable and stops later rules from joining words across the gap.
  GAP = '|'.freeze

  ROBOT_MARK = "\u{1F916}".freeze
  HUMAN_MARK = %r{\A\u{1F464}\u{FE0F}?\s*:?\s*}

  # Service lines of the phone secretary transcript (T-Bank and alike) and bare
  # greetings carry nothing for the job.
  NOISE_LINE = %r{
    \A(?:
      прослушать\s+сообщение |
      звонили\s+с\s+этого\s+номера |
      этот\s+абонент\s+звонил |
      \[?\s*абонент\s+положил\s+трубку |
      (?:ал+о[\s,.!?]*)+\z
    )
  }xi

  PHONE_CANDIDATE = %r{(?<![\d+])\+?\d[\d \-‒–—()]{8,18}\d(?!\d)}
  PHONE_LABEL     = %r{(?:тел(?:ефон|\.)?|моб(?:ильный|\.)?|номер|т\.)\s*[:\-–]?\s*\z}i

  # A house number, optionally announced by "д."/"дом". The lookahead skips
  # numbers that are times, dates, decimals or quantities.
  HOUSE = %r{
    (?<![[:alnum:]])
    (?<dom>(?:д|дом)\.?\s*(?:№\s*)?)?
    (?<house>[1-9]\d{0,3}(?:\s?[а-яa-z](?![[:alpha:]]))?(?:\s?/\s?\d{1,4}[а-я]?)?)
    (?!\d|[:.,]\d|[[:alpha:]&&[^кК]]|\s*(?:час|ч\b|мин|утра|дня|вечера|ночи|лет|год|руб|р\b|шт|раз|квт|бар|градус|°|%|-?(?:й|го|ый|ой)\b))
  }xi

  ADDRESS_PARTS = [
    [:flat,     'кв.',     %r{\A(?:кв(?:артира|\.)?|квар\.?)\s*№?\s*(\d{1,4}[а-я]?)(?![[:alnum:]])}i],
    [:korpus,   'корп.',   %r{\A(?:корп(?:ус)?\.?|к\.?)\s*(\d{1,3}[а-я]?)(?![[:alnum:]])}i],
    [:building, 'стр.',    %r{\A(?:стр(?:оение)?\.?)\s*(\d{1,3}[а-я]?)(?![[:alnum:]])}i],
    [:entrance, 'подъезд', %r{\A(?:(?:подъезд|под\.|п\.)\s*№?\s*(\d{1,2})|(?:в\s+)?(\d{1,2})\s*-?(?:й|ый|ой|м|ем)?\s*подъезд[еа]?)(?![[:alnum:]])}i],
    [:floor,    'этаж',    %r{\A(?:(?:этаж[еа]?|эт\.?)\s*(\d{1,3})|(?:на\s+)?(\d{1,3})\s*-?(?:й|ый|ой|м|ем)?\s*(?:этаж[еа]?|эт\b\.?))(?![[:alnum:]])}i],
    [:office,   'офис',    %r{\A(?:офис|оф\.)\s*№?\s*(\d{1,4}[а-я]?)(?![[:alnum:]])}i],
  ].freeze
  ADDRESS_PART_ORDER = %i[korpus building flat entrance floor office].freeze

  STREET_TYPES = [
    ['ул.',    %r{\A(?:ул|улица|улице|улицу|улицы)\z}],
    ['пр-т',   %r{\A(?:пр|пр-т|пр-кт|просп|проспект|проспекте)\z}],
    ['пер.',   %r{\A(?:пер|переулок|переулке)\z}],
    ['б-р',    %r{\A(?:б-р|бул|бульвар|бульваре)\z}],
    ['ш.',     %r{\A(?:ш|шоссе)\z}],
    ['пл.',    %r{\A(?:пл|площадь|площади)\z}],
    ['наб.',   %r{\A(?:наб|набережная|набережной)\z}],
    ['проезд', %r{\A(?:пр-д|проезд|проезде)\z}],
    ['туп.',   %r{\A(?:туп|тупик)\z}],
    ['мкр',    %r{\A(?:мкр|мкрн|микрорайон|микрорайоне)\z}],
    ['аллея',  %r{\A(?:аллея|аллее)\z}],
    ['тракт',  %r{\A(?:тракт)\z}],
  ].freeze

  # Words that end the street name when reading back from the house number.
  STREET_STOP_WORDS = %w[
    в во на по к ко у из от до для за около возле напротив и а или но с со
    адрес адреса адресу дом д кв квартира подъезд этаж корпус
    нужно надо срочно пожалуйста позвоните позвонить приехать
    котел котла котлу бойлер колонка кран ошибка код давление модель марка
    стиральная машина холодильник кондиционер плита розетка счетчик смеситель унитаз
  ].freeze
  STREET_STOP_ENDINGS = %r{(?:ть|ться|тся|ает|яет|ует|ите)\z}
  STREET_NUMBER       = %r{\A\d{1,2}(?:-?[а-я]{1,2})?\z}
  MAX_STREET_WORDS    = 3

  # How far back from a match the street name and the phone label are looked
  # for; bounds the work per match on long pasted texts.
  LOOKBEHIND_CHARS = 80
  PART_WINDOW_CHARS = 40

  # Equipment the text names, checked in this order, with its work type. The
  # first one found wins, so a leaking boiler is a boiler job, not plumbing.
  EQUIPMENT = [
    ['Котёл',                'Котлы и отопление',         %r{котел|котл[аеуыо]|электрокот}],
    ['Газовая колонка',      'Водонагреватели и колонки', %r{колонк}],
    ['Водонагреватель',      'Водонагреватели и колонки', %r{бойлер|водонагрев}],
    ['Стиральная машина',    'Бытовая техника',           %r{стиральн|стиралк}],
    ['Посудомоечная машина', 'Бытовая техника',           %r{посудомо|посудомойк}],
    ['Сушильная машина',     'Бытовая техника',           %r{сушильн}],
    ['Холодильник',          'Бытовая техника',           %r{холодильн}],
    ['Морозильник',          'Бытовая техника',           %r{морозильн}],
    ['Варочная панель',      'Бытовая техника',           %r{варочн}],
    ['Духовой шкаф',         'Бытовая техника',           %r{духов}],
    ['Плита',                'Бытовая техника',           %r{\bплит[аеуы]\b}],
    ['Микроволновка',        'Бытовая техника',           %r{микроволн|\bсвч\b}],
    ['Вытяжка',              'Бытовая техника',           %r{вытяжк}],
    ['Кондиционер',          'Кондиционеры',              %r{кондиционер|сплит}],
    ['Тёплый пол',           'Котлы и отопление',         %r{тепл(?:ый|ого|ом)\s+пол}],
    ['Радиатор',             'Котлы и отопление',         %r{радиатор|батаре}],
    ['Насос',                'Котлы и отопление',         %r{насос}],
    ['Счётчик воды',         'Сантехника',                %r{счетчик}],
    ['Смеситель',            'Сантехника',                %r{смесител}],
    ['Унитаз',               'Сантехника',                %r{унитаз}],
    ['Раковина',             'Сантехника',                %r{раковин}],
    ['Полотенцесушитель',    'Сантехника',                %r{полотенцесуш}],
    ['Кран',                 'Сантехника',                %r{(?<![[:alpha:]])кран}],
    ['Розетка',              'Электрика',                 %r{розетк}],
    ['Выключатель',          'Электрика',                 %r{выключател}],
    ['Светильник',           'Электрика',                 %r{люстр|светильник}],
    ['Электрощиток',         'Электрика',                 %r{щиток}],
  ].freeze

  # The work type of a text that names no equipment.
  WORK_TYPE_WORDS = [
    ['Котлы и отопление', %r{отоплени|запах\s+газа|пахнет\s+газ|газом\s+пахн}],
    ['Сантехника',        %r{сантех|засор|канализ|\bтруб[аеыу]?\b|сифон|водопровод|теч[её]т|протек|протечк|капа[ею]т}],
    ['Электрика',         %r{электри|проводк|\bсвет[аеу]?\b|автомат}],
    ['Бытовая техника',   %r{бытов\S*\s+техник|не\s+(?:слива|отжима|набира)|барабан}],
    ['Мелкий ремонт',     %r{повесить|собрать|сборк|карниз|\bполк[аиу]\b|замок|замк[аи]}],
  ].freeze

  # Faults and kinds of work, in the order they are listed.
  FAULTS = [
    ['пахнет газом',      %r{запах\s+газа|пахнет\s+газ|газом\s+пахн}],
    ['плата управления',  %r{мозг|\bплат[аеуы]\b|электроник}],
    ['не греет',          %r{не\s+гре(?:ет|ют)|не\s+нагрева}],
    ['нет горячей воды',  %r{нет\s+горяч}],
    ['не холодит',        %r{не\s+(?:холод|мороз|охлажда)}],
    ['не сливает воду',   %r{не\s+слива}],
    ['не набирает воду',  %r{не\s+набира}],
    ['не отжимает',       %r{не\s+отжима}],
    ['не крутит барабан', %r{не\s+крут|барабан\s+не}],
    ['не включается',     %r{не\s+(?:включа|запуска|зажига|разжига)}],
    ['не работает',       %r{не\s+работа}],
    ['нет света',         %r{нет\s+свет|не\s+горит\s+свет}],
    ['искрит',            %r{искрит}],
    ['выбивает автомат',  %r{выбива}],
    ['течёт',             %r{теч[её]т|теку|протека|протечк|капа[ею]т|подтека}],
    ['падает давление',   %r{давлени}],
    ['шумит',             %r{шум|хлопа|гудит|стучит|свистит|вибрир}],
    ['засор',             %r{засор}],
    ['обслуживание',      %r{обслуживан}],
    ['чистка',            %r{чистк|почистить|промывк}],
    ['диагностика',       %r{диагност}],
    ['демонтаж',          %r{демонтаж}],
    ['установка',         %r{установ|подключ|(?<!де)монтаж}],
    ['замена',            %r{замен|поменя}],
  ].freeze
  MAX_FAULTS = 3

  ERROR_CODE = %r{(?:ошибк[аиуе]?|код)\s*[:№#-]?\s*([a-zа-я]{1,2}\s?-?\d{1,3}|\d{1,3})(?![[:alnum:]])}i
  BARE_ERROR_CODE = %r{(?<![[:alnum:]])([efе]\d{2,3})(?![[:alnum:]])}i
  CODE_LOOKALIKES = %w[А A В B Е E К K М M Н H О O Р P С C Т T Х X].each_slice(2).to_h.freeze

  # Canonical brand name and its spellings. Brands that make one kind of
  # equipment also give the equipment and work type when the text names none;
  # brands of several kinds (Bosch: boilers and washing machines) do not.
  BOILER = ['Котёл', 'Котлы и отопление'].freeze
  HEATER = ['Водонагреватель', 'Водонагреватели и колонки'].freeze
  BRANDS = [
    ['Baxi',           %w[baxi бакси],                BOILER],
    ['Beretta',        %w[beretta берета беретта],    BOILER],
    ['Vaillant',       %w[vaillant вайлант ваилант],  BOILER],
    ['Buderus',        %w[buderus будерус],           BOILER],
    ['Navien',         %w[navien навьен навиен],      BOILER],
    ['Protherm',       %w[protherm протерм],          BOILER],
    ['Viessmann',      %w[viessmann висман виссман],  BOILER],
    ['Immergas',       %w[immergas иммергаз имергаз], BOILER],
    ['Ferroli',        %w[ferroli ферроли],           BOILER],
    ['Kiturami',       %w[kiturami китурами],         BOILER],
    ['Rinnai',         %w[rinnai риннай],             BOILER],
    ['Junkers',        %w[junkers юнкерс],            BOILER],
    ['Lemax',          %w[lemax лемакс],              BOILER],
    ['Thermex',        %w[thermex термекс],           HEATER],
    ['Bosch',          %w[bosch бош]],
    ['Ariston',        %w[ariston аристон]],
    ['Electrolux',     %w[electrolux электролюкс]],
    ['Daewoo',         %w[daewoo дэу]],
    ['Kentatsu',       %w[kentatsu кентатсу]],
    ['Neva',           %w[neva]],
    ['Haier',          %w[haier хаер хайер]],
    ['Samsung',        %w[samsung самсунг]],
    ['LG',             %w[lg]],
    ['Indesit',        %w[indesit индезит]],
    ['Atlant',         %w[atlant атлант]],
    ['Candy',          %w[candy канди]],
    ['Zanussi',        %w[zanussi занусси]],
    ['Hotpoint',       %w[hotpoint хотпоинт]],
    ['Whirlpool',      %w[whirlpool вирпул]],
    ['Beko',           %w[beko беко]],
    ['Gorenje',        %w[gorenje горенье]],
    ['Siemens',        %w[siemens сименс]],
    ['Miele',          %w[miele миле]],
    ['Midea',          %w[midea мидея]],
    ['Hansa',          %w[hansa ханса]],
    ['Weissgauff',     %w[weissgauff вайсгауф]],
    ['Daikin',         %w[daikin дайкин]],
    ['Mitsubishi',     %w[mitsubishi мицубиси]],
    ['Ballu',          %w[ballu баллу]],
    ['Gree',           %w[gree]],
  ].map { |brand, spellings, kind| [brand, %r{(?<![[:alpha:]])(?:#{spellings.join('|')})(?![[:alpha:]])}i, kind] }.freeze
  MODEL_TOKENS = %r{\A(?: +[A-Za-z0-9][A-Za-z0-9.+/-]*(?![A-Za-z0-9.+/-])(?!\s*(?:квт|kw\b|л\b|литр))){1,4}}i
  NOT_A_MODEL = %w[ok ок whatsapp viber telegram tg wa sms www id].freeze
  # A model of a brand the list does not know: Latin words in the text,
  # starting with a word of two letters or more ("Weissgauff WM 4947").
  LATIN_MODEL = %r{(?<![A-Za-z0-9])[A-Za-z][A-Za-z0-9.+/-]+(?: +[A-Za-z0-9][A-Za-z0-9.+/-]*(?![A-Za-z0-9.+/-])(?!\s*(?:квт|kw\b|л\b|литр))){0,3}}

  NAME_WORD  = %r{[А-ЯЁ][а-яё]+(?:-[А-ЯЁ][а-яё]+)?}
  NAME_LABEL = %r{(?i:имя|клиент(?:ка)?|заказчик|контакт(?:ное\s+лицо)?|зовут|спросить)\s*[:\-–]?\s*(#{NAME_WORD}(?: +#{NAME_WORD}){0,2})}
  NAME_WORD_PATTERN = %r{(?<![[:alpha:]])#{NAME_WORD}(?![[:alpha:]])}
  PATRONYMIC = %r{\A[А-ЯЁ][а-яё]+(?:вич|вна|чна|ична)\z}
  SURNAME    = %r{\A[А-ЯЁ][а-яё]+(?:ов|ова|ев|ева|ёв|ёва|ин|ина|ын|ына|ский|ская|цкий|цкая|ко|ук|юк|ян|дзе|швили)\z}
  NAME_TAIL  = Regexp.union(PATRONYMIC, SURNAME)
  FIRST_NAMES = %w[
    Александр Алексей Анатолий Андрей Антон Аркадий Арсений Артём Артем Артур Богдан Борис Вадим
    Валентин Валерий Василий Виктор Виталий Владимир Владислав Вячеслав Георгий Геннадий Глеб
    Григорий Давид Даниил Денис Дмитрий Евгений Егор Захар Иван Игорь Илья Кирилл Константин Лев
    Леонид Максим Марк Матвей Михаил Никита Николай Олег Павел Пётр Петр Роман Руслан Семён Семен
    Сергей Станислав Степан Тимофей Тимур Фёдор Федор Эдуард Юрий Ярослав Рустам Ринат Марат Ильдар
    Азат Айдар Камиль Магомед Мурат Расул Шамиль Тагир Эльдар Рамиль Равиль Саша Лёша Леша Дима
    Серёжа Сережа Коля Миша Паша Петя Ваня Витя Женя Костя Слава Толя Юра Вова Володя Гена Валера
    Стас Влад Макс Рома
    Александра Алла Алёна Алена Алина Алиса Анастасия Ангелина Анна Антонина Валентина Валерия Вера
    Вероника Виктория Галина Дарья Диана Ева Евгения Екатерина Елена Елизавета Жанна Зинаида Зоя Инна
    Ирина Карина Кира Кристина Ксения Лариса Лидия Лилия Любовь Людмила Маргарита Марина Мария Милана
    Надежда Наталья Наталия Нина Оксана Олеся Ольга Полина Раиса Регина Светлана София Софья Тамара
    Татьяна Ульяна Юлия Яна Эльвира Гульнара Альбина Зульфия Лейла Луиза Фатима Аня Катя Лена Таня
    Наташа Оля Света Маша Юля Галя Люда Ира Вика Даша Настя Ксюша Валя Люба Надя Лиза Соня
  ].to_set.freeze

  RELATIVE_DAYS = [['послезавтра', 2], ['завтра', 1], ['сегодня', 0]].freeze
  WEEKDAYS = [
    [1, %r{\bпонедельник}], [2, %r{\bвторник}], [3, %r{\bсред[уа]\b}], [4, %r{\bчетверг}],
    [5, %r{\bпятниц}], [6, %r{\bсуббот}], [0, %r{\bвоскресень}],
  ].freeze
  MONTHS = %w[январ феврал март апрел ма июн июл август сентябр октябр ноябр декабр].freeze
  NUMERIC_DATE = %r{(?<![\d.,])(\d{1,2})[./](\d{2})(?:[./](\d{4}|\d{2}))?(?!\d|[.:]\d)}
  WORD_DATE    = %r{(?<!\d)(\d{1,2})\s+(январ|феврал|март|апрел|ма[яй]|июн|июл|август|сентябр|октябр|ноябр|декабр)[а-я]*}

  TIME_WINDOWS = [
    %r{(?<![[:alnum:]])(?:с|от)\s*(\d{1,2})(?:[:.-](\d{2}))?\s*(?:ч(?:ас(?:ов|а)?)?\.?\s*)?(?:до|по|-|–)\s*(\d{1,2})(?:[:.-](\d{2}))?(?!\d)}i,
    %r{(?<![\d:])(\d{1,2})[:.](\d{2})\s*[-–]\s*(\d{1,2})[:.](\d{2})(?!\d)},
  ].freeze
  CLOCK_TIME    = %r{(?<![\d:.])(\d{1,2}):(\d{2})(?!\d)}
  SUFFIXED_HOUR = %r{(?<![[:alnum:]])(?:в|к|около)\s+(\d{1,2})(?:[.-](\d{2}))?\s*(утра|дня|вечера|ночи|час(?:а|ов)?|ч\.?)(?![[:alpha:]])}i
  BARE_HOUR     = %r{(?<![[:alnum:]])(?:в|к|около)\s+(\d{1,2})(?=\s*(?:[,;!?|\n]|\.(?!\d)|\z))}i

  CRITICAL = %r{авари|затоп|залива|прорвал|прорыв|запах\s+газа|пахнет\s+газ|газом\s+пахн|утечк|искрит|задымлен}
  HIGH     = %r{срочн|как\s+можно\s+скорее|побыстрее|сегодня\s+же|замерза}

  def initialize(text, today:)
    @lines = clean_lines(text)
    @text  = @lines.join("\n")
    @rest  = @text.dup
    @match = @text.downcase.tr('ё', 'е')
    @today = today
  end

  def draft
    @draft ||= begin
      # Order matters: the phone and the address are cut out of the rest before
      # the name, date and time are read, so their digits and street names
      # cannot pass for a date or a client.
      result = {
        client_phone: extract_phone,
        address:      extract_address,
      }
      result[:client_name] = extract_name
      result.merge!(work_positions)
      result[:description] = @text.presence
      result[:priority] = priority

      if (visit_date = extract_date)
        result[:visit_date] = visit_date.iso8601
        result[:visit_day]  = DomServis::DispatchSchedule.weekday_key(visit_date)
      end
      result[:visit_time] = extract_time

      result.compact
    end
  end

  def missing
    KEY_FIELDS.select { |field| draft[field].blank? }
  end

  # The job title the board shows: "Котлы и отопление: Котёл Baxi — Не греет".
  # The create form builds it from the same three positions.
  def self.service_type_for(work_type, equipment, fault)
    title = [work_type, equipment].compact_blank.join(': ')
    [title, fault].compact_blank.join(' — ').presence&.truncate(250, omission: '…')
  end

  private

  def clean_lines(text)
    text.to_s.tr("\u00A0", ' ').gsub(%r{https?://\S+}, ' ').split(%r{\r\n?|\n}).filter_map do |line|
      line = line.strip
      next if line.start_with?(ROBOT_MARK)

      line = line.sub(HUMAN_MARK, '').gsub(%r{[ \t]+}, ' ').strip
      next if line.empty? || line.match?(NOISE_LINE)

      line
    end
  end

  def consume!(start, finish)
    @rest[start...finish] = GAP * (finish - start)
  end

  def extract_phone
    @rest.to_enum(:scan, PHONE_CANDIDATE).each do
      match = Regexp.last_match
      phone = russian_phone(match[0])
      next if phone.blank?

      label = @rest[[match.begin(0) - LOOKBEHIND_CHARS, 0].max...match.begin(0)][PHONE_LABEL]
      consume!(match.begin(0) - label.to_s.length, match.end(0))
      return phone
    end

    nil
  end

  # Ten digits starting with 9, eleven starting with 7/8, or an explicit
  # international number: anything else is more likely an order or flat number.
  def russian_phone(raw)
    digits = raw.gsub(%r{\D}, '')
    international = raw.start_with?('+')
    plausible = if international
                  digits.length.between?(11, 15)
                else
                  (digits.length == 11 && digits.start_with?('7', '8')) || (digits.length == 10 && digits.start_with?('9'))
                end
    return if !plausible

    DomServis::Dispatch::ClientResolver.normalize_phone("#{'+' if international}#{digits}")
  end

  def extract_address
    candidates = address_candidates
    return if candidates.empty?

    best = candidates.find { |candidate| candidate[:labeled] } ||
           candidates.find { |candidate| candidate[:strong] } ||
           candidates.first

    # A message repeated with more detail ("…кв 11" and then "…кв 11, 3 этаж")
    # gives the same street and house twice; keep the fuller one.
    fuller = candidates.select { |candidate| candidate[:key] == best[:key] }.max_by { |candidate| candidate[:parts].size }
    best = fuller if fuller[:parts].size > best[:parts].size

    candidates.select { |candidate| candidate[:key] == best[:key] }.each { |candidate| consume!(candidate[:start], candidate[:finish]) }
    format_address(best)
  end

  def address_candidates
    offset = 0
    @rest.split("\n", -1).each_with_object([]) do |line, candidates|
      line.to_enum(:scan, HOUSE).each do
        candidate = address_candidate(line, Regexp.last_match)
        candidates << candidate.merge(start: offset + candidate[:start], finish: offset + candidate[:finish]) if candidate
      end
      offset += line.length + 1
    end
  end

  def address_candidate(line, match)
    window_start = [match.begin(0) - LOOKBEHIND_CHARS, 0].max
    street = street_before(line[window_start...match.begin(0)], window_start)
    return if street.nil?

    parts, finish = address_parts(line, match.end(0))
    house = match[:house].delete(' ')

    street.merge(
      finish:,
      house:   house.upcase,
      parts:,
      labeled: line[[street[:start] - LOOKBEHIND_CHARS, 0].max...street[:start]].match?(%r{адрес}i),
      strong:  street[:type].present? || match[:dom].present? || parts.any?,
      key:     "#{street[:name].join(' ').downcase} #{house.downcase}",
    )
  end

  # Reads the street name back from the house number: up to three words of
  # Cyrillic letters (or the number of a street like "8 Марта"), stopping at
  # punctuation, the "адрес" label, prepositions and words of the request.
  def street_before(prefix, offset)
    words = prefix.to_enum(:scan, %r{\S+}).map { [Regexp.last_match[0], offset + Regexp.last_match.begin(0)] }
    words.pop while words.any? && words.last[0].match?(%r{\A[,\-–—]+\z})

    street = { type: nil, name: [], start: nil }
    while (word, position = words.pop)
      break if !take_street_word(street, word, position)
    end

    street if street[:name].any?
  end

  # Adds a word read backwards to the street; false once the street ends.
  def take_street_word(street, word, position)
    type = street_type(word)
    first = street[:name].empty? && street[:type].nil?
    return false if !first && word.match?(type ? %r{[,:;!?]\z} : %r{[.,:;!?"»)|]\z})

    if type
      street[:type] = type
      street[:start] = position
      return street[:name].empty?
    end

    return false if !street_name_word?(word, street[:name])

    street[:name].unshift(word.sub(%r{[,.:;]+\z}, ''))
    street[:start] = position
    true
  end

  def street_type(word)
    token = word.downcase.sub(%r{[,.:;]+\z}, '')
    STREET_TYPES.find { |_label, pattern| token.match?(pattern) }&.first
  end

  def street_name_word?(word, name)
    return false if name.size >= MAX_STREET_WORDS

    cleaned = word.sub(%r{[,.:;]+\z}, '')
    return name.any? if cleaned.match?(STREET_NUMBER)
    return false if !cleaned.match?(%r{\A[а-яё]+(?:-[а-яё]+)*\z}i)

    token = cleaned.downcase.tr('ё', 'е')
    STREET_STOP_WORDS.exclude?(token) && !token.match?(STREET_STOP_ENDINGS)
  end

  def address_parts(line, position)
    parts = {}

    loop do
      rest = line[position, PART_WINDOW_CHARS].to_s
      gap = rest[%r{\A[\s,.;]*}]

      key, label, value, length = ADDRESS_PARTS.lazy.filter_map do |part_key, part_label, pattern|
        match = rest[gap.length..].match(pattern)
        [part_key, part_label, match.captures.compact.first, match[0].length] if match && parts.exclude?(part_key)
      end.first
      break if key.nil?

      parts[key] = "#{label} #{value}"
      position += gap.length + length
    end

    [parts, position]
  end

  def format_address(candidate)
    street = candidate[:name].map { |word| word.match?(%r{\A\d}) ? word : capitalize_word(word) }.join(' ')
    street = "#{candidate[:type]} #{street}" if candidate[:type]

    [street, "д. #{candidate[:house]}", *ADDRESS_PART_ORDER.filter_map { |key| candidate[:parts][key] }].join(', ')
  end

  def capitalize_word(word)
    word.split('-').map { |part| part[0].upcase + part[1..].to_s.downcase }.join('-')
  end

  def extract_name
    labeled = @rest.match(NAME_LABEL)
    return labeled[1] if labeled

    words = @rest.to_enum(:scan, NAME_WORD_PATTERN).map { Regexp.last_match }
    index = words.index { |word| FIRST_NAMES.include?(word[0]) }
    return if index.nil?

    current = words[index]
    following = words[index + 1]
    preceding = index.positive? ? words[index - 1] : nil

    name = [current[0]]
    name << following[0] if adjacent?(current, following) && following[0].match?(NAME_TAIL)
    name.unshift(preceding[0]) if adjacent?(preceding, current) && preceding[0].match?(SURNAME)
    name.join(' ')
  end

  def adjacent?(left, right)
    left.present? && right.present? && @rest[left.end(0)...right.begin(0)].match?(%r{\A +\z})
  end

  def work_positions
    equipment = EQUIPMENT.find { |_label, _work_type, pattern| @match.match?(pattern) }
    brand, model = equipment_model
    work_type = equipment&.second ||
                WORK_TYPE_WORDS.find { |_work_type, pattern| @match.match?(pattern) }&.first ||
                brand&.third&.second
    equipment_label = equipment&.first || brand&.third&.first
    fault = detected_faults.join(', ').upcase_first.presence

    positions = {
      work_type:,
      equipment: [equipment_label, model].compact_blank.join(' ').presence,
      fault:,
    }
    positions.merge(service_type: self.class.service_type_for(*positions.values))
  end

  # The brand entry and the model as written: the canonical brand with the
  # Latin model words after it ("Beretta CIA", "Baxi Eco Four 24", but not the
  # power in "Beretta 24 квт"), or Latin words of a brand the list does not
  # know. A Cyrillic spelling gives the brand alone.
  def equipment_model
    BRANDS.each do |entry|
      match = @text.match(entry[1])
      next if match.nil?

      model = [entry[0]]
      if match[0].ascii_only?
        model += @text[match.end(0), 80].to_s[MODEL_TOKENS].to_s.split.map { |token| token.sub(%r{[.+/-]+\z}, '') }
      end
      return [entry, model.join(' ')]
    end

    [nil, unknown_brand_model]
  end

  # Skips error codes ("ошибка H01") and messenger names.
  def unknown_brand_model
    @text.to_enum(:scan, LATIN_MODEL).each do
      match = Regexp.last_match
      model = match[0].sub(%r{[.+/-]+\z}, '')
      next if model.match?(%r{\A[ef]\d{2,3}\z}i) || NOT_A_MODEL.include?(model.split.first.downcase)
      next if @text[[match.begin(0) - 12, 0].max...match.begin(0)].match?(%r{(?:ошибк\S*|код)\s*[:№#-]?\s*\z}i)

      return model
    end

    nil
  end

  def detected_faults
    faults = []
    code = @text[ERROR_CODE, 1] || @text[BARE_ERROR_CODE, 1]
    faults << "ошибка #{normalize_code(code)}" if code

    FAULTS.each do |label, pattern|
      faults << label if @match.match?(pattern)
    end

    faults.uniq.first(MAX_FAULTS)
  end

  def normalize_code(code)
    code.upcase.gsub(%r{[\s-]}, '').gsub(%r{[АВЕКМНОРСТХ]}, CODE_LOOKALIKES)
  end

  def priority
    return 'critical' if @match.match?(CRITICAL)
    return 'high' if @match.match?(HIGH)

    nil
  end

  def extract_date
    rest = @rest.downcase.tr('ё', 'е')

    numeric_date(rest) || word_date(rest) || relative_date(rest) || weekday_date(rest)
  end

  def numeric_date(rest)
    rest.to_enum(:scan, NUMERIC_DATE).each do
      day, month, year = Regexp.last_match.captures.map { |value| value&.to_i }
      date = build_date(day, month, year)
      return date if date
    end

    nil
  end

  def word_date(rest)
    match = rest.match(WORD_DATE)
    return if match.nil?

    month = MONTHS.index { |stem| match[2].start_with?(stem) }
    build_date(match[1].to_i, month + 1, nil)
  end

  def relative_date(rest)
    days = RELATIVE_DAYS.find { |word, _days| rest.match?(%r{\b#{word}\b}) }&.last
    days && (@today + days)
  end

  def weekday_date(rest)
    wday = WEEKDAYS.find { |_wday, pattern| rest.match?(pattern) }&.first
    return if wday.nil?

    days = (wday - @today.wday) % 7
    @today + (days.zero? ? 7 : days)
  end

  # Without a year the date is this year's, unless it is more than two months
  # gone, which means early next year ("15.01" written in December).
  def build_date(day, month, year)
    year = 2000 + year if year && year < 100
    date = Date.new(year || @today.year, month, day)
    date = date.next_year if year.nil? && date < @today - 60
    date
  rescue Date::Error
    nil
  end

  # Only explicit times become the visit time: "к 15", "в 10:30", "с 10 до 12".
  # Words like "утром" or "после обеда" stay in the description.
  def extract_time
    TIME_WINDOWS.each do |pattern|
      @rest.to_enum(:scan, pattern).each do
        from_hour, from_minute, to_hour, to_minute = Regexp.last_match.captures
        from = clock(from_hour, from_minute)
        to = clock(to_hour, to_minute)
        return "#{from}-#{to}" if from && to && to > from
      end
    end

    if (match = @rest.match(CLOCK_TIME))
      time = clock(match[1], match[2])
      return time if time
    end

    if (match = @rest.match(SUFFIXED_HOUR))
      time = clock(afternoon(match[1].to_i, match[3]), match[2])
      return time if time
    end

    match = @rest.match(BARE_HOUR)
    match && clock(match[1], nil)
  end

  def afternoon(hour, suffix)
    return hour + 12 if suffix.to_s.downcase == 'вечера' && hour < 12
    return hour + 12 if suffix.to_s.downcase == 'дня' && hour.between?(1, 6)

    hour
  end

  def clock(hour, minute)
    hour = hour.to_i
    minute = minute.to_i
    return if !hour.between?(0, 23) || !minute.between?(0, 59)

    format('%<hour>02d:%<minute>02d', hour:, minute:)
  end
end
