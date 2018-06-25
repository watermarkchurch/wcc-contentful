# frozen_string_literal: true

module WCC::Contentful
  # Raised by {WCC::Contentful.validate_models!} if a content type in the space
  # does not match the validation defined on the associated model.
  class ValidationError < StandardError
    Message =
      Struct.new(:path, :error) do
        def to_s
          "#{path}: #{error}"
        end
      end

    attr_reader :errors

    def initialize(errors)
      @errors = ValidationError.join_msg_keys(errors)
      super("Content Type Schema from Contentful failed validation!\n  #{@errors.join("\n  ")}")
    end

    # Turns the error messages hash into an array of message structs like:
    # menu.fields.name.type: must be equal to String
    def self.join_msg_keys(hash)
      ret =
        hash.map do |k, v|
          if v.is_a?(Hash)
            msgs = join_msg_keys(v)
            msgs.map { |msg| Message.new(k.to_s + '.' + msg.path, msg.error) }
          else
            v.map { |msg| Message.new(k.to_s, msg) }
          end
        end
      ret.flatten(1)
    end
  end

  class SyncError < StandardError
  end

  # Raised when a constant under {WCC::Contentful::Model} does not match to a
  # content type in the configured Contentful space
  class ContentTypeNotFoundError < NameError
  end

  # Raised when an entry contains a circular reference and cannot be represented
  # as a flat tree.
  class CircularReferenceError < StandardError
  end

  # Raised by {WCC::Contentful::ModelMethods#resolve Model#resolve} when attempting
  # to resolve an entry's links and that entry cannot be found in the space.
  class ResolveError < StandardError
  end
end
