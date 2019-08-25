# typed: false
# frozen_string_literal: true

module WCC::Contentful::Store
  class CDNAdapter
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
        store: self,
        client: @client,
        relation: { content_type: content_type },
        options: options
      )
    end

    class Query < Base::Query
      delegate :count, to: :response

      def to_enum
        return response.items unless @options[:include]

        response.items.map { |e| resolve_includes(e, @options[:include]) }
      end

      def initialize(store:, client:, relation:, options: nil, **extra)
        raise ArgumentError, 'Client cannot be nil' unless client.present?
        raise ArgumentError, 'content_type must be provided' unless relation[:content_type].present?

        super(store)
        @client = client
        @relation = relation
        @options = options || {}
        @extra = extra || {}
      end

      def apply_operator(operator, field, expected, context = nil)
        op = operator == :eq ? nil : operator
        param = parameter(field, operator: op, context: context, locale: true)

        self.class.new(
          store: @store,
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

      Base::Query::OPERATORS.each do |op|
        define_method(op) do |field, expected, context = nil|
          apply_operator(op, field, expected, context)
        end
      end

      private

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
