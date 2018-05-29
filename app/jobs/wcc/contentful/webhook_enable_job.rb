# frozen_string_literal: true

require 'active_job'

module WCC::Contentful
  class WebhookEnableJob < ActiveJob::Base
    self.queue_adapter = :async
    queue_as :default

    def perform(args)
      client = WCC::Contentful::SimpleClient::Management.new(
        **args
      )
    end
  end
end
