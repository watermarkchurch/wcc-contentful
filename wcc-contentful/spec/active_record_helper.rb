# frozen_string_literal: true

require 'spec_helper'

begin
  gem 'active_record'
  require 'active_record'
rescue Gem::LoadError
  # active_record is not loaded in this test run
  warn 'WARNING: Cannot load active_record - some tests will be skipped'
end

if defined?(ActiveJob)
  ActiveJob::Base.queue_adapter = :test
else
  RSpec.configure do |c|
    # skip active record based specs
    c.before(:each, active_record: true) do
      skip 'rails is not loaded'
    end
  end
end
