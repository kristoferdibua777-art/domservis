# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# What a master does and where (decision 2026-10-24): directions and areas of
# the work tag dictionary. A master is told about new jobs that fit them.
class AddDirectionsAndAreasToDomServisMasterRates < ActiveRecord::Migration[7.2]
  def change
    add_column :dom_servis_master_rates, :directions, :jsonb, null: false, default: []
    add_column :dom_servis_master_rates, :areas, :jsonb, null: false, default: []

    DomServis::MasterRate.reset_column_information
  end
end
