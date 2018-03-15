# frozen_string_literal: true

module WCC::Contentful::ModelValidators
  class ProcDsl
    def to_proc
      @proc
    end

    def initialize(proc)
      @proc = proc
    end
  end

  class FieldDsl
    attr_reader :field

    def schema
      return @field_schema if @field_schema

      type_pred = parse_type_predicate(@type)

      procs =
        @options.map do |opt|
          if opt.is_a?(Hash)
            opt.map { |k, v| parse_option(k, v) }
          else
            parse_option(opt)
          end
        end

      @field_schema =
        Dry::Validation.Schema do
          instance_eval(&type_pred)

          procs.flatten.each { |p| instance_eval(&p) }
        end
    end

    def to_proc
      f = field
      s = schema
      proc { required(f).schema(s) }
    end

    def initialize(field, field_type, options)
      @field = field.to_s.camelize(:lower) unless field.is_a?(String)
      @type = field_type
      @options = options
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

    def parse_option(option, option_arg = nil)
      case option
      when :required
        proc { required('required').value(eql?: true) }
      when :optional
        proc { required('required').value(eql?: false) }
      when :link_to
        link_to_proc = parse_field_link_to(option_arg)
        return link_to_proc unless @type.to_s.camelize == 'Array'
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

      # this works because a Link can only have one validation in its "validations" array -
      # this will fail if Contentful ever changes that

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
end
