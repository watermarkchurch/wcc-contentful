# frozen_string_literal: true

gem 'pg', '~> 1.0'
gem 'connection_pool', '~> 2.2'
require 'pg'
require 'connection_pool'
require_relative 'instrumentation'

module WCC::Contentful::Store
  # Implements the store interface where all Contentful entries are stored in a
  # JSONB table.
  class PostgresStore < Base
    include WCC::Contentful::Store::Instrumentation

    delegate :each, to: :to_enum

    attr_reader :connection_pool

    def initialize(_config = nil, connection_options = nil, pool_options = nil)
      super()
      @schema_ensured = false
      connection_options ||= { dbname: 'postgres' }
      pool_options ||= {}
      @connection_pool = build_connection_pool(connection_options, pool_options)
      @dirty = false
    end

    def set(key, value)
      ensure_hash value
      result =
        @connection_pool.with do |conn|
          conn.exec_prepared('upsert_entry', [
                               key,
                               value.to_json,
                               quote_array(extract_links(value))
                             ])
        end
      # mark dirty - we need to refresh the materialized view
      mutex.with_write_lock { @dirty = true }

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
      Query.new(
        self,
        content_type: content_type,
        options: options
      )
    end

    def exec_query(statement, params = [])
      if mutex.with_read_lock { @dirty }
        was_dirty =
          mutex.with_write_lock do
            was_dirty = @dirty
            @dirty = false
            was_dirty
          end

        @connection_pool.with { |conn| conn.exec_prepared('refresh_views_concurrently') } if was_dirty
      end

      @connection_pool.with { |conn| conn.exec(statement, params) }
    end

    private

    def extract_links(entry)
      return [] unless fields = entry['fields']

      links =
        fields.flat_map do |_f, locale_hash|
          locale_hash.flat_map do |_locale, value|
            if value.is_a? Array
              value.map { |val| val.dig('sys', 'id') if link?(val) }
            elsif link?(value)
              value.dig('sys', 'id')
            end
          end
        end

      links.compact
    end

    def link?(value)
      value.is_a?(Hash) && value.dig('sys', 'type') == 'Link'
    end

    def quote_array(arr)
      return unless arr

      encoder = PG::TextEncoder::Array.new
      encoder.encode(arr)
    end

    class Query < WCC::Contentful::Store::Query
      def count
        return @count if @count

        statement, params = finalize_statement('SELECT count(*)')
        result = store.exec_query(statement, params)
        @count = result.getvalue(0, 0).to_i
      end

      def first
        return @first if @first

        statement, params = finalize_statement('SELECT t.*', ' LIMIT 1', depth: @options[:include])
        result = store.exec_query(statement, params)
        return if result.num_tuples == 0

        row = result.first
        entry = JSON.parse(row['data'])

        if @options[:include] && @options[:include] > 0
          includes = decode_includes(row['includes'])
          entry = resolve_includes(entry, @options[:include], includes)
        end
        entry
      end

      def to_enum
        result_set.lazy.map do |row|
          entry = JSON.parse(row['data'])
          if @options[:include] && @options[:include] > 0
            includes = decode_includes(row['includes'])
            entry = resolve_includes(entry, @options[:include], includes)
          end

          entry
        end
      end

      private

      def result_set
        return @result_set if @result_set

        statement, params = finalize_statement('SELECT t.*', depth: @options[:include])
        @result_set = store.exec_query(statement, params)
      rescue PG::ConnectionBad
        []
      end

      def resolve_includes(entry, depth, includes)
        return entry unless entry && depth && depth > 0

        WCC::Contentful::LinkVisitor.new(entry, :Link, :Asset, depth: depth - 1).map! do |val|
          resolve_link(val, includes)
        end
      end

      def resolve_link(val, includes)
        return val unless val.is_a?(Hash) && val.dig('sys', 'type') == 'Link'
        return val unless included = includes[val.dig('sys', 'id')]

        included
      end

      def decode_includes(includes)
        return {} unless includes

        decoder = PG::TextDecoder::Array.new
        decoder.decode(includes)
          .map { |e| JSON.parse(e) }
          .each_with_object({}) do |entry, h|
            h[entry.dig('sys', 'id')] = entry
          end
      end

      def finalize_statement(select_statement, limit_statement = nil, depth: nil)
        statement =
          if content_type == 'Asset'
            "WHERE t.data->'sys'->>'type' = $1"
          else
            "WHERE t.data->'sys'->'contentType'->'sys'->>'id' = $1"
          end
        params = [content_type]
        joins = []

        statement =
          conditions.reduce(statement) do |memo, condition|
            raise ArgumentError, "Operator #{condition.op} not supported" unless condition.op == :eq

            if condition.path_tuples.length == 1
              memo + _eq(condition.path, condition.expected, params)
            else
              join_path, expectation_path = condition.path_tuples
              memo + _join(join_path, expectation_path, condition.expected, params, joins)
            end
          end

        table = 'contentful_raw'
        if depth && depth > 0
          table = 'contentful_raw_includes'
          select_statement += ', t.includes'
        end

        statement =
          select_statement +
          " FROM #{table} AS t \n" +
          joins.join("\n") + "\n" +
          statement +
          (limit_statement || '')

        [statement, params]
      end

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
    end

    class << self
      def ensure_schema(conn)
        conn.exec(<<~HEREDOC
          CREATE TABLE IF NOT EXISTS contentful_raw (
            id varchar PRIMARY KEY,
            data jsonb,
            links text[]
          );
          ALTER TABLE contentful_raw ADD COLUMN IF NOT EXISTS links text[];
          CREATE INDEX IF NOT EXISTS contentful_raw_value_type ON contentful_raw ((data->'sys'->>'type'));
          CREATE INDEX IF NOT EXISTS contentful_raw_value_content_type ON contentful_raw ((data->'sys'->'contentType'->'sys'->>'id'));

          CREATE or replace FUNCTION "fn_contentful_upsert_entry"(_id varchar, _data jsonb, _links text[]) RETURNS jsonb AS $$
          DECLARE
            prev jsonb;
          BEGIN
            SELECT data, links FROM contentful_raw WHERE id = _id INTO prev;
            INSERT INTO contentful_raw (id, data, links) values (_id, _data, _links)
              ON CONFLICT (id) DO
                UPDATE
                SET data = _data,
                  links = _links;
            RETURN prev;
          END;
          $$ LANGUAGE 'plpgsql';

          CREATE MATERIALIZED VIEW IF NOT EXISTS contentful_raw_includes_ids_jointable AS
            WITH RECURSIVE includes (root_id, depth) AS (
              SELECT t.id as root_id, 0, t.id, t.links FROM contentful_raw t
              UNION ALL
                SELECT l.root_id, l.depth + 1, r.id, r.links
                FROM includes l, contentful_raw r
                WHERE r.id = ANY(l.links) AND l.depth < 5
            )
            SELECT DISTINCT root_id as id, id as included_id
              FROM includes;

          CREATE INDEX IF NOT EXISTS contentful_raw_includes_ids_jointable_id ON contentful_raw_includes_ids_jointable (id);
          CREATE UNIQUE INDEX IF NOT EXISTS contentful_raw_includes_ids_jointable_id_included_id ON contentful_raw_includes_ids_jointable (id, included_id);

          CREATE OR REPLACE VIEW contentful_raw_includes AS
            SELECT t.id, t.data, array_remove(array_agg(r_incl.data), NULL) as includes
              FROM contentful_raw t
              LEFT JOIN contentful_raw_includes_ids_jointable incl ON t.id = incl.id
              LEFT JOIN contentful_raw r_incl ON r_incl.id = incl.included_id
              GROUP BY t.id, t.data;


        HEREDOC
        )
      end

      def prepare_statements(conn)
        conn.prepare('upsert_entry', 'SELECT * FROM fn_contentful_upsert_entry($1,$2,$3)')
        conn.prepare('select_entry', 'SELECT * FROM contentful_raw WHERE id = $1')
        conn.prepare('select_ids', 'SELECT id FROM contentful_raw')
        conn.prepare('delete_by_id', 'DELETE FROM contentful_raw WHERE id = $1 RETURNING *')
        conn.prepare('refresh_views_concurrently',
          'REFRESH MATERIALIZED VIEW CONCURRENTLY contentful_raw_includes_ids_jointable')
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
