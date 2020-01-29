# frozen_string_literal: true

module WCC::Contentful::Store
  class CDNAdapter
    # Note: CDNAdapter should not instrument store events cause it's not a store.

    attr_reader :client

    # The CDNAdapter cannot index data coming back from the Sync API.
    def index?
      false
    end

    # Intentionally not implementing write methods

    def initialize(client)
      super()
      @client = client
    end

    def find(key, hint: nil, **options)
      options = { locale: '*' }.merge!(options || {})
      entry =
        if hint
          client.public_send(hint.underscore, key, options)
        else
          begin
            client.entry(key, options)
          rescue WCC::Contentful::SimpleClient::NotFoundError
            client.asset(key, options)
          end
        end
      entry&.raw
    rescue WCC::Contentful::SimpleClient::NotFoundError
      nil
    end

    def find_by(content_type:, filter: nil, options: nil)
      # default implementation - can be overridden
      q = find_all(content_type: content_type, options: { limit: 1 }.merge!(options || {}))
      q = q.apply(filter) if filter
      q.first
    end

    def find_all(content_type:, options: nil)
      Query.new(
        self,
        client: @client,
        relation: { content_type: content_type },
        options: options
      )
    end

    class Query
      include Enumerable

      delegate :count, to: :response
      delegate :each, to: :to_enum

      def to_enum
        return response.items unless @options[:include]

        response.items.map { |e| resolve_includes(e, @options[:include]) }
      end

      def initialize(store, client:, relation:, options: nil, **extra)
        raise ArgumentError, 'Client cannot be nil' unless client.present?
        raise ArgumentError, 'content_type must be provided' unless relation[:content_type].present?

        @store = store
        @client = client
        @relation = relation
        @options = options || {}
        @extra = extra || {}
      end

      # Called with a filter object by {Base#find_by} in order to apply the filter.
      def apply(filter, context = nil)
        filter.reduce(self) do |query, (field, value)|
          if value.is_a?(Hash)
            if op?(k = value.keys.first)
              query.apply_operator(k.to_sym, field.to_s, value[k], context)
            else
              query.nested_conditions(field, value, context)
            end
          else
            query.apply_operator(:eq, field.to_s, value)
          end
        end
      end

      def apply_operator(operator, field, expected, context = nil)
        op = operator == :eq ? nil : operator
        param = parameter(field, operator: op, context: context, locale: true)

        self.class.new(
          @store,
          client: @client,
          relation: @relation.merge(param => expected),
          options: @options,
          **@extra
        )
      end

      def nested_conditions(field, conditions, context)
        base_param = parameter(field)

        conditions.reduce(self) do |query, (ref, value)|
          query.apply({ "#{base_param}.#{parameter(ref)}" => value }, context)
        end
      end

      WCC::Contentful::Store::Query::OPERATORS.each do |op|
        define_method(op) do |field, expected, context = nil|
          apply_operator(op, field, expected, context)
        end
      end

      private

      def op?(key)
        WCC::Contentful::Store::Query::OPERATORS.include?(key.to_sym)
      end

      def sys?(field)
        field.to_s =~ /sys\./
      end

      def id?(field)
        field.to_sym == :id
      end

      def response
        @response ||=
          if @relation[:content_type] == 'Asset'
            @client.assets(
              { locale: '*' }.merge!(@relation.reject { |k| k == :content_type }).merge!(@options)
            )
          else
            @client.entries({ locale: '*' }.merge!(@relation).merge!(@options))
          end
      end

      def resolve_includes(entry, depth)
        return entry unless entry && depth && depth > 0

        WCC::Contentful::LinkVisitor.new(entry, :Link, :Asset, depth: depth).map! do |val|
          resolve_link(val)
        end
      end

      def resolve_link(val)
        return val unless val.is_a?(Hash) && val.dig('sys', 'type') == 'Link'
        return val unless included = response.includes[val.dig('sys', 'id')]

        included
      end

      def parameter(field, operator: nil, context: nil, locale: false)
        if sys?(field)
          "#{field}#{op_param(operator)}"
        elsif id?(field)
          "sys.#{field}#{op_param(operator)}"
        else
          "#{field_reference(field)}#{locale(context) if locale}#{op_param(operator)}"
        end
      end

      def locale(context)
        ".#{(context || {}).fetch(:locale, 'en-US')}"
      end

      def op_param(operator)
        operator ? "[#{operator}]" : ''
      end

      def field_reference(field)
        return field if nested?(field)

        "fields.#{field}"
      end

      def nested?(field)
        field.to_s.include?('.')
      end
    end
  end
end
