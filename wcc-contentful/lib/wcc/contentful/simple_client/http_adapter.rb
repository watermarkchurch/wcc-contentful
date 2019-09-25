# frozen_string_literal: true

gem 'http'
require 'http'

class WCC::Contentful::SimpleClient::HttpAdapter
  def get(url, params = {}, headers = {})
    req = OpenStruct.new(params: params, headers: headers)

    yield req if block_given?

    Response.new(
      HTTP[req.headers].get(url, params: req.params)
    )
  end

  def post(url, body, headers = {}, proxy = {})
    Response.new(
      if proxy[:host]
        HTTP[headers].via(proxy[:host], proxy[:port], proxy[:username], proxy[:password])
          .post(url, json: body)
      else
        HTTP[headers].post(url, json: body)
      end
    )
  end

  Response =
    Struct.new(:raw) do
      extend Forwardable

      def_delegators :raw, :body, :to_s, :status, :headers

      def status
        raw.code
      end
    end
end
