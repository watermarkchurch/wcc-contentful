# frozen_string_literal: true

RSpec.describe WCC::Contentful::ModelMethods do
  describe '#resolve' do
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
      builder = WCC::Contentful::ModelBuilder.new({ 'toJsonTest' => typedef })
      builder.build_models
      WCC::Contentful::Model::ToJsonTest.new(raw)
    }

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
        .with({ depth: 1, '1' => subject })
    end

    it 'stops when it hits a circular reference' do
    end
  end
end
