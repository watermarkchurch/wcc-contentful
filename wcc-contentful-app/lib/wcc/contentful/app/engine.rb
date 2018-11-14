# frozen_string_literal: true

module WCC::Contentful::App
  class Engine < ::Rails::Engine
    initializer 'WCC::Contentful::App::Engine.assets' do |app|
      app.config.assets.precompile += %w[*.jpg *.png *.svg]
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end
  end
end
