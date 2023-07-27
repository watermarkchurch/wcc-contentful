# frozen_string_literal: true

module WCC::Contentful::App
  class Engine < ::Rails::Engine
    if config.try(:assets)
      config.assets.precompile += %w[*.jpg *.png *.svg]
      config.assets.precompile +=
        [
          'config/manifest.js'
        ].map { |f| File.expand_path("../../../../../app/assets/#{f}", __FILE__) }
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end
  end
end
