# frozen_string_literal: true

# Extend this module inside a root query definition to do schema federation.
# https://blog.apollographql.com/apollo-federation-f260cf525d21
#
# This handles only queries, not mutations or subscriptions.
module WCC::Contentful::Graphql::Federation
  extend self

  # Accepts an externally defined schema with a root query, and "stitches" it's
  # query root into the current GraphQL::ObjectType definition.
  # All fields on the external query object like `resource()`, `allResource()`
  # will be inserted into the current object.  The `resolve` method for those
  # fields will execute a query on the external schema, returning the results.
  def schema_stitch(schema, namespace: nil)
    ns_titleized = namespace&.titleize
    ns = NamespacesTypes.new(namespace: ns_titleized)

    def_fields =
      proc {
        schema.query.fields.each do |(key, field_def)|
          field key do
            type ns.namespaced(field_def.type)
            description field_def.description

            field_def.arguments.each do |(arg_name, arg)|
              argument arg_name, ns.namespaced(arg.type)
            end

            resolve GraphQL::Federation.delegate_to_schema(schema)
          end
        end
      }

    if namespace
      stub_class = Struct.new(:name)

      field namespace do
        type(GraphQL::ObjectType.define do
          name ns_titleized

          instance_exec(&def_fields)
        end)

        resolve ->(_obj, _arguments, _context) { stub_class.new(namespace) }
      end
    else
      def_fields.call
    end
  end

  def delegate_to_schema(schema, field_name: nil, arguments: nil)
    ->(obj, inner_args, context) {
      field_name ||= context.ast_node.name

      arguments = arguments.call(obj, inner_args, context) if arguments&.respond_to?(:call)
      arguments = BuildsArguments.call(arguments) if arguments
      arguments ||= context.ast_node.arguments

      field_node = GraphQL::Language::Nodes::Field.new(
        name: field_name,
        arguments: arguments,
        selections: context.ast_node.selections,
        directives: context.ast_node.directives
      )

      query_node = GraphQL::Language::Nodes::OperationDefinition.new(
        name: context.query.operation_name,
        operation_type: 'query',
        variables: context.query.selected_operation.variables,
        selections: [
          field_node
        ]
      )

      # the ast_node.to_query_string prints the relevant section of the query to
      # a string.  We build a query out of that which we execute on the external
      # schema.
      query = query_node.to_query_string

      result = schema.execute(query,
        variables: context.query.variables)

      if result['errors'].present?
        raise GraphQL::ExecutionError.new(
          result.dig('errors', 0, 'message'),
          ast_node: context.ast_node
        )
      end

      result.dig('data', field_name)
    }
  end
end

GraphQL::Define::DefinedObjectProxy.__send__(:include, WCC::Contentful::Graphql::Federation)

require_relative './federation/namespaces_types'
require_relative './federation/builds_arguments'
