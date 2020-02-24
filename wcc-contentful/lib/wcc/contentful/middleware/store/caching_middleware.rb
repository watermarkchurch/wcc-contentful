# frozen_string_literal: true

module WCC::Contentful::Store
  class CachingMiddleware
    include WCC::Contentful::Middleware::Store

    def initialize(cache = nil)
      @cache = cache || ActiveSupport::Cache::MemoryStore.new
      @client = client
    end

    def find(key, **options)
      event = 'fresh'
      found =
        @cache.fetch(key) do
          event = 'miss'
          # if it's not a contentful ID don't hit the API.
          # Store a nil object if we can't find the object on the CDN.
          (store.find(key, options) || nil_obj(key)) if key =~ /^\w+$/
        end
      _instrument(event + '.lazycachestore', key: key, options: options)

      case found.try(:dig, 'sys', 'type')
      when 'Nil', 'DeletedEntry', 'DeletedAsset'
        nil
      else
        found
      end
    end

    # TODO: https://github.com/watermarkchurch/wcc-contentful/issues/18
    #  figure out how to cache the results of a find_by query, ex:
    #  `find_by('slug' => '/about')`
    def find_by(content_type:, filter: nil, options: nil)
      if filter.keys == ['sys.id']
        # Direct ID lookup, like what we do in `WCC::Contentful::ModelMethods.resolve`
        # We can return just this item.  Stores are not required to implement :include option.
        if found = @cache.read(filter['sys.id'])
          return found
        end
      end

      store.find_by(content_type: content_type, filter: filter, options: options)
    end

    delegate :find_all, to: :store

    # #index is called whenever the sync API comes back with more data.
    def index(json)
      id = json.dig('sys', 'id')
      return unless prev = @cache.read(id)

      if (prev_rev = prev&.dig('sys', 'revision')) && (next_rev = json.dig('sys', 'revision'))
        return prev if next_rev < prev_rev
      end

      # we also set deletes in the cache - no need to go hit the API when we know
      # this is a nil object
      ensure_hash json
      @cache.write(id, json)

      case json.dig('sys', 'type')
      when 'DeletedEntry', 'DeletedAsset'
        _instrument 'delete', id: id
        nil
      else
        _instrument 'set', id: id
        json
      end
    end

    def index?
      true
    end

    def set(key, value)
      ensure_hash value
      old = @cache.read(key)
      @cache.write(key, value)
      old
    end

    def delete(key)
      old = @cache.read(key)
      @cache.delete(key)
      old
    end

    private

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
