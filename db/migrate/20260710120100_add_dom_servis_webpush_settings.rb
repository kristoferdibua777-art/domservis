# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Seeds the VAPID key pair and subject used by the Dom-Servis Web Push
# sender to sign push messages. The keys are generated once via the
# `rake dom_servis:webpush:generate_keys` task (or entered manually in
# the admin UI) and stored as plaintext strings.
class AddDomServisWebpushSettings < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Setting.create_if_not_exists(
      title:       'Dom-Servis Web Push VAPID public key',
      name:        'dom_servis_webpush_vapid_public_key',
      area:        'DomServis::WebPush',
      description: 'Base64url-encoded VAPID public key used by the dispatch board to subscribe browsers for Web Push.',
      options:     {},
      state:       '',
      preferences: {
        prio:       3650,
        permission: ['dom_servis.admin'],
      },
      frontend:    true
    )

    Setting.create_if_not_exists(
      title:       'Dom-Servis Web Push VAPID private key',
      name:        'dom_servis_webpush_vapid_private_key',
      area:        'DomServis::WebPush',
      description: 'Base64url-encoded VAPID private key used to sign outgoing dispatch Web Push messages. Keep secret.',
      options:     {},
      state:       '',
      preferences: {
        prio:       3651,
        permission: ['dom_servis.admin'],
      },
      frontend:    false
    )

    Setting.create_if_not_exists(
      title:       'Dom-Servis Web Push subject',
      name:        'dom_servis_webpush_subject',
      area:        'DomServis::WebPush',
      description: 'Contact URI included in VAPID JWT claims (mailto: or https: URL).',
      options:     {},
      state:       'mailto:admin@example.com',
      preferences: {
        prio:       3652,
        permission: ['dom_servis.admin'],
      },
      frontend:    false
    )
  end
end
