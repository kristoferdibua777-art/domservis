# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::DispatchSchedule
  DATE_PATTERN = %r{\A\d{4}-\d{2}-\d{2}\z}
  TIME_COMPONENT = '(?:[01]\d|2[0-3]):[0-5]\d'.freeze
  TIME_PATTERN = %r{\A#{TIME_COMPONENT}\z}
  TIME_WINDOW_PATTERN = %r{\A#{TIME_COMPONENT}-#{TIME_COMPONENT}\z}
  WEEKDAY_KEYS = %w[sun mon tue wed thu fri sat].freeze

  class << self
    def parse_date(value)
      return if value.blank?

      string = value.to_s
      return if !string.match?(DATE_PATTERN)

      Date.iso8601(string)
    rescue Date::Error
      nil
    end

    def valid_manual_time?(value)
      value.blank? || value.to_s.match?(TIME_PATTERN) || value.to_s.match?(TIME_WINDOW_PATTERN)
    end

    def weekday_key(date)
      WEEKDAY_KEYS.fetch(date.wday)
    end
  end
end
