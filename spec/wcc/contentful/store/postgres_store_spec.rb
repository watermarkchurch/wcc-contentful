# frozen_string_literal: true

require 'wcc/contentful/store/postgres_store'

RSpec.describe WCC::Contentful::Store::PostgresStore do
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
end
