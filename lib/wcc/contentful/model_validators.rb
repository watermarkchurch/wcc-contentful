

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

  def validate_field(field, type, *options)
    field = field.to_s.camelize(:lower) unless field.is_a?(String)

    procs =
      options.map do |opt|
        if opt.is_a?(Hash)
          opt.map { |k, v| parse_option(k, v) }
        else
          parse_option(opt)
        end
      end

    field_schema =
      Dry::Validation.Schema do
        required(:type).value(eql?: type)
        # overridden when :array is passed in above
        optional(:array).value(eql?: false)

        procs.flatten.each { |p| instance_eval(&p) }
      end
    (@field_validations ||= []) << proc { required(field).schema(field_schema) }
  end

  private

  def parse_option(option, option_arg = nil)
    case option
    when :required
      proc { required(:required).value(eql?: true) }
    when :optional
      proc { required(:required).value(eql?: false) }
    when :array
      proc { required(:array).value(eql?: true) }
    when :link_to
      parse_field_link_to(option_arg)
    else
      raise ArgumentError, "unknown validation requirement: #{option}"
    end
  end

  def parse_field_link_to(option_arg)
    raise ArgumentError, 'validation link_to: requires an argument' unless option_arg

    return proc { required(:link_types).each(format?: option_arg) } if option_arg.is_a?(Regexp)

    option_arg = [option_arg] unless option_arg.is_a?(Array)
    proc { required(:link_types).value(eql?: option_arg) }
  end
end
