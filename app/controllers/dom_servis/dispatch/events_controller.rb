# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::EventsController < DomServis::Dispatch::BaseController
  def index
    job = dispatch_job_scope.find(params[:job_id])
    authorize job, :show?

    render json: job.events.ordered_recent.map(&:attributes_with_association_ids), status: :ok
  end
end
