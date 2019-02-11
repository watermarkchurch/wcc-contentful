# frozen_string_literal: true

# This object contains all the configuration options for the `wcc-contentful` gem.
class WCC::Contentful::App::Configuration
  # TODO: things to configure in the app?
  ATTRIBUTES = %i[
  ].freeze

  attr_reader :wcc_contentful_config

  delegate(*WCC::Contentful::Configuration::ATTRIBUTES, to: :wcc_contentful_config)
  delegate(*(WCC::Contentful::Configuration::ATTRIBUTES.map { |a| "#{a}=" }),
    to: :wcc_contentful_config)

  def initialize(wcc_contentful_config)
    @wcc_contentful_config = wcc_contentful_config
  end

  # Validates the configuration, raising ArgumentError if anything is wrong.  This
  # is called by WCC::Contentful::App.init!
  def validate!
    wcc_contentful_config.validate!
  end

  def frozen?
    false
  end

  class FrozenConfiguration
    attr_reader(*ATTRIBUTES)

    attr_reader :wcc_contentful_config

    delegate(*WCC::Contentful::Configuration::ATTRIBUTES, to: :wcc_contentful_config)

    def initialize(configuration, frozen_wcc_contentful_config)
      unless frozen_wcc_contentful_config.frozen?
        raise ArgumentError, 'Please first freeze the wcc_contentful_config'
      end

      @wcc_contentful_config = frozen_wcc_contentful_config

      ATTRIBUTES.each do |att|
        val = configuration.public_send(att)
        val.freeze if val.respond_to?(:freeze)
        instance_variable_set("@#{att}", val)
      end
    end

    def frozen?
      true
    end
  end
end
