# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddDomServisDispatchBackingTicketGroupSetting < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Setting.create_if_not_exists(
      title:       'Dom-Servis backing ticket group',
      name:        'dom_servis_dispatch_backing_ticket_group_id',
      area:        'DomServis::Dispatch',
      description: 'Defines which group backing tickets created from the Dom-Servis dispatch board are filed under. Falls back to an operator-accessible group when unset or when the configured group is not accessible.',
      options:     {
        form: [
          {
            display:  '',
            null:     true,
            name:     'dom_servis_dispatch_backing_ticket_group_id',
            tag:      'tree_select',
            multiple: false,
            relation: 'Group',
          },
        ],
      },
      state:       nil,
      preferences: {
        permission: ['dom_servis.admin'],
      },
      frontend:    false,
    )
  end

  def down
    Setting.where(name: 'dom_servis_dispatch_backing_ticket_group_id').destroy_all
  end
end
