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
          callToAction
          conference
          dog
          dropdownMenu
          faq
          formField
          homepage
          menu
          menuButton
          migrationHistory
          ministry
          ministryCard
          page
          partnerChurch
          redirect2
          section-CardSearch
          section-Faq
          section-Testimonials
          section-VideoHighlight
          section-block-text
          section-contact-us
          section-domain-object-header
          section-faq
          section-featured-items
          section-hero
          section-image-gallery
          section-intro
          section-location-map
          section-ministry-details
          section-partner-churches
          section-product-list
          section-resource-list
          section-testimonials
          section-video
          section-video-highlight
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
end
