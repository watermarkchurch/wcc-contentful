# frozen_string_literal: true

module WCC::Contentful
  class Services
    # A GraphQL schema that will query Contentful using your configured store.
    #
    # @api Store
    def graphql_schema
      @graphql_schema ||=
        ensure_configured do |_config|
          WCC::Contentful::Graphql::Builder.new(
            WCC::Contentful.types,
            store
          ).build_schema
        end
    end
  end

  module ServiceAccessors
    def graphql_schema
      Services.instance.graphql_schema
    end
  end
end
