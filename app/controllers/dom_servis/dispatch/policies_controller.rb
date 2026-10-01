# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::PoliciesController < DomServis::Dispatch::BaseController
  def show
    payload = DomServis::DispatchPolicy.effective_for(current_user).merge(
      registry: DomServis::DispatchPolicy.registry,
    )

    # Admins export the job history every 30 days; the board reminds them.
    payload[:history_export_due] = DomServis::DispatchHistoryExport.due? if current_user.permissions?('dom_servis.admin')

    render json: payload, status: :ok
  end
end
