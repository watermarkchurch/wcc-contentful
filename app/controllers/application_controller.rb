# frozen_string_literal: true

Mime::Type.register 'application/vnd.contentful.management.v1+json', :json

module WCC::Contentful
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
  end
end
