# frozen_string_literal: true

require 'active_job'
require 'wcc/contentful/event_emitter'

module WCC::Contentful
  # The SyncEngine is used to keep the currently configured store up to date
  # using the Sync API.  It is available on the WCC::Contentful::Services instance,
  # and the application is responsible to periodically call #next in order to hit
  # the sync API and update the store.
  #
  # If you have mounted the WCC::Contentful::Engine, then
  # the WCC::Contentful::WebhookController will call #next automatically anytime
  # a webhook is received.
  class SyncEngine
    include WCC::Contentful::EventEmitter

    def state
      (@state&.dup || {}).freeze
    end

    attr_reader :store
    attr_reader :client

    def should_sync?
      store&.respond_to?(:index) || has_listeners?
    end

    def initialize(state: nil, store: nil, client: nil, key: nil)
      @state_key = key || "sync:#{object_id}"
      @client = client || WCC::Contentful::Services.instance.client
      @mutex = Mutex.new

      if store
        @fetch_method = FETCH_METHODS.find { |m| store.respond_to?(m) }
        @write_method = WRITE_METHODS.find { |m| store.respond_to?(m) }
        unless @fetch_method && @write_method
          raise ArgumentError, ":store param must implement one of #{FETCH_METHODS}" \
            " AND one of #{WRITE_METHODS}"
        end

        @store = store
        @state = fetch
      end
      if state
        @state = { 'token' => state } if state.is_a? String
        @state = state if state.is_a? Hash
        raise ArgumentError, ':state param must be a String or Hash' unless @state
      end
      raise ArgumentError, 'either :state or :store must be provided' unless @state || @store
    end

    # Gets the next increment of data from the Sync API.
    # If the configured store responds to `:index`, that will be called with each
    # item in the Sync response to update the store.
    # If a block is passed, that block will be evaluated with each item in the
    # response.
    # @param [String] up_to_id An ID to look for in the response.  The method returns
    #   true if the ID was found or no up_to_id was given, false if the ID did not come back.
    # @return [Array] A `[Boolean, Integer]` tuple where the first value is whether the ID was found,
    #   and the second value is the number of items returned.
    def next(up_to_id: nil)
      id_found = up_to_id.nil?
      count = 0

      @mutex.synchronize do
        @state ||= fetch || {}
        next_sync_token = @state['token']

        sync_resp = client.sync(sync_token: next_sync_token)
        sync_resp.items.each do |item|
          id = item.dig('sys', 'id')
          id_found ||= id == up_to_id

          yield(item) if block_given?
          store.index(item) if store&.respond_to?(:index)
          emit_item(item)

          count += 1
        end

        @state['token'] = sync_resp.next_sync_token
        write
      end

      [id_found, count]
    end

    FETCH_METHODS = %i[fetch find].freeze
    WRITE_METHODS = %i[write set].freeze

    private

    def emit_item(item)
      event = item.dig('sys', 'type')
      emit(event, item)
    end

    def fetch
      store&.public_send(@fetch_method, @state_key)
    end

    def write
      store&.public_send(@write_method, @state_key, @state)
    end

    # Define the job only if rails is loaded
    if defined?(ActiveJob::Base)
      # This job uses the Contentful Sync API to update the configured store with
      # the latest data from Contentful.
      class Job < ActiveJob::Base
        include WCC::Contentful::ServiceAccessors

        self.queue_adapter = :async
        queue_as :default

        def perform(event = nil)
          up_to_id = nil
          up_to_id = event[:up_to_id] || event.dig('sys', 'id') if event
          sync!(up_to_id: up_to_id)
        end

        # Calls the Contentful Sync API and updates the configured store with the returned
        # data.
        #
        # @param [String] up_to_id
        #  An ID that we know has changed and should come back from the sync.
        #  If we don't find this ID in the sync data, then drop a job to try
        #  the sync again after a few minutes.
        #
        def sync!(up_to_id: nil)
          id_found, count = sync_engine.next(up_to_id: up_to_id)

          next_sync_token = sync_engine.state['token']

          logger.info "Synced #{count} entries.  Next sync token:\n  #{next_sync_token}"
          logger.info "Should enqueue again? [#{!id_found}]"
          # Passing nil to only enqueue the job 1 more time
          sync_later!(up_to_id: nil) unless id_found
          next_sync_token
        end

        # Drops an ActiveJob job to invoke WCC::Contentful.sync! after a given amount
        # of time.
        def sync_later!(up_to_id: nil, wait: 10.minutes)
          self.class.set(wait: wait)
            .perform_later(up_to_id: up_to_id)
        end
      end
    end
  end
end