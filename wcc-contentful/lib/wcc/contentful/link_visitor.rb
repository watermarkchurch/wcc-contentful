# frozen_string_literal: true

class WCC::Contentful::LinkVisitor
  attr_reader :entry
  attr_reader :type
  attr_reader :fields
  attr_reader :depth

  def initialize(entry, *fields, depth: 0)
    unless entry.is_a?(Hash) && entry.dig('sys', 'id')
      raise ArgumentError, 'Please provide an entry as a hash value'
    end
    unless ct = entry.dig('sys', 'contentType', 'sys', 'id')
      raise ArgumentError, 'Entry has no content type!'
    end

    @type = WCC::Contentful.types[ct]
    raise ArgumentError, "Unknown content type '#{ct}'" unless @type

    @entry = entry
    @fields = fields
    @depth = depth
  end

  def visit(&block)
    type.fields.each_value do |f|
      if f.array
        visit_array_field(f, &block)
      else
        visit_field(f, &block)
      end
    end

    nil
  end

  private

  def visit_array_field(field, &block)
    each_locale(field) do |val, locale|
      val&.map do |v|
        visit_field_value(v, field, locale, &block)
      end
    end
  end

  def visit_field(field, &block)
    each_locale(field) do |val, locale|
      visit_field_value(val, field, locale, &block)
    end
  end

  def visit_field_value(val, field, locale, &block)
    yield(val, field, locale) if fields.empty? || fields.include?(field.type) || fields.include?(field.name)

    if depth > 0 && field.type == :Link && val.dig('sys', 'type') == 'Entry'
      self.class.new(val, *fields, depth: depth - 1).visit(&block)
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
