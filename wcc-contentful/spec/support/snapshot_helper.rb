# frozen_string_literal: true

require 'rspec/expectations'

module WCC::Contentful::SnapshotHelper
  extend ActiveSupport::Concern
  extend RSpec::Matchers::DSL

  included do
    after(:all) do
      # we have to do this in an after block in case there's multiple
      # writes in the same file, which would mess up our detected line numbers.
      write_all_inline_snapshots
    end
  end

  matcher :match_html_snapshot do |file_name|
    match do |actual|
      @expected = load_snapshot(file_name)
      @actual = Nokogiri::HTML.fragment(actual).to_xhtml.strip

      if @expected.blank? || update_snapshots?
        write_snapshot(file_name, @actual.to_xhtml)
        next true
      end

      @expected = Nokogiri::HTML.fragment(@expected).to_xhtml.strip
      values_match?(@expected, @actual)
    end

    failure_message do |_actual|
      [
        "Expected to match snapshot in file #{file_name}",
        '(run with env var UPDATE_SNAPSHOTS=true to update snapshots)',
        "Diff:#{differ.diff_as_string(@actual, @expected)}"
      ].join("\n")
    end
  end

  matcher :match_inline_html_snapshot do |inline_snapshot|
    filename, line_num = WCC::Contentful::SnapshotHelper
      .find_inline_call_spot(caller)
    raise StandardError, 'Could not find inline call spot' if line_num.blank?

    match do |actual|
      @expected = inline_snapshot
      @actual = Nokogiri::HTML.fragment(actual).to_xhtml.strip

      if @expected.blank?
        queue_write_inline_snapshot(filename, line_num, @actual)
        next true
      end

      @expected = Nokogiri::HTML.fragment(@expected).to_xhtml.strip
      values_match?(@expected, @actual)
    end

    failure_message do |_actual|
      [
        'Expected to match inline snapshot',
        '(delete inline snapshot heredoc including <<~SNAP and SNAP tags to regenerate)',
        "Diff:#{differ.diff_as_string(@actual, @expected)}"
      ].join("\n")
    end
  end

  # https://stackoverflow.com/a/32479025/2192243
  def differ
    RSpec::Support::Differ.new(
      object_preparer: ->(object) { RSpec::Matchers::Composable.surface_descriptions_in(object) },
      color: RSpec::Matchers.configuration.color?
    )
  end

  def update_snapshots?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('UPDATE_SNAPSHOTS', nil))
  end

  def snapshot_full_path(file_name)
    File.join('spec/snapshots', file_name)
  end

  def load_snapshot(file_name)
    file = snapshot_full_path(file_name)
    return File.read(file) if File.exist?(file)
  end

  def write_snapshot(file_name, actual)
    file = snapshot_full_path(file_name)
    FileUtils.mkdir_p(File.dirname(file))

    puts "SnapshotHelper: Writing new snapshot in #{file_name}"
    File.write(file, actual)
  end

  MATCH_INLINE_SNAPSHOT_REGEXP = /match_inline_snapshot(\((['"\s]+|<<~\w+)?\))?\s*$/.freeze

  def queue_write_inline_snapshot(filename, line_num, actual)
    to_insert = actual.split("\n")

    # enqueue to the filename
    (WCC::Contentful::SnapshotHelper.write_queue[filename] ||= []) <<
      [line_num, to_insert]
  end

  def write_all_inline_snapshots
    WCC::Contentful::SnapshotHelper.write_queue.each do |filename, queue|
      # rewrite in reverse order to preserve correct line numbers
      queue = queue.sort_by(&:first).reverse

      lines = File.readlines(filename)
      queue.each do |line_num, to_insert|
        # rewrite the lines
        idx = line_num - 1
        lines[idx] = lines[idx].sub(MATCH_INLINE_SNAPSHOT_REGEXP, 'match_inline_snapshot <<~SNAP')
        lines = lines[0..idx] + to_insert + ['SNAP'] + lines[line_num..]
      end

      puts "SnapshotHelper: Writing new inline snapshot in #{filename}"
      File.open(filename, 'w') do |f|
        lines.each { |line| f.puts(line) }
      end
    end

    WCC::Contentful::SnapshotHelper.clear_write_queue!
  end

  class << self
    def write_queue
      @write_queue ||= {}
    end

    def clear_write_queue!
      @write_queue = {}
    end

    def find_inline_call_spot(called_from)
      called_from.each do |line|
        next unless /_spec\.rb/.match?(line)

        filename, line_num = line.split(':')
        line_num = line_num&.to_i
        next unless filename && line_num

        return [filename, line_num]
      end
    end
  end
end
