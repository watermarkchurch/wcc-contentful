# frozen_string_literal: true

RSpec.describe WCC::Contentful::Store::CDNAdapter, :vcr do
  subject(:adapter) {
    WCC::Contentful::Store::CDNAdapter.new(
      WCC::Contentful::SimpleClient::Cdn.new(
        access_token: contentful_access_token,
        space: contentful_space_id
      )
    )
  }

  let(:asset) {
    <<~JSON
      {
        "sys": {
          "space": {
            "sys": {
              "type": "Link",
              "linkType": "Space",
              "id": "343qxys30lid"
            }
          },
          "id": "3pWma8spR62aegAWAWacyA",
          "type": "Asset",
          "createdAt": "2018-02-12T19:53:39.309Z",
          "updatedAt": "2018-02-12T19:53:39.309Z",
          "revision": 1
        },
        "fields": {
          "title": {
            "en-US": "apple-touch-icon"
          },
          "file": {
            "en-US": {
              "url": "//images.contentful.com/343qxys30lid/3pWma8spR62aegAWAWacyA/1beaebf5b66d2405ff9c9769a74db709/apple-touch-icon.png",
              "details": {
                "size": 40832,
                "image": {
                  "width": 180,
                  "height": 180
                }
              },
              "fileName": "apple-touch-icon.png",
              "contentType": "image/png"
            }
          }
        }
      }
    JSON
  }

  before do
    content_types = JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
    indexer = WCC::Contentful::ContentTypeIndexer.new
    content_types['items'].each do |raw_content_type|
      indexer.index(raw_content_type)
    end
    allow(WCC::Contentful).to receive(:types)
      .and_return(indexer.types)
  end

  describe '#find' do
    it 'finds data by ID' do
      # act
      found = adapter.find('3bZRv5ISCkui6kguIwM2U0')

      # assert
      expect(found['sys']).to include({
        'id' => '3bZRv5ISCkui6kguIwM2U0',
        'type' => 'Entry'
      })
      expect(found['fields']).to include({
        'text' => {
          'en-US' => 'Ministries'
        },
        'iconFA' => {
          'en-US' => 'fa-file-alt'
        },
        'buttonStyle' => {
          'en-US' => %w[
            rounded
            custom
          ]
        },
        'customButtonCss' => {
          'en-US' => [
            'border-color: green;'
          ]
        },
        'link' => {
          'en-US' => {
            'sys' => {
              'type' => 'Link',
              'linkType' => 'Entry',
              'id' => 'JhYhSfZPAOMqsaK8cYOUK'
            }
          }
        }
      })
    end

    it 'finds asset by ID' do
      # act
      found = adapter.find('4JV2MbQVoAeEUQGUmYGQGY')

      # assert
      expect(found['sys']).to include({
        'id' => '4JV2MbQVoAeEUQGUmYGQGY',
        'type' => 'Asset'
      })

      expect(found['fields']).to eq({
        'title' => {
          'en-US' => 'goat-clip-art'
        },
        'file' => {
          'en-US' => {
            'url' => "//images.ctfassets.net/#{contentful_space_id}/"\
              '4JV2MbQVoAeEUQGUmYGQGY/1f0e377e665d2ab94fb86b0c88e75b06/goat-clip-art.png',
            'details' => {
              'size' => 62_310,
              'image' => {
                'width' => 219,
                'height' => 203
              }
            },
            'fileName' => 'goat-clip-art.png',
            'contentType' => 'image/png'
          }
        }
      })
    end

    it 'follows hint for assets' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
          '/entries/3pWma8spR62aegAWAWacyA')
        .with(query: hash_including(locale: '*'))
        .to_raise('Should not hit the Entries endpoint')

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
          '/assets/3pWma8spR62aegAWAWacyA')
        .with(query: hash_including(locale: '*'))
        .to_return(status: 200, body: asset)

      # act
      found = adapter.find('3pWma8spR62aegAWAWacyA', hint: 'Asset')

      # assert
      expect(found).to be_present
      expect(found.dig('sys', 'id')).to eq('3pWma8spR62aegAWAWacyA')
      expect(found.dig('fields', 'title', 'en-US')).to eq('apple-touch-icon')
    end

    it 'returns nil when not found' do
      # act
      found = adapter.find('asdf')

      # assert
      expect(found).to be_nil
    end
  end

  describe '#find_by' do
    it 'finds first of content type' do
      # act
      found = adapter.find_by(content_type: 'menuButton')

      # assert
      expect(found).to_not be_nil
      expect(found.dig('sys', 'contentType', 'sys', 'id')).to eq('menuButton')
    end

    it 'finds assets' do
      # act
      found = adapter.find_by(content_type: 'Asset')

      # assert
      expect(found).to_not be_nil
      expect(found.dig('fields', 'title', 'en-US')).to eq('goat-clip-art')
    end

    it 'can apply filter object' do
      # act
      found = adapter.find_by(content_type: 'page', filter: { 'slug' => { eq: '/conferences' } })

      # assert
      expect(found).to_not be_nil
      expect(found.dig('sys', 'id')).to eq('1UojJt7YoMiemCq2mGGUmQ')
      expect(found.dig('fields', 'title', 'en-US')).to eq('Conferences')
    end

    it 'allows filtering by a reference field' do
      # act
      found = adapter.find_by(
        content_type: 'menuButton',
        filter: {
          link: {
            slug: { eq: '/conferences' },
            'sys.contentType.sys.id': 'page'
          }
        }
      )

      # assert
      expect(found).to_not be_nil
      expect(found.dig('sys', 'id')).to eq('4j79PYivYIWuqwA4scaAOW')
      expect(found.dig('sys', 'contentType', 'sys', 'id')).to eq('menuButton')
    end

    it 'allows filtering by reference id' do
      # act
      found = adapter.find_by(
        content_type: 'menuButton',
        filter: { 'link' => { id: '1UojJt7YoMiemCq2mGGUmQ' } }
      )

      # assert
      expect(found).to_not be_nil
      expect(found.dig('sys', 'id')).to eq('4j79PYivYIWuqwA4scaAOW')
    end

    it 'requires sys attributes to be explicitly specified' do
      expect {
        adapter.find_by(
          content_type: 'menuButton',
          filter: { 'link' => { contentType: 'page' } }
        )
      }.to raise_exception(WCC::Contentful::SimpleClient::ApiError)

      expect {
        adapter.find_by(
          content_type: 'menuButton',
          filter: { 'link' => { 'sys.contentType.sys.id': 'page' } }
        )
      }.to_not raise_exception
    end

    it 'assumes all non-sys arguments to be fields' do
      # act
      found = adapter.find_by(
        content_type: 'page',
        filter: { slug: '/conferences' }
      )

      # assert
      expect(found).to_not be_nil
      expect(found.dig('sys', 'id')).to eq('1UojJt7YoMiemCq2mGGUmQ')
      expect(found.dig('fields', 'slug', 'en-US')).to eq('/conferences')
    end

    it 'does allows properties named `*sys*`' do
      # act
      found = adapter.find_by(content_type: 'system', filter: { system: 'One' })

      # assert
      expect(found).to_not be_nil
      expect(found.dig('sys', 'id')).to eq('2eXv0N3vUkIOWAauGg4q8a')
      expect(found.dig('fields', 'system', 'en-US')).to eq('One')
    end

    it 'passes query params thru to client' do
      entry_stub = make_entry('test1', 'page')
      expect(adapter.client).to receive(:entries)
        .with({
          locale: '*',
          content_type: 'page',
          'fields.test.en-US' => 'junk',
          limit: 2,
          skip: 10,
          include: 5
        })
        .and_return(double(items: [entry_stub], includes: {}))

      # act
      found = adapter.find_by(
        content_type: 'page',
        filter: { test: 'junk' },
        options: {
          limit: 2,
          skip: 10,
          include: 5
        }
      )

      # assert
      expect(found).to eq(entry_stub)
    end
  end

  describe '#find_all' do
    it 'filters on content type' do
      # act
      found = adapter.find_all(content_type: 'menuButton')

      # assert
      expect(found.count).to eq(11)
      expect(found.map { |i| i.dig('fields', 'text', 'en-US') }.sort).to eq(
        [
          'About',
          'About Watermark Resources',
          'Cart',
          'Conferences',
          'Find A Ministry for Your Church',
          'Login',
          'Ministries',
          'Mission',
          'Privacy Policy',
          'Terms & Conditions',
          'Watermark.org'
        ]
      )
    end

    it 'finds assets' do
      # act
      found = adapter.find_all(content_type: 'Asset')

      # assert
      expect(found.count).to eq(6)
      expect(found.map { |i| i.dig('fields', 'title', 'en-US') }.sort).to eq(
        [
          'apple-touch-icon',
          'favicon',
          'favicon-16x16',
          'favicon-32x32',
          'goat-clip-art',
          'worship'
        ]
      )
    end

    it 'filter query eq can find value' do
      # act
      found = adapter.find_all(content_type: 'page')
        .apply('slug' => { eq: '/conferences' })

      # assert
      expect(found.count).to eq(1)
      page = found.first
      expect(page.dig('sys', 'id')).to eq('1UojJt7YoMiemCq2mGGUmQ')
      expect(page.dig('fields', 'title', 'en-US')).to eq('Conferences')
    end

    it 'defaults to :in if given an array' do
      stub = stub_request(:get,
        'https://cdn.contentful.com/spaces/hw5pse7y1ojx/entries?content_type=conference&fields.tags.en-US%5Bin%5D=a,b&locale=*')
        .to_return(body: {
          sys: { type: 'Array' },
          total: 2,
          items: [
            { sys: { type: 'Entry', id: '1' } },
            { sys: { type: 'Entry', id: '2' } }
          ]
        }.to_json)

      # act
      found = adapter.find_all(content_type: 'conference')
        .apply(tags: %w[a b])

      expect(found.count).to eq(2)
      expect(stub).to have_been_requested
    end

    it 'handles nin with array' do
      stub = stub_request(:get,
        'https://cdn.contentful.com/spaces/hw5pse7y1ojx/entries?content_type=conference&fields.tags.en-US%5Bnin%5D=a,b&locale=*')
        .to_return(body: {
          sys: { type: 'Array' },
          total: 1,
          items: [
            { sys: { type: 'Entry', id: '1' } }
          ]
        }.to_json)

      # act
      found = adapter.find_all(content_type: 'conference')
        .apply(tags: { nin: %w[a b] })

      expect(found.count).to eq(1)
      expect(stub).to have_been_requested
    end

    it 'recursively resolves links if include > 0' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries" \
        '?content_type=page&include=2&limit=5&locale=*')
        .to_return(body: load_fixture('contentful/cdn_adapter_spec/page_find_all_1.json'))
        .then.to_raise(StandardError)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries" \
        '?content_type=page&include=2&limit=5&locale=*&skip=5')
        .to_return(body: load_fixture('contentful/cdn_adapter_spec/page_find_all_2.json'))
        .then.to_raise(StandardError)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries" \
        '?content_type=page&include=2&limit=5&locale=*&skip=10')
        .to_return(body: load_fixture('contentful/cdn_adapter_spec/page_find_all_3.json'))
        .then.to_raise(StandardError)

      # act
      found = adapter.find_all(content_type: 'page', options: {
        limit: 5,
        include: 2
      })

      # assert
      expect(found.to_enum).to be_a(Enumerator::Lazy)
      items = found.to_enum.force
      expect(items.count).to eq(11)

      page5 = items[5]
      expect(page5.dig('sys', 'id')).to eq('MNL6HaLyWAAo4A2S2mkkk')

      # depth 1
      header = page5.dig('fields', 'header', 'en-US')
      expect(header.dig('sys', 'type')).to eq('Entry')

      # depth 2
      domain_object = header.dig('fields', 'domainObject', 'en-US')
      expect(domain_object.dig('sys', 'type')).to eq('Entry')
    end

    it 'stops resolving links at include depth' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries" \
        '?content_type=page&include=2&limit=5&locale=*')
        .to_return(body: load_fixture('contentful/cdn_adapter_spec/page_find_all_1.json'))
        .then.to_raise(StandardError)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries" \
        '?content_type=page&include=2&limit=5&locale=*&skip=5')
        .to_return(body: load_fixture('contentful/cdn_adapter_spec/page_find_all_2.json'))
        .then.to_raise(StandardError)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries" \
        '?content_type=page&include=2&limit=5&locale=*&skip=10')
        .to_return(body: load_fixture('contentful/cdn_adapter_spec/page_find_all_3.json'))
        .then.to_raise(StandardError)

      # act
      found = adapter.find_all(content_type: 'page', options: {
        limit: 5,
        include: 2
      })

      # assert
      expect(found.to_enum).to be_a(Enumerator::Lazy)
      items = found.to_enum.force
      expect(items.count).to eq(11)

      page5 = items[5]
      expect(page5.dig('sys', 'id')).to eq('MNL6HaLyWAAo4A2S2mkkk')

      # depth 1
      header = page5.dig('fields', 'header', 'en-US')

      # depth 2
      domain_object = header.dig('fields', 'domainObject', 'en-US')

      # depth 3
      thumbnail = domain_object.dig('fields', 'thumbnail', 'en-US')
      expect(thumbnail.dig('sys', 'type')).to eq('Link')
    end

    it 'ensures enumerator remains lazy when map applied at higher layer' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries" \
        '?content_type=page&include=2&limit=5&locale=*')
        .to_return(body: load_fixture('contentful/cdn_adapter_spec/page_find_all_1.json'))
        .then.to_raise(StandardError)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries" \
        '?content_type=page&include=2&limit=5&locale=*&skip=5')
        .to_raise(StandardError.new('Should not call second page'))

      # act
      found = adapter.find_all(content_type: 'page', options: {
        limit: 5,
        include: 2
      })

      # assert
      only_two = found.map { |entry| OpenStruct.new(entry) }.take(2).to_a

      expect(only_two.length).to eq 2
    end
  end

  it 'CDN Adapter does not implement #set' do
    expect(subject).to_not respond_to(:set)
  end

  it 'CDN Adapter does not implement #delete' do
    expect(subject).to_not respond_to(:delete)
  end

  it 'CDN Adapter does not implement #index' do
    expect(subject.index?).to be false
    expect {
      subject.index(asset)
    }.to raise_error
  end

  def make_entry(id, content_type)
    {
      'sys' => {
        'id' => id,
        'type' => 'Entry',
        'contentType' => {
          'sys' => {
            'type' => 'Link',
            'linkType' => 'ContentType',
            'id' => content_type
          }
        }
      },
      'fields' => {}
    }
  end
end
