# frozen_string_literal: true

RSpec.describe WCC::Contentful::Store::LazyCacheStore do
  subject(:store) {
    WCC::Contentful::Store::LazyCacheStore.new(
      WCC::Contentful::SimpleClient::Cdn.new(
        access_token: contentful_access_token,
        space: contentful_space_id
      )
    )
  }

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
  end

  it 'delegates #find_all to the API and does not cache them' do
    stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
      .with(query: hash_including({
        locale: '*',
        content_type: 'menu',
        'fields.name.en-US' => 'Main Menu'
      }))
      .to_return(body: load_fixture('contentful/lazy_cache_store/query_main_menu.json'))
      .times(2)

    # act
    main_menu = store.find_all(content_type: 'menu')
      .apply(name: 'Main Menu')
      .first

    # assert
    expect(main_menu.dig('sys', 'id')).to eq('FNlqULSV0sOy4IoGmyWOW')
    main_menu2 = store.find_all(content_type: 'menu')
      .apply(name: 'Main Menu')
      .first
    expect(main_menu2).to eq(main_menu)
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
  end
end
