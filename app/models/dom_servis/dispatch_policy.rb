# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::DispatchPolicy
  SETTING_NAME = 'dom_servis_dispatch_policy'
  ROLE_KEYS    = %w[master dispatcher admin].freeze

  READ_ONLY_FIELDS = %w[
    id
    job_code
    created_at
    updated_at
    created_by_id
    updated_by_id
    published_at
    taken_at
    completed_at
    cancelled_at
  ].freeze

  ROLE_REGISTRY = [
    {
      key:          'master',
      label:        'Master',
      base_role:    'Agent',
      overlay_role: 'Dom-Servis Master',
      permission:   'dom_servis.master',
      description:  'Takes jobs from the shared pool and moves owned jobs through the master workflow.',
    },
    {
      key:          'dispatcher',
      label:        'Dispatcher',
      base_role:    'Agent',
      overlay_role: 'Dom-Servis Dispatcher',
      permission:   'dom_servis.dispatcher',
      description:  'Creates, edits, reschedules and coordinates jobs across the board.',
    },
    {
      key:          'admin',
      label:        'Owner / Admin',
      base_role:    'Admin',
      overlay_role: 'Dom-Servis Admin',
      permission:   'dom_servis.admin',
      description:  'Owns the dispatch policy, dashboards and administrative control of the module.',
    },
  ].freeze

  ACTION_GROUPS = [
    {
      key:   'job_lifecycle',
      label: 'Job lifecycle actions',
      items: [
        { key: 'create_job',            label: 'Create job',            description: 'Open and submit a new dispatch job into the board.' },
        { key: 'publish_to_pool',       label: 'Publish to pool',       description: 'Expose a newly created job to the shared master pool.' },
        { key: 'take_job',              label: 'Take job',              description: 'Claim a shared pool job.' },
        { key: 'release_to_pool',       label: 'Release to pool',       description: 'Return an owned job back into the pool.' },
        { key: 'set_status_in_progress', label: 'Set in progress',      description: 'Move a job into active execution.' },
        { key: 'set_status_done',       label: 'Set done',              description: 'Mark a job as completed.' },
        { key: 'cancel_job',            label: 'Cancel job',            description: 'Cancel an active or pending job.' },
        { key: 'transfer_to_partner',   label: 'Transfer to partner',   description: 'Close the job on our board and hand it off to a partner service.' },
        { key: 'reopen_job',            label: 'Reopen job',            description: 'Reopen a completed or cancelled job.' },
      ],
    },
    {
      key:   'coordination',
      label: 'Coordination actions',
      items: [
        { key: 'move_job_day',          label: 'Move job day',          description: 'Move a job to another weekday inside the dispatch board.' },
        { key: 'move_job_week',         label: 'Move job week',         description: 'Move a job across weeks.' },
        { key: 'change_priority',       label: 'Change priority',       description: 'Change the visual and operational priority of a job.' },
        { key: 'change_assignee',       label: 'Assign master',         description: 'Assign or reassign a job through the dedicated operational action.' },
        { key: 'edit_all_fields',       label: 'Edit all fields',       description: 'Open full payload editing for job data.' },
        { key: 'delete_job',            label: 'Delete job',            description: 'Delete a dispatch job from the board.' },
      ],
    },
    {
      key:   'job_content',
      label: 'Content and evidence',
      items: [
        { key: 'add_comment',           label: 'Add comment',           description: 'Add or update an operational comment on the job.' },
        { key: 'add_attachment',        label: 'Add attachment',        description: 'Attach files, photos or evidence to the job.' },
        { key: 'remove_attachment',     label: 'Remove attachment',     description: 'Remove files from the job payload.' },
      ],
    },
  ].freeze

  STATUS_REGISTRY = [
    { key: 'pool',        label: 'Pool',        description: 'Shared pool state before a master claims the job.' },
    { key: 'taken',       label: 'Taken',       description: 'Claimed by a worker but not yet started.' },
    { key: 'in_progress', label: 'In progress', description: 'Actively being worked on.' },
    { key: 'done',        label: 'Done',        description: 'Completed and closed for the operational workflow.' },
    { key: 'cancelled',   label: 'Cancelled',   description: 'Cancelled before completion.' },
    { key: 'transferred_to_partner', label: 'Transferred to partner', description: 'Closed on the Dom-Servis board after handoff to a partner service.' },
  ].freeze

  SETTINGS_REGISTRY = [
    {
      key:         'deadline_warning_minutes',
      label:       'Deadline warning minutes',
      description: 'How many minutes before the visit deadline a pool job should turn red on the board.',
      default:     120,
      min:         1,
      step:        5,
    },
  ].freeze

  FIELD_METADATA = {
    'job_code'     => { label: 'Job code',      group: 'identity',     source: 'db' },
    'source'       => { label: 'Source',        group: 'identity',     source: 'db' },
    'status'       => { label: 'Status',        group: 'lifecycle',    source: 'db' },
    'priority'     => { label: 'Priority',      group: 'lifecycle',    source: 'db' },
    'visit_day'    => { label: 'Visit day',     group: 'schedule',     source: 'db' },
    'visit_date'   => { label: 'Visit date',    group: 'schedule',     source: 'db' },
    'visit_time'   => { label: 'Visit time',    group: 'schedule',     source: 'db' },
    'address'      => { label: 'Address',       group: 'customer',     source: 'db' },
    'client_name'  => { label: 'Client name',   group: 'customer',     source: 'db' },
    'client_phone' => { label: 'Client phone',  group: 'customer',     source: 'db' },
    'service_type' => { label: 'Service type',  group: 'job_content',  source: 'db' },
    'description'  => { label: 'Description',   group: 'job_content',  source: 'db' },
    'comment'      => { label: 'Comment',       group: 'job_content',  source: 'db' },
    'work_tags'    => { label: 'Work tags',     group: 'job_content',  source: 'db' },
    'assignee_id'  => { label: 'Assignee',      group: 'assignment',   source: 'db' },
    'ticket_id'    => { label: 'Linked ticket', group: 'assignment',   source: 'db' },
    'published_at' => { label: 'Published at',  group: 'lifecycle',    source: 'db' },
    'taken_at'     => { label: 'Taken at',      group: 'lifecycle',    source: 'db' },
    'completed_at' => { label: 'Completed at',  group: 'lifecycle',    source: 'db' },
    'cancelled_at' => { label: 'Cancelled at',  group: 'lifecycle',    source: 'db' },
    'organization_id' => { label: 'Customer account', group: 'customer', source: 'db' },
    'attachments'  => { label: 'Attachments',   group: 'attachments',  source: 'virtual' },
  }.freeze

  FIELD_GROUPS = {
    'identity'    => 'Identity',
    'customer'    => 'Customer',
    'schedule'    => 'Scheduling',
    'job_content' => 'Job content',
    'assignment'  => 'Assignment',
    'lifecycle'   => 'Lifecycle',
    'attachments' => 'Attachments',
    'other'       => 'Other',
  }.freeze

  class << self
    def registry
      {
        roles:         ROLE_REGISTRY,
        action_groups: ACTION_GROUPS,
        statuses:      STATUS_REGISTRY,
        field_groups:  grouped_fields,
        settings:      SETTINGS_REGISTRY,
      }
    end

    def current
      normalize(setting_value)
    end

    def reset!
      return if !setting_record

      Setting.reset(SETTING_NAME, true)
    end

    def set!(value)
      normalized = normalize(value)

      if setting_record
        Setting.set(SETTING_NAME, normalized, validate: false)
      end

      normalized
    end

    def effective_for(user)
      role_key = role_key_for(user)
      policy   = current

      {
        role_key: role_key,
        actions:  policy['actions'].transform_values { |entry| entry[role_key] == true },
        statuses: policy['statuses'].transform_values { |entry| entry[role_key] == true },
        fields:   policy['fields'].transform_values do |entry|
          role_entry = entry[role_key] || {}

          {
            'visible'  => role_entry['visible'] == true,
            'editable' => role_entry['editable'] == true,
          }
        end,
        settings: policy['settings'],
      }
    end

    def role_key_for(user)
      return 'admin' if user.permissions?('dom_servis.admin')
      return 'dispatcher' if user.permissions?('dom_servis.dispatcher')
      return 'master' if user.permissions?('dom_servis.master')

      'master'
    end

    def action_allowed?(user, action_key)
      effective_for(user).dig(:actions, action_key.to_s) == true
    end

    def status_allowed?(user, status_key)
      effective_for(user).dig(:statuses, status_key.to_s) == true
    end

    def editable_field?(user, field_key)
      effective_for(user).dig(:fields, field_key.to_s, 'editable') == true
    end

    private

    def action_items
      @action_items ||= ACTION_GROUPS.flat_map { |group| group[:items] }
    end

    def field_entries
      fields = DomServis::DispatchJob.column_names.each_with_object([]) do |name, result|
        next if %w[created_by_id updated_by_id].include?(name)

        meta = FIELD_METADATA[name] || {}

        result << {
          'key'    => name,
          'label'  => meta[:label] || humanize_field(name),
          'group'  => meta[:group] || 'other',
          'source' => meta[:source] || 'db',
        }
      end

      FIELD_METADATA.each do |name, meta|
        next if fields.any? { |entry| entry['key'] == name }

        fields << {
          'key'    => name,
          'label'  => meta[:label] || humanize_field(name),
          'group'  => meta[:group] || 'other',
          'source' => meta[:source] || 'virtual',
        }
      end

      fields.sort_by { |entry| [FIELD_GROUPS.fetch(entry['group'], FIELD_GROUPS['other']), entry['label']] }
    end

    def grouped_fields
      field_entries
        .group_by { |entry| entry['group'] }
        .map do |group, items|
          {
            key:   group,
            label: FIELD_GROUPS.fetch(group, FIELD_GROUPS['other']),
            items: items,
          }
        end
    end

    def default_actions
      action_items.each_with_object({}) do |action, memo|
        memo[action[:key]] = {
          'master'     => action_default(action[:key], 'master'),
          'dispatcher' => action_default(action[:key], 'dispatcher'),
          'admin'      => action_default(action[:key], 'admin'),
        }
      end
    end

    def default_statuses
      STATUS_REGISTRY.each_with_object({}) do |status, memo|
        memo[status[:key]] = {
          'master'     => status_default(status[:key], 'master'),
          'dispatcher' => status_default(status[:key], 'dispatcher'),
          'admin'      => status_default(status[:key], 'admin'),
        }
      end
    end

    def default_fields
      field_entries.each_with_object({}) do |field, memo|
        memo[field['key']] = ROLE_KEYS.each_with_object({}) do |role, role_memo|
          role_memo[role] = {
            'visible'  => field_visible_default(field['key'], role),
            'editable' => field_editable_default(field['key'], role),
          }
        end
      end
    end

    def default_settings
      SETTINGS_REGISTRY.each_with_object({}) do |setting, memo|
        memo[setting[:key]] = setting_default(setting[:key])
      end
    end

    def defaults
      {
        'actions'  => default_actions,
        'statuses' => default_statuses,
        'fields'   => default_fields,
        'settings' => default_settings,
      }
    end

    def normalize(value)
      value    = (value || {}).deep_stringify_keys
      defaults = defaults()

      {
        'actions'  => normalize_action_matrix(value['actions'], defaults['actions']),
        'statuses' => normalize_action_matrix(value['statuses'], defaults['statuses']),
        'fields'   => normalize_field_matrix(value['fields'], defaults['fields']),
        'settings' => normalize_settings(value['settings'], defaults['settings']),
      }
    end

    def normalize_action_matrix(raw_matrix, default_matrix)
      raw_matrix = (raw_matrix || {}).deep_stringify_keys

      default_matrix.each_with_object({}) do |(key, default_roles), memo|
        memo[key] = ROLE_KEYS.each_with_object({}) do |role, role_memo|
          raw_value = raw_matrix.dig(key, role)
          role_memo[role] = raw_value.nil? ? default_roles[role] : ActiveModel::Type::Boolean.new.cast(raw_value)
        end
      end
    end

    def normalize_field_matrix(raw_matrix, default_matrix)
      raw_matrix = (raw_matrix || {}).deep_stringify_keys

      default_matrix.each_with_object({}) do |(key, default_roles), memo|
        memo[key] = ROLE_KEYS.each_with_object({}) do |role, role_memo|
          raw_role = (raw_matrix.dig(key, role) || {}).deep_stringify_keys

          role_memo[role] = {
            'visible'  => raw_role.key?('visible') ? ActiveModel::Type::Boolean.new.cast(raw_role['visible']) : default_roles[role]['visible'],
            'editable' => raw_role.key?('editable') ? ActiveModel::Type::Boolean.new.cast(raw_role['editable']) : default_roles[role]['editable'],
          }
        end
      end
    end

    def action_default(action_key, role_key)
      matrix = {
        'master' => %w[
          take_job
          release_to_pool
          set_status_in_progress
          set_status_done
          add_comment
          add_attachment
        ],
        'dispatcher' => %w[
          create_job
          publish_to_pool
          take_job
          release_to_pool
          set_status_in_progress
          set_status_done
          cancel_job
          transfer_to_partner
          reopen_job
          move_job_day
          move_job_week
          change_priority
          change_assignee
          edit_all_fields
          add_comment
          add_attachment
          remove_attachment
          delete_job
        ],
        'admin' => %w[
          create_job
          publish_to_pool
          take_job
          release_to_pool
          set_status_in_progress
          set_status_done
          cancel_job
          transfer_to_partner
          reopen_job
          move_job_day
          move_job_week
          change_priority
          change_assignee
          edit_all_fields
          add_comment
          add_attachment
          remove_attachment
          delete_job
        ],
      }

      matrix.fetch(role_key, []).include?(action_key)
    end

    def status_default(status_key, role_key)
      matrix = {
        'master' => %w[in_progress done],
        'dispatcher' => %w[pool taken in_progress done cancelled transferred_to_partner],
        'admin' => %w[pool taken in_progress done cancelled transferred_to_partner],
      }

      matrix.fetch(role_key, []).include?(status_key)
    end

    def field_visible_default(field_key, role_key)
      return false if role_key == 'master' && %w[ticket_id].include?(field_key)

      true
    end

    def field_editable_default(field_key, role_key)
      return false if READ_ONLY_FIELDS.include?(field_key)
      return false if field_key == 'assignee_id'
      return false if %w[status ticket_id organization_id attachments].include?(field_key) && role_key == 'master'
      return false if role_key == 'master'

      true
    end

    def normalize_settings(raw_settings, default_settings)
      raw_settings = (raw_settings || {}).deep_stringify_keys

      default_settings.each_with_object({}) do |(key, default_value), memo|
        memo[key] = normalize_setting_value(key, raw_settings.key?(key) ? raw_settings[key] : default_value)
      end
    end

    def normalize_setting_value(key, value)
      case key
      when 'deadline_warning_minutes'
        minutes = value.to_i
        minutes.positive? ? minutes : setting_default(key)
      else
        value
      end
    end

    def setting_default(key)
      case key
      when 'deadline_warning_minutes'
        120
      else
        nil
      end
    end

    def humanize_field(field_name)
      field_name.to_s.tr('_', ' ').split.map(&:capitalize).join(' ')
    end

    def setting_record
      @setting_record ||= Setting.find_by(name: SETTING_NAME)
    end

    def setting_value
      return {} if !setting_record

      Setting.get(SETTING_NAME) || {}
    end
  end
end
