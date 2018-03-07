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
        config.content_delivery = :eager_sync
      end
    end
  end

  after(:each) do
    consts = WCC::ContentfulModel.all_models.map(&:to_s).uniq
    consts.each do |c|
      begin
        WCC::ContentfulModel.send(:remove_const, c.split(':').last)
      rescue StandardError => e
        warn e
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
    before do
      allow(WCC::Contentful).to receive(:validate_models!)
    end

    it 'raises argument error if not configured' do
      WCC::Contentful.instance_variable_set('@configuration', nil)

      # act
      expect {
        WCC::Contentful.init!
      }.to raise_error(ArgumentError)
    end

    context 'without management token' do
      it 'should populate models via ContentfulModel cache' do
        # act
        VCR.use_cassette('models/wcc_contentful/sync/initial', record: :none) do
          WCC::Contentful.init!
        end

        # assert
        content_type = WCC::ContentfulModel::MenuItem.content_type
        expect(content_type).to eq('menuItem')
      end

      it 'should populate store via sync API' do
        # act
        VCR.use_cassette('models/wcc_contentful/sync/initial', record: :none) do
          WCC::Contentful.init!
        end

        # assert
        page = WCC::ContentfulModel.find('1UojJt7YoMiemCq2mGGUmQ')
        expect(page).to_not be_nil
        expect(page).to be_a(WCC::ContentfulModel::Page)
        expect(page.slug).to eq('/conferences')

        expect(page.sections).to be_nil
      end
    end

    context 'with management token' do
      before(:each) do
        WCC::Contentful.configure do |config|
          config.management_token = ENV['CONTENTFUL_MANAGEMENT_TOKEN'] || 'CFPAT-xxxx'
        end
      end

      it 'should populate models via Management API cache' do
        # act
        VCR.use_cassette('models/wcc_contentful/content_types/mgmt_api', record: :none) do
          VCR.use_cassette('models/wcc_contentful/sync/initial', record: :none) do
            WCC::Contentful.init!
          end
        end

        # assert
        content_type = WCC::ContentfulModel::Page.content_type
        expect(content_type).to eq('page')
      end

      it 'should populate store via sync API' do
        # act
        VCR.use_cassette('models/wcc_contentful/content_types/mgmt_api', record: :none) do
          VCR.use_cassette('models/wcc_contentful/sync/initial', record: :none) do
            WCC::Contentful.init!
          end
        end

        # assert
        asset = WCC::ContentfulModel::Asset.find('2zKTmej544IakmIqoEu0y8')
        expect(asset).to_not be_nil
        expect(asset).to be_a(WCC::ContentfulModel::Asset)
        expect(asset.file.fileName).to eq('favicon.ico')
      end
    end

    context 'content_delivery = direct' do
      before(:each) do
        WCC::Contentful.configure do |config|
          config.content_delivery = :direct
        end
      end

      it 'builds out store using CDNAdapter' do
        # act
        VCR.use_cassette('models/wcc_contentful/content_types/mgmt_api', record: :none) do
          WCC::Contentful.init!
        end

        # assert
        expect(WCC::ContentfulModel.store).to be_a(WCC::Contentful::Store::CDNAdapter)

        page =
          VCR.use_cassette('models/wcc_contentful/entries/JhYhSfZPAOMqsaK8cYOUK') do
            WCC::ContentfulModel::Page.find('JhYhSfZPAOMqsaK8cYOUK')
          end
        expect(page.title).to eq('Ministries')
      end
    end
  end

  describe '.validate_models!' do
    let(:indexed_types) {
      load_indexed_types('contentful/indexed_types_from_content_type_indexer.json')
    }
    let(:models_dir) {
      File.dirname(__FILE__) + '/../../lib/wcc/contentful_model'
    }

    it 'validates successfully if all types present' do
      WCC::Contentful.instance_variable_set('@types', indexed_types)
      Dir["#{models_dir}/*.rb"].each { |file| load file }

      # act
      expect {
        WCC::Contentful.validate_models!
      }.to_not raise_error
    end

    it 'fails validation if menus not present' do
      types = indexed_types.except!('menu')
      WCC::Contentful::ModelBuilder.new(types).build_models
      WCC::Contentful.instance_variable_set('@types', types)

      load "#{models_dir}/menu.rb"

      # act
      expect {
        WCC::Contentful.validate_models!
      }.to raise_error(WCC::Contentful::ValidationError)
    end
  end
end
