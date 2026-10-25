# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::PoliciesController < DomServis::Dispatch::BaseController
  def show
    payload = DomServis::DispatchPolicy.effective_for(current_user).merge(
      registry: DomServis::DispatchPolicy.registry,
    )

    # Admins export the job history every 30 days; the board reminds them.
    payload[:history_export_due] = DomServis::DispatchHistoryExport.due? if current_user.permissions?('dom_servis.admin')

    # The board marks the pool jobs that fit the master (directions, areas).
    rate = DomServis::MasterRate.find_by(user_id: current_user.id)
    payload[:master_profile] = { directions: rate&.directions || [], areas: rate&.areas || [] }

    render json: payload, status: :ok
  end
end
