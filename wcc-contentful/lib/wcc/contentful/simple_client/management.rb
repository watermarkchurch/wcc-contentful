# frozen_string_literal: true

# @api Client
class WCC::Contentful::SimpleClient::Management < WCC::Contentful::SimpleClient
  def initialize(space:, management_token:, **options)
    super(
      **options,
      api_url: options[:management_api_url] || 'https://api.contentful.com',
      space: space,
      access_token: management_token,
    )

    @post_adapter = @adapter if @adapter.respond_to?(:post)
    @post_adapter ||= self.class.load_adapter(nil)
  end

  def client_type
    'management'
  end

  def content_types(**query)
    resp =
      _instrument 'content_types', query: query do
        get('content_types', query)
      end
    resp.assert_ok!
  end

  def content_type(key, query = {})
    resp =
      _instrument 'content_types', content_type: key, query: query do
        get("content_types/#{key}", query)
      end
    resp.assert_ok!
  end

  def locales(**query)
    resp =
      _instrument 'locales', query: query do
        get('locales', query)
      end
    resp.assert_ok!
  end

  def locale(key, query = {})
    resp =
      _instrument 'locales', content_type: key, query: query do
        get("locales/#{key}", query)
      end
    resp.assert_ok!
  end

  def editor_interface(content_type_id, query = {})
    resp =
      _instrument 'editor_interfaces', content_type: content_type_id, query: query do
        get("content_types/#{content_type_id}/editor_interface", query)
      end
    resp.assert_ok!
  end

  def webhook_definitions(**query)
    resp =
      _instrument 'webhook_definitions', query: query do
        get("/spaces/#{space}/webhook_definitions", query)
      end
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
    resp =
      _instrument 'post.webhook_definitions' do
        post("/spaces/#{space}/webhook_definitions", webhook)
      end
    resp.assert_ok!
  end

  def post(path, body)
    url = URI.join(@api_url, path)

    resp =
      _instrument 'post_http', url: url do
        post_http(url, body)
      end

    Response.new(self,
      { url: url, body: body },
      resp)
  end

  private

  def post_http(url, body, headers = {})
    headers = {
      Authorization: "Bearer #{@access_token}",
      'Content-Type' => 'application/vnd.contentful.management.v1+json'
    }.merge(headers || {})

    body = body.to_json unless body.is_a? String
    resp = @post_adapter.post(url, body, headers)

    if [301, 302, 307].include?(resp.status) && !@options[:no_follow_redirects]
      resp = get_http(resp.headers['location'], nil, headers)
    elsif resp.status == 308 && !@options[:no_follow_redirects]
      resp = post_http(resp.headers['location'], body, headers)
    end
    resp
  end
end
