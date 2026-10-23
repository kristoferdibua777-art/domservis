# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The partner's share of a job of its organization (decision 2026-10-24): a
# percent of the works or of the whole sum of the report.
class DomServis::PartnerRate < ApplicationModel
  self.table_name = 'dom_servis_partner_rates'

  BASES = %w[works total].freeze

  belongs_to :organization

  validates :organization_id, uniqueness: true
  validates :percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :base, inclusion: { in: BASES }

  def self.terms_for(organization_id)
    rate = organization_id.present? ? find_by(organization_id:) : nil

    { percent: rate&.percent || 0, base: rate&.base || 'works' }
  end
end
