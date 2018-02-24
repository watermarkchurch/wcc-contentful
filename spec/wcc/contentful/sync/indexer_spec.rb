# frozen_string_literal: true

RSpec.describe WCC::Contentful::Sync::Indexer do
  subject { WCC::Contentful::Sync::Indexer.new(WCC::Contentful::Sync::MemoryStore.new) }

  it 'loads data from sync API' do
    sync_initial = JSON.parse(load_fixture('contentful/sync_initial.json'))

    # act
    sync_initial.each do |k, v|
      subject.index(k, v)
    end

    # assert
    expect(subject.types.keys.sort).to eq(
      %w[
        ContentfulAsset
        ContentfulFaq
        ContentfulHomepage
        ContentfulMenu
        ContentfulMenuItem
        ContentfulMigrationHistory
        ContentfulPage
        ContentfulRedirect
        ContentfulSection_Faq
        ContentfulSection_VideoHighlight
      ]
    )

    faq = subject.types['ContentfulFaq']
    expect(faq.dig(:fields, 'question', :type)).to eq(:String)
    expect(faq.dig(:fields, 'answer', :type)).to eq(:String)
    expect(faq.dig(:fields, 'numFaqs', :type)).to eq(:Int)
    expect(faq.dig(:fields, 'numFaqsFloat', :type)).to eq(:Float)
    expect(faq.dig(:fields, 'dateOfFaq', :type)).to eq(:DateTime)
    expect(faq.dig(:fields, 'truthyOrFalsy', :type)).to eq(:Boolean)
    expect(faq.dig(:fields, 'placeOfFaq', :type)).to eq(:Location)

    json = subject.types.to_json
    File.write('test.json', json)
  end

  it 'resolves potential linked types' do
    sync_initial = JSON.parse(load_fixture('contentful/sync_initial.json'))

    # act
    sync_initial.each do |k, v|
      subject.index(k, v)
    end

    # assert
    redirect = subject.types['ContentfulRedirect']
    redirect_ref = redirect.dig(:fields, 'pageReference')
    expect(redirect_ref[:type]).to eq(:Link)
    expect(redirect_ref[:link_types]).to include('ContentfulPage')

    homepage = subject.types['ContentfulHomepage']
    sections_ref = homepage.dig(:fields, 'sections')
    expect(sections_ref[:link_types].sort).to eq(
      %w[
        ContentfulSection_Faq
        ContentfulSection_VideoHighlight
      ]
    )
  end

  it 'resolves date times correctly' do
    sync_initial = JSON.parse(load_fixture('contentful/sync_initial.json'))

    # act
    sync_initial.each do |k, v|
      subject.index(k, v)
    end

    # assert
    history = subject.types['ContentfulMigrationHistory']
    started = history.dig(:fields, 'started')
    expect(started[:type]).to eq(:DateTime)

    migration_name = history.dig(:fields, 'migrationName')
    expect(migration_name[:type]).to eq(:String)
  end

  it 'sets array flag on array fields' do
    sync_initial = JSON.parse(load_fixture('contentful/sync_initial.json'))

    # act
    sync_initial.each do |k, v|
      subject.index(k, v)
    end

    # assert
    homepage = subject.types['ContentfulHomepage']
    favicons = homepage.dig(:fields, 'favicons')
    expect(favicons[:array]).to be(true)
  end
end
