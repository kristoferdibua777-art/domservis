// Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

// Service worker for the Dom-Servis dispatch board PWA.
//
// This is a dependency-free classic service worker (no Vite build step):
// the dispatch board already ships its assets through the legacy Sprockets
// bundle, so there is nothing to precache here. The SW exists to receive
// Web Push events and surface system notifications to masters.
//
// Served at /dispatch/sw.js (see DispatchBoardController#service_worker,
// which renders this file from public/assets/dispatch/sw.js).
(function () {
  'use strict';

  var DEFAULT_ICON = '/assets/dispatch/icon-192.png';
  var DEFAULT_URL = '/dispatch/';

  // Activate new versions immediately so push events keep working
  // without waiting for every client tab to close.
  self.addEventListener('install', function () {
    self.skipWaiting();
  });

  self.addEventListener('message', function (event) {
    if (event.data && event.data.type === 'SKIP_WAITING') {
      self.skipWaiting();
    }
  });

  self.addEventListener('activate', function (event) {
    event.waitUntil(self.clients.claim());
  });

  self.addEventListener('push', function (event) {
    var payload = {};

    try {
      payload = event.data ? event.data.json() : {};
    } catch (e) {
      var raw = event.data ? event.data.text() : '';
      if (raw) payload.body = raw;
    }

    var title = payload.title || 'Дом-Сервис';
    var options = {
      body: payload.body || '',
      icon: DEFAULT_ICON,
      // No `badge`: Android renders the badge as a monochrome mask, so a
      // full-colour square icon shows up as a blank white square in the
      // status bar. Without it Chrome falls back to its own small icon.
      data: {
        url: payload.url || DEFAULT_URL,
        jobId: payload.jobId || null,
      },
      tag: payload.tag || 'dom-servis-dispatch',
      renotify: true,
      requireInteraction: false,
      vibrate: [200, 100, 200],
    };

    // Only forward actions when the platform supports them
    // (iOS Safari has limited support for notification actions).
    if (payload.actions && payload.actions.length > 0) {
      options.actions = payload.actions;
    }

    event.waitUntil(self.registration.showNotification(title, options));
  });

  self.addEventListener('notificationclick', function (event) {
    var notification = event.notification;
    var targetUrl = (notification.data && notification.data.url) || DEFAULT_URL;

    notification.close();

    event.waitUntil(
      (function () {
        return self.clients
          .matchAll({ type: 'window', includeUncontrolled: true })
          .then(function (allClients) {
            for (var i = 0; i < allClients.length; i++) {
              var client = allClients[i];
              if (client.url && client.url.indexOf('/dispatch/') !== -1) {
                // Focus the open board; navigate it only when the push
                // points somewhere other than the board itself.
                var focused = 'focus' in client ? client.focus() : Promise.resolve(client);
                if (targetUrl !== DEFAULT_URL && 'navigate' in client) {
                  return focused.then(function (c) { return (c || client).navigate(targetUrl); });
                }
                return focused;
              }
            }
            if (self.clients.openWindow) {
              return self.clients.openWindow(targetUrl);
            }
            return Promise.resolve();
          });
      })()
    );
  });
})();
