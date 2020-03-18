# frozen_string_literal: true

require 'spec_helper'

begin
  gem 'active_job'
  require 'active_job'
rescue Gem::LoadError
  # active_job is not loaded in this test run
  warn 'WARNING: Cannot load active_job - some tests will be skipped'
end

if defined?(ActiveJob)
  ActiveJob::Base.queue_adapter = :test
else
  RSpec.configure do |c|
    # skip job specs
    c.before(:each, type: :job) do
      skip 'active_job gem is not loaded'
    end

    c.before(:each, active_job: true) do
      skip 'active_job gem is not loaded'
    end
  end
end
