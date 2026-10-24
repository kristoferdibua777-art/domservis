# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# A work or a part in a master report. list_price keeps the price list price
# at the time it was picked, so a changed price stays visible.
class DomServis::DispatchReportItem < ApplicationModel
  self.table_name = 'dom_servis_dispatch_report_items'

  KINDS = DomServis::PriceItem::KINDS

  belongs_to :dispatch_report, class_name: 'DomServis::DispatchReport', inverse_of: :items
  belongs_to :price_item, class_name: 'DomServis::PriceItem', optional: true

  validates :name, presence: true, length: { maximum: 250 }
  validates :kind, inclusion: { in: KINDS }
  validates :unit, presence: true, length: { maximum: 20 }
  validates :quantity, numericality: { greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }

  before_validation :calculate_amount

  def work?
    kind == 'work'
  end

  def part?
    kind == 'part'
  end

  def price_changed_from_list?
    list_price.present? && list_price != price
  end

  def line_amount
    (quantity.to_d * price.to_d).round(2)
  end

  def payload
    {
      id:               id,
      price_item_id:    price_item_id,
      kind:             kind,
      name:             name,
      quantity:         quantity.to_f,
      unit:             unit,
      list_price:       list_price&.to_f,
      price:            price.to_f,
      amount:           amount.to_f,
      bought_by_master: bought_by_master,
      price_changed:    price_changed_from_list?,
    }
  end

  private

  def calculate_amount
    self.bought_by_master = false if !part?
    self.amount = line_amount
  end
end
