# frozen_string_literal: true

require 'wcc/contentful/event'
require 'wisper'

begin
  gem 'activejob'
  require 'active_job'
rescue Gem::LoadError # rubocop:disable Lint/HandleExceptions
  # suppress
end

module WCC::Contentful
  # The SyncEngine is used to keep the currently configured store up to date
  # using the Sync API.  It is available on the WCC::Contentful::Services instance,
  # and the application is responsible to periodically call #next in order to hit
  # the sync API and update the store.
  #
  # If you have mounted the WCC::Contentful::Engine, AND the configured store is
  # one that can be synced (i.e. it responds to `:index`), then
  # the WCC::Contentful::WebhookController will call #next automatically anytime
  # a webhook is received.  Otherwise you should hook up to the Webhook events
  # and call the sync engine via your initializer:
  #     WCC::Contentful::Events.subscribe(proc do |event|
  #       WCC::Contentful::Services.instance.sync_engine.next(up_to: event.dig('sys', 'id'))
  #     end, with: :call)
  class SyncEngine
    include ::Wisper::Publisher

    def state
      (@state&.dup || token_wrapper_factory(nil)).freeze
    end

    attr_reader :store, :client, :options

    def should_sync?
      store&.index?
    end

    def initialize(client: nil, store: nil, state: nil, **options)
      @options = {
        key: "sync:#{object_id}"
      }.merge!(options).freeze

      @state_key = @options[:key] || "sync:#{object_id}"
      @client = client || WCC::Contentful::Services.instance.client
      @mutex = Mutex.new

      if store
        unless %i[index index? find].all? { |m| store.respond_to?(m) }
          raise ArgumentError, ':store param must implement the Store interface'
        end

        @store = store
      end
      if state
        @state = token_wrapper_factory(state)
        raise ArgumentError, ':state param must be a String or Hash' unless @state.is_a? Hash
        raise ArgumentError, ':state param must be of sys.type = "token"' unless @state.dig('sys', 'type') == 'token'
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
      all_events = []

      @mutex.synchronize do
        @state ||= read_state || token_wrapper_factory(nil)
        sync_token = @state['token']

        next_sync_token =
          client.sync(sync_token: sync_token) do |item|
            id = item.dig('sys', 'id')
            id_found ||= id == up_to_id

            store.index(item) if store&.index?
            event = WCC::Contentful::Event.from_raw(item, source: self)
            yield(event) if block_given?
            emit_event(event)

            # Only keep the "sys" not the content in case we have a large space
            all_events << WCC::Contentful::Event.from_raw(item.slice('sys'), source: self)
          end

        @state = @state.merge('token' => next_sync_token)
        write_state
      end

      emit_sync_complete(all_events)

      [id_found, all_events.length]
    end

    def emit_event(event)
      type = event.dig('sys', 'type')
      raise ArgumentError, "Unknown event type #{event}" unless type.present?

      broadcast(type, event)
    end

    def emit_sync_complete(events)
      event = WCC::Contentful::Event::SyncComplete.new(events, source: self)
      broadcast('SyncComplete', event)
    end

    private

    def read_state
      return unless found = store&.find(@state_key)

      # backwards compat - migrate existing state
      token_wrapper_factory(found)
    end

    def write_state
      store.index(@state) if store&.index?
    end

    def token_wrapper_factory(state)
      state = { 'token' => state } unless state.is_a? Hash

      state.merge!('sys' => { 'id' => @state_key, 'type' => 'token' }) unless state['sys']
      state
    end

    # Define the job only if rails is loaded
    if defined?(ActiveJob)
      # This job uses the Contentful Sync API to update the configured store with
      # the latest data from Contentful.
      class Job < ActiveJob::Base
        # This should always be "async", because the configured store could be an in-memory store.
        self.queue_adapter = :async
        queue_as :default

        def configuration
          @configuration ||= WCC::Contentful.configuration
        end

        def services
          @services ||= WCC::Contentful::Services.instance
        end

        def perform(event = nil)
          return unless services.sync_engine&.should_sync?

          up_to_id = nil
          retry_count = 0
          if event
            up_to_id = event[:up_to_id] || event.dig('sys', 'id')
            retry_count = event[:retry_count] if event[:retry_count]
          end
          sync!(up_to_id: up_to_id, retry_count: retry_count)
        end

        # Calls the Contentful Sync API and updates the configured store with the returned
        # data.
        #
        # @param [String] up_to_id
        #  An ID that we know has changed and should come back from the sync.
        #  If we don't find this ID in the sync data, then drop a job to try
        #  the sync again after a few minutes.
        #
        def sync!(up_to_id: nil, retry_count: 0)
          id_found, count = services.sync_engine.next(up_to_id: up_to_id)

          next_sync_token = services.sync_engine.state['token']

          logger.info "Synced #{count} entries.  Next sync token:\n  #{next_sync_token}"
          unless id_found
            if retry_count >= configuration.sync_retry_limit
              logger.error "Unable to find item with id '#{up_to_id}' on the Sync API.  " \
                           "Abandoning after #{retry_count} retries."
            else
              wait = (2**retry_count) * configuration.sync_retry_wait.seconds
              logger.info "Unable to find item with id '#{up_to_id}' on the Sync API.  " \
                          "Retrying after #{wait.inspect} " \
                          "(#{configuration.sync_retry_limit - retry_count} retries remaining)"

              self.class.set(wait: wait)
                .perform_later(up_to_id: up_to_id, retry_count: retry_count + 1)
            end
          end
          next_sync_token
        end

        # Enqueues an ActiveJob job to invoke WCC::Contentful.sync! after a given amount
        # of time.
        def sync_later!(up_to_id: nil, wait: 10.seconds)
          self.class.set(wait: wait)
            .perform_later(up_to_id: up_to_id)
        end
      end
    end
  end
end
