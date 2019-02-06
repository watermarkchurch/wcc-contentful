# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::LinkVisitor do
  let(:subject) { described_class.new(entry.dup) }

  before do
    content_types = JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
    indexer = WCC::Contentful::ContentTypeIndexer.new
    content_types['items'].each do |raw_content_type|
      indexer.index(raw_content_type)
    end
    allow(WCC::Contentful).to receive(:types)
      .and_return(indexer.types)
  end

  context 'unresolved entry' do
    let(:response) {
      JSON.parse(load_fixture('contentful/lazy_cache_store/homepage_include_2.json'))
    }
    let(:entry) {
      response.dig('items', 0)
    }

    describe '#visit' do
      it 'visits all links' do
        visited = []

        result =
          subject.visit(:Link) do |link, field|
            expect(field.name).to eq('sections')
            expect(link.dig('sys', 'type')).to eq('Link')
            visited << link.dig('sys', 'id')
          end

        expect(result).to be nil
        expect(subject.entry).to eq(entry)
        expect(visited).to eq(%w[
                                1vLsSaBmPeKW80qS6M0KSg
                                4rquxbmohiuaWAMeSs8OSS
                                Hmw8ax6yMUOmKE8e80euo
                                2qinjlj49quMCm2W2g2oec
                                4brZj69fjW8wC4GwW8qmMQ
                              ])
      end

      it 'visits all slugs' do
        visited = []

        subject.visit('slug') do |value, field, locale|
          expect(field.name).to eq('slug')
          expect(field.type).to eq(:String)
          expect(locale).to eq('en-US')
          visited << value
        end

        expect(visited).to eq(['/'])
      end

      it 'visits all fields' do
        visited = {}

        subject.visit do |value, field|
          visited[field.name] ||= []
          visited[field.name] << if field.type == :Link
                                   value.dig('sys', 'id')
                                 else
                                   value
                           end
        end

        expect(visited).to eq({
          'title' => ['Watermark Resources'],
          'slug' => ['/'],
          'sections' => %w[
            1vLsSaBmPeKW80qS6M0KSg
            4rquxbmohiuaWAMeSs8OSS
            Hmw8ax6yMUOmKE8e80euo
            2qinjlj49quMCm2W2g2oec
            4brZj69fjW8wC4GwW8qmMQ
          ]
        })
      end
    end
  end
end
