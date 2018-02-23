# frozen_string_literal: true

RSpec.describe WCC::Contentful::Graphql::Indexer do
  subject { WCC::Contentful::Graphql::Indexer.instance }

  it 'loads data from sync API' do
    sync_initial = JSON.parse(load_fixture('contentful/sync_initial.json'))

    # act
    sync_initial.each do |k, v|
      subject.index(k, v)
    end

    # assert
    expect(subject.types.keys.sort).to eq(
      [
        'ContentfulAsset',
        'ContentfulFaq',
        'ContentfulHomepage',
        'ContentfulMenu',
        'ContentfulMenuItem',
        'ContentfulMigrationHistory',
        'ContentfulPage',
        'ContentfulRedirect',
        'ContentfulSection-Faq',
        'ContentfulSection-VideoHighlight'
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
    expect(sections_ref[:link_types].sort).to eq([
                                                   'ContentfulSection-Faq',
                                                   'ContentfulSection-VideoHighlight'
                                                 ])
  end
end
