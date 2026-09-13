# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::EventsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit! ['dom_servis.admin']
  permit! %i[index], to: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master']
end
