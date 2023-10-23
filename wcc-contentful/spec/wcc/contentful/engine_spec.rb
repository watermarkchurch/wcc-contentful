# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'WCC::Contentful::Engine', rails: true do
  let(:described_class) {
    WCC::Contentful::Engine
  }

  def run_initializers
    app = Rails.application
    described_class.initializers.each do |initializer|
      initializer.run(app)
    end
    app.reloader.prepare!
  end

  describe 'initializers' do
    let(:body) {
      JSON.parse(load_fixture('contentful/contentful_published_blog.json'))
    }

    let(:event) { WCC::Contentful::Event.from_raw(body) }
    let(:webhook_controller) { double(class: WCC::Contentful::WebhookController) }

    before do
      WCC::Contentful.configure do |config|
        config.webhook_username = 'tester1'
        config.webhook_password = 'password1'
        config.space = contentful_space_id
        config.access_token = contentful_access_token

        # required in order to trigger SyncEngine::Job
        config.store = :eager_sync, :memory
      end
    end

    it 'runs a sync on Entry event' do
      expect(WCC::Contentful::SyncEngine::Job).to receive(:perform_later)
        .with(hash_including(body))
      run_initializers

      # act
      Wisper::GlobalListeners.registrations.each do |registration|
        registration.broadcast('Entry', webhook_controller, event)
      end
    end

    it 'runs a sync even in master environment' do
      WCC::Contentful.configure do |config|
        config.environment = 'staging'
      end
      run_initializers

      # expect
      expect(WCC::Contentful::SyncEngine::Job).to receive(:perform_later)

      # act
      Wisper::GlobalListeners.registrations.each do |registration|
        registration.broadcast('Entry', webhook_controller, event)
      end
    end

    it 'runs configured jobs on success' do
      my_job = double(perform_later: nil)
      expect(WCC::Contentful.configuration).to receive(:webhook_jobs)
        .and_return([my_job])
      run_initializers

      expect(my_job).to receive(:perform_later)
        .with(hash_including(body))

      # act
      Wisper::GlobalListeners.registrations.each do |registration|
        registration.broadcast('Entry', webhook_controller, event)
      end
    end

    it 'continues running jobs even if one fails' do
      jobs = [
        double,
        double
      ]
      allow(jobs[0]).to receive(:perform_later)
        .and_raise(ArgumentError, 'boom')
      expect(jobs[1]).to receive(:perform_later)

      expect(WCC::Contentful.configuration).to receive(:webhook_jobs)
        .and_return(jobs)
      run_initializers

      # act
      Wisper::GlobalListeners.registrations.each do |registration|
        registration.broadcast('Entry', webhook_controller, event)
      end
    end
  end
end
