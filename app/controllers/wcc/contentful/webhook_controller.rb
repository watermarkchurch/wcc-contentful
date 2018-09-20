# frozen_string_literal: true

require_dependency 'wcc/contentful/application_controller'

module WCC::Contentful
  # The WebhookController is mounted by the WCC::Contentful::Engine to receive
  # webhook events from Contentful.  It passes these webhook events to
  # the jobs configured in {WCC::Contentful::Configuration WCC::Contentful::Configuration#webhook_jobs}
  class WebhookController < ApplicationController
    include WCC::Contentful::ServiceAccessors

    before_action :authorize_contentful
    protect_from_forgery unless: -> { request.format.json? }

    rescue_from ActionController::ParameterMissing do |_e|
      render json: { msg: 'The request must conform to Contentful webhook structure' }, status: 400
    end

    def receive
      event = params.require('webhook').permit!
      event.require('sys').require(%w[id type])
      event = event.to_h

      # Immediately update the store, we may update again later using DelayedSyncJob.
      store.index(event) if store.respond_to?(:index)

      jobs.each do |job|
        begin
          if job.respond_to?(:perform_later)
            job.perform_later(event)
          elsif job.respond_to?(:call)
            job.call(event)
          else
            Rails.logger.error "Misconfigured webhook job: #{job} does not respond to " \
              ':perform_later or :call'
          end
        rescue StandardError => e
          Rails.logger.error "Error in job #{job}: #{e}"
        end
      end
    end

    private

    def authorize_contentful
      config = WCC::Contentful.configuration

      if config.webhook_username.present? && config.webhook_password.present?
        unless authenticate_with_http_basic do |u, p|
                 u == config.webhook_username &&
                     p == config.webhook_password
               end
          request_http_basic_authentication
          return
        end
      end

      # 'application/vnd.contentful.management.v1+json' is an alias for the 'application/json'
      # content-type, so 'request.content_type' will give 'application/json'
      return if request.headers['Content-Type'] == 'application/vnd.contentful.management.v1+json'

      render json: { msg: 'This endpoint only responds to webhooks from Contentful' }, status: 406
    end

    def jobs
      jobs = [WCC::Contentful::DelayedSyncJob]
      jobs.push(*WCC::Contentful.configuration.webhook_jobs)
    end
  end
end
