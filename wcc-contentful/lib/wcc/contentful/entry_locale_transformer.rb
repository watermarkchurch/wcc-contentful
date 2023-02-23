# frozen_string_literal: true

##
# This class provides helper methods to transform Entry and Asset hashes
module WCC::Contentful::EntryLocaleTransformer
  extend self

  # Attribute reader falling back to WCC::Contentful configuration
  # needed for locale fallbacks
  def configuration
    @configuration || WCC::Contentful.configuration
  end

  ##
  # Takes an entry which represents a specific 'sys.locale' and transforms it
  # to the 'locale=*' format
  def transform_to_star(entry)
    # locale=* entries have a nil sys.locale
    unless entry_locale = entry.dig('sys', 'locale')
      # nothing to do
      return entry
    end

    sys = entry['sys'].except('locale').merge({
      'WCC::Contentful::EntryLocaleTransformer:locales_included' => [entry_locale]
    })
    fields =
      entry['fields'].transform_values do |value|
        h = {}
        h[entry_locale] = value
        h
      end

    {
      'sys' => sys,
      'fields' => fields
    }
  end

  ##
  # Takes an entry in the 'locale=*' format and transforms it to a specific locale
  def transform_to_locale(entry, locale)
    # If the backing store already returned a localized entry, nothing to do
    if entry_locale = entry.dig('sys', 'locale')
      unless entry_locale == locale
        raise WCC::Contentful::LocaleMismatchError,
          "expected #{locale} but was #{entry_locale}"
      end

      return entry
    end
    return entry unless entry['fields']

    # Transform the store's "locale=*" entry into a localized one
    locale ||= default_locale

    entry = entry.dup
    entry['sys']['locale'] = locale
    entry['fields'] =
      entry['fields'].transform_values do |value|
        next if value.nil?

        # replace the all-locales value with the localized value
        l = locale
        v = nil
        while l
          v = value[l]
          break if v

          l = configuration.locale_fallbacks[l]
        end

        v
      end

    entry
  end

  ##
  # Takes an entry in a specific 'sys.locale' and merges it into an entry that is
  # in the 'locale=*' format
  def reduce_to_star(memo, entry)
    if memo_locale = memo.dig('sys', 'locale')
      raise WCC::Contentful::LocaleMismatchError, "expected locale: * but was #{memo_locale}"
    end
    unless entry_locale = entry.dig('sys', 'locale')
      raise WCC::Contentful::LocaleMismatchError, 'expected a specific locale but got locale: *'
    end

    if memo.dig('sys', 'id') != entry.dig('sys', 'id')
      raise ArgumentError,
        "IDs of memo and entry must match! were (#{memo.dig('sys',
          'id').inspect} and #{entry.dig('sys', 'id').inspect})"
    end

    entry['fields'].each do |key, value|
      memo_field = memo['fields'][key] ||= {}
      memo_field[entry_locale] = value
    end

    memo
  end
end
