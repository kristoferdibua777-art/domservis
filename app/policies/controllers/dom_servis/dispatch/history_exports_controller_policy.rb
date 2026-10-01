# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::HistoryExportsControllerPolicy < Controllers::ApplicationControllerPolicy
  def index?
    access?
  end

  def create?
    access?
  end

  def download?
    access?
  end

  def purge?
    access?
  end

  private

  def access?
    user.permissions?('dom_servis.admin')
  end
end
