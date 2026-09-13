# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class BackfillDomServisAdminGroupAccess < ActiveRecord::Migration[7.2]
  def up
    ticket_group = Group.find_by(name: 'Users') || Group.find_by(id: 1)
    return if !ticket_group

    User.where(active: true).find_each do |user|
      next if !user.permissions?('ticket.agent')
      next if user.group_ids_access('create').present?

      user.group_ids_access_map = { ticket_group.id => 'full' }
      user.save!
    end
  end

  def down
    # Intentionally left blank. The backfill is idempotent and only restores the
    # expected access baseline for Dom-Servis operational users.
  end
end
