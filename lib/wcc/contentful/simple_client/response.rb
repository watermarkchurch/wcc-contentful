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
      @raw ||= JSON.parse(body)
    end
    alias_method :to_json, :raw

    def error_message
      raw.dig('message') || "#{code}: #{raw_response.message}"
    end

    def next_page?
      return unless raw.key? 'items'
      raw['items'].length + raw['skip'] < raw['total']
    end

    def next_page
      return unless next_page?

      @next_page ||= @client.get(
        @request[:url],
        (@request[:query] || {}).merge({
          skip: raw['items'].length + raw['skip']
        })
      )
      @next_page.assert_ok!
    end

    def initialize(client, request, raw_response)
      @client = client
      @request = request
      @raw_response = raw_response
      @body = raw_response.body.to_s
    end

    def assert_ok!
      return self if code >= 200 && code < 300
      raise ApiError[code], self
    end

    def each_page(&block)
      raise ArgumentError, 'Not a collection response' unless raw['items']

      ret =
        Enumerator.new do |y|
          y << self

          if next_page?
            next_page.each_page.each do |page|
              y << page
            end
          end
        end

      if block_given?
        ret.map(&block)
      else
        ret.lazy
      end
    end

    def items
      each_page.flat_map do |page|
        page.raw['items']
      end
    end

    def count
      raw['total']
    end

    def first
      raise ArgumentError, 'Not a collection response' unless raw['items']
      raw['items'].first
    end

    def includes
      @includes ||=
        raw.dig('includes')&.each_with_object({}) do |(_t, entries), h|
          entries.each { |e| h[e.dig('sys', 'id')] = e }
        end || {}

      return @includes unless @next_page
      @includes.merge(@next_page.includes)
    end
  end

  class SyncResponse < Response
    def initialize(response)
      super(response.client, response.request, response.raw_response)
    end

    def next_page?
      raw['nextPageUrl'].present?
    end

    def next_page
      return unless next_page?

      @next_page ||= SyncResponse.new(@client.get(raw['nextPageUrl']))
      @next_page.assert_ok!
    end

    def next_sync_token
      # If we haven't grabbed the next page yet, then our next "sync" will be getting
      # the next page.  We could just as easily call sync again with that token.
      @next_page&.next_sync_token ||
        @next_sync_token ||= SyncResponse.parse_sync_token(
          raw['nextPageUrl'] || raw['nextSyncUrl']
        )
    end

    def each_page
      raise ArgumentError, 'Not a collection response' unless raw['items']

      ret =
        Enumerator.new do |y|
          y << self

          if next_page?
            next_page.each_page.each do |page|
              y << page
            end
          end
        end

      if block_given?
        ret.map(&block)
      else
        ret.lazy
      end
    end

    def count
      raise NotImplementedError,
        'Sync does not return an accurate total.  Use #items.count instead.'
    end

    def self.parse_sync_token(url)
      url = URI.parse(url)
      q = CGI.parse(url.query)
      q['sync_token']&.first
    end
  end

  class ApiError < StandardError
    attr_reader :response

    def self.[](code)
      case code
      when 404
        NotFoundError
      else
        ApiError
      end
    end

    def initialize(response)
      @response = response
      super(response.error_message)
    end
  end

  class NotFoundError < ApiError
  end
end
