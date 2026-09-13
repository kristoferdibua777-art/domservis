# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::RequestSourcesControllerPolicy < Controllers::ApplicationControllerPolicy
  default_permit! 'dom_servis.admin'
end
