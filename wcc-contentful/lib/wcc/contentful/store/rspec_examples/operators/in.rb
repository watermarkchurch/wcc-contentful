# frozen_string_literal: true

RSpec.shared_examples 'supports :in operator' do
  it 'find_all with array on string field' do
    ids = 1.upto(10).to_a
    data =
      ids.map do |i|
        {
          'sys' => {
            'id' => "k#{i}",
            'contentType' => { 'sys' => { 'id' => 'test' } }
          },
          'fields' => { 'name' => { 'en-US' => "test#{i}" } }
        }
      end
    data.each { |d| subject.set(d.dig('sys', 'id'), d) }

    to_find = ids.shuffle.take(2)

    # act
    found = subject.find_all(content_type: 'test')
      .in('name', to_find.map { |i| "test#{i}" })

    expect(found.count).to eq(2)
    expect(found.map { |item| item.dig('sys', 'id') }.sort).to eq(
      to_find.map { |i| "k#{i}" }.sort
    )
  end

  it 'find_all with array on array field' do
    ids = 1.upto(10).to_a
    data =
      ids.map do |i|
        {
          'sys' => {
            'id' => "k#{i}",
            'contentType' => { 'sys' => { 'id' => 'test' } }
          },
          'fields' => { 'name' => { 'en-US' => ["test#{i}", "test_2_#{i}"] } }
        }
      end
    data.each { |d| subject.set(d.dig('sys', 'id'), d) }

    to_find1, to_find2 = ids.shuffle

    # act
    found = subject.find_all(content_type: 'test')
      .in('name', ["test#{to_find1}", "test_2_#{to_find2}"])

    expect(found.count).to eq(2)
    expect(found.map { |item| item.dig('sys', 'id') }.sort).to eq(
      ["k#{to_find1}", "k#{to_find2}"].sort
    )
  end

  it 'find_all defaults to :in when given an array' do
    ids = 1.upto(10).to_a
    data =
      ids.map do |i|
        {
          'sys' => {
            'id' => "k#{i}",
            'contentType' => { 'sys' => { 'id' => 'test' } }
          },
          'fields' => { 'name' => { 'en-US' => "test#{i}" } }
        }
      end
    data.each { |d| subject.set(d.dig('sys', 'id'), d) }

    to_find = ids.shuffle.take(3)

    # act
    found = subject.find_all(content_type: 'test')
      .apply('name' => to_find.map { |i| "test#{i}" })

    expect(found.count).to eq(3)
    expect(found.map { |item| item.dig('sys', 'id') }.sort).to eq(
      to_find.map { |i| "k#{i}" }.sort
    )
  end

  it 'find_by with array on string field' do
    ids = 1.upto(10).to_a
    data =
      ids.map do |i|
        {
          'sys' => {
            'id' => "k#{i}",
            'contentType' => { 'sys' => { 'id' => 'test' } }
          },
          'fields' => { 'name' => { 'en-US' => "test#{i}" } }
        }
      end
    data.each { |d| subject.set(d.dig('sys', 'id'), d) }

    to_find = ids.sample

    # act
    found = subject.find_by(
      content_type: 'test',
      filter: { name: { in: ['asdf', "test#{to_find}"] } }
    )

    expect(found.dig('sys', 'id')).to eq("k#{to_find}")
  end

  it 'find_by defaults to :in when given an array' do
    ids = 1.upto(10).to_a
    data =
      ids.map do |i|
        {
          'sys' => {
            'id' => "k#{i}",
            'contentType' => { 'sys' => { 'id' => 'test' } }
          },
          'fields' => { 'name' => { 'en-US' => "test#{i}" } }
        }
      end
    data.each { |d| subject.set(d.dig('sys', 'id'), d) }

    to_find = ids.sample

    # act
    found = subject.find_by(
      content_type: 'test',
      filter: { name: ['asdf', "test#{to_find}"] }
    )

    expect(found.dig('sys', 'id')).to eq("k#{to_find}")
  end
end
