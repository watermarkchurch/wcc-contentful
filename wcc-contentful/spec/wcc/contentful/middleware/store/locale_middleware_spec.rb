# frozen_string_literal: true

RSpec.describe WCC::Contentful::Middleware::Store::LocaleMiddleware do
  let(:config) {
    WCC::Contentful::Configuration.new.tap do |c|
      c.default_locale = 'en-US'
      c.locale_fallbacks = {
        'es-US' => 'en-US'
      }
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

  let(:entry) do
    JSON.parse(<<~JSON)
      {
        "sys": {
          "space": {
            "sys": {
              "type": "Link",
              "linkType": "Space",
              "id": "343qxys30lid"
            }
          },
          "id": "2zKTmej544IakmIqoEu0y8",
          "type": "Entry",
          "createdAt": "2018-03-09T23:39:27.737Z",
          "updatedAt": "2018-03-09T23:39:27.737Z",
          "revision": 1,
          "contentType": {
            "sys": {
              "type": "Link",
              "linkType": "ContentType",
              "id": "page"
            }
          }
        },
        "fields": {
          "title": {
            "en-US": "This is a page",
            "es-US": "Esta es una pagina"
          },
          "slug": {
            "en-US": "some-page"
          },
          "hero": {
            "en-US": {
              "sys": {
                "type": "Link",
                "linkType": "Asset",
                "id": "3pWma8spR62aegAWAWacyA"
              }
            },
            "es-US": {
              "sys": {
                "type": "Link",
                "linkType": "Asset",
                "id": "2lxKGj91eW0zXj6NuZjj4y"
              }
            }
          }
        }
      }
    JSON
  end

  context 'no locale' do
    it 'find returns data from default locale' do
      store.index(entry)

      # act
      localized_entry = store.find('2zKTmej544IakmIqoEu0y8')

      # assert
      expect(localized_entry.dig('fields', 'title')).to eq('This is a page')
      expect(localized_entry.dig('fields', 'hero', 'sys', 'linkType')).to eq('Asset')
      expect(localized_entry.dig('fields', 'hero', 'sys', 'id')).to eq(
        '3pWma8spR62aegAWAWacyA'
      )
    end
  end

  context 'different locale' do
    it 'find returns data from specified locale' do
      store.index(entry)

      # act
      localized_entry = store.find('2zKTmej544IakmIqoEu0y8', locale: 'es-US')

      # assert
      expect(localized_entry.dig('fields', 'title')).to eq('Esta es una pagina')
      expect(localized_entry.dig('fields', 'slug')).to eq('some-page')
      expect(localized_entry.dig('fields', 'hero', 'sys', 'linkType')).to eq('Asset')
      expect(localized_entry.dig('fields', 'hero', 'sys', 'id')).to eq(
        '2lxKGj91eW0zXj6NuZjj4y'
      )
    end

    it 'falls back to defined fallbackLocale' do
      allow(config).to receive(:locale_fallbacks)
        .and_return({
          'es-MX' => 'es-ES',
          'es-ES' => 'es-US'
        })

      # add in an es-ES translation to fall back to
      entry['fields']['title']['es-ES'] = 'Esta es es-ES'
      store.index(entry)

      # act
      localized_entry = store.find('2zKTmej544IakmIqoEu0y8', locale: 'es-MX')

      # assert
      expect(localized_entry.dig('fields', 'title')).to eq('Esta es es-ES')
    end

    it 'continues falling back until a translation found' do
      allow(config).to receive(:locale_fallbacks)
        .and_return({
          'es-MX' => 'es-ES',
          'es-ES' => 'es-US'
        })

      # no es-ES translation, fall back to es-US
      store.index(entry)

      # act
      localized_entry = store.find('2zKTmej544IakmIqoEu0y8', locale: 'es-MX')

      # assert
      expect(localized_entry.dig('fields', 'title')).to eq('Esta es una pagina')
    end

    it 'stops falling back if no fallback found' do
      allow(config).to receive(:locale_fallbacks)
        .and_return({
          'es-MX' => 'es-ES',
          'es-ES' => nil
        })

      # no es-ES translation, fall back to es-US
      store.index(entry)

      # act
      localized_entry = store.find('2zKTmej544IakmIqoEu0y8', locale: 'es-MX')

      # assert
      expect(localized_entry.dig('fields', 'title')).to eq(nil)
    end
  end

  context 'locale: *' do
    it 'find returns all locales' do
      store.index(entry)

      # act
      localized_entry = store.find('2zKTmej544IakmIqoEu0y8', locale: '*')

      # assert
      expect(localized_entry.dig('fields', 'title', 'es-US')).to eq('Esta es una pagina')
      expect(localized_entry.dig('fields', 'title', 'en-US')).to eq('This is a page')
      expect(localized_entry.dig('fields', 'slug', 'es-US')).to eq(nil)
      expect(localized_entry.dig('fields', 'slug', 'en-US')).to eq('some-page')
      expect(localized_entry.dig('fields', 'hero', 'en-US', 'sys', 'id')).to eq(
        '3pWma8spR62aegAWAWacyA'
      )
      expect(localized_entry.dig('fields', 'hero', 'es-US', 'sys', 'id')).to eq(
        '2lxKGj91eW0zXj6NuZjj4y'
      )
    end
  end
end
