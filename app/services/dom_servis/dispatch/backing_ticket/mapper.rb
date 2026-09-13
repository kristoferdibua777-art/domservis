# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::BackingTicket::Mapper
  CUSTOM_FIELDS = %i[
    dom_servis_job_code
    dom_servis_visit_day
    dom_servis_visit_date
    dom_servis_visit_time
    dom_servis_service_type
    dom_servis_client_name
    dom_servis_client_phone
    dom_servis_dispatch_status
    dom_servis_dispatch_priority
    dom_servis_dispatch_source
    dom_servis_address
    dom_servis_work_tags
    dom_servis_description
    dom_servis_comment
    dom_servis_assignee_name
  ].freeze

  def initialize(dispatch_job:, resolver:)
    @dispatch_job = dispatch_job
    @resolver = resolver
  end

  attr_reader :dispatch_job, :resolver

  def create_attributes
    base_attributes.merge(
      group_id:        resolver.group.id,
      customer_id:     resolver.customer.id,
      created_by_id:   resolver.actor_user&.id,
      updated_by_id:   resolver.actor_user&.id,
      organization_id: dispatch_job.organization_id,
      owner_id:        dispatch_job.assignee_id,
      state_id:        resolver.ticket_state&.id,
      priority_id:     resolver.ticket_priority&.id,
      title:           title,
    )
  end

  def update_attributes
    base_attributes.merge(
      updated_by_id:   resolver.actor_user&.id,
      organization_id: dispatch_job.organization_id,
      owner_id:        dispatch_job.assignee_id,
      state_id:        resolver.ticket_state&.id,
      priority_id:     resolver.ticket_priority&.id,
      title:           title,
    )
  end

  def creation_article
    {
      body:     ["Created from Dom-Servis dispatch board.", snapshot_body].join("\n\n"),
      internal: true,
      sender:   'Agent',
      type:     'note',
      subject:  'Dom-Servis dispatch job created',
    }
  end

  def change_article(changes)
    normalized_changes = normalize_changes(changes)
    return if normalized_changes.blank?

    lines = normalized_changes.flat_map { |event_type, meta| change_lines(event_type, meta) }.compact
    return if lines.blank?

    body_parts = [
      "Updated from Dom-Servis dispatch board by #{actor_name}.",
      lines.join("\n"),
    ]

    if normalized_changes.key?('comment_added')
      body_parts << "Current dispatch comment:\n#{dispatch_job.comment}"
    end

    if normalized_changes.key?('description_updated')
      body_parts << "Current dispatch description:\n#{dispatch_job.description}"
    end

    {
      body:     body_parts.join("\n\n"),
      internal: true,
      sender:   'Agent',
      type:     'note',
      subject:  'Dom-Servis dispatch job updated',
    }
  end

  private

  def base_attributes
    supported_custom_fields.each_with_object({}) do |field_name, memo|
      memo[field_name] = send(field_name)
    end
  end

  def supported_custom_fields
    @supported_custom_fields ||= CUSTOM_FIELDS.select { |field_name| Ticket.column_names.include?(field_name.to_s) }
  end

  def title
    [
      dispatch_job.job_code,
      dispatch_job.service_type,
      dispatch_job.address,
    ].compact.join(' | ').truncate(200)
  end

  def snapshot_body
    [
      "Job code: #{dispatch_job.job_code}",
      "Service type: #{dispatch_job.service_type}",
      ("Organization: #{dispatch_job.organization.name}" if dispatch_job.organization),
      "Client: #{client_line}",
      "Address: #{dispatch_job.address}",
      "Schedule: #{schedule_line}",
      "Status: #{status_name(dispatch_job.status)}",
      "Priority: #{dispatch_job.priority}",
      "Assignee: #{assignee_name}",
      "Source: #{dispatch_job.source}",
      ("Work tags: #{dispatch_job.work_tags.join(', ')}" if dispatch_job.work_tags.present?),
      ("Description:\n#{dispatch_job.description}" if dispatch_job.description.present?),
      ("Dispatcher comment:\n#{dispatch_job.comment}" if dispatch_job.comment.present?),
    ].compact.join("\n")
  end

  def change_lines(event_type, meta)
    case event_type
    when 'taken'
      ["- Taken by #{actor_name}."]
    when 'released'
      ['- Returned to shared pool.']
    when 'status_changed'
      ["- Status: #{status_name(meta['from'] || meta[:from])} -> #{status_name(meta['to'] || meta[:to])}."]
    when 'priority_changed'
      ["- Priority: #{value_or_dash(meta['from'] || meta[:from])} -> #{value_or_dash(meta['to'] || meta[:to])}."]
    when 'moved_weekday'
      ["- Visit day: #{value_or_dash(meta['from'] || meta[:from])} -> #{value_or_dash(meta['to'] || meta[:to])}."]
    when 'comment_added'
      ['- Dispatch comment updated.']
    when 'description_updated'
      ['- Dispatch description updated.']
    when 'organization_changed'
      ["- Organization: #{organization_name(meta['from'] || meta[:from])} -> #{organization_name(meta['to'] || meta[:to])}."]
    when 'tags_changed'
      ["- Work tags: #{Array(meta['to'] || meta[:to]).join(', ')}."]
    when 'assigned'
      ["- Assigned to #{user_name(meta['to'] || meta[:to])}."]
    when 'assignee_changed'
      ["- Assignee: #{user_name(meta['from'] || meta[:from])} -> #{user_name(meta['to'] || meta[:to])}."]
    else
      nil
    end
  end

  def normalize_changes(changes)
    (changes || {}).deep_stringify_keys
  end

  def actor_name
    user_name(resolver.actor_user)
  end

  def assignee_name
    user_name(dispatch_job.assignee)
  end

  def client_line
    parts = [dispatch_job.client_name.presence, dispatch_job.client_phone.presence].compact
    return '-' if parts.blank?

    parts.join(' / ')
  end

  def schedule_line
    parts = [dispatch_job.visit_day.presence, dispatch_job.visit_date.presence, dispatch_job.visit_time.presence].compact
    return '-' if parts.blank?

    parts.join(' / ')
  end

  def user_name(user_or_id)
    user =
      case user_or_id
      when User
        user_or_id
      when nil, ''
        nil
      else
        User.find_by(id: user_or_id)
      end

    return '-' if user.blank?
    return user.fullname if user.fullname.present?

    user.login.presence || user.email.presence || user.id.to_s
  end

  def organization_name(organization_id)
    return '-' if organization_id.blank?

    Organization.find_by(id: organization_id)&.name || organization_id.to_s
  end

  def value_or_dash(value)
    value.present? ? value : '-'
  end

  def status_name(value)
    case value.to_s
    when 'pool'
      'Pool'
    when 'taken'
      'Taken'
    when 'in_progress'
      'In progress'
    when 'done'
      'Done'
    when 'cancelled'
      'Cancelled'
    when 'transferred_to_partner'
      'Transferred to partner'
    else
      value_or_dash(value)
    end
  end

  def dom_servis_job_code
    dispatch_job.job_code
  end

  def dom_servis_visit_day
    dispatch_job.visit_day
  end

  def dom_servis_visit_date
    dispatch_job.visit_date
  end

  def dom_servis_visit_time
    dispatch_job.visit_time
  end

  def dom_servis_service_type
    dispatch_job.service_type
  end

  def dom_servis_client_name
    dispatch_job.client_name
  end

  def dom_servis_client_phone
    dispatch_job.client_phone
  end

  def dom_servis_dispatch_status
    dispatch_job.status
  end

  def dom_servis_dispatch_priority
    dispatch_job.priority
  end

  def dom_servis_dispatch_source
    dispatch_job.source
  end

  def dom_servis_address
    dispatch_job.address
  end

  def dom_servis_work_tags
    dispatch_job.work_tags.join(', ')
  end

  def dom_servis_description
    dispatch_job.description
  end

  def dom_servis_comment
    dispatch_job.comment
  end

  def dom_servis_assignee_name
    assignee_name
  end
end
