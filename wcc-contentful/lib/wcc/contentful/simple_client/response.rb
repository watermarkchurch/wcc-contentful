# frozen_string_literal: true

require_relative '../instrumentation'

class WCC::Contentful::SimpleClient
  class Response
    include ::WCC::Contentful::Instrumentation

    attr_reader :raw_response, :client, :request

    delegate :status, to: :raw_response
    alias_method :code, :status
    delegate :headers, to: :raw_response

    def body
      @body ||= raw_response.body.to_s
    end

    def raw
      @raw ||= JSON.parse(body)
    end
    alias_method :to_json, :raw

    def error_message
      parsed_message =
        begin
          raw['message']
        rescue JSON::ParserError
          nil
        end
      parsed_message || "#{code}: #{raw_response.body}"
    end

    def skip
      raw['skip']
    end

    def total
      raw['total']
    end

    def next_page?
      return unless raw.key? 'items'

      page_items.length + skip < total
    end

    def next_page
      return unless next_page?

      query = (@request[:query] || {}).merge({
        skip: page_items.length + skip
      })
      np =
        _instrument 'page', url: @request[:url], query: query do
          @client.get(@request[:url], query)
        end
      np.assert_ok!
    end

    def initialize(client, request, raw_response)
      @client = client
      @request = request
      @raw_response = raw_response
      @body = raw_response.body.to_s
    end

    def assert_ok!
      return self if status >= 200 && status < 300

      raise ApiError[status], self
    end

    def each_page(&block)
      raise ArgumentError, 'Not a collection response' unless page_items

      ret = PaginatingEnumerable.new(self)

      if block_given?
        ret.map(&block)
      else
        ret.lazy
      end
    end

    def items
      each_page.flat_map(&:page_items)
    end

    def page_items
      raw['items']
    end

    def count
      total
    end

    def first
      raise ArgumentError, 'Not a collection response' unless page_items

      page_items.first
    end

    def includes
      @includes ||=
        raw['includes']&.each_with_object({}) do |(_t, entries), h|
          entries&.each { |e| h[e.dig('sys', 'id')] = e }
        end || {}
    end
  end

  class SyncResponse < Response
    def initialize(response, memoize: false)
      super(response.client, response.request, response.raw_response)
      @memoize = memoize
    end

    def next_page?
      raw['nextPageUrl'].present?
    end

    def next_page
      return unless next_page?
      return @next_page if @next_page

      url = raw['nextPageUrl']
      next_page =
        _instrument 'page', url: url do
          @client.get(url)
        end

      next_page = SyncResponse.new(next_page)
      next_page.assert_ok!
      @next_page = next_page if @memoize
      next_page
    end

    def next_sync_token
      # If we have iterated some pages, return the sync token of the final
      # page that was iterated.  Do this without maintaining a reference to
      # all the pages.
      return @last_sync_token if @last_sync_token

      SyncResponse.parse_sync_token(raw['nextPageUrl'] || raw['nextSyncUrl'])
    end

    def each_page(&block)
      if block_given?
        super do |page|
          @last_sync_token = page.next_sync_token

          yield page
        end
      else
        super.map do |page|
          @last_sync_token = page.next_sync_token
          page
        end
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

  class PaginatingEnumerable
    include Enumerable

    def initialize(initial_page)
      raise ArgumentError, 'Must provide initial page' unless initial_page.present?

      @initial_page = initial_page
    end

    def each
      page = @initial_page
      yield page

      while page.next_page?
        page = page.next_page
        yield page
      end
    end
  end

  class ApiError < StandardError
    attr_reader :response

    def self.[](code)
      case code
      when 404
        NotFoundError
      when 401
        UnauthorizedError
      when 429
        RateLimitError
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

  class UnauthorizedError < ApiError
  end

  class RateLimitError < ApiError
  end
end
