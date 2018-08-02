# frozen_string_literal: true

module WCC::Contentful::Store
  class LazyCacheStore
    def initialize(client, cache: nil)
      @cdn = CDNAdapter.new(client)
      @cache = cache || ActiveSupport::Cache::MemoryStore.new
      @client = client
    end

    def find(key)
      found =
        @cache.fetch(key) do
          # if it's not a contentful ID don't hit the API.
          # Store a nil object if we can't find the object on the CDN.
          (@cdn.find(key) || nil_obj(key)) if key =~ /^\w+$/
        end

      case found.try(:dig, 'sys', 'type')
      when 'Nil', 'DeletedEntry', 'DeletedAsset'
        nil
      else
        found
      end
    end

    # TODO: https://zube.io/watermarkchurch/development/c/2265
    #  figure out how to cache the results of a find_by query, ex:
    #  `find_by('slug' => '/about')`
    def find_by(content_type:, filter: nil, options: nil)
      q = find_all(content_type: content_type, options: options)
      q = q.apply(filter) if filter
      q.first
    end

    def find_all(content_type:, options: nil)
      Query.new(
        store: self,
        client: @client,
        relation: { content_type: content_type },
        cache: @cache,
        options: options
      )
    end

    # #index is called whenever the sync API comes back with more data.
    def index(json)
      id = json.dig('sys', 'id')
      return unless prev = @cache.read(id)

      if (prev_rev = prev&.dig('sys', 'revision')) && (next_rev = json.dig('sys', 'revision'))
        return prev if next_rev < prev_rev
      end

      # we also set deletes in the cache - no need to go hit the API when we know
      # this is a nil object
      @cache.write(id, json)

      case json.dig('sys', 'type')
      when 'DeletedEntry', 'DeletedAsset'
        nil
      else
        json
      end
    end

    def set(key, value)
      old = @cache.read(key)
      @cache.write(key, value)
      old
    end

    def delete(key)
      old = @cache.read(key)
      @cache.delete(key)
      old
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

    class Query < CDNAdapter::Query
      def initialize(cache:, **extra)
        super(cache: cache, **extra)
        @cache = cache
      end

      protected

      def response
        # rubocop:disable Naming/MemoizedInstanceVariableName
        # I don't want to conflict with the memoized @response in super
        @response_wrapper ||= ResponseWrapper.new(super, @cache)
        # rubocop:enable Naming/MemoizedInstanceVariableName
      end

      ResponseWrapper =
        Struct.new(:response, :cache) do
          delegate :count, to: :response

          def items
            @items ||=
              response.items.map do |item|
                id = item.dig('sys', 'id')
                prev = cache.read(id)
                unless (prev_rev = prev&.dig('sys', 'revision')) &&
                    (next_rev = item.dig('sys', 'revision')) &&
                    next_rev < prev_rev

                  cache.write(id, item)
                end

                item
              end
          end

          def includes
            @includes ||= IncludesWrapper.new(response, cache)
          end
        end

      IncludesWrapper =
        Struct.new(:response, :cache) do
          def [](id)
            item = response.includes[id]
            prev = cache.read(id)
            unless (prev_rev = prev&.dig('sys', 'revision')) &&
                (next_rev = item.dig('sys', 'revision')) &&
                next_rev < prev_rev

              cache.write(id, item)
            end

            item
          end
        end
    end
  end
end
