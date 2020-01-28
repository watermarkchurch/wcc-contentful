# frozen_string_literal: true

# A Store middleware wraps the Store interface to perform any desired transformations
# on the Contentful entries coming back from the store.  A Store middleware must
# implement the Store interface as well as a `store=` attribute writer, which is
# used to inject the next store or middleware in the chain.
#
# The Store interface can be seen on the WCC::Contentful::Store::Base class.  It
# consists of the `#find, #find_by, #find_all, #set, #delete,` and `#index` methods.
#
# Including this concern will define those methods to pass through to the next store.
# Any of those methods can be overridden on the implementing middleware.
# It will also expose two overridable methods, `#select?` and `#transform`.  These
# methods are applied when reading values out of the store, and can be used to
# apply a filter or transformation to each entry in the store.
module WCC::Contentful::Middleware::Store
  extend ActiveSupport::Concern

  attr_accessor :store

  delegate :index, :index?, :set, :delete, to: :store

  class_methods do
    def call(store, _content_delivery_params, _config)
      instance = new
      instance.store = store
      instance
    end
  end

  def find(id, **options)
    found = store.find(id, **options)
    return transform(found) if found && select?(found)
  end

  def find_by(options: nil, **args)
    result = store.find_by(**args.merge(options: options))
    return unless result && select?(result)

    result = resolve_includes(result, options[:include]) if options && options[:include]
    transform(result)
  end

  def find_all(options: nil, **args)
    Query.new(
      store.find_all(**args.merge(options: options)),
      self,
      options
    )
  end

  def resolve_includes(entry, depth)
    return entry unless entry && depth && depth > 0

    WCC::Contentful::LinkVisitor.new(entry, :Link, depth: depth).map! do |val|
      resolve_link(val)
    end
  end

  def resolve_link(val)
    return val unless resolved_link?(val)

    if select?(val)
      transform(val)
    else
      # Pretend it's an unresolved link -
      # matches the behavior of a store when the link cannot be retrieved
      WCC::Contentful::Link.new(val.dig('sys', 'id'), val.dig('sys', 'type')).to_h
    end
  end

  def resolved_link?(value)
    value.is_a?(Hash) && value.dig('sys', 'type') == 'Entry'
  end

  # The default version of `#select?` returns true for all entries.
  # Override this with your own implementation.
  def select?(_entry)
    true
  end

  # The default version of `#transform` just returns the entry.
  # Override this with your own implementation.
  def transform(entry)
    entry
  end

  class Query < WCC::Contentful::Store::Query
    attr_reader :wrapped_query, :middleware, :options

    delegate :apply, :apply_operator, to: :wrapped_query

    def to_enum
      result =
        wrapped_query.to_enum
          .select { |x| middleware.select?(x) }

      if options && options[:include]
        result = result.map { |x| middleware.resolve_includes(x, options[:include]) }
      end

      result.map { |x| middleware.transform(x) }
    end

    def initialize(wrapped_query, middleware, options)
      @wrapped_query = wrapped_query
      @middleware = middleware
      @options = options
    end
  end
end
