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

    task :coverage do
      require 'simplecov'
      require 'rspec'

      specs = Dir.glob("#{__dir__}/#{name}/spec/**/*_spec.rb")

      Dir.chdir(name) do
        RSpec::Core::Runner.run([*specs])
      end
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

task coverage: GEMS.map { |g| "#{g}:coverage" } do
end
