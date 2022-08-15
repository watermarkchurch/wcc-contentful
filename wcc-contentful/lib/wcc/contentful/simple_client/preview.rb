# frozen_string_literal: true

# @api Client
class WCC::Contentful::SimpleClient::Preview < WCC::Contentful::SimpleClient
  def initialize(space:, preview_token:, **options)
    super(
      **options,
      api_url: options[:preview_api_url] || 'https://preview.contentful.com/',
      space: space,
      access_token: preview_token
    )
  end

  def client_type
    'preview'
  end
end
