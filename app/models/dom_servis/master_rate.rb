# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# What the admin sets for a master (decisions 2026-10-24):
#
# - the share of a job: a percent of the works of the report; parts the
#   master bought are paid back in full;
# - directions and areas of the work tag dictionary: the master is told
#   about new jobs of those directions in those areas. A master without
#   them is told about every job, and so is everybody when no master fits,
#   so that a job never goes unnoticed.
class DomServis::MasterRate < ApplicationModel
  self.table_name = 'dom_servis_master_rates'

  belongs_to :user

  validates :user_id, uniqueness: true
  validates :work_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :directions_and_areas_are_known

  before_validation :normalize_directions_and_areas

  def self.percent_for(user_id)
    return 0 if user_id.blank?

    find_by(user_id:)&.work_percent || 0
  end

  # The masters among the given users that a job fits, or all of them when
  # none does.
  def self.fitting(job, users)
    tags  = Array(job.work_tags)
    rates = where(user_id: users.map(&:id)).index_by(&:user_id)
    fit   = users.select { |user| rates[user.id].nil? || rates[user.id].fits?(tags) }

    fit.presence || users.to_a
  end

  def fits?(job_tags)
    covers?(directions, job_tags & DomServis::WorkTagCatalog::DIRECTION_TAGS.values) &&
      covers?(areas, job_tags & DomServis::WorkTagCatalog::AREA_TAGS.keys)
  end

  private

  # Nothing set on either side means no restriction.
  def covers?(own, wanted)
    own.blank? || wanted.blank? || own.intersect?(wanted)
  end

  def normalize_directions_and_areas
    self.directions = Array(directions).map(&:to_s).compact_blank.uniq
    self.areas      = Array(areas).map(&:to_s).compact_blank.uniq
  end

  def directions_and_areas_are_known
    unknown = (directions - DomServis::WorkTagCatalog::DIRECTION_TAGS.values) + (areas - DomServis::WorkTagCatalog::AREA_TAGS.keys)
    return if unknown.empty?

    errors.add(:base, "нет в справочнике тегов: #{unknown.join(', ')}")
  end
end
