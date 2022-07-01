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
    include WCC::Contentful::Instrumentation

    delegate :each, to: :to_enum

    attr_reader :connection_pool
    attr_accessor :logger

    def initialize(_config = nil, connection_options = nil, pool_options = nil)
      super()
      @schema_ensured = false
      connection_options ||= { dbname: 'postgres' }
      pool_options ||= {}
      @connection_pool = PostgresStore.build_connection_pool(connection_options, pool_options)
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

      previous_value =
        if result.num_tuples == 0
          nil
        else
          val = result.getvalue(0, 0)
          JSON.parse(val) if val
        end

      if views_need_update?(value, previous_value) && !mutex.with_read_lock { @dirty }
        _instrument 'mark_dirty'
        mutex.with_write_lock { @dirty = true }
      end

      previous_value
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

        if was_dirty
          _instrument 'refresh_views' do
            @connection_pool.with { |conn| conn.exec_prepared('refresh_views_concurrently') }
          end
        end
      end

      logger&.debug("[PostgresStore] #{statement}\n#{params.inspect}")
      _instrument 'exec' do
        @connection_pool.with { |conn| conn.exec(statement, params) }
      end
    end

    private

    def extract_links(entry)
      return [] unless fields = entry && entry['fields']

      links =
        fields.flat_map do |_f, locale_hash|
          locale_hash&.flat_map do |_locale, value|
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

    def views_need_update?(value, previous_value)
      # contentful_raw_includes_ids_jointable needs update if any links change
      return true if extract_links(value) != extract_links(previous_value)
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
          entry = resolve_includes([entry, includes], @options[:include])
        end
        entry
      end

      def result_set
        return @result_set if @result_set

        statement, params = finalize_statement('SELECT t.*', depth: @options[:include])
        @result_set =
          store.exec_query(statement, params)
            .lazy.map do |row|
            entry = JSON.parse(row['data'])
            includes =
              (decode_includes(row['includes']) if @options[:include] && @options[:include] > 0)

            [entry, includes]
          end
      rescue PG::ConnectionBad
        []
      end

      private

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
          "#{select_statement} FROM #{table} AS t \n#{joins.join("\n")}\n#{statement}#{limit_statement || ''}"

        [statement, params]
      end

      def _eq(path, expected, params)
        return " AND t.id = $#{push_param(expected, params)}" if path == %w[sys id]

        if path[3] == 'sys'
          # the path can be either an array or a singular json obj, and we have to dig
          # into it to detect whether it contains `{ "sys": { "id" => expected } }`
          expected = { 'sys' => { path[4] => expected } }.to_json
          return ' AND fn_contentful_jsonb_any_to_jsonb_array(t.data->' \
                 "#{quote_parameter_path(path.take(3))}) @> " \
                 "jsonb_build_array($#{push_param(expected, params)}::jsonb)"
        end

        " AND t.data->#{quote_parameter_path(path)}" \
          " @> to_jsonb($#{push_param(expected, params)})"
      end

      PARAM_TYPES = {
        String => 'text'

        # These can be cast directly to jsonb
        # Integer => 'jsonb'
        # Float => 'jsonb'
      }.freeze

      def push_param(param, params)
        params << param
        param_type = PARAM_TYPES[param.class] || 'jsonb'

        "#{params.length}::#{param_type}"
      end

      def quote_parameter_path(path)
        path.map { |p| "'#{p}'" }.join('->')
      end

      def _join(join_path, expectation_path, expected, params, joins)
        # join back to the table using the links column (join_table_alias becomes s0, s1, s2)
        # this is faster because of the index
        join_table_alias = push_join(join_path, joins)

        # then apply the where clauses:
        #  1. that the joined entry has the data at the appropriate path
        #  2. that the entry joining to the other entry actually links at this path and not another
        <<~WHERE_CLAUSE
           AND #{join_table_alias}.data->#{quote_parameter_path(expectation_path)} ? $#{push_param(expected, params)}::text
          AND exists (select 1 from jsonb_array_elements(fn_contentful_jsonb_any_to_jsonb_array(t.data->#{quote_parameter_path(join_path)})) as link where link->'sys'->'id' ? #{join_table_alias}.id)
        WHERE_CLAUSE
      end

      def push_join(_path, joins)
        table_alias = "s#{joins.length}"
        joins << "JOIN contentful_raw AS #{table_alias} ON " \
                 "#{table_alias}.id=ANY(t.links)"
        table_alias
      end
    end

    EXPECTED_VERSION = 2

    class << self
      def prepare_statements(conn)
        conn.prepare('upsert_entry', 'SELECT * FROM fn_contentful_upsert_entry($1,$2,$3)')
        conn.prepare('select_entry', 'SELECT * FROM contentful_raw WHERE id = $1')
        conn.prepare('select_ids', 'SELECT id FROM contentful_raw')
        conn.prepare('delete_by_id', 'DELETE FROM contentful_raw WHERE id = $1 RETURNING *')
        conn.prepare('refresh_views_concurrently',
          'REFRESH MATERIALIZED VIEW CONCURRENTLY contentful_raw_includes_ids_jointable')
      end

      # This is intentionally a class var so that all subclasses share the same mutex
      @@schema_mutex = Mutex.new # rubocop:disable Style/ClassVars

      def build_connection_pool(connection_options, pool_options)
        ConnectionPool.new(pool_options) do
          PG.connect(connection_options).tap do |conn|
            unless schema_ensured?(conn)
              @@schema_mutex.synchronize do
                ensure_schema(conn) unless schema_ensured?(conn)
              end
            end
            prepare_statements(conn)
          end
        end
      end

      def schema_ensured?(conn)
        result = conn.exec('SELECT version FROM wcc_contentful_schema_version' \
                           ' ORDER BY version DESC LIMIT 1')
        return false if result.num_tuples == 0

        result[0]['version'].to_i >= EXPECTED_VERSION
      rescue PG::UndefinedTable
        # need to run v1 schema migration
        false
      end

      def ensure_schema(conn)
        result =
          begin
            conn.exec('SELECT version FROM wcc_contentful_schema_version' \
                      ' ORDER BY version DESC')
          rescue PG::UndefinedTable
            []
          end
        1.upto(EXPECTED_VERSION).each do |version_num|
          next if result.find { |row| row['version'].to_s == version_num.to_s }

          conn.exec(File.read(File.join(__dir__, "postgres_store/schema_#{version_num}.sql")))
        end
      end
    end
  end
end
