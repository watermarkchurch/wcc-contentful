# frozen_string_literal: true

gem 'pg', '~> 1.0'
gem 'connection_pool', '~> 2.2'
require 'pg'
require 'connection_pool'

module WCC::Contentful::Store
  class PostgresStore < Base
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
    end

    def find_all(content_type:, options: nil)
      statement = "WHERE data->'sys'->'contentType'->'sys'->>'id' = $1"
      Query.new(
        self,
        @connection_pool,
        statement,
        [content_type],
        options
      )
    end

    class Query < Base::Query
      def initialize(store, connection_pool, statement = nil, params = nil, options = nil)
        super(store)
        @connection_pool = connection_pool
        @statement = statement ||
          "WHERE data->'sys'->>'id' IS NOT NULL"
        @params = params || []
        @options = options || {}
      end

      def eq(field, expected, context = nil)
        locale = context[:locale] if context.present?
        locale ||= 'en-US'

        params = @params.dup

        statement = @statement + " AND data->'fields'->$#{push_param(field, params)}" \
          "->$#{push_param(locale, params)} ? $#{push_param(expected, params)}"

        Query.new(
          @store,
          @connection_pool,
          statement,
          params,
          @options
        )
      end

      def count
        return @count if @count

        statement = 'SELECT count(*) FROM contentful_raw ' + @statement
        result = @connection_pool.with { |conn| conn.exec(statement, @params) }
        @count = result.getvalue(0, 0).to_i
      end

      def first
        return @first if @first

        statement = 'SELECT * FROM contentful_raw ' + @statement + ' LIMIT 1'
        result = @connection_pool.with { |conn| conn.exec(statement, @params) }
        return if result.num_tuples == 0

        resolve_includes(
          JSON.parse(result.getvalue(0, 1)),
          @options[:include]
        )
      end

      def map
        arr = []
        resolve.each do |row|
          arr << yield(
          resolve_includes(
            JSON.parse(row['data']),
            @options[:include]
          )
          )
        end
        arr
      end

      def result
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

        statement = 'SELECT * FROM contentful_raw ' + @statement
        @resolved = @connection_pool.with { |conn| conn.exec(statement, @params) }
      end

      def push_param(param, params)
        params << param
        params.length
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

        DROP FUNCTION IF EXISTS "upsert_entry"(_id varchar, _data jsonb);
        CREATE FUNCTION "upsert_entry"(_id varchar, _data jsonb) RETURNS jsonb AS $$
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
