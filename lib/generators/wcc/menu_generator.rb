# frozen_string_literal: true

module Wcc
  class MenuGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def create_menus_migration
      now = Time.now.strftime('%Y%m%d%H%M')
      copy_file 'generated_add_menus.ts',
        "db/migrate/#{now}01_generated_add_menus.ts"
    end

    def ensure_migration_tools_installed
      in_root do
        run 'npm init -y' unless File.exist?('package.json')
        package = JSON.parse(File.read('package.json'))
        deps = package['dependencies']

        unless deps.try(:[], 'contentful-migration-cli').present?
          run 'npm install --save watermarkchurch/migration-cli'
        end
      end
    end

    def ensure_wrapper_script_in_bin_dir
      copy_file 'contentful', 'bin/contentful' unless inside('bin') { File.exist?('contentful') }

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

    def drop_model_overrides_in_lib_dir
      copy_file 'menu.rb', 'lib/wcc/contentful/model/menu.rb'
      copy_file 'menu_button.rb', 'lib/wcc/contentful/model/menu_button.rb'
    end
  end
end
