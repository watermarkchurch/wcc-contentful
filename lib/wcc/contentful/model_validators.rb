

# frozen_string_literal: true

require 'dry-validation'

require_relative 'model_validators/base'
require_relative 'model_validators/field_validator'

module WCC::Contentful::ModelValidators
  def validate_type(&block)
    raise ArgumentError, 'validate_type requires a block' unless block_given?
    schema = @schema || Dry::Validation::Schema
    @schema = Dry::Validation.Schema(schema, {}, &block)
  end

  def validate_type!
    return unless @schema
    @schema.call(content_type_definition)
  end
end
