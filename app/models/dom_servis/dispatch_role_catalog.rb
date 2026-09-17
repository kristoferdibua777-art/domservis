# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::DispatchRoleCatalog
  ROLE_DEFINITIONS = {
    'Dom-Servis Admin'      => {
      note:       __('Assign together with Admin. Grants the Dom-Servis administrative workspace and dispatch policy controls.'),
      permission: 'dom_servis.admin',
    },
    'Dom-Servis Dispatcher' => {
      note:       __('Assign together with Agent. Grants the Dom-Servis dispatcher workspace and dispatcher actions.'),
      permission: 'dom_servis.dispatcher',
    },
    'Dom-Servis Master'     => {
      note:       __('Assign together with Agent. Grants the Dom-Servis master workspace and master actions.'),
      permission: 'dom_servis.master',
    },
  }.freeze

  # Mirrors the Permission attributes created by
  # db/migrate/20260318130001_add_dom_servis_dispatch_permissions.rb (left
  # untouched). ROLE_DEFINITIONS only carries a permission KEY per role, not
  # the full Permission metadata, so this has its own definition.
  PERMISSION_DEFINITIONS = {
    'dom_servis.admin'      => {
      label:       'Dom-Servis Admin',
      description: 'Access the Dom-Servis administrative workspace and dispatch policy controls.',
      preferences: {
        prio:         3490,
        translations: ['Dom-Servis Admin'],
      },
    },
    'dom_servis.dispatcher' => {
      label:        'Dom-Servis Dispatcher',
      description:  'Access the Dom-Servis dispatcher workspace.',
      allow_signup: false,
      preferences:  {
        prio: 3500,
      },
    },
    'dom_servis.master'     => {
      label:        'Dom-Servis Master',
      description:  'Access the Dom-Servis master workspace.',
      allow_signup: false,
      preferences:  {
        prio: 3510,
      },
    },
  }.freeze

  class << self
    # Idempotently ensures the three DomServis Permission rows exist, with
    # the same attributes as the migration above.
    def ensure_permissions!
      PERMISSION_DEFINITIONS.each do |name, attributes|
        Permission.create_if_not_exists(attributes.merge(name: name))
      end

      true
    end

    # Ensures the three DomServis permissions exist, then syncs the overlay
    # roles (see sync! below). Seed/bootstrap paths must not depend on the
    # migration above having already populated the permissions - use this,
    # not sync! directly, wherever that isn't already guaranteed.
    def bootstrap!(actor_id: first_user_id)
      ensure_permissions!
      sync!(actor_id: actor_id)
    end

    # Creates/updates the three DomServis overlay roles and grants each its
    # matching permission. Role-only: does not create the Permission rows
    # themselves (see ensure_permissions!/bootstrap! above) - raises 'Invalid
    # permission <key>' via Role#permission_grant if one is missing.
    def sync!(actor_id: first_user_id)
      return false if actor_id.blank?

      ROLE_DEFINITIONS.each do |name, definition|
        role = Role.find_or_initialize_by(name: name)
        role.active        = true
        role.note          = definition[:note]
        role.created_by_id ||= actor_id
        role.updated_by_id = actor_id

        role.permission_grant(definition[:permission])
        role.save!
      end

      true
    end

    def names
      ROLE_DEFINITIONS.keys
    end

    def seeded?
      Role.where(name: names).count == names.count
    end

    private

    def first_user_id
      User.reorder(:id).limit(1).pick(:id)
    end
  end
end
