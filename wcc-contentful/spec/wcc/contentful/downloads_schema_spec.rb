# frozen_string_literal: true

require 'wcc/contentful/downloads_schema'

RSpec.describe WCC::Contentful::DownloadsSchema do
  describe '#call' do
    let(:content_types) {
      [
        {
          'sys' => {
            'space' => {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'Space',
                'id' => '343qxys30lid'
              }
            },
            'id' => 'testimonial',
            'type' => 'ContentType',
            'createdAt' => '2018-02-12T19:47:57.690Z',
            'updatedAt' => '2018-02-12T19:47:57.856Z',
            'createdBy' => {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'User',
                'id' => '0SUbYs2vZlXjVR6bH6o83O'
              }
            },
            'updatedBy' => {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'User',
                'id' => '0SUbYs2vZlXjVR6bH6o83O'
              }
            },
            'publishedCounter' => 1,
            'version' => 2,
            'publishedBy' => {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'User',
                'id' => '0SUbYs2vZlXjVR6bH6o83O'
              }
            },
            'publishedVersion' => 1,
            'firstPublishedAt' => '2018-02-12T19:47:57.856Z',
            'publishedAt' => '2018-02-12T19:47:57.856Z'
          },
          'displayField' => 'name',
          'name' => 'Testimonial',
          'description' => "A Testimonial contains a user's photo...",
          'fields' => [
            {
              'id' => 'name',
              'name' => 'Name',
              'type' => 'Symbol',
              'localized' => false,
              'required' => true,
              'validations' => [],
              'disabled' => false,
              'omitted' => false
            },
            {
              'id' => 'photo',
              'name' => 'Photo',
              'type' => 'Link',
              'localized' => false,
              'required' => true,
              'validations' => [
                {
                  'linkMimetypeGroup' => [
                    'image'
                  ]
                }
              ],
              'disabled' => false,
              'omitted' => false,
              'linkType' => 'Asset'
            }
          ]
        },
        {
          'sys' => {
            'space' => {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'Space',
                'id' => '343qxys30lid'
              }
            },
            'id' => 'menu',
            'type' => 'ContentType',
            'createdAt' => '2018-02-12T17:39:58.461Z',
            'updatedAt' => '2018-02-14T18:33:19.888Z',
            'createdBy' => {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'User',
                'id' => '0SUbYs2vZlXjVR6bH6o83O'
              }
            },
            'updatedBy' => {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'User',
                'id' => '0SUbYs2vZlXjVR6bH6o83O'
              }
            },
            'publishedCounter' => 4,
            'version' => 8,
            'publishedBy' => {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'User',
                'id' => '0SUbYs2vZlXjVR6bH6o83O'
              }
            },
            'publishedVersion' => 7,
            'firstPublishedAt' => '2018-02-12T17:39:58.717Z',
            'publishedAt' => '2018-02-14T18:33:19.888Z'
          },
          'displayField' => 'name',
          'name' => 'Menu',
          'description' => 'A Menu contains...',
          'fields' => [
            {
              'id' => 'name',
              'name' => 'Name',
              'type' => 'Symbol',
              'localized' => false,
              'required' => false,
              'validations' => [],
              'disabled' => false,
              'omitted' => false
            },
            {
              'id' => 'items',
              'name' => 'Items',
              'type' => 'Array',
              'localized' => false,
              'required' => false,
              'validations' => [],
              'disabled' => false,
              'omitted' => false,
              'items' => {
                'type' => 'Link',
                'validations' => [
                  {
                    'linkContentType' => %w[
                      dropdownMenu
                      menuButton
                    ],
                    'message' => 'The Menu groups must contain only sub-Menus or MenuButtons'
                  }
                ],
                'linkType' => 'Entry'
              }
            }
          ]
        }
      ]
    }

    let(:editor_interface) {
      {
        'sys' => {
          'id' => 'default',
          'type' => 'EditorInterface',
          'space' => {
            'sys' => {
              'id' => 'hw5pse7y1ojx',
              'type' => 'Link',
              'linkType' => 'Space'
            }
          },
          'version' => 3,
          'createdAt' => '2018-11-02T19:09:17.171Z',
          'createdBy' => {
            'sys' => {
              'id' => '0SUbYs2vZlXjVR6bH6o83O',
              'type' => 'Link',
              'linkType' => 'User'
            }
          },
          'updatedAt' => '2018-11-07T19:09:26.570Z',
          'updatedBy' => {
            'sys' => {
              'id' => '0SUbYs2vZlXjVR6bH6o83O',
              'type' => 'Link',
              'linkType' => 'User'
            }
          },
          'contentType' => {
            'sys' => {
              'id' => 'page',
              'type' => 'Link',
              'linkType' => 'ContentType'
            }
          },
          'environment' => {
            'sys' => {
              'id' => 'gburgett',
              'type' => 'Link',
              'linkType' => 'Environment'
            }
          }
        },
        'controls' => [
          {
            'fieldId' => 'title',
            'widgetId' => 'singleLine'
          },
          {
            'fieldId' => 'slug',
            'widgetId' => 'singleLine'
          }
        ]
      }
    }

    let(:management_client) {
      client = double(
        content_types: double(
          items: content_types
        )
      )

      allow(client).to receive(:editor_interface) do |content_type_id, _query = {}|
        i = editor_interface.deep_dup
        i['sys']['contentType']['sys']['id'] = content_type_id
        double(raw: i)
      end
      client
    }

    let(:subject) {
      described_class.new(nil, management_client)
    }

    it 'creates directory' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          subject.call

          expect(File.exist?('db')).to be true
        end
      end
    end

    it 'writes file with proper formatting' do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          subject.call

          expect(File.read('db/contentful-schema.json'))
            .to eq(load_fixture('contentful/contentful-schema.json'))
        end
      end
    end
  end
end
