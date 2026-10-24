# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Saves the master report of a job from the board form (see
# DomServis::DispatchReport). The items are replaced by the submitted ones;
# a line picked from the price list keeps the list price next to the price
# the master entered. A report may be saved unfinished while the job is
# being worked on; for done and closed jobs, and when the master finishes
# the job with it, it has to be complete.
class DomServis::Dispatch::ReportSaver
  ITEM_FIELDS = %i[price_item_id kind name quantity unit price bought_by_master].freeze

  def initialize(job:, user:, params:)
    @job = job
    @user = user
    @params = params
  end

  attr_reader :job, :user, :params

  def save!(require_complete: false)
    report = job.report || job.build_report(submitted_by: user)
    report.master = job.assignee if job.assignee
    report.assign_attributes(report_attributes)
    replace_items(report) if params.key?(:items)
    report.apply_rates
    report.updated_by = user

    check_items!(report)
    raise Exceptions::UnprocessableEntity, "Отчёт не сдан: #{report.missing.join('; ')}." if require_complete && !report.complete?

    report.submitted_at ||= Time.zone.now if report.complete?
    report.save!
    report
  end

  private

  def report_attributes
    {
      work_summary:    text(:work_summary),
      recommendations: text(:recommendations),
      payment_method:  params.key?(:payment_method) ? params[:payment_method].to_s.presence : nil,
      amount_paid:     money(params[:amount_paid]),
    }.select { |key, _value| params.key?(key) }
  end

  def text(key)
    params[key].to_s.strip.presence
  end

  def replace_items(report)
    rows = Array(params[:items])
    raise Exceptions::UnprocessableEntity, "В отчёте больше #{DomServis::DispatchReport::MAX_ITEMS} позиций." if rows.size > DomServis::DispatchReport::MAX_ITEMS

    report.items.each(&:mark_for_destruction)
    rows.each_with_index do |row, index|
      report.items.build(item_attributes(row.to_h.symbolize_keys.slice(*ITEM_FIELDS), index))
    end
  end

  def check_items!(report)
    wrong = report.live_items.each_with_index.filter_map do |item, index|
      "#{index + 1} (#{item.name.presence || 'без названия'})" if !item.valid?
    end
    return if wrong.empty?

    raise Exceptions::UnprocessableEntity, "Проверьте позиции #{wrong.join(', ')}: нужны название, количество больше 0 и цена не меньше 0."
  end

  def item_attributes(row, index)
    price_item = row[:price_item_id].present? ? DomServis::PriceItem.find_by(id: row[:price_item_id]) : nil

    {
      position:         index,
      price_item:       price_item,
      kind:             row[:kind].presence || price_item&.kind || 'work',
      name:             row[:name].to_s.strip.presence || price_item&.name,
      quantity:         decimal(row[:quantity], 1),
      unit:             row[:unit].to_s.strip.presence || price_item&.unit || 'шт',
      list_price:       price_item&.price,
      price:            row.key?(:price) ? money(row[:price]) : (price_item&.price || 0),
      bought_by_master: ActiveModel::Type::Boolean.new.cast(row[:bought_by_master]) || false,
    }
  end

  def money(value)
    decimal(value, 0).round(2)
  end

  # Accepts "1 500,50" as typed on a phone.
  def decimal(value, default)
    text = value.to_s.delete(" \u00A0").tr(',', '.')
    return BigDecimal(default.to_s) if text.blank?

    BigDecimal(text)
  rescue ArgumentError
    raise Exceptions::UnprocessableEntity, "Не число: «#{value}»."
  end
end
