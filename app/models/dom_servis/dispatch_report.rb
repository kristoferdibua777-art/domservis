# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The master's report of a job (decision 2026-10-24). A job moves to done only
# with a complete report: works or parts with prices, how the client paid,
# what was done, recommendations to the client and a photo or an act among
# the job attachments. The sums are calculated here:
#
# - works and parts from the items, the total is what the client pays;
# - the master gets master_percent of the works plus the parts he bought;
# - the partner (organization of the job) gets partner_percent of the works
#   or of the total;
# - the company keeps the rest;
# - money paid in cash or by transfer to the master stays with him, so the
#   settlement is what the company still owes the master (negative: what he
#   hands over).
#
# Until the job is closed the shares follow the current rates (see
# #apply_rates); a closed job keeps the rates it was closed with.
class DomServis::DispatchReport < ApplicationModel
  self.table_name = 'dom_servis_dispatch_reports'

  PAYMENT_METHODS = {
    'cash'             => 'Наличными мастеру',
    'transfer_master'  => 'Переводом мастеру',
    'card'             => 'Картой через терминал',
    'transfer_company' => 'На счёт компании',
    'partner'          => 'Платит партнёр',
    'unpaid'           => 'Не оплачено',
  }.freeze

  # The money stays with the master until he settles with the company.
  MASTER_PAYMENT_METHODS = %w[cash transfer_master].freeze
  # No money from the client on site.
  NO_PAYMENT_METHODS = %w[partner unpaid].freeze
  # Attachment kinds that prove the work: a photo or an act.
  EVIDENCE_KINDS = %w[completion_act diagnostic_photo].freeze
  MAX_ITEMS = 50

  belongs_to :dispatch_job, class_name: 'DomServis::DispatchJob', inverse_of: :report
  belongs_to :master, class_name: 'User', optional: true
  belongs_to :submitted_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  has_many :items, -> { reorder(:position, :id) },
           class_name: 'DomServis::DispatchReportItem',
           inverse_of: :dispatch_report,
           dependent:  :destroy,
           autosave:   true

  validates :dispatch_job_id, uniqueness: true
  validates :payment_method, inclusion: { in: PAYMENT_METHODS.keys }, allow_blank: true
  validates :amount_paid, numericality: { greater_than_or_equal_to: 0 }
  validates :partner_base, inclusion: { in: DomServis::PartnerRate::BASES }
  validate :items_within_limit

  before_validation :calculate

  def live_items
    items.reject(&:marked_for_destruction?)
  end

  # What the report still lacks before the job can be finished.
  def missing
    list = []
    list << 'добавьте хотя бы одну работу или запчасть' if live_items.empty?
    list << 'напишите, что сделано' if work_summary.blank?
    list << 'напишите рекомендации клиенту (если их нет — «нет»)' if recommendations.blank?
    list << 'укажите, как клиент заплатил' if payment_method.blank?
    list << 'укажите сумму, полученную от клиента' if payment_received? && amount_paid.to_d <= 0
    list << 'приложите фото результата или акт выполненных работ' if !evidence?
    list
  end

  def complete?
    missing.empty?
  end

  def self.evidence_for?(job)
    Array(job&.attachments).any? { |store| EVIDENCE_KINDS.include?(store.preferences['dom_servis_kind']) }
  end

  def evidence?
    self.class.evidence_for?(dispatch_job)
  end

  def payment_received?
    payment_method.present? && NO_PAYMENT_METHODS.exclude?(payment_method)
  end

  def apply_rates
    return if dispatch_job.status == 'closed' && persisted?

    terms = DomServis::PartnerRate.terms_for(dispatch_job.organization_id)

    self.master_percent  = DomServis::MasterRate.percent_for(master_id)
    self.partner_percent = terms[:percent]
    self.partner_base    = terms[:base]
  end

  def payment_method_label
    PAYMENT_METHODS[payment_method]
  end

  # view: :base for dispatchers, :master for the master of the job (his own
  # share), :admin for everything.
  def payload(view: :base)
    data = {
      id:                   id,
      dispatch_job_id:      dispatch_job_id,
      master_id:            master_id,
      master_name:          master&.fullname,
      submitted_at:         submitted_at,
      updated_at:           updated_at,
      work_summary:         work_summary,
      recommendations:      recommendations,
      payment_method:       payment_method,
      payment_method_label: payment_method_label,
      amount_paid:          amount_paid.to_f,
      money_at_master:      money_at_master.to_f,
      works_total:          works_total.to_f,
      parts_total:          parts_total.to_f,
      total:                total.to_f,
      items:                live_items.map(&:payload),
      complete:             complete?,
      missing:              missing,
    }
    data.merge!(master_payload) if %i[master admin].include?(view)
    data.merge!(company_payload) if view == :admin
    data
  end

  # An internal note on the backing ticket: what was done and the sums the
  # client sees, without the shares.
  def ticket_note
    [
      "#{['Отчёт мастера', master&.fullname].compact_blank.join(' ')}:",
      *live_items.map { |item| item_note(item) },
      "Итого: #{format_money(total)} (работы #{format_money(works_total)}, запчасти #{format_money(parts_total)})",
      "Оплата: #{payment_method_label || 'не указана'}, получено #{format_money(amount_paid)}",
      ("Что сделано: #{work_summary}" if work_summary.present?),
      ("Рекомендации: #{recommendations}" if recommendations.present?),
    ].compact.join("\n")
  end

  private

  def master_payload
    {
      master_percent:      master_percent.to_f,
      master_amount:       master_amount.to_f,
      parts_reimbursement: parts_reimbursement.to_f,
      master_payout:       master_payout.to_f,
      master_settlement:   master_settlement.to_f,
    }
  end

  def company_payload
    {
      partner_percent: partner_percent.to_f,
      partner_base:    partner_base,
      partner_amount:  partner_amount.to_f,
      company_amount:  company_amount.to_f,
    }
  end

  def item_note(item)
    "- #{item.name}: #{format_number(item.quantity)} #{item.unit} × #{format_money(item.price)} = #{format_money(item.line_amount)}"
  end

  def calculate
    calculate_totals
    calculate_shares
    calculate_settlement
  end

  def calculate_totals
    rows = live_items

    self.works_total         = amount_of(rows.select(&:work?))
    self.parts_total         = amount_of(rows.select(&:part?))
    self.total               = works_total + parts_total
    self.parts_reimbursement = amount_of(rows.select { |item| item.part? && item.bought_by_master })
  end

  def calculate_shares
    self.master_amount  = percent_of(works_total, master_percent)
    self.master_payout  = master_amount + parts_reimbursement
    self.partner_amount = percent_of(partner_base == 'total' ? total : works_total, partner_percent)
    self.company_amount = total - partner_amount - master_payout
  end

  def calculate_settlement
    self.money_at_master   = MASTER_PAYMENT_METHODS.include?(payment_method) ? amount_paid.to_d : BigDecimal('0')
    self.master_settlement = master_payout - money_at_master
  end

  def amount_of(rows)
    rows.sum(BigDecimal('0'), &:line_amount)
  end

  def percent_of(value, percent)
    (value.to_d * percent.to_d / 100).round(2)
  end

  def items_within_limit
    return if live_items.size <= MAX_ITEMS

    errors.add(:items, "больше #{MAX_ITEMS} позиций")
  end

  def format_money(value)
    "#{format_number(value)} ₽"
  end

  def format_number(value)
    number = value.to_d.round(2)
    number.frac.zero? ? number.to_i.to_s : format('%.2f', number).tr('.', ',')
  end
end
