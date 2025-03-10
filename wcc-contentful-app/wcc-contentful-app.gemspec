# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wcc/contentful/app/version'

doc_version = Gem::Version.new(WCC::Contentful::App::VERSION).release.to_s.sub(/\.\d+$/, '')

# rubocop:disable Layout/LineLength
Gem::Specification.new do |spec|
  spec.name          = 'wcc-contentful-app'
  spec.version       = WCC::Contentful::App::VERSION
  spec.authors       = ['Watermark Dev']
  spec.email         = ['dev@watermark.org']

  spec.summary       = File.readlines(File.expand_path('README.md', __dir__)).join
  spec.description   = 'Models, Controllers, and Views common to Watermark Church apps'
  spec.homepage      = 'https://github.com/watermarkchurch/wcc-contentful'
  spec.license       = 'MIT'

  spec.metadata = {
    'documentation_uri' => "https://watermarkchurch.github.io/wcc-contentful/#{doc_version}/wcc-contentful-app",
'rubygems_mfa_required' => 'true'
  }

  spec.required_ruby_version = '>= 2.7'

  spec.files = Dir['app/**/*', 'config/**/*', 'lib/**/*'] +
    %w[Rakefile README.md wcc-contentful-app.gemspec]

  spec.require_paths = ['lib']

  spec.add_development_dependency 'capybara', '~> 3.9'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'dotenv', '~> 2.2'
  spec.add_development_dependency 'erb_lint'
  spec.add_development_dependency 'httplog', '~> 1.0'
  spec.add_development_dependency 'rails-controller-testing', '~> 1.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rspec_junit_formatter', '~> 0.4.1'
  spec.add_development_dependency 'simplecov', '~> 0.16.1'
  spec.add_development_dependency 'vcr', '~> 5.0'
  spec.add_development_dependency 'webmock', '~> 3.0'

  # Makes testing easy via `bundle exec guard`
  spec.add_development_dependency 'guard', '~> 2.14'
  spec.add_development_dependency 'guard-rspec', '~> 4.7'
  spec.add_development_dependency 'guard-rubocop', '~> 1.3.0'
  spec.add_development_dependency 'guard-shell', '~> 0.7.1'

  # for generators
  spec.add_development_dependency 'generator_spec', '~> 0.9.4'

  # wcc-contentful-app needs rails to function, so require it for specs.
  spec.add_development_dependency 'rails', '~> 5'
  spec.add_development_dependency 'rspec-rails', '~> 3.7'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'timecop', '~> 0.9.1'
  spec.add_development_dependency 'typhoeus', '~> 1.4.0'

  spec.add_dependency 'redcarpet', '~> 3.4'
  spec.add_dependency 'wcc-contentful', "~> #{WCC::Contentful::App::VERSION}"
end
# rubocop:enable Layout/LineLength
