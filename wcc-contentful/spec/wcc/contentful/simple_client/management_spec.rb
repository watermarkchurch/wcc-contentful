# frozen_string_literal: true

RSpec.describe WCC::Contentful::SimpleClient::Management do
  WCC::Contentful::SimpleClient::ADAPTERS.keys.each do |adapter|
    context "with #{adapter} adapter" do
      let(:client) {
        WCC::Contentful::SimpleClient::Management.new(
          management_token: 'testtoken',
          space: 'testspace',
          environment: 'testenv',
          connection: adapter
        )
      }
      describe '#content_types' do
        it 'uses environment' do
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

      describe '#content_type' do
        it 'uses environment' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/content_types/test1234')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(body: <<~HEREDOC)
              {
                "sys": {
                  "space": {
                    "sys": {
                      "type": "Link",
                      "linkType": "Space",
                      "id": "testspace"
                    }
                  },
                  "id": "test1234",
                  "type": "ContentType",
                  "createdAt": "2018-02-12T19:47:57.690Z",
                  "updatedAt": "2018-02-12T19:47:57.856Z"
                },
                "displayField": "name",
                "name": "Test Content Type",
                "description": "test test test",
                "fields": [
                  {
                    "id": "name",
                    "name": "Name",
                    "type": "Symbol",
                    "localized": false,
                    "required": true,
                    "validations": [],
                    "disabled": false,
                    "omitted": false
                  }
                ]
              }
            HEREDOC

          # act
          resp = client.content_type('test1234')

          # assert
          resp.assert_ok!
          expect(resp.raw.dig('sys', 'id')).to eq('test1234')
          expect(resp.raw.dig('fields', 0, 'id')).to eq('name')
        end

        it 'raises error on 404' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/content_types/test1234')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(status: 404, body: '')

          # act
          expect {
            client.content_type('test1234')
          }.to raise_error(WCC::Contentful::SimpleClient::NotFoundError)
        end
      end

      describe 'webhook_definitions' do
        it 'gets webhook definitions from space root' do
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

        it 'never retries a webhook post on 429' do
          stub_request(:post, 'https://api.contentful.com/spaces/testspace/webhook_definitions')
            .to_return(status: 429,
                       headers: {
                         'X-Contentful-RateLimit-Reset': 1
                       })
            .then
            .to_raise(StandardError, 'Should have bailed!')

          # act
          expect {
            client.post_webhook_definition('test' => 'body')
          }.to raise_error(WCC::Contentful::SimpleClient::RateLimitError)
        end
      end
    end
  end
end
