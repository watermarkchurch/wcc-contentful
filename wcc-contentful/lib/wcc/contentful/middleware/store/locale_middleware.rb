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

    def transform_to_star(entry)
      entry
    end

    def transform_to_locale(entry, locale)
      # If the backing store already returned a localized entry, nothing to do
      if entry_locale = entry.dig('sys', 'locale')
        raise WCC::Contentful::LocaleMismatchError unless entry_locale == locale

        return entry
      end
      return entry unless entry['fields']

      # Transform the store's "locale=*" entry into a localized one
      locale ||= default_locale

      entry = entry.dup
      entry['sys']['locale'] = locale
      entry['fields'] =
        entry['fields'].transform_values do |v|
          next if v.nil?

          # replace the all-locales value with the localized value
          if v[locale].nil?
            v[default_locale]
          else
            v[locale]
          end
        end

      entry
    end
  end
end
