# frozen_string_literal: true

module WCC::Contentful::App
  class Engine < ::Rails::Engine
    isolate_namespace WCC::Contentful::App

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end
  end
end