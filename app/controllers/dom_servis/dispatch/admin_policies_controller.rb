# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::AdminPoliciesController < DomServis::Dispatch::BaseController
  def show
    render json: payload, status: :ok
  end

  def update
    policy = params.require(:policy).permit!.to_h

    DomServis::DispatchPolicy.set!(policy)

    render json: payload, status: :ok
  end

  def reset
    DomServis::DispatchPolicy.reset!

    render json: payload, status: :ok
  end

  private

  def payload
    {
      stats:    dispatch_stats,
      tags:     DomServis::DispatchTagCatalog.entries,
      registry: DomServis::DispatchPolicy.registry,
      policy:   DomServis::DispatchPolicy.current,
    }
  end

  def dispatch_stats
    jobs = DomServis::DispatchJob.all

    {
      total:  jobs.count,
      pool:   jobs.where(status: 'pool').count,
      active: jobs.where(status: %w[taken in_progress]).count,
      done:   jobs.where(status: 'done').count,
    }
  end
end
