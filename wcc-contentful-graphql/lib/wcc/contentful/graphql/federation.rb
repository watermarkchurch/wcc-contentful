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
    ns = NamespacesTypes.new(namespace: namespace)

    def_fields =
      proc {
        schema.query.fields.each do |(key, field_def)|
          field key, ns.namespaced(field_def.type) do
            description field_def.description

            field_def.arguments.each do |(arg_name, arg)|
              argument arg_name, ns.namespaced(arg.type)
            end

            resolve delegate_to_schema(schema,
              field_name: key,
              namespace: namespace)
          end
        end
      }

    if namespace
      stub_class = Struct.new(:name)
      namespaced_type =
        GraphQL::ObjectType.define do
          name namespace.titleize

          instance_exec(&def_fields)
        end

      field namespace, namespaced_type do
        resolve ->(_obj, _arguments, _context) { stub_class.new(namespace) }
      end
    else
      def_fields.call
    end
  end

  def delegate_to_schema(schema, field_name: nil, arguments: nil, namespace: nil)
    ->(obj, inner_args, context) {
      field_name ||= context.ast_node.name

      args = arguments.call(obj, inner_args, context) if arguments&.respond_to?(:call)
      args = BuildsArguments.call(args) if args
      args ||= context.ast_node.arguments

      field_node = GraphQL::Language::Nodes::Field.new(
        name: field_name,
        arguments: args,
        selections: context.ast_node.selections,
        directives: context.ast_node.directives
      )

      vars = context.query.selected_operation.variables
      if namespace
        ns = NamespacesTypes.new(namespace: namespace)
        vars = vars.map { |v| ns.de_namespace_variable(v) }
      end
      query_node = GraphQL::Language::Nodes::OperationDefinition.new(
        name: context.query.operation_name,
        operation_type: 'query',
        variables: vars,
        selections: [
          field_node
        ]
      )
      document = GraphQL::Language::Nodes::Document.new(
        definitions: [query_node]
      )

      result = schema.execute(
        document: document,
        variables: context.query.variables
      )

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
