# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wcc/contentful/version'

doc_version = Gem::Version.new(WCC::Contentful::VERSION).release.to_s.sub(/\.\d+$/, '')

# rubocop:disable Layout/LineLength
Gem::Specification.new do |spec|
  spec.name          = 'wcc-contentful'
  spec.version       = WCC::Contentful::VERSION
  spec.authors       = ['Watermark Dev']
  spec.email         = ['dev@watermark.org']

  spec.summary       = File.readlines(File.expand_path('README.md', __dir__)).join
  spec.description   = 'Contentful API wrapper library exposing an ActiveRecord-like interface'
  spec.homepage      = 'https://github.com/watermarkchurch/wcc-contentful/wcc-contentful'
  spec.license       = 'MIT'

  spec.metadata = {
    'documentation_uri' => "https://watermarkchurch.github.io/wcc-contentful/#{doc_version}/wcc-contentful",
    'rubygems_mfa_required' => 'true'
  }

  spec.required_ruby_version = '>= 2.7'

  spec.files = Dir['app/**/*', 'config/**/*', 'lib/**/*'] +
    %w[Rakefile README.md wcc-contentful.gemspec]

  spec.require_paths = ['lib']

  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'dotenv', '~> 2.2'
  spec.add_development_dependency 'erb_lint'
  spec.add_development_dependency 'httplog', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec-instrumentation-matcher'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.4.1'
  spec.add_development_dependency 'simplecov', '~> 0.16.1'
  spec.add_development_dependency 'vcr', '~> 5.0'
  spec.add_development_dependency 'webmock', '~> 3.0'
  spec.add_development_dependency 'wisper-rspec'

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency 'guard', '~> 2.14'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'guard-rubocop', '~> 1.3.0'
  spec.add_development_dependency 'guard-shell', '~> 0.7.1'

  # for generators
  spec.add_development_dependency 'generator_spec', '~> 0.9.4'
  # spec.add_development_dependency 'rails', '~> 5.0'
  # spec.add_development_dependency 'rspec-rails', '~> 3.7'
  spec.add_development_dependency 'sqlite3', '~> 1.4'
  spec.add_development_dependency 'timecop', '~> 0.9.1'

  # optional dependencies
  spec.add_development_dependency 'connection_pool', '~> 2.2'
  spec.add_development_dependency 'faraday', '~> 0.9'
  spec.add_development_dependency 'http', '> 1.0', '< 3.0'
  spec.add_development_dependency 'pg', '~> 1.0'
  spec.add_development_dependency 'typhoeus', '~> 1.3'

  spec.add_dependency 'activesupport', '>= 5'
  spec.add_dependency 'wcc-base', '~> 0.3.1'
  spec.add_dependency 'wisper', '~> 2.0.0'
end
# rubocop:enable Layout/LineLength
