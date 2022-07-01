# frozen_string_literal: true

module WCC::Contentful::App
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
            msgs.map { |msg| Message.new("#{k}.#{msg.path}", msg.error) }
          else
            v.map { |msg| Message.new(k.to_s, msg) }
          end
        end
      ret.flatten(1)
    end
  end

  class PageNotFoundError < StandardError
    attr_reader :slug

    def initialize(slug)
      super("Page not found: '#{slug}'")
      @slug = slug
    end
  end
end
