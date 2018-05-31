# frozen_string_literal: true

require 'active_job'

module WCC::Contentful
  class DelayedSyncJob < ActiveJob::Base
    include WCC::Contentful::ServiceAccessors

    self.queue_adapter = :async
    queue_as :default

    def self.mutex
      @mutex ||= Mutex.new
    end

    def perform(*args)
      sync_options = args.first || {}
      sync!(**sync_options)
    end

    ##
    # Calls the Contentful Sync API and updates the configured store with the returned
    # data.
    #
    # up_to_id: An ID that we know has changed and should come back from the sync.
    #           If we don't find this ID in the sync data, then drop a job to try
    #           the sync again after a few minutes.
    #
    def sync!(up_to_id: nil)
      return unless store.respond_to?(:index)

      self.class.mutex.synchronize do
        next_sync_token = store.find('sync:token')
        sync_resp = client.sync(sync_token: next_sync_token)

        id_found = up_to_id.nil?

        sync_resp.items.each do |item|
          id = item.dig('sys', 'id')
          id_found ||= id == up_to_id
          store.index(item)
        end
        store.set('sync:token', sync_resp.next_sync_token)

        puts "found? #{id_found}"
        sync_later!(up_to_id: up_to_id) unless id_found
        sync_resp.next_sync_token
      end
    end

    ##
    # Drops an ActiveJob job to invoke WCC::Contentful.sync! after a given amount
    # of time.
    def sync_later!(up_to_id: nil, wait: 10.minutes)
      WCC::Contentful::DelayedSyncJob.set(wait: wait)
        .perform_later(up_to_id)
    end
  end
end
