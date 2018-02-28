# frozen_string_literal: true

RSpec.describe WCC::Contentful do
  it 'has a version number' do
    expect(WCC::Contentful::VERSION).not_to be nil
  end

  describe '.configuration' do
    let(:valid_contentful_access_token) { ENV['CONTENTFUL_ACCESS_TOKEN'] }
    let(:valid_contentful_space_id) { ENV['CONTENTFUL_SPACE_ID'] }
    let(:valid_contentful_default_locale) { 'en-US' }

    context 'after WCC::Contentful has been configured' do
      before do
        WCC::Contentful.configure do |config|
          config.access_token = valid_contentful_access_token
          config.space = valid_contentful_space_id
          config.default_locale = valid_contentful_default_locale
        end
      end

      it 'should return a Contentful config object populated with the values given' do
        config = WCC::Contentful.configuration

        expect(config.access_token).to eq(valid_contentful_access_token)
        expect(config.space).to eq(valid_contentful_space_id)
        expect(config.default_locale).to eq(valid_contentful_default_locale)
        expect(config.nil?).to eq(false)
      end
    end
  end

  describe '.configure' do
    let(:valid_contentful_access_token) { '<VALID_CONTENTFUL_ACCESS_TOKEN>' }
    let(:valid_contentful_space_id) { '<VALID_CONTENTFUL_SPACE_ID>' }
    let(:valid_contentful_default_locale) { 'en-US' }
    let(:invalid_contentful_access_token) { '<INVALID_CONTENTFUL_ACCESS_TOKEN>' }
    let(:invalid_contentful_space_id) { '<INVALID_CONTENTFUL_SPACE_ID>' }
    let(:invalid_contentful_default_locale) { 'simmer-down-now-fella' }

    context 'when passed VALID configuration arguments' do
      before do
        WCC::Contentful.configure do |config|
          config.access_token = valid_contentful_access_token
          config.space = valid_contentful_space_id
          config.default_locale = valid_contentful_default_locale
        end
      end

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

      it 'should allow you to fetch a Redirect object from Contentful' do
        VCR.use_cassette('models/wcc_contentful/redirect/has_slug_and_url', record: :none) do
          response = WCC::Contentful::Redirect.find_by_slug('redirect-with-slug-and-url')
          expect(response.nil?).to eq(false)
        end
      end
    end

    context 'when passed INVALID configuration arguments' do
      before do
        WCC::Contentful.configure do |config|
          config.access_token = invalid_contentful_access_token
          config.space = invalid_contentful_space_id
          config.default_locale = invalid_contentful_default_locale
        end
      end

      it 'should return a Contentful config object populated with the invalid values given' do
        config = WCC::Contentful.configuration

        expect(config.access_token).to eq(invalid_contentful_access_token)
        expect(config.space).to eq(invalid_contentful_space_id)
        expect(config.default_locale).to eq(invalid_contentful_default_locale)
        expect(config.nil?).to eq(false)
      end

      it 'should return a ContentfulModel config object populated with the invalid values given' do
        contentful_model_config = ContentfulModel.configuration

        expect(contentful_model_config.access_token).to eq(invalid_contentful_access_token)
        expect(contentful_model_config.space).to eq(invalid_contentful_space_id)
        expect(contentful_model_config.default_locale).to eq(invalid_contentful_default_locale)
        expect(contentful_model_config.nil?).to eq(false)
      end

      it 'should not allow you to fetch a Redirect object from Contentful' do
        # Cassettes have the configuration that was used during the time of recording
        # baked into the yml file, so this cassette will always have invalid config
        # arguments unless overwritten later.
        VCR.use_cassette('models/wcc_contentful/redirect/unauthorized', record: :none) do
          response = WCC::Contentful::Redirect.find_by_slug('unauthorized-slug-request')
          expect(response.nil?).to eq(true)
        end
      end
    end
  end
end
