# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::PriceListsControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! %i[show], to: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master']
  permit! %i[update], to: 'dom_servis.admin'
end
