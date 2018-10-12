# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful do
  # describe '.validate_models!' do
  #   let(:content_types) {
  #     raw = JSON.parse(load_fixture('contentful/content_types_mgmt_api.json'))
  #     raw['items']
  #   }
  #   let(:models_dir) {
  #     File.dirname(__FILE__) + '/../../lib/wcc/contentful/model'
  #   }

  #   it 'validates successfully if all types present' do
  #     indexer =
  #       WCC::Contentful::ContentTypeIndexer.new.tap do |ixr|
  #         content_types.each { |type| ixr.index(type) }
  #       end
  #     types = indexer.types
  #     WCC::Contentful::ModelBuilder.new(types).build_models
  #     WCC::Contentful.instance_variable_set('@content_types', content_types)
  #     Dir["#{models_dir}/*.rb"].each { |file| load file }

  #     # act
  #     expect {
  #       WCC::Contentful.validate_models!
  #     }.to_not raise_error
  #   end

  #   it 'fails validation if menus not present' do
  #     all_but_menu = content_types.reject { |ct| ct.dig('sys', 'id') == 'menu' }
  #     indexer =
  #       WCC::Contentful::ContentTypeIndexer.new.tap do |ixr|
  #         all_but_menu.each { |type| ixr.index(type) }
  #       end
  #     types = indexer.types
  #     WCC::Contentful::ModelBuilder.new(types).build_models
  #     WCC::Contentful.instance_variable_set('@content_types', all_but_menu)

  #     load "#{models_dir}/menu.rb"

  #     # act
  #     expect {
  #       WCC::Contentful.validate_models!
  #     }.to raise_error(WCC::Contentful::ValidationError)
  #   end
  # end
end
