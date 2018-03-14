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

    def each_page(&block)
      raise ArgumentError, 'Not a collection response' unless raw['items']

      memoized_pages = (@memoized_pages ||= [self])
      ret =
        Enumerator.new do |y|
          page_index = 0
          current_page = self
          loop do
            y << current_page

            skip_amt = current_page.raw['items'].length + current_page.raw['skip']
            break if current_page.raw['items'].empty? || skip_amt >= current_page.raw['total']

            page_index += 1
            if page_index < memoized_pages.length
              current_page = memoized_pages[page_index]
            else
              current_page = @client.get(
                @request[:url],
                (@request[:query] || {}).merge({ skip: skip_amt })
              )
              current_page.assert_ok!
              memoized_pages.push(current_page)
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

      memoized_pages = (@memoized_pages ||= [self])
      ret =
        Enumerator.new do |y|
          page_index = 0
          current_page = self
          loop do
            y << current_page

            break if current_page.raw['items'].empty?

            page_index += 1
            if page_index < memoized_pages.length
              current_page = memoized_pages[page_index]
            else
              current_page = @client.get(raw['nextSyncUrl'])
              current_page.assert_ok!
              @next_sync_token = SyncResponse.parse_sync_token(current_page.raw['nextSyncUrl'])
              memoized_pages.push(current_page)
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
      raw['items'].length
    end

    def self.parse_sync_token(url)
      url = URI.parse(url)
      q = CGI.parse(url.query)
      q['sync_token']&.first
    end
  end
end
