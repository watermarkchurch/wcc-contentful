# frozen_string_literal: true

class WCC::Contentful::Store::Query
  Condition =
    Struct.new(:path, :op, :expected, :locale_fallbacks) do
      LINK_KEYS = %w[id type linkType].freeze # rubocop:disable Lint/ConstantDefinitionInBlock

      ##
      # Breaks the path into an array of tuples, where each tuple represents an
      # entry subquery.
      # If the query is a simple query on a field in an entry, there will be one
      # tuple in the array:
      #   { 'title' => 'foo' } becomes
      #   [['fields', 'title', 'en-US']]
      #
      # If the query is a query through a link, there will be multiple tuples:
      #  { 'page' => { 'title' => 'foo' } } becomes
      #  [['fields', 'page', 'en-US'], ['fields', 'title', 'en-US']]
      def path_tuples
        return @path_tuples if @path_tuples

        arr = []
        remaining = path.dup
        until remaining.empty?
          locale = nil
          link_sys = nil
          link_field = nil

          sys_or_fields = remaining.shift
          field = remaining.shift
          locale = remaining.shift if sys_or_fields == 'fields'

          if remaining[0] == 'sys' && LINK_KEYS.include?(remaining[1])
            link_sys = remaining.shift
            link_field = remaining.shift
          end

          arr << [sys_or_fields, field, locale, link_sys, link_field].compact
        end
        @path_tuples = arr.freeze
      end

      ##
      # Starting with the last part of the path that is a locale, iterates all the
      # combinations of potential locale fallbacks.
      # e.g. if the path is ['fields', 'page', 'es-MX', 'fields', 'title', 'es-MX']
      # then we get:
      #  ['fields', 'page', 'es-MX', 'fields', 'title', 'es-MX'] (self)
      #  ['fields', 'page', 'es-MX', 'fields', 'title', 'es-US']
      #  ['fields', 'page', 'es-MX', 'fields', 'title', 'en-US']
      #  ['fields', 'page', 'es-US', 'fields', 'title', 'es-MX']
      #  ['fields', 'page', 'es-US', 'fields', 'title', 'es-US']
      #  ['fields', 'page', 'es-US', 'fields', 'title', 'en-US']
      #  ['fields', 'page', 'en-US', 'fields', 'title', 'es-MX']
      #  ['fields', 'page', 'en-US', 'fields', 'title', 'es-US']
      #  ['fields', 'page', 'en-US', 'fields', 'title', 'en-US']
      def each_locale_fallback(&block)
        return to_enum(:each_locale_fallback) unless block_given?

        _each_locale_fallback(path_tuples, 0, &block)
      end

      private

      # Find the next fallback tuples from this set of tuples
      def _each_locale_fallback(original_tuples, start_at, &block)
        tuples = original_tuples.deep_dup
        varying = tuples[start_at]

        if varying[2].nil?
          # This is a non-localizable query, so just yield it
          yield Condition.new(tuples.flatten, op, expected, locale_fallbacks)
          return
        end

        while varying[2]
          if tuples.length > start_at + 1
            # There's more locales that we need to vary to the right, so recurse into those
            _each_locale_fallback(tuples, start_at + 1, &block)
          else
            # We're the tail of the condition, so yield it.
            yield Condition.new(tuples.flatten, op, expected, locale_fallbacks)
          end

          varying[2] = locale_fallbacks[varying[2]]
        end
      end
    end
end
