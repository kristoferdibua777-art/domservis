# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Standalone PWA entry point for the Dom-Servis dispatch board.
#
# Mirrors the MobileController pattern: serves a dedicated HTML shell
# (with manifest + service worker registration) that boots the legacy
# CoffeeScript dispatch board inside a fullscreen standalone web app.
# This lets masters install an app-like icon on their phone home screen
# and later receive Web Push notifications through the dispatch SW.

class DispatchBoardController < ApplicationController
  # Skip CSRF protection for the manifest and service worker endpoints.
  # Both are public read-only responses and must be reachable before
  # the session-dependent app shell finishes booting.
  skip_before_action :verify_csrf_token, only: %i[service_worker manifest]

  def index
    render(layout: 'layouts/dispatch_board', locals: { locale: current_user&.preferences&.dig(:locale) })
  end

  def service_worker
    # The dispatch service worker is a dependency-free classic script that
    # lives under public/ (no Vite build step), so we render it directly.
    # Set a long max-age via cache headers since the SW protocol handles
    # its own update lifecycle through skipWaiting/clientsClaim.
    response.headers['Cache-Control'] = 'public, max-age=0, must-revalidate'
    response.headers['Service-Worker-Allowed'] = '/dispatch'
    render(file: Rails.root.join('public/assets/dispatch/sw.js'), layout: false, content_type: 'text/javascript')
  end

  def manifest
    name = Setting.get('organization').presence || Setting.get('product_name').presence || 'Dom-Servis'

    render(
      layout:       false,
      json:         {
        id:               '/dispatch/',
        short_name:       'Dom-Servis',
        name:             name,
        description:      'Dom-Servis dispatch board for masters and dispatchers.',
        orientation:      'any',
        background_color: '#0a1119',
        theme_color:      '#20242d',
        display:          'standalone',
        start_url:        '/dispatch/',
        scope:            '/dispatch/',
        icons:            [
          # Icons live in public/assets/dispatch/ and are referenced
          # relative to the manifest location (/dispatch/manifest.webmanifest).
          { src: '../assets/dispatch/icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: '../assets/dispatch/icon-192.png', sizes: '192x192', type: 'image/png', purpose: 'any' },
          { src: '../assets/dispatch/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      content_type: 'application/manifest+json'
    )
  end
end
