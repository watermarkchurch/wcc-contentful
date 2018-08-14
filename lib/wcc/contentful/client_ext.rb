# frozen_string_literal: true

class Contentful::Client
  class << self
    alias_method :old_get_http, :get_http
  end

  def self.adapter
    @adapter ||=
      WCC::Contentful::SimpleClient.load_adapter(WCC::Contentful.configuration.http_adapter) ||
      ->(url, query, headers, proxy) { old_get_http(url, query, headers, proxy) }
  end

  def self.get_http(url, query, headers = {}, proxy = {})
    if environment = WCC::Contentful.configuration.environment
      url = rewrite_to_environment(url, environment)
    end

    adapter.call(url, query, headers, proxy)
  end

  REWRITE_REGEXP = /^(https?\:\/\/(?:\w+)\.contentful\.com\/spaces\/[^\/]+\/)(?!environments)(.+)$/
  def self.rewrite_to_environment(url, environment)
    return url unless m = REWRITE_REGEXP.match(url)
    File.join(m[1], 'environments', environment, m[2])
  end
end
