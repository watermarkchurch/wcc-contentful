# typed: false
# frozen_string_literal: true

module WCC::Contentful
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
  end
end
