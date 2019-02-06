# frozen_string_literal: true

class WCC::Contentful::LinkVisitor
  attr_reader :entry
  attr_reader :type

  def initialize(entry)
    unless entry.is_a?(Hash) && entry.dig('sys', 'id')
      raise ArgumentError, 'Please provide an entry as a hash value'
    end
    unless ct = entry.dig('sys', 'contentType', 'sys', 'id')
      raise ArgumentError, 'Entry has no content type!'
    end

    @entry = entry
    @type = WCC::Contentful.types[ct]
    raise ArgumentError, "Unknown content type '#{ct}'" unless @type
  end

  def visit(*fields, depth: 0, &block)
    type.fields.each_value do |f|
      if fields.empty? || fields.include?(f.type) || fields.include?(f.name)
        if f.array
          visit_array_field(f, depth, &block)
        else
          visit_field(f, depth, &block)
        end
      end
    end

    nil
  end

  private

  def visit_array_field(field, _depth)
    each_locale(field) do |val, locale|
      val&.map do |v|
        yield(v, field, locale)
      end
    end
  end

  def visit_field(field, _depth)
    each_locale(field) do |val, locale|
      yield(val, field, locale)
    end
  end

  def each_locale(field)
    raw_value = entry.dig('fields', field.name)
    if entry.dig('sys', 'locale')
      yield(raw_value, entry.dig('sys', 'locale'))
    else
      raw_value&.each do |(locale, val)|
        yield(val, locale)
      end
    end
  end
end
