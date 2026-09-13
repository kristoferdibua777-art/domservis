# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::BaseController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  private

  def dispatch_job_scope
    policy_scope(DomServis::DispatchJob)
  end
end
