# frozen_string_literal: true

module WCC::Contentful::Store
  class CDNAdapter
    include WCC::Contentful::Store::Interface
    # NOTE: CDNAdapter should not instrument store events cause it's not a store.

    attr_writer :client, :preview_client

    def client
      @preview ? @preview_client : @client
    end

    # The CDNAdapter cannot index data coming back from the Sync API.
    def index?
      false
    end

    def index
      raise NotImplementedError, 'Cannot put data to the CDN!'
    end

    # Intentionally not implementing write methods

    def initialize(client = nil, preview: false)
      super()
      @client = client
      @preview = preview
    end

    def find(key, hint: nil, **options)
      options = options&.dup || {}
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
        client: client,
        relation: { content_type: content_type },
        options: options
      )
    end

    class Query
      include WCC::Contentful::Store::Query::Interface
      include Enumerable

      # by default all enumerable methods delegated to the lazy enumerable
      delegate(*(Enumerable.instance_methods - Module.instance_methods), to: :to_enum)

      # response.count gets the number of items
      delegate :count, to: :response

      def to_enum
        return response.each_page.flat_map(&:page_items) unless @options[:include]

        response.each_page
          .flat_map { |page| page.page_items.each_with_object(page).to_a }
          .map do |e, page|
            resolve_includes(e, page.includes, depth: @options[:include])
          end
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
        if expected.is_a?(Array)
          expected = expected.join(',')
          op = :in if op.nil?
        end

        param = parameter(field, operator: op, context: context, locale: false)

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

      WCC::Contentful::Store::Query::Interface::OPERATORS.each do |op|
        define_method(op) do |field, expected, context = nil|
          apply_operator(op, field, expected, context)
        end
      end

      private

      def op?(key)
        WCC::Contentful::Store::Query::Interface::OPERATORS.include?(key.to_sym)
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
              @relation.reject { |k| k == :content_type }.merge(@options)
            )
          else
            @client.entries(@relation.merge(@options))
          end
      end

      def resolve_includes(entry, includes, depth:)
        return entry unless entry && depth && depth > 0

        # Dig links out of response.includes and insert them into the entry
        WCC::Contentful::LinkVisitor.new(entry, :Link, depth: depth - 1).map! do |val|
          resolve_link(val, includes)
        end
      end

      def resolve_link(val, includes)
        return val unless val.is_a?(Hash) && val.dig('sys', 'type') == 'Link'
        return val unless included = includes[val.dig('sys', 'id')]

        included
      end

      # Constructs the CDN query parameter from a structured field definition and
      # operator.
      # Notes:
      #  * "eq" can be omitted, e.g. 'fields.slug=/' is equivalent to 'fields.slug[eq]=/'
      #  * If "locale" is specified in the query, matching is done against that locale,
      #      unless the query explicitly specifies the locale.  Examples:
      #      'locale=es-US&fields.title=página principal' matches on the es locale
      #      'locale=en-US&fields.title=página principal' returns nothing
      #      'locale=en-US&fields.title.es-US=página principal' returns the page, but in the english locale.
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
