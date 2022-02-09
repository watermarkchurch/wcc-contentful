# frozen_string_literal: true

RSpec.shared_examples 'supports :ne operator' do
  [
    [String, proc { "test#{rand(1..100_000)}" }],
    [Integer, proc { rand(-4_611_686_018_427_387_903..4_611_686_018_427_387_903) }],
    [Float, proc { rand }]
  ].each do |(type, generator)|
    context "with #{type} value" do
      let(:specified_value) {
        generator.call
      }

      let(:desired) {
        # desired entry doesn't have the specified_value
        {
          'sys' => { 'id' => "k#{rand}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
          'fields' => { type.to_s => { 'en-US' => 1.upto(rand(2..5)).map { generator.call } } }
        }
      }

      let(:data) {
        1.upto(3).map do |i|
          random_values = 1.upto(rand(2..5)).map { generator.call }

          # remaining data does include the specified_value
          {
            'sys' => {
              'id' => "k#{i}",
              'contentType' => { 'sys' => { 'id' => 'test1' } }
            },
            'fields' => { type.to_s => { 'en-US' => [*random_values, specified_value].shuffle } }
          }
        end
      }

      it 'find_by can apply filter object' do
        specified_value = generator.call
        data = {
          'sys' => { 'id' => "k#{rand}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
          'fields' => { type.to_s => { 'en-US' => specified_value } }
        }

        subject.set(data.dig('sys', 'id'), data)

        # act
        found = subject.find_by(content_type: 'test1', filter: { type.to_s => { ne: specified_value } })

        # assert
        expect(found).to be_nil
      end

      it 'find_by can find value in array' do
        [*data, desired].shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'test1', filter: { type.to_s => { ne: specified_value } })

        # assert
        expect(found).to_not be_nil
        expect(found).to eq(desired)
      end

      it 'find_all can apply operator' do
        [*data, desired].shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_all(content_type: 'test1')
          .ne(type.to_s, specified_value)

        # assert
        expect(found.count).to eq(1)
        expect(found.first).to eq(desired)
      end
    end
  end
end
