# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# A line of the price list (decision 2026-10-24): a work or a part with its
# unit and price, optionally for one direction of the work tag dictionary.
# A master picks lines into the report; the price there can be changed.
class DomServis::PriceItem < ApplicationModel
  self.table_name = 'dom_servis_price_items'

  KINDS = %w[work part].freeze

  validates :name, presence: true, length: { maximum: 250 }
  validates :kind, inclusion: { in: KINDS }
  validates :unit, presence: true, length: { maximum: 20 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validate :direction_is_known

  scope :ordered, -> { order(:position, :id) }
  scope :active, -> { where(active: true) }

  def payload
    {
      id:        id,
      name:      name,
      kind:      kind,
      direction: direction,
      unit:      unit,
      price:     price.to_f,
      active:    active,
      position:  position,
    }
  end

  private

  def direction_is_known
    return if direction.blank?
    return if DomServis::WorkTagCatalog::DIRECTION_TAGS.value?(direction)

    errors.add(:direction, "«#{direction}» нет в направлениях справочника тегов")
  end
end
