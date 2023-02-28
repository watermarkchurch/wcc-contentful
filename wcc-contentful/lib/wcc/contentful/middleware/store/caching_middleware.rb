# frozen_string_literal: true

module WCC::Contentful::Middleware::Store
  class CachingMiddleware
    include WCC::Contentful::Middleware::Store
    # include instrumentation, but not specifically store stack instrumentation
    include WCC::Contentful::Instrumentation

    attr_accessor :expires_in, :configuration

    def default_locale
      @default_locale ||= configuration&.default_locale&.to_s || 'en-US'
    end

    def initialize(cache = nil)
      @cache = cache || ActiveSupport::Cache::MemoryStore.new
      @expires_in = nil
    end

    def find(key, **options)
      event = 'fresh'
      found =
        @cache.fetch(key, expires_in: expires_in) do
          event = 'miss'
          # if it's not a contentful ID don't hit the API.
          # Store a nil object if we can't find the object on the CDN.
          (store.find(key, **options) || nil_obj(key)) if key =~ /^\w+$/
        end

      return unless found
      return if %w[Nil DeletedEntry DeletedAsset].include?(found.dig('sys', 'type'))

      # If what we found in the cache is for the wrong Locale, go hit the store directly.
      # Now that the one locale is in the cache, when we index next time we'll index the
      # all-locales version and we'll be fine.
      locale = options[:locale]&.to_s || default_locale
      if found.dig('sys', 'locale') != locale
        event = 'miss'
        return store.find(key, **options)
      end

      found
    ensure
      _instrument(event, key: key, options: options)
    end

    # TODO: https://github.com/watermarkchurch/wcc-contentful/issues/18
    #  figure out how to cache the results of a find_by query, ex:
    #  `find_by('slug' => '/about')`
    def find_by(content_type:, filter: nil, options: nil)
      options ||= {}
      if filter&.keys == ['sys.id'] && found = @cache.read(filter['sys.id'])
        # This is equivalent to a find, usually this is done by the resolver to
        # try to include deeper relationships.  Since we already have this object,
        # don't hit the API again.
        return if %w[Nil DeletedEntry DeletedAsset].include?(found.dig('sys', 'type'))
        return found if found.dig('sys', 'locale') == options[:locale]
      end

      store.find_by(content_type: content_type, filter: filter, options: options)
    end

    delegate :find_all, to: :store

    # #index is called whenever the sync API comes back with more data.
    def index(json)
      delegated_result = store.index(json) if store.index?
      caching_result = _index(json)
      # _index returns nil if we don't already have it cached - so use the store result.
      # store result is nil if it doesn't index, so use the caching result if we have it.
      # They ought to be the same thing if it's cached and the store also indexes.
      caching_result || delegated_result
    end

    def index?
      true
    end

    private

    LAZILY_CACHEABLE_TYPES = %w[
      Entry
      Asset
      DeletedEntry
      DeletedAsset
    ].freeze

    def _index(json)
      ensure_hash(json)
      id = json.dig('sys', 'id')
      type = json.dig('sys', 'type')
      prev = @cache.read(id)
      return if prev.nil? && LAZILY_CACHEABLE_TYPES.include?(type)

      if (prev_rev = prev&.dig('sys', 'revision')) && (next_rev = json.dig('sys', 'revision')) && (next_rev < prev_rev)
        return prev
      end

      # we also set DeletedEntry objects in the cache - no need to go hit the API when we know
      # this is a nil object
      @cache.write(id, json, expires_in: expires_in)

      case type
      when 'DeletedEntry', 'DeletedAsset'
        _instrument 'delete', id: id
        nil
      else
        _instrument 'set', id: id
        json
      end
    end

    def nil_obj(id)
      {
        'sys' => {
          'id' => id,
          'type' => 'Nil',
          'revision' => 1
        }
      }
    end

    def ensure_hash(val)
      raise ArgumentError, 'Value must be a Hash' unless val.is_a?(Hash)
    end
  end
end
