# frozen_string_literal: true

require 'active_job'

module WCC::Contentful
  class DelayedSyncJob < ActiveJob::Base
    queue_as :default

    def perform(*args)
      sync_options = args.first || {}
      WCC::Contentful.sync!(**sync_options)
    end
  end
end
