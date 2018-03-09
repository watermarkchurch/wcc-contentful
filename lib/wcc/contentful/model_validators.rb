

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
      required('fields').schema(fields_schema)
    end
  end

  def validate_fields(&block)
    raise ArgumentError, 'validate_type requires a block' unless block_given?
    @field_validations ||= []
    @field_validations << block
  end

  def validate_field(field, type, *options)
    field = field.to_s.camelize(:lower) unless field.is_a?(String)
    type_pred = parse_type_predicate(type)

    procs =
      options.map do |opt|
        if opt.is_a?(Hash)
          opt.map { |k, v| parse_option(type, k, v) }
        else
          parse_option(type, opt)
        end
      end

    field_schema =
      Dry::Validation.Schema do
        instance_eval(&type_pred)

        procs.flatten.each { |p| instance_eval(&p) }
      end
    (@field_validations ||= []) << proc { required(field).schema(field_schema) }
  end

  # Accepts a content types response from the API and transforms it
  # to be acceptible for the validator.
  def self.transform_content_types_for_validation(content_types)
    if items = content_types.try(:[], 'items')
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

  private

  def parse_type_predicate(type)
    case type
    when :String
      proc { required('type').value(included_in?: %w[Symbol Text]) }
    when :Int
      proc { required('type').value(eql?: 'Integer') }
    when :Float
      proc { required('type').value(eql?: 'Number') }
    when :DateTime
      proc { required('type').value(eql?: 'Date') }
    when :Asset
      proc {
        required('type').value(eql?: 'Link')
        required('linkType').value(eql?: 'Asset')
      }
    else
      proc { required('type').value(eql?: type.to_s.camelize) }
    end
  end

  def parse_option(field_type, option, option_arg = nil)
    case option
    when :required
      proc { required('required').value(eql?: true) }
    when :optional
      proc { required('required').value(eql?: false) }
    when :link_to
      link_to_proc = parse_field_link_to(option_arg)
      return link_to_proc unless field_type.to_s.camelize == 'Array'
      proc {
        required('items').schema do
          required('type').value(eql?: 'Link')
          instance_eval(&link_to_proc)
        end
      }
    when :items
      type_pred = parse_type_predicate(option_arg)
      proc {
        required('items').schema do
          instance_eval(&type_pred)
        end
      }
    else
      raise ArgumentError, "unknown validation requirement: #{option}"
    end
  end

  def parse_field_link_to(option_arg)
    raise ArgumentError, 'validation link_to: requires an argument' unless option_arg

    if option_arg.is_a?(Regexp)
      return proc {
        required('validations').each do
          schema do
            required('linkContentType').each(format?: option_arg)
          end
        end
      }
    end

    option_arg = [option_arg] unless option_arg.is_a?(Array)
    proc {
      required('validations').each do
        schema do
          required('linkContentType').value(eql?: option_arg)
        end
      end
    }
  end
end
