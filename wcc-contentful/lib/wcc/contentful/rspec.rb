# typed: false
# frozen_string_literal: true

require 'wcc/contentful'

require_relative './test'

module WCC::Contentful::RSpec
  include WCC::Contentful::Test::Double
  include WCC::Contentful::Test::Factory

  ##
  # Builds out a fake Contentful entry for the given content type, and then
  # stubs the Model API to return that content type for `.find` and `.find_by`
  # query methods.
  def contentful_stub(content_type, **attrs)
    const = WCC::Contentful::Model.resolve_constant(content_type.to_s)
    instance = contentful_create(content_type, **attrs)

    # mimic what's going on inside model_singleton_methods.rb
    # find, find_by, etc always return a new instance from the same raw
    allow(WCC::Contentful::Model).to receive(:find)
      .with(instance.id) do
        contentful_create(content_type, raw: instance.raw, **attrs)
      end
    allow(WCC::Contentful::Model).to receive(:find)
      .with(instance.id, anything) do |_id, options|

        contentful_create(content_type, options, raw: instance.raw, **attrs)
      end
    allow(const).to receive(:find) { |id, options| WCC::Contentful::Model.find(id, options) }

    attrs.each do |k, v|
      allow(const).to receive(:find_by)
        .with(hash_including(k => v)) do |filter|
          filter = filter&.dup
          options = filter&.delete(:options) || {}

          contentful_create(content_type, options, raw: instance.raw, **attrs)
        end
    end

    instance
  end
end

if defined?(RSpec)
  RSpec.configure do |config|
    config.include WCC::Contentful::RSpec
  end
end
