# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Intake::TextParser do
  # A Wednesday.
  let(:today) { Date.new(2026, 10, 14) }

  def parse(text)
    described_class.new(text, today:).call
  end

  it 'reads a WhatsApp message', :aggregate_failures do
    result = parse(<<~TEXT)
      [14.10.2026, 10:15] Ирина Петрова: Здравствуйте! Котёл Baxi Eco Four 24 не греет, ошибка E03. Адрес: Калининград, ул. Ленина 5, кв. 12. Телефон 8 (900) 123-45-67. Можно завтра после 18?
    TEXT

    expect(result).to include(
      client_phone: '+79001234567',
      client_name:  'Ирина Петрова',
      address:      'Калининград, ул. Ленина 5, кв. 12',
      service_type: 'Газовый котёл: Ошибка E03, Не греет · Baxi Eco Four 24',
      priority:     'high',
      visit_date:   '2026-10-15',
      visit_day:    'thu',
      visit_time:   '18:00-20:00',
    )
    expect(result[:description]).not_to include('[14.10.2026, 10:15]')
  end

  it 'reads an Avito message with a street without a marker' do
    result = parse(<<~TEXT)
      Сообщение от покупателя
      Имя: Сергей
      Нужно заменить смеситель на кухне, течёт. Ленина 10-25. 89211234567
    TEXT

    expect(result).to include(
      client_phone: '+79211234567',
      client_name:  'Сергей',
      address:      'Ленина 10-25',
      service_type: 'Сантехника: Течёт, Установка или замена',
      priority:     'high',
      description:  'Нужно заменить смеситель на кухне, течёт.',
    )
  end

  it 'reads a Telegram message with a weekday and a time window' do
    result = parse(<<~TEXT)
      Анна, [14.10.2026 09:30]
      Добрый день. Стиральная машина Bosch не сливает воду. г. Гурьевск, пр. Калининградский 12, подъезд 2. Тел +7 911 555 44 33. В пятницу с 10 до 13 удобно.
    TEXT

    expect(result).to include(
      client_phone: '+79115554433',
      client_name:  'Анна',
      address:      'г. Гурьевск, пр. Калининградский 12, подъезд 2',
      service_type: 'Бытовая техника: Не сливает воду · Bosch',
      priority:     nil,
      visit_date:   '2026-10-16',
      visit_time:   '10:00-13:00',
    )
  end

  it 'marks a gas smell as critical and cuts the address before the phone' do
    result = parse('Срочно! Пахнет газом от котла, ул. Мира д. 3 кв 7, звоните 89001112233 Олег')

    expect(result).to include(priority: 'critical', client_name: 'Олег', address: 'ул. Мира д. 3 кв 7', client_phone: '+79001112233')
  end

  it 'keeps every phone and offers the first one as the client phone' do
    expect(parse('Мой номер 89001234567, жены 8 900 765-43-21')).to include(phones: %w[+79001234567 +79007654321], client_phone: '+79001234567')
  end

  it 'reads the usual phone notations but not dates', :aggregate_failures do
    expect(parse("+7(4012)53-45-67\n8-911-123-45-67\n9111234560\nдата 14.10.2026")[:phones]).to eq(%w[+74012534567 +79111234567 +79111234560])
    expect(parse('Заявка от 14.10.2026, номер 123456')[:phones]).to be_empty
  end

  it 'leaves out what the text does not have' do
    expect(parse('Здравствуйте, сколько стоит обслуживание котла?')).to include(
      client_phone: nil,
      client_name:  nil,
      address:      nil,
      service_type: 'Газовый котёл: Плановое обслуживание',
      visit_date:   nil,
      visit_time:   nil,
    )
  end

  it 'does not take the time of a chat message for the visit time' do
    result = parse("[14.10.2026, 10:15] Иван: котёл течёт\n[14.10.2026, 10:16] Иван: 89001234567")

    expect(result).to include(visit_time: nil, visit_date: nil, client_name: 'Иван')
  end

  it 'reads dates and times', :aggregate_failures do
    expect(parse('Приезжайте 20.10 к 10')).to include(visit_date: '2026-10-20', visit_time: '10:00')
    expect(parse('Можно в 6 вечера, 17 октября?')).to include(visit_date: '2026-10-17', visit_time: '18:00')
    expect(parse('мастер нужен до 12, течёт кран')).to include(visit_time: '08:00-12:00')
    expect(parse('Доброе утро! Можно утром послезавтра?')).to include(visit_date: '2026-10-16', visit_time: '08:00-12:00')
  end

  it 'reads the part of the day named by a noun', :aggregate_failures do
    expect(parse('Пушкина 5 кв 7, 89001234567, Сергей, Юнкерс, ошибка 90, завтра вечер')).to include(visit_date: '2026-10-15', visit_time: '16:00-20:00')
    expect(parse('Котёл не греет, можно на утро пятницы?')).to include(visit_date: '2026-10-16', visit_time: '08:00-12:00')
    expect(parse('Течёт кран, приезжайте ближе к вечеру')).to include(visit_time: '16:00-20:00')
    expect(parse('Можно вечерком, кран капает')).to include(visit_time: '16:00-20:00')
  end

  it 'does not take a greeting for the part of the day', :aggregate_failures do
    expect(parse('Алло, добрый вечер, котёл не греет')).to include(visit_time: nil)
    expect(parse('Здравствуйте, доброе утро. Течёт кран, приезжайте днём')).to include(visit_time: '12:00-16:00')
  end

  it 'does not treat a burning lamp as an emergency' do
    expect(parse('На котле горит красная лампочка, не включается')).to include(priority: nil, service_type: 'Газовый котёл: Не включается')
  end

  it 'reads labelled names and addresses' do
    expect(parse("Клиент: Мария Иванова\nАдрес: Светлогорск, Ленина 3\nтел 89001234567")).to include(client_name: 'Мария Иванова', address: 'Светлогорск, Ленина 3')
  end

  it 'takes a boiler brand for a boiler job and reads a Cyrillic error code' do
    expect(parse('Navien Deluxe 24K, ошибка Е10')[:service_type]).to eq('Газовый котёл: Ошибка E10 · Navien Deluxe 24K')
  end

  it 'does not take a street named after a brand for the brand' do
    expect(parse('Мария, тел. 89001234567, котёл течёт, ул. Нева 1')).to include(service_type: 'Газовый котёл: Течёт', client_name: 'Мария')
  end

  # The description is what is left of the client's words once the client
  # phone, the name, the address, the greetings and the closing words are out.
  describe 'messages as clients write them' do
    it 'reads a short message with the name at the end' do
      expect(parse('Протекает унитаз, срочно!!! Ленина 10 кв 5, 89114443322 Галина')).to include(
        client_phone: '+79114443322',
        client_name:  'Галина',
        address:      'Ленина 10 кв 5',
        description:  'Протекает унитаз, срочно!',
      )
    end

    it 'reads a WhatsApp message sent from a number' do
      result = parse('[15.10.2026, 09:12] +7 921 555-12-34: Добрый день! Меня зовут Сергей. Не работает розетка на кухне, искрит. Адрес: ул. Гагарина 15, кв 8')

      expect(result).to include(client_phone: '+79215551234', client_name: 'Сергей', address: 'ул. Гагарина 15, кв 8', description: 'Не работает розетка на кухне, искрит.')
    end

    it 'reads a signature and a settlement' do
      result = parse('Здравствуйте. Нужно установить смеситель в ванной. Посёлок Васильково, ул. Шатурская 3. Тел. 8 (909) 777-66-55. С уважением, Ольга')

      expect(result).to include(client_name: 'Ольга', address: 'Посёлок Васильково, ул. Шатурская 3', description: 'Нужно установить смеситель в ванной.')
    end

    it 'puts a city written after "в" back in its plain form', :aggregate_failures do
      expect(parse('Добрый вечер, это Наталья. Котёл не греет, в Гурьевске, ул. Каштановая 7. 89062223344')).to include(
        client_name: 'Наталья',
        address:     'Гурьевск, ул. Каштановая 7',
        description: 'Котёл не греет.',
      )
      expect(parse('В Светлом на ул. Лесной 4 не работает свет, 89001112233')).to include(address: 'Светлый, ул. Лесной 4', description: 'Не работает свет')
    end

    it 'keeps the second phone in the description' do
      result = parse("Добрый день! Течёт батарея в спальне. Калининград, Московский проспект 120, кв. 45. Мой номер 89114445566, если не возьму — звоните мужу 89217778899.\nТатьяна")

      expect(result).to include(
        phones:       %w[+79114445566 +79217778899],
        client_phone: '+79114445566',
        client_name:  'Татьяна',
        address:      'Калининград, Московский проспект 120, кв. 45',
        description:  'Течёт батарея в спальне. Если не возьму — звоните мужу 89217778899.',
      )
    end

    it 'leaves the name empty when the text has none' do
      result = parse('Здравствуйте! Не сливает воду стиральная машина LG. Светлогорск, ул. Октябрьская 22. 8 911 000 11 22')

      expect(result).to include(client_name: nil, address: 'Светлогорск, ул. Октябрьская 22', description: 'Не сливает воду стиральная машина LG.')
    end

    it 'ends the address at the house when there is no punctuation', :aggregate_failures do
      expect(parse('Ирина 89001234567 ул. Мира 5 кв 3 засор в ванной')).to include(client_name: 'Ирина', address: 'ул. Мира 5 кв 3', description: 'Засор в ванной')
      expect(parse('Алло, это Сергей с Невского 12 кв 40, опять засор на кухне, 89051234567')).to include(
        client_name: 'Сергей',
        address:     'Невского 12 кв 40',
        description: 'Опять засор на кухне',
      )
    end

    it 'reads a form with labels' do
      result = parse("Имя: Андрей\nТелефон: +7(911)123-45-67\nАдрес: пос. Малое Исаково, ул. Пушкина 4\nПроблема: не включается бойлер Thermex")

      expect(result).to include(client_name: 'Андрей', address: 'пос. Малое Исаково, ул. Пушкина 4', description: 'Не включается бойлер Thermex')
    end

    it 'keeps the wished time in the description' do
      result = parse('Здравствуйте, меня зовут Галина Петровна. Не работает духовка. Зеленоградск, ул. Тургенева 8. Звоните после 17, 8-906-123-45-67')

      expect(result).to include(client_name: 'Галина Петровна', description: 'Не работает духовка. Звоните после 17', visit_time: '17:00-20:00')
    end

    it 'takes the name on the first line of an Avito chat' do
      result = parse("Елена\nЗдравствуйте! Нужен мастер повесить люстру и карниз. Янтарный, ул. Советская 30, кв 2\n89112223344")

      expect(result).to include(client_name: 'Елена', address: 'Янтарный, ул. Советская 30, кв 2', description: 'Нужен мастер повесить люстру и карниз.')
    end

    it 'leaves out the closing words but not a last line that is no name', :aggregate_failures do
      expect(parse("Кран капает в ванной, Советский проспект 15-3.\n89003334455 Вера\nЗаранее спасибо!")).to include(
        client_name: 'Вера',
        address:     'Советский проспект 15-3',
        description: 'Кран капает в ванной.',
      )
      expect(parse("Котёл не греет, ул. Ленина 5, 89001234567\nЖду")).to include(client_name: nil, description: "Котёл не греет\nЖду")
    end

    it 'keeps the other phone written after "или"' do
      result = parse('Нужен электрик, частный дом в пос. Ушаково, ул. Центральная 12. Телефон 89000000001 или 89000000002. Михаил')

      expect(result).to include(client_name: 'Михаил', address: 'пос. Ушаково, ул. Центральная 12', description: 'Нужен электрик, частный дом. Телефон 89000000002.')
    end

    it 'does not take a street or a surname for a name or a city', :aggregate_failures do
      expect(parse('Это Ленина 5, течёт кран, 89001234567')).to include(client_name: nil, address: 'Ленина 5')
      expect(parse('Анна Гусева, Гусев, ул. Мира 5, 89001234567, не греет батарея')).to include(address: 'Гусев, ул. Мира 5')
      expect(parse('Котёл Navien ошибка 03, г. Калининград, ул. Ю. Гагарина 5. Тел: 8 911 111 22 33 (Светлана)')).to include(
        client_name: 'Светлана',
        address:     'г. Калининград, ул. Ю. Гагарина 5',
        description: 'Котёл Navien ошибка 03.',
      )
    end

    it 'reads a street written after "на"' do
      result = parse('Добрый вечер! В квартире на Ленинском проспекте 30 кв 15 нет света, выбивает автомат. Можно сегодня после 19? Мой номер +7 (921) 000-11-22, Павел')

      expect(result).to include(client_name: 'Павел', address: 'Ленинском проспекте 30 кв 15', description: 'В квартире нет света, выбивает автомат. Можно сегодня после 19?')
    end

    it 'keeps the punctuation of the client' do
      expect(parse('Течёт... и капает?! ул. 50 лет Октября 10, 89001234567')).to include(address: 'ул. 50 лет Октября 10', description: 'Течёт... и капает?!')
    end

    it 'gives no description when the text has only the contacts' do
      expect(parse('Ул. Ленина 5, 89001234567, Ирина')).to include(client_name: 'Ирина', address: 'Ул. Ленина 5', description: nil)
    end
  end
end
