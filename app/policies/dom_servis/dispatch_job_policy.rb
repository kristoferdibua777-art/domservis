# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::DispatchJobPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?
      return scope.all if dispatcher_access?

      if master_access?
        return scope.where(assignee_id: user.id).or(scope.where(status: 'pool', assignee_id: nil))
      end

      scope.none
    end

    private

    def dispatcher_access?
      user.permissions?('dom_servis.admin') || user.permissions?('dom_servis.dispatcher')
    end

    def master_access?
      user.permissions?('dom_servis.master')
    end
  end

  def show?
    return true if dispatcher_access?
    return true if record.assignee_id == user.id

    master_access? && record.status == 'pool' && record.assignee_id.blank?
  end

  def create?
    dispatcher_access?
  end

  def update?
    dispatcher_access?
  end

  def destroy?
    dispatcher_access?
  end

  def take?
    return true if dispatcher_access?

    master_access? && record.status == 'pool' && record.assignee_id.blank?
  end

  def release?
    return true if dispatcher_access?

    master_access? && record.assignee_id == user.id
  end

  def update_status?
    return true if dispatcher_access?

    master_access? && record.assignee_id == user.id
  end

  private

  def dispatcher_access?
    user.permissions?('dom_servis.admin') || user.permissions?('dom_servis.dispatcher')
  end

  def master_access?
    user.permissions?('dom_servis.master')
  end
end
