# frozen_string_literal: true

module WCC::Contentful::Middleware::Store
  extend ActiveSupport::Concern

  attr_accessor :store

  delegate :index, :set, :delete, to: :store

  def find(id)
    found = store.find(id)
    return transform(found) if select(found)
  end

  def find_by(options: nil, **args)
    result = store.find_by(**args.merge(options: options))
    return unless select(result)

    result = resolve_includes(result, options[:include]) if options && options[:include]
    transform(result)
  end

  def find_all(options: nil, **args)
    result =
      store.find_all(**args.merge(options: options))
        .select { |x| select(x) }

    result = result.map { |x| resolve_includes(x, options[:include]) } if options && options[:include]

    result.map { |x| transform(x) }
  end

  private

  def resolve_includes(entry, depth)
    return entry unless entry && depth && depth > 0 && fields = entry['fields']

    fields.each do |(_name, locales)|
      # TODO: handle non-* locale
      locales.each do |(locale, val)|
        locales[locale] =
          if val.is_a? Array
            val.map { |e| resolve_link(e, depth) }
          else
            resolve_link(val, depth)
          end
      end
    end

    entry
  end

  def resolve_link(val, depth)
    return val unless val.is_a?(Hash) && val.dig('sys', 'type') == 'Entry'

    unless select(val)
      # Pretend it's an unresolved link -
      # matches the behavior of a store when the link cannot be retrieved
      return WCC::Contentful::Link.new(val.dig('sys', 'id'), val.dig('sys', 'type')).to_h
    end

    transform(resolve_includes(val, depth - 1))
  end

  def select(_entry)
    true
  end

  def transform(entry)
    entry
  end
end
