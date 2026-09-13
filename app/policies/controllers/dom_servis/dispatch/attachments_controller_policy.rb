# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::AttachmentsControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit! ['dom_servis.admin']
  permit! %i[index show create], to: ['dom_servis.admin', 'dom_servis.dispatcher', 'dom_servis.master']
  permit! %i[destroy], to: ['dom_servis.admin', 'dom_servis.dispatcher']
end
