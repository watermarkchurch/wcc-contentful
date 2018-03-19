# frozen_string_literal: true

RSpec.describe WCC::Contentful, :vcr do
  it 'has a version number' do
    expect(WCC::Contentful::VERSION).not_to be nil
  end

  let(:valid_contentful_access_token) { contentful_access_token }
  let(:valid_contentful_space_id) { contentful_space_id }
  let(:valid_contentful_default_locale) { 'en-US' }

  before do
    WCC::Contentful.configure do |config|
      config.access_token = valid_contentful_access_token
      config.space = valid_contentful_space_id
      config.content_delivery = :eager_sync
    end
  end

  after(:each) do
    consts = WCC::Contentful::Model.all_models.map(&:to_s).uniq
    consts.each do |c|
      begin
        WCC::Contentful::Model.send(:remove_const, c.split(':').last)
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

      it 'should set the Contentful client on the WCC::Contentful module' do
        client = WCC::Contentful.client

        expect(client).to be_a(WCC::Contentful::SimpleClient)
      end
    end

    context 'when passed INVALID configuration arguments' do
      it 'should error with a Contentful::Unauthorized' do
        WCC::Contentful.configure do |config|
          config.access_token = invalid_contentful_access_token
          config.space = invalid_contentful_space_id
          config.default_locale = invalid_contentful_default_locale
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
      before(:each) do
        WCC::Contentful.configure do |config|
          config.access_token = valid_contentful_access_token
          config.space = valid_contentful_space_id
          config.management_token = nil
          config.default_locale = nil
        end
      end

      it 'should populate models via CDN client' do
        # act
        WCC::Contentful.init!

        # assert
        content_type = WCC::Contentful::Model::MenuButton.content_type
        expect(content_type).to eq('menuButton')
      end

      it 'should populate store via sync API' do
        # act
        WCC::Contentful.init!

        # assert
        page = WCC::Contentful::Model.find('1UojJt7YoMiemCq2mGGUmQ')
        expect(page).to_not be_nil
        expect(page).to be_a(WCC::Contentful::Model::Page)
        expect(page.slug).to eq('/conferences')

        expect(page.sections).to be_nil
      end
    end

    context 'with management token' do
      before(:each) do
        WCC::Contentful.configure do |config|
          config.management_token = contentful_management_token
          config.default_locale = nil
        end
      end

      it 'should populate models via Management API cache' do
        # act
        WCC::Contentful.init!

        # assert
        content_type = WCC::Contentful::Model::Page.content_type
        expect(content_type).to eq('page')
      end

      it 'should populate store via sync API' do
        # act
        WCC::Contentful.init!

        # assert
        asset = WCC::Contentful::Model::Asset.find('2zKTmej544IakmIqoEu0y8')
        expect(asset).to_not be_nil
        expect(asset).to be_a(WCC::Contentful::Model::Asset)
        expect(asset.file.fileName).to eq('favicon.ico')
      end
    end

    context 'content_delivery = direct' do
      before(:each) do
        WCC::Contentful.configure do |config|
          config.management_token = contentful_management_token
          config.content_delivery = :direct
        end
      end

      it 'builds out store using CDNAdapter' do
        # act
        WCC::Contentful.init!

        # assert
        expect(WCC::Contentful::Model.store).to be_a(WCC::Contentful::Store::CDNAdapter)

        page = WCC::Contentful::Model::Page.find('JhYhSfZPAOMqsaK8cYOUK')
        expect(page.title).to eq('Ministries')
      end
    end
  end

  describe '.validate_models!' do
    let(:content_types) {
      raw = JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
      raw['items']
    }
    let(:models_dir) {
      File.dirname(__FILE__) + '/../../lib/wcc/contentful/model'
    }

    it 'validates successfully if all types present' do
      indexer =
        WCC::Contentful::ContentTypeIndexer.new.tap do |ixr|
          content_types.each { |type| ixr.index(type) }
        end
      types = indexer.types
      WCC::Contentful::ModelBuilder.new(types).build_models
      WCC::Contentful.instance_variable_set('@content_types', content_types)
      Dir["#{models_dir}/*.rb"].each { |file| load file }

      # act
      expect {
        WCC::Contentful.validate_models!
      }.to_not raise_error
    end

    it 'fails validation if menus not present' do
      all_but_menu = content_types.reject { |ct| ct.dig('sys', 'id') == 'menu' }
      indexer =
        WCC::Contentful::ContentTypeIndexer.new.tap do |ixr|
          all_but_menu.each { |type| ixr.index(type) }
        end
      types = indexer.types
      WCC::Contentful::ModelBuilder.new(types).build_models
      WCC::Contentful.instance_variable_set('@content_types', all_but_menu)

      load "#{models_dir}/menu.rb"

      # act
      expect {
        WCC::Contentful.validate_models!
      }.to raise_error(WCC::Contentful::ValidationError)
    end
  end
end
