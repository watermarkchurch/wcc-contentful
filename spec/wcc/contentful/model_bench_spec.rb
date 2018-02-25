# frozen_string_literal: true

require 'benchmark'

RSpec.describe WCC::Contentful::Model, :bench do
  include BenchHelper

  let(:types) { load_indexed_types }
  subject {
    WCC::Contentful::ModelBuilder.new(types)
  }

  context 'with memory store' do
    it 'bench Model.find by id' do
      subject.build_models

      run_bench { |id| WCC::Contentful::Model.find(id) }
    end

    it 'bench Homepage.find by id' do
      subject.build_models

      run_bench(content_type: 'homepage') { |id| WCC::Contentful::Homepage.find(id) }
    end

    it 'bench Homepage expand 15 links' do
      subject.build_models

      run_bench(content_type: 'homepage') do |id|
        homepage = WCC::Contentful::Homepage.find(id)
        # 13 links via main_menu
        main_menu = homepage.main_menu1
        main_menu.icon.file[:url]
        main_menu.second_group.each { |item| item.link&.title }
        main_menu.third_group.each { |item| item.link&.title }
        main_menu.hamburger.first_group[0].link.title

        # 2 more links via sections
        homepage.sections.each(&:id)
      end
    end

    it 'bench find_by (filter)' do
      subject.build_models

      styles = ['custom', 'rounded', 'external', 'value doesnt exist']

      run_bench(content_type: 'menuItem') do |_, i|
        _ = WCC::Contentful::MenuItem.find_by(button_style: styles[i % styles.length])
      end
    end
  end
end
