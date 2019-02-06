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

  def map(&block)
    fields =
      entry['fields'].each_with_object({}) do |(key, value), h|
        h[key] =
          if field_def = type.fields[key]
            if field_def.array
              map_array_field(field_def, &block)
            else
              map_field(field_def, &block)
            end
          else
            value.deep_dup
          end
      end

    entry.merge({
      'sys' => entry['sys'].deep_dup,
      'fields' => fields
    })
  end

  private

  def visit_array_field(field, &block)
    each_locale(field) do |val, locale|
      val&.each do |v|
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
    if fields.empty? || fields.include?(field.type) || fields.include?(field.name)
      yield(val, field, locale)
    end

    return unless depth > 0 && field.type == :Link && val.dig('sys', 'type') == 'Entry'

    self.class.new(val, *fields, depth: depth - 1).visit(&block)
  end

  def map_array_field(field, &block)
    each_locale(field) do |val, locale|
      val&.map do |v|
        map_field_value(v, field, locale, &block)
      end
    end
  end

  def map_field(field, &block)
    each_locale(field) do |val, locale|
      map_field_value(val, field, locale, &block)
    end
  end

  def map_field_value(val, field, locale, &block)
    val =
      if fields.empty? || fields.include?(field.type) || fields.include?(field.name)
        yield(val, field, locale)
      else
        val.dup
      end

    if depth > 0 && field.type == :Link && val.dig('sys', 'type') == 'Entry'
      val = self.class.new(val, *fields, depth: depth - 1).map(&block)
    end

    val
  end

  def each_locale(field)
    raw_value = entry.dig('fields', field.name)
    if entry.dig('sys', 'locale')
      yield(raw_value, entry.dig('sys', 'locale'))
    else
      raw_value&.each_with_object({}) do |(locale, val), h|
        h[locale] = yield(val, locale)
      end
    end
  end
end
