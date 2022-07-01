# frozen_string_literal: true

require_relative './attributes'

module WCC::Contentful::Test::Double
  ##
  # Builds a rspec double of the Contentful model for the given content_type.
  # All attributes that are known to be required fields on the content type
  # will return a default value based on the field type.
  def contentful_double(const, **attrs)
    const = WCC::Contentful::Model.resolve_constant(const.to_s) unless const.respond_to?(:content_type_definition)
    attrs.symbolize_keys!

    bad_attrs = attrs.reject { |a| const.instance_methods.include?(a) }
    raise ArgumentError, "Attribute(s) do not exist on #{const}: #{bad_attrs.keys}" if bad_attrs.any?

    double(attrs[:name] || attrs[:id] || nil, defaults(const).merge(attrs))
  end

  ##
  # Builds an rspec double of a Contentful image asset, including the file
  # URL and details.  These fields can be overridden.
  def contentful_image_double(**attrs)
    attrs = {
      title: WCC::Contentful::Test::Attributes[:String],
      description: WCC::Contentful::Test::Attributes[:String],
      file: {
        url: '//images.ctfassets.net/7yx6/2rak/test.jpg',
        details: {
          image: {
            width: 0,
            height: 0
          }
        }
      }
    }.deep_merge!(attrs)

    attrs[:file] = OpenStruct.new(attrs[:file]) if attrs[:file]

    attrs[:raw] = {
      sys: {
        space: {
          sys: {
            type: 'Link',
            linkType: 'Space',
            id: ENV.fetch('CONTENTFUL_SPACE_ID', nil)
          }
        },
        id: SecureRandom.urlsafe_base64,
        type: 'Asset',
        createdAt: Time.now.to_s(:iso8601),
        updatedAt: Time.now.to_s(:iso8601),
        environment: {
          sys: {
            id: 'master',
            type: 'Link',
            linkType: 'Environment'
          }
        },
        revision: rand(100),
        locale: 'en-US'
      },
      fields: attrs.each_with_object({}) { |(k, v), h| h[k] = { 'en-US' => v } }
    }

    double(attrs)
  end

  private

  def defaults(model)
    attributes = WCC::Contentful::Test::Attributes.defaults(model)
    methods = model.instance_methods - WCC::Contentful::Model.instance_methods
    methods.each_with_object(attributes) { |f, h| h[f] ||= nil }
  end
end
