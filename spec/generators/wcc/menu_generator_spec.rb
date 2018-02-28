# frozen_string_literal: true

require 'rails_helper'
require 'rails/generators'
require 'generators/wcc/menu/menu_generator'

class MenuGeneratorTest < Rails::Generators::TestCase
  tests MenuGenerator
  destination Rails.root.join('tmp/generators')
  setup :prepare_destination

  # test "generator runs without errors" do
  #   assert_nothing_raised do
  #     run_generator ["arguments"]
  #   end
  # end
end
