# frozen_string_literal: true

require_relative '../middleware'

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
  include WCC::Contentful::Store::Interface

  attr_accessor :store

  delegate :index, :index?, to: :store

  class_methods do
    def call(store, *content_delivery_params, **_)
      instance = new(*content_delivery_params)
      instance.store = store
      instance
    end
  end

  def find(id, **options)
    found = store.find(id, **options)
    return transform(found) if found && (!has_select? || select?(found))
  end

  def find_by(options: nil, **args)
    result = store.find_by(**args.merge(options: options))
    return unless result && (!has_select? || select?(result))

    result = resolve_includes(result, options[:include]) if options && options[:include]
    transform(result)
  end

  def find_all(options: nil, **args)
    DelegatingQuery.new(
      store.find_all(**args.merge(options: options)),
      middleware: self,
      options: options
    )
  end

  def resolve_includes(entry, depth)
    return entry unless entry && depth && depth > 0

    # We only care about entries (see #resolved_link?)
    WCC::Contentful::LinkVisitor.new(entry, :Entry, depth: depth).map! do |val|
      resolve_link(val)
    end
  end

  def resolve_link(val)
    return val unless resolved_link?(val)

    if !has_select? || select?(val)
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

  def has_select? # rubocop:disable Naming/PredicateName
    respond_to?(:select?)
  end

  # The default version of `#transform` just returns the entry.
  # Override this with your own implementation.
  def transform(entry)
    entry
  end

  class DelegatingQuery
    include WCC::Contentful::Store::Query::Interface
    include Enumerable

    # by default all enumerable methods delegated to the to_enum method
    delegate(*(Enumerable.instance_methods - Module.instance_methods), to: :to_enum)

    def count
      if middleware.has_select?
        raise NameError, "Count cannot be determined because the middleware '#{middleware}'" \
          " implements the #select? method.  Please use '.to_a.count' to count entries that" \
          ' pass the #select? method.'
      end

      # The wrapped query may get count from the "Total" field in the response,
      # or apply a "COUNT(*)" to the query.
      wrapped_query.count
    end

    attr_reader :wrapped_query, :middleware, :options

    def to_enum
      result = wrapped_query.to_enum
      result = result.select { |x| middleware.select?(x) } if middleware.has_select?

      if options && options[:include]
        result = result.map { |x| middleware.resolve_includes(x, options[:include]) }
      end

      result.map { |x| middleware.transform(x) }
    end

    def apply(filter, context = nil)
      self.class.new(
        wrapped_query.apply(filter, context),
        middleware: middleware,
        options: options,
        **@extra
      )
    end

    def apply_operator(operator, field, expected, context = nil)
      self.class.new(
        wrapped_query.apply_operator(operator, field, expected, context),
        middleware: middleware,
        options: options,
        **@extra
      )
    end

    WCC::Contentful::Store::Query::Interface::OPERATORS.each do |op|
      # @see #apply_operator
      define_method(op) do |field, expected, context = nil|
        self.class.new(
          wrapped_query.public_send(op, field, expected, context),
          middleware: middleware,
          options: options,
          **@extra
        )
      end
    end

    def initialize(wrapped_query, middleware:, options: nil, **extra)
      @wrapped_query = wrapped_query
      @middleware = middleware
      @options = options
      @extra = extra
    end
  end
end
