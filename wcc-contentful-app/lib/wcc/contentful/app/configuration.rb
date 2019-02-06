# frozen_string_literal: true

# This object contains all the configuration options for the `wcc-contentful` gem.
class WCC::Contentful::App::Configuration
  # TODO: things to configure in the app?
  ATTRIBUTES = %i[
  ].freeze

  def initialize
  end

  # Validates the configuration, raising ArgumentError if anything is wrong.  This
  # is called by WCC::Contentful::App.init!
  def validate!
  end

  def frozen?
    false
  end

  def freeze
    FrozenConfiguration.new(self)
  end

  class FrozenConfiguration
    attr_reader(*ATTRIBUTES)

    def initialize(configuration)
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
