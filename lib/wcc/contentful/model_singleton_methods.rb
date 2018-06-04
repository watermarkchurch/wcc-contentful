
# frozen_string_literal: true

##
# This module is extended by all models and defines singleton
# methods that are not dynamically generated.
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

  def find(id, options: nil)
    options ||= {}
    raw = store(options[:preview]).find(id)
    new(raw, options) if raw.present?
  end

  def find_all(filter = nil)
    options = filter&.delete(:options) || {}

    if filter
      filter.transform_keys! { |k| k.to_s.camelize(:lower) }
      bad_fields = filter.keys.reject { |k| self::FIELDS.include?(k) }
      raise ArgumentError, "These fields do not exist: #{bad_fields}" unless bad_fields.empty?
    end

    query = store(options.delete(:preview))
      .find_all(content_type: content_type, query: options)
    query = query.apply(filter) if filter
    query.map { |r| new(r, options) }
  end

  def find_by(filter = nil)
    options = filter&.delete(:options) || {}

    filter.transform_keys! { |k| k.to_s.camelize(:lower) }
    bad_fields = filter.keys.reject { |k| self::FIELDS.include?(k) }
    raise ArgumentError, "These fields do not exist: #{bad_fields}" unless bad_fields.empty?

    result = store(options.delete(:preview))
      .find_by(content_type: content_type, filter: filter, query: options)

    new(result, options) if result
  end

  def inherited(subclass)
    # only register if it's not already registered
    return if WCC::Contentful::Model.registered?(content_type)
    WCC::Contentful::Model.register_for_content_type(content_type, klass: subclass)
  end
end
