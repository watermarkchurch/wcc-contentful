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
    end
  end
end
