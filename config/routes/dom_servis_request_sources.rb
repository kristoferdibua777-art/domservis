# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Zammad::Application.routes.draw do
  scope Rails.configuration.api_path do
      namespace :dom_servis do
        resources :request_sources, only: %i[index show create update destroy], controller: :request_sources do
          collection do
          match :search, via: %i[get post]
          end
        end
      end
  end
end
