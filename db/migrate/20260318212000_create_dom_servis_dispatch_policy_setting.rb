# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class CreateDomServisDispatchPolicySetting < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Setting.create_if_not_exists(
      title:       'Dom-Servis dispatch policy',
      name:        'dom_servis_dispatch_policy',
      area:        'DomServis::Dispatch',
      description: 'Stores the dispatch board role matrices for actions, statuses and fields.',
      options:     {},
      state:       {},
      preferences: {
        prio:       3600,
        permission: ['dom_servis.admin'],
      },
      frontend:    false
    )
  end
end
