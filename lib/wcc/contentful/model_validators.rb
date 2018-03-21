# frozen_string_literal: true

require 'dry-validation'

require_relative 'model_validators/dsl'

module WCC::Contentful::ModelValidators
  def schema
    return if @field_validations.nil? || @field_validations.empty?
    field_validations = @field_validations

    # "page": {
    #   "sys": { ... }
    #   "fields": {
    #     "title": { ... },
    #     "sections": { ... },
    #     ...
    #   }
    # }

    fields_schema =
      Dry::Validation.Schema do
        # Had to dig through the internals of Dry::Validation to find
        # this magic incantation
        field_validations.each { |dsl| instance_eval(&dsl.to_proc) }
      end

    Dry::Validation.Schema do
      required('fields').schema(fields_schema)
    end
  end

  ##
  # Accepts a block which uses the {dry-validation DSL}[http://dry-rb.org/gems/dry-validation/]
  # to validate the 'fields' object of a content type.
  def validate_fields(&block)
    raise ArgumentError, 'validate_fields requires a block' unless block_given?
    dsl = ProcDsl.new(Proc.new(&block))

    (@field_validations ||= []) << dsl
  end

  ##
  # Validates a single field is of the expected type.
  # Type expectations are one of:
  #
  # [:String]   the field type must be `Symbol` or `Text`
  # [:Int]      the field type must be `Integer`
  # [:Float]    the field type must be `Number`
  # [:DateTime] the field type must be 'Date'
  # [:Asset]    the field must be a link and the `linkType` must be `Asset`
  # [:Link]     the field must be a link and the `linkType` must be `Entry`.
  # [:Location] the field type must be `Location`
  # [:Boolean]  the field type must be `Boolean`
  # [:Json]     the field type must be `Json` - a json blob.
  # [:Array]    the field must be a List.
  #
  # Additional validation options can be enforced:
  #
  # [:required] the 'Required Field' checkbox must be checked
  # [:optional] the 'Required Field' checkbox must not be checked
  # [:link_to]  (only `:Link` or `:Array` type) the given content type(s) must be
  #             checked in the 'Accept only specified entry type' validations
  #             Example:
  #               validate_field :button, :Link, link_to: ['button', 'altButton']
  #
  # [:items]    (only `:Array` type) the items of the list must be of the given type.
  #             Example:
  #               validate_field :my_strings, :Array, items: :String
  #
  # Examples:
  # see WCC::Contentful::Model::Menu and WCC::Contentful::Model::MenuButton
  def validate_field(field, type, *options)
    dsl = FieldDsl.new(field, type, options)

    (@field_validations ||= []) << dsl
  end

  ##
  # Accepts a content types response from the API and transforms it
  # to be acceptible for the validator.
  def self.transform_content_types_for_validation(content_types)
    if !content_types.is_a?(Array) && items = content_types.try(:[], 'items')
      content_types = items
    end

    # Transform the array into a hash keyed by content type ID
    content_types.each_with_object({}) do |ct, ct_hash|
      # Transform the fields into a hash keyed by field ID
      ct['fields'] =
        ct['fields'].each_with_object({}) do |f, f_hash|
          f_hash[f['id']] = f
        end

      ct_hash[ct.dig('sys', 'id')] = ct
    end
  end
end
