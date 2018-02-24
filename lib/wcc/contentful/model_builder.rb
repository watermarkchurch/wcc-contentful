# frozen_string_literal: true

module WCC::Contentful
  class ModelBuilder
    include Helpers

    def initialize(types, store)
      @types = types
      @store = store
    end

    def build_models
      @types.each_with_object([]) do |(_k, v), a|
        a << build_model(v)
      end
    end

    private

    def build_model(t)
      puts "building model #{t[:name]}"
      const = constant_from_content_type(t[:content_type])
      return WCC::Contentful.const_get(const) if WCC::Contentful.const_defined?(const)

      # TODO: https://github.com/dkubb/ice_nine ?
      typedef = t.deep_dup.freeze
      WCC::Contentful.const_set(const,
        Class.new(Model) do
          class << self
            define_method(:content_type) do
              typedef[:content_type]
            end

            define_method(:content_type_definition) do
              typedef
            end
          end

          define_method(:initialize) do |raw, context = nil|
            @locale = context[:locale] if context.present?
            @locale ||= 'en-US'
            @id = raw.dig('sys', 'id')
            @space = raw.dig('sys', 'space', 'sys', 'id')
            @created_at = raw.dig('sys', 'createdAt')
            @created_at = Time.parse(@created_at) if @created_at.present?
            @updated_at = raw.dig('sys', 'updatedAt')
            @updated_at = Time.parse(@updated_at) if @updated_at.present?
            @revision = raw.dig('sys', 'revision')

            typedef[:fields].each_value do |f|
              raw_value = raw.dig('fields', f[:name], @locale)
              instance_variable_set('@' + f[:name], raw_value)
            end
          end

          attr_reader :id
          attr_reader :space
          attr_reader :created_at
          attr_reader :updated_at
          attr_reader :revision

          # Make a field for each column:
          typedef[:fields].each_value do |f|
            name = f[:name]
            var_name = '@' + name
            case f[:type]
            when :Asset
              # todo
              next
            when :Link
              next
            when :DateTime
              define_method(name) do
                val = instance_variable_get(var_name)
                Time.zone.parse(val) if val.present?
              end
            when :Location
              next
            when :Json
              define_method(name) do
                value = instance_variable_get(var_name)
                return value if value.is_a? Array
                return value.to_h if value.respond_to?(:to_h)
                return JSON.parse(value) if value.is_a? String
                raise ArgumentError, "Cannot coerce value '#{value}' to a hash"
              end
            else
              define_method(name) do
                instance_variable_get(var_name)
              end
            end
          end
        end)
    end
  end
end
