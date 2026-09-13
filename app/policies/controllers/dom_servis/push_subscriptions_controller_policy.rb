# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::PushSubscriptionsControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! %i[create destroy test], to: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master']
end
