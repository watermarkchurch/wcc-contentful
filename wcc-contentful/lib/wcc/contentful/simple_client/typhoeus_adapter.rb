# typed: true
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

  def post(url, body, headers = {}, proxy = {})
    raise NotImplementedError, 'Proxying Not Yet Implemented' if proxy[:host]

    TyphoeusAdapter::Response.new(
      Typhoeus.post(
        url,
        body: body.to_json,
        headers: headers
      )
    )
  end

  Response =
    Struct.new(:raw) do
      delegate :body, to: :raw
      delegate :to_s, to: :body
      delegate :code, to: :raw
      delegate :headers, to: :raw

      def status
        raw.code
      end
    end
end
