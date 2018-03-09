# frozen_string_literal: true

RSpec.describe WCC::Contentful::Store::CDNAdapter, :vcr do
  subject(:adapter) {
    WCC::Contentful::Store::CDNAdapter.new(
      WCC::Contentful::SimpleClient::Cdn.new(
        access_token: ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234',
        space: ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'
      )
    )
  }

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
          'url' => '//images.ctfassets.net/343qxys30lid/4JV2MbQVoAeEUQGUmYGQGY/'\
            '1f0e377e665d2ab94fb86b0c88e75b06/goat-clip-art.png',
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

  it 'find_by filters on content type' do
    # act
    found = adapter.find_by(content_type: 'menuItem')

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

  it 'filter query eq can find value' do
    # act
    found = adapter.find_by(content_type: 'page')
      .apply({ field: 'slug', eq: '/conferences' })

    # assert
    expect(found.count).to eq(1)
    page = found.first
    expect(page.dig('sys', 'id')).to eq('1UojJt7YoMiemCq2mGGUmQ')
    expect(page.dig('fields', 'title', 'en-US')).to eq('Conferences')
  end
end
