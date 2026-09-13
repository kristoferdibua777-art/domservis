# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::JobsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit! ['dom_servis.admin']
  permit! %i[index show take release update_status], to: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master']
  permit! %i[create update destroy parse_input], to: ['dom_servis.admin', 'dom_servis.dispatcher']
end
