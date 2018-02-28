# frozen_string_literal: true

require 'spec_helper'

ENV['RAILS_ENV'] ||= 'test'

require 'action_controller/railtie'
require 'rspec/rails'

# rubocop:disable Style/ClassAndModuleChildren
module FakeApp
  class Application < Rails::Application
  end
end
# rubocop:enable Style/ClassAndModuleChildren
