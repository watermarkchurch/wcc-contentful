# frozen_string_literal: true

require_relative './link'
require_relative './sys'
require_relative './rich_text'

module WCC::Contentful
  class ModelBuilder
    include Helpers

    attr_reader :namespace

    def initialize(types, namespace: WCC::Contentful::Model)
      @types = types
      @namespace = namespace
    end

    def build_models
      @types.each_with_object([]) do |(_k, v), a|
        a << build_model(v)
      end
    end

    private

    def build_model(typedef)
      const = typedef.name
      ns = namespace
      return ns.const_get(const) if ns.const_defined?(const)

      # TODO: https://github.com/dkubb/ice_nine ?
      typedef = typedef.deep_dup.freeze
      ns.const_set(const,
        Class.new(namespace) do
          extend ModelSingletonMethods
          include ModelMethods
          include Helpers

          const_set('ATTRIBUTES', typedef.fields.keys.map(&:to_sym).freeze)
          const_set('FIELDS', typedef.fields.keys.freeze)

          # Magic type in their system which has a separate endpoint
          # but we represent in the same model space
          if const == 'Asset'
            define_singleton_method(:type) { 'Asset' }
          else
            define_singleton_method(:type) { 'Entry' }
          end

          define_singleton_method(:content_type) do
            typedef.content_type
          end

          define_singleton_method(:content_type_definition) do
            typedef
          end

          define_singleton_method(:model_namespace) { ns }

          define_method(:initialize) do |raw, context = nil|
            ct = content_type_from_raw(raw)
            if ct.present? && ct != typedef.content_type
              raise ArgumentError, 'Wrong Content Type - ' \
                                   "'#{raw.dig('sys', 'id')}' is a #{ct}, expected #{typedef.content_type}"
            end
            if raw.dig('sys', 'locale').blank? && %w[Entry Asset].include?(raw.dig('sys', 'type'))
              raise ArgumentError, 'Model layer cannot represent "locale=*" entries. ' \
                                   "Please use a specific locale in your query.  \n" \
                                   "(Error occurred with entry id: #{raw.dig('sys', 'id')})"
            end

            @raw = raw.freeze

            created_at = raw.dig('sys', 'createdAt')
            created_at = Time.parse(created_at) if created_at.present?
            updated_at = raw.dig('sys', 'updatedAt')
            updated_at = Time.parse(updated_at) if updated_at.present?
            @sys = WCC::Contentful::Sys.new(
              raw.dig('sys', 'id'),
              raw.dig('sys', 'type'),
              raw.dig('sys', 'locale'),
              raw.dig('sys', 'space', 'sys', 'id'),
              created_at,
              updated_at,
              raw.dig('sys', 'revision'),
              OpenStruct.new(context).freeze
            )

            typedef.fields.each_value do |f|
              raw_value = raw.dig('fields', f.name)

              if raw_value.present?
                case f.type
                # DateTime is intentionally not parsed!
                #  a DateTime can be '2018-09-28', '2018-09-28T17:00:00', or '2018-09-28T17:00:00Z'
                #  depending entirely on the editor interface in Contentful.  Trying to parse this
                #  requires an assumption of the correct time zone to place them in.  At this point
                #  in the code we don't have that knowledge, so we're punting to app-defined models.
                #
                #  As an example, a user enters '2018-09-28' into Contentful.  That date is parsed as
                #  '2018-09-28T00:00:00Z' when system time is UTC (ex. on Heroku), but translating that
                #  date to US Central results in '2018-09-27' which is not what the user intentded.
                #
                # when :DateTime
                #   raw_value = Time.parse(raw_value).localtime
                when :RichText
                  raw_value = WCC::Contentful::RichText.tokenize(raw_value, services: ns.services)
                when :Int
                  raw_value = Integer(raw_value)
                when :Float
                  raw_value = Float(raw_value)
                end
              elsif f.array
                # array fields need to resolve to an empty array when nothing is there
                raw_value = []
              end
              instance_variable_set("@#{f.name}", raw_value)
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
            var_name = "@#{name}"
            case f.type
            when :Asset, :Link
              define_method(name) do
                val = instance_variable_get("#{var_name}_resolved")
                return val if val.present?

                _resolve_field(name)
              end

              id_method_name = "#{name}_id"
              if f.array
                id_method_name = "#{name}_ids"
                define_method(id_method_name) do
                  instance_variable_get(var_name)&.map { |link| link.dig('sys', 'id') }
                end
              else
                define_method(id_method_name) do
                  instance_variable_get(var_name)&.dig('sys', 'id')
                end
              end
              alias_method id_method_name.underscore, id_method_name
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
