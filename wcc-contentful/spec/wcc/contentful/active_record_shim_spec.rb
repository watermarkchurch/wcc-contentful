# frozen_string_literal: true

require 'spec_helper'
require 'active_record'

class ShimTest
  include WCC::Contentful::ActiveRecordShim

  def initialize(raw)
    @raw = raw.freeze

    created_at = raw.dig('sys', 'createdAt')
    created_at = Time.parse(created_at) if created_at.present?
    updated_at = raw.dig('sys', 'updatedAt')
    updated_at = Time.parse(updated_at) if updated_at.present?
    @sys = WCC::Contentful::Sys.new(
      raw.dig('sys', 'id'),
      raw.dig('sys', 'type'),
      raw.dig('sys', 'locale') || 'en-US',
      raw.dig('sys', 'space', 'sys', 'id'),
      created_at,
      updated_at,
      raw.dig('sys', 'revision'),
      OpenStruct.new.freeze
    )
  end

  attr_reader :sys
  attr_reader :raw
  delegate :id, to: :sys
  delegate :created_at, to: :sys
  delegate :updated_at, to: :sys
  delegate :revision, to: :sys
  delegate :space, to: :sys

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

  describe '#cache_key' do
    let(:raw) {
      {
        'sys' => {
          'id' => 'ax1234',
          'type' => 'Entry',
          'createdAt' => '2019-05-10T18:59:25.828Z',
          'updatedAt' => '2019-05-10T18:59:25.828Z',
          'revision' => 1
        },
        'fields' => {}
      }
    }
    let(:subject) { ShimTest.new(raw) }

    context 'Rails 5.2' do
      before do
        allow(ActiveRecord::Base).to receive(:try)
          .with(:cache_versioning)
          .and_return(true)
      end

      it { expect(subject.cache_key).to eq('ShimTest/ax1234') }

      it '#cache_version' do
        expect(subject.cache_version).to eq('1')
      end

      it '#cache_key_with_version' do
        expect(subject.cache_key_with_version).to eq('ShimTest/ax1234-1')
      end
    end

    context 'Rails 5.1 and before' do
      before do
        allow(ActiveRecord::Base).to receive(:try)
          .with(:cache_versioning)
          .and_return(nil)
      end

      it { expect(subject.cache_key).to eq('ShimTest/ax1234-1') }
    end
  end
end
