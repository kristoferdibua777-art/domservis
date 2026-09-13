# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::PoliciesControllerPolicy < Controllers::ApplicationControllerPolicy
  def show?
    user.permissions?('dom_servis.admin') || user.permissions?('dom_servis.dispatcher') || user.permissions?('dom_servis.master')
  end
end
