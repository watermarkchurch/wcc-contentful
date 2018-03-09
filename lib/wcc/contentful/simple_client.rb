# frozen_string_literal: true

require 'http'

module WCC::Contentful
  class SimpleClient
    def self.cdn
    end

    def initialize(api_url:, space_id:, access_token:, **options)
      @api_url = URI.join(api_url, "/spaces/#{space_id}/")
      @space_id = space_id
      @access_token = access_token

      @get_http = options[:override_get_http] if options[:override_get_http].present?

      @options = options
    end

    def get(path, query = nil)
      url = URI.join(@api_url, path)

      Response.new(self,
        { url: url, query: query },
        get_http(url, query))
    end

    private

    def get_http(url, query, headers = {}, proxy = {})
      headers = {
        Authorization: "Bearer #{@access_token}"
      }.merge(headers || {})
      query = {
        locale: @options[:default_locale] || '*'
      }.merge(query || {})

      resp =
        if @get_http
          @get_http.call(url, query, headers, proxy)
        else
          default_get_http(url, query, headers, proxy)
        end
      if [301, 302, 307].include?(resp.code) && !@options[:no_follow_redirects]
        resp = get_http(resp.headers['location'], nil, headers, proxy)
      end
      resp
    end

    def default_get_http(url, query, headers = {}, proxy = {})
      if proxy[:host]
        HTTP[headers].via(proxy[:host], proxy[:port], proxy[:username], proxy[:password])
          .get(url, params: query)
      else
        HTTP[headers].get(url, params: query)
      end
    end

    class Response
      attr_reader :raw

      delegate :code, to: :raw
      delegate :headers, to: :raw

      def body
        @body ||= raw.body.to_s
      end

      def to_json
        @json ||= JSON.parse(body)
      end

      def initialize(client, request, raw_response)
        @client = client
        @request = request
        @raw = raw_response
        @body = raw.body.to_s
      end

      def assert_ok!
        return if code >= 200 && code < 300
        raise ApiError, "Error response from API: #{code}: #{raw.reason}\n#{body}"
      end

      def each_page
        raise ArgumentError, 'Not a collection response' unless to_json['items']

        pages = []
        current_page = self
        loop do
          pages << if block_given?
                     yield(current_page)
                   else
                     current_page
                   end

          skip_amt = current_page.to_json['items'].length + current_page.to_json['skip']
          break if current_page.to_json['items'].empty? || skip_amt >= current_page.to_json['total']

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
            page.to_json['items'].map { |i| yield(i) }
          end
        ret.flatten
      end

      def each(&block)
        map(&block)
        nil
      end
    end

    class ApiError < StandardError
    end
  end
end
