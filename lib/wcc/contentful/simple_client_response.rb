# frozen_string_literal: true

class WCC::Contentful::SimpleClient
  class Response
    attr_reader :raw_response
    attr_reader :client
    attr_reader :request

    delegate :code, to: :raw_response
    delegate :headers, to: :raw_response

    def body
      @body ||= raw_response.body.to_s
    end

    def raw
      @json ||= JSON.parse(body)
    end
    alias_method :to_json, :raw

    def error_message
      raw.dig('message') || "#{code}: #{raw_response.message}"
    end

    def initialize(client, request, raw_response)
      @client = client
      @request = request
      @raw_response = raw_response
      @body = raw_response.body.to_s
    end

    def assert_ok!
      return self if code >= 200 && code < 300
      raise Contentful::Error[code], self if defined?(Contentful)
      raise ApiError self
    end

    def each_page
      raise ArgumentError, 'Not a collection response' unless raw['items']

      pages = []
      current_page = self
      loop do
        pages << if block_given?
                   yield(current_page)
                 else
                   current_page
                 end

        skip_amt = current_page.raw['items'].length + current_page.raw['skip']
        break if current_page.raw['items'].empty? || skip_amt >= current_page.raw['total']

        current_page = @client.get(
          @request[:url],
          (@request[:query] || {}).merge({ skip: skip_amt })
        )
      end
      pages
    end

    def map
      raise ArgumentError, 'No block given' unless block_given?

      ret =
        each_page do |page|
          page.raw['items'].map do |i|
            yield(OpenStruct.new({ raw: i }.merge(i)))
          end
        end
      ret.flatten
    end

    def each_item(&block)
      map(&block)
      nil
    end

    def all
      map { |i| i }
    end

    def count
      raw['total']
    end

    def first
      raise ArgumentError, 'Not a collection response' unless raw['items']
      return unless item = raw['items'].first
      OpenStruct.new({ raw: item }.merge(item))
    end
  end

  class SyncResponse < Response
    def initialize(response)
      super(response.client, response.request, response.raw_response)
    end

    def next_sync_token
      @next_sync_token ||= SyncResponse.parse_sync_token(raw['nextSyncUrl'])
    end

    def each_page
      raise ArgumentError, 'Not a collection response' unless raw['items']

      pages = []
      current_page = self
      loop do
        pages << if block_given?
                   yield(current_page)
                 else
                   current_page
                 end

        break if current_page.raw['items'].empty?

        current_page = @client.get(raw['nextSyncUrl'])
        current_page.assert_ok!
        @next_sync_token = SyncResponse.parse_sync_token(current_page.raw['nextSyncUrl'])
      end
      pages
    end

    def count
      raw['items'].length
    end

    def self.parse_sync_token(url)
      url = URI.parse(url)
      q = CGI.parse(url.query)
      q['sync_token']&.first
    end
  end
end
