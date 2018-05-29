

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
end
