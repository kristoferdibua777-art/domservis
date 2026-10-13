# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

# The messages follow the shape the dispatch receives them in (SMS, the phone
# secretary transcript); phones and house numbers are made up.
RSpec.describe DomServis::Intake::TextParser do
  subject(:parser) { described_class.new(text, today:) }

  # A Tuesday.
  let(:today) { Date.new(2026, 10, 13) }

  context 'with an address and a note' do
    let(:text) { 'Сержанта Мишина 12Б, только позвоните чуть заранее' }

    it 'reads the address and keeps the whole text as the description' do
      expect(parser.draft).to eq(address: 'Сержанта Мишина, д. 12Б', description: text)
    end

    it 'reports the key fields the text does not give' do
      expect(parser.missing).to eq(%i[client_phone client_name work_type equipment fault])
    end
  end

  context 'with an address, a fault and a boiler model' do
    let(:text) { 'Осипенко д. 7. кв.3 " мозги" котёл Beretta CIA' }

    it 'splits the work into positions', :aggregate_failures do
      expect(parser.draft).to include(
        address:      'Осипенко, д. 7, кв. 3',
        work_type:    'Котлы и отопление',
        equipment:    'Котёл Beretta CIA',
        fault:        'Плата управления',
        service_type: 'Котлы и отопление: Котёл Beretta CIA — Плата управления',
      )
      expect(parser.missing).to eq(%i[client_phone client_name])
    end
  end

  describe 'work positions' do
    [
      ['Ленина 5, стиральная машина Weissgauff WM 4947 не сливает воду, ошибка E21', 'Бытовая техника', 'Стиральная машина Weissgauff WM 4947', 'Ошибка E21, не сливает воду'],
      ['Мира 10 кв 4, холодильник Атлант не морозит', 'Бытовая техника', 'Холодильник Atlant', 'Не холодит'],
      ['Мира 2, Bosch Serie 4 не сливает', 'Бытовая техника', 'Bosch Serie 4', 'Не сливает воду'],
      ['Гагарина 3, кондиционер Daikin течёт и шумит', 'Кондиционеры', 'Кондиционер Daikin', 'Течёт, шумит'],
      ['Победы 12, бойлер Термекс 80 л не греет', 'Водонагреватели и колонки', 'Водонагреватель Thermex', 'Не греет'],
      ['Садовая 4, нет света в квартире, выбивает автомат', 'Электрика', nil, 'Нет света, выбивает автомат'],
      ['Ленина 8, засор в ванной', 'Сантехника', nil, 'Засор'],
      ['Кирова 7, нужно повесить карниз', 'Мелкий ремонт', nil, nil],
      ['Ленина 3, посудомойка ошибка H01, Иван WhatsApp', 'Бытовая техника', 'Посудомоечная машина', 'Ошибка H01'],
    ].each do |message, work_type, equipment, fault|
      context "with \"#{message}\"" do
        let(:text) { message }

        it 'reads the work type, the equipment with its model and the fault' do
          expect(parser.draft.slice(:work_type, :equipment, :fault)).to eq({ work_type:, equipment:, fault: }.compact)
        end
      end
    end
  end

  context 'with a labelled address repeated in a second, fuller message' do
    let(:text) do
      <<~TEXT
        Адрес для установки нового счетчика воды: улица малая лесная дом 15 квартира 9
        Телефон 89001234567
        Улица малая лесная дом 15 квартира 9, 3 этаж
      TEXT
    end

    it 'keeps the fuller address and the phone', :aggregate_failures do
      expect(parser.draft).to include(
        address:      'ул. Малая Лесная, д. 15, кв. 9, этаж 3',
        client_phone: '+79001234567',
        service_type: 'Сантехника: Счётчик воды — Установка',
      )
    end
  end

  context 'with the street written after the "Адрес" label' do
    let(:text) { 'Адрес , суздальская 21 подъезд 2 кв 54' }

    it 'reads the entrance and the flat' do
      expect(parser.draft[:address]).to eq('Суздальская, д. 21, кв. 54, подъезд 2')
    end
  end

  context 'with a phone secretary transcript' do
    let(:text) do
      <<~TEXT
        Прослушать сообщение: https://l.tbank.ru/callmob
        Звонили с этого номера и оставили сообщение.
        👤: Иван.
        👤: Алло, алло!
        🤖: У вас очень красивое «алло». Пожалуйста, говорите.
        👤: Иван это Валерьевич беспокоит
        👤: [Абонент положил трубку]
        Этот абонент звонил вам сегодня в 18:00
      TEXT
    end

    it 'keeps only what the caller said', :aggregate_failures do
      expect(parser.draft).to eq(client_name: 'Иван', description: "Иван.\nИван это Валерьевич беспокоит")
    end
  end

  context 'with every field in one message' do
    let(:text) { 'Осипенко д. 7 кв 3, котёл Baxi Eco Four 24, ошибка E10, не греет. Мария Петрова +7 (900) 123-45-67, завтра с 10 до 12' }

    it 'fills the whole draft', :aggregate_failures do
      expect(parser.draft).to include(
        address:      'Осипенко, д. 7, кв. 3',
        service_type: 'Котлы и отопление: Котёл Baxi Eco Four 24 — Ошибка E10, не греет',
        client_name:  'Мария Петрова',
        client_phone: '+79001234567',
        visit_date:   '2026-10-14',
        visit_day:    'wed',
        visit_time:   '10:00-12:00',
      )
      expect(parser.missing).to be_empty
    end
  end

  context 'with a request in front of the street' do
    let(:text) { 'Нужно починить кран Сержанта Мишина 12Б. Иван 8 900 765 43 21 в пятницу к 15' }

    it 'stops the street name at the request words', :aggregate_failures do
      expect(parser.draft).to include(
        address:      'Сержанта Мишина, д. 12Б',
        service_type: 'Сантехника: Кран',
        client_name:  'Иван',
        client_phone: '+79007654321',
        visit_date:   '2026-10-16',
        visit_day:    'fri',
        visit_time:   '15:00',
      )
    end
  end

  context 'with the street type after the name and a building number' do
    let(:text) { 'Лесная улица 12к2, срочно, пахнет газом' }

    it 'reads the address and marks the job critical' do
      expect(parser.draft).to include(address: 'ул. Лесная, д. 12, корп. 2', priority: 'critical', service_type: 'Котлы и отопление — Пахнет газом')
    end
  end

  context 'with a street named after a date' do
    let(:text) { 'ул. 8 Марта 15 кв 3, Наталья, 9001112233, бойлер Thermex течёт' }

    it 'keeps the number in the street name and does not read it as a date', :aggregate_failures do
      expect(parser.draft).to include(
        address:      'ул. 8 Марта, д. 15, кв. 3',
        client_name:  'Наталья',
        client_phone: '+79001112233',
        service_type: 'Водонагреватели и колонки: Водонагреватель Thermex — Течёт',
      )
      expect(parser.draft).not_to include(:visit_date)
    end
  end

  context 'with numbers that are not an address, a phone or a date' do
    let(:text) { 'Заявка №1234567. Котёл Протерм 24 квт, давление 1.5 бар' }

    it 'leaves them in the description', :aggregate_failures do
      expect(parser.draft).not_to include(:address, :client_phone, :visit_date, :visit_time)
      expect(parser.draft[:service_type]).to eq('Котлы и отопление: Котёл Protherm — Падает давление')
    end
  end

  describe 'phones' do
    %w[+7(900)123-45-67 89001234567 9001234567].each do |phone|
      context "with #{phone}" do
        let(:text) { "Мира 10, #{phone}" }

        it 'normalizes the number' do
          expect(parser.draft[:client_phone]).to eq('+79001234567')
        end
      end
    end
  end

  describe 'visit dates and times' do
    {
      'Мира 10, 25 октября утром'     => { visit_date: '2026-10-25', visit_day: 'sun' },
      'Мира 10, 20.10 в 9 утра'       => { visit_date: '2026-10-20', visit_day: 'tue', visit_time: '09:00' },
      'Мира 10, приходите в 7 вечера' => { visit_time: '19:00' },
      'Мира 10, сегодня в 14:30'      => { visit_date: '2026-10-13', visit_day: 'tue', visit_time: '14:30' },
      'Мира 10, в 3 подъезде'         => {},
    }.each do |message, expected|
      context "with \"#{message}\"" do
        let(:text) { message }

        it 'reads only explicit dates and times' do
          expect(parser.draft.slice(:visit_date, :visit_day, :visit_time)).to eq(expected)
        end
      end
    end

    context 'with a January date written in December' do
      let(:today) { Date.new(2026, 12, 28) }
      let(:text)  { 'Мира 10, 15.01' }

      it 'takes the date in the next year' do
        expect(parser.draft[:visit_date]).to eq('2027-01-15')
      end
    end
  end
end
