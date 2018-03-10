# frozen_string_literal: true

module WCC::Contentful::Store
  class CDNAdapter
    attr_reader :client

    def initialize(client)
      @client = client
    end

    def find(key)
      entry =
        begin
          client.entry(key, locale: '*')
        rescue Contentful::NotFound
          client.asset(key, locale: '*')
        end
      entry&.raw
    end

    def find_all
      raise ArgumentError, 'use find_by content type instead'
    end

    def find_by(content_type:)
      Query.new(@client, content_type: content_type)
    end

    class Query
      delegate :count, to: :resolve

      def first
        resolve.first
      end

      def map
        resolve.map do |entry|
          yield entry
        end
      end

      def result
        raise ArgumentError, 'Not Implemented'
      end

      def initialize(client, relation)
        raise ArgumentError, 'Client cannot be nil' unless client.present?
        raise ArgumentError, 'content_type must be provided' unless relation[:content_type].present?
        @client = client
        @relation = relation
      end

      def apply(filter, context = nil)
        return eq(filter[:field], filter[:eq], context) if filter[:eq]

        raise ArgumentError, "Filter not implemented: #{filter}"
      end

      def eq(field, expected, context = nil)
        locale = context[:locale] if context.present?
        locale ||= 'en-US'
        Query.new(@client,
          @relation.merge("fields.#{field}.#{locale}" => expected))
      end

      private

      def resolve
        return @resolved if @resolved
        @client.entries({ locale: '*' }.merge!(@relation))
      end
    end
  end
end
