# frozen_string_literal: true

require_relative './test'

module WCC::Contentful::RSpec
  include WCC::Contentful::Test::Double
  include WCC::Contentful::Test::Factory

  def contentful_stub(content_type, **attrs)
    const = WCC::Contentful::Model.resolve_constant(content_type.to_s)
    instance = contentful_create(content_type, **attrs)

    allow(WCC::Contentful::Model).to receive(:find)
      .with(instance.id)
      .and_return(instance)
    allow(WCC::Contentful::Model).to receive(:find)
      .with(instance.id, anything)
      .and_return(instance)
    allow(const).to receive(:find) { |id, options| WCC::Contentful::Model.find(id, options) }

    attrs.each do |k, v|
      allow(const).to receive(:find_by)
        .with(hash_including(k => v))
        .and_return(instance)
    end

    instance
  end
end

RSpec.configure do |config|
  config.include WCC::Contentful::RSpec
end
