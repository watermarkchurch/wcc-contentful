# frozen_string_literal: true

RSpec.describe WCC::Contentful::ModelBuilder do
  subject {
    WCC::Contentful::ModelBuilder.new(types)
  }

  after(:each) do
    @schema&.each do |c|
      WCC::Contentful::Model.send(:remove_const, c.to_s.split(':').last)
    end
  end
  let(:types) { load_indexed_types }
  let!(:store) {
    load_store_from_sync
  }

  it 'builds models from loaded types' do
    # act
    @schema = subject.build_models

    # assert
    expect(@schema.map(&:to_s).sort).to eq(
      %w[
        WCC::Contentful::Model::Asset
        WCC::Contentful::Model::Dog
        WCC::Contentful::Model::Faq
        WCC::Contentful::Model::Homepage
        WCC::Contentful::Model::Menu
        WCC::Contentful::Model::MenuButton
        WCC::Contentful::Model::MigrationHistory
        WCC::Contentful::Model::Ministry
        WCC::Contentful::Model::MinistryCard
        WCC::Contentful::Model::Page
        WCC::Contentful::Model::Redirect2
        WCC::Contentful::Model::Section_CardSearch
        WCC::Contentful::Model::Section_Faq
        WCC::Contentful::Model::Section_Testimonials
        WCC::Contentful::Model::Section_VideoHighlight
        WCC::Contentful::Model::Testimonial
        WCC::Contentful::Model::Theme
      ]
    )

    expect(WCC::Contentful::Model.all_models).to include(WCC::Contentful::Model::Page)
  end

  it 'finds types by ID' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    main_menu = WCC::Contentful::Model.find('FNlqULSV0sOy4IoGmyWOW')

    # assert
    expect(main_menu).to be_instance_of(WCC::Contentful::Model::Menu)
    expect(main_menu.id).to eq('FNlqULSV0sOy4IoGmyWOW')
    expect(main_menu.created_at).to eq(Time.parse('2018-02-12T20:09:38.819Z'))
    expect(main_menu.updated_at).to eq(Time.parse('2018-02-12T21:59:43.653Z'))
    expect(main_menu.revision).to eq(2)
    expect(main_menu.space).to eq('343qxys30lid')

    expect(main_menu.name).to eq('Main Menu')
  end

  it 'finds by ID on derived class' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    main_menu = WCC::Contentful::Model::Menu.find('FNlqULSV0sOy4IoGmyWOW')

    # assert
    expect(main_menu).to be_instance_of(WCC::Contentful::Model::Menu)
    expect(main_menu.id).to eq('FNlqULSV0sOy4IoGmyWOW')
    expect(main_menu.created_at).to eq(Time.parse('2018-02-12T20:09:38.819Z'))
    expect(main_menu.updated_at).to eq(Time.parse('2018-02-12T21:59:43.653Z'))
    expect(main_menu.revision).to eq(2)
    expect(main_menu.space).to eq('343qxys30lid')

    expect(main_menu.name).to eq('Main Menu')
  end

  it 'returns nil if cannot find ID' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    main_menu = WCC::Contentful::Model::Menu.find('asdf')

    # assert
    expect(main_menu).to be_nil
  end

  it 'errors fast if ID is wrong content type' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    expect {
      _actually_a_menu = WCC::Contentful::Model::Page.find('FNlqULSV0sOy4IoGmyWOW')
    }.to raise_error(ArgumentError)
  end

  it 'finds types by content type' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    menu_items = WCC::Contentful::Model::MenuButton.find_all

    # assert
    expect(menu_items.length).to eq(11)
    expect(menu_items.map(&:id).sort).to eq(
      %w[
        1EjBdAgOOgAQKAggQoY2as
        1IJEXB4AKEqQYEm4WuceG2
        1TikjmGeSIisEWoC4CwokQ
        2X7Pm2VQmQyAWK0y2wy8me
        3Jmk4yOwhOY0yKsI6mAQ2a
        3bZRv5ISCkui6kguIwM2U0
        4Gye0ybf2EiWCgSyEg0cyE
        4W3ADPamKsMOg6Gu8aGwOu
        4tMhra8IAwcEoKS6QSQYcc
        5NBhDw3i2kUqSwqYok4YQO
        ZosJIuGfgkky0cA2GsymW
      ]
    )
    menu_item = menu_items.find { |i| i.id == '4tMhra8IAwcEoKS6QSQYcc' }
    expect(menu_item.custom_button_css).to eq(
      [
        'text-decoration: underline;',
        'color: brown;'
      ]
    )
  end

  it 'finds with filter' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    menu_items = WCC::Contentful::Model::MenuButton.find_by(button_style: 'custom')

    # assert
    expect(menu_items.length).to eq(2)
    expect(menu_items.map(&:id).sort).to eq(
      %w[3bZRv5ISCkui6kguIwM2U0 4tMhra8IAwcEoKS6QSQYcc]
    )
  end

  it 'finds single item with filter' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    redirect = WCC::Contentful::Model::Redirect2.find_by(slug: 'mister_roboto')

    # assert
    expect(redirect.length).to eq(1)
    expect(redirect[0].pageReference.title).to eq('Conferences')
  end

  it 'resolves numeric fields' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    faq = WCC::Contentful::Model::Faq.find_all.first

    # assert
    expect(faq.num_faqs).to eq(2)
    expect(faq.num_faqs_float).to eq(2.1)
  end

  it 'resolves date times and json blobs' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    migration = WCC::Contentful::Model::MigrationHistory.find_all.first

    # assert
    expect(migration.started).to eq(Time.zone.parse('2018-02-22T21:12:45.621Z'))
    expect(migration.completed).to eq(Time.zone.parse('2018-02-22T21:12:46.699Z'))

    expect(migration.detail).to be_instance_of(Array)
    expect(migration.detail[0]).to be_instance_of(OpenStruct)
    expect(migration.detail.dig(0, 'intent', 'intents')).to include(
      {
        'meta' => {
          'callsite' => {
            'file' =>
              '/Users/gburgett/projects/wm/jtj-com/db/migrate/20180219160530_test_migration.ts',
            'line' => 3
          },
          'contentTypeInstanceId' => 'contentType/dog/0'
        },
        'type' => 'contentType/create',
        'payload' => {
          'contentTypeId' => 'dog'
        }
      }
    )
  end

  it 'resolves coordinates' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    faq = WCC::Contentful::Model::Faq.find('1nzrZZShhWQsMcey28uOUQ')

    # assert
    expect(faq.placeOfFaq.lat).to eq(52.5391688192368)
    expect(faq.placeOfFaq.lon).to eq(13.4033203125)
  end

  it 'resolves linked types' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    main_menu = WCC::Contentful::Model::Menu.find('FNlqULSV0sOy4IoGmyWOW')

    # assert
    expect(main_menu.hamburger).to be_instance_of(WCC::Contentful::Model::Menu)
    expect(main_menu.hamburger.buttons[0]).to be_instance_of(WCC::Contentful::Model::MenuButton)
    expect(main_menu.hamburger.buttons[0].link).to be_instance_of(WCC::Contentful::Model::Page)
    expect(main_menu.hamburger.buttons[0].link.title).to eq('About')
  end

  it 'handles nil linked types' do
    subject.build_models
    WCC::Contentful::Model.store = store

    # act
    ministries_page = WCC::Contentful::Model::Page.find('JhYhSfZPAOMqsaK8cYOUK')

    # assert
    expect(ministries_page.sub_menu).to be_nil
  end

  it 'resolves linked assets' do
    @schema = subject.build_models
    WCC::Contentful::Model.store = store

    # act
    homepage = WCC::Contentful::Model::Homepage.find_all.first

    # assert
    expect(homepage.hero_image).to be_instance_of(WCC::Contentful::Model::Asset)
    expect(homepage.hero_image.file).to be_a(OpenStruct)
    expect(homepage.hero_image.title).to eq('worship')
    expect(homepage.hero_image.file['url']).to eq('//images.contentful.com/343qxys30lid/' \
      '572YrsdGZGo0sw2Www2Si8/545f53511e362a78a8f34e1837868256/worship.jpg')
    expect(homepage.hero_image.file['contentType']).to eq('image/jpeg')

    expect(homepage.favicons).to be_a(Array)
    expect(homepage.favicons.length).to eq(4)
    expect(homepage.favicons[0]).to be_instance_of(WCC::Contentful::Model::Asset)
    expect(homepage.favicons[0].file.fileName).to eq('favicon.ico')
  end
end
