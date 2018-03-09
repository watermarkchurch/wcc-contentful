# frozen_string_literal: true

require 'http'

module WCC::Contentful
  class SimpleClient
    def initialize(api_url:, space:, access_token:, **options)
      @api_url = URI.join(api_url, '/spaces/', space + '/')
      @space = space
      @access_token = access_token

      @get_http = options[:override_get_http] if options[:override_get_http].present?

      @options = options
      @query_defaults = {}
      @query_defaults[:locale] = @options[:default_locale] if @options[:default_locale]
    end

    def get(path, query = {})
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

      q = @query_defaults.dup
      q = q.merge(query) if query

      resp =
        if @get_http
          @get_http.call(url, q, headers, proxy)
        else
          default_get_http(url, q, headers, proxy)
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
      attr_reader :raw_response

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

      def each(&block)
        map(&block)
        nil
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

    class ApiError < StandardError
      attr_reader :response

      def initialize(response)
        @response = response
        super(response.error_message)
      end
    end

    class Cdn < SimpleClient
      def initialize(space:, access_token:, **options)
        super(
          api_url: options[:api_url] || 'https://cdn.contentful.com/',
          space: space,
          access_token: access_token,
          **options
        )
      end

      def entry(key, query = {})
        resp = get("entries/#{key}", query)
        resp.assert_ok!
      end

      def entries(query = {})
        resp = get('entries', query)
        resp.assert_ok!
      end

      def asset(key, query = {})
        resp = get("assets/#{key}", query)
        resp.assert_ok!
      end
    end

    class Management < SimpleClient
      def initialize(management_token:, **options)
        super(
          api_url: options[:api_url] || 'https://api.contentful.com',
          space: options[:space] || '/',
          access_token: management_token,
          **options
        )
      end

      def content_types(space: nil, **query)
        puts "options: #{@options}"
        space ||= @space
        raise ArgumentError, 'please provide a space ID' if space.nil?

        resp = get("/spaces/#{space}/content_types", query)
        resp.assert_ok!
      end
    end
  end
end
