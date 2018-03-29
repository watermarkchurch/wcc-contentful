# frozen_string_literal: true

require 'http'

require_relative 'simple_client/response'

module WCC::Contentful
  ##
  # The SimpleClient accesses the Contentful CDN to get JSON responses,
  # returning the raw JSON data as a parsed hash.
  # It can be configured to access any API url and exposes only a single method,
  # `get`.  This method returns a WCC::Contentful::SimpleClient::Response
  # that handles paging automatically.
  #
  # The SimpleClient by default uses 'http' to perform the gets, but any HTTP
  # client can be injected by passing a proc as the `override_get_http:` option.
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

    ##
    # The CDN SimpleClient accesses 'https://cdn.contentful.com' to get raw
    # JSON responses.  It exposes methods to query entries, assets, and content_types.
    # The responses are instances of WCC::Contentful::SimpleClient::Response
    # which handles paging automatically.
    class Cdn < SimpleClient
      def initialize(space:, access_token:, **options)
        super(
          api_url: options[:api_url] || 'https://cdn.contentful.com/',
          space: space,
          access_token: access_token,
          **options
        )
      end

      ##
      # Gets an entry by ID
      def entry(key, query = {})
        resp = get("entries/#{key}", query)
        resp.assert_ok!
      end

      ##
      # Queries entries with optional query parameters
      def entries(query = {})
        resp = get('entries', query)
        resp.assert_ok!
      end

      ##
      # Gets an asset by ID
      def asset(key, query = {})
        resp = get("assets/#{key}", query)
        resp.assert_ok!
      end

      ##
      # Queries assets with optional query parameters
      def assets(query = {})
        resp = get('assets', query)
        resp.assert_ok!
      end

      ##
      # Queries content types with optional query parameters
      def content_types(query = {})
        resp = get('content_types', query)
        resp.assert_ok!
      end

      ##
      # Accesses the Sync API to get a list of items that have changed since
      # the last sync.
      #
      # If `sync_token` is nil, an initial sync is performed.
      # Returns a WCC::Contentful::SimpleClient::SyncResponse
      # which handles paging automatically.
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
