# frozen_string_literal: true

appraise "rack-2.0_ruby-2.7.6" do
  gem 'rack', '~> 2.0'

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

appraise "rails-6.1_ruby-3.1" do
  gem 'rails', '~> 6.1'
  gem 'railties', '~> 6.1'

  # https://stackoverflow.com/a/70500221
  gem 'net-smtp', require: false

  gem 'sqlite3', '~> 1.4'

  group :test do
    gem 'rspec-rails', '~> 5.0'
  end

  ruby '3.1.1'
end

appraise "rails-7.0_ruby-3.2" do
  gem 'rails', '~> 7.0.0'
  gem 'railties', '~> 7.0.0'

  gem 'sqlite3', '~> 1.4'

  group :test do
    gem 'rspec-rails', '~> 6.0'
  end

  ruby '3.2.2'
end

appraise "rails-7.2_ruby-3.3" do
  gem 'rails', '~> 7.2.0'
  gem 'railties', '~> 7.2.0'

  group :test do
    gem 'rspec-rails', '~> 6.0'
  end

  ruby '3.3.5'
end

appraise "rails-8.0_ruby-3.4" do
  gem 'rails', '~> 8.0.0'
  gem 'railties', '~> 8.0.0'

  gem 'sqlite3', '>= 2.1'

  group :test do
    gem 'rspec-rails', '~> 6.0'
  end

  ruby '3.4.2'
end
