module WCC::Contentful::Middleware::Store
  class LocaleMiddleware
    include WCC::Contentful::Middleware::Store

    attr_accessor :configuration

    def default_locale
      @default_locale ||= configuration&.default_locale || 'en-US'
    end

    def transform(entry, locale: nil)
      # If the backing store already returned a localized entry, nothing to do
      return entry if entry.dig('sys', 'locale')
      return entry unless entry['fields']

      # Transform the store's "locale=*" entry into a localized one
      locale ||= default_locale

      entry = entry.dup
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
    end
  end
end
