# frozen_string_literal: true

require 'wcc/contentful/store/postgres_store'
require 'wcc/contentful/store/rspec_examples'
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

      conn.exec('DROP TABLE IF EXISTS wcc_contentful_schema_version CASCADE')
      conn.exec('DROP TABLE IF EXISTS contentful_raw CASCADE')
    ensure
      conn.close
    end
  end

  it_behaves_like 'contentful store', {
    nested_queries: true,
    include_param: true
  }

  let(:entry) do
    JSON.parse(<<~JSON)
      {
        "sys": {
          "space": {
            "sys": {
              "type": "Link",
              "linkType": "Space",
              "id": "343qxys30lid"
            }
          },
          "id": "Menu1ID",
          "type": "Entry",
          "createdAt": "2018-03-09T23:39:27.737Z",
          "updatedAt": "2018-03-09T23:39:27.737Z",
          "revision": 1,
          "contentType": {
            "sys": {
              "type": "Link",
              "linkType": "ContentType",
              "id": "menu"
            }
          }
        },
        "fields": {
          "title": {
            "en-US": "Top Nav"
          },
          "brandLink": {
            "en-US": {
              "sys": {
                "type": "Link",
                "linkType": "Entry",
                "id": "HomepageEntryID"
              }
            }
          },
          "brandIcon": {
            "en-US": {
              "sys": {
                "type": "Link",
                "linkType": "Asset",
                "id": "BrandAssetID"
              }
            }
          },
          "items": {
            "en-US": [
              {
                "sys": {
                  "type": "Link",
                  "linkType": "Entry",
                  "id": "Button1ID"
                }
              },
              {
                "sys": {
                  "type": "Link",
                  "linkType": "Entry",
                  "id": "Button2ID"
                }
              }
            ]
          }
        }
      }
    JSON
  end

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

  it 'stores links in separate column' do
    # act
    subject.set(entry.dig('sys', 'id'), entry)

    # assert
    row =
      subject.connection_pool.with do |conn|
        conn.exec("SELECT * FROM contentful_raw WHERE id = '#{entry.dig('sys', 'id')}'")
      end

    decoder = PG::TextDecoder::Array.new
    links = decoder.decode(row[0]['links'])
    expect(links.sort).to eq(
      %w[
        BrandAssetID
        Button1ID
        Button2ID
        HomepageEntryID
      ]
    )
  end

  it 'updates links in separate column' do
    old_entry = entry.deep_dup
    # no items links - pretend it's a field of a different type
    old_entry['fields']['items']['en-US'] = [
      'Some Text'
    ]

    subject.set(entry.dig('sys', 'id'), old_entry)
    # act
    subject.set(entry.dig('sys', 'id'), entry)

    # assert
    row =
      subject.connection_pool.with do |conn|
        conn.exec("SELECT * FROM contentful_raw WHERE id = '#{entry.dig('sys', 'id')}'")
      end

    decoder = PG::TextDecoder::Array.new
    links = decoder.decode(row[0]['links'])
    # includes the items links
    expect(links.sort).to eq(%w[
                               BrandAssetID
                               Button1ID
                               Button2ID
                               HomepageEntryID
                             ])
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
