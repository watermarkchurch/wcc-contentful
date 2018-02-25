# frozen_string_literal: true

RSpec.shared_examples 'contentful store' do
  it 'stores and finds data by ID' do
    data = { 'key' => 'val', '1' => { 'deep' => 9 } }

    # act
    subject.index('1234', data)
    found = subject.find('1234')

    # assert
    expect(found).to eq(data)
  end

  it 'returns all keys' do
    data = { 'key' => 'val', '1' => { 'deep' => 9 } }

    # act
    subject.index('1234', data)
    subject.index('5678', data)
    subject.index('9999', data)
    subject.index('8888', data)
    keys = subject.keys

    # assert
    expect(keys.sort).to eq(
      %w[1234 5678 8888 9999]
    )
  end

  it 'find_all gets everything' do
    data =
      1.upto(10).map do |i|
        { 'sys' => { 'id' => "k#{i}" }, '1' => { 'deep' => 9 + i } }
      end
    data.each { |d| subject.index(d['sys']['id'], d) }

    # act
    found = subject.find_all

    # assert
    expect(found.count).to eq(10)
    expect(found.first).to eq({ 'sys' => { 'id' => 'k1' }, '1' => { 'deep' => 10 } })
    expect(found.map { |d| d.dig('1', 'deep') }).to eq(
      [10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
    )
  end

  it 'find_all can apply filter query' do
    data =
      1.upto(10).map do |i|
        { 'sys' => { 'id' => "k#{i}" }, 'fields' => { 'name' => { 'en-US' => "test#{i}" } } }
      end
    data.each { |d| subject.index(d.dig('sys', 'id'), d) }

    # act
    found = subject.find_all.eq('name', 'test4')

    # assert
    expect(found.count).to eq(1)
    expect(found.first['sys']['id']).to eq('k4')
  end

  it 'find_by filters on content type' do
    content_types = %w[test1 test2 test3 test4]
    data =
      1.upto(10).map do |i|
        {
          'sys' => {
            'id' => "k#{i}",
            'contentType' => { 'sys' => { 'id' => content_types[i % content_types.length] } }
          },
          'fields' => { 'name' => { 'en-US' => "test#{i}" } }
        }
      end
    data.each { |d| subject.index(d.dig('sys', 'id'), d) }

    # act
    found = subject.find_by(content_type: 'test2')

    # assert
    expect(found.count).to eq(3)
    expect(found.map { |d| d.dig('sys', 'id') }).to eq(
      %w[k1 k5 k9]
    )
  end

  it 'find_by can apply filter query' do
    content_types = %w[test1 test2 test3 test4]
    data =
      1.upto(10).map do |i|
        {
          'sys' => {
            'id' => "k#{i}",
            'contentType' => { 'sys' => { 'id' => content_types[i % content_types.length] } }
          },
          'fields' => { 'name' => { 'en-US' => "test#{i}" } }
        }
      end
    data.each { |d| subject.index(d.dig('sys', 'id'), d) }

    # act
    found = subject.find_by(content_type: 'test2')
      .apply({ field: 'name', eq: 'test5' })

    # assert
    expect(found.count).to eq(1)
    expect(found.first.dig('sys', 'id')).to eq('k5')
  end
end
