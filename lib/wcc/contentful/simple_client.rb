# frozen_string_literal: true

require 'http'

require_relative 'simple_client_response'

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

      def assets(query = {})
        resp = get('assets', query)
        resp.assert_ok!
      end

      def content_types(query = {})
        resp = get('content_types', query)
        resp.assert_ok!
      end

      def sync(sync_token: nil, **query)
        sync_token =
          if sync_token
            { sync_token: sync_token }
          else
            { initial: true }
          end
        query = query.merge(sync_token)
        resp = SyncResponse.new(get('sync', query))
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
        space ||= @space
        raise ArgumentError, 'please provide a space ID' if space.nil?

        resp = get("/spaces/#{space}/content_types", query)
        resp.assert_ok!
      end
    end
  end
end
