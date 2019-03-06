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

  describe '#index' do
    it 'does not drop a job when publish_at in the past' do
      publish_at = Time.zone.now - 1.minute
      entry = {
        'sys' => { 'id' => 'test', 'type' => 'Entry' },
        'fields' => {
          'publishAt' => {
            'en-US' => publish_at.to_s
          }
        }
      }

      expect(store).to receive(:index).with(entry)
      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue)
      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue_at)

      instance.index(entry)
    end

    it 'does not drop a job when unpublish_at in the past' do
      publish_at = Time.zone.now - 1.minute
      entry = {
        'sys' => { 'id' => 'test', 'type' => 'Entry' },
        'fields' => {
          'unpublishAt' => {
            'en-US' => publish_at.to_s
          }
        }
      }

      expect(store).to receive(:index).with(entry)
      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue)
      expect(ActiveJob::Base.queue_adapter).to_not receive(:enqueue_at)

      instance.index(entry)
    end

    it 'drops a job for both publishAt and unpublishAt' do
      publish_at = Time.zone.parse((Time.zone.now + 1.minute).to_s)
      unpublish_at = Time.zone.parse((Time.zone.now + 2.minutes).to_s)
      entry = {
        'sys' => { 'id' => 'test', 'type' => 'Entry' },
        'fields' => {
          'publishAt' => {
            'en-US' => publish_at.to_s
          },
          'unpublishAt' => {
            'en-US' => unpublish_at.to_s
          }
        }
      }

      expect(store).to receive(:index).with(entry)

      configured_publish_job = double
      expect(WCC::Contentful::App::Middleware::PublishAt::Job).to receive(:set)
        .with(wait_until: publish_at + 1.second)
        .and_return(configured_publish_job)
      expect(configured_publish_job).to receive(:perform_later)
        .with(entry)

      configured_unpublish_job = double
      expect(WCC::Contentful::App::Middleware::PublishAt::Job).to receive(:set)
        .with(wait_until: unpublish_at + 1.second)
        .and_return(configured_unpublish_job)
      expect(configured_unpublish_job).to receive(:perform_later)
        .with(entry)

      # act
      instance.index(entry)
    end
  end

  describe 'Job' do
    describe '#perform' do
      it 'emits the entry on WCC::Contentful::Events' do
        allow(WCC::Contentful::Services)
          .to receive(:instance)
          .and_return(double(sync_engine: double(subscribe: nil)))

        emitted = []
        WCC::Contentful::Events.subscribe(
          ->(entry) { emitted << entry },
          with: :call
        )

        publish_at = Time.zone.parse((Time.zone.now - 1.minute).to_s)
        entry = {
          'sys' => { 'id' => 'test', 'type' => 'Entry' },
          'fields' => {
            'publishAt' => {
              'en-US' => publish_at.to_s
            }
          }
        }

        WCC::Contentful::App::Middleware::PublishAt::Job.perform_now(entry)

        expect(emitted.length).to eq(1)
        event = emitted[0]
        expect(event).to be_a WCC::Contentful::Event::Entry
        expect(event.raw).to eq(entry)
      end

      it 'emits a DeletedEntry on WCC::Contentful::Events' do
        allow(WCC::Contentful::Services)
          .to receive(:instance)
          .and_return(double(sync_engine: double(subscribe: nil)))

        emitted = []
        WCC::Contentful::Events.subscribe(
          ->(entry) { emitted << entry },
          with: :call
        )

        unpublish_at = Time.zone.parse((Time.zone.now - 1.minute).to_s)
        entry = {
          'sys' => { 'id' => 'test', 'type' => 'Entry' },
          'fields' => {
            'unpublishAt' => {
              'en-US' => unpublish_at.to_s
            }
          }
        }

        WCC::Contentful::App::Middleware::PublishAt::Job.perform_now(entry)

        expect(emitted.length).to eq(1)
        event = emitted[0]
        expect(event).to be_a WCC::Contentful::Event::DeletedEntry
        expect(event.raw).to eq({
          'sys' => { 'id' => 'test', 'type' => 'DeletedEntry' }
          # no fields in a DeletedEntry
        })
      end
    end
  end
end
