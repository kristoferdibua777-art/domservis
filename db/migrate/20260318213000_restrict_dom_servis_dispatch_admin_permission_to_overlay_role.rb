# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class RestrictDomServisDispatchAdminPermissionToOverlayRole < ActiveRecord::Migration[7.2]
  def up
    return if !Permission.exists?(name: 'admin.dom_servis_dispatch')

    Role.where(name: 'Admin').find_each do |role|
      next if !role.with_permission?('admin.dom_servis_dispatch')

      role.permission_revoke('admin.dom_servis_dispatch')
      role.save!
    end
  end

  def down
    return if !Permission.exists?(name: 'admin.dom_servis_dispatch')

    Role.where(name: 'Admin').find_each do |role|
      next if role.with_permission?('admin.dom_servis_dispatch')

      role.permission_grant('admin.dom_servis_dispatch')
      role.save!
    end
  end
end
