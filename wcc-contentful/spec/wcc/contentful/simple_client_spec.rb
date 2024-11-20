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
          connection: :whoopsie
        )
      }.to raise_error(ArgumentError)
    end
  end

  WCC::Contentful::SimpleClient::ADAPTERS.each_key do |adapter|
    context "with #{adapter} adapter" do
      subject(:client) {
        WCC::Contentful::SimpleClient.new(
          api_url: 'https://cdn.contentful.com',
          access_token: contentful_access_token,
          space: contentful_space_id,
          connection: adapter
        )
      }

      describe 'get' do
        it 'gets entries with query params' do
          stub_request(:get, "#{cdn_base}/entries?limit=2")
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
          stub_request(:get, "#{cdn_base}/entries?content_type=menuButton&fields.text=Ministries")
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
          stub_request(:get, "#{cdn_base}/content_types?limit=5")
            .to_return(body: load_fixture('contentful/simple_client/content_types_first_page.json'))
          stub_request(:get, "#{cdn_base}/content_types?limit=5&skip=5")
            .to_return(body: load_fixture('contentful/simple_client/content_types_2nd_page.json'))
          stub_request(:get, "#{cdn_base}/content_types?limit=5&skip=10")
            .to_return(body: load_fixture('contentful/simple_client/content_types_3rd_page.json'))
          stub_request(:get, "#{cdn_base}/content_types?limit=5&skip=15")
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
          stub_request(:get, "#{cdn_base}/content_types?limit=5")
            .to_return(body: load_fixture('contentful/simple_client/content_types_first_page.json'))
          stub_request(:get, "#{cdn_base}/content_types?limit=5&skip=5")
            .to_return(body: load_fixture('contentful/simple_client/content_types_2nd_page.json'))
          stub_request(:get, "#{cdn_base}/content_types?limit=5&skip=10")
            .to_return(body: load_fixture('contentful/simple_client/content_types_3rd_page.json'))
          stub_request(:get, "#{cdn_base}/content_types?limit=5&skip=15")
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
            .to eq(%w[
                     dog
                     faq
                     homepage
                     menu
                     menuButton
                     migrationHistory
                     ministry
                     ministryCard
                     page
                     redirect
                     section-CardSearch
                     section-Faq
                     section-Testimonials
                     section-VideoHighlight
                     testimonial
                     theme
                   ])
        end

        it 'does not paginate if only the first page is taken' do
          stub_request(:get, /https:\/\/cdn\.contentful\.com\/spaces\/.+\/content_types\?limit=5/)
            .to_return(status: 200,
              body: load_fixture('contentful/simple_client/content_types_first_page.json'))

          stub_request(:get, /https:\/\/cdn\.contentful\.com\/spaces\/.+\/content_types\?.*skip=.*/)
            .to_raise(StandardError.new('Should not execute request for second page'))

          # act
          resp = client.get('content_types', { limit: 5 })

          # assert
          resp.assert_ok!
          items = resp.items.take(5)
          expect(items.map { |c| c.dig('sys', 'id') }.force)
            .to eq(%w[
                     homepage
                     migrationHistory
                     page
                     section-CardSearch
                     ministry
                   ])
        end

        it 'does not memoize pages' do
          page1 = stub_request(:get, /https:\/\/cdn\.contentful\.com\/spaces\/.+\/assets\?limit=5$/)
            .to_return(status: 200,
              body: load_fixture('contentful/simple_client/assets_first_page.json'))

          page2 = stub_request(:get, /https:\/\/cdn\.contentful\.com\/spaces\/.+\/assets\?.*skip=5.*/)
            .to_return(status: 200,
              body: load_fixture('contentful/simple_client/assets_second_page.json'))

          # act
          resp = client.get('assets', { limit: 5 })

          # assert
          resp.assert_ok!
          # Count should not cause a pagination
          expect(resp.count).to eq(6)
          expect(page2).to_not have_been_requested

          # Forcing to_a should cause pagination
          expect(resp.items.to_a.count).to eq(6)
          expect(page2).to have_been_requested.times(1)

          # Second pagination should not be memoized
          expect(resp.items.map { |c| c.dig('fields', 'title') }.force)
            .to eq(%w[
                     goat-clip-art
                     favicon
                     worship
                     favicon-16x16
                     apple-touch-icon
                     favicon-32x32
                   ])
          expect(page2).to have_been_requested.times(2)

          # The original call generating the response object should be only once
          expect(page1).to have_been_requested.times(1)
        end

        it 'paginates all items when enumerable forced' do
          stub_request(:get, "#{cdn_base}/entries?content_type=page&limit=5")
            .to_return(body: load_fixture('contentful/simple_client/pages_first_page.json'))
          stub_request(:get, "#{cdn_base}/entries?content_type=page&limit=5&skip=5")
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
          stub_request(:get, "#{cdn_base}/entries?content_type=page&limit=5&include=2")
            .to_return(body: load_fixture('contentful/simple_client/pages_with_includes_page_1.json'))
          stub_request(:get, "#{cdn_base}/entries?content_type=page&limit=5&skip=5&include=2")
            .to_return(body: load_fixture('contentful/simple_client/pages_with_includes_page_2.json'))
          # act
          resp = client.get('entries', { content_type: 'page', limit: 5, include: 2 })
          # range the pages to load up the whole hash
          pages = resp.each_page.to_a
          includes =
            pages.each_with_object({}) do |p, h|
              h.merge!(p.includes)
            end

          # assert
          expect(includes.count).to eq(73)

          # loads an entry from 2 levels deep
          expect(includes['6B4mPenxokGUM2GuIEmg8C']).to eq({
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
          expect(includes['2rakCOkeRumQuig0K8uaYm']).to eq({
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

        it 'instruments pagination' do
          stub_request(:get, "#{cdn_base}/content_types?limit=5")
            .to_return(body: load_fixture('contentful/simple_client/content_types_first_page.json'))
          stub_request(:get, "#{cdn_base}/content_types?limit=5&skip=5")
            .to_return(body: load_fixture('contentful/simple_client/content_types_2nd_page.json'))

          # act
          resp = client.get('content_types', { limit: 5 })

          # assert
          pages = resp.each_page
          _p0 = pages.next
          expect {
            expect {
              _p1 = pages.next
            }.to instrument('page.response.simpleclient.contentful.wcc')
          }.to instrument('get_http.simpleclient.contentful.wcc')
        end

        it 'retries GETs on 429 rate limit' do
          stub_request(:get, "#{cdn_base}/entries?limit=2")
            .to_return(status: 429,
              headers: {
                # 20 per second
                'X-Contentful-RateLimit-Reset': 1
              })
            .then
            .to_return(body: load_fixture('contentful/simple_client/entries_limit_2.json'))

          # act
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          resp = client.get('entries', { limit: 2 })
          finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          # assert
          resp.assert_ok!
          expect(resp.status).to eq(200)
          expect(resp.to_json['items'].map { |i| i.dig('sys', 'id') }).to eq(
            %w[1tPGouM76soIsM2e0uikgw 1IJEXB4AKEqQYEm4WuceG2]
          )
          expect(finish - start).to be > 1.0
        end

        it 'times out on a long 429 rate limit reset' do
          stub_request(:get, "#{cdn_base}/entries?limit=2")
            .to_return(status: 429,
              headers: {
                # 7200 per hour for preview API
                'X-Contentful-RateLimit-Reset': 3600
              })
            .then
            .to_raise(StandardError, 'Should have bailed!')

          resp = client.get('entries', { limit: 2 })

          expect {
            resp.assert_ok!
          }.to raise_error(WCC::Contentful::SimpleClient::RateLimitError)
        end

        it 'times out on multiple rate limits' do
          # just keep returning rate limit error
          stub_request(:get, "#{cdn_base}/entries?limit=2")
            .to_return(status: 429,
              headers: {
                'X-Contentful-RateLimit-Reset': 1
              })

          # act
          start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          resp = client.get('entries', { limit: 2 })
          finish = Process.clock_gettime(Process::CLOCK_MONOTONIC)

          # assert
          expect {
            resp.assert_ok!
          }.to raise_error(WCC::Contentful::SimpleClient::RateLimitError)
          # It should have at least waited the default wait time to see if
          # rate limits clear up.
          expect(finish - start).to be > 1.0
        end

        it 'instruments rate limit' do
          stub_request(:get, "#{cdn_base}/entries?limit=2")
            .to_return(status: 429,
              headers: {
                # 20 per second
                'X-Contentful-RateLimit-Reset': 1
              })
            .then
            .to_return(body: load_fixture('contentful/simple_client/entries_limit_2.json'))

          # act
          expect {
            client.get('entries', { limit: 2 })
          }.to instrument('rate_limit.simpleclient.contentful.wcc')
        end
      end
    end
  end

  describe 'Cdn' do
    subject(:client) {
      WCC::Contentful::SimpleClient::Cdn.new(
        access_token: contentful_access_token,
        space: contentful_space_id
      )
    }

    it 'notifies' do
      fixture = JSON.parse(load_fixture('contentful/simple_client/entries_limit_2.json'))
      stub_request(:get, "#{cdn_base}/entries?limit=2")
        .to_return(body: fixture.to_json)

      expect {
        client.entries({ limit: 2 })
      }.to instrument('get_http.simpleclient.contentful.wcc')

      expect {
        client.entries({ limit: 2 })
      }.to instrument('entries.simpleclient.contentful.wcc')
    end

    describe 'sync' do
      it 'gets all sync items' do
        stub_request(:get, "#{cdn_base}/sync?initial=true")
          .to_return(body: load_fixture('contentful/simple_client/sync_initial.json'))

        # act
        items = []
        client.sync do |item|
          items << item.dig('sys', 'id')
        end

        # assert
        expect(items.count).to eq(34)
        expect(items.sort.take(5))
          .to eq(%w[
                   1EjBdAgOOgAQKAggQoY2as 1IJEXB4AKEqQYEm4WuceG2 1MsOLBrDwEUAUIuMY8Ys6o
                   1TikjmGeSIisEWoC4CwokQ 1UojJt7YoMiemCq2mGGUmQ
                 ])
      end

      it 'returns next sync token' do
        stub_request(:get, "#{cdn_base}/sync?initial=true")
          .to_return(body: load_fixture('contentful/simple_client/sync_initial.json'))

        # act
        next_sync_token = client.sync {}

        # assert
        expect(next_sync_token)
          .to eq('w5ZGw6JFwqZmVcKsE8Kow4grw45QdybCpsOKdcK_ZjDCpMOFwpXDq8KRUE1Fw613K8KyA8OIwqv' \
                 'CtDfChhbCpsO7CjfDssOKw7YtXMOnwobDjcKrw7XDjMKHw7jCq8K1wrRRwpHCqMKIwr_DoMKSwrnCqS0' \
                 'qw47DkShzZ8K3V8KR')
      end

      it 'pages when theres a lot of items' do
        stub_request(:get, "#{cdn_base}/sync?initial=true")
          .to_return(body: load_fixture('contentful/simple_client/sync_paginated_initial.json'))

        sync_token = 'wonDrcKnRgcSOF4-wrDCgcKefWzCgsOxwrfCq8KOfMOdXUPCvEnChwEEO8KFwqHDj8KxwrzDmk' \
                     'TCrsKWUwnDiFczCULDs08Pw5LDj1DCr8KQwoEVw7dBdhPDi23DrsKlwoPDkcKESGfCt8Kyw5hnDcOEwrkMOjL' \
                     'CtsOZwqzDh8OAI3ZEW8K0fELDqMKAw73DoFo-RV_DsRVteRhXw7LDulU4worCgsOlRsOVworCtgrCpnkqTBdG' \
                     'w6PDt8OYOcOHDw'
        stub_request(:get, "#{cdn_base}/sync?sync_token=#{sync_token}")
          .to_return(body: load_fixture('contentful/simple_client/sync_paginated_page_2.json'))

        sync_token = 'wonDrcKnRgcSOF4-wrDCgcKefWzCgsOxwrfCq8KOfMOdXUPCvEnChwEEO8KFwqHDj8KxwrzDmk' \
                     'TCrsKWUwnDiFczCULDs08Pw5LDj1DCr8KQwoEVw7dBdhPDi23DrsKlwoPDkcKESGfCt8Kyw5hnDcOEwrkMOjL' \
                     'CtsOZCiV0HMKKw4rDpcKXwpXCh1vDlVMPRcOLYMKzw7HDucOFbsKSZ3pqTcONwqxXw43CssKgP8Oqw7HCqnPC' \
                     'nsOpdXfCksO1fVfDsDM'
        stub_request(:get, "#{cdn_base}/sync?sync_token=#{sync_token}")
          .to_return(body: load_fixture('contentful/simple_client/sync_paginated_page_3.json'))

        # act
        items = []
        client.sync do |item|
          items << item
        end

        # assert
        expect(items.count).to be > 200
      end

      it 'accepts sync token' do
        sync_token = 'w5ZGw6JFwqZmVcKsE8Kow4grw45QdybCpsOKdcK_ZjDCpMOFwpXDq8' \
                     'KRUE1Fw613K8KyA8OIwqvCtDfChhbCpsO7CjfDssOKw7YtXMOnwobDjcKrw7XDjMK' \
                     'Hw7jCq8K1wrRRwpHCqMKIwr_DoMKSwrnCqS0qw47DkShzZ8K3V8KR'
        stub_request(:get, "#{cdn_base}/sync?sync_token=#{sync_token}")
          .to_return(body: {
            'sys' => {
              'type' => 'Array'
            },
            'items' => [],
            nextSyncUrl: "#{cdn_base}/sync?sync_token=another-sync-token"
          }.to_json)

        # act
        items = []
        client.sync(sync_token: sync_token) do |item|
          items << item
        end

        # assert
        expect(items).to eq([])
      end

      context 'with deprecated response syntax' do
        it 'gives sync token from end of pagination' do
          stub_request(:get, "#{cdn_base}/sync?initial=true")
            .to_return(body: load_fixture('contentful/simple_client/sync_paginated_initial.json'))

          sync_token = 'wonDrcKnRgcSOF4-wrDCgcKefWzCgsOxwrfCq8KOfMOdXUPCvEnChwEEO8KFwqHDj8KxwrzDmk' \
                       'TCrsKWUwnDiFczCULDs08Pw5LDj1DCr8KQwoEVw7dBdhPDi23DrsKlwoPDkcKESGfCt8Kyw5hnDcOEwrkMOjL' \
                       'CtsOZwqzDh8OAI3ZEW8K0fELDqMKAw73DoFo-RV_DsRVteRhXw7LDulU4worCgsOlRsOVworCtgrCpnkqTBdG' \
                       'w6PDt8OYOcOHDw'
          stub_request(:get, "#{cdn_base}/sync?sync_token=#{sync_token}")
            .to_return(body: load_fixture('contentful/simple_client/sync_paginated_page_2.json'))

          sync_token = 'wonDrcKnRgcSOF4-wrDCgcKefWzCgsOxwrfCq8KOfMOdXUPCvEnChwEEO8KFwqHDj8KxwrzDmk' \
                       'TCrsKWUwnDiFczCULDs08Pw5LDj1DCr8KQwoEVw7dBdhPDi23DrsKlwoPDkcKESGfCt8Kyw5hnDcOEwrkMOjL' \
                       'CtsOZCiV0HMKKw4rDpcKXwpXCh1vDlVMPRcOLYMKzw7HDucOFbsKSZ3pqTcONwqxXw43CssKgP8Oqw7HCqnPC' \
                       'nsOpdXfCksO1fVfDsDM'
          stub_request(:get, "#{cdn_base}/sync?sync_token=#{sync_token}")
            .to_return(body: load_fixture('contentful/simple_client/sync_paginated_page_3.json'))

          # act
          resp = client.sync

          # assert
          resp.assert_ok!
          resp.items.force
          expect(resp.next_sync_token)
            .to eq('w5ZGw6JFwqZmVcKsE8Kow4grw45QdybCrcOgWcKuXTjCjsK2H8KwLwTDuHnDr1HCiybCuBTCi8O_w4Q3wpPDg2fCtx' \
                   '5mWcOKwrMnFmxWcjjCmDbDj8KbYMOowozCkwfDncOEYCLDtMKaRcOIw4U8w5PCijLDsiMD')
        end
      end

      it 'notifies' do
        stub_request(:get, "#{cdn_base}/sync?initial=true")
          .to_return(body: load_fixture('contentful/simple_client/sync_initial.json'))

        expect {
          client.sync {}
        }.to instrument('get_http.simpleclient.contentful.wcc')

        expect {
          client.sync
        }.to instrument('sync.simpleclient.contentful.wcc')
      end
    end

    describe 'tags' do
      it 'gets all tags' do
        stub_request(:get, "#{cdn_base}/tags")
          .to_return(body: load_fixture('contentful/simple_client/tags.json'))

        # act
        resp = client.tags

        # assert
        resp.assert_ok!
        expect(resp.status).to eq(200)
        expect(resp.to_json['items'].length).to eq(1)

        tag = resp.to_json['items'][0]
        expect(tag['name']).to eq('NY Campaign')
        expect(tag.dig('sys', 'id')).to eq('nyCampaign')
        expect(tag.dig('sys', 'visibility')).to eq('public')
        expect(tag.dig('sys', 'type')).to eq('Tag')
      end

      it 'gets tags with query params' do
        stub_request(:get, "#{cdn_base}/tags?limit=2")
          .to_return(body: load_fixture('contentful/simple_client/tags.json'))

        # act
        resp = client.tags({ limit: 2 })

        # assert
        resp.assert_ok!
        expect(resp.status).to eq(200)
        expect(resp.to_json['items'].length).to eq(1)
      end

      it 'notifies' do
        stub_request(:get, "#{cdn_base}/tags")
          .to_return(body: load_fixture('contentful/simple_client/tags.json'))

        expect {
          client.tags
        }.to instrument('get_http.simpleclient.contentful.wcc')

        expect {
          client.tags
        }.to instrument('tags.simpleclient.contentful.wcc')
      end
    end

    describe 'tag' do
      it 'gets a single tag by ID' do
        stub_request(:get, "#{cdn_base}/tags/ministry-external-focus")
          .to_return(body: load_fixture('contentful/simple_client/single-tag.json'))

        # act
        resp = client.tag('ministry-external-focus')

        # assert
        resp.assert_ok!
        expect(resp.status).to eq(200)
        expect(resp.to_json['name']).to eq('Ministry: External Focus')
        expect(resp.to_json.dig('sys', 'id')).to eq('ministry-external-focus')
        expect(resp.to_json.dig('sys', 'visibility')).to eq('private')
        expect(resp.to_json.dig('sys', 'type')).to eq('Tag')
      end
    end
  end

  context 'with environment' do
    subject(:client) {
      WCC::Contentful::SimpleClient.new(
        api_url: 'https://cdn.contentful.com',
        access_token: contentful_access_token,
        space: contentful_space_id,
        environment: 'specs'
      )
    }

    describe 'get' do
      it 'gets entries with query params from environment' do
        fixture = JSON.parse(load_fixture('contentful/simple_client/entries_limit_2.json'))
        fixture['items'].each do |entry|
          entry['sys']['environment'] = { 'sys' => { 'id' => 'specs' } }
        end

        stub_request(:get, "#{cdn_base}/environments/specs/entries?limit=2")
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
        stub_request(:get, "#{cdn_base}/environments/specs/entries?content_type=page&limit=5")
          .to_return(body: load_fixture('contentful/simple_client/pages_first_page.json'))
        stub_request(:get, "#{cdn_base}/environments/specs/entries?content_type=page&limit=5&skip=5")
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
