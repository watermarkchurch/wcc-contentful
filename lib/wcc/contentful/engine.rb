# frozen_string_literal: true

require 'wcc/rails'

module WCC::Contentful
  class Engine < ::Rails::Engine
    isolate_namespace WCC::Contentful

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end
  end
end
