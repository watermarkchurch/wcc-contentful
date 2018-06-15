# frozen_string_literal: true

require_relative './sys'

module WCC::Contentful
  class ModelBuilder
    include Helpers

    def initialize(types)
      @types = types
    end

    def build_models
      @types.each_with_object([]) do |(_k, v), a|
        a << build_model(v)
      end
    end

    private

    def build_model(typedef)
      const = typedef.name
      return WCC::Contentful::Model.const_get(const) if WCC::Contentful::Model.const_defined?(const)

      # TODO: https://github.com/dkubb/ice_nine ?
      typedef = typedef.deep_dup.freeze
      WCC::Contentful::Model.const_set(const,
        Class.new(WCC::Contentful::Model) do
          extend ModelSingletonMethods
          include ModelMethods
          include Helpers

          const_set('ATTRIBUTES', typedef.fields.keys.map(&:to_sym).freeze)
          const_set('FIELDS', typedef.fields.keys.freeze)

          define_singleton_method(:content_type) do
            typedef.content_type
          end

          define_singleton_method(:content_type_definition) do
            typedef
          end

          define_method(:initialize) do |raw, context = nil|
            ct = content_type_from_raw(raw)
            if ct != typedef.content_type
              raise ArgumentError, 'Wrong Content Type - ' \
                "'#{raw.dig('sys', 'id')}' is a #{ct}, expected #{typedef.content_type}"
            end
            @raw = raw.freeze

            created_at = raw.dig('sys', 'createdAt')
            created_at = Time.parse(created_at) if created_at.present?
            updated_at = raw.dig('sys', 'updatedAt')
            updated_at = Time.parse(updated_at) if updated_at.present?
            @sys = WCC::Contentful::Sys.new(
              raw.dig('sys', 'id'),
              raw.dig('sys', 'locale') || context.try(:[], :locale) || 'en-US',
              raw.dig('sys', 'space', 'sys', 'id'),
              created_at,
              updated_at,
              raw.dig('sys', 'revision'),
              OpenStruct.new(context).freeze
            )

            typedef.fields.each_value do |f|
              raw_value = raw.dig('fields', f.name, @sys.locale)
              if raw_value.present?
                case f.type
                when :DateTime
                  raw_value = Time.parse(raw_value).localtime
                when :Int
                  raw_value = Integer(raw_value)
                when :Float
                  raw_value = Float(raw_value)
                end
              elsif f.array
                # array fields need to resolve to an empty array when nothing is there
                raw_value = []
              end
              instance_variable_set('@' + f.name, raw_value)
            end
          end

          attr_reader :sys
          attr_reader :raw
          delegate :id, to: :sys
          delegate :created_at, to: :sys
          delegate :updated_at, to: :sys
          delegate :revision, to: :sys
          delegate :space, to: :sys

          # Make a field for each column:
          typedef.fields.each_value do |f|
            name = f.name
            var_name = '@' + name
            case f.type
            when :Asset, :Link
              define_method(name) do
                val = instance_variable_get(var_name + '_resolved')
                return val if val.present?

                _resolve_field(name)
              end
            when :Coordinates
              define_method(name) do
                val = instance_variable_get(var_name)
                OpenStruct.new(val.slice('lat', 'lon')) if val
              end
            when :Json
              define_method(name) do
                value = instance_variable_get(var_name)

                parse_value =
                  ->(v) do
                    return v.to_h if v.respond_to?(:to_h)

                    raise ArgumentError, "Cannot coerce value '#{value}' to a hash"
                  end

                return value.map { |v| OpenStruct.new(parse_value.call(v)) } if value.is_a?(Array)

                OpenStruct.new(parse_value.call(value))
              end
            else
              define_method(name) do
                instance_variable_get(var_name)
              end
            end
            alias_method name.underscore, name
          end
        end)
    end
  end
end
