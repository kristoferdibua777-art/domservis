# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::EventsController < DomServis::Dispatch::BaseController
  def index
    job = dispatch_job_scope.find(params[:job_id])
    authorize job, :show?

    events = job.events.includes(:actor_user).ordered_recent
    render json: events.map { |event| event.attributes_with_association_ids.merge('actor_name' => event.actor_user&.fullname) }, status: :ok
  end
end
