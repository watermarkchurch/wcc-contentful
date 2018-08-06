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
    adapter.call(url, query, headers, proxy)
  end
end
