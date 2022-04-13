# frozen_string_literal: true

rubies =
  [
    '2.3.8',
    '2.5.7'
  ].map { |r| Gem::Version.new(r) }

rubies.each do |ruby_version|
  common =
    proc do
      ruby ruby_version.to_s
    end

  appraise "rails-5.2_ruby-#{ruby_version}" do
    gem 'rails', '~> 5.2.0'
    gem 'railties', '~> 5.2.0'

    group :test do
      gem 'rspec-rails', '~> 3.7'
    end

    instance_exec(&common)
  end

  appraise "rails-5.0_ruby-#{ruby_version}" do
    gem 'rails', '~> 5.0.0'
    gem 'railties', '~> 5.0.0'

    group :test do
      gem 'rspec-rails', '~> 3.7'
    end

    instance_exec(&common)
  end

  appraise "middleman-4.2_ruby-#{ruby_version}" do
    gem 'middleman', '~> 4.2'
    # nokogiri 1.13+ requires ruby 2.6+
    gem 'nokogiri', '< 1.13'

    instance_exec(&common)
  end
end
