# frozen_string_literal: true

RSpec.describe WCC::Contentful::ModelMethods do
  let(:typedef) {
    WCC::Contentful::IndexedRepresentation::ContentType.new({
      name: 'ToJsonTest',
      content_type: 'toJsonTest',
      fields: {
        'name' => {
          name: 'name',
          type: :String
        },
        'blob' => {
          name: 'blob',
          type: :Json
        },
        'someLink' => {
          name: 'someLink',
          type: :Link
        },
        'items' => {
          name: 'items',
          array: true,
          type: :Link
        }
      }
    })
  }

  let(:raw) {
    {
      'sys' => {
        'space' => {
          'sys' => {
            'type' => 'Link',
            'linkType' => 'Space',
            'id' => '343qxys30lid'
          }
        },
        'id' => '1',
        'type' => 'Entry',
        'createdAt' => '2018-02-13T22:54:35.359Z',
        'updatedAt' => '2018-02-23T21:07:54.897Z',
        'revision' => 3,
        'contentType' => {
          'sys' => {
            'type' => 'Link',
            'linkType' => 'ContentType',
            'id' => 'toJsonTest'
          }
        }
      },
      'fields' => {
        'name' => {
          'en-US' => 'asdf'
        },
        'blob' => {
          'en-US' => {
            'some' => { 'data' => 3 }
          }
        },
        'someLink' => {
          'en-US' => {
            'sys' => {
              'type' => 'Link',
              'linkType' => 'Entry',
              'id' => '2'
            }
          }
        },
        'items' => {
          'en-US' => [
            {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'Entry',
                'id' => '3'
              }
            },
            {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'Asset',
                'id' => '4'
              }
            }
          ]
        }
      }
    }
  }

  subject {
    WCC::Contentful::Model::ToJsonTest.new(raw)
  }

  before do
    builder = WCC::Contentful::ModelBuilder.new({ 'toJsonTest' => typedef })
    builder.build_models
  end

  describe '#resolve' do
    it 'raises argument error for depth 0' do
      expect {
        subject.resolve(depth: 0)
      }.to raise_error(ArgumentError)
    end

    it 'resolves links for depth 1' do
      fake2 = double
      allow(WCC::Contentful::Model).to receive(:find)
        .with('2').once
        .and_return(fake2)
      allow(WCC::Contentful::Model).to receive(:find)
        .with('3').once
        .and_return(nil)
      fake4 = double
      allow(WCC::Contentful::Model).to receive(:find)
        .with('4').once
        .and_return(fake4)

      # act
      subject.resolve

      # assert
      expect(WCC::Contentful::Model).to have_received(:find)
        .with('2')
      expect(WCC::Contentful::Model).to have_received(:find)
        .with('3')
      expect(WCC::Contentful::Model).to have_received(:find)
        .with('4')

      expect(subject.some_link).to eq(fake2)
      expect(subject.items).to eq([nil, fake4])
    end

    it 'recursively resolves links for further depth' do
      fake2 = double(
        resolve: nil
      )
      allow(WCC::Contentful::Model).to receive(:find)
        .with('2').once
        .and_return(fake2)

      # act
      subject.resolve(depth: 2, fields: [:some_link])

      # assert
      expect(WCC::Contentful::Model).to have_received(:find)
        .with('2')
      expect(fake2).to have_received(:resolve)
        .with(depth: 1, context: { '1' => subject, '2' => fake2 })
    end

    it 'stops when it hits a circular reference' do
      raw3 = raw.deep_dup
      raw3['sys']['id'] = '3'
      # circular back to 1
      raw3['fields']['items']['en-US'][0] = { 'sys' => { 'id' => '1' } }
      test3 = WCC::Contentful::Model::ToJsonTest.new(raw3)

      expect(WCC::Contentful::Model).to receive(:find)
        .with('2').once
        .and_return(nil)
      expect(WCC::Contentful::Model).to receive(:find)
        .with('3').once
        .and_return(test3)
      expect(WCC::Contentful::Model).to receive(:find)
        .with('4').once
        .and_return(double(resolve: nil))

      # act
      subject.resolve(depth: 99)

      # assert
      expect(subject.items[0]).to equal(test3)
      expect(test3.items[0]).to equal(subject)
    end

    it 'instantiates a model class for an already resolved raw value' do
      expect(WCC::Contentful::Model).to_not receive(:find)

      raw2 = {
        'sys' => {
          'id' => '2',
          'type' => 'Entry',
          'contentType' => { 'sys' => { 'id' => 'toJsonTest' } }
        },
        'fields' => {
          'name' => {
            'en-US' => 'raw2'
          }
        }
      }
      raw3 = {
        'sys' => {
          'id' => '3',
          'type' => 'Entry',
          'contentType' => { 'sys' => { 'id' => 'toJsonTest' } }
        },
        'fields' => {
          'name' => {
            'en-US' => 'raw3'
          }
        }
      }

      raw['fields']['someLink']['en-US'] = raw2
      raw['fields']['items']['en-US'] = [raw3, nil]

      # act
      subject.resolve(depth: 2, fields: [:some_link])

      # assert
      expect(subject.some_link.name).to eq('raw2')
      expect(subject.items[0].name).to eq('raw3')
      expect(subject.items[1]).to be_nil
    end
  end

  describe '#to_json' do
    it 'writes sys' do
      # act
      json = JSON.parse(subject.to_json)

      # assert
      expect(json['sys']).to eq({
        'space' => {
          'sys' => {
            'type' => 'Link',
            'linkType' => 'Space',
            'id' => '343qxys30lid'
          }
        },
          'id' => '1',
          'type' => 'Entry',
          'createdAt' => '2018-02-13T22:54:35.359Z',
          'updatedAt' => '2018-02-23T21:07:54.897Z',
          'revision' => 3,
          'contentType' => {
            'sys' => {
              'type' => 'Link',
              'linkType' => 'ContentType',
              'id' => 'toJsonTest'
            }
          },
          'locale' => 'en-US'
      })
    end

    it 'writes unresolved fields' do
      # act
      json = JSON.parse(subject.to_json)

      # assert
      expect(json.dig('fields', 'name')).to eq('asdf')
      expect(json.dig('fields', 'blob')).to eq('some' => { 'data' => 3 })
      expect(json.dig('fields', 'someLink')).to eq({
        'sys' => {
          'type' => 'Link',
          'linkType' => 'Entry',
          'id' => '2'
        }
      })
      expect(json.dig('fields', 'items')).to eq(
        [
          {
            'sys' => {
              'type' => 'Link',
              'linkType' => 'Entry',
              'id' => '3'
            }
          },
          {
            'sys' => {
              'type' => 'Link',
              'linkType' => 'Asset',
              'id' => '4'
            }
          }
        ]
      )
    end

    it 'writes resolved links' do
      fake2 = double({ to_h: { 'sys' => { 'type' => 'double', 'id' => 'fake2' } } })
      allow(WCC::Contentful::Model).to receive(:find)
        .with('2').once
        .and_return(fake2)
      allow(WCC::Contentful::Model).to receive(:find)
        .with('3').once
        .and_return(nil)
      fake4 = double({ to_h: { 'sys' => { 'type' => 'double', 'id' => 'fake4' } } })
      allow(WCC::Contentful::Model).to receive(:find)
        .with('4').once
        .and_return(fake4)

      subject.resolve

      # act
      json = JSON.parse(subject.to_json)

      # assert
      expect(json.dig('fields', 'someLink')).to eq({
        'sys' => {
          'type' => 'double',
          'id' => 'fake2'
        }
      })
      expect(json.dig('fields', 'items')).to eq(
        [
          nil,
          {
            'sys' => {
              'type' => 'double',
              'id' => 'fake4'
            }
          }
        ]
      )
    end

    it 'raises circular reference exception' do
      raw3 = raw.deep_dup
      raw3['sys']['id'] = '3'
      # circular back to 1
      raw3['fields']['items']['en-US'][0] = { 'sys' => { 'id' => '1' } }
      test3 = WCC::Contentful::Model::ToJsonTest.new(raw3)

      expect(WCC::Contentful::Model).to receive(:find)
        .with('2').once
        .and_return(nil)
      expect(WCC::Contentful::Model).to receive(:find)
        .with('3').once
        .and_return(test3)
      expect(WCC::Contentful::Model).to receive(:find)
        .with('4').once
        .and_return(double(resolve: nil))

      subject.resolve(depth: 99)

      # act
      expect {
        subject.to_json
      }.to raise_error(WCC::Contentful::CircularReferenceError)
    end
  end
end
