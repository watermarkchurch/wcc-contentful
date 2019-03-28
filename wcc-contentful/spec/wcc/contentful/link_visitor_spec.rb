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

  context 'unresolved entry' do
    let(:response) {
      JSON.parse(load_fixture('contentful/lazy_cache_store/homepage_include_2.json'))
    }
    let(:entry) {
      response.dig('items', 0)
    }

    describe '#each' do
      it 'visits all links' do
        visited = []
        subject = described_class.new(entry.dup, :Link)

        result =
          subject.each do |link, field|
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
        subject = described_class.new(entry.dup, 'slug')

        subject.each do |value, field, locale|
          expect(field.name).to eq('slug')
          expect(field.type).to eq(:String)
          expect(locale).to eq('en-US')
          visited << value
        end

        expect(visited).to eq(['/'])
      end

      it 'visits all fields' do
        visited = {}
        subject = described_class.new(entry.dup)

        subject.each do |value, field|
          visited[field.name] ||= []
          visited[field.name] <<
            if field.type == :Link
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

  context 'resolved entry' do
    let(:entry) {
      JSON.parse(load_fixture('contentful/resolved_homepage_include_2.json'))
    }

    describe '#each' do
      it 'visits all links recursively' do
        visited = []
        subject = described_class.new(entry.dup, :Link, :Asset, depth: 2)

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

      it 'visits all slugs' do
        visited = []
        subject = described_class.new(entry.dup, 'slug', depth: 4)

        subject.each do |value, field, locale|
          expect(field.name).to eq('slug')
          expect(field.type).to eq(:String)
          expect(locale).to eq('en-US')
          visited << value
        end

        expect(visited).to eq([
                                '/',
                                '/ministries/reengage',
                                '/ministries/regen',
                                '/ministries/merge',
                                '/ministries/foundation-groups',
                                '/conferences/mmtc',
                                '/ctc',
                                '/conferences/yatc',
                                '/conferences/regeneration'
                              ])
      end

      it 'visits all fields' do
        visited = {}
        subject = described_class.new(entry.dup, depth: 2)

        subject.each do |value, field|
          visited[field.name] ||= []
          visited[field.name] <<
            if field.type == :Link
              value.dig('sys', 'id')
            else
              value
            end
        end

        expect(visited.keys).to eq(
          %w[
            title slug sections backgroundImage text primaryButton externalLink
            secondaryButton style tag subtext embedCode link items header subpages
            domainObject name actionButton faqs question answer
          ]
        )
      end

      it 'handles nil entries' do
        visited = []
        subject = described_class.new(entry.dup, :Link, :Asset, depth: 2)

        # insert a nil section & broken (nil) link
        entry.dig('fields', 'sections', 'en-US') << nil
        entry.dig('fields', 'sections', 'en-US', 2,
          'fields')['link'] = nil

        subject.each do |link|
          visited << link.dig('sys', 'id')
        end

        # Skip the 2nd section's link plus the two entries it linked to
        expect(visited.count).to eq(95)
      end
    end

    describe '#map!' do
      it 'writes to the same entry' do
        subject = described_class.new(entry.deep_dup, :Link, depth: 2)

        result =
          subject.map! do |link|
            link.merge({
              'resolved' => true
            })
          end

        expect(subject.entry).to_not eq(entry)
        expect(result).to eq(subject.entry)

        expect(subject.entry.dig('fields', 'sections', 'en-US', 2, 'resolved')).to eq(true)
        expect(subject.entry.dig('fields', 'sections', 'en-US', 2,
          'fields', 'items', 'en-US', 0,
          'fields', 'header', 'en-US'))
          .to eq({
            'sys' => {
              'type' => 'Link',
              'linkType' => 'Entry',
              'id' => '11RNBi9ANwc4QuyKmESGQg'
            },
            'resolved' => true
          })
      end
    end
  end
end
