# frozen_string_literal: true

RSpec.shared_examples 'contentful store' do
  describe '#set/#find' do
    it 'stores and finds data by ID' do
      data = { 'key' => 'val', '1' => { 'deep' => 9 } }

      # act
      subject.set('1234', data)
      found = subject.find('1234')

      # assert
      expect(found).to eq(data)
    end

    it 'find returns nil if key doesnt exist' do
      data = { 'key' => 'val', '1' => { 'deep' => 9 } }
      subject.set('1234', data)

      # act
      found = subject.find('asdf')

      # assert
      expect(found).to be_nil
    end

    it 'set returns prior value if exists' do
      data = { 'key' => 'val', '1' => { 'deep' => 9 } }
      data2 = { 'key' => 'val', '2' => { 'deep' => 11 } }

      # act
      prior1 = subject.set('1234', data)
      prior2 = subject.set('1234', data2)

      # assert
      expect(prior1).to be_nil
      expect(prior2).to eq(data)
      expect(subject.find('1234')).to eq(data2)
    end
  end

  describe '#delete' do
    it 'deletes an item out of the store' do
      data = { 'key' => 'val', '1' => { 'deep' => 9 } }
      subject.set('9999', data)

      # act
      deleted = subject.delete('9999')

      # assert
      expect(deleted).to eq(data)
      expect(subject.find('9999')).to be_nil
    end

    it "returns nil if item doesn't exist" do
      data = { 'key' => 'val', '1' => { 'deep' => 9 } }
      subject.set('9999', data)

      # act
      deleted = subject.delete('asdf')

      # assert
      expect(deleted).to be_nil
      expect(subject.find('9999')).to eq(data)
    end
  end

  describe '#index' do
    it 'stores an "Entry"'

    it 'updates an "Entry" when exists'

    it 'TODO: does not overwrite an entry if revision is lower'

    it 'stores an "Asset"'

    it 'updates an "Asset" when exists'

    it 'TODO: does not overwrite an asset if revision is lower'

    it 'removes a "DeletedEntry"'

    it 'removes a "DeletedAsset"'
  end

  describe '#find_by' do
    it 'finds first of content type' do
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
      data.each { |d| subject.set(d.dig('sys', 'id'), d) }

      # act
      found = subject.find_by(content_type: 'test3')

      # assert
      # expect one of these, but order is not defined
      expect(%w[k2 k6 k10]).to include(found.dig('sys', 'id'))
    end

    it 'can apply filter object' do
      data =
        1.upto(10).map do |i|
          {
            'sys' => { 'id' => "k#{i}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
            'fields' => { 'name' => { 'en-US' => "test#{i}" } }
          }
        end
      data.each { |d| subject.set(d.dig('sys', 'id'), d) }

      # act
      found = subject.find_by(content_type: 'test1', filter: { 'name' => 'test4' })

      # assert
      expect(found).to_not be_nil
      expect(found['sys']['id']).to eq('k4')
    end

    it 'filter object can find value in array'
  end

  describe '#find_all' do
    it 'find_all can apply filter query' do
      data =
        1.upto(10).map do |i|
          {
            'sys' => { 'id' => "k#{i}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
            'fields' => { 'name' => { 'en-US' => "test#{i}" } }
          }
        end
      data.each { |d| subject.set(d.dig('sys', 'id'), d) }

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
      data.each { |d| subject.set(d.dig('sys', 'id'), d) }

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
      data.each { |d| subject.set(d.dig('sys', 'id'), d) }

      # act
      found = subject.find_all(content_type: 'test2')
        .apply('name' => { eq: 'test_2_5' })

      # assert
      expect(found.count).to eq(1)
      expect(found.first.dig('sys', 'id')).to eq('k5')
    end
  end
end
