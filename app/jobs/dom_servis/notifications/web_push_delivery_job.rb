# Copyright (C) 2012-2026 Zammad Foundation, https://zammad-foundation.org/

# Delivers a single Web Push message to one subscription asynchronously.
#
# Push delivery is offloaded to the job queue so the dispatch request
# cycle is never blocked on slow or timing-out push-service HTTP calls.
# Each subscription gets its own job so one failing endpoint cannot
# block delivery to the rest.
module DomServis
  module Notifications
    class WebPushDeliveryJob < ApplicationJob
      queue_as :default

      # Push service failures are usually transient (device offline) or
      # permanent (subscription gone). Either way we do not want to retry
      # aggressively and hammer the push service, so we discard fast.
      discard_on ActiveJob::DeserializationError

      def perform(subscription, payload)
        return if subscription.blank?

        DomServis::Notifications::WebPushSender
          .new(subscription: subscription, payload: payload)
          .deliver
      end
    end
  end
end
