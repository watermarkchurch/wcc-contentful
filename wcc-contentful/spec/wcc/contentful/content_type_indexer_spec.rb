# frozen_string_literal: true

RSpec.describe WCC::Contentful::ContentTypeIndexer do
  let(:raw_data) {
    JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
  }

  subject(:indexer) { WCC::Contentful::ContentTypeIndexer.new }

  context 'index content type data' do
    it 'generates type data' do
      # act
      raw_data['items'].each do |raw_content_type|
        indexer.index(raw_content_type)
      end

      # assert
      expect(indexer.types.keys.sort).to eq(
        %w[
          Asset
          dog
          dropdownMenu
          faq
          homepage
          menu
          menuButton
          migrationHistory
          ministry
          ministryCard
          page
          redirect2
          section-CardSearch
          section-Faq
          section-Testimonials
          section-VideoHighlight
          testimonial
          theme
        ]
      )

      faq = subject.types['faq']
      expect(faq.fields['question'].type).to eq(:String)
      expect(faq.fields['answer'].type).to eq(:String)
      expect(faq.fields['numFaqs'].type).to eq(:Int)
      expect(faq.fields['numFaqsFloat'].type).to eq(:Float)
      expect(faq.fields['dateOfFaq'].type).to eq(:DateTime)
      expect(faq.fields['truthyOrFalsy'].type).to eq(:Boolean)
      expect(faq.fields['placeOfFaq'].type).to eq(:Coordinates)
    end

    it 'resolves potential linked types' do
      # act
      raw_data['items'].each do |raw_content_type|
        indexer.index(raw_content_type)
      end

      # assert
      redirect = subject.types['redirect2']
      redirect_ref = redirect.fields['pageReference']
      expect(redirect_ref.type).to eq(:Link)
      expect(redirect_ref.link_types).to include('page')

      homepage = subject.types['homepage']
      sections_ref = homepage.fields['sections']
      expect(sections_ref.link_types.sort).to eq(
        %w[
          section-CardSearch
          section-Faq
          section-Testimonials
          section-VideoHighlight
        ]
      )
    end

    it 'resolves date times correctly' do
      # act
      raw_data['items'].each do |raw_content_type|
        indexer.index(raw_content_type)
      end

      # assert
      history = subject.types['migrationHistory']
      started = history.fields['started']
      expect(started.type).to eq(:DateTime)

      migration_name = history.fields['migrationName']
      expect(migration_name.type).to eq(:String)
    end

    it 'sets array flag on array fields' do
      # act
      raw_data['items'].each do |raw_content_type|
        indexer.index(raw_content_type)
      end

      # assert
      homepage = subject.types['homepage']
      favicons = homepage.fields['favicons']
      expect(favicons.array).to be(true)
    end

    it 'generates phony Asset content type' do
      # act
      raw_data['items'].each do |raw_content_type|
        indexer.index(raw_content_type)
      end

      # assert
      asset = subject.types['Asset']
      title = asset.fields['title']
      expect(title.type).to eq(:String)
      desc = asset.fields['description']
      expect(desc.type).to eq(:String)
      file = asset.fields['file']
      expect(file.type).to eq(:Json)
    end
  end

  context 'index from contentful ruby gems' do
    before(:all) do
      require 'contentful'
      require 'contentful/management'
    end

    after(:all) do
      ::Contentful.send(:remove_const, :Management)
      Object.send(:remove_const, :Contentful)
    end

    before do
      VCR.use_cassette('models/wcc_contentful/content_types', record: :none) do
        WCC::Contentful.configure do |config|
          config.access_token = contentful_access_token
          config.space = contentful_space_id
          config.management_token = contentful_management_token
          config.default_locale = 'en-US'
        end
      end
    end

    context 'management API' do
      let(:content_types) {
        VCR.use_cassette('models/wcc_contentful/content_types/mgmt_api_master', record: :none) do
          Contentful::Management::Client.new(contentful_management_token)
            .content_types(contentful_space_id, 'master')
            .all
            .map { |t| t }
        end
      }

      it 'generates type data' do
        # act
        content_types.each do |managed_content_type|
          indexer.index(managed_content_type)
        end

        # assert
        # includes non-published content types
        expect(indexer.types.keys.sort).to eq(
          %w[
            Asset
            asdf
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
          ]
        )

        sections = indexer.types['page'].fields['sections']
        expect(sections.link_types).to eq(
          %w[
            section-CardSearch
            section-Faq
            section-Testimonials
            section-VideoHighlight
          ]
        )
      end

      it 'generates link types even for single links' do
        # act
        content_types.each do |managed_content_type|
          indexer.index(managed_content_type)
        end

        # assert
        sub_menu = indexer.types['page'].fields['subMenu']
        expect(sub_menu.link_types).to eq(['menu'])
      end
    end

    context 'contentful.rb CDN' do
      before do
        require 'contentful'
        WCC::Contentful.configure do |config|
          config.access_token = contentful_access_token
          config.space = contentful_space_id
          config.management_token = contentful_management_token
          config.default_locale = 'en-US'
        end
      end

      let(:content_types) {
        VCR.use_cassette('models/wcc_contentful/content_types_env_master', record: :none) do
          Contentful::Client.new(
            access_token: contentful_access_token,
            space: contentful_space_id
          ).content_types(limit: 1000)
        end
      }

      it 'figures out link types from validations' do
        # act
        content_types.each do |managed_content_type|
          indexer.index(managed_content_type)
        end

        # assert
        sections_field = indexer.types['page'].fields['sections']

        expect(sections_field.link_types).to be_present
      end
    end
  end
end
