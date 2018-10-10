# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'

# require rails libraries:
#   railtie includes rails + framework middleware
#   active_job for any job specs
require 'action_controller/railtie'
require 'active_job'

# require rspec-rails to simulate framework behavior in specs
require 'rspec/rails'

# require dummy rails app for engine related specs
require File.expand_path('dummy/config/environment.rb', __dir__)
