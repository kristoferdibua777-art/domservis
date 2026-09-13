# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::AdminPoliciesControllerPolicy < Controllers::ApplicationControllerPolicy
  def show?
    access?
  end

  def update?
    access?
  end

  def reset?
    access?
  end

  private

  def access?
    user.permissions?('dom_servis.admin')
  end
end
