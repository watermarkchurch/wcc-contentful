# frozen_string_literal: true


appraise "rails-5.2_ruby-2.7.6" do
  gem 'rails', '~> 5.2.0'
  gem 'railties', '~> 5.2.0'

  group :test do
    gem 'rspec-rails', '~> 3.7'
  end

  ruby '2.7.6'
end

appraise "rails-6.1_ruby-2.7.6" do
  gem 'rails', '~> 6.1'
  gem 'railties', '~> 6.1'

  group :test do
    gem 'rspec-rails', '~> 5.0'
  end

  ruby '2.7.6'
end

appraise "middleman-4.2_ruby-2.7.6" do
  gem 'middleman', '~> 4.2'

  ruby '2.7.6'
end

appraise "rails-6.1_ruby-3.1" do
  gem 'rails', '~> 6.1'
  gem 'railties', '~> 6.1'
  # https://stackoverflow.com/a/70500221
  gem 'net-smtp', require: false

  group :test do
    gem 'rspec-rails', '~> 5.0'
  end

  ruby '3.1.1'
end