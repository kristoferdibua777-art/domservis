# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::PoliciesController < DomServis::Dispatch::BaseController
  def show
    render json: DomServis::DispatchPolicy.effective_for(current_user).merge(
      registry: DomServis::DispatchPolicy.registry,
    ), status: :ok
  end
end
