# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wcc/contentful/middleman/version'

doc_version = Gem::Version.new(WCC::Contentful::Middleman::VERSION).release.to_s.sub(/\.\d+$/, '')

# rubocop:disable Layout/LineLength
Gem::Specification.new do |spec|
  spec.name        = 'wcc-contentful-middleman'
  spec.version     = WCC::Contentful::Middleman::VERSION
  spec.platform    = Gem::Platform::RUBY
  spec.authors       = ['Watermark Dev']
  spec.email         = ['dev@watermark.org']
  spec.summary       = File.readlines(File.expand_path('README.md', __dir__)).join
  spec.description   = 'Middleman plugin for creating pages from Contentful'
  spec.homepage      = 'https://github.com/watermarkchurch/wcc-contentful'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 2.3'

  spec.metadata = {
    'documentation_uri' => "https://watermarkchurch.github.io/wcc-contentful/#{doc_version}/wcc-contentful-middleman",
'rubygems_mfa_required' => 'true'
  }

  spec.files = Dir['lib/**/*'] + %w[Rakefile README.md wcc-contentful-middleman.gemspec]

  spec.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  spec.require_paths = ['lib']

  # The version of middleman-core your extension depends on
  spec.add_dependency 'middleman-core', '>= 4.3.6'
  spec.add_dependency 'wcc-contentful', ">= #{WCC::Contentful::Middleman::VERSION}"

  # Additional dependencies
  spec.add_development_dependency 'dotenv', '~> 2.2'
  spec.add_development_dependency 'erb_lint', '~> 0.0.26'
  spec.add_development_dependency 'httplog', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.4.1'
  spec.add_development_dependency 'simplecov', '~> 0.16.1'
  spec.add_development_dependency 'webmock', '~> 3.0'

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency 'guard', '~> 2.14'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'guard-rubocop', '~> 1.3.0'
  spec.add_development_dependency 'guard-shell', '~> 0.7.1'
end
# rubocop:enable Layout/LineLength
