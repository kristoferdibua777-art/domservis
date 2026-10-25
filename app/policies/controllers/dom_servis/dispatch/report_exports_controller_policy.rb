# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::ReportExportsControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! %i[show], to: 'dom_servis.admin'
end
