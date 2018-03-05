# frozen_string_literal: true

RSpec.describe WCC::Contentful::Store::PostgresStore do
  subject { WCC::Contentful::Store::PostgresStore.new(ENV['POSTGRES_CONNECTION']) }

  before :each do
    begin
      conn = PG.connect(ENV['POSTGRES_CONNECTION'] || { dbname: 'contentful' })

      conn.exec('DROP TABLE IF EXISTS contentful_raw')
    ensure
      conn.close
    end
  end

  it_behaves_like 'contentful store'
end
