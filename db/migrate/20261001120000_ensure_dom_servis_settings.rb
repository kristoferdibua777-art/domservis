# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# The dispatch policy and Web Push settings were created only by migrations
# that skip a system without system_init_done (20260318212000,
# 20260710120100). On a fresh install the migrations run before the seeds,
# so these settings never existed there: the admin could not save the
# dispatch policy and the VAPID keys could not be stored. The seeds create
# them now; this migration adds whichever are missing on systems installed
# before that. Existing settings are left as they are.
class EnsureDomServisSettings < ActiveRecord::Migration[7.2]
  def up
    return if !Setting.exists?(name: 'system_init_done')

    Setting.create_if_not_exists(
      title:       'Dom-Servis dispatch policy',
      name:        'dom_servis_dispatch_policy',
      area:        'DomServis::Dispatch',
      description: 'Stores the dispatch board role matrices for actions, statuses and fields.',
      options:     {},
      state:       {},
      preferences: {
        prio:       3600,
        permission: ['dom_servis.admin'],
      },
      frontend:    false
    )

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
