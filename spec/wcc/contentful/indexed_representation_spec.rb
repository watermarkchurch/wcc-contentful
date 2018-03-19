# frozen_string_literal: true

RSpec.describe WCC::Contentful::IndexedRepresentation do
  let(:serialized) {
    load_fixture('contentful/indexed_types_from_content_type_indexer.json')
  }

  it 'round trip deserializes from json' do
    # act
    ir = described_class.from_json(serialized)
    reserialized = ir.to_json

    # assert
    expect(JSON.parse(reserialized)).to eq(JSON.parse(serialized))
  end
end
