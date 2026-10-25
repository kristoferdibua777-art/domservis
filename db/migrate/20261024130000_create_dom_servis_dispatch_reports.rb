# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Master reports (decision 2026-10-24): a master finishes a job only with a
# report of the works and parts with their prices, the client's payment,
# what was done, recommendations and a photo or an act. Prices come from the
# price list and can be changed in the report; the master's share is a
# percent of the works, the partner's share a percent of the works or of the
# whole sum (admin settings).
class CreateDomServisDispatchReports < ActiveRecord::Migration[7.2]
  def change
    create_price_items
    create_master_rates
    create_partner_rates
    create_reports
    create_report_items
  end

  private

  def create_price_items
    create_table :dom_servis_price_items, id: :integer do |t|
      t.string :name, limit: 250, null: false
      t.string :kind, limit: 20, null: false, default: 'work'
      t.string :direction, limit: 100
      t.string :unit, limit: 20, null: false, default: 'шт'
      t.decimal :price, precision: 12, scale: 2, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps limit: 3, null: false
    end
  end

  def create_master_rates
    create_table :dom_servis_master_rates, id: :integer do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, type: :integer, index: { unique: true }
      t.decimal :work_percent, precision: 5, scale: 2, null: false, default: 0

      t.timestamps limit: 3, null: false
    end
  end

  def create_partner_rates
    create_table :dom_servis_partner_rates, id: :integer do |t|
      t.references :organization, null: false, foreign_key: { on_delete: :cascade }, type: :integer, index: { unique: true }
      t.decimal :percent, precision: 5, scale: 2, null: false, default: 0
      t.string :base, limit: 20, null: false, default: 'works'

      t.timestamps limit: 3, null: false
    end
  end

  def create_reports
    create_table :dom_servis_dispatch_reports, id: :integer do |t|
      t.references :dispatch_job, null: false, type: :integer, foreign_key: { to_table: :dom_servis_dispatch_jobs }, index: { unique: true }
      t.references :master, type: :integer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :submitted_by, type: :integer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :updated_by, type: :integer, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :submitted_at, limit: 3
      t.text :work_summary
      t.text :recommendations
      t.string :payment_method, limit: 30
      t.decimal :amount_paid, precision: 12, scale: 2, null: false, default: 0
      t.decimal :works_total, precision: 12, scale: 2, null: false, default: 0
      t.decimal :parts_total, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0
      t.decimal :master_percent, precision: 5, scale: 2, null: false, default: 0
      t.decimal :master_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :parts_reimbursement, precision: 12, scale: 2, null: false, default: 0
      t.decimal :master_payout, precision: 12, scale: 2, null: false, default: 0
      t.decimal :partner_percent, precision: 5, scale: 2, null: false, default: 0
      t.string :partner_base, limit: 20, null: false, default: 'works'
      t.decimal :partner_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :company_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :money_at_master, precision: 12, scale: 2, null: false, default: 0
      t.decimal :master_settlement, precision: 12, scale: 2, null: false, default: 0

      t.timestamps limit: 3, null: false
    end
  end

  def create_report_items
    create_table :dom_servis_dispatch_report_items, id: :integer do |t|
      t.references :dispatch_report, null: false, type: :integer, foreign_key: { to_table: :dom_servis_dispatch_reports }
      t.references :price_item, type: :integer, foreign_key: { to_table: :dom_servis_price_items, on_delete: :nullify }
      t.integer :position, null: false, default: 0
      t.string :kind, limit: 20, null: false, default: 'work'
      t.string :name, limit: 250, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false, default: 1
      t.string :unit, limit: 20, null: false, default: 'шт'
      t.decimal :list_price, precision: 12, scale: 2
      t.decimal :price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :amount, precision: 12, scale: 2, null: false, default: 0
      t.boolean :bought_by_master, null: false, default: false

      t.timestamps limit: 3, null: false
    end
  end
end
