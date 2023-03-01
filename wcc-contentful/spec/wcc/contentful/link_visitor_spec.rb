# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::LinkVisitor do
  before do
    content_types = JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
    indexer = WCC::Contentful::ContentTypeIndexer.new
    content_types['items'].each do |raw_content_type|
      indexer.index(raw_content_type)
    end
    allow(WCC::Contentful).to receive(:types)
      .and_return(indexer.types)
  end

  shared_examples 'unresolved entry' do
    describe '#each' do
      it 'visits all links' do
        visited = []
        subject = described_class.new(entry.dup, :Link)

        result =
          subject.each do |link, field|
            expect(field).to eq('sections')
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

      it 'visits all fields' do
        visited = {}
        subject = described_class.new(entry.dup)

        subject.each do |value, field|
          visited[field] ||= []
          visited[field] <<
            if value.is_a?(Hash)
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

  context 'with locale = *' do
    let(:response) {
      JSON.parse(load_fixture('contentful/lazy_cache_store/homepage_include_2.json'))
    }
    let(:entry) {
      response.dig('items', 0)
    }

    it_behaves_like 'unresolved entry'
  end

  context 'unresolved entry with sys.locale' do
    let(:response) {
      JSON.parse(load_fixture('contentful/lazy_cache_store/homepage_include_2_in_locale.json'))
    }
    let(:entry) {
      response.dig('items', 0)
    }

    it_behaves_like 'unresolved entry'
  end

  shared_examples 'resolved entry' do
    describe '#each' do
      it 'visits all links recursively' do
        visited = []
        subject = described_class.new(entry.dup, :Link, :Entry, :Asset, depth: 2)

        result =
          subject.each do |link, _field|
            # entry or link
            expect(%w[Entry Asset Link]).to include(link.dig('sys', 'type'))
            visited << link.dig('sys', 'id')
          end

        expect(result).to be nil
        expect(subject.entry).to eq(entry)
        expect(visited.count).to eq(97)
        # does not yield the base entry
        expect(visited).to_not include(entry.dig('sys', 'id'))
      end

      it 'visits all fields' do
        visited = {}
        subject = described_class.new(entry.dup, depth: 2)

        subject.each do |value, field|
          visited[field] ||= []
          visited[field] <<
            if value.is_a?(Hash)
              value.dig('sys', 'id')
            else
              value
            end
        end

        expected = %w[
          title slug sections backgroundImage text primaryButton externalLink
          secondaryButton style tag subtext embedCode link items header subpages
          domainObject name actionButton faqs question answer
          ionIcon
        ]
        expect(expected - visited.keys).to eq([])
        expect(visited.keys - expected).to eq([])
      end

      it 'handles nil entries' do
        visited = []
        subject = described_class.new(entry.dup, :Link, :Entry, :Asset, depth: 2)

        # insert a nil section & broken (nil) link
        sections = entry.dig('fields', 'sections')
        sections = sections['en-US'] unless entry.dig('sys', 'locale')
        sections << nil
        sections[2]['fields']['link'] = nil

        subject.each do |link|
          visited << link.dig('sys', 'id')
        end

        # Skip the 2nd section's link plus the two entries it linked to
        expect(visited.count).to eq(95)
      end
    end

    describe '#map!' do
      it 'writes to the same entry' do
        locale = entry.dig('sys', 'locale')

        subject = described_class.new(entry.deep_dup, :Link, depth: 2)

        # act
        result =
          subject.map! do |link|
            link.merge({
              'resolved' => true
            })
          end

        expect(subject.entry).to_not eq(entry)
        expect(result).to eq(subject.entry)

        sections = subject.entry.dig('fields', 'sections')
        sections = sections['en-US'] unless locale

        link = sections[2]
        # Since this is not a link, but rather an Entry, it does not get yielded
        # and so does not have the "resolved" marker
        expect(link.keys).to_not include('resolved')
        # Instead it keeps the value that it already had
        title = link.dig('fields', 'title')
        title = title['en-US'] unless locale
        expect(title).to eq('Featured Ministries')
      end
    end
  end

  context 'resolved entry with locale=*' do
    let(:entry) {
      JSON.parse(load_fixture('contentful/resolved_homepage_include_2.json'))
    }

    it_behaves_like 'resolved entry'
  end

  context 'resolved entry with sys.locale' do
    let(:entry) {
      JSON.parse(load_fixture('contentful/resolved_homepage_include_2_in_locale.json'))
    }

    it_behaves_like 'resolved entry'
  end
end
