

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

  def validate_field(field, *opts)
    field = field.to_s.camelize(:lower) unless field.is_a?(String)
    field_schema =
      Dry::Validation.Schema do
        opts.each do |opt|
          case opt
          when :required
            required(:required).value(eql?: true)
          when :optional
            required(:required).value(eql?: false)
          else
            required(:type).value(eql?: opt)
          end
        end
      end
    (@field_validations ||= []) << proc { required(field).schema(field_schema) }
  end
end
