
# frozen_string_literal: true

##
# This module is extended by all models and defines singleton
# methods that are not dynamically generated.
module WCC::Contentful::ModelSingletonMethods
  def find(id, context = nil)
    raw = WCC::Contentful::Model.store.find(id)
    new(raw, context) if raw.present?
  end

  def find_all(filter = nil, context = nil)
    if filter
      filter.transform_keys! { |k| k.to_s.camelize(:lower) }
      bad_fields = filter.keys.reject { |k| self::FIELDS.include?(k) }
      raise ArgumentError, "These fields do not exist: #{bad_fields}" unless bad_fields.empty?
    end

    query = WCC::Contentful::Model.store.find_all(content_type: content_type)
    query = query.apply(filter) if filter
    query.map { |r| new(r, context) }
  end

  def find_by(filter, context = nil)
    filter.transform_keys! { |k| k.to_s.camelize(:lower) }
    bad_fields = filter.keys.reject { |k| self::FIELDS.include?(k) }
    raise ArgumentError, "These fields do not exist: #{bad_fields}" unless bad_fields.empty?

    result =
      if defined?(context[:preview]) && context[:preview] == true
        if WCC::Contentful::Model.preview_store.nil?
          raise ArgumentError,
            'You must include a contentful preview token in your WCC::Contentful.configure block'
        end
        WCC::Contentful::Model.preview_store.find_by(content_type: content_type, filter: filter)
      else
        WCC::Contentful::Model.store.find_by(content_type: content_type, filter: filter)
      end

    new(result, context) if result
  end

  def inherited(subclass)
    # only register if it's not already registered
    return if WCC::Contentful::Model.registered?(content_type)
    WCC::Contentful::Model.register_for_content_type(content_type, klass: subclass)
  end
end
