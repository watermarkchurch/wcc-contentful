# frozen_string_literal: true

module WCC::Contentful::App
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
  end
end
