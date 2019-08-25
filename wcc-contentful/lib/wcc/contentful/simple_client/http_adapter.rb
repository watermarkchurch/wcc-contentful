# typed: true
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

  def post(url, body, headers = {}, proxy = {})
    if proxy[:host]
      HTTP[headers].via(proxy[:host], proxy[:port], proxy[:username], proxy[:password])
        .post(url, json: body)
    else
      HTTP[headers].post(url, json: body)
    end
  end
end
