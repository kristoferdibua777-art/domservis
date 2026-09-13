# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

Zammad::Application.routes.draw do
  get '/dispatch',                      to: 'dispatch_board#index'
  get '/dispatch/sw.js',                to: 'dispatch_board#service_worker'
  get '/dispatch/manifest.webmanifest', to: 'dispatch_board#manifest'
  get '/dispatch/*path',                to: 'dispatch_board#index'
end
