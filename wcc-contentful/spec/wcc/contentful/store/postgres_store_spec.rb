# frozen_string_literal: true

require 'wcc/contentful/store/postgres_store'
require 'concurrency_helper'

RSpec.describe WCC::Contentful::Store::PostgresStore do
  include ConcurrencyHelper

  subject {
    WCC::Contentful::Store::PostgresStore.new(double('Configuration'),
      ENV['POSTGRES_CONNECTION'], size: 5)
  }

  before :each do
    begin
      conn = PG.connect(ENV['POSTGRES_CONNECTION'] || { dbname: 'postgres' })

      conn.exec('DROP TABLE IF EXISTS contentful_raw')
    ensure
      conn.close
    end
  end

  it_behaves_like 'contentful store'

  it 'returns all keys' do
    data = { 'key' => 'val', '1' => { 'deep' => 9 } }

    # act
    subject.set('1234', data)
    subject.set('5678', data)
    subject.set('9999', data)
    subject.set('8888', data)
    keys = subject.keys

    # assert
    expect(keys.sort).to eq(
      %w[1234 5678 8888 9999]
    )
  end

  it 'can be used in concurrent threads' do
    data = { 'key' => 'val' }
    subject.set('foo', data)

    # act
    results = do_in_threads(3) { subject.find('foo') }

    # assert
    expect(results).to eq([data, data, data])
  end

  context 'db does not exist' do
    subject {
      WCC::Contentful::Store::PostgresStore.new(double('Configuration'),
        { dbname: 'asdf' }, size: 5)
    }

    it '#set raises error' do
      expect {
        subject.set('foo', { 'key' => 'val' })
      }.to raise_error(PG::ConnectionBad)
    end

    it '#delete raises error' do
      expect {
        subject.delete('foo')
      }.to raise_error(PG::ConnectionBad)
    end

    # DB should not need to exist in order to run rake db:setup
    it '#find returns nil' do
      result = subject.find('foo')
      expect(result).to be nil
    end

    it '#find_all returns empty' do
      result = subject.find_all(content_type: 'foo').to_a
      expect(result).to eq([])
    end

    it '#keys returns empty' do
      result = subject.keys.to_a
      expect(result).to eq([])
    end
  end
end
