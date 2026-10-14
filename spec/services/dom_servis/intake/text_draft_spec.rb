# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::Intake::TextDraft do
  let(:today)  { Date.new(2026, 10, 14) }
  let(:text)   { 'Котёл Baxi не греет. Адрес: ул. Ленина 5, кв. 12. Тел 8 900 123-45-67, Ирина' }
  let(:ai_off) { DomServis::Intake::AISettings.new({}) }
  let(:ai_on)  { DomServis::Intake::AISettings.new('enabled' => true, 'auth_key' => 'a2V5OnNlY3JldGtleTEyMzQ=', 'model' => 'GigaChat-2-Pro') }
  let(:ai_answer) do
    {
      client_name:  'Ирина',
      client_phone: '+7 999 000-00-00',
      address:      'улица Ленина, дом 5, квартира 12',
      service_type: 'Газовый котёл: Не греет · Baxi',
      priority:     'medium',
      visit_date:   '2026-10-14',
      visit_time:   '10:00',
      description:  'Котёл Baxi не греет.',
      missing:      ['Номер подъезда'],
    }
  end

  def draft(value = text, settings: ai_off)
    described_class.new(text: value, today:, ai_settings: settings).call
  end

  def check_texts(result)
    result[:checks].map { |check| "#{check[:level]}: #{check[:text]}" }
  end

  def answer_with(answer)
    allow(DomServis::Intake::AIParser).to receive(:new).and_return(instance_double(DomServis::Intake::AIParser, call: answer))
  end

  context 'without GigaChat' do
    it 'fills the draft by the rules and names a new client', :aggregate_failures do
      result = draft

      expect(result[:draft]).to include(client_phone: '+79001234567', address: 'ул. Ленина 5, кв. 12', priority: 'high')
      expect(result[:draft]).not_to have_key(:comment)
      expect(result[:ai]).to eq(enabled: false, used: false, model: nil, error: nil)
      expect(check_texts(result)).to include('info: Новый клиент — он появится в базе, когда заявка будет создана.')
      expect(result[:client]).to be_nil
    end

    it 'reports what is missing', :aggregate_failures do
      result = draft('Здравствуйте, сколько стоит обслуживание котла?')

      expect(check_texts(result)).to include('error: Телефон клиента не найден — без него заявку не создать.', 'error: Адрес не найден — уточните у клиента.')
    end
  end

  context 'with GigaChat' do
    before { answer_with(ai_answer) }

    it 'uses only the values found in the text', :aggregate_failures do
      result = draft(settings: ai_on)

      expect(result[:draft]).to include(
        client_phone: '+79001234567',
        address:      'улица Ленина, дом 5, квартира 12',
        service_type: 'Газовый котёл: Не греет · Baxi',
        priority:     'high',
        description:  'Котёл Baxi не греет.',
        comment:      "Исходный текст:\n#{text}",
      )
      expect(result[:draft]).not_to include(:visit_date, :visit_time)
      expect(check_texts(result)).to include(
        'warning: ИИ предложил номер +7 999 000-00-00, которого нет в тексте, — номер не подставлен.',
        'info: Уточнить: Номер подъезда',
        'ok: Текст проверен ИИ (GigaChat-2-Pro).',
      )
      expect(result[:ai]).to eq(enabled: true, used: true, model: 'GigaChat-2-Pro', error: nil)
    end

    it 'drops an address that is not in the text', :aggregate_failures do
      answer_with(ai_answer.merge(address: 'проспект Мира 40'))
      result = draft(settings: ai_on)

      expect(result[:draft][:address]).to eq('ул. Ленина 5, кв. 12')
      expect(check_texts(result)).to include('warning: Адрес от ИИ не найден в тексте — взят адрес, найденный по правилам.')
    end

    it 'takes the date and time when the text names them' do
      answer_with(ai_answer.merge(visit_date: '2026-10-15', visit_time: '10:00'))

      expect(draft("#{text}. Завтра в 10:00", settings: ai_on)[:draft]).to include(visit_date: '2026-10-15', visit_day: 'thu', visit_time: '10:00')
    end

    it 'keeps an emergency critical' do
      answer_with(ai_answer.merge(client_phone: '89001112233', address: 'ул. Мира 3'))

      expect(draft('Пахнет газом! ул. Мира 3, 89001112233', settings: ai_on)[:draft]).to include(priority: 'critical', client_phone: '+79001112233')
    end

    it 'falls back to the rules when GigaChat fails', :aggregate_failures do
      allow(DomServis::Intake::AIParser).to receive(:new).and_raise(DomServis::Intake::AIError, 'В GigaChat закончились оплаченные токены.')
      result = draft(settings: ai_on)

      expect(result[:draft]).to include(client_phone: '+79001234567', address: 'ул. Ленина 5, кв. 12')
      expect(result[:ai]).to include(used: false, error: 'В GigaChat закончились оплаченные токены.')
      expect(check_texts(result)).to include('warning: ИИ не ответил: В GigaChat закончились оплаченные токены. Поля заполнены по правилам — проверьте их.')
    end
  end

  context 'with a known client' do
    let!(:client) { create(:customer, firstname: 'Ирина', lastname: 'Смирнова', email: 'irina.smirnova@example.com', phone: '+79001234567') }

    before do
      create_job(service_type: 'Газовый котёл: Не греет', address: 'ул. Ленина 5, кв. 12', client_phone: '8 (900) 123-45-67', status: 'pool', ticket: create(:ticket))
      create_job(service_type: 'Сантехника', address: 'Советский пр. 10', client_phone: '+79001234567', status: 'cancelled')
    end

    def create_job(**attributes)
      DomServis::DispatchJob.create!(visit_day: 'mon', visit_date: '2026-10-12', priority: 'medium', source: 'manual', **attributes)
    end

    it 'compares the draft with the client and the earlier jobs', :aggregate_failures do
      result = draft('Мария, тел. 89001234567, котёл течёт, ул. Нева 1')
      open_job = DomServis::DispatchJob.find_by(status: 'pool')

      expect(check_texts(result)).to include(
        "ok: Клиент есть в базе: #{client.fullname}.",
        "warning: В базе клиент записан как «#{client.fullname}», в тексте — «Мария».",
        "warning: У клиента уже есть открытая заявка № #{open_job.ticket.number} (на стенде): Газовый котёл: Не греет.",
      )
      expect(check_texts(result).grep(%r{открытая заявка.*Сантехника})).to be_empty
      expect(result[:client]).to include(name: client.fullname, jobs_count: 2)
    end

    it 'takes the name from the database when the text has none' do
      expect(draft('89001234567 котёл не греет ул. Ленина 5')[:draft][:client_name]).to eq(client.fullname)
    end

    it 'warns when the phone belongs to several clients' do
      create(:customer, firstname: 'Пётр', email: 'petr@example.com', mobile: '8 900 123 45 67')

      expect(check_texts(draft('89001234567 котёл не греет ул. Ленина 5')).grep(%r{\Aerror: Номер записан у нескольких клиентов})).to be_present
    end
  end
end
