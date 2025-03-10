# frozen_string_literal: true

RSpec.describe WCC::Contentful::SimpleClient::Management do
  WCC::Contentful::SimpleClient::ADAPTERS.each_key do |adapter|
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

        it 'notifies' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/content_types?limit=1000')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(body: '{ "skip": 0, "total": 0, "items": [] }')

          expect {
            client.content_types(limit: 1000)
          }.to instrument('get_http.simpleclient.contentful.wcc')

          expect {
            client.content_types(limit: 1000)
          }.to instrument('content_types.simpleclient.contentful.wcc')
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

      describe '#locales' do
        it 'uses environment' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/locales?limit=1000')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(body: load_fixture('contentful/simple_client/locales.json'))

          # act
          resp = client.locales(limit: 1000)

          # assert
          resp.assert_ok!
          items = resp.items.force
          expect(items.count).to eq(2)
          expect(items.dig(0, 'code')).to eq('en-US')
          expect(items.dig(1, 'name')).to eq('Spanish (United States)')
        end

        it 'notifies' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/locales?limit=1000')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(body: '{ "skip": 0, "total": 0, "items": [] }')

          expect {
            client.locales(limit: 1000)
          }.to instrument('get_http.simpleclient.contentful.wcc')

          expect {
            client.locales(limit: 1000)
          }.to instrument('locales.simpleclient.contentful.wcc')
        end
      end

      describe '#locale' do
        it 'uses environment' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/locales/6gf9SW2So4IhpW8SGzoHeW')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(body: <<~JSON)
              {
                "name": "Spanish (United States)",
                "internal_code": "es-US",
                "code": "es-US",
                "fallbackCode": "en-US",
                "default": false,
                "contentManagementApi": true,
                "contentDeliveryApi": true,
                "optional": true,
                "sys": {
                  "type": "Locale",
                  "id": "6gf9SW2So4IhpW8SGzoHeW"
                }
              }
            JSON

          # act
          resp = client.locale('6gf9SW2So4IhpW8SGzoHeW')

          # assert
          resp.assert_ok!
          expect(resp.raw.dig('sys', 'id')).to eq('6gf9SW2So4IhpW8SGzoHeW')
          expect(resp.raw['code']).to eq('es-US')
        end

        it 'raises error on 404' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/locales/test1234')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(status: 404, body: '')

          # act
          expect {
            client.locale('test1234')
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
          expect(resp.items.force).to eq([
                                           {
                                             'url' => 'https://www.example.com/test',
                                             'sys' => {
                                               'type' => 'WebhookDefinition',
                                               'id' => '5GvfGrfrshJT6g0kZIvph8'
                                             }
                                           }
                                         ])
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

      describe '#tags' do
        it 'queries tag list' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/tags?limit=1000')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(body: load_fixture('contentful/simple_client/tags.json'))

          # act
          resp = client.tags(limit: 1000)

          # assert
          resp.assert_ok!
          item = resp.items.first
          expect(item['name']).to eq('NY Campaign')
          expect(item.dig('sys', 'id')).to eq('nyCampaign')
        end

        it 'gets single tag' do
          stub_request(:get, 'https://api.contentful.com/spaces/testspace/environments/testenv/tags/ministry-external-focus')
            .with(headers: { Authorization: 'Bearer testtoken' })
            .to_return(body: load_fixture('contentful/simple_client/single-tag.json'))

          # act
          resp = client.tag('ministry-external-focus')

          # assert
          resp.assert_ok!
          expect(resp.raw.dig('sys', 'id')).to eq('ministry-external-focus')
          expect(resp.raw['name']).to eq('Ministry: External Focus')
        end

        it 'can create a tag' do
          new_tag = JSON.parse <<~JSON
            {
              "name": "Ministry: Weddings at Watermark",
              "sys": {
                "visibility": "public",
                "type": "Tag",
                "id": "ministry_weddings"
              }
            }
          JSON

          stub_request(:put, 'https://api.contentful.com/spaces/testspace/environments/testenv/tags/ministry_weddings')
            .with(headers: {
              Authorization: 'Bearer testtoken',
              'Content-Type' => 'application/vnd.contentful.management.v1+json'
            })
            .to_return(body: load_fixture('contentful/simple_client/tag_create.json'))

          # act
          resp = client.tag_create(new_tag)

          # assert
          resp.assert_ok!
          expect(resp.raw.dig('sys', 'id')).to eq('ministry_weddings')
          expect(resp.raw.dig('sys', 'visibility')).to eq('public')
          expect(resp.raw.dig('sys', 'type')).to eq('Tag')
          expect(resp.raw['name']).to eq('Ministry: Weddings at Watermark')
        end
      end
    end
  end
end
