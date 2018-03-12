# frozen_string_literal: true

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

    def build_model(t)
      const = t.name
      return WCC::ContentfulModel.const_get(const) if WCC::ContentfulModel.const_defined?(const)

      # TODO: https://github.com/dkubb/ice_nine ?
      typedef = t.deep_dup.freeze
      fields = typedef.fields.keys
      WCC::ContentfulModel.const_set(const,
        Class.new(WCC::ContentfulModel) do
          include Helpers

          define_singleton_method(:content_type) do
            typedef.content_type
          end

          define_singleton_method(:content_type_definition) do
            typedef
          end

          define_singleton_method(:find) do |id, context = nil|
            raw = WCC::ContentfulModel.store.find(id)
            new(raw, context) if raw.present?
          end

          define_singleton_method(:find_all) do |context = nil|
            raw = WCC::ContentfulModel.store.find_by(content_type: content_type)
            raw.map { |r| new(r, context) }
          end

          define_singleton_method(:find_by) do |filter, context = nil|
            filter.transform_keys! { |k| k.to_s.camelize(:lower) }
            bad_fields = filter.keys.reject { |k| fields.include?(k) }
            raise ArgumentError, "These fields do not exist: #{bad_fields}" unless bad_fields.empty?

            query = WCC::ContentfulModel.store.find_by(content_type: content_type)
            filter.each do |field, v|
              query = query.eq(field, v, context)
            end
            query.map { |r| new(r, context) }
          end

          define_method(:initialize) do |raw, context = nil|
            ct = content_type_from_raw(raw)
            if ct != typedef.content_type
              raise ArgumentError, 'Wrong Content Type - ' \
                "'#{raw.dig('sys', 'id')}' is a #{ct}, expected #{typedef.content_type}"
            end

            @locale = context[:locale] if context.present?
            @locale ||= 'en-US'
            @id = raw.dig('sys', 'id')
            @space = raw.dig('sys', 'space', 'sys', 'id')
            @created_at = raw.dig('sys', 'createdAt')
            @created_at = Time.parse(@created_at) if @created_at.present?
            @updated_at = raw.dig('sys', 'updatedAt')
            @updated_at = Time.parse(@updated_at) if @updated_at.present?
            @revision = raw.dig('sys', 'revision')

            typedef.fields.each_value do |f|
              raw_value = raw.dig('fields', f.name, @locale)
              if raw_value.present?
                case f.type
                when :DateTime
                  raw_value = Time.zone.parse(raw_value)
                when :Int
                  raw_value = Integer(raw_value)
                when :Float
                  raw_value = Float(raw_value)
                end
              end
              instance_variable_set('@' + f.name, raw_value)
            end
          end

          attr_reader :id
          attr_reader :space
          attr_reader :created_at
          attr_reader :updated_at
          attr_reader :revision

          # Make a field for each column:
          typedef.fields.each_value do |f|
            name = f.name
            var_name = '@' + name
            case f.type
            when :Asset, :Link
              define_method(name) do
                val = instance_variable_get(var_name + '_resolved')
                return val if val.present?

                return unless val = instance_variable_get(var_name)

                val =
                  if val.is_a? Array
                    val.map { |v| WCC::ContentfulModel.find(v.dig('sys', 'id')) }
                  else
                    WCC::ContentfulModel.find(val.dig('sys', 'id'))
                  end

                instance_variable_set(var_name + '_resolved', val)
                val
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
