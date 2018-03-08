

# frozen_string_literal: true

require 'dry-validation'

module WCC::Contentful::ModelValidators
  def schema
    return if @field_validations.nil? || @field_validations.empty?
    field_validations = @field_validations
    fields_schema =
      Dry::Validation.Schema do
        # Had to dig through the internals of Dry::Validation to find
        # this magic incantation
        field_validations.each { |b| instance_eval(&b) }
      end

    Dry::Validation.Schema do
      required(:fields).schema(fields_schema)
    end
  end

  def validate_fields(&block)
    raise ArgumentError, 'validate_type requires a block' unless block_given?
    @field_validations ||= []
    @field_validations << block
  end

  def validate_field(field, type, *opts)
    field = field.to_s.camelize(:lower) unless field.is_a?(String)

    array = false

    field_schema =
      Dry::Validation.Schema do
        required(:type).value(eql?: type)

        opts.each do |opt|
          case opt
          when :required
            required(:required).value(eql?: true)
          when :optional
            required(:required).value(eql?: false)
          when :array
            array = true
            required(:array).value(eql?: true)
          else
            raise ArgumentError, "unknown validation requirement: #{opt}"
          end
        end

        optional(:array).value(eql?: false) unless array
      end
    (@field_validations ||= []) << proc { required(field).schema(field_schema) }
  end
end
