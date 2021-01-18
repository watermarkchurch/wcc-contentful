# frozen_string_literal: true

require 'bump/tasks'
require 'bundler/gem_helper'
require 'active_support/inflector'

require_relative 'wcc-contentful/lib/wcc/contentful/version'
version = WCC::Contentful::VERSION

GEMS = [
  'wcc-contentful',
  'wcc-contentful-app',
  'wcc-contentful-graphql'
].freeze

GEMS.each do |name|
  namespace name do
    Dir.chdir(name) do
      Bundler::GemHelper.install_tasks
    end
  end
end

def sync_versions
  current = Bump::Bump.current
  GEMS.each do |gem|
    Dir.chdir(gem) do
      Bump::Bump.run('set', version: current, commit: false, bundle: false, tag: false)
    end
  end
end

task :check do
  GEMS.each do |gem|
    version_file = "#{gem}/lib/#{gem.gsub('-', '/')}/version"
    require_relative version_file
    version_const = to_const(gem).const_get('VERSION')

    unless version_const == version
      raise "Versions are not synchronized!  Please update #{version_file}.rb"
    end
  end
end

# After each version bump task, sync the versions of the gems
namespace :bump do
  Bump::Bump::BUMPS.each do |bump|
    task bump do
      sync_versions

      system('find . -type f -name version.rb | xargs git add')
      system("git commit -m 'Release v#{Bump::Bump.current}'")
    end
  end
end

desc "Create tag and build and push all gems\n" \
  'To prevent publishing in RubyGems use `gem_push=no rake release`'
task release: [:check].concat(GEMS.map { |g| "#{g}:release" })
desc "Build #{GEMS.join(',')} into the pkg directory."
task build: GEMS.map { |g| "#{g}:build" }
task install: GEMS.map { |g| "#{g}:install" }
task 'install:local' => GEMS.map { |g| "#{g}:install:local" }

def to_const(gem)
  gem.split('-').map(&:titleize).join('::').gsub('Wcc', 'WCC').constantize
end

namespace :coverage do
  task :aggregate do
    require 'simplecov'

    # https://github.com/colszowka/simplecov/issues/219#issuecomment-377991535
    results =
      GEMS.map { |g| "#{g}/coverage/.resultset.json" }.map do |result_file_name|
        puts "Processing #{result_file_name}"
        SimpleCov::Result.from_hash(JSON.parse(File.read(result_file_name)))
      end
    merged_result = SimpleCov::ResultMerger.merge_results(*results)
    FileUtils.mkdir_p('./coverage')
    File.write('./coverage/.resultset.json', JSON.pretty_generate(merged_result.to_hash))
  end

  task html: 'coverage:aggregate' do
    require 'simplecov'

    result = SimpleCov::Result.from_hash(JSON.parse(File.read('./coverage/.resultset.json')))
    formatter = SimpleCov::Formatter::HTMLFormatter.new
    formatter.format(result)

    system('open ./coverage/index.html')
  end

  task coveralls: 'coverage:aggregate' do
    require 'simplecov'
    require 'coveralls'

    result = SimpleCov::Result.from_hash(JSON.parse(File.read('./coverage/.resultset.json')))
    formatter = Coveralls::SimpleCov::Formatter.new
    formatter.format(result)
  end
end

task coverage: [*GEMS.map { |g| "#{g}:coverage" }, 'coverage:aggregate'] do
end
