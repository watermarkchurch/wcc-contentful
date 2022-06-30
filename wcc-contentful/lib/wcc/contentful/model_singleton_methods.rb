# frozen_string_literal: true

# This module is extended by all models and defines singleton
# methods that are not dynamically generated.
# @api Model
module WCC::Contentful::ModelSingletonMethods
  # Finds an instance of this content type.
  #
  # @return [nil, WCC::Contentful::Model] An instance of the appropriate model class
  #   for this content type, or nil if the ID does not exist in the space.
  # @example
  #   WCC::Contentful::Model::Page.find(id)
  def find(id, options: nil)
    options ||= {}
    store = options[:preview] ? services.preview_store : services.store
    raw =
      _instrumentation.instrument 'find.model.contentful.wcc',
        content_type: content_type, id: id, options: options do
        store.find(id, **{ hint: type }.merge!(options.except(:preview)))
      end
    new(raw, options) if raw.present?
  end

  # Finds all instances of this content type, optionally limiting to those matching
  # a given filter query.
  #
  # @return [Enumerator::Lazy<WCC::Contentful::Model>, <WCC::Contentful::Model>]
  #   A set of instantiated model objects matching the given query.
  # @example
  #   WCC::Contentful::Model::Page.find_all('sys.created_at' => { lte: Date.today })
  def find_all(filter = nil)
    filter = filter&.dup
    options = filter&.delete(:options) || {}

    filter.transform_keys! { |k| k.to_s.camelize(:lower) } if filter.present?

    store = options[:preview] ? services.preview_store : services.store
    query =
      _instrumentation.instrument 'find_all.model.contentful.wcc',
        content_type: content_type, filter: filter, options: options do
        store.find_all(content_type: content_type, options: options.except(:preview))
      end
    query = query.apply(filter) if filter.present?
    ModelQuery.new(query, options, self)
  end

  # Finds the first instance of this content type matching the given query.
  #
  # @return [nil, WCC::Contentful::Model] A set of instantiated model objects matching
  #   the given query.
  # @example
  #   WCC::Contentful::Model::Page.find_by(slug: '/some-slug')
  def find_by(filter = nil)
    filter = filter&.dup
    options = filter&.delete(:options) || {}

    filter.transform_keys! { |k| k.to_s.camelize(:lower) } if filter.present?

    store = options[:preview] ? services.preview_store : services.store
    result =
      _instrumentation.instrument 'find_by.model.contentful.wcc',
        content_type: content_type, filter: filter, options: options do
        store.find_by(content_type: content_type, filter: filter, options: options.except(:preview))
      end

    new(result, options) if result
  end

  def inherited(subclass)
    # If another different class is already registered for this content type,
    # don't auto-register this one.
    return if model_namespace.registered?(content_type)

    model_namespace.register_for_content_type(content_type, klass: subclass)
  end

  class ModelQuery
    include Enumerable

    # by default all enumerable methods delegated to the to_enum method
    delegate(*(Enumerable.instance_methods - Module.instance_methods), to: :to_enum)
    delegate :each, to: :to_enum

    # except count - because that needs to pull data off the final query obj
    delegate :count, to: :wrapped_query

    attr_reader :wrapped_query, :options, :klass

    def initialize(wrapped_query, options, klass)
      @wrapped_query = wrapped_query
      @options = options
      @klass = klass
    end

    def to_enum
      wrapped_query.to_enum
        .map { |r| klass.new(r, options) }
    end
  end
end
