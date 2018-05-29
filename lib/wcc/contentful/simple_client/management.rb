

# frozen_string_literal: true

class WCC::Contentful::SimpleClient::Management < WCC::Contentful::SimpleClient
  def initialize(space:, management_token:, **options)
    super(
      api_url: options[:api_url] || 'https://api.contentful.com',
      space: space,
      access_token: management_token,
      **options
    )
  end

  def client_type
    'management'
  end

  def content_types(**query)
    resp = get('content_types', query)
    resp.assert_ok!
  end
end
