# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddDomServisDispatchPermissions < ActiveRecord::Migration[7.2]
  def up
    Permission.create_if_not_exists(
      name:        'dom_servis.admin',
      label:       'Dom-Servis Admin',
      description: 'Access the Dom-Servis administrative workspace and dispatch policy controls.',
      preferences: {
        prio: 3490,
        translations: ['Dom-Servis Admin']
      },
    )

    Permission.create_if_not_exists(
      name:        'dom_servis.dispatcher',
      label:       'Dom-Servis Dispatcher',
      description: 'Access the Dom-Servis dispatcher workspace.',
      allow_signup: false,
      preferences: {
        prio: 3500,
      },
    )

    Permission.create_if_not_exists(
      name:        'dom_servis.master',
      label:       'Dom-Servis Master',
      description: 'Access the Dom-Servis master workspace.',
      allow_signup: false,
      preferences: {
        prio: 3510,
      },
    )

  end

  def down
    Permission.where(name: %w[dom_servis.admin dom_servis.dispatcher dom_servis.master]).destroy_all
  end
end
