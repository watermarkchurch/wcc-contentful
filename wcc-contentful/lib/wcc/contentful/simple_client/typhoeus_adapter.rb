# frozen_string_literal: true

gem 'typhoeus'
require 'typhoeus'

class WCC::Contentful::SimpleClient::TyphoeusAdapter
  def get(url, params = {}, headers = {})
    req = OpenStruct.new(params: params, headers: headers)
    yield req if block_given?
    Response.new(
      Typhoeus.get(
        url,
        params: req.params,
        headers: req.headers
      )
    )
  end

  def post(url, body, headers = {}, proxy = {})
    raise NotImplementedError, 'Proxying Not Yet Implemented' if proxy[:host]

    Response.new(
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
