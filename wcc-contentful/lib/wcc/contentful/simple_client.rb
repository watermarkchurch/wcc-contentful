# frozen_string_literal: true

require_relative 'simple_client/response'
require_relative 'simple_client/management'
require_relative 'simple_client/cdn'
require_relative 'simple_client/preview'
require_relative 'instrumentation'

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
  # The SimpleClient by default uses 'faraday' to perform the gets, but any HTTP
  # client adapter be injected by passing the `connection:` option.
  #
  # @api Client
  class SimpleClient
    include WCC::Contentful::Instrumentation

    attr_reader :api_url, :space, :environment

    # Creates a new SimpleClient with the given configuration.
    #
    # @param [String] api_url the base URL of the Contentful API to connect to
    # @param [String] space The Space ID to access
    # @param [String] access_token A Contentful Access Token to be sent in the Authorization header
    # @param [Hash] options The remaining optional parameters, defined below
    # @option options [Symbol, Object] connection The Faraday connection to use to make requests.
    #   Auto-discovered based on what gems are installed if this is not provided.
    # @option options [String] environment The contentful environment to access. Defaults to 'master'.
    # @option options [Boolean] no_follow_redirects If true, do not follow 300 level redirects.
    # @option options [Number] rate_limit_wait_timeout The maximum time to block the thread waiting
    #   on a rate limit response.  By default will wait for one 429 and then fail on the second 429.
    def initialize(api_url:, space:, access_token:, **options)
      @api_url = URI.join(api_url, '/spaces/', "#{space}/")
      @space = space
      @access_token = access_token

      @adapter = SimpleClient.load_adapter(options[:connection])

      @options = options
      @_instrumentation = @options[:instrumentation]
      @query_defaults = {}
      # default 1.5 so that we retry one time then fail if still rate limited
      # https://www.contentful.com/developers/docs/references/content-preview-api/#/introduction/api-rate-limits
      @rate_limit_wait_timeout = @options[:rate_limit_wait_timeout] || 1.5

      @environment = options[:environment]
      return unless @environment.present?

      @api_url = URI.join(@api_url, 'environments/', "#{@environment}/")
    end

    # performs an HTTP GET request to the specified path within the configured
    # space and environment.  Query parameters are merged with the defaults and
    # appended to the request.
    def get(path, query = {})
      url = URI.join(@api_url, path)

      resp =
        _instrument 'get_http', url: url, query: query do
          get_http(url, query)
        end
      Response.new(self,
        { url: url, query: query },
        resp)
    end

    ADAPTERS = {
      faraday: ['faraday', '>= 0.9'],
      typhoeus: ['typhoeus', '~> 1.0']
    }.freeze

    def self.load_adapter(adapter)
      case adapter
      when nil
        ADAPTERS.each do |a, spec|
          gem(*spec)
          return load_adapter(a)
        rescue Gem::LoadError
          next
        end
        raise ArgumentError, 'Unable to load adapter!  Please install one of ' \
                             "#{ADAPTERS.values.map(&:join).join(',')}"
      when :faraday
        require 'faraday'
        ::Faraday.new do |faraday|
          faraday.response :logger, (Rails.logger if defined?(Rails)), { headers: false, bodies: false }
          faraday.adapter :net_http
        end
      when :typhoeus
        require_relative 'simple_client/typhoeus_adapter'
        TyphoeusAdapter.new
      else
        unless adapter.respond_to?(:get)
          raise ArgumentError, "Adapter #{adapter} is not invokeable!  Please " \
                               "pass use one of #{ADAPTERS.keys} or create a Faraday-compatible adapter"
        end
        adapter
      end
    end

    private

    def _instrumentation_event_prefix
      # Unify all CDN, Management, Preview notifications under same namespace
      '.simpleclient.contentful.wcc'
    end

    def get_http(url, query, headers = {})
      headers = {
        Authorization: "Bearer #{@access_token}"
      }.merge(headers || {})

      q = @query_defaults.dup
      q = q.merge(query) if query
      q.compact!

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      loop do
        resp = @adapter.get(url, q, headers)

        if [301, 302, 307].include?(resp.status) && !@options[:no_follow_redirects]
          url = resp.headers['Location']
          next
        end

        if resp.status == 429 &&
            reset = resp.headers['X-Contentful-RateLimit-Reset'].presence
          reset = reset.to_f
          _instrument 'rate_limit', start: start, reset: reset, timeout: @rate_limit_wait_timeout
          now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if (now - start) + reset < @rate_limit_wait_timeout
            sleep(reset)
            next
          end
        end

        return resp
      end
    end
  end
end
