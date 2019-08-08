# frozen_string_literal: true

require_dependency 'wcc/contentful/application_controller'

module WCC::Contentful
  # The WebhookController is mounted by the WCC::Contentful::Engine to receive
  # webhook events from Contentful.  It passes these webhook events to
  # the jobs configured in {WCC::Contentful::Configuration WCC::Contentful::Configuration#webhook_jobs}
  class WebhookController < ApplicationController
    include WCC::Contentful::ServiceAccessors
    include Wisper::Publisher

    before_action :authorize_contentful
    protect_from_forgery unless: -> { request.format.json? }

    rescue_from ActionController::ParameterMissing do |_e|
      render json: { msg: 'The request must conform to Contentful webhook structure' }, status: 400
    end

    def receive
      params.require('sys').require(%w[id type])
      params.permit('sys', 'fields')
      event = params.slice('sys', 'fields').permit!.to_h

      return unless check_environment(event)

      # Immediately update the store, we may update again later using SyncEngine::Job.
      store.index(event) if store.index?

      event = WCC::Contentful::Event.from_raw(event, source: self)
      emit_event(event)
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

    def check_environment(event)
      environment_id = event.dig('sys', 'environment', 'sys', 'id')
      return true unless environment_id.present?

      configured_environment = WCC::Contentful.configuration.environment.presence || 'master'
      configured_environment.casecmp(environment_id) == 0
    end

    def emit_event(event)
      type = event.dig('sys', 'type')
      raise ArgumentError, "Unknown event type #{event}" unless type.present?

      broadcast(type, event)
    end
  end
end
