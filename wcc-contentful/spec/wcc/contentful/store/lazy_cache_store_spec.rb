# frozen_string_literal: true

RSpec.describe WCC::Contentful::Store::LazyCacheStore do
  let(:cache) {
    ActiveSupport::Cache::MemoryStore.new
  }

  subject(:store) {
    WCC::Contentful::Store::LazyCacheStore.new(
      WCC::Contentful::SimpleClient::Cdn.new(
        access_token: contentful_access_token,
        space: contentful_space_id
      ),
      cache: cache
    )
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
    it 'finds and caches items from the backing API' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
          '/entries/47PsST8EicKgWIWwK2AsW6')
        .with(query: hash_including({ locale: '*' }))
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

    it 'instruments a find' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
          '/entries/47PsST8EicKgWIWwK2AsW6')
        .with(query: hash_including({ locale: '*' }))
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))

      expect {
        store.find('47PsST8EicKgWIWwK2AsW6')
      }.to instrument('find.store.contentful.wcc')
    end

    it 'instruments a cache hit' do
      cache.write('47PsST8EicKgWIWwK2AsW6',
        JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json')))

      expect {
        store.find('47PsST8EicKgWIWwK2AsW6')
      }.to instrument('fresh.lazycachestore.store.contentful.wcc')
    end

    it 'instruments a cache miss' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
          '/entries/47PsST8EicKgWIWwK2AsW6')
        .with(query: hash_including({ locale: '*' }))
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))

      expect {
        store.find('47PsST8EicKgWIWwK2AsW6')
      }.to instrument('miss.lazycachestore.store.contentful.wcc')
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
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
        '/entries/xxxxxxxxxxxxxxxxxxasdf')
        .with(query: hash_including({ locale: '*' }))
        .to_return(status: 404, body: not_found)
        .times(1)
        .then.to_raise('Should not hit the API a second time!')

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
        '/assets/xxxxxxxxxxxxxxxxxxasdf')
        .with(query: hash_including({ locale: '*' }))
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
        data = { token: 'jenny_8675309' }

        # assert
        expect { subject.set('sync:token', data) }.to_not raise_error
      end

      it 'should raise an error if the value is not a Hash' do
        data = 'jenny_8675309'
        expect { subject.set('sync:token', data) }.to raise_error(ArgumentError)
      end
    end

    it 'returns stored token if it exists in the cache' do
      data = { token: 'jenny_8675309' }

      store.set('sync:343qxys30lid:token', data)

      # act
      token = store.find('sync:343qxys30lid:token')

      # assert
      expect(token).to eq(data)
    end

    it 'passes options to backing CDN adapter' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
        '/entries/47PsST8EicKgWIWwK2AsW6')
        .with(query: hash_including({ 'locale' => '*', 'include' => '2' }))
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))

      # act
      page = store.find('47PsST8EicKgWIWwK2AsW6', include: 2, hint: 'Entry')

      # assert
      expect(page.dig('fields', 'heroText', 'en-US')).to eq('Some test hero text')
    end
  end

  describe '#find_all' do
    it 'does not read from cache for second hit' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          locale: '*',
          include: '2',
          content_type: 'menu',
          'fields.name.en-US' => 'Main Menu'
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

    it 'instruments find_all' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          include: '2',
          content_type: 'menu'
        }))
        .to_return(body: load_fixture('contentful/lazy_cache_store/query_main_menu.json'))

      expect {
        store.find_all(content_type: 'menu', options: { include: 2 })
      }.to instrument('find_all.store.contentful.wcc')
        .with(hash_including(
                content_type: 'menu',
                options: { include: 2 }
              ))
    end

    context 'cache_response: true' do
      it 'caches all response items' do
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
          .with(query: hash_including({
            locale: '*',
            content_type: 'menu',
            'fields.name.en-US' => 'Main Menu'
          }))
          .to_return(body: load_fixture('contentful/lazy_cache_store/query_main_menu.json'))

        # act
        main_menu = store.find_all(content_type: 'menu', options: { cache_response: true })
          .apply(name: 'Main Menu')
          .first

        # assert
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
            '/entries/FNlqULSV0sOy4IoGmyWOW')
          .with(query: hash_including({
            locale: '*'
          }))
          .to_raise('Should not hit the API a second time!')
        main_menu2 = store.find('FNlqULSV0sOy4IoGmyWOW')
        expect(main_menu2).to eq(main_menu)
      end

      it 'caches all response includes' do
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
          .with(query: hash_including({
            locale: '*',
            content_type: 'page'
          }))
          .to_return(body: load_fixture('contentful/lazy_cache_store/pages_include_2.json'))

        # act
        found = store.find_all(content_type: 'page', options: {
          limit: 5,
          include: 2,
          cache_response: true
        })
        _pages = found.take(5).force

        # assert
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
            '/entries/38ijVyGafC6ESQyk6uy2kw')
          .with(query: hash_including({
            locale: '*'
          }))
          .to_raise('Should not hit the API a second time!')
        cached_product_list = store.find('38ijVyGafC6ESQyk6uy2kw')
        expect(cached_product_list.dig('sys', 'id')).to eq('38ijVyGafC6ESQyk6uy2kw')
        expect(cached_product_list.dig('sys', 'type')).to eq('Entry')
        expect(cached_product_list.dig('fields', 'collectionId', 'en-US')).to eq('Z2lk...')
      end
    end

    context 'nil options' do
      it 'does not blow up...' do
        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
          .with(query: hash_including({
            locale: '*',
            content_type: 'menu',
            'fields.name.en-US' => 'Main Menu'
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
    let(:body) { load_fixture('contentful/lazy_cache_store/homepage_include_2.json') }
    let(:body_hash) { JSON.parse(body) }
    let(:page) { body_hash.dig('items', 0) }

    it 'returns a cached entry if looking up by sys.id' do
      store.set(page.dig('sys', 'id'), page)

      # act
      cached_page = store.find_by(content_type: 'page', filter: { 'sys.id' => page.dig('sys', 'id') })

      # assert
      expect(cached_page).to eq(page)
    end

    it 'falls back to a query if sys.id does not exist in cache' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          locale: '*',
          content_type: 'page',
          'sys.id' => page.dig('sys', 'id')
        }))
        .to_return(body: body)

      # act
      queried_page = store.find_by(content_type: 'page', filter: { 'sys.id' => page.dig('sys', 'id') })

      # assert
      expect(queried_page).to eq(page)
    end

    it 'stores returned object in cache' do
      id = page.dig('sys', 'id')
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries/#{id}")
        .with(query: hash_including({
          locale: '*'
        }))
        .to_return(body: page.to_json)
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          locale: '*',
          content_type: 'page',
          'sys.id' => id
        })).to_raise('Should not hit the API a second time!')

      # act
      # store it in the cache and then query again
      store.find(id)
      cached_page = store.find_by(content_type: 'page', filter: { 'sys.id' => id })

      # assert
      expect(cached_page).to eq(page)
    end

    it 'issues a query if looking up by any other field' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          locale: '*',
          content_type: 'page',
          'fields.slug.en-US' => '/'
        }))
        .to_return(body: body)

      store.set(page.dig('sys', 'id'), { 'sys' => { 'type' => 'not a page' } })

      # act - should not read from the cache
      queried_page = store.find_by(content_type: 'page', filter: { 'fields.slug' => '/' })

      # assert
      expect(queried_page).to eq(page)
    end

    it 'grabs included values when include parameter supplied' do
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          locale: '*',
          content_type: 'page',
          'fields.slug.en-US' => '/'
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
      # Delete the section from the includes array - simulates it being unpublished
      section0_id = page.dig('fields', 'sections', 'en-US', 0, 'sys', 'id')
      includes_arr = body_hash.dig('includes', 'Entry')
      includes_arr.delete_at(includes_arr.find_index { |e| e.dig('sys', 'id') == section0_id })

      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
        .with(query: hash_including({
          locale: '*',
          content_type: 'page',
          'fields.slug.en-US' => '/'
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

    it 'instruments find_by' do
      store.set(page.dig('sys', 'id'), page)

      expect {
        store.find_by(content_type: 'page', filter: { 'sys.id' => page.dig('sys', 'id') })
      }.to instrument('find_by.store.contentful.wcc')
        .with(hash_including(
                content_type: 'page',
                filter: { 'sys.id' => page.dig('sys', 'id') }
              ))
    end

    context 'cache_response: true' do
      it 'overwrites included item in the cache' do
        section0_id = page.dig('fields', 'sections', 'en-US', 0, 'sys', 'id')
        includes_arr = body_hash.dig('includes', 'Entry')
        includes_arr.delete_at(includes_arr.find_index { |e| e.dig('sys', 'id') == section0_id })

        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
          .with(query: hash_including({
            locale: '*',
            content_type: 'page',
            'fields.slug.en-US' => '/'
          }))
          .to_return(body: body_hash.to_json)

        store.set(section0_id, {
          'sys' => {
            'id' => section0_id,
            'revision' => 1
          }
        })

        # act
        _queried_page = store.find_by(content_type: 'page',
                                      filter: { 'fields.slug' => '/' },
                                      options: { include: 2, cache_response: true })

        # assert
        cached_section0 = store.find(section0_id)
        expect(cached_section0).to eq({
          'sys' => {
            'id' => section0_id,
            'revision' => 1
          }
        })
      end

      it 'does not overwrite included item if it is missing' do
        # Delete the section from the includes array - simulates it being unpublished
        section0_id = page.dig('fields', 'sections', 'en-US', 0, 'sys', 'id')
        includes_arr = body_hash.dig('includes', 'Entry')
        section0 = includes_arr.find { |e| e.dig('sys', 'id') == section0_id }

        stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
          .with(query: hash_including({
            locale: '*',
            content_type: 'page',
            'fields.slug.en-US' => '/'
          }))
          .to_return(body: body_hash.to_json)

        store.set(section0_id, {
          'sys' => {
            'id' => section0_id,
            'revision' => 1
          }
        })

        # act
        _queried_page = store.find_by(content_type: 'page',
                                      filter: { 'fields.slug' => '/' },
                                      options: { include: 2, cache_response: true })

        # assert
        cached_section0 = store.find(section0_id)
        expect(cached_section0).to eq(section0)
      end
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
      req = stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
        '/entries/47PsST8EicKgWIWwK2AsW6')
        .with(query: hash_including({ locale: '*' }))
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))

      got = store.find('47PsST8EicKgWIWwK2AsW6')
      expect(got.dig('fields', 'heroText', 'en-US')).to eq('Some test hero text')
      expect(req).to have_been_requested
    end

    it 'updates the cache if the item was recently accessed' do
      original_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      store.set('47PsST8EicKgWIWwK2AsW6', original_about_page)

      updated_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      updated_about_page['fields']['heroText']['en-US'] = 'updated hero text'

      # act
      store.index(updated_about_page)

      # assert
      got = store.find('47PsST8EicKgWIWwK2AsW6')
      expect(got.dig('fields', 'heroText', 'en-US')).to eq('updated hero text')
    end

    it 'updates an "Entry" when exists' do
      existing = { 'test' => { 'data' => 'asdf' } }
      subject.set('1qLdW7i7g4Ycq6i4Cckg44', existing)

      # act
      latest = subject.index(entry)

      # assert
      expect(latest).to eq(entry)
      expect(subject.find('1qLdW7i7g4Ycq6i4Cckg44')).to eq(entry)
    end

    it 'does not overwrite an entry if revision is lower' do
      initial = entry
      updated = entry.deep_dup
      updated['sys']['revision'] = 2
      updated['fields']['slug']['en-US'] = 'test slug'

      subject.set(updated.dig('sys', 'id'), updated)

      # act
      latest = subject.index(initial)

      # assert
      expect(latest).to eq(updated)
      expect(subject.find('1qLdW7i7g4Ycq6i4Cckg44')).to eq(updated)
    end

    it 'removes a "DeletedEntry"' do
      existing = { 'test' => { 'data' => 'asdf' } }
      subject.set('6HQsABhZDiWmi0ekCouUuy', existing)

      # act
      latest = subject.index(deleted_entry)

      # assert
      expect(latest).to be_nil
      expect(subject.find('6HQsABhZDiWmi0ekCouUuy')).to be_nil
    end

    it 'does not remove if "DeletedEntry" revision is lower' do
      existing = entry
      existing['sys']['id'] = deleted_entry.dig('sys', 'id')
      existing['sys']['revision'] = deleted_entry.dig('sys', 'revision') + 1
      subject.set(existing.dig('sys', 'id'), existing)

      # act
      latest = subject.index(deleted_entry)

      # assert
      expect(latest).to eq(existing)
      expect(subject.find(deleted_entry.dig('sys', 'id'))).to eq(existing)
    end

    it 'instruments index - no set when entry not cached' do
      expect {
        expect {
          # act
          subject.index(entry)
        }.to instrument('index.store.contentful.wcc')
          .with(hash_including(id: '1qLdW7i7g4Ycq6i4Cckg44'))
      }.to_not instrument('set.store.contentful.wcc')
    end

    it 'instruments index - set when entry cached' do
      new_entry = entry.merge({
        'sys' => entry['sys'].merge({ 'revision': 2 })
      })
      subject.set('1qLdW7i7g4Ycq6i4Cckg44', entry)

      expect {
        expect {
          # act
          subject.index(new_entry)
        }.to instrument('index.store.contentful.wcc')
          .with(hash_including(id: '1qLdW7i7g4Ycq6i4Cckg44'))
      }.to instrument('set.store.contentful.wcc')
        .with(hash_including(id: '1qLdW7i7g4Ycq6i4Cckg44'))
    end

    it 'instruments index delete' do
      existing = { 'test' => { 'data' => 'asdf' } }
      subject.set('6HQsABhZDiWmi0ekCouUuy', existing)

      expect {
        expect {
          # act
          subject.index(deleted_entry)
        }.to instrument('index.store.contentful.wcc')
          .with(hash_including(id: '6HQsABhZDiWmi0ekCouUuy'))
      }.to instrument('delete.store.contentful.wcc')
        .with(hash_including(id: '6HQsABhZDiWmi0ekCouUuy'))
    end
  end
end
