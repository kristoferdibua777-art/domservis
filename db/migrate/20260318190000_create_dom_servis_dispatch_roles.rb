# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class CreateDomServisDispatchRoles < ActiveRecord::Migration[7.2]
  def up
    DomServis::DispatchRoleCatalog.sync!
  end

  def down
    Role.where(name: DomServis::DispatchRoleCatalog.names).find_each(&:destroy!)
  end
end
