# frozen_string_literal: true

RSpec.describe WCC::Contentful::Store::MemoryStore do
  subject { WCC::Contentful::Store::MemoryStore.new }

  it_behaves_like 'contentful store'

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

  it 'can find string key with indifferent access' do
    data = { value: 1 }

    subject.set('test', data)

    expect(subject.find(:test)).to eq(data)
    expect(subject.find('test')).to eq(data)
  end

  it 'can find symbol key with indifferent access' do
    data = { value: 1 }

    subject.set(:test, data)

    expect(subject.find(:test)).to eq(data)
    expect(subject.find('test')).to eq(data)
  end
end
