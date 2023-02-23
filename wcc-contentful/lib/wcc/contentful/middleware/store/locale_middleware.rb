# frozen_string_literal: true

module WCC::Contentful::Middleware::Store
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
        # Do we actually want to transform { 'title' => 'foobar' } into { 'title' => { 'en-US' => 'foobar' } }?
        # Lets see if this ever actually comes up.
        entry
      else
        transform_to_locale(entry, locale)
      end
    end
  end
end
