# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Stores per-user Web Push subscriptions for the Dom-Servis dispatch board.
#
# Each browser that grants push permission sends back a PushSubscription
# containing the push service endpoint, an ECDH P-256 public key (p256dh)
# and an auth secret. We persist one row per subscription so the backend
# can fan out push notifications to every device a master has registered.
class CreateDomServisPushSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :dom_servis_push_subscriptions do |t|
      t.references :user, foreign_key: true, null: false

      # Full push service endpoint URL (e.g. https://fcm.googleapis.com/...).
      t.string :endpoint, null: false

      # Client ECDH P-256 public key, base64url-encoded.
      t.string :p256dh_key, null: false

      # Client auth secret, base64url-encoded.
      t.string :auth_key, null: false

      # Optional subscription expiration timestamp (RFC 8030).
      t.datetime :expiration_time

      # User agent string of the subscribing browser, for diagnostics.
      t.text :user_agent

      # Subscriptions are deactivated (not destroyed) when the push
      # service reports them as expired/invalid, so we keep history.
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :dom_servis_push_subscriptions, :endpoint, unique: true
    add_index :dom_servis_push_subscriptions, %i[user_id active], name: 'idx_dom_servis_push_subs_on_user_and_active'
  end
end
