# frozen_string_literal: true

require 'spec_helper'

class ShimTest
  include WCC::Contentful::ActiveRecordShim

  def self.content_type
    'shim-test'
  end
end

RSpec.describe WCC::Contentful::ActiveRecordShim do
  it 'defines methods' do
    expect(ShimTest).to respond_to(:model_name)
    expect(ShimTest).to respond_to(:table_name)
    expect(ShimTest).to respond_to(:unscoped)
    expect(ShimTest).to respond_to(:find_in_batches)
  end

  describe '.model_name' do
    it 'returns class name' do
      expect(ShimTest.model_name).to eq(ShimTest.name)
    end
  end

  describe '.table_name' do
    it 'returns class name in plural underscore format' do
      expect(ShimTest.table_name).to eq('shim_tests')
    end
  end

  describe '.unscoped' do
    let(:arg) { -> { 'test' } }

    it 'yields passed block' do
      expect(ShimTest.unscoped(&arg)).to eq(arg.call)
    end
  end

  describe '.find_in_batches' do
    it 'calls `find_all` with filters' do
      block = ->(batch) { batch }
      find_all = spy
      expect(ShimTest).to receive(:find_all)
        .with(options: hash_including(:limit, :skip, :include))
        .and_return(find_all)

      ShimTest.find_in_batches({ batch_size: 50 }, &block)

      expect(find_all).to have_received(:each_slice).with(50, &block)
    end
  end

  describe '.where' do
    it 'calls `find_all` with filters' do
      find_all = spy
      expect(ShimTest).to receive(:find_all)
        .with(id: %w[1 2 3])
        .and_return(find_all)

      result = ShimTest.where(id: %w[1 2 3])

      expect(result).to eq(find_all)
    end
  end

  describe '.const_get' do
    class ShimTest::ConstGetTest
      def self.content_type
        'const-get-test'
      end
    end

    class ConstGetTest < ShimTest::ConstGetTest
      include WCC::Contentful::ActiveRecordShim
    end

    it 'loads the top-level constant instead of the superclass' do
      got = ConstGetTest.const_get('ConstGetTest')

      expect(got).to eq(ConstGetTest)
    end
  end
end
