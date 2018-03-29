# frozen_string_literal: true

module WCC::Contentful::Store
  class CDNAdapter < Base
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
    end

    def find_all(content_type:)
      Query.new(@client, content_type: content_type)
    end

    class Query < Base::Query
      delegate :count, to: :resolve

      def result
        resolve.items
      end

      def initialize(client, relation)
        raise ArgumentError, 'Client cannot be nil' unless client.present?
        raise ArgumentError, 'content_type must be provided' unless relation[:content_type].present?
        @client = client
        @relation = relation
      end

      def eq(field, expected, context = nil)
        locale = context[:locale] if context.present?
        locale ||= 'en-US'
        Query.new(@client,
          @relation.merge("fields.#{field}.#{locale}" => expected))
      end

      private

      def resolve
        return @resolve if @resolve
        @resolve ||=
          if @relation[:content_type] == 'Asset'
            @client.assets(
              { locale: '*' }.merge!(@relation.reject { |k| k == :content_type })
            )
          else
            @client.entries({ locale: '*' }.merge!(@relation))
          end
      end
    end
  end
end
