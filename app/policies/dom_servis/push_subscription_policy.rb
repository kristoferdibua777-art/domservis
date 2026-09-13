# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Policy for DomServis::PushSubscription.
#
# A master/dispatcher/admin may create push subscriptions only for their
# own user (the browser cannot register on behalf of someone else), and
# may only destroy their own subscriptions.
class DomServis::PushSubscriptionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?

      scope.where(user_id: user.id)
    end
  end

  def create?
    dispatch_access?
  end

  def destroy?
    dispatch_access? && record.user_id == user.id
  end

  private

  def dispatch_access?
    user.permissions?('dom_servis.admin') ||
      user.permissions?('dom_servis.dispatcher') ||
      user.permissions?('dom_servis.master')
  end
end
