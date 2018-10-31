# frozen_string_literal: true

module Wcc
  class ModelGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)
    argument :model, type: :string

    VALID_MODELS =
      Dir.glob("#{__dir__}/templates/*")
        .select { |f| File.directory? f }
        .map { |f| File.basename f }
        .sort
        .freeze

    def initialize(*)
      super

      return if VALID_MODELS.include?(singular)

      raise ArgumentError, "Model must be one of #{VALID_MODELS.to_sentence}"
    end

    def ensure_migration_tools_installed
      in_root do
        run 'npm init -y' unless File.exist?('package.json')
        package = JSON.parse(File.read('package.json'))
        deps = package['dependencies']

        unless deps.try(:[], '@watermarkchurch/contentful-migration').present?
          run 'npm install --save @watermarkchurch/contentful-migration ts-node ' \
            'typescript contentful-export'
        end
      end
    end

    def ensure_wrapper_script_in_bin_dir
      unless inside('bin') { File.exist?('contentful') }
        copy_file 'contentful_shell_wrapper', 'bin/contentful'
      end

      if inside('bin') { File.exist?('release') }
        release = inside('bin') { File.read('release') }
        unless release.include?('contentful migrate')
          insert_into_file('bin/release', after: 'bundle exec rake db:migrate') do
            <<~HEREDOC
              DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
              $DIR/contentful migrate -y
            HEREDOC
          end
        end
      else
        copy_file 'release', 'bin/release'
      end

      if in_root { File.exist?('Procfile') }
        procfile = in_root { File.read('Procfile') }
        unless procfile.include?('release:')
          insert_into_file('Procfile') do
            'release: bin/release'
          end
        end
      else
        copy_file 'Procfile'
      end
    end

    def ensure_initializer_exists
      return if inside('config/initializers') { File.exist?('wcc_contentful.rb') }

      copy_file 'wcc_contentful.rb', 'config/initializers/wcc_contentful.rb'
    end

    def create_model_migrations
      copy_file "#{singular}/migrations/generated_add_#{plural}.ts",
        "db/migrate/#{timestamp}01_generated_add_#{plural}.ts"

      Dir.glob("#{singular}/migrations/*.rb").each do |f|
        copy_file f, "db/migrate/#{timestamp}_#{f}"
      end
    end

    def drop_model_overrides_in_app_models
      directory "#{singular}/models", 'app/models'
    end

    private

    def singular
      model.downcase.singularize
    end

    def plural
      model.downcase.pluralize
    end

    def timestamp
      Time.now.strftime('%Y%m%d%H%M')
    end
  end
end
