# frozen_string_literal: true

require 'active_support/dependencies'
require_dependency WCC::Contentful::Engine.root.join('app/controllers/application_controller')

module WCC::Contentful
  class WebhookController < ApplicationController
    before_action :authorize_contentful

    def receive
      WCC::Contentful.sync!(params.dig('sys', 'id'))
    end

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

      return if request.content_type == 'application/vnd.contentful.management.v1+json'
      render json: { msg: 'This endpoint only responds to webhooks from Contentful' }, status: 406
    end
  end
end
