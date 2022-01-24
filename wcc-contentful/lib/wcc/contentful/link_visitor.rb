# frozen_string_literal: true

# The LinkVisitor is a utility class for walking trees of linked entries.
# It is used internally by the Store layer to compose the resulting resolved hashes.
# But you can use it too!
class WCC::Contentful::LinkVisitor
  attr_reader :entry
  attr_reader :fields
  attr_reader :depth

  # @param [Hash] entry The entry hash (resolved or unresolved) to walk
  # @param [Array<Symbol>] The type of fields to select from the entry tree.
  #         Must be one of `:Link`, `:Entry`, `:Asset`.
  # @param [Fixnum] depth (optional) How far to walk down the tree of links.  Be careful of
  #         recursive trees!
  def initialize(entry, *fields, depth: 0)
    unless entry.is_a?(Hash) && entry.dig('sys', 'type') == 'Entry'
      raise ArgumentError, "Please provide an entry as a hash value (got #{entry})"
    end

    @entry = entry
    @fields = fields.map(&:to_s)
    @depth = depth
  end

  # Walks an entry and its resolved links, without transforming the entry.
  # @yield [value, field, locale]
  # @yieldparam [Object] value The value of the selected field.
  # @yieldparam [WCC::Contentful::IndexedRepresentation::Field] field The type of the selected field
  # @yieldparam [String] locale The locale of the current field value
  # @returns nil
  def each(&block)
    _each do |val, field, locale, index|
      yield(val, field, locale, index) if should_yield_field?(field, val)

      next unless should_walk_link?(field, val)

      self.class.new(val, *fields, depth: depth - 1).each(&block)
    end

    nil
  end

  def map!(&block)
    _each do |val, field, locale, index|
      if should_yield_field?(field, val)
        val = yield(val, field, locale, index)
        set_field(field, locale, index, val)
      end

      next unless should_walk_link?(field, val)

      self.class.new(val, *fields, depth: depth - 1).map!(&block)
    end

    entry
  end

  private

  def _each(&block)
    (entry['fields'] || {}).each do |(k, _v)|
      each_field(k, &block)
    end
  end

  def each_field(field)
    each_locale(field) do |val, locale|
      if val&.is_a?(Array)
        val.each_with_index do |v, index|
          yield(v, field, locale, index) unless v.nil?
        end
      else
        yield(val, field, locale) unless val.nil?
      end
    end
  end

  def each_locale(field)
    raw_value = entry.dig('fields', field)
    if locale = entry.dig('sys', 'locale')
      if raw_value.is_a?(Hash) && raw_value[locale]
        # it's a locale=* entry, but they've added sys.locale to those now
        raw_value = raw_value[locale]
      end
      yield(raw_value, locale)
    else
      raw_value&.each_with_object({}) do |(l, val), h|
        h[l] = yield(val, l)
      end
    end
  end

  def should_yield_field?(_field, value)
    return true if fields.empty?

    case value
    when Hash
      fields.include?(value.dig('sys', 'type'))
    when Array
      value.any? { |v| v.is_a?(Hash) && fields.include?(v.dig('sys', 'type')) }
    end
  end

  def should_walk_link?(_field, val, dep = depth)
    dep > 0 && val.is_a?(Hash) && val.dig('sys', 'type') == 'Entry'
  end

  def set_field(field, locale, index, val)
    current_field = (entry['fields'][field] ||= {})

    if index.nil?
      current_field[locale] = val
    else
      (current_field[locale] ||= [])[index] = val
    end
  end
end
