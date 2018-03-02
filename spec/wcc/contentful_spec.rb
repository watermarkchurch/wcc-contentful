# frozen_string_literal: true

RSpec.describe WCC::Contentful do
  it 'has a version number' do
    expect(WCC::Contentful::VERSION).not_to be nil
  end

  let(:valid_contentful_access_token) { ENV['CONTENTFUL_ACCESS_TOKEN'] || 'test1234' }
  let(:valid_contentful_space_id) { ENV['CONTENTFUL_SPACE_ID'] || 'test1xab' }
  let(:valid_contentful_default_locale) { 'en-US' }

  before do
    VCR.use_cassette('models/wcc_contentful/content_types', record: :none) do
      WCC::Contentful.configure do |config|
        config.access_token = valid_contentful_access_token
        config.space = valid_contentful_space_id
        config.default_locale = valid_contentful_default_locale
      end
    end
  end

  describe '.configure' do
    let(:invalid_contentful_access_token) { 'test5678' }
    let(:invalid_contentful_space_id) { 'testxxxx' }
    let(:invalid_contentful_default_locale) { 'simmer-down-now-fella' }

    context 'when passed VALID configuration arguments' do
      it 'should return a Contentful config object populated with the valid values given' do
        config = WCC::Contentful.configuration

        expect(config.access_token).to eq(valid_contentful_access_token)
        expect(config.space).to eq(valid_contentful_space_id)
        expect(config.default_locale).to eq(valid_contentful_default_locale)
        expect(config.nil?).to eq(false)
      end

      it 'should return a ContentfulModel config object populated with the valid values given' do
        contentful_model_config = ContentfulModel.configuration

        expect(contentful_model_config.access_token).to eq(valid_contentful_access_token)
        expect(contentful_model_config.space).to eq(valid_contentful_space_id)
        expect(contentful_model_config.default_locale).to eq(valid_contentful_default_locale)
        expect(contentful_model_config.nil?).to eq(false)
      end

      it 'should set the Contentful client on the WCC::Contentful module' do
        client = WCC::Contentful.client

        expect(client).to be_a(Contentful::Client)
      end

      it 'should allow you to fetch a Redirect object from Contentful' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_url', record: :none) do
          response = WCC::Contentful::Redirect.find_by_slug('redirect-with-slug-and-url')
          expect(response.nil?).to eq(false)
        end
      end
    end

    context 'when passed INVALID configuration arguments' do
      it 'should error with a Contentful::Unauthorized' do
        VCR.use_cassette('models/wcc_contentful/content_types/invalid_space', record: :none) do
          WCC::Contentful.configure do |config|
            config.access_token = invalid_contentful_access_token
            config.space = invalid_contentful_space_id
            config.default_locale = invalid_contentful_default_locale
          end
        end
      end
    end
  end

  describe '.init' do
    it 'raises argument error if not configured' do
      WCC::Contentful.configuration = nil

      # act
      expect {
        WCC::Contentful.init!
      }.to raise_error(ArgumentError)
    end

    it ''
  end
end
