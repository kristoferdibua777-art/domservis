# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class CreateDomServisAdminPermission < ActiveRecord::Migration[7.2]
  def up
    Permission.create_if_not_exists(
      name:        'dom_servis.admin',
      label:       'Dom-Servis Admin',
      description: 'Access the Dom-Servis administrative workspace and dispatch policy controls.',
      allow_signup: false,
      preferences: {
        prio: 3490,
        translations: ['Dom-Servis Admin'],
      },
    )

    Role.where(name: 'Dom-Servis Admin').find_each do |role|
      role.permission_grant('dom_servis.admin')
      role.permission_revoke('admin.dom_servis_dispatch') if Permission.exists?(name: 'admin.dom_servis_dispatch')
      role.save!
    end

    setting = Setting.find_by(name: 'dom_servis_dispatch_policy')
    if setting
      setting.preferences ||= {}
      setting.preferences['permission'] = ['dom_servis.admin']
      setting.save!
    end
  end

  def down
    Role.where(name: 'Dom-Servis Admin').find_each do |role|
      role.permission_revoke('dom_servis.admin') if role.with_permission?('dom_servis.admin')
      role.save!
    end

    setting = Setting.find_by(name: 'dom_servis_dispatch_policy')
    if setting
      setting.preferences ||= {}
      setting.preferences['permission'] = ['admin.dom_servis_dispatch']
      setting.save!
    end

    Permission.find_by(name: 'dom_servis.admin')&.destroy!
  end
end
