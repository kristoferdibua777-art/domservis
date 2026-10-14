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
end
