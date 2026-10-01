# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Zammad::Application.routes.draw do
  scope Rails.configuration.api_path do
    namespace :dom_servis do
      namespace :dispatch do
        resource :policy, only: %i[show], controller: :policies
        resource :admin_policy, only: %i[show update], controller: :admin_policies do
          post :reset
        end
        resources :tags, only: %i[index], controller: :tags

        resources :history_exports, only: %i[index create], controller: :history_exports do
          member do
            get :download
            post :purge
          end
        end

        resources :jobs, only: %i[index show create update destroy] do
          collection do
            post :parse_input
          end

          member do
            post :take
            post :assign
            post :release
            post :status, action: :update_status
            post :move_day
            post :change_priority
            post :resync_ticket
          end

          resources :events, only: %i[index]
          resources :attachments, only: %i[index show create destroy], controller: :attachments
        end

        # Web Push subscription management for the dispatch board PWA.
        resources :push_subscriptions, only: %i[create destroy], controller: '/dom_servis/push_subscriptions' do
          collection { post :test }
        end
      end
    end
  end
end
