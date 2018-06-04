# frozen_string_literal: true

module WCC::Contentful::Store
  class CDNAdapter
    attr_reader :client

    # Intentionally not implementing write methods

    def initialize(client)
      super()
      @client = client
    end

    def find(key)
      entry =
        begin
          client.entry(key, locale: '*')
        rescue WCC::Contentful::SimpleClient::NotFoundError
          client.asset(key, locale: '*')
        end
      entry&.raw
    rescue WCC::Contentful::SimpleClient::NotFoundError
      nil
    end

    def find_by(content_type:, filter: nil, query: nil)
      # default implementation - can be overridden
      q = find_all(content_type: content_type, query: query)
      q = q.apply(filter) if filter
      q.first
    end

    def find_all(content_type:, query: nil)
      Query.new(self, @client, { content_type: content_type }, query)
    end

    class Query < Base::Query
      delegate :count, to: :response

      def result
        return response.items unless @query[:include]
        response.items.map { |e| resolve_includes(e, @query[:include]) }
      end

      def initialize(store, client, relation, query = nil)
        raise ArgumentError, 'Client cannot be nil' unless client.present?
        raise ArgumentError, 'content_type must be provided' unless relation[:content_type].present?

        super(store)
        @client = client
        @relation = relation
        @query = query || {}
      end

      def apply_operator(operator, field, expected, context = nil)
        op = operator == :eq ? nil : operator
        param = parameter(field, operator: op, context: context, locale: true)

        Query.new(@store, @client, @relation.merge(param => expected), @query)
      end

      def nested_conditions(field, conditions, context)
        base_param = parameter(field)

        conditions.reduce(self) do |query, (ref, value)|
          query.apply({ "#{base_param}.#{parameter(ref)}" => value }, context)
        end
      end

      private

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

      def response
        return @response if @response
        @response ||=
          if @relation[:content_type] == 'Asset'
            @client.assets(
              { locale: '*' }.merge!(@relation.reject { |k| k == :content_type }).merge!(@query)
            )
          else
            @client.entries({ locale: '*' }.merge!(@relation).merge!(@query))
          end
      end

      def resolve_link(val, depth)
        return val unless val.is_a?(Hash) && val.dig('sys', 'type') == 'Link'
        return val unless included = response.includes[val.dig('sys', 'id')]
        resolve_includes(included, depth - 1)
      end
    end
  end
end
