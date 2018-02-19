# frozen_string_literal: true

RSpec.describe WCC::Contentful::Redirect, type: :model do

  describe '.find_by_slug' do
    before do
      WCC::Contentful.configure do |config|
        config.access_token = '<CONTENTFUL_ACCESS_TOKEN>'
        config.space = '<CONTENTFUL_SPACE_ID>'
        config.default_locale = 'en-US'
      end
    end
    context 'when the Redirect model in Contentful has a slug and url, but no pageReference' do
      it 'should receive a slug string and return a Redirect object' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_url', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-and-url')
          expect(response.url).to eq('https://survey.watermark.org/survey/4b2018')
        end
      end
      it 'should let you know that the pageReference field is nil' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_url', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-and-url')
          expect(response.pageReference.nil?).to eq(true)
        end
      end 
    end

    context 'when the Redirect model in Contentful has a slug and pageReference, but no url' do
      it 'should receive a slug string and return a Redirect object' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_page_reference', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-and-page-reference')
          expect(response.pageReference.url).to eq('theporchchristmas')
        end
      end

      it 'should let you know that the url field is nil' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_page_reference', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-and-page-reference')
          expect(response.url.nil?).to eq(true)
        end
      end      
    end

    context 'when the Redirect model in Contentful has a slug, but no url nor pageReference' do
      it 'should receive a slug string and return a Redirect object' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_only', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-only')
          expect(response.slug).to eq('redirect-with-slug-only')
        end
      end

      it 'should let you know that the url field is nil' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_only', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-only')
          expect(response.url.nil?).to eq(true)
        end
      end

      it 'should let you know that the pageReference field is nil' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_only', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-only')
          expect(response.pageReference.nil?).to eq(true)
        end
      end 
    end
  end

  describe '#location' do
    context 'when the Redirect model in Contentful has a slug and url, but no pageReference' do
      it 'should return the url of the Redirect model' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_url', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-and-url')
          expect(response.location).to eq("#{response.url}")
        end
      end
    end

    context 'when the Redirect model in Contentful has a slug and pageReference, but no url' do
      it 'should return the url of the pageReference' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_page_reference', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-and-page-reference')
          expect(response.location).to eq("/#{response.pageReference.url}")
        end
      end
    end

    context 'when the Redirect model in Contentful has a slug, but no url nor pageReference' do
      it 'should return nil' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_only', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-only')
          expect(response.location.nil?).to eq(true)
        end
      end
    end
  end

  describe '#valid_page_reference?' do
    context 'when the Redirect model has a pageReference that includes a url' do
      it 'should return true' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_page_reference', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-and-page-reference')
          expect(response.valid_page_reference?(response.pageReference)).to eq(true)
        end
      end
    end

    context 'when the Redirect model has a pageReference that does not include a url' do
      it 'should return false' do
        VCR.use_cassette('models/wcc_contentful/redirect/page_ref_with_no_url') do
          response = described_class.find_by_slug('page-ref-with-no-url')
          expect(response.valid_page_reference?(response.pageReference)).to eq(false)
        end
      end
    end

    context 'when the Redirect model does not have a pageReference' do
      it 'should return false' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_only', record: :none) do
          response = described_class.find_by_slug('redirect-with-slug-only')
          expect(response.valid_page_reference?(response.pageReference)).to eq(false)
        end
      end
    end
  end

end
