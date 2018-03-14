# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wcc/contentful/version'

Gem::Specification.new do |spec|
  spec.name          = 'wcc-contentful'
  spec.version       = WCC::Contentful::VERSION
  spec.authors       = ['Watermark Dev']
  spec.email         = ['dev@watermark.org']

  spec.summary       = File.readlines('README.md').join
  spec.description   = 'Contentful API wrapper library for Watermark apps'
  spec.homepage      = 'https://github.com/watermarkchurch/wcc-contentful'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 2.3'

  spec.files         =
    `git ls-files -z`.split("\x0").reject do |f|
      f.match(%r{^(test|spec|features)/})
    end

  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'dotenv', '~> 2.2'
  spec.add_development_dependency 'httplog', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.3.0'
  spec.add_development_dependency 'rubocop', '~> 0.52'
  spec.add_development_dependency 'vcr', '~> 4.0'
  spec.add_development_dependency 'webmock', '~> 3.0'

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency 'guard', '~> 2.14'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'guard-rubocop', '~> 1.3.0'

  # for generators
  spec.add_development_dependency 'generator_spec', '~> 0.9.4'
  spec.add_development_dependency 'rails', '~> 5.1'
  spec.add_development_dependency 'rspec-rails', '~> 3.7'
  spec.add_development_dependency 'timecop', '~> 0.9.1'

  # optional dependencies
  spec.add_development_dependency 'contentful_model', '~> 0.2.0'
  spec.add_development_dependency 'pg', '~> 1.0'

  spec.add_dependency 'activesupport', '>= 5'
  spec.add_dependency 'contentful', '>= 0.12.0'
  spec.add_dependency 'dry-validation', '~> 0.11.1'
  spec.add_dependency 'graphql', '~> 1.7'
end
