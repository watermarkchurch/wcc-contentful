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
    if entry_locale = entry.dig('sys', 'locale')
      # locale=* entries have a nil sys.locale
      raise WCC::Contentful::LocaleMismatchError, "expected locale: * but was #{entry_locale}"
    end

    raise NotImplementedError, 'TODO'
  end

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
end
