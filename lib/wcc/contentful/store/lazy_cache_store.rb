# frozen_string_literal: true

module WCC::Contentful::Store
  class LazyCacheStore
    attr_reader :cache

    delegate :find_by, to: :@store

    def initialize(client:, cache: nil)
      @store = CDNAdapter.new(client)
      @cache = cache || ActiveSupport::Cache::MemoryStore.new
    end

    def find(key)
      @cache.fetch(key) do
        @store.find(key)
      end
    end

    # `index` is called whenever the sync API comes back with more data.
    def index(key, value)
      # We only update stuff that's been used recently - i.e. it's in the cache.
      @cache.write(key, value) if @cache.exist?(key)
    end
  end
end
