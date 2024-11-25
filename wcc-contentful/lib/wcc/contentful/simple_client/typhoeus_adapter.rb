# frozen_string_literal: true

gem 'typhoeus'
require 'typhoeus'
require 'ostruct'

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

  def put(url, body, headers = {}, proxy = {})
    raise NotImplementedError, 'Proxying Not Yet Implemented' if proxy[:host]

    Response.new(
      Typhoeus.put(
        url,
        body: body.to_json,
        headers: headers
      )
    )
  end

  class Response < SimpleDelegator
    delegate :to_s, to: :body

    def raw
      __getobj__
    end

    def status
      code
    end
  end
end
