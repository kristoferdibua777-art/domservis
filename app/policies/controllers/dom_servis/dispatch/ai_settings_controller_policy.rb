# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::AiSettingsControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! %i[show update check], to: 'dom_servis.admin'
end
