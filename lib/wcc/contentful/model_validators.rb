# frozen_string_literal: true

require 'dry-validation'

require_relative 'model_validators/dsl'

module WCC::Contentful::ModelValidators
  def schema
    return if @field_validations.nil? || @field_validations.empty?
    field_validations = @field_validations
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

  def validate_fields(&block)
    raise ArgumentError, 'validate_type requires a block' unless block_given?
    dsl = ProcDsl.new(Proc.new(&block))

    (@field_validations ||= []) << dsl
  end

  def validate_field(field, type, *options)
    dsl = FieldDsl.new(field, type, options)

    (@field_validations ||= []) << dsl
  end

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
