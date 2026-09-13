# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Rake tasks for managing the Dom-Servis dispatch board Web Push setup.
#
#   rake dom_servis:webpush:generate_keys
#     Generates a fresh VAPID key pair and stores it in the Dom-Servis
#     Web Push settings. Run once during initial setup.
#
#   rake dom_servis:webpush:status
#     Prints the current Web Push configuration status.
namespace :dom_servis do
  namespace :webpush do
    desc 'Generate and store a VAPID key pair for the Dom-Servis dispatch board.'
    task generate_keys: :environment do
      require 'web-push'

      vapid_key = WebPush.generate_key

      Setting.set('dom_servis_webpush_vapid_public_key', vapid_key.public_key)
      Setting.set('dom_servis_webpush_vapid_private_key', vapid_key.private_key)

      puts 'Dom-Servis Web Push VAPID keys generated and stored.'
      puts "Public key:  #{vapid_key.public_key}"
      puts 'Private key: [hidden]'
      puts 'Subject:     ' + (Setting.get('dom_servis_webpush_subject').presence || '(default mailto:)')
    rescue LoadError
      abort 'The web-push gem is not installed. Run `bundle install` first.'
    end

    desc 'Show the current Dom-Servis Web Push configuration.'
    task status: :environment do
      public_key  = Setting.get('dom_servis_webpush_vapid_public_key').presence
      private_key = Setting.get('dom_servis_webpush_vapid_private_key').presence
      subject     = Setting.get('dom_servis_webpush_subject').presence

      puts 'Dom-Servis Web Push status:'
      puts "  VAPID public key:  #{public_key ? 'configured' : 'MISSING'}"
      puts "  VAPID private key: #{private_key ? 'configured' : 'MISSING'}"
      puts "  Subject:           #{subject || '(not set)'}"

      active_subs = DomServis::PushSubscription.active.count
      puts "  Active subscriptions: #{active_subs}"
    end
  end
end
