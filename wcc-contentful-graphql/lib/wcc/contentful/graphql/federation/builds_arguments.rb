# frozen_string_literal: true

module WCC::Contentful::Graphql::Federation
  BuildsArguments =
    Struct.new(:argument) do
      def self.call(arguments)
        arguments.map { |arg| new(arg).call }
      end

      def call
        return argument if argument.is_a? GraphQL::Language::Nodes::Argument

        GraphQL::Language::Nodes::Argument.new(name: key, value: value)
      end

      private

      def key
        argument[0]
      end

      def value
        if argument[1].is_a? Hash
          return GraphQL::Language::Nodes::InputObject.new(arguments: BuildsArguments.call(argument[1]))
        end

        argument[1]
      end
    end
end
