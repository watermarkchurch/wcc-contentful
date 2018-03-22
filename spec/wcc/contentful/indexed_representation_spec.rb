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

  it 'deep dup duplicates all the way down to fields' do
    ir = described_class.from_json(serialized)

    # act
    ir2 = ir.deep_dup

    # assert
    expect(ir2).to_not equal(ir)

    ct = ir[ir.keys.first]
    ct2 = ir2[ct.name]
    expect(ct2).to_not equal(ct)

    field = ct.fields.values.first
    field2 = ct2.fields[field.name]
    expect(field2).to_not equal(field)
  end

  it '#== works after deep dup' do
    ir = described_class.from_json(serialized)

    # act
    ir2 = ir.deep_dup

    # assert
    expect(ir2).to eq(ir)
    expect(ir2 == ir).to be true
    expect(ir2 != ir).to be false

    ct = ir[ir.keys.first]
    ct2 = ir2[ct.name]
    expect(ct2).to eq(ct)
    expect(ct2 == ct).to be true

    field = ct.fields.values.first
    field2 = ct2.fields[field.name]
    expect(field2).to eq(field)
    expect(field2 == field).to be true
  end
end
