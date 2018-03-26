# frozen_string_literal: true

gem 'typhoeus'
require 'typhoeus'

class TyphoeusAdapter
  def call(url, query, headers = {}, proxy = {})
    raise NotImplementedError, 'Proxying Not Yet Implemented' if proxy[:host]

    TyphoeusAdapter::Response.new(
      Typhoeus.get(
        url,
        params: query,
        headers: headers
      )
    )
  end

  class Response
    delegate :body, to: :@raw
    delegate :to_s, to: :body
    delegate :code, to: :@raw
    delegate :headers, to: :@raw

    def status
      @raw.code
    end

    def initialize(response)
      @raw = response
    end
  end
end
