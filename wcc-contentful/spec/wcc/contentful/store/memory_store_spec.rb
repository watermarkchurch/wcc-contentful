# frozen_string_literal: true

require 'wcc/contentful/store/rspec_examples'

RSpec.describe WCC::Contentful::Store::MemoryStore do
  subject { WCC::Contentful::Store::MemoryStore.new(configuration) }

  let(:configuration) {
    WCC::Contentful::Configuration.new
  }

  it_behaves_like 'contentful store', {
    nested_queries: false,
    locale_queries: true,
    include_param: 0,
    operators: described_class::SUPPORTED_OPS
  }

  it 'returns all keys' do
    data = { 'key' => 'val', '1' => { 'deep' => 9 } }

    # act
    subject.set('1234', data)
    subject.set('5678', data)
    subject.set('9999', data)
    subject.set('8888', data)
    keys = subject.keys

    # assert
    expect(keys.sort).to eq(
      %w[1234 5678 8888 9999]
    )
  end
end
