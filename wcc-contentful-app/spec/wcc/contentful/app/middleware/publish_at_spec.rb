# frozen_string_literal: true

require 'spec_helper'
require 'wcc/contentful/app/middleware/publish_at'

RSpec.describe WCC::Contentful::App::Middleware::PublishAt do
  let(:job_entry_storage) {
    {}
  }
  before do
    storage = double

    allow(WCC::Contentful::App::Middleware::PublishAt).to receive(:job_entry_storage)
      .and_return(storage)
    allow(storage).to receive(:get) { |key| job_entry_storage[key] }
    allow(storage).to receive(:set) { |k, v| job_entry_storage[k] = v }
  end

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

  let(:store) { double('store', index?: false) }

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

      allow(store).to receive(:find).with('test', {}).and_return(entry)

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

      allow(store).to receive(:find).with('test', {}).and_return(entry)

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

      allow(store).to receive(:find).with('test', {}).and_return(entry)

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

      allow(store).to receive(:find).with('test', {}).and_return(entry)

      result = instance.find('test')

      expect(result).to be entry
    end

    it 'passes an entry with neither field' do
      entry = {
        'sys' => { 'id' => 'test' },
        'fields' => {
        }
      }

      allow(store).to receive(:find).with('test', {}).and_return(entry)

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

    it 'updates job entry storage when enqueuing job' do
      publish_at = Time.zone.parse((Time.zone.now + 1.minute).to_s)
      unpublish_at = Time.zone.parse((Time.zone.now + 2.minutes).to_s)
      entry = {
        'sys' => {
          'id' => 'test',
          'type' => 'Entry',
          'revision' => 2
        },
        'fields' => {
          'publishAt' => {
            'en-US' => publish_at.to_s
          },
          'unpublishAt' => {
            'en-US' => unpublish_at.to_s
          }
        }
      }

      configured_publish_job = double
      allow(WCC::Contentful::App::Middleware::PublishAt::Job).to receive(:set)
        .and_return(configured_publish_job)
      allow(configured_publish_job).to receive(:perform_later)

      configured_unpublish_job = double
      allow(WCC::Contentful::App::Middleware::PublishAt::Job).to receive(:set)
        .and_return(configured_unpublish_job)
      allow(configured_unpublish_job).to receive(:perform_later)

      # act
      instance.index(entry)

      # assert
      expect(job_entry_storage['WCC::Contentful::App::Middleware::PublishAt.Entry.test'])
        .to eq(entry)
    end

    it 'updates job entry storage when revision changes' do
      old_entry = {
        'sys' => {
          'id' => 'test',
          'type' => 'Entry',
          'revision' => 1
        },
        'fields' => {}
      }
      entry = {
        'sys' => {
          'id' => 'test',
          'type' => 'Entry',
          'revision' => 2
        },
        'fields' => {}
      }

      job_entry_storage['WCC::Contentful::App::Middleware::PublishAt.Entry.test'] = old_entry

      # act
      instance.index(entry)

      # assert
      expect(job_entry_storage['WCC::Contentful::App::Middleware::PublishAt.Entry.test'])
        .to eq(entry)
    end

    it 'does not add to job entry storage if no job to enqueue' do
      publish_at = Time.zone.now - 1.minute
      entry = {
        'sys' => { 'id' => 'test', 'type' => 'Entry' },
        'fields' => {
          'publishAt' => {
            'en-US' => publish_at.to_s
          }
        }
      }

      # act
      instance.index(entry)

      # assert
      expect(job_entry_storage.count).to eq(0)
    end

    it 'calls index on the backing store if it responds to index' do
      entry = {
        'sys' => { 'id' => 'test', 'type' => 'Entry' },
        'fields' => {
        }
      }

      allow(store).to receive(:index?).and_return(true)
      expect(store).to receive(:index).with(entry)

      instance.index(entry)
    end

    it 'does not call index on the backing store if it doesnt respond to index' do
      entry = {
        'sys' => { 'id' => 'test', 'type' => 'Entry' },
        'fields' => {
        }
      }

      expect(store).to_not receive(:index)

      instance.index(entry)
    end
  end

  describe 'Job' do
    before do
      allow(WCC::Contentful::Services)
        .to receive(:instance)
        .and_return(double(sync_engine: double(subscribe: nil)))
    end

    describe '#perform' do
      it 'emits the entry on WCC::Contentful::Events' do
        emitted = []
        WCC::Contentful::Events.subscribe(
          ->(entry) { emitted << entry },
          with: :call
        )

        publish_at = Time.zone.parse((Time.zone.now - 1.minute).to_s)
        entry = {
          'sys' => { 'id' => 'test', 'type' => 'Entry', 'revision' => 1 },
          'fields' => {
            'publishAt' => {
              'en-US' => publish_at.to_s
            }
          }
        }

        job_entry_storage['WCC::Contentful::App::Middleware::PublishAt.Entry.test'] = entry

        WCC::Contentful::App::Middleware::PublishAt::Job.perform_now(entry)

        expect(emitted.length).to eq(1)
        event = emitted[0]
        expect(event).to be_a WCC::Contentful::Event::Entry
        expect(event.raw).to eq(entry)
      end

      it 'emits a DeletedEntry on WCC::Contentful::Events' do
        emitted = []
        WCC::Contentful::Events.subscribe(
          ->(entry) { emitted << entry },
          with: :call
        )

        unpublish_at = Time.zone.parse((Time.zone.now - 1.minute).to_s)
        entry = {
          'sys' => { 'id' => 'test', 'type' => 'Entry', 'revision' => 1 },
          'fields' => {
            'unpublishAt' => {
              'en-US' => unpublish_at.to_s
            }
          }
        }
        job_entry_storage['WCC::Contentful::App::Middleware::PublishAt.Entry.test'] = entry

        WCC::Contentful::App::Middleware::PublishAt::Job.perform_now(entry)

        expect(emitted.length).to eq(1)
        event = emitted[0]
        expect(event).to be_a WCC::Contentful::Event::DeletedEntry
        expect(event.raw).to eq({
          'sys' => { 'id' => 'test', 'type' => 'DeletedEntry', 'revision' => 1 }
          # no fields in a DeletedEntry
        })
      end

      it 'does not emit if the entry has been updated' do
        emitted = []
        WCC::Contentful::Events.subscribe(
          ->(entry) { emitted << entry },
          with: :call
        )

        unpublish_at = Time.zone.parse((Time.zone.now - 1.minute).to_s)
        entry = {
          'sys' => { 'id' => 'test', 'type' => 'Entry', 'revision' => 1 },
          'fields' => {
            'unpublishAt' => {
              'en-US' => unpublish_at.to_s
            }
          }
        }
        updated_entry = {
          'sys' => { 'id' => 'test', 'type' => 'Entry', 'revision' => 2 }
        }
        job_entry_storage['WCC::Contentful::App::Middleware::PublishAt.Entry.test'] = updated_entry

        WCC::Contentful::App::Middleware::PublishAt::Job.perform_now(entry)

        expect(emitted.length).to eq(0)
      end
    end
  end
end
