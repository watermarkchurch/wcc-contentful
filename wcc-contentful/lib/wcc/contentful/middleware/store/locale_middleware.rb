# frozen_string_literal: true

module WCC::Contentful::Middleware::Store
  class LocaleMiddleware
    include WCC::Contentful::Middleware::Store

    attr_accessor :configuration

    def default_locale
      @default_locale ||= configuration&.default_locale || 'en-US'
    end

    def transform(entry, options)
      locale = options[:locale]
      if locale == '*'
        transform_to_star(entry)
      else
        transform_to_locale(entry, locale)
      end
    end

    private

    def transform_to_star(entry)
      if entry_locale = entry.dig('sys', 'locale')
        # locale=* entries have a nil sys.locale
        raise WCC::Contentful::LocaleMismatchError, "expected locale: * but was #{entry_locale}"
      end

      # Do we want to transform { 'title' => 'foobar' } into { 'title' => { 'en-US' => 'foobar' } }?
      # Lets see if this ever actually comes up.
      entry
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
end
