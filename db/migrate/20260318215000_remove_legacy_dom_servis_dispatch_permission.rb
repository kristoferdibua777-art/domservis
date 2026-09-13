# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class RemoveLegacyDomServisDispatchPermission < ActiveRecord::Migration[7.2]
  LEGACY_PERMISSION = 'admin.dom_servis_dispatch'

  def up
    permission = Permission.find_by(name: LEGACY_PERMISSION)
    return if !permission

    Role.joins(:permissions).where(permissions: { id: permission.id }).distinct.find_each do |role|
      role.permission_revoke(LEGACY_PERMISSION)
      role.save!
    end

    permission.destroy!
  end

  def down
    Permission.create_if_not_exists(
      name:        LEGACY_PERMISSION,
      label:       'Dom-Servis Dispatch',
      description: 'Legacy Dom-Servis dispatch admin permission kept only for rollback compatibility.',
      preferences: {
        translations: ['Dom-Servis Dispatch'],
      },
    )
  end
end
