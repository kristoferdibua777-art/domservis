# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::DispatchRoleCatalog
  ROLE_DEFINITIONS = {
    'Dom-Servis Admin' => {
      note:       'Assign together with Admin. Grants the Dom-Servis administrative workspace and dispatch policy controls.',
      permission: 'dom_servis.admin',
    },
    'Dom-Servis Dispatcher' => {
      note:       'Assign together with Agent. Grants the Dom-Servis dispatcher workspace and dispatcher actions.',
      permission: 'dom_servis.dispatcher',
    },
    'Dom-Servis Master' => {
      note:       'Assign together with Agent. Grants the Dom-Servis master workspace and master actions.',
      permission: 'dom_servis.master',
    },
  }.freeze

  class << self
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
      User.order(:id).limit(1).pick(:id)
    end
  end
end
