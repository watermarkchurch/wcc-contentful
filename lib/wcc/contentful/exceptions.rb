# frozen_string_literal: true

module WCC::Contentful
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

  class ContentTypeNotFoundError < NameError
  end
end
