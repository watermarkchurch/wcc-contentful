# frozen_string_literal: true

# This GraphQL type definition wraps a type definition from an external schema
# and redefines it in our top-level schema, so that names do not clash.
# ex. "Campus" in the events schema becomes "Event_Campus"
class WCC::Contentful::Graphql::Federation::NamespacesTypes
  class << self
    def registry
      @registry ||= {}
    end
  end

  attr_reader :namespace

  def initialize(namespace:)
    @namespace = namespace&.titleize
  end

  # Gets the graphql type definition for the externally resolved field
  def namespaced(type)
    return type if type.default_scalar?
    return namespaced(type.of_type).to_list_type if type.is_a?(GraphQL::ListType)
    return namespaced(type.of_type).to_non_null_type if type.is_a?(GraphQL::NonNullType)

    me = self
    ns = namespace
    typename = [namespace, type.to_s].compact.join('_')
    self.class.registry[typename] ||=
      if type.is_a?(GraphQL::UnionType)
        possible_types =
          type.possible_types.map { |t| me.namespaced(t) }
        GraphQL::UnionType.define do
          name typename
          possible_types possible_types
        end
      elsif type.is_a?(GraphQL::InputObjectType)
        GraphQL::InputObjectType.define do
          name typename
          type.arguments.each do |(name, arg)|
            argument name, me.namespaced(arg.type)
          end
        end
      elsif type.is_a?(GraphQL::ScalarType)
        GraphQL::ScalarType.define do
          name typename

          coerce_input type.method(:coerce_input)
          coerce_result type.method(:coerce_result)
        end
      elsif type.is_a?(GraphQL::ObjectType)
        GraphQL::ObjectType.define do
          name typename
          description "#{type.name} from remote#{ns ? ' ' + ns : ''}"

          type.fields.each do |(name, field_def)|
            field name, me.namespaced(field_def.type) do
              field_def.arguments.each do |(arg_name, arg)|
                argument arg_name, me.namespaced(arg.type)
              end

              resolve ->(obj, _args, _ctx) do
                # The object is a JSON response that came back from the
                # external schema.  Resolve the value by using the hash key.
                obj[name]
              end
            end
          end
        end
      else
        raise ArgumentError, "Cannot namespace type #{type} (#{type.class})"
      end
  end
  # rubocop:enable

  def de_namespace_variable(variable_definition)
    variable_definition.merge(
      type: de_namespace_type(variable_definition.type)
    )
  end

  def de_namespace_type(type_node)
    of_type = type_node.try(:of_type)
    if of_type
      return type_node.merge(
        of_type: de_namespace_type(of_type)
      )
    end

    type_node.merge(
      name: type_node.name.sub(namespace + '_', '')
    )
  end
end
