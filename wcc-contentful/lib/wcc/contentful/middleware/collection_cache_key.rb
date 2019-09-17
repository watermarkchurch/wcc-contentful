# frozen_string_literal: true

require_relative './store'

class WCC::Contentful::Middleware::CollectionCacheKey
  include WCC::Contentful::Middleware::Store

  def self.call(store, content_delivery_params, _config)
    # This does not apply in preview mode
    return if content_delivery_params&.find { |h| h.is_a?(Hash) && h[:preview] }

    instance = new(ActiveSupport::Cache.lookup_store(*options))
    instance.store = store
    instance
  end

  attr_accessor :store
  delegate :index, :set, :delete, :find, to: :store

  attr_reader :cache

  def initialize(cache = nil)
    @cache = cache
  end

  # We need to index records if we're going to use an underlying cache store
  def index?
    @cache.present? || store.index?
  end

  def find_by(content_type:, filter: nil, options: nil)
    q = find_all(content_type: content_type, options: { limit: 1 }.merge!(options || {}))
    q = q.apply(filter) if filter
    return q.first unless @cache

    @cache.fetch(q.cache_key) { q.first }
  end

  def find_all(content_type:, options: nil)
    CacheableQuery.new(
      query: store.find_all(content_type: content_type, options: options),
      middleware: self,
      relation: {},
      options: { cacheable: true }.merge!(options || {})
    )
  end

  def last_modified_entry(content_type, &block)
    return @cache.fetch("CollectionCacheKey:#{content_type}", &block) if @cache

    yield
  end

  class CacheableQuery < WCC::Contentful::Store::Base::DelegatingQuery
    def initialize(middleware:, relation:, **extra)
      super(middleware: middleware, relation: relation, **extra)
      @middleware = middleware
      @relation = relation || {}
    end

    def cache_key
      raise NotCacheableError, self unless @options[:cacheable]
      return unless lm = last_modified_entry

      params = [
        lm.dig('sys', 'id'),
        lm.dig('sys', 'updatedAt'),
        @relation.to_param
      ]
      Digest::SHA1.hexdigest(params.join(':'))
    end

    def last_modified
      raise NotCacheableError, self unless @options[:cacheable]

      last_modified_entry&.dig('sys', 'updatedAt')
    end

    def apply_operator(operator, field, expected, context = nil)
      new_query = @wrapped_query.apply_operator(operator, field, expected, context)

      self.class.new(
        **@extra,
        query: new_query,
        relation: @relation.merge({ field => { operator => expected } }),
        options: @options
      )
    end

    def nested_conditions(field, conditions, context)
      new_query = @wrapped_query.nested_conditions(field, conditions, context)

      self.class.new(
        **@extra,
        query: new_query,
        relation: @relation.merge({ field => conditions }),
        options: @options
      )
    end

    private

    def last_modified_entry
      ct = @wrapped_query.content_type

      @middleware.last_modified_entry(ct) do
        @middleware.store.find_by(content_type: ct, options: {
          order: '-sys.updatedAt'
        })
      end
    end
  end

  class NotCacheableError < StandardError
    attr_reader :query

    def initialize(query, message: nil)
      super(message || "query #{query} is not cacheable")
      @query = query
    end
  end
end
