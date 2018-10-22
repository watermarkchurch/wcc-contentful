# frozen_string_literal: true

require 'bump/tasks'

task :check do
  require_relative 'wcc-contentful/lib/wcc/contentful/version'
  require_relative 'wcc-contentful-app/lib/wcc/contentful/app/version'

  unless WCC::Contentful::App::VERSION == WCC::Contentful::VERSION
    raise 'Versions are not synchronized!  Please update wcc-contentful-app/lib/wcc/contentful/app/version.rb'
  end
end

def sync_versions
  current = Bump::Bump.current
  Dir.chdir('wcc-contentful-app') do
    Bump::Bump.run('set', version: current, commit: false, bundle: false, tag: false)
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

require "bundler/gem_helper"

gems = [
  'wcc-contentful',
  'wcc-contentful-app'
]

gems.each do |name|
  namespace name do
    Dir.chdir(name) do
      Bundler::GemHelper.install_tasks
    end
  end
end

desc "Create tag and build and push all gems\n" \
  "To prevent publishing in RubyGems use `gem_push=no rake release`"
task release: [:check].concat(gems.map { |g| "#{g}:release" })
desc "Build #{gems.join(',')} into the pkg directory."
task build: gems.map { |g| "#{g}:build" }
task install: gems.map { |g| "#{g}:install" }
task "install:local" => gems.map { |g| "#{g}:install:local" }
