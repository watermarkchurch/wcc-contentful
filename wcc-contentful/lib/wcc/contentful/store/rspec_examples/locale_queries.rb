# frozen_string_literal: true

RSpec.shared_examples 'supports locales in queries' do |feature_set|
  describe 'supports query options: { locale: ... }' do
    before { skip('querying alternate locales not supported') } if feature_set == false

    generator = proc { "test#{rand(1..10_000)}" }

    let(:desired_value) {
      generator.call
    }

    let(:data) {
      1.upto(3).map do |i|
        {
          'sys' => { 'id' => "k#{i}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
          'fields' => {
            'slug' => {
              'en-US' => generator.call,
              'es-ES' => generator.call
            }
          }
        }
      end
    }

    let(:desired) {
      {
        'sys' => { 'id' => "k#{rand}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
        'fields' => {
          'slug' => {
            'en-US' => generator.call,
            'es-ES' => desired_value
          }
        }
      }
    }

    context 'when localized value exists' do
      it 'find_by can apply filter object' do
        [*data, desired].shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'test1',
          filter: { 'slug' => desired_value },
          options: { locale: 'es-ES' })

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
              'fields' => {
                'slug' => {
                  'en-US' => [generator.call, generator.call],
                  'es-ES' => [generator.call, generator.call]
                }
              }
            }
          end

        desired_value = generator.call
        desired = {
          'sys' => { 'id' => "k#{rand}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
          'fields' => {
            'slug' => {
              'en-US' => [generator.call, generator.call],
              'es-ES' => [generator.call, desired_value]
            }
          }
        }

        data << desired
        data.shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'test1',
          filter: { 'slug' => { eq: desired_value } },
          options: { locale: 'es-ES' })

        # assert
        expect(found).to_not be_nil
        expect(found).to eq(desired)
      end

      it 'find_all can apply operator' do
        desired =
          4.upto(5).map do |i|
            {
              'sys' => { 'id' => "d#{i}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
              'fields' => {
                'slug' => {
                  'en-US' => generator.call,
                  'es-ES' => desired_value
                }
              }
            }
          end

        [*data, *desired].shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_all(content_type: 'test1', options: { locale: 'es-ES' })
          .eq('slug', desired_value)

        # assert
        expect(found.count).to eq(2)
        sorted = found.to_a.sort_by { |item| item.dig('sys', 'id') }
        expect(sorted).to eq(desired)
      end
    end

    context 'using fallback locales' do
      before { pending('querying alternate locales not yet implemented') } if feature_set&.to_s == 'pending'

      before do
        allow(configuration).to receive(:locale_fallbacks)
          .and_return({
            'es-MX' => 'es-ES',
            'es-ES' => 'en-US'
          })
      end

      it 'find_by can apply filter object' do
        [*data, desired].shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'test1',
          filter: { 'slug' => desired_value },
          options: { locale: 'es-MX' })

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
              'fields' => {
                'slug' => {
                  'en-US' => [generator.call, generator.call],
                  'es-ES' => [generator.call, generator.call]
                }
              }
            }
          end

        desired_value = generator.call
        desired = {
          'sys' => { 'id' => "k#{rand}", 'contentType' => { 'sys' => { 'id' => 'test1' } } },
          'fields' => {
            'slug' => {
              'en-US' => [generator.call, generator.call],
              'es-ES' => [generator.call, desired_value]
            }
          }
        }

        data << desired
        data.shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'test1',
          filter: { 'slug' => { eq: desired_value } },
          options: { locale: 'es-MX' })

        # assert
        expect(found).to_not be_nil
        expect(found).to eq(desired)
      end

      it 'find_all can apply operator' do
        desired = [
          {
            'sys' => { 'id' => 'd1', 'contentType' => { 'sys' => { 'id' => 'test1' } } },
            'fields' => {
              'slug' => {
                'en-US' => generator.call,
                'es-ES' => desired_value
              }
            }
          },
          {
            'sys' => { 'id' => 'd2', 'contentType' => { 'sys' => { 'id' => 'test1' } } },
            'fields' => {
              'slug' => {
                'en-US' => desired_value
              }
            }
          }
        ]

        [*data, *desired].shuffle.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_all(content_type: 'test1', options: { locale: 'es-MX' })
          .eq('slug', desired_value)

        # assert
        expect(found.count).to eq(2)
        sorted = found.to_a.sort_by { |item| item.dig('sys', 'id') }
        expect(sorted).to eq(desired)
      end
    end
  end
end
