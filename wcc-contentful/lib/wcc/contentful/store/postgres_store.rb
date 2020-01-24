# frozen_string_literal: true

gem 'pg', '~> 1.0'
gem 'connection_pool', '~> 2.2'
require 'pg'
require 'connection_pool'
require_relative 'instrumentation'

module WCC::Contentful::Store
  class PostgresStore < Base
    include WCC::Contentful::Store::Instrumentation

    attr_reader :connection_pool

    def initialize(_config = nil, connection_options = nil, pool_options = nil)
      super()
      @schema_ensured = false
      connection_options ||= { dbname: 'postgres' }
      pool_options ||= {}
      @connection_pool = build_connection_pool(connection_options, pool_options)
    end

    def set(key, value)
      ensure_hash value
      result = @connection_pool.with { |conn| conn.exec_prepared('upsert_entry', [key, value.to_json]) }
      return if result.num_tuples == 0

      val = result.getvalue(0, 0)
      JSON.parse(val) if val
    end

    def keys
      result = @connection_pool.with { |conn| conn.exec_prepared('select_ids') }
      arr = []
      result.each { |r| arr << r['id'].strip }
      arr
    rescue PG::ConnectionBad
      []
    end

    def delete(key)
      result = @connection_pool.with { |conn| conn.exec_prepared('delete_by_id', [key]) }
      return if result.num_tuples == 0

      JSON.parse(result.getvalue(0, 1))
    end

    def find(key, **_options)
      result = @connection_pool.with { |conn| conn.exec_prepared('select_entry', [key]) }
      return if result.num_tuples == 0

      JSON.parse(result.getvalue(0, 1))
    rescue PG::ConnectionBad
      nil
    end

    def find_all(content_type:, options: nil)
      statement =
        if content_type == 'Asset'
          "WHERE t.data->'sys'->>'type' = $1"
        else
          "WHERE t.data->'sys'->'contentType'->'sys'->>'id' = $1"
        end
      Query.new(
        self,
        @connection_pool,
        statement: statement,
        params: [content_type],
        options: options
      )
    end

    class Query < Base::Query
      # rubocop:disable Metrics/ParameterLists
      def initialize(
        store,
        connection_pool,
        statement: nil,
        joins: nil,
        params: nil,
        options: nil
      )
        super(store)
        @connection_pool = connection_pool
        @statement = statement ||
          "WHERE t.data->'sys'->>'id' IS NOT NULL"
        @params = params || []
        @options = options || {}
        @joins = joins || []
      end
      # rubocop:enable Metrics/ParameterLists

      def eq(field, expected, context = nil)
        locale = context[:locale] if context.present?
        locale ||= 'en-US'

        params = @params.dup

        statement =
          @statement +
          if field.to_s == 'id'
            " AND t.id = $#{push_param(expected, params)}"
          else
            " AND t.data->#{parameter(field, locale)}" \
              " ? $#{push_param(expected, params)}::text"
          end

        Query.new(
          @store,
          @connection_pool,
          statement: statement,
          joins: @joins,
          params: params,
          options: @options
        )
      end

      def self_join(field, conditions, context)
        locale = context[:locale] if context.present?
        locale ||= 'en-US'

        params = @params.dup
        joins = @joins.dup

        join_table_alias = push_join(field, locale, params, joins)

        statement =
          reduce_conditions(conditions, locale, params)
            .reduce(@statement) do |memo, condition|
            memo + " AND #{join_table_alias}.data->#{condition}"
          end

        Query.new(
          @store,
          @connection_pool,
          statement: statement,
          joins: joins,
          params: params,
          options: @options
        )
      end

      def count
        return @count if @count

        statement = finalize_statement('SELECT count(*)')
        result = run_statement(statement)
        @count = result.getvalue(0, 0).to_i
      end

      def first
        return @first if @first

        statement = finalize_statement('SELECT *', ' LIMIT 1')
        result = run_statement(statement)
        return if result.num_tuples == 0

        resolve_includes(
          JSON.parse(result.getvalue(0, 1)),
          @options[:include]
        )
      end

      def to_enum
        arr = []
        resolve.each do |row|
          arr <<
            resolve_includes(
              JSON.parse(row['data']),
              @options[:include]
            )
        end
        arr
      end

      # TODO: override resolve_includes to make it more efficient

      private

      def resolve
        return @resolved if @resolved

        statement = finalize_statement('SELECT *')
        @resolved = run_statement(statement)
      rescue PG::ConnectionBad
        []
      end

      def push_param(param, params)
        params << param
        params.length
      end

      def parameter_path(field, locale, path = [])
        path = [*path, *field.to_s.split('.')]
        path = path.unshift('sys') if path[0] == 'id'
        path = path.unshift('fields') unless %w[sys fields].include?(path[0])
        # add locale after each "fields.*.'en-US'", i.e. every 2nd path part
        path =
          path.each_with_index.flat_map do |p, i|
            next ['sys', p] if p == 'id' && path[i - 1] != 'sys'

            next p unless path[i - 1] == 'fields'

            [p, locale]
          end

        path
      end

      def quote_parameter_path(path)
        path.map { |p| "'#{p}'" }.join('->')
      end

      def parameter(field, locale)
        quote_parameter_path(parameter_path(field, locale))
      end

      def push_join(field, locale, _params, joins)
        table_alias = "s#{joins.length}"
        joins << "JOIN contentful_raw AS #{table_alias} ON " \
          "t.data->#{parameter(field, locale)}" \
            "->'sys'->>'id'=#{table_alias}.id"
        table_alias
      end

      def reduce_conditions(conditions, locale, params, path = [])
        conditions.flat_map do |f, expected|
          if expected.is_a? Hash
            path = parameter_path(f, locale, path)
            next reduce_conditions(expected, locale, params, path)
          end

          if op?(f)
            raise ArgumentError, "Cannot apply operator '#{f}'" unless f == 'eq'

            next "#{quote_parameter_path(path)} ? $#{push_param(expected, params)}::text"
          end

          path = parameter_path(f, locale, path)
          next "#{quote_parameter_path(path)} ? $#{push_param(expected, params)}::text"
        end
      end

      def finalize_statement(select_statement, limit_statement = nil)
        select_statement + " FROM contentful_raw AS t \n" +
          @joins.join("\n") + "\n" +
          @statement +
          (limit_statement || '')
      end

      def run_statement(statement)
        @connection_pool.with { |conn| conn.exec(statement, @params) }
      end
    end

    def self.ensure_schema(conn)
      conn.exec(<<~HEREDOC
        CREATE TABLE IF NOT EXISTS contentful_raw (
          id varchar PRIMARY KEY,
          data jsonb
        );
        CREATE INDEX IF NOT EXISTS contentful_raw_value_type ON contentful_raw ((data->'sys'->>'type'));
        CREATE INDEX IF NOT EXISTS contentful_raw_value_content_type ON contentful_raw ((data->'sys'->'contentType'->'sys'->>'id'));

        CREATE or replace FUNCTION "upsert_entry"(_id varchar, _data jsonb) RETURNS jsonb AS $$
        DECLARE
          prev jsonb;
        BEGIN
          SELECT data FROM contentful_raw WHERE id = _id INTO prev;
          INSERT INTO contentful_raw (id, data) values (_id, _data)
            ON CONFLICT (id) DO
              UPDATE
              SET data = _data;
           RETURN prev;
        END;
        $$ LANGUAGE 'plpgsql';
      HEREDOC
      )
    end

    def self.prepare_statements(conn)
      conn.prepare('upsert_entry', 'SELECT * FROM upsert_entry($1,$2)')
      conn.prepare('select_entry', 'SELECT * FROM contentful_raw WHERE id = $1')
      conn.prepare('select_ids', 'SELECT id FROM contentful_raw')
      conn.prepare('delete_by_id', 'DELETE FROM contentful_raw WHERE id = $1 RETURNING *')
    end

    private

    def build_connection_pool(connection_options, pool_options)
      ConnectionPool.new(pool_options) do
        PG.connect(connection_options).tap do |conn|
          unless @schema_ensured
            PostgresStore.ensure_schema(conn)
            @schema_ensured = true
          end
          PostgresStore.prepare_statements(conn)
        end
      end
    end
  end
end
