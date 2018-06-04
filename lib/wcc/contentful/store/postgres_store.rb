# frozen_string_literal: true

gem 'pg', '~> 1.0'
require 'pg'

module WCC::Contentful::Store
  class PostgresStore < Base
    def initialize(connection_options = nil)
      super()
      connection_options ||= { dbname: 'postgres' }
      @conn = PG.connect(connection_options)
      PostgresStore.ensure_schema(@conn)
    end

    def set(key, value)
      result = @conn.exec_prepared('upsert_entry', [key, value.to_json])
      return if result.num_tuples == 0
      val = result.getvalue(0, 0)
      JSON.parse(val) if val
    end

    def keys
      result = @conn.exec_prepared('select_ids')
      arr = []
      result.each { |r| arr << r['id'].strip }
      arr
    end

    def delete(key)
      result = @conn.exec_prepared('delete_by_id', [key])
      return if result.num_tuples == 0
      JSON.parse(result.getvalue(0, 1))
    end

    def find(key)
      result = @conn.exec_prepared('select_entry', [key])
      return if result.num_tuples == 0
      JSON.parse(result.getvalue(0, 1))
    end

    def find_all(content_type:, query: nil)
      statement = "WHERE data->'sys'->'contentType'->'sys'->>'id' = $1"
      Query.new(
        self,
        @conn,
        statement,
        [content_type],
        query
      )
    end

    class Query < Base::Query
      def initialize(store, conn, statement = nil, params = nil, options = nil)
        super(store)
        @conn = conn
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
          @conn,
          statement,
          params,
          @options
        )
      end

      def count
        return @count if @count
        statement = 'SELECT count(*) FROM contentful_raw ' + @statement
        result = @conn.exec(statement, @params)
        @count = result.getvalue(0, 0).to_i
      end

      def first
        return @first if @first
        statement = 'SELECT * FROM contentful_raw ' + @statement + ' LIMIT 1'
        result = @conn.exec(statement, @params)
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
        @resolved = @conn.exec(statement, @params)
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

        DROP FUNCTION IF EXISTS "upsert_entry";
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

      conn.prepare('upsert_entry', 'SELECT * FROM upsert_entry($1,$2)')
      conn.prepare('select_entry', 'SELECT * FROM contentful_raw WHERE id = $1')
      conn.prepare('select_ids', 'SELECT id FROM contentful_raw')
      conn.prepare('delete_by_id', 'DELETE FROM contentful_raw WHERE id = $1 RETURNING *')
    end
  end
end
