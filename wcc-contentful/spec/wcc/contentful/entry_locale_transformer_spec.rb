# frozen_string_literal: true

RSpec.describe WCC::Contentful::EntryLocaleTransformer do
  let(:config) {
    WCC::Contentful::Configuration.new.tap do |c|
      c.default_locale = 'en-US'
      c.locale_fallbacks = {
        'es-US' => 'en-US'
      }
    end
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

  subject {
    described_class
  }

  before do
    allow(subject).to receive(:configuration).and_return(config)
  end

  describe '.transform_to_locale' do
    it 'picks fields from specified locale' do
      localized_entry = subject.transform_to_locale(entry, 'es-US')

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

      # act
      localized_entry = subject.transform_to_locale(entry, 'es-MX')

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

      # act
      localized_entry = subject.transform_to_locale(entry, 'es-MX')

      # assert
      expect(localized_entry.dig('fields', 'title')).to eq('Esta es una pagina')
    end

    it 'stops falling back if no fallback found' do
      allow(config).to receive(:locale_fallbacks)
        .and_return({
          'es-MX' => 'es-ES',
          'es-ES' => nil
        })

      # no es-ES translation, fallback is nil, do not use en-US

      # act
      localized_entry = subject.transform_to_locale(entry, 'es-MX')

      # assert
      expect(localized_entry.dig('fields', 'title')).to eq(nil)
    end

    it 'does not modify the original entry' do
      # act
      _localized_entry = subject.transform_to_locale(entry, 'es-US')

      # assert
      expect(entry.dig('sys', 'locale')).to eq(nil)
      expect(entry.dig('fields', 'title').keys).to eq(%w[en-US es-US])
    end
  end

  describe '.reduce_to_star' do
    let(:localized_entry) {
      JSON.parse(<<~JSON)
        {
          "sys": {
            "id": "2zKTmej544IakmIqoEu0y8",
            "type": "Entry",
            "revision": 1,
            "locale": "es-MX"
          },
          "fields": {
            "title": "esta es es-MX",
            "slug": "some-page",
            "hero": {
              "sys": {
                "type": "Link",
                "linkType": "Asset",
                "id": "2lxKGj91eW0zXj6NuZjj4y"
              }
            }
          }
        }
      JSON
    }
    it 'merges in a locale to the memo entry' do
      # act
      memo = subject.reduce_to_star(entry, localized_entry)

      # assert
      expect(memo.dig('sys', 'id')).to eq('2zKTmej544IakmIqoEu0y8')
      expect(memo.dig('sys', 'locale')).to be_nil
      expect(memo.dig('fields', 'title', 'es-MX')).to eq(
        'esta es es-MX'
      )
      # preserves existing field
      expect(memo.dig('fields', 'title', 'es-US')).to eq(
        'Esta es una pagina'
      )

      # Merges in fallback value - this is OK
      expect(memo.dig('fields', 'slug', 'es-MX')).to eq('some-page')
      expect(memo.dig('fields', 'slug', 'en-US')).to eq('some-page')
    end
  end

  describe '.transform_to_star' do
    let(:localized_entry) {
      JSON.parse(<<~JSON)
        {
          "sys": {
            "id": "2zKTmej544IakmIqoEu0y8",
            "type": "Entry",
            "revision": 1,
            "locale": "es-MX"
          },
          "fields": {
            "title": "esta es es-MX",
            "slug": "some-page",
            "hero": {
              "sys": {
                "type": "Link",
                "linkType": "Asset",
                "id": "2lxKGj91eW0zXj6NuZjj4y"
              }
            }
          }
        }
      JSON
    }

    it 'moves fields to locale=* format' do
      # act
      entry = subject.transform_to_star(localized_entry)

      expect(entry.dig('sys', 'id')).to eq('2zKTmej544IakmIqoEu0y8')
      # removes locale field
      expect(entry.dig('sys', 'locale')).to be_nil

      expect(entry.dig('fields', 'title')).to be_a Hash
      expect(entry.dig('fields', 'title', 'es-MX')).to eq('esta es es-MX')
      expect(entry.dig('fields', 'slug', 'es-MX')).to eq('some-page')
      expect(entry.dig('fields', 'hero', 'es-MX', 'sys', 'id')).to eq(
        '2lxKGj91eW0zXj6NuZjj4y'
      )
    end
  end
end
