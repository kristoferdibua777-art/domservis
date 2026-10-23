# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Shares of masters and partners for the report calculator (decision
# 2026-10-24), set by the admin in Dispatch Admin: a percent of the works for
# each master, a percent of the works or of the total for each partner
# organization. Reports of jobs that are not closed yet follow them.
class DomServis::Dispatch::FinanceRatesController < DomServis::Dispatch::BaseController
  def show
    render json: payload, status: :ok
  end

  def update
    ActiveRecord::Base.transaction do
      Array(rates_params[:masters]).each { |row| save_master_rate!(row) }
      Array(rates_params[:partners]).each { |row| save_partner_rate!(row) }
    end

    render json: payload, status: :ok
  end

  private

  def payload
    master_rates  = DomServis::MasterRate.all.index_by(&:user_id)
    partner_rates = DomServis::PartnerRate.all.index_by(&:organization_id)

    {
      masters:  masters.map do |user|
        { user_id: user.id, name: user.fullname, work_percent: master_rates[user.id]&.work_percent.to_f }
      end,
      partners: Organization.where(active: true).reorder(:name).map do |organization|
        rate = partner_rates[organization.id]
        { organization_id: organization.id, name: organization.name, percent: rate&.percent.to_f, base: rate&.base || 'works' }
      end,
      bases:    [{ id: 'works', label: 'от работ' }, { id: 'total', label: 'от всей суммы' }],
    }
  end

  def masters
    role_ids = Role.with_permissions('dom_servis.master').pluck(:id)
    User.joins(:roles).where(roles: { id: role_ids }, users: { active: true }).distinct.reorder(:firstname, :lastname, :id)
  end

  def save_master_rate!(row)
    rate = DomServis::MasterRate.find_or_initialize_by(user_id: User.find(row[:user_id]).id)
    rate.update!(work_percent: percent(row[:work_percent]))
  rescue ActiveRecord::RecordInvalid
    raise Exceptions::UnprocessableEntity, "Процент мастера должен быть от 0 до 100: «#{row[:work_percent]}»."
  end

  def save_partner_rate!(row)
    rate = DomServis::PartnerRate.find_or_initialize_by(organization_id: Organization.find(row[:organization_id]).id)
    rate.update!(percent: percent(row[:percent]), base: row[:base].presence || 'works')
  rescue ActiveRecord::RecordInvalid
    raise Exceptions::UnprocessableEntity, "Процент партнёра должен быть от 0 до 100: «#{row[:percent]}»."
  end

  def percent(value)
    value.to_s.delete("  %").tr(',', '.').presence || 0
  end

  def rates_params
    params.permit(masters: %i[user_id work_percent], partners: %i[organization_id percent base]).to_h.with_indifferent_access
  end
end
