# frozen_string_literal: true

require 'spec_helper'
require 'wcc/contentful/app/middleware/publish_at'

RSpec.describe WCC::Contentful::App::Middleware::PublishAt do
  describe '.call' do
    it 'creates a middleware' do
      result = described_class.call(double('store'), [], double('config'))

      expect(result).to be_a described_class
    end

    it 'does not return an instance if preview is true' do
      result = described_class.call(double('store'), [{ preview: true }], double('config'))

      expect(result).to be_nil
    end
  end

  let(:store) { double('store') }

  subject(:instance) {
    described_class.call(store, [], double('config'))
  }

  describe '#find' do
    it 'ignores an entry with publishAt after now' do
      publish_at = Time.zone.now + 1.minute
      entry = {
        'sys' => { 'id' => 'test' },
        'fields' => {
          'publishAt' => {
            'en-US' => publish_at.to_s
          }
        }
      }

      allow(store).to receive(:find).with('test').and_return(entry)

      result = instance.find('test')

      expect(result).to be_nil
    end

    it 'passes an entry with publishAt before now' do
      publish_at = Time.zone.now - 1.minute
      entry = {
        'sys' => { 'id' => 'test' },
        'fields' => {
          'publishAt' => {
            'en-US' => publish_at.to_s
          }
        }
      }

      allow(store).to receive(:find).with('test').and_return(entry)

      result = instance.find('test')

      expect(result).to be entry
    end

    it 'ignores an entry with unpublishAt before now' do
      publish_at = Time.zone.now - 1.minute
      entry = {
        'sys' => { 'id' => 'test' },
        'fields' => {
          'unpublishAt' => {
            'en-US' => publish_at.to_s
          }
        }
      }

      allow(store).to receive(:find).with('test').and_return(entry)

      result = instance.find('test')

      expect(result).to be_nil
    end

    it 'passes an entry with unpublishAt after now' do
      publish_at = Time.zone.now + 1.minute
      entry = {
        'sys' => { 'id' => 'test' },
        'fields' => {
          'unpublishAt' => {
            'en-US' => publish_at.to_s
          }
        }
      }

      allow(store).to receive(:find).with('test').and_return(entry)

      result = instance.find('test')

      expect(result).to be entry
    end

    it 'passes an entry with neither field' do
      entry = {
        'sys' => { 'id' => 'test' },
        'fields' => {
        }
      }

      allow(store).to receive(:find).with('test').and_return(entry)

      result = instance.find('test')

      expect(result).to be entry
    end
  end
end
