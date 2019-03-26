# frozen_string_literal: true

module WCC::Contentful::App::Middleware
  class PublishAt
    include WCC::Contentful::Middleware::Store

    class << self
      def job_entry_storage
        @job_entry_storage ||= Redis::Store.new
      end
      attr_writer :job_entry_storage

      def entry_key(entry)
        [name, entry.dig('sys', 'type'), entry.dig('sys', 'id')].join('.')
      end

      def update_storage(entry, force = false)
        key = entry_key(entry)
        return job_entry_storage.set(key, entry) if force

        return unless old_entry = job_entry_storage.get(key)
        return unless old_revision = old_entry.dig('sys', 'revision')
        return unless old_revision < entry.dig('sys', 'revision')

        job_entry_storage.set(key, entry)
      end

      def latest_entry_version?(entry)
        # If the entry isn't in the job storage, then something's changed.
        return false unless from_storage = job_entry_storage.get(entry_key(entry))

        entry.dig('sys', 'revision') >= from_storage.dig('sys', 'revision')
      end
    end

    def self.call(store, content_delivery_params, config)
      # This does not apply in preview mode
      return if content_delivery_params&.find { |h| h.is_a?(Hash) && (h[:preview] == true) }

      super
    end

    def select?(entry)
      publish_at = entry.dig('fields', 'publishAt', 'en-US')
      unpublish_at = entry.dig('fields', 'unpublishAt', 'en-US')

      after(publish_at) && before(unpublish_at)
    end

    def index(entry)
      maybe_enqueue_job(entry) if entry.dig('sys', 'type') == 'Entry'

      self.class.update_storage(entry)

      store.index(entry) if store.index?
    end

    private

    def after(time)
      return true unless time

      Time.zone.now >= Time.zone.parse(time)
    end

    def before(time)
      return true unless time

      Time.zone.now <= Time.zone.parse(time)
    end

    if defined?(ActiveJob::Base)
      def maybe_enqueue_job(entry)
        publish_at = entry.dig('fields', 'publishAt', 'en-US')
        unpublish_at = entry.dig('fields', 'unpublishAt', 'en-US')

        enqueue_job_at(publish_at, entry) if publish_at.present? && before(publish_at)
        enqueue_job_at(unpublish_at, entry) if unpublish_at.present? && before(unpublish_at)
      end

      def enqueue_job_at(timestamp, entry)
        ts = Time.zone.parse(timestamp)

        self.class.update_storage(entry, true)
        Job.set(wait_until: ts + 1.second).perform_later(entry)
      end

      class Job < ActiveJob::Base
        include Wisper::Publisher

        self.queue_adapter = :async

        def self.cache
          @cache ||= Rails.cache
        end
        attr_writer :cache

        def initialize(*arguments)
          super

          subscribe(WCC::Contentful::Events.instance, with: :rebroadcast)
        end

        def perform(entry)
          return unless WCC::Contentful::App::Middleware::PublishAt.latest_entry_version?(entry)

          publish_at = entry.dig('fields', 'publishAt', 'en-US')
          unpublish_at = entry.dig('fields', 'unpublishAt', 'en-US')
          latest_event =
            [publish_at, unpublish_at]
              .select { |x| x.present? && Time.zone.now >= Time.zone.parse(x) }
              .max

          if latest_event == publish_at
            emit_entry(entry)
          else
            emit_deleted_entry(entry)
          end
        end

        def emit_entry(entry)
          emit_event(entry)
        end

        def emit_deleted_entry(entry)
          emit_event({
            'sys' => entry['sys'].merge({ 'type' => 'DeletedEntry' })
          })
        end

        def emit_event(entry)
          event = WCC::Contentful::Event.from_raw(entry, source: self)
          type = entry.dig('sys', 'type')
          raise ArgumentError, "Unknown event type #{event}" unless type.present?

          broadcast(type, event)
        end
      end
    else
      def maybe_enqueue_job(entry)
      end
    end
  end
end
