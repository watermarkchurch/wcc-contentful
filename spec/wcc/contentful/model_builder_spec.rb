# frozen_string_literal: true

RSpec.describe WCC::Contentful::ModelBuilder do
  subject {
    WCC::Contentful::ModelBuilder.new(types)
  }

  let(:types) { load_indexed_types }
  let!(:store) {
    load_store_from_sync
  }

  before do
    allow(WCC::Contentful::Services.instance).to receive(:store)
      .and_return(store)
  end

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
        WCC::Contentful::Model::SectionCardsearch
        WCC::Contentful::Model::SectionFaq
        WCC::Contentful::Model::SectionTestimonials
        WCC::Contentful::Model::SectionVideohighlight
        WCC::Contentful::Model::Testimonial
        WCC::Contentful::Model::Theme
      ]
    )

    expect(WCC::Contentful::Model.constants(false)).to include(:Page)
  end

  it 'finds types by ID' do
    @schema = subject.build_models

    # act
    main_menu = WCC::Contentful::Model.find('FNlqULSV0sOy4IoGmyWOW')

    # assert
    expect(main_menu).to be_instance_of(WCC::Contentful::Model::Menu)
    expect(main_menu.id).to eq('FNlqULSV0sOy4IoGmyWOW')
    expect(main_menu.created_at).to eq(Time.parse('2018-02-12T20:09:38.819Z'))
    expect(main_menu.updated_at).to eq(Time.parse('2018-02-12T21:59:43.653Z'))
    expect(main_menu.revision).to eq(2)
    expect(main_menu.space).to eq(contentful_space_id)

    expect(main_menu.name).to eq('Main Menu')
  end

  it 'finds by ID on derived class' do
    @schema = subject.build_models

    # act
    main_menu = WCC::Contentful::Model::Menu.find('FNlqULSV0sOy4IoGmyWOW')

    # assert
    expect(main_menu).to be_instance_of(WCC::Contentful::Model::Menu)
    expect(main_menu.id).to eq('FNlqULSV0sOy4IoGmyWOW')
    expect(main_menu.created_at).to eq(Time.parse('2018-02-12T20:09:38.819Z'))
    expect(main_menu.updated_at).to eq(Time.parse('2018-02-12T21:59:43.653Z'))
    expect(main_menu.revision).to eq(2)
    expect(main_menu.space).to eq(contentful_space_id)

    expect(main_menu.name).to eq('Main Menu')
  end

  it 'returns nil if cannot find ID' do
    @schema = subject.build_models

    # act
    main_menu = WCC::Contentful::Model::Menu.find('asdf')

    # assert
    expect(main_menu).to be_nil
  end

  it 'errors fast if ID is wrong content type' do
    @schema = subject.build_models

    # act
    expect {
      _actually_a_menu = WCC::Contentful::Model::Page.find('FNlqULSV0sOy4IoGmyWOW')
    }.to raise_error(ArgumentError)
  end

  it 'finds types by content type' do
    @schema = subject.build_models

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

    # act
    menu_items = WCC::Contentful::Model::MenuButton.find_all(button_style: 'custom')

    # assert
    expect(menu_items.length).to eq(2)
    expect(menu_items.map(&:id).sort).to eq(
      %w[3bZRv5ISCkui6kguIwM2U0 4tMhra8IAwcEoKS6QSQYcc]
    )
  end

  it 'returns empty array if find_all finds nothing' do
    @schema = subject.build_models
    store_resp = double
    expect(store).to receive(:find_all).and_return(store_resp)
    expect(store_resp).to receive(:apply).and_return(store_resp)

    expect(store_resp).to_not be_nil

    expect(store_resp).to receive(:map).and_return([])

    # act
    menu_items = WCC::Contentful::Model::MenuButton.find_all(button_style: 'asdf')

    # assert
    expect(menu_items).to eq([])
  end

  it 'finds single item with filter' do
    @schema = subject.build_models

    # act
    redirect = WCC::Contentful::Model::Redirect2.find_by(slug: 'mister_roboto')

    # assert
    expect(redirect).to_not be_nil
    expect(redirect.pageReference.title).to eq('Conferences')
  end

  it 'returns nil if find_by finds nothing' do
    @schema = subject.build_models

    # act
    redirect = WCC::Contentful::Model::Redirect2.find_by(slug: 'asdf')

    # assert
    expect(redirect).to be_nil
  end

  it 'resolves numeric fields' do
    @schema = subject.build_models

    # act
    faq = WCC::Contentful::Model::Faq.find_all.first

    # assert
    expect(faq.num_faqs).to eq(2)
    expect(faq.num_faqs_float).to eq(2.1)
  end

  it 'resolves date times and json blobs' do
    @schema = subject.build_models

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

    # act
    faq = WCC::Contentful::Model::Faq.find('1nzrZZShhWQsMcey28uOUQ')

    # assert
    expect(faq.placeOfFaq.lat).to eq(52.5391688192368)
    expect(faq.placeOfFaq.lon).to eq(13.4033203125)
  end

  it 'resolves linked types' do
    @schema = subject.build_models

    # act
    main_menu = WCC::Contentful::Model::Menu.find('FNlqULSV0sOy4IoGmyWOW')

    # assert
    expect(main_menu.hamburger).to be_instance_of(WCC::Contentful::Model::Menu)
    expect(main_menu.hamburger.items[0]).to be_instance_of(WCC::Contentful::Model::MenuButton)
    expect(main_menu.hamburger.items[0].link).to be_instance_of(WCC::Contentful::Model::Page)
    expect(main_menu.hamburger.items[0].link.title).to eq('About')
  end

  it 'handles nil linked types' do
    @schema = subject.build_models

    # act
    ministries_page = WCC::Contentful::Model::Page.find('JhYhSfZPAOMqsaK8cYOUK')

    # assert
    expect(ministries_page.sub_menu).to be_nil
  end

  it 'linked arrays are empty when no links found' do
    @schema = subject.build_models

    # act
    privacy_policy_page = WCC::Contentful::Model::Page.find('1tPGouM76soIsM2e0uikgw')

    # assert
    expect(privacy_policy_page.sections).to eq([])
  end

  it 'resolves linked assets' do
    @schema = subject.build_models

    # act
    homepage = WCC::Contentful::Model::Homepage.find_all.first

    # assert
    expect(homepage.hero_image).to be_instance_of(WCC::Contentful::Model::Asset)
    expect(homepage.hero_image.file).to be_a(OpenStruct)
    expect(homepage.hero_image.title).to eq('worship')
    expect(homepage.hero_image.file['url']).to eq("//images.contentful.com/#{contentful_space_id}/" \
      '572YrsdGZGo0sw2Www2Si8/545f53511e362a78a8f34e1837868256/worship.jpg')
    expect(homepage.hero_image.file['contentType']).to eq('image/jpeg')

    expect(homepage.favicons).to be_a(Array)
    expect(homepage.favicons.length).to eq(4)
    expect(homepage.favicons[0]).to be_instance_of(WCC::Contentful::Model::Asset)
    expect(homepage.favicons[0].file.fileName).to eq('favicon.ico')
  end

  context 'with options' do
    it 'find_by preloads links when include param > 0' do
      @schema = subject.build_models

      # act
      home_page = WCC::Contentful::Model::Homepage.find_by(
        options: { include: 1 },
        site_title: 'Watermark Resources'
      )

      # assert
      # no on-demand link resolution, it's already been resolved
      expect(store).to_not receive(:find)

      expect(home_page.heroImage).to be_a(WCC::Contentful::Model::Asset)
      expect(home_page.heroImage.file.fileName).to eq('worship.jpg')

      expect(home_page.sections[0]).to be_a(WCC::Contentful::Model::SectionFaq)
      expect(home_page.sections[0].helpText).to eq('asdf')
    end
  end

  describe 'model subclasses' do
    before do
      @shema = subject.build_models
    end

    after do
      Object.send(:remove_const, :SUB_MENU) if defined?(SUB_MENU)
      Object.send(:remove_const, :SUB_PAGE) if defined?(SUB_PAGE)
      Object.send(:remove_const, :SUB_MENU_BUTTON) if defined?(SUB_MENU_BUTTON)
    end

    it 'can execute .find' do
      SUB_PAGE =
        Class.new(WCC::Contentful::Model::Page) do
        end

      # act
      page = SUB_PAGE.find('1tPGouM76soIsM2e0uikgw')

      # assert
      expect(page).to_not be_nil
      expect(page).to be_a(SUB_PAGE)
    end

    it 'can execute .find_by' do
      SUB_MENU =
        Class.new(WCC::Contentful::Model::Menu) do
        end

      # act
      button = SUB_MENU.find_by('name' => 'Main Menu')

      # assert
      expect(button).to_not be_nil
      expect(button).to be_a(SUB_MENU)
    end

    it 'can execute .find_all' do
      SUB_MENU_BUTTON =
        Class.new(WCC::Contentful::Model::MenuButton) do
        end

      # act
      buttons = SUB_MENU_BUTTON.find_all

      # assert
      expect(buttons.count).to eq(11)
      buttons.each do |button|
        expect(button).to be_a(SUB_MENU_BUTTON)
      end
    end

    it 'responds to .content_type' do
      SUB_PAGE =
        Class.new(WCC::Contentful::Model::Page) do
        end

      # act
      ct = SUB_PAGE.content_type

      # assert
      expect(ct).to eq('page')
    end

    it 'responds to .content_type_definition' do
      SUB_PAGE =
        Class.new(WCC::Contentful::Model::Page) do
        end

      # act
      ctd = SUB_PAGE.content_type_definition

      # assert
      expect(ctd).to eq(types['page'])
      # has been duplicated to avoid unexpected modification
      expect(ctd).to_not equal(types['page'])
    end

    it 'raises meaningful error when constant not defined' do
      Object.send(:remove_const, :FooBar) if defined?(FooBar)
      WCC::Contentful::Model.send(:remove_const, :FooBar) if defined?(WCC::Contentful::Model::FooBar)
      expect {
        class FooBar < WCC::Contentful::Model::FooBar
        end
      }.to raise_error(NameError,
        'Content type \'fooBar\' does not exist in the space')
    end
  end

  describe 'model class registry' do
    before do
      @schema = subject.build_models
    end

    after do
      WCC::Contentful::Model.class_variable_get('@@registry').clear

      Object.send(:remove_const, :SUB_MENU) if defined?(SUB_MENU)
      Object.send(:remove_const, :SUB_MENU_BUTTON) if defined?(SUB_MENU_BUTTON)
      Object.send(:remove_const, :SUB_MENU_BUTTON_2) if defined?(SUB_MENU_BUTTON_2)
      Object.send(:remove_const, :SUB_MENU_BUTTON_3) if defined?(SUB_MENU_BUTTON_3)
      Object.send(:remove_const, :MenuButton) if defined?(MenuButton)
    end

    it 'registered class is returned when a link is expanded' do
      SUB_MENU_BUTTON =
        Class.new(WCC::Contentful::Model::MenuButton) do
        end

      SUB_MENU =
        Class.new(WCC::Contentful::Model::Menu) do
        end

      WCC::Contentful::Model.register_for_content_type(klass: SUB_MENU_BUTTON)

      main_menu = SUB_MENU.find('FNlqULSV0sOy4IoGmyWOW')

      # act
      expanded_button = main_menu.second_group.first

      # assert
      expect(expanded_button).to_not be_nil
      expect(expanded_button).to be_a(SUB_MENU_BUTTON)
    end

    it 'class can be registered by being the first subclass' do
      SUB_MENU_BUTTON =
        Class.new(WCC::Contentful::Model::MenuButton) do
        end
      SUB_MENU_BUTTON_2 =
        Class.new(SUB_MENU_BUTTON) do
        end

      SUB_MENU_BUTTON_3 =
        Class.new(WCC::Contentful::Model::MenuButton) do
        end

      # act
      button = WCC::Contentful::Model.find('5NBhDw3i2kUqSwqYok4YQO')

      # assert
      expect(button).to be_a(SUB_MENU_BUTTON)
    end

    it 'class registration can be overridden in the class definition' do
      SUB_MENU_BUTTON =
        Class.new(WCC::Contentful::Model::MenuButton) do
        end

      SUB_MENU_BUTTON_2 =
        Class.new(SUB_MENU_BUTTON) do
          register_for_content_type
        end

      SUB_MENU_BUTTON_3 =
        Class.new(WCC::Contentful::Model::MenuButton) do
        end

      # act
      button = WCC::Contentful::Model.find('5NBhDw3i2kUqSwqYok4YQO')

      # assert
      expect(button).to be_a(SUB_MENU_BUTTON_2)
    end

    it 'loads app-defined constant using const_missing' do
      expect(Object).to receive(:const_missing).with('MenuButton') do
        MenuButton =
          Class.new(WCC::Contentful::Model::MenuButton) do
          end
      end

      # act
      button = WCC::Contentful::Model.find('5NBhDw3i2kUqSwqYok4YQO')

      # assert
      expect(button).to be_a(MenuButton)
    end

    it 'does not use loaded class if it does not inherit WCC::Contentful::Model' do
      expect(Object).to receive(:const_missing) do
        MenuButton =
          Class.new do
            def initialize(raw, context)
            end
          end
      end

      # act
      button = WCC::Contentful::Model.find('5NBhDw3i2kUqSwqYok4YQO')

      # assert
      expect(button).to be_a(WCC::Contentful::Model::MenuButton)
    end
  end
end
