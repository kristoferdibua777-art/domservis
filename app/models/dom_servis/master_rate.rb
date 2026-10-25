# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The master's share of a job (decision 2026-10-24): a percent of the works
# of the report. Parts the master bought are paid back in full.
class DomServis::MasterRate < ApplicationModel
  self.table_name = 'dom_servis_master_rates'

  belongs_to :user

  validates :user_id, uniqueness: true
  validates :work_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def self.percent_for(user_id)
    return 0 if user_id.blank?

    find_by(user_id:)&.work_percent || 0
  end
end
