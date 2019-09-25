# frozen_string_literal: true

RSpec.describe WCC::Contentful::SimpleClient, :vcr do
  let(:cdn_base) { "https://cdn.contentful.com/spaces/#{contentful_space_id}" }

  describe 'initialize' do
    after do
      WCC::Contentful::SimpleClient::ADAPTERS = {
        typhoeus: ['typhoeus', '~> 1.0'],
        http: ['http', '> 1.0', '< 3.0']
      }.freeze
    end

    it 'fails to load when no adapter gem found' do
      expect {
        WCC::Contentful::SimpleClient::ADAPTERS = {
          asdf: ['asdf', '~> 1.0']
        }.freeze

        WCC::Contentful::SimpleClient.new(
          api_url: 'https://cdn.contentful.com',
          access_token: contentful_access_token,
          space: contentful_space_id
        )
      }.to raise_error(ArgumentError)
    end

    it 'fails to load when gem is wrong version' do
      expect {
        WCC::Contentful::SimpleClient::ADAPTERS = {
          http: ['http', '< 1.0']
        }.freeze

        WCC::Contentful::SimpleClient.new(
          api_url: 'https://cdn.contentful.com',
          access_token: contentful_access_token,
          space: contentful_space_id
        )
      }.to raise_error(ArgumentError)
    end

    it 'fails to load when adapter is not invokeable' do
      WCC::Contentful::SimpleClient::ADAPTERS = {}.freeze

      expect {
        WCC::Contentful::SimpleClient::ADAPTERS = {
          http: ['http', '< 1.0']
        }.freeze

        WCC::Contentful::SimpleClient.new(
          api_url: 'https://cdn.contentful.com',
          access_token: contentful_access_token,
          space: contentful_space_id,
          adapter: :whoopsie
        )
      }.to raise_error(ArgumentError)
    end
  end

  WCC::Contentful::SimpleClient::ADAPTERS.keys.each do |adapter|
    context "with #{adapter} adapter" do
      subject(:client) {
        WCC::Contentful::SimpleClient.new(
          api_url: 'https://cdn.contentful.com',
          access_token: contentful_access_token,
          space: contentful_space_id,
          adapter: adapter
        )
      }

      describe 'get' do
        it 'gets entries with query params' do
          stub_request(:get, cdn_base + '/entries?limit=2')
            .to_return(body: load_fixture('contentful/simple_client/entries_limit_2.json'))

          # act
          resp = client.get('entries', { limit: 2 })

          # assert
          resp.assert_ok!
          expect(resp.status).to eq(200)
          expect(resp.to_json['items'].map { |i| i.dig('sys', 'id') }).to eq(
            %w[1tPGouM76soIsM2e0uikgw 1IJEXB4AKEqQYEm4WuceG2]
          )
        end

        it 'can query entries with query param' do
          stub_request(:get, cdn_base + '/entries?content_type=menuButton&fields.text=Ministries')
            .to_return(body: load_fixture('contentful/simple_client/menu_buttons_limit_1.json'))

          # act
          resp = client.get('entries',
            {
              content_type: 'menuButton',
              'fields.text' => 'Ministries'
            })

          # assert
          resp.assert_ok!
          expect(resp.status).to eq(200)
          expect(resp.to_json['items'].map { |i| i.dig('sys', 'id') }).to eq(
            %w[3bZRv5ISCkui6kguIwM2U0]
          )
        end

        it 'follows redirects' do
          stub_request(:get, 'http://other-contentful-api.com/api')
            .to_return(status: 301, headers: {
              'Location' => 'https://redirected-contentful-api.com/api'
            })
          stub_request(:get, 'https://redirected-contentful-api.com/api')
            .to_return(body: load_fixture('contentful/simple_client/menu_buttons_limit_1.json'))

          client = WCC::Contentful::SimpleClient.new(
            api_url: 'http://other-contentful-api.com/api',
            access_token: contentful_access_token,
            space: contentful_space_id
          )

          # act
          resp = client.get('/api')

          # assert
          resp.assert_ok!
          expect(resp.status).to eq(200)
          expect(resp.to_json['items'].map { |i| i.dig('sys', 'id') }).to eq(
            %w[3bZRv5ISCkui6kguIwM2U0]
          )
        end

        it 'paginates directly when block given' do
          stub_request(:get, cdn_base + '/content_types?limit=5')
            .to_return(body: load_fixture('contentful/simple_client/content_types_first_page.json'))
          stub_request(:get, cdn_base + '/content_types?limit=5&skip=5')
            .to_return(body: load_fixture('contentful/simple_client/content_types_2nd_page.json'))
          stub_request(:get, cdn_base + '/content_types?limit=5&skip=10')
            .to_return(body: load_fixture('contentful/simple_client/content_types_3rd_page.json'))
          stub_request(:get, cdn_base + '/content_types?limit=5&skip=15')
            .to_return(body: load_fixture('contentful/simple_client/content_types_4th_page.json'))

          # act
          resp = client.get('content_types', { limit: 5 })

          # assert
          resp.assert_ok!
          num_pages = 0
          resp.each_page do |page|
            expect(page.to_json['items'].length).to be <= 5
            num_pages += 1
          end
          expect(num_pages).to eq(4)
        end

        it 'does lazy pagination' do
          stub_request(:get, cdn_base + '/content_types?limit=5')
            .to_return(body: load_fixture('contentful/simple_client/content_types_first_page.json'))
          stub_request(:get, cdn_base + '/content_types?limit=5&skip=5')
            .to_return(body: load_fixture('contentful/simple_client/content_types_2nd_page.json'))
          stub_request(:get, cdn_base + '/content_types?limit=5&skip=10')
            .to_return(body: load_fixture('contentful/simple_client/content_types_3rd_page.json'))
          stub_request(:get, cdn_base + '/content_types?limit=5&skip=15')
            .to_return(body: load_fixture('contentful/simple_client/content_types_4th_page.json'))

          # act
          resp = client.get('content_types', { limit: 5 })

          # assert
          resp.assert_ok!
          pages = resp.each_page
          expect(pages).to be_a(Enumerator::Lazy)
          pages =
            pages.map do |page|
              expect(page.to_json['items'].length).to be <= 5
              page.to_json['items']
            end
          pages = pages.force
          expect(pages.length).to eq(4)
          expect(pages.flatten.map { |c| c.dig('sys', 'id') }.sort)
            .to eq([
                     'dog',
                     'faq',
                     'homepage',
                     'menu',
                     'menuButton',
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

        it 'does not paginate if only the first page is taken' do
          stub_request(:get, /https\:\/\/cdn\.contentful\.com\/spaces\/.+\/content_types\?limit\=5/)
            .to_return(status: 200,
                       body: load_fixture('contentful/simple_client/content_types_first_page.json'))

          stub_request(:get, /https\:\/\/cdn\.contentful\.com\/spaces\/.+\/content_types\?.*skip\=.*/)
            .to_raise(StandardError.new('Should not execute request for second page'))

          # act
          resp = client.get('content_types', { limit: 5 })

          # assert
          resp.assert_ok!
          items = resp.items.take(5)
          expect(items.map { |c| c.dig('sys', 'id') }.force)
            .to eq([
                     'homepage',
                     'migrationHistory',
                     'page',
                     'section-CardSearch',
                     'ministry'
                   ])
        end

        it 'memoizes pages' do
          stub_request(:get, /https\:\/\/cdn\.contentful\.com\/spaces\/.+\/assets\?limit\=5/)
            .to_return(status: 200,
                       body: load_fixture('contentful/simple_client/assets_first_page.json'))
            .times(1)

          stub_request(:get, /https\:\/\/cdn\.contentful\.com\/spaces\/.+\/assets\?.*skip\=5.*/)
            .to_return(status: 200,
                       body: load_fixture('contentful/simple_client/assets_second_page.json'))
            .times(1)

          # act
          resp = client.get('assets', { limit: 5 })

          # assert
          resp.assert_ok!
          # first pagination
          expect(resp.items.count).to eq(6)
          # should be memoized
          expect(resp.items.map { |c| c.dig('fields', 'title', 'en-US') }.force)
            .to eq([
                     'goat-clip-art',
                     'favicon',
                     'worship',
                     'favicon-16x16',
                     'apple-touch-icon',
                     'favicon-32x32'
                   ])
        end

        it 'paginates all items when enumerable forced' do
          stub_request(:get, cdn_base + '/entries?content_type=page&limit=5')
            .to_return(body: load_fixture('contentful/simple_client/pages_first_page.json'))
          stub_request(:get, cdn_base + '/entries?content_type=page&limit=5&skip=5')
            .to_return(body: load_fixture('contentful/simple_client/pages_2nd_page.json'))

          # act
          resp = client.get('entries', { content_type: 'page', limit: 5 })

          # assert
          resp.assert_ok!
          items =
            resp.items.map do |item|
              item.dig('sys', 'id')
            end
          expect(items.force)
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

        it 'builds a hash of included links by ID' do
          stub_request(:get, cdn_base + '/entries?content_type=page&limit=5&include=2')
            .to_return(body: load_fixture('contentful/simple_client/pages_with_includes_page_1.json'))
          stub_request(:get, cdn_base + '/entries?content_type=page&limit=5&skip=5&include=2')
            .to_return(body: load_fixture('contentful/simple_client/pages_with_includes_page_2.json'))
          # act
          resp = client.get('entries', { content_type: 'page', limit: 5, include: 2 })
          # range the pages to load up the whole hash
          resp.items.force

          # assert
          expect(resp.includes.count).to eq(73)

          # loads an entry from 2 levels deep
          expect(resp.includes['6B4mPenxokGUM2GuIEmg8C']).to eq({
            'sys' => {
              'space' => {
                'sys' => {
                  'type' => 'Link',
                  'linkType' => 'Space',
                  'id' => contentful_space_id
                }
              },
              'id' => '6B4mPenxokGUM2GuIEmg8C',
              'type' => 'Entry',
              'createdAt' => '2018-04-19T21:14:41.272Z',
              'updatedAt' => '2018-04-19T21:14:41.272Z',
              'environment' => {
                'sys' => {
                  'id' => 'master',
                  'type' => 'Link',
                  'linkType' => 'Environment'
                }
              },
              'revision' => 1,
              'contentType' => {
                'sys' => {
                  'type' => 'Link',
                  'linkType' => 'ContentType',
                  'id' => 'menuButton'
                }
              },
              'locale' => 'en-US'
            },
            'fields' => {
              'text' => 'Conflict Field Guide Download',
              'externalLink' => 'http://www.watermark.org/dallas/ministries/community/resources/conflict-field-guide'
            }
          })

          # loads an asset
          expect(resp.includes['2rakCOkeRumQuig0K8uaYm']).to eq({
            'sys' => {
              'space' => {
                'sys' => {
                  'type' => 'Link',
                  'linkType' => 'Space',
                  'id' => contentful_space_id
                }
              },
              'id' => '2rakCOkeRumQuig0K8uaYm',
              'type' => 'Asset',
              'createdAt' => '2018-04-16T19:45:06.658Z',
              'updatedAt' => '2018-05-21T14:55:21.976Z',
              'environment' => {
                'sys' => {
                  'id' => 'master',
                  'type' => 'Link',
                  'linkType' => 'Environment'
                }
              },
              'revision' => 2,
              'locale' => 'en-US'
            },
            'fields' => {
              'title' => 'bg-watermark-the-porch-marvin',
              'file' => {
                'url' => "//images.ctfassets.net/#{contentful_space_id}/2rakCOkeRumQuig0K8uaYm/" \
                  'ca2d47f56904a5069876856f3524990b/bg-watermark-the-porch-dea.jpg',
                'details' => {
                  'size' => 217_715,
                  'image' => {
                    'width' => 1600,
                    'height' => 833
                  }
                },
                'fileName' => 'bg-watermark-the-porch-dea.jpg',
                'contentType' => 'image/jpeg'
              }
            }
          })
        end
      end

      describe 'Cdn' do
        subject(:client) {
          WCC::Contentful::SimpleClient::Cdn.new(
            access_token: contentful_access_token,
            space: contentful_space_id,
            adapter: adapter
          )
        }

        describe 'sync' do
          it 'gets all sync items' do
            stub_request(:get, cdn_base + '/sync?initial=true')
              .to_return(body: load_fixture('contentful/simple_client/sync_initial.json'))

            # act
            resp = client.sync

            # assert
            resp.assert_ok!
            items = resp.items.map { |i| i.dig('sys', 'id') }
            expect(resp.items.count).to eq(34)
            expect(items.sort.take(5))
              .to eq(%w[
                       1EjBdAgOOgAQKAggQoY2as 1IJEXB4AKEqQYEm4WuceG2 1MsOLBrDwEUAUIuMY8Ys6o
                       1TikjmGeSIisEWoC4CwokQ 1UojJt7YoMiemCq2mGGUmQ
                     ])
          end

          it 'pages when theres a lot of items' do
            stub_request(:get, cdn_base + '/sync?initial=true')
              .to_return(body: load_fixture('contentful/simple_client/sync_paginated_initial.json'))

            sync_token = 'wonDrcKnRgcSOF4-wrDCgcKefWzCgsOxwrfCq8KOfMOdXUPCvEnChwEEO8KFwqHDj8KxwrzDmk' \
              'TCrsKWUwnDiFczCULDs08Pw5LDj1DCr8KQwoEVw7dBdhPDi23DrsKlwoPDkcKESGfCt8Kyw5hnDcOEwrkMOjL' \
              'CtsOZwqzDh8OAI3ZEW8K0fELDqMKAw73DoFo-RV_DsRVteRhXw7LDulU4worCgsOlRsOVworCtgrCpnkqTBdG' \
              'w6PDt8OYOcOHDw'
            stub_request(:get, cdn_base + '/sync?sync_token=' + sync_token)
              .to_return(body: load_fixture('contentful/simple_client/sync_paginated_page_2.json'))

            sync_token = 'wonDrcKnRgcSOF4-wrDCgcKefWzCgsOxwrfCq8KOfMOdXUPCvEnChwEEO8KFwqHDj8KxwrzDmk' \
              'TCrsKWUwnDiFczCULDs08Pw5LDj1DCr8KQwoEVw7dBdhPDi23DrsKlwoPDkcKESGfCt8Kyw5hnDcOEwrkMOjL' \
              'CtsOZCiV0HMKKw4rDpcKXwpXCh1vDlVMPRcOLYMKzw7HDucOFbsKSZ3pqTcONwqxXw43CssKgP8Oqw7HCqnPC' \
              'nsOpdXfCksO1fVfDsDM'
            stub_request(:get, cdn_base + '/sync?sync_token=' + sync_token)
              .to_return(body: load_fixture('contentful/simple_client/sync_paginated_page_3.json'))

            # act
            resp = client.sync

            # assert
            resp.assert_ok!
            items = resp.items.map { |i| i.dig('sys', 'id') }
            expect(items.count).to be > 200
          end

          it 'returns next sync token' do
            stub_request(:get, cdn_base + '/sync?initial=true')
              .to_return(body: load_fixture('contentful/simple_client/sync_initial.json'))

            # act
            resp = client.sync

            # assert
            resp.assert_ok!
            expect(resp.next_sync_token)
              .to eq('w5ZGw6JFwqZmVcKsE8Kow4grw45QdybCpsOKdcK_ZjDCpMOFwpXDq8KRUE1Fw613K8KyA8OIwqv' \
                'CtDfChhbCpsO7CjfDssOKw7YtXMOnwobDjcKrw7XDjMKHw7jCq8K1wrRRwpHCqMKIwr_DoMKSwrnCqS0' \
                'qw47DkShzZ8K3V8KR')
          end

          it 'accepts sync token' do
            sync_token = 'w5ZGw6JFwqZmVcKsE8Kow4grw45QdybCpsOKdcK_ZjDCpMOFwpXDq8' \
              'KRUE1Fw613K8KyA8OIwqvCtDfChhbCpsO7CjfDssOKw7YtXMOnwobDjcKrw7XDjMK' \
              'Hw7jCq8K1wrRRwpHCqMKIwr_DoMKSwrnCqS0qw47DkShzZ8K3V8KR'
            stub_request(:get, cdn_base + '/sync?sync_token=' + sync_token)
              .to_return(body: {
                'sys' => {
                  'type' => 'Array'
                },
                'items' => [],
                "nextSyncUrl": cdn_base + '/sync?sync_token=another-sync-token'
              }.to_json)

            # act
            resp = client.sync(sync_token: sync_token)

            # assert
            resp.assert_ok!
            items = resp.items.map { |i| i.dig('sys', 'id') }
            expect(resp.items.count).to eq(0)
            expect(items.force).to eq([])
          end
        end
      end

      context 'with environment' do
        subject(:client) {
          WCC::Contentful::SimpleClient.new(
            api_url: 'https://cdn.contentful.com',
            access_token: contentful_access_token,
            space: contentful_space_id,
            adapter: adapter,
            environment: 'specs'
          )
        }

        describe 'get' do
          it 'gets entries with query params from environment' do
            fixture = JSON.parse(load_fixture('contentful/simple_client/entries_limit_2.json'))
            fixture['items'].each do |entry|
              entry['sys']['environment'] = { 'sys' => { 'id' => 'specs' } }
            end

            stub_request(:get, cdn_base + '/environments/specs/entries?limit=2')
              .to_return(body: fixture.to_json)

            # act
            resp = client.get('entries', { limit: 2 })

            # assert
            resp.assert_ok!
            expect(resp.status).to eq(200)
            expect(resp.to_json['items'].map { |i| i.dig('sys', 'id') }).to eq(
              %w[1tPGouM76soIsM2e0uikgw 1IJEXB4AKEqQYEm4WuceG2]
            )
            resp.to_json['items'].each do |item|
              expect(item.dig('sys', 'environment', 'sys', 'id')).to eq('specs')
            end
          end

          it 'paginates all items' do
            stub_request(:get, cdn_base + '/environments/specs/entries?content_type=page&limit=5')
              .to_return(body: load_fixture('contentful/simple_client/pages_first_page.json'))
            stub_request(:get, cdn_base +
                '/environments/specs/entries?content_type=page&limit=5&skip=5')
              .to_return(body: load_fixture('contentful/simple_client/pages_2nd_page.json'))

            # act
            resp = client.get('entries', { content_type: 'page', limit: 5 })

            # assert
            resp.assert_ok!
            items =
              resp.items.map do |item|
                item.dig('sys', 'id')
              end
            expect(items.force)
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
    end
  end
end
