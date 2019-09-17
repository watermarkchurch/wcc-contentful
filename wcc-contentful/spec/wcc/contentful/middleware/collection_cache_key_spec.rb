# frozen_string_literal: true

require 'rails_helper'

require 'wcc/contentful/middleware/collection_cache_key'

RSpec.describe WCC::Contentful::Middleware::CollectionCacheKey do
  let(:next_store) { double }

  subject(:instance) {
    described_class.new.tap { |i| i.store = next_store }
  }

  before do
    allow(WCC::Contentful).to receive(:types)
      .and_return({
        'test1' => double(fields: {
          'title' => double(name: 'title', type: :String, array: false),
          'link' => double(name: 'link', type: :Link, array: false),
          'links' => double(name: 'links', type: :Link, array: true)
        })
      })
  end

  %i[
    index
    index?
    set
    delete
  ].each do |method|
    it "delegates #{method} to backing store" do
      expect(next_store).to receive(method)

      subject.public_send(method)
    end
  end

  context 'without cache' do
    describe 'find_all #last_modified' do
      let!(:backing_query) {
        double('backing_query', content_type: 'test1').tap do |query|
          expect(next_store).to receive(:find_all)
            .with(content_type: 'test1', options: nil)
            .and_return(query)
        end
      }

      it 'returns latest updated_at from backing store' do
        query = instance.find_all(content_type: 'test1')

        expect(next_store).to receive(:find_by)
          .with(content_type: 'test1', options: {
            order: '-sys.updatedAt'
          })
          .and_return({
            'sys' => { 'id' => 'A1', 'updatedAt' => '123', 'type' => 'Entry' }
          })

        expect(query.last_modified).to eq('123')
      end

      it 'returns cache_key derived from last entry' do
        query = instance.find_all(content_type: 'test1')

        expect(next_store).to receive(:find_by)
          .with(content_type: 'test1', options: {
            order: '-sys.updatedAt'
          })
          .and_return({
            'sys' => { 'id' => 'A1', 'updatedAt' => '123', 'type' => 'Entry' }
          })

        expect(query.cache_key).to eq(Digest::SHA1.hexdigest('A1:123:'))
      end

      it 'includes relation in cache key' do
        query = instance.find_all(content_type: 'test1')
        expect(backing_query).to receive(:apply_operator)
          .and_return(backing_query)
        expect(backing_query).to receive(:nested_conditions)
          .and_return(backing_query)
        query = query.apply({
          'slug' => 'asdf',
          'link' => { id: '1234' }
        })

        expect(next_store).to receive(:find_by)
          .with(content_type: 'test1', options: {
            order: '-sys.updatedAt'
          })
          .and_return({
            'sys' => { 'id' => 'A1', 'updatedAt' => '123', 'type' => 'Entry' }
          })

        expect(query.cache_key).to eq(
          Digest::SHA1.hexdigest(
            'A1:123:link%5Bid%5D=1234&slug%5Beq%5D=asdf'
          )
        )
      end
    end
  end

  def sys
    {
      'id' => SecureRandom.urlsafe_base64,
      'type' => 'Entry',
      'contentType' => content_type
    }
  end

  def content_type
    {
      'sys' => {
        'linkType' => 'ContentType',
        'type' => 'Link',
        'id' => 'test1'
      }
    }
  end
end
