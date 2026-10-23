# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The tags a dispatch job can carry: the work tag dictionary in its order
# (DomServis::WorkTagCatalog), then the other Zammad tags by name.
class DomServis::DispatchTagCatalog
  class << self
    def entries(selected_names: [])
      selected_names = normalize_names(selected_names)

      names = (DomServis::WorkTagCatalog.names + Tag::Item.reorder(name: :asc).pluck(:name) + selected_names).uniq
      dispatch_counts = dispatch_usage_counts
      ticket_counts   = ticket_usage_counts

      names.map do |name|
        {
          id:             name,
          name:           name,
          group:          DomServis::WorkTagCatalog.group_key(name),
          dispatch_count: dispatch_counts.fetch(name, 0),
          ticket_count:   ticket_counts.fetch(name, 0),
          selected:       selected_names.include?(name),
        }
      end
    end

    def groups
      DomServis::WorkTagCatalog.groups.map { |group| group.slice(:key, :label) } + [DomServis::WorkTagCatalog::OTHER_GROUP]
    end

    # Dictionary tags are always valid: Zammad creates a missing one with its
    # first use on the backing ticket.
    def missing_names(names)
      normalize_names(names).reject { |name| DomServis::WorkTagCatalog.include?(name) || Tag::Item.exists?(name: name) }
    end

    def normalize_names(value)
      names =
        case value
        when Array
          value
        when String
          value.split(',')
        else
          []
        end

      names.filter_map do |item|
        normalized = item.to_s.strip
        normalized.presence
      end.uniq.first(25)
    end

    private

    def dispatch_usage_counts
      DomServis::DispatchJob.pluck(:work_tags).each_with_object(Hash.new(0)) do |tags, memo|
        Array(tags).each do |tag_name|
          normalized = tag_name.to_s.strip
          next if normalized.blank?

          memo[normalized] += 1
        end
      end
    end

    def ticket_usage_counts
      Tag.joins(:tag_item).group('tag_items.name').count
    end
  end
end
