# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::Dispatch::TagsController < DomServis::Dispatch::BaseController
  def index
    render json: payload, status: :ok
  end

  private

  def payload
    {
      tags:   DomServis::DispatchTagCatalog.entries,
      groups: DomServis::DispatchTagCatalog.groups,
    }
  end
end
