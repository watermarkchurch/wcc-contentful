# frozen_string_literal: true

require 'spec_helper'

class ShimTest
  include WCC::Contentful::ActiveRecordShim
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
end
