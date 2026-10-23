# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class Controllers::DomServis::Dispatch::FinanceRatesControllerPolicy < Controllers::ApplicationControllerPolicy
  permit! %i[show update], to: 'dom_servis.admin'
end
