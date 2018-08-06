# frozen_string_literal: true

# This module is extended by all models and defines singleton
# methods that are not dynamically generated.
# @api Model
module WCC::Contentful::ModelSingletonMethods
  def store(preview = false)
    if preview
      if WCC::Contentful::Model.preview_store.nil?
        raise ArgumentError,
          'You must include a contentful preview token in your WCC::Contentful.configure block'
      end
      WCC::Contentful::Model.preview_store
    else
      WCC::Contentful::Model.store
    end
  end

  # Finds an instance of this content type.
  #
  # @return [nil, WCC::Contentful::Model] An instance of the appropriate model class
  #   for this content type, or nil if the ID does not exist in the space.
  # @example
  #   WCC::Contentful::Model::Page.find(id)
  def find(id, options: nil)
    options ||= {}
    context = options.dup
    raw = store(options.delete(:preview))
      .find(id, { hint: type }.merge!(options))
    new(raw, context) if raw.present?
  end

  # Finds all instances of this content type, optionally limiting to those matching
  # a given filter query.
  #
  # @return [Enumerator::Lazy<WCC::Contentful::Model>, <WCC::Contentful::Model>]
  #   A set of instantiated model objects matching the given query.
  # @example
  #   WCC::Contentful::Model::Page.find_all('sys.created_at' => { lte: Date.today })
  def find_all(filter = nil)
    options = filter&.delete(:options) || {}
    context = options.dup

    if filter
      filter.transform_keys! { |k| k.to_s.camelize(:lower) }
      bad_fields = filter.keys.reject { |k| self::FIELDS.include?(k) }
      raise ArgumentError, "These fields do not exist: #{bad_fields}" unless bad_fields.empty?
    end

    query = store(options.delete(:preview))
      .find_all(content_type: content_type, options: options)
    query = query.apply(filter) if filter
    query.map { |r| new(r, context) }
  end

  # Finds the first instance of this content type matching the given query.
  #
  # @return [nil, WCC::Contentful::Model] A set of instantiated model objects matching
  #   the given query.
  # @example
  #   WCC::Contentful::Model::Page.find_by(slug: '/some-slug')
  def find_by(filter = nil)
    options = filter&.delete(:options) || {}
    context = options.dup

    filter.transform_keys! { |k| k.to_s.camelize(:lower) }
    bad_fields = filter.keys.reject { |k| self::FIELDS.include?(k) }
    raise ArgumentError, "These fields do not exist: #{bad_fields}" unless bad_fields.empty?

    result = store(options.delete(:preview))
      .find_by(content_type: content_type, filter: filter, options: options)

    new(result, context) if result
  end

  def inherited(subclass)
    # only register if it's not already registered
    return if WCC::Contentful::Model.registered?(content_type)
    WCC::Contentful::Model.register_for_content_type(content_type, klass: subclass)
  end
end
