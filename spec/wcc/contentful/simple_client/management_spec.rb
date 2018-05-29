

# frozen_string_literal: true

RSpec.describe WCC::Contentful::SimpleClient::Management do
  describe 'content_types' do
    it 'uses environment' do
      client = WCC::Contentful::SimpleClient::Management.new(
        management_token: 'testtoken',
        space: 'testspace',
        environment: 'testenv'
      )

      stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/content_types?limit=1000')
        .with(headers: { Authorization: 'Bearer testtoken' })
        .to_return(body: '{ "skip": 0, "total": 0, "items": [] }')

      # act
      resp = client.content_types(limit: 1000)

      # assert
      resp.assert_ok!
      expect(resp.items.force).to eq([])
    end
  end

  describe 'webhook_definitions' do
    it 'gets webhook definitions from space root' do
      client = WCC::Contentful::SimpleClient::Management.new(
        management_token: 'testtoken',
        space: 'testspace',
        environment: 'testenv'
      )

      stub_request(:get, 'https://api.contentful.com/spaces/testspace/webhook_definitions?limit=25')
        .with(headers: { Authorization: 'Bearer testtoken' })
        .to_return(body: '{
          "total":1,
          "limit":25,
          "skip":0,
          "sys":{
            "type":"Array"
          },
          "items":[
            {
              "url":"https://www.example.com/test",
              "sys":{
                "type":"WebhookDefinition",
                "id":"5GvfGrfrshJT6g0kZIvph8"
              }
            }
          ]
        }')

      # act
      resp = client.webhook_definitions(limit: 25)

      # assert
      resp.assert_ok!
      expect(resp.items.force).to eq([{
        'url' => 'https://www.example.com/test',
        'sys' => { 'type' => 'WebhookDefinition', 'id' => '5GvfGrfrshJT6g0kZIvph8' }
      }])
    end

    it 'posts a new definition to space root' do
      client = WCC::Contentful::SimpleClient::Management.new(
        management_token: 'testtoken',
        space: 'testspace',
        environment: 'testenv'
      )

      stub_request(:post, 'https://api.contentful.com/spaces/testspace/webhook_definitions')
        .with(headers: {
          Authorization: 'Bearer testtoken',
          'Content-Type' => 'application/vnd.contentful.management.v1+json'
        })
        .to_return(body: '{
              "url":"https://www.example.com/test",
              "sys":{
                "type":"WebhookDefinition",
                "id":"5GvfGrfrshJT6g0kZIvph8"
              }
            }')

      # act
      resp = client.post_webhook_definition('test' => 'body')

      # assert
      resp.assert_ok!
      expect(resp.raw).to eq({
        'url' => 'https://www.example.com/test',
        'sys' => { 'type' => 'WebhookDefinition', 'id' => '5GvfGrfrshJT6g0kZIvph8' }
      })
    end
  end
end
