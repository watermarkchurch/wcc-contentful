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
  end

  it 'CDN Adapter does not implement #set' do
    expect(subject).to_not respond_to(:set)
  end

  it 'CDN Adapter does not implement #delete' do
    expect(subject).to_not respond_to(:delete)
  end

  it 'CDN Adapter does not implement #index' do
    expect(subject).to_not respond_to(:index)
  end
end
