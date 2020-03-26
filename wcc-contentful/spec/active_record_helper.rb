# frozen_string_literal: true

require 'spec_helper'

begin
  gem 'activerecord'
  require 'active_record'
rescue Gem::LoadError => e
  # active_record is not loaded in this test run
  warn "WARNING: Cannot load active_record - some tests will be skipped\n#{e}"
end

if defined?(ActiveJob)
  ActiveJob::Base.queue_adapter = :test
else
  RSpec.configure do |c|
    # skip active record based specs
    c.before(:each, active_record: true) do
      skip 'activerecord is not loaded'
    end
  end
end
