# frozen_string_literal: true

RSpec.shared_examples 'supports :nin operator' do
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

    to_exclude = ids.shuffle.take(2)

    # act
    found = subject.find_all(content_type: 'test')
      .nin('name', to_exclude.map { |i| "test#{i}" })

    expect(found.count).to eq(8)
    expect(found.map { |item| item.dig('sys', 'id') }.sort).to eq(
      (ids - to_exclude).map { |i| "k#{i}" }.sort
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

    to_exclude1, to_exclude2 = ids.shuffle

    # act
    found = subject.find_all(content_type: 'test')
      .nin('name', ["test#{to_exclude1}", "test_2_#{to_exclude2}"])

    expect(found.count).to eq(8)
    expect(found.map { |item| item.dig('sys', 'id') }.sort).to eq(
      (ids - [to_exclude1, to_exclude2]).map { |i| "k#{i}" }.sort
    )
  end

  it 'find_by with array on string field' do
    ids = 1.upto(2).to_a
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

    to_exclude, to_expect = ids.shuffle

    # act
    found = subject.find_by(
      content_type: 'test',
      filter: { name: { nin: ['asdf', "test#{to_exclude}"] } }
    )

    expect(found.dig('sys', 'id')).to eq("k#{to_expect}")
  end
end
