# frozen_string_literal: true

# The LinkVisitor is a utility class for walking trees of linked entries.
# It is used internally by the Store layer to compose the resulting resolved hashes.
# But you can use it too!
class WCC::Contentful::LinkVisitor
  attr_reader :entry
  attr_reader :type
  attr_reader :fields
  attr_reader :depth

  # @param [Hash] entry The entry hash (resolved or unresolved) to walk
  # @param [Array<String, Symbol>] The fields to select from the entry tree.
  #         Use `:Link` to select only links, or `'slug'` to select all slugs in the tree.
  # @param [Fixnum] depth (optional) How far to walk down the tree of links.  Be careful of
  #         recursive trees!
  # @example
  #   entry = store.find_by(id: id, include: 3)
  #   WCC::Contentful::LinkVisitor.new(entry, 'slug', depth: 3)
  #     .map { |slug| 'https://mirror-site' + slug }
  def initialize(entry, *fields, depth: 0)
    unless entry.is_a?(Hash) && entry.dig('sys', 'id')
      raise ArgumentError, "Please provide an entry as a hash value (got #{entry})"
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

  # Walks an entry and its resolved links, without transforming the entry.
  # @yield [value, field, locale]
  # @yieldparam [Object] value The value of the selected field.
  # @yieldparam [WCC::Contentful::IndexedRepresentation::Field] field The type of the selected field
  # @yieldparam [String] locale The locale of the current field value
  # @returns nil
  def visit(&block)
    _visit do |val, field, locale, index|
      yield(val, field, locale, index) if should_yield_field?(field)

      next unless should_walk_link?(field, val)

      self.class.new(val, *fields, depth: depth - 1).visit(&block)
    end

    nil
  end

  # Walks an entry and its resolved links, transforming the given values.
  # @yield [value, field, locale]
  # @yieldparam value The value of the selected field.
  # @yieldparam [WCC::Contentful::IndexedRepresentation::Field] field The type of the selected field
  # @yieldparam [String] locale The locale of the current field value
  # @yieldreturn The new value of the field.
  # @returns A new entry hash, with selected fields replaced by the results of the block
  def map(&block)
    fields =
      entry['fields'].each_with_object({}) do |(key, value), h|
        h[key] =
          if field_def = type.fields[key]
            map_field(field_def, &block)
          else
            value.deep_dup
          end
      end

    entry.merge({
      'sys' => entry['sys'].deep_dup,
      'fields' => fields
    })
  end

  def map_in_place(&block)
    _visit do |val, field, locale, index|
      if should_yield_field?(field)
        val = yield(val, field, locale, index)
        set_field(field, locale, index, val)
      end

      next unless should_walk_link?(field, val)

      self.class.new(val, *fields, depth: depth - 1).map_in_place(&block)
    end

    entry
  end

  private

  def _visit(&block)
    type.fields.each_value do |f|
      visit_field(f, &block)
    end
  end

  def visit_field(field)
    each_locale(field) do |val, locale|
      if field.array
        val&.each_with_index do |v, index|
          yield(v, field, locale, index) unless v.nil?
        end
      else
        yield(val, field, locale) unless val.nil?
      end
    end
  end

  def map_field(field, &block)
    each_locale(field) do |val, locale|
      if field.array
        val&.map&.with_index do |v, index|
          map_field_value(v, field, locale, index, &block) unless v.nil?
        end
      else
        map_field_value(val, field, locale, &block) unless val.nil?
      end
    end
  end

  def map_field_value(val, field, locale, index = nil, &block)
    val =
      if should_yield_field?(field)
        yield(val, field, locale, index)
      else
        val.dup
      end

    val = self.class.new(val, *fields, depth: depth - 1).map(&block) if should_walk_link?(field, val)

    val
  end

  def each_locale(field)
    raw_value = entry.dig('fields', field.name)
    if locale = entry.dig('sys', 'locale')
      yield(raw_value, locale)
    else
      raw_value&.each_with_object({}) do |(l, val), h|
        h[l] = yield(val, l)
      end
    end
  end

  def should_yield_field?(field)
    fields.empty? || fields.include?(field.type) || fields.include?(field.name)
  end

  def should_walk_link?(field, val, dep = depth)
    dep > 0 && field.type == :Link && val.dig('sys', 'type') == 'Entry'
  end

  def set_field(field, locale, index, val)
    current_field = (entry['fields'][field.name] ||= {})

    if field.array
      (current_field[locale] ||= [])[index] = val
    else
      current_field[locale] = val
    end
  end
end
