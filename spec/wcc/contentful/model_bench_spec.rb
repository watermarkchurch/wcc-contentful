# frozen_string_literal: true

require 'benchmark'

RSpec.shared_examples 'model querying' do
  it 'bench Model.find by id' do
    subject.build_models

    run_bench(store_builder: store_builder) { |id| WCC::Contentful::Model.find(id) }
  end

  it 'bench Homepage.find by id' do
    subject.build_models

    run_bench(store_builder: store_builder, content_type: 'homepage') do |id|
      WCC::Contentful::Homepage.find(id)
    end
  end

  it 'bench Homepage expand 15 links' do
    subject.build_models

    run_bench(store_builder: store_builder, content_type: 'homepage') do |id|
      homepage = WCC::Contentful::Homepage.find(id)
      # 13 links via main_menu
      main_menu = homepage.main_menu
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

    run_bench(store_builder: store_builder, content_type: 'menuButton') do |_, i|
      _ = WCC::Contentful::MenuButton.find_by(button_style: styles[i % styles.length])
    end
  end

  it 'bench find_by looking for single slug' do
    subject.build_models

    run_bench(store_builder: store_builder, content_type: 'menuButton') do
      redirect = WCC::Contentful::Redirect2.find_by(slug: 'mister_roboto')
      expect(redirect.length).to eq(1)
      expect(redirect[0].pageReference.title).to eq('Conferences')
    end
  end
end

RSpec.describe WCC::ContentfulModel, :bench do
  include BenchHelper

  let(:types) { load_indexed_types }
  subject {
    WCC::Contentful::ModelBuilder.new(types)
  }

  context 'with memory store' do
    let(:store_builder) {
      -> { WCC::Contentful::Store::MemoryStore.new }
    }

    include_examples 'model querying'
  end

  context 'with postgres store' do
    let!(:store_builder) {
      -> {
        begin
          conn = PG.connect(ENV['POSTGRES_CONNECTION'] || { dbname: 'contentful' })

          conn.exec('DROP TABLE IF EXISTS contentful_raw')
        ensure
          conn.close
        end
        WCC::Contentful::Model.store =
          WCC::Contentful::Store::PostgresStore.new(ENV['POSTGRES_CONNECTION'])
      }
    }

    include_examples 'model querying'
  end
end
