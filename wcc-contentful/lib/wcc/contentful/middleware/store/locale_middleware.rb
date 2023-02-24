# frozen_string_literal: true

module WCC::Contentful::Middleware::Store
  ##
  # This middleware enforces that all entries returned by the store layer are properly localized.
  # It does this by transforming entries from the store's "locale=*" format into the specified locale (or default).
  #
  # Stores keep entries in the "locale=*" format, which is a hash of all locales for each field.  This is convenient
  # because the Sync API returns them in this format.  However, the Model layer requires localized entries.  So, to
  # separate concerns, this middleware handles the transformation.
  class LocaleMiddleware
    include WCC::Contentful::Middleware::Store
    include WCC::Contentful::EntryLocaleTransformer

    attr_accessor :configuration

    def default_locale
      @default_locale ||= configuration&.default_locale || 'en-US'
    end

    def transform(entry, options)
      locale = options[:locale] || default_locale
      if locale == '*'
        transform_to_star(entry)
      else
        transform_to_locale(entry, locale)
      end
    end
  end
end
