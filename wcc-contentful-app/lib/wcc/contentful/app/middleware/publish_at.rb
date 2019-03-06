# frozen_string_literal: true

module WCC::Contentful::App::Middleware
  class PublishAt
    include WCC::Contentful::Middleware::Store

    def self.call(store, content_delivery_params, config)
      # This does not apply in preview mode
      return if content_delivery_params&.find { |array| array[:preview] == true }

      super
    end

    def select?(entry)
      publish_at = entry.dig('fields', 'publishAt', 'en-US')
      unpublish_at = entry.dig('fields', 'unpublishAt', 'en-US')

      after(publish_at) && before(unpublish_at)
    end

    def index(entry)
      maybe_drop_job(entry) if entry.dig('sys', 'type') == 'Entry'

      super
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
      def maybe_drop_job(entry)
        publish_at = entry.dig('fields', 'publishAt', 'en-US')
        unpublish_at = entry.dig('fields', 'unpublishAt', 'en-US')

        drop_job_at(publish_at, entry) if publish_at.present? && before(publish_at)
        drop_job_at(unpublish_at, entry) if unpublish_at.present? && before(unpublish_at)
      end

      def drop_job_at(timestamp, entry)
        ts = Time.zone.parse(timestamp)
        Job.set(wait_until: ts + 1.second).perform_later(entry)
      end

      class Job < ActiveJob::Base
        include Wisper::Publisher

        def self.cache
          @cache ||= Rails.cache
        end
        attr_writer :cache

        def initialize(*arguments)
          super

          subscribe(WCC::Contentful::Events.instance, with: :rebroadcast)
        end

        def perform(entry)
          emit_event(entry)
        end

        def emit_event(entry)
          event = WCC::Contentful::Event.from_raw(entry, source: self)
          type = entry.dig('sys', 'type')
          raise ArgumentError, "Unknown event type #{event}" unless type.present?

          broadcast(type, event)
        end
      end
    else
      def maybe_drop_job(entry)
      end
    end
  end
end
