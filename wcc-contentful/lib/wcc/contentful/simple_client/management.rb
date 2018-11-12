# frozen_string_literal: true

# @api Client
class WCC::Contentful::SimpleClient::Management < WCC::Contentful::SimpleClient
  def initialize(space:, management_token:, **options)
    super(
      api_url: options[:api_url] || 'https://api.contentful.com',
      space: space,
      access_token: management_token,
      **options
    )

    @post_adapter = @adapter if @adapter.respond_to?(:post)
    @post_adapter ||= self.class.load_adapter(nil)
  end

  def client_type
    'management'
  end

  def content_types(**query)
    resp = get('content_types', query)
    resp.assert_ok!
  end

  def content_type(key, query = {})
    resp = get("content_types/#{key}", query)
    resp.assert_ok!
  end

  def editor_interface(content_type_id, query = {})
    resp = get("content_types/#{content_type_id}/editor_interface", query)
    resp.assert_ok!
  end

  def webhook_definitions(**query)
    resp = get("/spaces/#{space}/webhook_definitions", query)
    resp.assert_ok!
  end

  # {
  #   "name": "My webhook",
  #   "url": "https://www.example.com/test",
  #   "topics": [
  #     "Entry.create",
  #     "ContentType.create",
  #     "*.publish",
  #     "Asset.*"
  #   ],
  #   "httpBasicUsername": "yolo",
  #   "httpBasicPassword": "yolo",
  #   "headers": [
  #     {
  #       "key": "header1",
  #       "value": "value1"
  #     },
  #     {
  #       "key": "header2",
  #       "value": "value2"
  #     }
  #   ]
  # }
  def post_webhook_definition(webhook)
    resp = post("/spaces/#{space}/webhook_definitions", webhook)
    resp.assert_ok!
  end

  def post(path, body)
    url = URI.join(@api_url, path)

    Response.new(self,
      { url: url, body: body },
      post_http(url, body))
  end

  private

  def post_http(url, body, headers = {}, proxy = {})
    headers = {
      Authorization: "Bearer #{@access_token}",
      'Content-Type' => 'application/vnd.contentful.management.v1+json'
    }.merge(headers || {})

    resp = @post_adapter.post(url, body, headers, proxy)

    if [301, 302, 307].include?(resp.code) && !@options[:no_follow_redirects]
      resp = get_http(resp.headers['location'], nil, headers, proxy)
    end
    resp
  end
end
