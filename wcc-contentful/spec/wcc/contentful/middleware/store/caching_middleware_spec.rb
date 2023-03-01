# frozen_string_literal: true

RSpec.describe WCC::Contentful::Middleware::Store::CachingMiddleware do
  include WCC::Contentful::EntryLocaleTransformer

  let(:configuration) {
    WCC::Contentful::Configuration.new.tap do |config|
      config.locale_fallbacks = {
        'es' => 'en-US'
      }
    end
  }

  let(:cache) {
    ActiveSupport::Cache::MemoryStore.new
  }

  subject(:store) {
    described_class.new(cache).tap do |middleware|
      middleware.store =
        WCC::Contentful::Store::CDNAdapter.new(
          WCC::Contentful::SimpleClient::Cdn.new(
            access_token: contentful_access_token,
            space: contentful_space_id
          )
        )
    end
  }

  before do
    content_types = JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
    indexer = WCC::Contentful::ContentTypeIndexer.new
    content_types['items'].each do |raw_content_type|
      indexer.index(raw_content_type)
    end
    allow(WCC::Contentful).to receive(:types)
      .and_return(indexer.types)
    allow(WCC::Contentful).to receive(:configuration)
      .and_return(configuration)
  end

  describe '#find' do
    it 'finds and caches items from the backing API' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                         '/entries/47PsST8EicKgWIWwK2AsW6')
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))
        .times(1)
        .then.to_raise('Should not hit the API a second time!')

      # act
      page = store.find('47PsST8EicKgWIWwK2AsW6')

      # assert
      expect(page.dig('fields', 'heroText', 'en-US')).to eq('Some test hero text')

      # should not hit the API again
      page2 = store.find('47PsST8EicKgWIWwK2AsW6')
      expect(page2).to eq(page)
    end

    it 'uses configured expires_in' do
      subject.expires_in = 30.days

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                         '/entries/47PsST8EicKgWIWwK2AsW6')
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))
        .times(1)
        .then.to_raise('Should not hit the API a second time!')

      # assert
      expect(cache).to receive(:fetch)
        .with('47PsST8EicKgWIWwK2AsW6', expires_in: 30.days)

      # act
      store.find('47PsST8EicKgWIWwK2AsW6')
    end

    it 'instruments a cache hit' do
      cache.write('47PsST8EicKgWIWwK2AsW6',
        JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json')))

      expect {
        store.find('47PsST8EicKgWIWwK2AsW6')
      }.to instrument('fresh.cachingmiddleware.store.middleware.contentful.wcc')
    end

    it 'instruments a cache miss' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                         '/entries/47PsST8EicKgWIWwK2AsW6')
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))

      expect {
        store.find('47PsST8EicKgWIWwK2AsW6')
      }.to instrument('miss.cachingmiddleware.store.middleware.contentful.wcc')
    end

    let(:not_found) {
      <<~JSON
        {
          "sys": {
            "type": "Error",
            "id": "NotFound"
          },
          "message": "The resource could not be found.",
          "details": {
            "id": "asdf",
            "type": "Entry",
            "space": "343qxys30lid"
          },
          "requestId": "05dcc4dadac53dc61cf0a348ae2b04eb"
        }
      JSON
    }

    it 'finds and caches nils from the backing API' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                         '/entries/xxxxxxxxxxxxxxxxxxasdf')
        .to_return(status: 404, body: not_found)
        .times(1)
        .then.to_raise('Should not hit the API a second time!')

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                         '/assets/xxxxxxxxxxxxxxxxxxasdf')
        .to_return(status: 404, body: not_found)
        .times(1)

      # act
      page = store.find('xxxxxxxxxxxxxxxxxxasdf')

      # assert
      expect(page).to be_nil

      # should not hit the API again
      page2 = store.find('xxxxxxxxxxxxxxxxxxasdf')
      expect(page2).to be_nil
    end

    it 'does not hit the backing API for sync token' do
      # act
      token = store.find('sync:343qxys30lid:token')

      # assert
      expect(token).to be_nil
    end

    describe 'ensures that the stored value is of type Hash' do
      it 'should not raise an error if value is a Hash' do
        data = {
          'sys' => { 'id' => 'sync:token', 'type' => 'token' },
          'data' => { token: 'jenny_8675309' }
        }

        # assert
        expect { subject.index(data) }.to_not raise_error
      end

      it 'should raise an error if the value is not a Hash' do
        data = 'jenny_8675309'
        expect { subject.index(data) }.to raise_error(ArgumentError)
      end
    end

    it 'returns stored token if it exists in the cache' do
      data = {
        'sys' => { 'id' => 'sync:343qxys30lid:token', 'type' => 'token' },
        'data' => { 'token' => 'jenny_8675309' }
      }

      cache.write('sync:343qxys30lid:token', data)

      # act
      token = store.find('sync:343qxys30lid:token')

      # assert
      expect(token.dig('data', 'token')).to eq('jenny_8675309')
    end

    it 'passes options to backing CDN adapter' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                         '/entries/47PsST8EicKgWIWwK2AsW6')
        .with(query: hash_including({ 'include' => '2' }))
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))

      # act
      page = store.find('47PsST8EicKgWIWwK2AsW6', include: 2, hint: 'Entry')

      # assert
      expect(page.dig('fields', 'heroText', 'en-US')).to eq('Some test hero text')
    end

    it 'does not hit backing API if indexed for locale' do
      entry = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      localized_entry = transform_to_locale(entry, 'en-US')
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                         '/entries/47PsST8EicKgWIWwK2AsW6?locale=en-US')
        .to_return(body: localized_entry.to_json)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                         '/entries/47PsST8EicKgWIWwK2AsW6?locale=es')
        .to_raise('Should not hit the API a second time!')

      # prime the cache w/ en-US version
      _page = store.find('47PsST8EicKgWIWwK2AsW6', locale: 'en-US')
      # we got an update!  Index the cache with the all-locales version
      entry['sys']['revision'] = entry['sys']['revision'] + 1
      entry['fields']['title']['en-US'] = 'About 2'
      entry['fields']['title']['es'] = 'Sobre 2'

      store.index(entry)

      # act - get es version
      page = store.find('47PsST8EicKgWIWwK2AsW6', locale: 'es')

      # assert
      page = transform_to_locale(page, 'es')
      expect(page.dig('fields', 'heroText')).to eq('Algun texto de prueba')
    end
  end

  describe '#find_all' do
    it 'does not read from cache for second hit' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          include: '2',
          content_type: 'menu',
          'fields.name' => 'Main Menu'
        }))
        .to_return(body: load_fixture('contentful/lazy_cache_store/query_main_menu.json'))
        .times(2)

      # act
      main_menu = store.find_all(content_type: 'menu', options: { include: 2 })
        .apply(name: 'Main Menu')
        .first

      # assert
      expect(main_menu.dig('sys', 'id')).to eq('FNlqULSV0sOy4IoGmyWOW')
      main_menu2 = store.find_all(content_type: 'menu', options: { include: 2 })
        .apply(name: 'Main Menu')
        .first
      expect(main_menu2).to eq(main_menu)
    end

    context 'nil options' do
      it 'does not blow up...' do
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
          .with(query: hash_including({
            content_type: 'menu',
            'fields.name' => 'Main Menu'
          }))
          .to_return(body: load_fixture('contentful/lazy_cache_store/query_main_menu.json'))
          .times(2)

        # act
        store.find_all(content_type: 'menu')
          .apply(name: 'Main Menu')
          .first
      end
    end
  end

  describe '#find_by' do
    it 'returns a cached entry if looking up by sys.id' do
      page = JSON.parse(load_fixture('contentful/lazy_cache_store/homepage_include_2.json')).dig('items', 0)
      cache.write(page.dig('sys', 'id'), page)

      # act
      cached_page = store.find_by(content_type: 'page', filter: { 'sys.id' => page.dig('sys', 'id') })

      # assert
      expect(cached_page).to eq(page)
    end

    it 'falls back to a query if sys.id does not exist in cache' do
      fixture = load_fixture('contentful/lazy_cache_store/homepage_include_2.json')
      page = JSON.parse(fixture).dig('items', 0)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          content_type: 'page',
          'sys.id' => page.dig('sys', 'id')
        }))
        .to_return(body: fixture)

      # act
      queried_page = store.find_by(content_type: 'page', filter: { 'sys.id' => page.dig('sys', 'id') })

      # assert
      expect(queried_page).to eq(page)
    end

    it 'stores returned object in cache' do
      fixture = load_fixture('contentful/lazy_cache_store/page_about.json')
      page = JSON.parse(fixture)

      id = page.dig('sys', 'id')
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries/#{id}")
        .to_return(body: page.to_json)
        .then.to_raise('Should not hit the API a second time!')

      # act
      # store it in the cache and then query again
      store.find(id)
      cached_page = store.find_by(content_type: 'page', filter: { 'sys.id' => id })

      # assert
      expect(cached_page).to eq(page)
    end

    it 'issues a query if looking up by any other field' do
      body = load_fixture('contentful/lazy_cache_store/homepage_include_2.json')
      page = JSON.parse(body).dig('items', 0)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          content_type: 'page',
          'fields.slug' => '/'
        }))
        .to_return(body: body)

      cache.write(page.dig('sys', 'id'), { 'sys' => { 'type' => 'not a page' } })

      # act - should not read from the cache
      queried_page = store.find_by(content_type: 'page', filter: { 'fields.slug' => '/' })

      # assert
      expect(queried_page).to eq(page)
    end

    it 'grabs included values when include parameter supplied' do
      body = load_fixture('contentful/lazy_cache_store/homepage_include_2.json')
      _page = JSON.parse(body).dig('items', 0)

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          content_type: 'page',
          'fields.slug' => '/'
        }))
        .to_return(body: body)

      # act
      queried_page = store.find_by(content_type: 'page',
        filter: { 'fields.slug' => '/' },
        options: { include: 2 })

      # assert
      section0 = queried_page.dig('fields', 'sections', 'en-US', 0)
      expect(section0.dig('sys', 'type')).to eq('Entry')
      bg_img = section0.dig('fields', 'backgroundImage', 'en-US')
      expect(bg_img.dig('sys', 'type')).to eq('Asset')
      expect(bg_img.dig('fields', 'title', 'en-US')).to eq('bg-watermark-mainpage-hero')
    end

    it 'does not resolve a missing link' do
      body = load_fixture('contentful/lazy_cache_store/homepage_include_2.json')
      body_hash = JSON.parse(body)
      page = body_hash.dig('items', 0)

      # Delete the section from the includes array - simulates it being unpublished
      section0_id = page.dig('fields', 'sections', 'en-US', 0, 'sys', 'id')
      includes_arr = body_hash.dig('includes', 'Entry')
      includes_arr.delete_at(includes_arr.find_index { |e| e.dig('sys', 'id') == section0_id })

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          content_type: 'page',
          'fields.slug' => '/'
        }))
        .to_return(body: body_hash.to_json)

      # act
      queried_page = store.find_by(content_type: 'page',
        filter: { 'fields.slug' => '/' },
        options: { include: 2 })

      # assert
      section0 = queried_page.dig('fields', 'sections', 'en-US', 0)
      expect(section0.dig('sys', 'type')).to eq('Link')
      section1 = queried_page.dig('fields', 'sections', 'en-US', 1)
      expect(section1.dig('sys', 'type')).to eq('Entry')
    end

    it 'maintains separate cache per locale' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries/58IzCq6qGPFelU77b4R8rP")
        .to_return(body: <<~JSON)
          {
            "sys": {
              "space": {
                "sys": {
                  "type": "Link",
                  "linkType": "Space",
                  "id": "4gyidsb2jx1u"
                }
              },
              "id": "58IzCq6qGPFelU77b4R8rP",
              "type": "Entry",
              "contentType": {
                "sys": {
                  "type": "Link",
                  "linkType": "ContentType",
                  "id": "sectionHero"
                }
              },
              "locale": "en-US"
            },
            "fields": {
              "title": "Homepage Hero",
              "subtitle": "This is the Homepage",
              "heroImage": {
                "sys": {
                  "type": "Link",
                  "linkType": "Asset",
                  "id": "5NlJ0zsfx7ugCgZoPNDDf2"
                }
              }
            }
          }
        JSON

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries/58IzCq6qGPFelU77b4R8rP?locale=es")
        .to_return(body: <<~JSON)
          {
            "sys": {
              "space": {
                "sys": {
                  "type": "Link",
                  "linkType": "Space",
                  "id": "4gyidsb2jx1u"
                }
              },
              "id": "58IzCq6qGPFelU77b4R8rP",
              "type": "Entry",
              "contentType": {
                "sys": {
                  "type": "Link",
                  "linkType": "ContentType",
                  "id": "sectionHero"
                }
              },
              "locale": "es"
            },
            "fields": {
              "title": "Homepage Hero",
              "subtitle": "Esta es la página principal",
              "heroImage": {
                "sys": {
                  "type": "Link",
                  "linkType": "Asset",
                  "id": "5NlJ0zsfx7ugCgZoPNDDf2"
                }
              }
            }
          }
        JSON

      # prime the cache with the en-US entry
      store.find('58IzCq6qGPFelU77b4R8rP')

      # act - go fetch the 'es' entry
      page = store.find('58IzCq6qGPFelU77b4R8rP', locale: 'es')

      # assert
      expect(page.dig('fields', 'subtitle')).to eq(
        'Esta es la página principal'
      )
    end
  end

  describe '#index' do
    let(:entry) {
      JSON.parse(<<~JSON)
        {
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "343qxys30lid"
              }
            },
            "id": "1qLdW7i7g4Ycq6i4Cckg44",
            "type": "Entry",
            "createdAt": "2018-03-09T23:39:27.737Z",
            "updatedAt": "2018-03-09T23:39:27.737Z",
            "revision": 1,
            "contentType": {
              "sys": {
                "type": "Link",
                "linkType": "ContentType",
                "id": "redirect"
              }
            }
          },
          "fields": {
            "slug": {
              "en-US": "redirect-with-slug-and-url"
            },
            "url": {
              "en-US": "http://www.google.com"
            }
          }
        }
      JSON
    }

    let(:deleted_entry) {
      JSON.parse(<<~JSON)
        {
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "343qxys30lid"
              }
            },
            "id": "6HQsABhZDiWmi0ekCouUuy",
            "type": "DeletedEntry",
            "createdAt": "2018-03-13T19:45:44.454Z",
            "updatedAt": "2018-03-13T19:45:44.454Z",
            "deletedAt": "2018-03-13T19:45:44.454Z",
            "environment": {
              "sys": {
                "type": "Link",
                "linkType": "Environment",
                "id": "98322ee2-6dee-4651-b3a5-743be50fb107"
              }
            },
            "revision": 1
          }
        }
      JSON
    }

    let(:deleted_asset) {
      JSON.parse(<<~JSON)
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
            "type": "DeletedAsset",
            "createdAt": "2018-03-20T18:44:58.270Z",
            "updatedAt": "2018-03-20T18:44:58.270Z",
            "deletedAt": "2018-03-20T18:44:58.270Z",
            "environment": {
              "sys": {
                "type": "Link",
                "linkType": "Environment",
                "id": "98322ee2-6dee-4651-b3a5-743be50fb107"
              }
            },
            "revision": 1
          }
        }
      JSON
    }

    it 'does not update the cache if the item has not been accessed recently' do
      updated_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      updated_about_page['fields']['heroText']['en-US'] = 'updated hero text'

      # act
      store.index(updated_about_page)

      # assert
      # in the find, it will reach out to the CDN because it was not stored.
      req = stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}" \
                               '/entries/47PsST8EicKgWIWwK2AsW6')
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))

      got = store.find('47PsST8EicKgWIWwK2AsW6')
      expect(got.dig('fields', 'heroText', 'en-US')).to eq('Some test hero text')
      expect(req).to have_been_requested
    end

    it 'always writes to the cache for the sync token' do
      token = {
        'sys' => {
          'id' => 'sync:token',
          'type' => 'token'
        },
        'token' => '1234'
      }
      # act
      store.index(token)

      # assert
      got = store.find('sync:token')
      expect(got['token']).to eq('1234')
    end

    it 'updates the cache if the item was recently accessed' do
      original_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      cache.write('47PsST8EicKgWIWwK2AsW6', original_about_page)

      updated_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      updated_about_page['fields']['heroText']['en-US'] = 'updated hero text'

      # act
      store.index(updated_about_page)

      # assert
      got = store.find('47PsST8EicKgWIWwK2AsW6')
      expect(got.dig('fields', 'heroText', 'en-US')).to eq('updated hero text')
    end

    it 'uses configured expires_in' do
      subject.expires_in = 30.minutes

      original_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      cache.write('47PsST8EicKgWIWwK2AsW6', original_about_page)

      updated_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      updated_about_page['fields']['heroText']['en-US'] = 'updated hero text'

      # assert
      expect(cache).to receive(:write)
        .with('47PsST8EicKgWIWwK2AsW6', updated_about_page, expires_in: 30.minutes)

      # act
      store.index(updated_about_page)
    end

    it 'updates an "Entry" when exists' do
      existing = {
        'sys' => { 'type' => 'Entry', 'id' => entry.dig('sys', 'id') },
        'test' => { 'data' => 'asdf' }
      }
      cache.write(existing.dig('sys', 'id'), existing)

      # act
      latest = subject.index(entry)

      # assert
      expect(latest).to eq(entry)
      expect(subject.find(entry.dig('sys', 'id'))).to eq(entry)
    end

    it 'does not overwrite an entry if revision is lower' do
      initial = entry
      updated = entry.deep_dup
      updated['sys']['revision'] = 2
      updated['fields']['slug']['en-US'] = 'test slug'

      cache.write(updated.dig('sys', 'id'), updated)

      # act - write old data to the index method
      latest = subject.index(initial)

      # assert
      expect(latest).to eq(updated)
      expect(subject.find(initial.dig('sys', 'id'))).to eq(updated)
    end

    it 'removes a "DeletedEntry" and tracks that it was deleted' do
      existing = {
        'sys' => { 'type' => 'Entry', 'id' => deleted_entry.dig('sys', 'id') },
        'test' => { 'data' => 'asdf' }
      }
      cache.write(existing.dig('sys', 'id'), existing)

      # act
      latest = subject.index(deleted_entry)

      # assert
      expect(latest).to be_nil
      # This call should not hit the CDN.  If VCR complains, then the CachingMiddleware
      # did not properly store the deletion.
      expect(subject.find('6HQsABhZDiWmi0ekCouUuy')).to be_nil
    end

    it 'does not remove if "DeletedEntry" revision is lower' do
      existing = entry
      existing['sys']['id'] = deleted_entry.dig('sys', 'id')
      existing['sys']['revision'] = deleted_entry.dig('sys', 'revision') + 1
      cache.write(existing.dig('sys', 'id'), existing)

      # act
      latest = subject.index(deleted_entry)

      # assert
      expect(latest).to eq(existing)
      expect(subject.find(deleted_entry.dig('sys', 'id'))).to eq(existing)
    end

    it 'instruments index - no set when entry not cached' do
      expect {
        # act
        subject.index(entry)
      }.to_not instrument('set.cachingmiddleware.store.middleware.contentful.wcc')
    end

    it 'instruments index - set when entry cached' do
      new_entry = entry.merge({
        'sys' => entry['sys'].merge({ revision: 2 })
      })
      cache.write(entry.dig('sys', 'id'), entry)

      expect {
        # act
        subject.index(new_entry)
      }.to instrument('set.cachingmiddleware.store.middleware.contentful.wcc')
        .with(hash_including(id: '1qLdW7i7g4Ycq6i4Cckg44'))
    end

    it 'instruments index delete' do
      existing = {
        'sys' => { 'type' => 'Entry', 'id' => deleted_entry.dig('sys', 'id') },
        'test' => { 'data' => 'asdf' }
      }
      cache.write(existing.dig('sys', 'id'), existing)

      expect {
        # act
        subject.index(deleted_entry)
      }.to instrument('delete.cachingmiddleware.store.middleware.contentful.wcc')
        .with(hash_including(id: deleted_entry.dig('sys', 'id')))
    end
  end
end
