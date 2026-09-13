# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class AddDomServisAdminRole < ActiveRecord::Migration[7.2]
  def up
    DomServis::DispatchRoleCatalog.sync!
  end

  def down
    Role.find_by(name: 'Dom-Servis Admin')&.destroy!
  end
end
