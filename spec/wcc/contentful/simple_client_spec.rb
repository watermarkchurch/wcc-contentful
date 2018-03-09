

# frozen_string_literal: true

RSpec.describe WCC::Contentful::SimpleClient, :vcr do
  subject(:client) {
    WCC::Contentful::SimpleClient.new(
      api_url: 'https://cdn.contentful.com',
      access_token: ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234',
      space_id: ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'
    )
  }

  describe 'get' do
    it 'gets entries with query params' do
      # act
      resp = client.get('entries', { limit: 2 })

      # assert
      resp.assert_ok!
      expect(resp.code).to eq(200)
      expect(resp.to_json['items'].map { |i| i.dig('sys', 'id') }).to eq(
        %w[1tPGouM76soIsM2e0uikgw 1IJEXB4AKEqQYEm4WuceG2]
      )
    end

    it 'can query entries with query param' do
      # act
      resp = client.get('entries',
        {
          content_type: 'menuItem',
          'fields.text' => 'Ministries'
        })

      # assert
      resp.assert_ok!
      expect(resp.code).to eq(200)
      expect(resp.to_json['items'].map { |i| i.dig('sys', 'id') }).to eq(
        %w[3bZRv5ISCkui6kguIwM2U0]
      )
    end

    it 'follows redirects' do
      client = WCC::Contentful::SimpleClient.new(
        api_url: 'http://jtj.watermark.org',
        access_token: ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234',
        space_id: ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'
      )

      # act
      resp = client.get('/api')

      # assert
      resp.assert_ok!
      expect(resp.to_json['links']).to_not be_nil
    end

    it 'handles pagination' do
      # act
      resp = client.get('content_types', { limit: 5 })

      # assert
      resp.assert_ok!
      pages =
        resp.each_page do |page|
          expect(page.to_json['items'].length).to be <= 5
          page.to_json['items']
        end
      expect(pages.length).to eq(4)
      expect(pages.flatten.map { |c| c.dig('sys', 'id') }.sort)
        .to eq([
                 'dog',
                 'faq',
                 'homepage',
                 'menu',
                 'menuItem',
                 'migrationHistory',
                 'ministry',
                 'ministryCard',
                 'page',
                 'redirect',
                 'section-CardSearch',
                 'section-Faq',
                 'section-Testimonials',
                 'section-VideoHighlight',
                 'testimonial',
                 'theme'
               ])
    end

    it 'paginates all items' do
      # act
      resp = client.get('entries', { content_type: 'page', limit: 5 })

      # assert
      resp.assert_ok!
      items =
        resp.map do |item|
          item.dig('sys', 'id')
        end
      expect(items)
        .to eq(%w[
                 47PsST8EicKgWIWwK2AsW6
                 1loILDsvKYkmGWoiKOOgkE
                 1UojJt7YoMiemCq2mGGUmQ
                 3Azc4SjWSsYIuYO8m8qqQE
                 4lD8cHrr0QSAcY0sguqmss
                 1tPGouM76soIsM2e0uikgw
                 32EYWhG184SgoiYo2e6iOo
                 JhYhSfZPAOMqsaK8cYOUK
               ])
    end
  end
end
