# frozen_string_literal: true

RSpec.describe WCC::Contentful::Middleware::Store::LocaleMiddleware do
  let(:config) {
    WCC::Contentful::Configuration.new.tap do |c|
      c.default_locale = 'es-ES'
      c.store :eager_sync, :memory do
        middleware.clear
        use WCC::Contentful::Middleware::Store::LocaleMiddleware
      end
    end
  }

  let(:services) {
    WCC::Contentful::Services.new(config)
  }

  subject(:store) {
    config.store.build(services)
  }

  context 'no locale' do
    it 'find returns data from default locale'
  end

  context 'different locale'

  context 'locale: *'
end
