# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

require 'rails_helper'

RSpec.describe DomServis::MasterRate do
  let(:master) { create(:agent) }

  def rate(**attributes)
    described_class.new(user: master, **attributes)
  end

  describe '#fits?' do
    it 'fits every job without directions and areas' do
      expect(rate.fits?(['Электрика', 'Гурьевск'])).to be(true)
    end

    it 'fits jobs of its directions in its areas', :aggregate_failures do
      plumber = rate(directions: ['Сантехника'], areas: ['Калининград'])

      expect(plumber.fits?(%w[Сантехника Калининград Засор])).to be(true)
      expect(plumber.fits?(%w[Электрика Калининград])).to be(false)
      expect(plumber.fits?(%w[Сантехника Гурьевск])).to be(false)
      expect(plumber.fits?(%w[Сантехника])).to be(true), 'a job without an area fits any area'
    end
  end

  it 'keeps only known directions and areas', :aggregate_failures do
    expect(rate(directions: ['Газовый котёл', '', 'Газовый котёл'])).to be_valid
    expect(rate(directions: ['Космос'])).not_to be_valid
    expect(rate(areas: ['Луна'])).not_to be_valid
  end
end
