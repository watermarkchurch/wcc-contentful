# frozen_string_literal: true

require 'wcc/contentful/downloads_schema'

RSpec.describe WCC::Contentful::DownloadsSchema do
  describe '#call' do
    let(:content_types) {
      fixture = JSON.parse(load_fixture('contentful/contentful-schema-from-export.json'))
      fixture['contentTypes']
    }

    let(:editor_interfaces) {
      fixture = JSON.parse(load_fixture('contentful/contentful-schema-from-export.json'))
      fixture['editorInterfaces']
    }

    let(:management_client) {
      client = double(
        content_types: double(
          items: content_types.deep_dup
        )
      )

      allow(client).to receive(:editor_interface) do |content_type_id, _query = {}|
        double(
          raw: editor_interfaces
            .find { |i| i.dig('sys', 'contentType', 'sys', 'id') == content_type_id }
            .deep_dup
        )
      end
      client
    }

    let(:subject) {
      described_class.new('db/contentful-schema.json', management_client: management_client)
    }

    it 'creates directory' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          expect(File.exist?('db/contentful-schema.json')).to be false

          subject.call

          expect(File.exist?('db/contentful-schema.json')).to be true
        end
      end
    end

    it 'writes file with proper formatting' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('db')
          FileUtils.touch('db/contentful-schema.json')

          subject.call

          expect(File.read('db/contentful-schema.json'))
            .to eq(load_fixture('contentful/contentful-schema.json'))
        end
      end
    end

    it 'does not overwrite file if it is up to date' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          FileUtils.mkdir_p('db')
          FileUtils.cp(
            File.join(fixture_root, 'contentful/contentful-schema-from-export.json'),
            'db/contentful-schema.json'
          )

          subject.call

          expect(File.read('db/contentful-schema.json'))
            .to eq(load_fixture('contentful/contentful-schema-from-export.json'))
        end
      end
    end
  end
end
