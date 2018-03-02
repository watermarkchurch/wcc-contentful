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
          Dog
          Faq
          Homepage
          Menu
          MenuItem
          MigrationHistory
          Ministry
          MinistryCard
          Page
          Redirect2
          Section_CardSearch
          Section_Faq
          Section_Testimonials
          Section_VideoHighlight
          Testimonial
          Theme
        ]
      )

      faq = subject.types['Faq']
      expect(faq.dig(:fields, 'question', :type)).to eq(:String)
      expect(faq.dig(:fields, 'answer', :type)).to eq(:String)
      expect(faq.dig(:fields, 'numFaqs', :type)).to eq(:Int)
      expect(faq.dig(:fields, 'numFaqsFloat', :type)).to eq(:Float)
      expect(faq.dig(:fields, 'dateOfFaq', :type)).to eq(:DateTime)
      expect(faq.dig(:fields, 'truthyOrFalsy', :type)).to eq(:Boolean)
      expect(faq.dig(:fields, 'placeOfFaq', :type)).to eq(:Coordinates)

      json = subject.types.to_json
      File.write('test.json', json)
    end

    it 'resolves potential linked types' do
      # act
      raw_data['items'].each do |raw_content_type|
        indexer.index(raw_content_type)
      end

      # assert
      redirect = subject.types['Redirect2']
      redirect_ref = redirect.dig(:fields, 'pageReference')
      expect(redirect_ref[:type]).to eq(:Link)
      expect(redirect_ref[:link_types]).to include('Page')

      homepage = subject.types['Homepage']
      sections_ref = homepage.dig(:fields, 'sections')
      expect(sections_ref[:link_types].sort).to eq(
        %w[
          Section_CardSearch
          Section_Faq
          Section_Testimonials
          Section_VideoHighlight
        ]
      )
    end

    it 'resolves date times correctly' do
      # act
      raw_data['items'].each do |raw_content_type|
        indexer.index(raw_content_type)
      end

      # assert
      history = subject.types['MigrationHistory']
      started = history.dig(:fields, 'started')
      expect(started[:type]).to eq(:DateTime)

      migration_name = history.dig(:fields, 'migrationName')
      expect(migration_name[:type]).to eq(:String)
    end

    it 'sets array flag on array fields' do
      # act
      raw_data['items'].each do |raw_content_type|
        indexer.index(raw_content_type)
      end

      # assert
      homepage = subject.types['Homepage']
      favicons = homepage.dig(:fields, 'favicons')
      expect(favicons[:array]).to be(true)
    end
  end

  context 'index from contentful.rb management API' do
    before do
      VCR.use_cassette('models/wcc_contentful/content_types', record: :none) do
        WCC::Contentful.configure do |config|
          config.access_token = ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234'
          config.space = ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'
          config.management_token = ENV['CONTENTFUL_MANAGEMENT_TOKEN'] || 'CFPAT-xxxx'
          config.default_locale = 'en-US'
        end
      end
    end

    let(:content_types) {
      VCR.use_cassette('models/wcc_contentful/content_types/mgmt_api', record: :none) do
        ContentfulModel::Management.new.content_types
          .all(ContentfulModel.configuration.space)
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
          Asdf
          Asset
          Dog
          Faq
          Homepage
          Menu
          MenuItem
          MigrationHistory
          Ministry
          MinistryCard
          Page
          Redirect
          Section_CardSearch
          Section_Faq
          Section_Testimonials
          Section_VideoHighlight
          Testimonial
          Theme
        ]
      )

      sections = indexer.types['Page'][:fields]['sections']
      expect(sections[:link_types]).to eq(
        %w[
          Section_CardSearch
          Section_Faq
          Section_Testimonials
          Section_VideoHighlight
        ]
      )
    end
  end

  context 'index from contentful.rb CDN' do
    before do
      VCR.use_cassette('models/wcc_contentful/content_types', record: :none) do
        WCC::Contentful.configure do |config|
          config.access_token = ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234'
          config.space = ENV['CONTENTFUL_SPACE_ID'] || 'test1xab'
          config.management_token = ENV['CONTENTFUL_MANAGEMENT_TOKEN'] || 'CFPAT-xxxx'
          config.default_locale = 'en-US'
        end
      end
    end

    let(:content_types) {
      ContentfulModel::Base.client.dynamic_entry_cache.values.map(&:content_type)
    }

    it 'generates type data' do
      # act
      content_types.each do |managed_content_type|
        indexer.index(managed_content_type)
      end

      # assert
      expect(indexer.types.keys.sort).to eq(
        %w[
          Asset
          Dog
          Faq
          Homepage
          Menu
          MenuItem
          MigrationHistory
          Ministry
          MinistryCard
          Page
          Redirect
          Section_CardSearch
          Section_Faq
          Section_Testimonials
          Section_VideoHighlight
          Testimonial
          Theme
        ]
      )

      sections = indexer.types['Page'][:fields]['sections']
      expect(sections[:link_types]).to eq(
        %w[
          Section_CardSearch
          Section_Faq
          Section_Testimonials
          Section_VideoHighlight
        ]
      )
    end
  end
end
