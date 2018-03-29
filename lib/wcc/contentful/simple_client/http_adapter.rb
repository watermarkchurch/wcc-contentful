# frozen_string_literal: true

gem 'http'
require 'http'

class HttpAdapter
  def call(url, query, headers = {}, proxy = {})
    if proxy[:host]
      HTTP[headers].via(proxy[:host], proxy[:port], proxy[:username], proxy[:password])
        .get(url, params: query)
    else
      HTTP[headers].get(url, params: query)
    end
  end
end
