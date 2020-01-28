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

    def execute(query)
      statement =
        if query.content_type == 'Asset'
          "WHERE t.data->'sys'->>'type' = $1"
        else
          "WHERE t.data->'sys'->'contentType'->'sys'->>'id' = $1"
        end
      params = [query.content_type]
      joins = []

      statement =
        query.conditions.reduce(statement) do |memo, condition|
          raise ArgumentError, "Operator #{condition.op} not supported" unless condition.op == :eq

          if condition.path_tuples.length == 1
            memo + _eq(condition.path, condition.expected, params)
          else
            join_path, expectation_path = condition.path_tuples
            memo + _join(join_path, expectation_path, condition.expected, params, joins)
          end
        end

      QueryResults.new(
        connection_pool: @connection_pool,
        statement: statement,
        params: params,
        joins: joins
      )
    end

    private

    def _eq(path, expected, params)
      if path == %w[sys id]
        " AND t.id = $#{push_param(expected, params)}"
      else
        " AND t.data->#{quote_parameter_path(path)}" \
          " ? $#{push_param(expected, params)}::text"
      end
    end

    def push_param(param, params)
      params << param
      params.length
    end

    def quote_parameter_path(path)
      path.map { |p| "'#{p}'" }.join('->')
    end

    def _join(join_path, expectation_path, expected, params, joins)
      join_table_alias = push_join(join_path, joins)
      " AND #{join_table_alias}.data->#{quote_parameter_path(expectation_path)}" \
        " ? $#{push_param(expected, params)}::text"
    end

    def push_join(path, joins)
      table_alias = "s#{joins.length}"
      joins << "JOIN contentful_raw AS #{table_alias} ON " \
        "t.data->#{quote_parameter_path(path)}" \
          "->'sys'->>'id'=#{table_alias}.id"
      table_alias
    end

    class QueryResults
      include Enumerable

      # rubocop:disable Metrics/ParameterLists
      def initialize(
        connection_pool:,
        statement:,
        params:,
        joins:
        )
        @connection_pool = connection_pool
        @statement = statement
        @params = params
        @joins = joins
      end
      # rubocop:enable Metrics/ParameterLists

      def count
        return @count if @count

        statement = finalize_statement('SELECT count(*)')
        result = run_statement(statement)
        @count = result.getvalue(0, 0).to_i
      end

      def first
        return @first if @first

        statement = finalize_statement('SELECT t.*', ' LIMIT 1')
        result = run_statement(statement)
        return if result.num_tuples == 0

        JSON.parse(result.getvalue(0, 1))
      end

      def each
        resolve.each do |row|
          yield JSON.parse(row['data'])
        end
      end

      private

      def resolve
        return @resolved if @resolved

        statement = finalize_statement('SELECT t.*')
        @resolved = run_statement(statement)
      rescue PG::ConnectionBad
        []
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

    class << self
      def ensure_schema(conn)
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

      def prepare_statements(conn)
        conn.prepare('upsert_entry', 'SELECT * FROM upsert_entry($1,$2)')
        conn.prepare('select_entry', 'SELECT * FROM contentful_raw WHERE id = $1')
        conn.prepare('select_ids', 'SELECT id FROM contentful_raw')
        conn.prepare('delete_by_id', 'DELETE FROM contentful_raw WHERE id = $1 RETURNING *')
      end
    end

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
