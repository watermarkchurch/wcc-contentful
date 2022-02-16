# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'

# require dummy rails app for engine related specs
# require rails specific code
require 'rails/all'
require 'wcc/contentful/app/rails'

WebMock.stub_request(:get, 'https://api.contentful.com/spaces/' \
    "#{ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'}/content_types")
  .with(query: WebMock::API.hash_including({ limit: '1000' }))
  .to_return(body: File.read(
    File.expand_path('fixtures/contentful/content_types_mgmt_api.json', __dir__)
  ))
require File.expand_path('dummy/config/environment.rb', __dir__)

# require rspec-rails to simulate framework behavior in specs
require 'rails-controller-testing'
require 'rspec/rails'
require 'capybara/rspec'
require 'capybara/rails'

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

RSpec.configure do |config|
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.use_transactional_fixtures = true

  config.before(:each) do
    WCC::Contentful::Model.instance_variable_get('@registry').clear
    Wisper.clear
    WCC::Contentful.instance_variable_set('@configuration', nil)
    WCC::Contentful.instance_variable_set('@initialized', nil)
  end
end
