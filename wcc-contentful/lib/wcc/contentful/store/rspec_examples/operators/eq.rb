# frozen_string_literal: true

RSpec.shared_examples 'supports :eq operator' do
  [
    [String, proc { "test#{rand(1..10_000)}" }],
    [Integer, proc { rand(-4_611_686_018_427_387_903..4_611_686_018_427_387_903) }],
    [Float, proc { rand }]
  ].each do |(type, generator)|
    context "with #{type} value" do
      it 'find_by can apply filter object' do
        data =
          1.upto(3).map do |i|
            {
              'sys' => { 'id' => "k#{i}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
              'fields' => { type.to_s => { 'en-US' => generator.call } }
            }
          end

        desired_value = generator.call
        desired = {
          'sys' => { 'id' => "k#{rand}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
          'fields' => { type.to_s => { 'en-US' => desired_value } }
        }

        data << desired
        data.shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'test1', filter: { type.to_s => desired_value })

        # assert
        expect(found).to_not be_nil
        expect(found).to eq(desired)
      end

      it 'find_by can find value in array' do
        data =
          1.upto(3).map do |i|
            {
              'sys' => {
                'id' => "k#{i}",
                'contentType' => { 'sys' => { 'id' => 'test1' } }
              },
              'fields' => { 'name' => { 'en-US' => [generator.call, generator.call] } }
            }
          end

        desired_value = generator.call
        desired = {
          'sys' => { 'id' => "k#{rand}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
          'fields' => { type.to_s => { 'en-US' => [generator.call, desired_value].shuffle } }
        }

        data << desired
        data.shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'test1', filter: { type.to_s => { eq: desired_value } })

        # assert
        expect(found).to_not be_nil
        expect(found).to eq(desired)
      end

      it 'find_all can apply operator' do
        data =
          1.upto(3).map do |i|
            {
              'sys' => { 'id' => "k#{i}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
              'fields' => { type.to_s => { 'en-US' => generator.call } }
            }
          end

        desired_value = generator.call
        desired =
          4.upto(5).map do |i|
            {
              'sys' => { 'id' => "k#{i}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
              'fields' => { type.to_s => { 'en-US' => desired_value } }
            }
          end

        data += desired
        data.shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_all(content_type: 'test1')
          .eq(type.to_s, desired_value)

        # assert
        expect(found.count).to eq(2)
        sorted = found.to_a.sort_by { |item| item.dig('sys', 'id') }
        expect(sorted).to eq(desired)
      end
    end
  end
end
