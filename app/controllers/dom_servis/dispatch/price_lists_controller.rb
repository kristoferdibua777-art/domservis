# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The price list of the master report form (decision 2026-10-24). Everybody
# on the board reads the active lines; the admin reads and saves all of them.
class DomServis::Dispatch::PriceListsController < DomServis::Dispatch::BaseController
  def show
    scope = DomServis::PriceItem.ordered
    scope = scope.active if !admin?

    render json: payload(scope), status: :ok
  end

  # Replaces the price list with the submitted lines: a line with an id is
  # updated, one without is added, a line left out is removed (reports keep
  # their copy of it).
  def update
    rows = Array(price_list_params[:items])

    DomServis::PriceItem.transaction do
      kept = rows.each_with_index.map { |row, index| save_item!(row, index) }
      DomServis::PriceItem.where.not(id: kept.map(&:id)).destroy_all
    end

    render json: payload(DomServis::PriceItem.ordered), status: :ok
  end

  private

  def payload(scope)
    {
      items:      scope.map(&:payload),
      kinds:      [{ id: 'work', label: 'Работа' }, { id: 'part', label: 'Запчасть' }],
      directions: DomServis::WorkTagCatalog::DIRECTION_TAGS.values,
    }
  end

  def save_item!(row, index)
    item = row[:id].present? ? DomServis::PriceItem.find(row[:id]) : DomServis::PriceItem.new
    item.update!(item_attributes(row, index))
    item
  rescue ActiveRecord::RecordInvalid => e
    raise Exceptions::UnprocessableEntity, "Строка #{index + 1} прайса (#{row[:name].presence || 'без названия'}): #{e.record.errors.full_messages.join(', ')}."
  end

  def item_attributes(row, index)
    {
      name:      row[:name].to_s.strip,
      kind:      row[:kind].presence || 'work',
      direction: row[:direction].presence,
      unit:      row[:unit].to_s.strip.presence || 'шт',
      price:     row[:price].to_s.delete(" \u00A0").tr(',', '.').presence || 0,
      active:    row.key?(:active) ? ActiveModel::Type::Boolean.new.cast(row[:active]) : true,
      position:  index,
    }
  end

  def price_list_params
    params.permit(items: %i[id name kind direction unit price active]).to_h.with_indifferent_access
  end

  def admin?
    current_user.permissions?('dom_servis.admin')
  end
end
