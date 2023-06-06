# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::ModelBuilder do
  subject {
    WCC::Contentful::ModelBuilder.new(types)
  }

  let(:types) {
    types = load_indexed_types
    allow(WCC::Contentful).to receive(:types)
      .and_return(types)
    types
  }
  let(:store) {
    load_store_from_sync
  }

  let(:services) {
    double('services', store: store, instrumentation: ActiveSupport::Notifications)
  }

  before do
    allow(WCC::Contentful::Model).to receive(:services)
      .and_return(services)
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

  it 'can represent a DeletedEntry' do
    deleted_page_raw = {
      'sys' => {
        'type' => 'DeletedEntry',
        'id' => '123',
        'space' => { 'sys' => { 'type' => 'Link', 'linkType' => 'Space', 'id' => 'space123' } },
        'revision' => 1,
        'createdAt' => '2018-02-12T20:09:38.819Z',
        'updatedAt' => '2018-02-12T21:59:43.653Z',
        'deletedAt' => '2018-02-12T21:59:43.653Z',
        'environment' => { 'sys' => { 'id' => 'master', 'type' => 'Link', 'linkType' => 'Environment' } },
        'contentType' => {
          'sys' => {
            'type' => 'Link',
            'linkType' => 'ContentType',
            'id' => 'page'
          }
        }
      }
    }
    @schema = subject.build_models

    # act
    deleted_page = WCC::Contentful::Model::Page.new(deleted_page_raw)

    # assert
    expect(deleted_page).to be_instance_of(WCC::Contentful::Model::Page)
    expect(deleted_page.sys.type).to eq('DeletedEntry')
  end

  describe 'static methods' do
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

    it 'instruments find' do
      @schema = subject.build_models

      # act
      expect {
        WCC::Contentful::Model::Menu.find('FNlqULSV0sOy4IoGmyWOW')
      }.to instrument('find.model.contentful.wcc')
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
      expect(menu_items.count).to eq(11)
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
      expect(menu_items.count).to eq(2)
      expect(menu_items.map(&:id).sort).to eq(
        %w[3bZRv5ISCkui6kguIwM2U0 4tMhra8IAwcEoKS6QSQYcc]
      )
    end

    it 'instruments find_all' do
      @schema = subject.build_models

      # act
      expect {
        WCC::Contentful::Model::MenuButton.find_all(button_style: 'custom')
      }.to instrument('find_all.model.contentful.wcc')
    end

    it 'returns empty array if find_all finds nothing' do
      @schema = subject.build_models
      store_resp = double
      expect(store).to receive(:find_all).and_return(store_resp)
      expect(store_resp).to receive(:apply).and_return(store_resp)

      expect(store_resp).to receive(:to_enum).and_return([])

      # act
      menu_items = WCC::Contentful::Model::MenuButton.find_all(button_style: 'asdf')

      # assert
      expect(menu_items.to_a).to eq([])
    end

    it 'delegates #count to the underlying store w/o iterating the enumerable' do
      @schema = subject.build_models
      store_resp = double(count: 1234)
      expect(store).to receive(:find_all).and_return(store_resp)
      allow(store_resp).to receive(:apply).and_return(store_resp)

      expect(store_resp).to_not receive(:to_enum)

      # act
      menu_items = WCC::Contentful::Model::MenuButton.find_all(button_style: 'asdf')

      # assert
      expect(menu_items.count).to eq(1234)
    end

    it 'finds single item with filter' do
      @schema = subject.build_models

      # act
      redirect = WCC::Contentful::Model::Redirect2.find_by(slug: 'mister_roboto')

      # assert
      expect(redirect).to_not be_nil
      expect(redirect.pageReference.title).to eq('Conferences')
    end

    it 'instruments find_by' do
      @schema = subject.build_models

      # act
      expect {
        WCC::Contentful::Model::Redirect2.find_by(slug: 'mister_roboto')
      }.to instrument('find_by.model.contentful.wcc')
    end

    it 'returns nil if find_by finds nothing' do
      @schema = subject.build_models

      # act
      redirect = WCC::Contentful::Model::Redirect2.find_by(slug: 'asdf')

      # assert
      expect(redirect).to be_nil
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
  end

  describe 'fields' do
    it 'resolves numeric fields' do
      @schema = subject.build_models

      # act
      faq = WCC::Contentful::Model::Faq.find_all.first

      # assert
      expect(faq.num_faqs).to eq(2)
      expect(faq.num_faqs_float).to eq(2.1)
    end

    it 'resolves json blobs' do
      @schema = subject.build_models

      # act
      migration = WCC::Contentful::Model::MigrationHistory.find_all.first

      # assert
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

    # NOTE: see code comment inside model_builder.rb for why we do not parse DateTime objects
    it 'does not parse date times' do
      @schema = subject.build_models

      # act
      faq = WCC::Contentful::Model::Faq.find('1nzrZZShhWQsMcey28uOUQ')

      # assert
      expect(faq.date_of_faq).to be_a String
      expect(faq.date_of_faq).to eq('2018-02-01')
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

    it 'ignores linked types when they can\'t be resolved' do
      @schema = subject.build_models

      allow(WCC::Contentful::Model).to receive(:find)
        .and_call_original

      allow(WCC::Contentful::Model).to receive(:find)
        .with('5NBhDw3i2kUqSwqYok4YQO', any_args)
        .and_return(nil)

      # act
      main_menu = WCC::Contentful::Model::Menu.find('FNlqULSV0sOy4IoGmyWOW')

      # assert
      expect(main_menu.hamburger).to be_instance_of(WCC::Contentful::Model::Menu)
      expect(main_menu.hamburger.items[1]).to be_instance_of(WCC::Contentful::Model::MenuButton)
      expect(main_menu.hamburger.items[1].externalLink).to eq('https://www.watermark.org')
      expect(main_menu.hamburger.items.length).to eq(2)
    end

    it 'makes ID of linked types accessible' do
      @schema = subject.build_models

      # act
      main_menu = WCC::Contentful::Model::Menu.find('FNlqULSV0sOy4IoGmyWOW')

      # assert
      expect(store).to_not receive(:find)
      expect(main_menu.hamburger_id).to eq('6y9DftpiYoA4YiKg2CgoUU')
    end

    it 'makes all IDs of a linked array accessible' do
      @schema = subject.build_models

      # act
      side_menu = WCC::Contentful::Model::Menu.find('6y9DftpiYoA4YiKg2CgoUU')

      # assert
      expect(store).to_not receive(:find)
      expect(side_menu.items_ids).to eq(
        %w[
          1IJEXB4AKEqQYEm4WuceG2
          5NBhDw3i2kUqSwqYok4YQO
          4tMhra8IAwcEoKS6QSQYcc
        ]
      )
    end

    it 'stores backreference on linked type context' do
      @schema = subject.build_models

      # act
      main_menu = WCC::Contentful::Model::Menu.find('FNlqULSV0sOy4IoGmyWOW')

      # assert
      hamburger = main_menu.hamburger
      expect(hamburger.sys.context.backlinks).to eq([main_menu])

      button = hamburger.items[0]
      expect(button.sys.context.backlinks).to eq([hamburger, main_menu])

      page = button.link
      expect(page.sys.context.backlinks).to eq([button, hamburger, main_menu])
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
      expect(homepage.hero_image.file['url']).to eq(
        "//images.contentful.com/#{contentful_space_id}/" \
        '572YrsdGZGo0sw2Www2Si8/545f53511e362a78a8f34e1837868256/worship.jpg'
      )
      expect(homepage.hero_image.file['contentType']).to eq('image/jpeg')

      expect(homepage.favicons).to be_a(Array)
      expect(homepage.favicons.length).to eq(4)
      expect(homepage.favicons[0]).to be_instance_of(WCC::Contentful::Model::Asset)
      expect(homepage.favicons[0].file.fileName).to eq('favicon.ico')
    end

    it 'ignores linked assets when they can\'t be resolved' do
      @schema = subject.build_models

      allow(WCC::Contentful::Model).to receive(:find)
        .and_call_original

      allow(WCC::Contentful::Model).to receive(:find)
        .with('1MsOLBrDwEUAUIuMY8Ys6o', any_args)
        .and_return(nil)

      # act
      homepage = WCC::Contentful::Model::Homepage.find_all.first

      # assert
      expect(homepage.favicons).to be_a(Array)
      expect(homepage.favicons[1]).to be_instance_of(WCC::Contentful::Model::Asset)
      expect(homepage.favicons[1].file.fileName).to eq('favicon-32x32.png')
      expect(homepage.favicons.length).to eq(3)
    end

    describe 'rich text' do
      let(:store) { double('store') }
      let(:types) {
        WCC::Contentful::ContentTypeIndexer
          .load(path_to_fixture('contentful/content_types_rich_text.json'))
          .types
      }
      let(:fixture) { JSON.parse(load_fixture('contentful/block-text-with-rich-text.json')) }
      let(:block_text) {
        WCC::Contentful::EntryLocaleTransformer.transform_to_locale(
          fixture.dig('items', 0),
          'en-US'
        )
      }

      before do
        allow(store).to receive(:find_by)
          .and_return(block_text)

        @schema = subject.build_models
      end

      context 'unresolved' do
        it 'has content blocks' do
          # act
          block_text = WCC::Contentful::Model::SectionBlockText.find_by(id: '5op6hsU6BYvZCt7S0PjTVv')

          # assert
          expect(block_text.rich_body['content'].length).to eq(12)
          node_types = block_text.rich_body['content'].map { |c| c['nodeType'] }
          expect(node_types).to eq(
            %w[
              heading-2 heading-3 paragraph blockquote paragraph
              embedded-asset-block blockquote embedded-entry-block
              paragraph paragraph blockquote paragraph
            ]
          )
          classes = block_text.rich_body['content'].map(&:class)
          expect(classes).to eq(
            [
              WCC::Contentful::RichText::Heading,
              WCC::Contentful::RichText::Heading,
              WCC::Contentful::RichText::Paragraph,
              WCC::Contentful::RichText::Blockquote,
              WCC::Contentful::RichText::Paragraph,
              WCC::Contentful::RichText::EmbeddedAssetBlock,
              WCC::Contentful::RichText::Blockquote,
              WCC::Contentful::RichText::EmbeddedEntryBlock,
              WCC::Contentful::RichText::Paragraph,
              WCC::Contentful::RichText::Paragraph,
              WCC::Contentful::RichText::Blockquote,
              WCC::Contentful::RichText::Paragraph
            ]
          )
        end
      end
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
      WCC::Contentful::Model.instance_variable_get('@registry').clear

      Object.send(:remove_const, :SUB_MENU) if defined?(SUB_MENU)
      Object.send(:remove_const, :SUB_MENU_BUTTON) if defined?(SUB_MENU_BUTTON)
      Object.send(:remove_const, :SUB_MENU_BUTTON2) if defined?(SUB_MENU_BUTTON2)
      Object.send(:remove_const, :SUB_MENU_BUTTON3) if defined?(SUB_MENU_BUTTON3)
      Object.send(:remove_const, :MenuButton) if defined?(MenuButton)
      Object.send(:remove_const, :MyButton) if defined?(MyButton)
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
      SUB_MENU_BUTTON2 =
        Class.new(SUB_MENU_BUTTON) do
        end

      SUB_MENU_BUTTON3 =
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

      SUB_MENU_BUTTON2 =
        Class.new(SUB_MENU_BUTTON) do
          register_for_content_type
        end

      SUB_MENU_BUTTON3 =
        Class.new(WCC::Contentful::Model::MenuButton) do
        end

      # act
      button = WCC::Contentful::Model.find('5NBhDw3i2kUqSwqYok4YQO')

      # assert
      expect(button).to be_a(SUB_MENU_BUTTON2)
    end

    it 'loads app-defined constant using const_get' do
      allow(Object).to receive(:const_get).and_call_original
      expect(Object).to receive(:const_get).with('MenuButton') do
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
      allow(Object).to receive(:const_get).and_call_original
      expect(Object).to receive(:const_get).with('MenuButton') do
        MenuButton =
          Class.new do
            def initialize(_raw, _context = nil)
              raise ArgumentError, 'Should not have loaded this class!'
            end
          end
      end
      allow(WCC::Contentful::Model).to receive(:const_get).and_call_original

      # act
      button = WCC::Contentful::Model.find('5NBhDw3i2kUqSwqYok4YQO')

      # assert
      expect(button).to be_a(WCC::Contentful::Model::MenuButton)
    end

    it 'does not use loaded class if it does not exist' do
      allow(Object).to receive(:const_get).and_call_original
      expect(Object).to receive(:const_get).with('MenuButton')
        .and_raise(NameError, 'uninitialized constant MenuButton')
        .at_most(3).times
      allow(WCC::Contentful::Model).to receive(:const_get).and_call_original

      # act
      button = WCC::Contentful::Model.find('5NBhDw3i2kUqSwqYok4YQO')

      # assert
      expect(button).to be_a(WCC::Contentful::Model::MenuButton)
    end

    it 're-raises NameError if the class def itself raises a name error' do
      allow(Object).to receive(:const_get).and_call_original
      expect(Object).to receive(:const_get).with('MenuButton')
        .and_raise(NameError, 'uninitialized constant FooBar')

      # act
      expect {
        WCC::Contentful::Model.find('5NBhDw3i2kUqSwqYok4YQO')
      }.to raise_error(NameError)
    end

    it 'forces reloading after ActiveSupport triggers a reload' do
      with_tempfile(['my_menu_button', '.rb'], <<~RUBY) do |file|
        class MyButton < WCC::Contentful::Model::MenuButton
          register_for_content_type 'menuButton'
        end
      RUBY

        load(file.path)
        item = WCC::Contentful::Model.find '3Jmk4yOwhOY0yKsI6mAQ2a'
        expect(item).to be_a MyButton

        # ActiveSupport removes constants and triggers to_prepare
        Object.send(:remove_const, :MyButton)
        allow(Object).to receive(:const_get).and_call_original
        expect(Object).to receive(:const_get) do |name|
          expect(name.to_s).to eq('MyButton')
          load(file.path)
          MyButton
        end

        # act
        WCC::Contentful::Model.reload!

        item2 = WCC::Contentful::Model.find '3Jmk4yOwhOY0yKsI6mAQ2a'
        expect(item2).to be_a MyButton
      end
    end
  end

  def with_tempfile(name, contents)
    file = Tempfile.open(name)
    begin
      begin
        file.write(contents)
      ensure
        file.close
      end

      yield file
    ensure
      file.unlink
    end
  end
end
