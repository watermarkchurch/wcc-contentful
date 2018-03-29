# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators'
require 'generators/wcc/menu_generator'

require 'generator_spec'
require 'timecop'

RSpec.describe Wcc::MenuGenerator, type: :generator do
  destination Rails.root.join('tmp/generators')

  before(:all) do
    Timecop.freeze(Time.parse('2018-01-02T12:03:04'))
    prepare_destination
    run_generator
  end

  after(:all) do
    Timecop.return
  end

  it 'should drop migration in directory' do
    expect(destination_root).to have_structure {
      directory 'db' do
        directory 'migrate' do
          file '20180102120301_generated_add_menus.ts' do
            contains 'export = function (migration: Migration) {'
            contains 'migration.createContentType(\'menu\')'
            contains 'migration.createContentType(\'menuButton\')'
          end
        end
      end
    }
  end

  it 'should ensure migration-cli is installed' do
    expect(destination_root).to have_structure {
      file 'package.json' do
        contains '"contentful-migration-cli": "github:watermarkchurch/migration-cli"'
      end
    }
  end

  it 'should ensure bash wrapper is in bin directory' do
    expect(destination_root).to have_structure {
      directory 'bin' do
        file 'contentful'
      end
    }
  end

  it 'should ensure migrations are run on bin/release' do
    expect(destination_root).to have_structure {
      directory 'bin' do
        file 'release' do
          contains 'contentful migrate -y'
        end
      end
    }
  end

  it 'should ensure initializer exists' do
    expect(destination_root).to have_structure {
      directory 'config' do
        directory 'initializers' do
          file 'wcc_contentful.rb' do
            contains 'WCC::Contentful.configure'
            contains 'WCC::Contentful.init!'
          end
        end
      end
    }
  end

  it 'should drop sample model overrides in lib dir' do
    expect(destination_root).to have_structure {
      directory 'lib' do
        directory 'wcc' do
          directory 'contentful' do
            directory 'model' do
              file 'menu.rb' do
                contains 'class WCC::Contentful::Model::Menu < WCC::Contentful::Model'
              end
              file 'menu_button.rb' do
                contains 'class WCC::Contentful::Model::MenuButton < WCC::Contentful::Model'
              end
            end
          end
        end
      end
    }
  end
end
