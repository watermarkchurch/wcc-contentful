# frozen_string_literal: true


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

appraise "rails-7.0_ruby-3.2" do
  gem 'rails', '~> 7.0'
  gem 'railties', '~> 7.0'

  group :test do
    gem 'rspec-rails', '~> 6.0'
  end

  ruby '3.2.2'
end
