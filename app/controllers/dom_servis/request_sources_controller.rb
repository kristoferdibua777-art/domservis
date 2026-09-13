# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

class DomServis::RequestSourcesController < ApplicationController
  prepend_before_action :authenticate_and_authorize!

  def index
    model_index_render(DomServis::RequestSource.order(:id), params)
  end

  def show
    model_show_render(DomServis::RequestSource, params)
  end

  def create
    model_create_render(DomServis::RequestSource, params)
  end

  def update
    model_update_render(DomServis::RequestSource, params)
  end

  def destroy
    model_destroy_render(DomServis::RequestSource, params)
  end

  def search
    model_search_render(DomServis::RequestSource, params)
  end
end
