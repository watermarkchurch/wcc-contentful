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
    expect(faq.fields['question'].type).to eq(:String)
    expect(faq.fields['answer'].type).to eq(:String)
    expect(faq.fields['numFaqs'].type).to eq(:Int)
    expect(faq.fields['numFaqsFloat'].type).to eq(:Float)
    expect(faq.fields['dateOfFaq'].type).to eq(:DateTime)
    expect(faq.fields['truthyOrFalsy'].type).to eq(:Boolean)
    expect(faq.fields['placeOfFaq'].type).to eq(:Location)
  end
end
