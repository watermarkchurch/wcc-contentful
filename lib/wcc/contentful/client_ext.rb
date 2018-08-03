# frozen_string_literal: true

class Contentful::Client
  class << self
    alias_method :old_get_http, :get_http
  end

  def self.get_http(url, query, headers = {}, proxy = {})
    if override = WCC::Contentful::SimpleClient.load_adapter(WCC::Contentful.configuration.http_adapter)
      override.call(url, query, headers, proxy)
    else
      old_get_http(url, query, headers, proxy)
    end
  end
end
