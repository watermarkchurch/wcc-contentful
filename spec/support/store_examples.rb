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

  it 'find_all can apply filter query' do
    data =
      1.upto(10).map do |i|
        {
          'sys' => { 'id' => "k#{i}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
          'fields' => { 'name' => { 'en-US' => "test#{i}" } }
        }
      end
    data.each { |d| subject.index(d.dig('sys', 'id'), d) }

    # act
    found = subject.find_all(content_type: 'test1').eq('name', 'test4')

    # assert
    expect(found.count).to eq(1)
    expect(found.first['sys']['id']).to eq('k4')
  end

  it 'find_all filters on content type' do
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
    found = subject.find_all(content_type: 'test2')

    # assert
    expect(found.count).to eq(3)
    expect(found.map { |d| d.dig('sys', 'id') }).to eq(
      %w[k1 k5 k9]
    )
  end

  it 'filter query eq can find value in array' do
    content_types = %w[test1 test2 test3 test4]
    data =
      1.upto(10).map do |i|
        {
          'sys' => {
            'id' => "k#{i}",
            'contentType' => { 'sys' => { 'id' => content_types[i % content_types.length] } }
          },
          'fields' => { 'name' => { 'en-US' => ["test#{i}", "test_2_#{i}"] } }
        }
      end
    data.each { |d| subject.index(d.dig('sys', 'id'), d) }

    # act
    found = subject.find_all(content_type: 'test2')
      .apply({ field: 'name', eq: 'test_2_5' })

    # assert
    expect(found.count).to eq(1)
    expect(found.first.dig('sys', 'id')).to eq('k5')
  end
end
