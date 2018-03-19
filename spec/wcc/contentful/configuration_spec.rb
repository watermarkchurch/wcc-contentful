# frozen_string_literal: true

RSpec.describe WCC::Contentful::Configuration do
  subject(:config) { WCC::Contentful::Configuration.new }

  describe '#content_delivery' do
    it 'raises error when setting invalid content delivery method' do
      expect {
        config.content_delivery = :asdf
      }.to raise_error(ArgumentError)
    end

    it 'sets content delivery method when value is valid' do
      # act
      config.content_delivery = :eager_sync

      # assert
      expect(config.content_delivery).to eq(:eager_sync)
    end
  end

  describe '#sync_store' do
    it 'raises error when setting invalid store type' do
      expect {
        config.sync_store = :asdf
      }.to raise_error(ArgumentError)
    end

    it 'sets content delivery method when value is valid' do
      # act
      config.sync_store = :postgres

      # assert
      expect(config.sync_store).to be_a(WCC::Contentful::Store::PostgresStore)
    end
  end
end
