# frozen_string_literal: true

rubies =
  [
    '2.3.8',
    '2.5.7',
    '3.1.1'
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

  appraise "rails-6.1_ruby-#{ruby_version}" do
    gem 'rails', '~> 6.1'
    gem 'railties', '~> 6.1'

    group :test do
      gem 'rspec-rails', '~> 6.0'
    end

    instance_exec(&common)
  end

  appraise "middleman-4.2_ruby-#{ruby_version}" do
    gem 'middleman', '~> 4.2'

    instance_exec(&common)
  end
end
