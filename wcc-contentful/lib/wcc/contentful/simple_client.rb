# frozen_string_literal: true

require_relative 'simple_client/response'
require_relative 'simple_client/management'

module WCC::Contentful
  # The SimpleClient accesses the Contentful CDN to get JSON responses,
  # returning the raw JSON data as a parsed hash.  This is the bottom layer of
  # the WCC::Contentful gem.
  #
  # Note: Do not create this directly, instead create one of
  # WCC::Contentful::SimpleClient::Cdn, WCC::Contentful::SimpleClient::Preview,
  # WCC::Contentful::SimpleClient::Management
  #
  # It can be configured to access any API url and exposes only a single method,
  # `get`.  This method returns a WCC::Contentful::SimpleClient::Response
  # that handles paging automatically.
  #
  # The SimpleClient by default uses 'http' to perform the gets, but any HTTP
  # client can be injected by passing a proc as the `adapter:` option.
  #
  # @api Client
  class SimpleClient
    attr_reader :api_url
    attr_reader :space

    # Creates a new SimpleClient with the given configuration.
    #
    # @param [String] api_url the base URL of the Contentful API to connect to
    # @param [String] space The Space ID to access
    # @param [String] access_token A Contentful Access Token to be sent in the Authorization header
    # @param [Hash] options The remaining optional parameters, defined below
    # @option options [Symbol, Object] adapter The Adapter to use to make requests.
    #   Auto-discovered based on what gems are installed if this is not provided.
    # @option options [String] default_locale The locale query param to set by default.
    # @option options [String] environment The contentful environment to access. Defaults to 'master'.
    # @option options [Boolean] no_follow_redirects If true, do not follow 300 level redirects.
    def initialize(api_url:, space:, access_token:, **options)
      @api_url = URI.join(api_url, '/spaces/', space + '/')
      @space = space
      @access_token = access_token

      @adapter = SimpleClient.load_adapter(options[:adapter])

      @options = options
      @query_defaults = {}
      @query_defaults[:locale] = @options[:default_locale] if @options[:default_locale]

      return unless options[:environment].present?

      @api_url = URI.join(@api_url, 'environments/', options[:environment] + '/')
    end

    # performs an HTTP GET request to the specified path within the configured
    # space and environment.  Query parameters are merged with the defaults and
    # appended to the request.
    def get(path, query = {})
      url = URI.join(@api_url, path)

      Response.new(self,
        { url: url, query: query },
        get_http(url, query))
    end

    ADAPTERS = {
      faraday: ['faraday', '~> 0.9'],
      http: ['http', '> 1.0', '< 3.0'],
      typhoeus: ['typhoeus', '~> 1.0']
    }.freeze

    def self.load_adapter(adapter)
      case adapter
      when nil
        ADAPTERS.each do |a, spec|
          begin
            gem(*spec)
            return load_adapter(a)
          rescue Gem::LoadError
            next
          end
        end
        raise ArgumentError, 'Unable to load adapter!  Please install one of '\
          "#{ADAPTERS.values.map(&:join).join(',')}"
      when :faraday
        require 'faraday'
        ::Faraday.new do |faraday|
          faraday.response :logger, (Rails.logger if defined?(Rails)), { headers: false, bodies: false }
          faraday.adapter :net_http
        end
      when :http
        require_relative 'simple_client/http_adapter'
        HttpAdapter.new
      when :typhoeus
        require_relative 'simple_client/typhoeus_adapter'
        TyphoeusAdapter.new
      else
        unless adapter.respond_to?(:get)
          raise ArgumentError, "Adapter #{adapter} is not invokeable!  Please "\
            "pass use one of #{ADAPTERS.keys} or create a Faraday-compatible adapter"
        end
        adapter
      end
    end

    private

    def get_http(url, query, headers = {}, proxy = {})
      headers = {
        Authorization: "Bearer #{@access_token}"
      }.merge(headers || {})

      q = @query_defaults.dup
      q = q.merge(query) if query

      resp = @adapter.get(url, q, headers)

      if [301, 302, 307].include?(resp.status) && !@options[:no_follow_redirects]
        resp = get_http(resp.headers['location'], nil, headers, proxy)
      end
      resp
    end

    # The CDN SimpleClient accesses 'https://cdn.contentful.com' to get raw
    # JSON responses.  It exposes methods to query entries, assets, and content_types.
    # The responses are instances of WCC::Contentful::SimpleClient::Response
    # which handles paging automatically.
    #
    # @api Client
    class Cdn < SimpleClient
      def initialize(space:, access_token:, **options)
        super(
          api_url: options[:api_url] || 'https://cdn.contentful.com/',
          space: space,
          access_token: access_token,
          **options
        )
      end

      def client_type
        'cdn'
      end

      # Gets an entry by ID
      def entry(key, query = {})
        resp = get("entries/#{key}", query)
        resp.assert_ok!
      end

      # Queries entries with optional query parameters
      def entries(query = {})
        resp = get('entries', query)
        resp.assert_ok!
      end

      # Gets an asset by ID
      def asset(key, query = {})
        resp = get("assets/#{key}", query)
        resp.assert_ok!
      end

      # Queries assets with optional query parameters
      def assets(query = {})
        resp = get('assets', query)
        resp.assert_ok!
      end

      # Queries content types with optional query parameters
      def content_types(query = {})
        resp = get('content_types', query)
        resp.assert_ok!
      end

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

    # @api Client
    class Preview < Cdn
      def initialize(space:, preview_token:, **options)
        super(
          api_url: options[:api_url] || 'https://preview.contentful.com/',
          space: space,
          access_token: preview_token,
          **options
        )
      end

      def client_type
        'preview'
      end
    end
  end
end
