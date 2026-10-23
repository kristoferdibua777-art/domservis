# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::WorkTagCatalog do
  def infer(text, address: nil)
    described_class.infer(text:, address:)
  end

  it 'groups unique tags without commas', :aggregate_failures do
    expect(described_class.groups.pluck(:label)).to eq(['Направление', 'Вид работ', 'Неисправность', 'Оборудование', 'Марка', 'Район', 'Отметки'])
    expect(described_class.names).to eq(described_class.names.uniq)
    expect(described_class.names).to include('Газовый котёл', 'Плановое ТО', 'Запах газа', 'Стиральная машина', 'Baxi', 'Гурьевск', 'Ждёт запчасть')
    expect(described_class.names.grep(%r{,|\*})).to be_empty
  end

  it 'names the group of a tag', :aggregate_failures do
    expect(described_class.group_key('Baxi')).to eq('brand')
    expect(described_class.group_key('Ждёт запчасть')).to eq('mark')
    expect(described_class.group_key('boiler')).to eq('other')
  end

  describe '.infer' do
    it 'reads the service tile, the faults and the brand of a client form request' do
      expect(infer("Газовый котёл: Не греет отопление, Ошибка на дисплее · Baxi Eco Four 24\nПодробнее: давление 0,5 бар"))
        .to eq(['Газовый котёл', 'Не греет', 'Ошибка на дисплее', 'Baxi'])
    end

    it 'takes the direction from the tile and leaves the tile words out', :aggregate_failures do
      expect(infer('Сантехника: Радиатор отопления, Протечка')).to eq(['Сантехника', 'Течёт', 'Радиатор отопления'])
      expect(infer('Бойлер, колонка: Не зажигается колонка')).to eq(['Бойлер и колонка', 'Не зажигается', 'Газовая колонка'])
    end

    it 'reads the kind of work, the equipment and the urgent faults', :aggregate_failures do
      expect(infer('Установить бойлер и подключить смеситель')).to include('Установка', 'Бойлер', 'Смеситель и кран').and(not_include('Демонтаж'))
      expect(infer('Демонтаж старой колонки')).to include('Демонтаж', 'Газовая колонка').and(not_include('Установка'))
      expect(infer('Пахнет газом на кухне')).to include('Запах газа')
      expect(infer('Искрит в щитке')).to include('Электрика', 'Искрит', 'Электрощиток')
      expect(infer('Холодильник Атлант не морозит')).to eq(['Бытовая техника', 'Не морозит', 'Холодильник', 'Атлант'])
      expect(infer('Духовой шкаф не включается')).not_to include('Мебель')
    end

    it 'reads the area from the address', :aggregate_failures do
      expect(infer('Засор', address: 'Калининград, Ленинский пр. 10')).to include('Калининград')
      expect(infer('Засор', address: 'Калининградская обл., г. Зеленоградск')).to include('Калининградская область').and(not_include('Калининград'))
      expect(infer('Засор', address: 'Калининградская область, Гурьевский район, пос. Луговое')).to include('Гурьевск').and(not_include('Калининград'))
    end

    it 'finds nothing in a text without work words', :aggregate_failures do
      expect(infer('Уточнить у клиента', address: 'Уточнить у клиента')).to eq([])
      expect(infer('Boiler repair', address: 'Lenina 10')).to eq([])
    end
  end

  describe '.sync!' do
    it 'creates the missing Zammad tags', :aggregate_failures do
      expect { described_class.sync! }.to change(Tag::Item, :count).by(described_class.names.size)
      expect { described_class.sync! }.not_to change(Tag::Item, :count)
    end
  end
end
