# frozen_string_literal: true

require 'spec_helper'
require 'wcc/contentful/link_visitor'

begin
  gem 'rails'
  require 'rails'
rescue Gem::LoadError => e
  warn "WARNING: Cannot load rails - some tests will be skipped\n#{e}"
end

if defined?(Rails)
  ENV['RAILS_ENV'] ||= 'test'

  # require rails libraries:
  #   railtie includes rails + framework middleware
  #   active_job for any job specs
  require 'action_controller/railtie'
  require 'active_job'

  # require rails specific code
  require 'wcc/contentful/rails'

  # require dummy rails app for engine related specs
  VCR.use_cassette('models/wcc_contentful/content_types/init_mgmt_api', record: :none) do
    require File.expand_path('dummy/config/environment.rb', __dir__)
  end

  # require rspec-rails to simulate framework behavior in specs
  require 'rspec/rails'

  WCC::Contentful::WebhookEnableJob.queue_adapter = :test

  ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

  # Hack to debug autoloading issues
  # https://makandracards.com/makandra/48754-how-to-debug-rails-autoloading
  ActiveSupport::Dependencies.singleton_class.prepend(Module.new do
    def load_missing_constant(*args)
      Rails.logger.debug "#{__method__}(#{args.map(&:inspect).join(', ')})"
      super
    end

    def search_for_file(*args)
      Rails.logger.debug "#{__method__}(#{args.map(&:inspect).join(', ')})"
      Rails.logger.debug "  searching in paths #{autoload_paths}"
      super
    end
  end)

  RSpec.configure do |c|
    # skip rspec-rails spec types
    c.before(:each, rails: false) do
      skip 'This test is for a non-rails context'
    end
  end
else
  RSpec.configure do |c|
    # skip rspec-rails spec types
    c.before(:each, rails: true) do
      skip 'rails is not loaded'
    end
  end
end
