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
    raw = store(options[:preview])
      .find(id, { hint: type }.merge!(options.except(:preview)))
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

    query = store(options[:preview])
      .find_all(content_type: content_type, options: options.except(:preview))
    query = query.apply(filter) if filter.present?
    query.map { |r| new(r, options) }
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

    result = store(options[:preview])
      .find_by(content_type: content_type, filter: filter, options: options.except(:preview))

    new(result, options) if result
  end

  def inherited(subclass)
    # only register if it's not already registered
    return if WCC::Contentful::Model.registered?(content_type)

    WCC::Contentful::Model.register_for_content_type(content_type, klass: subclass)
  end
end
