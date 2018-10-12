# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'

# require rails libraries:
#   railtie includes rails + framework middleware
#   active_job for any job specs
require 'action_controller/railtie'
require 'active_job'

# require rails specific code
require 'wcc/contentful/rails'

# require rspec-rails to simulate framework behavior in specs
require 'rspec/rails'

# require dummy rails app for engine related specs

WebMock.stub_request(:get, 'https://api.contentful.com/spaces/' \
    "#{ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'}/content_types")
  .with(query: WebMock::API.hash_including({ limit: '1000' }))
  .to_return(body: File.read(
    File.expand_path('fixtures/contentful/content_types_mgmt_api.json', __dir__)
  ))
require File.expand_path('dummy/config/environment.rb', __dir__)

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')