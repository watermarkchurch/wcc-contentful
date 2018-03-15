# frozen_string_literal: true

RSpec.describe WCC::Contentful::Store::LazyCacheStore do
  subject(:store) {
    WCC::Contentful::Store::LazyCacheStore.new(
      client: WCC::Contentful::SimpleClient::Cdn.new(
        access_token: contentful_access_token,
        space: contentful_space_id
      )
    )
  }

  before do
    store.cache.clear
  end

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

  it 'delegates queries to the API and does not cache them' do
    stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}/entries")
      .with(query: hash_including({
        locale: '*',
        content_type: 'menu',
        'fields.name.en-US' => 'Main Menu'
      }))
      .to_return(body: load_fixture('contentful/lazy_cache_store/query_main_menu.json'))
      .times(2)

    # act
    main_menu = store.find_by(content_type: 'menu')
      .eq('name', 'Main Menu')
      .first

    # assert
    expect(main_menu.dig('sys', 'id')).to eq('FNlqULSV0sOy4IoGmyWOW')
    main_menu2 = store.find_by(content_type: 'menu')
      .eq('name', 'Main Menu')
      .first
    expect(main_menu2).to eq(main_menu)
  end

  describe '#index' do
    it 'does not update the cache if the item has not been accessed recently' do
      updated_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      updated_about_page['fields']['heroText']['en-US'] = 'updated hero text'

      # act
      store.index('47PsST8EicKgWIWwK2AsW6', updated_about_page)

      # assert
      # in the find, it will reach out to the CDN because it was not stored.
      stub_request(:get, "https://cdn.contentful.com/spaces/#{contentful_space_id}"\
        '/entries/47PsST8EicKgWIWwK2AsW6')
        .with(query: hash_including({ locale: '*' }))
        .to_return(body: load_fixture('contentful/lazy_cache_store/page_about.json'))

      got = store.find('47PsST8EicKgWIWwK2AsW6')
      expect(got.dig('fields', 'heroText', 'en-US')).to eq('Some test hero text')
    end

    it 'updates the cache if the item was recently accessed' do
      original_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      store.cache.write('47PsST8EicKgWIWwK2AsW6', original_about_page)

      updated_about_page = JSON.parse(load_fixture('contentful/lazy_cache_store/page_about.json'))
      updated_about_page['fields']['heroText']['en-US'] = 'updated hero text'

      # act
      store.index('47PsST8EicKgWIWwK2AsW6', updated_about_page)

      # assert
      got = store.find('47PsST8EicKgWIWwK2AsW6')
      expect(got.dig('fields', 'heroText', 'en-US')).to eq('updated hero text')
    end
  end
end
