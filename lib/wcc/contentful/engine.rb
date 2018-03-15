# frozen_string_literal: true

module WCC::Contentful
  class Engine < ::Rails::Engine
    isolate_namespace WCC::Contentful

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end
  end
end

# TODO: figure out why autoloading isn't working
require WCC::Contentful::Engine.root.join('app/controllers/wcc/contentful/webhook_controller')
require WCC::Contentful::Engine.root.join('config/routes.rb')
