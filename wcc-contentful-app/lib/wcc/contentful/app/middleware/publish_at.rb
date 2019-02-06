# frozen_string_literal: true

module WCC::Contentful::App::Middleware
  class PublishAt
    include WCC::Contentful::Middleware::Store

    def select(entry)
      publish_at = entry.dig('fields', 'publishAt', 'en-US')
      unpublish_at = entry.dig('fields', 'unpublishAt', 'en-US')

      after(publish_at) && before(unpublish_at)
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
  end
end
