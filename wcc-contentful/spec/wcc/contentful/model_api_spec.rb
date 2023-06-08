# frozen_string_literal: true

require 'rails_helper'
require 'wcc/contentful/model_api'

RSpec.describe WCC::Contentful::ModelAPI do
  let(:store) {
    double('store')
  }

  let(:preview_store) {
    double('preview_store')
  }

  let(:services) {
    double('services',
      store: store,
      preview_store: preview_store,
      instrumentation: ActiveSupport::Notifications)
  }

  before do
    reset_test_namespace!
  end

  context 'when configured' do
    before do
      TestNamespace::Model.configure(services: services) do |config|
        config.schema_file = path_to_fixture('contentful/blog-contentful-schema.json')
      end
    end

    it 'builds classes under namespace' do
      expect(TestNamespace::Model.constants(false).sort).to eq(
        %i[
          Asset
          BlogPost
          Category
          Collection
          MigrationHistory
          PageMetadata
          Property
          PublishingTarget
          SectionBlockText
          SectionPullQuote
          SectionScriptureQuote
          SectionVideoEmbed
          Tag
        ]
      )
    end

    it 'resolves json blobs' do
      # act
      migration = TestNamespace::Model::MigrationHistory.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'migrationHistory'
            }
          },
          'locale' => 'en-US'
        },
        'fields' => {
          'detail' => [
            {
              'intent' => {
                'intents' => [
                  {
                    'meta' => {
                      'callsite' => {
                        'file' =>
                          './jtj-com/db/migrate/20180219160530_test_migration.ts',
                        'line' => 3
                      },
                      'contentTypeInstanceId' => 'contentType/dog/0'
                    },
                    'type' => 'contentType/create',
                    'payload' => {
                      'contentTypeId' => 'dog'
                    }
                  }
                ]
              }
            }
          ]
        }
      })

      # assert
      expect(migration.detail).to be_instance_of(Array)
      expect(migration.detail[0]).to be_instance_of(OpenStruct)
      expect(migration.detail.dig(0, 'intent', 'intents')).to include(
        {
          'meta' => {
            'callsite' => {
              'file' =>
                './jtj-com/db/migrate/20180219160530_test_migration.ts',
              'line' => 3
            },
            'contentTypeInstanceId' => 'contentType/dog/0'
          },
          'type' => 'contentType/create',
          'payload' => {
            'contentTypeId' => 'dog'
          }
        }
      )
    end

    # NOTE: see code comment inside model_builder.rb for why we do not parse DateTime objects
    it 'does not parse date times' do
      # act
      post = TestNamespace::Model::BlogPost.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'blogPost'
            }
          },
          'locale' => 'en-US'
        },
        'fields' => {
          'publishAt' => '2021-01-01'
        }
      })

      # assert
      expect(post.publish_at).to be_a String
      expect(post.publish_at).to eq('2021-01-01')
    end

    it 'resolves linked types' do
      # act
      post = TestNamespace::Model::BlogPost.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'blogPost'
            }
          },
          'locale' => 'en-US'
        },
        'fields' => {
          'sections' => [
            {
              'sys' => {
                'type' => 'Entry',
                'contentType' => {
                  'sys' => {
                    'id' => 'sectionBlockText'
                  }
                },
                'locale' => 'en-US'
              },
              'fields' => {
                'text' => 'Lorem Ipsum Dolor Sit Amet'
              }
            }
          ]
        }
      })

      # assert
      expect(post.sections[0]).to be_instance_of(TestNamespace::Model::SectionBlockText)
      expect(post.sections[0].text).to eq('Lorem Ipsum Dolor Sit Amet')
    end

    it 'inherited class resolves linked types' do
      class MyBlogPost < TestNamespace::Model::BlogPost
      end

      class MyBlockText < TestNamespace::Model::SectionBlockText
      end

      # act
      post = MyBlogPost.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'blogPost'
            }
          },
          'locale' => 'en-US'
        },
        'fields' => {
          'sections' => [
            {
              'sys' => {
                'type' => 'Entry',
                'contentType' => {
                  'sys' => {
                    'id' => 'sectionBlockText'
                  }
                },
                'locale' => 'en-US'
              },
              'fields' => {
                'text' => 'Lorem Ipsum Dolor Sit Amet'
              }
            }
          ]
        }
      })

      # assert
      expect(post.sections[0]).to be_instance_of(MyBlockText)
      expect(post.sections[0].text).to eq('Lorem Ipsum Dolor Sit Amet')
    end

    it 'finds models by ID' do
      allow(store).to receive(:find)
        .with('1234', any_args)
        .and_return({
          'sys' => {
            'id' => '1234',
            'type' => 'Entry',
            'contentType' => {
              'sys' => {
                'id' => 'blogPost'
              }
            },
            'locale' => 'en-US'
          },
          'fields' => {
            'title' => 'Lorem Ipsum'
          }
        })

      # act
      entry = TestNamespace::Model.find('1234')

      # assert
      expect(entry).to be_a(TestNamespace::Model::BlogPost)
      expect(entry.id).to eq('1234')
      expect(entry.title).to eq('Lorem Ipsum')
    end

    it 'finds by ID on derived class' do
      allow(store).to receive(:find)
        .with('1234', anything)
        .and_return({
          'sys' => {
            'id' => '1234',
            'type' => 'Entry',
            'contentType' => {
              'sys' => {
                'id' => 'blogPost'
              }
            },
            'locale' => 'en-US'
          },
          'fields' => {
            'title' => 'Lorem Ipsum'
          }
        })

      # act
      entry = TestNamespace::Model::BlogPost.find('1234')

      # assert
      expect(entry).to be_a(TestNamespace::Model::BlogPost)
      expect(entry.id).to eq('1234')
      expect(entry.title).to eq('Lorem Ipsum')
    end

    it 'finds by ID on subclass' do
      allow(store).to receive(:find)
        .with('1234', anything)
        .and_return({
          'sys' => {
            'id' => '1234',
            'type' => 'Entry',
            'contentType' => {
              'sys' => {
                'id' => 'blogPost'
              }
            },
            'locale' => 'en-US'
          },
          'fields' => {
            'title' => 'Lorem Ipsum'
          }
        })

      # act
      entry = TestNamespace::Model::BlogPost.find('1234')

      # assert
      expect(entry).to be_a(TestNamespace::Model::BlogPost)
      expect(entry.id).to eq('1234')
      expect(entry.title).to eq('Lorem Ipsum')
    end

    it 'instruments find' do
      allow(store).to receive(:find)
      # act
      expect {
        TestNamespace::Model::BlogPost.find('1234')
      }.to instrument('find.model.contentful.wcc')
    end

    it 'subclass instruments find using configured instrumentation' do
      class MyBlogPost2 < TestNamespace::Model::BlogPost
      end

      instrumentation = double
      allow(instrumentation).to receive(:instrument)
      allow(services).to receive(:instrumentation)
        .and_return(instrumentation)

      allow(store).to receive(:find)

      # act
      MyBlogPost2.find('1234')

      expect(instrumentation).to have_received(:instrument)
        .with('find.model.contentful.wcc',
          content_type: 'blogPost', id: '1234', options: {})
    end

    it 'finds all by content type' do
      allow(store).to receive(:find_all)
        .with(content_type: 'blogPost', options: {})
        .and_return([
          {
            'sys' => {
              'id' => '1234',
              'type' => 'Entry',
              'contentType' => {
                'sys' => {
                  'id' => 'blogPost'
                }
              },
              'locale' => 'en-US'
            }
          },
          {
            'sys' => {
              'id' => '5678',
              'type' => 'Entry',
              'contentType' => {
                'sys' => {
                  'id' => 'blogPost'
                }
              },
              'locale' => 'en-US'
            }
          },
          {
            'sys' => {
              'id' => '9012',
              'type' => 'Entry',
              'contentType' => {
                'sys' => {
                  'id' => 'blogPost'
                }
              },
              'locale' => 'en-US'
            }
          }
        ].lazy)

      # act
      posts = TestNamespace::Model::BlogPost.find_all

      # assert
      expect(posts.map(&:id).sort).to eq(
        %w[
          1234
          5678
          9012
        ]
      )
    end

    it 'finds single item with filter' do
      allow(store).to receive(:find_by)
        .with(content_type: 'blogPost', filter: { 'slug' => 'mister_roboto' }, options: {})
        .and_return(
          {
            'sys' => {
              'id' => '1234',
              'type' => 'Entry',
              'contentType' => {
                'sys' => {
                  'id' => 'blogPost'
                }
              },
              'locale' => 'en-US'
            }
          }
        )

      # act
      post = TestNamespace::Model::BlogPost.find_by(slug: 'mister_roboto')

      # assert
      expect(post.id).to eq('1234')
    end

    it 'calls into store to resolve linked types' do
      allow(store).to receive(:find)
        .with('blockText1234', any_args)
        .and_return(
          {
            'sys' => {
              'type' => 'Entry',
              'contentType' => {
                'sys' => {
                  'id' => 'sectionBlockText'
                }
              },
              'locale' => 'en-US'
            },
            'fields' => {
              'text' => 'Lorem Ipsum Dolor Sit Amet'
            }
          }
        )

      # act
      post = TestNamespace::Model::BlogPost.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'blogPost'
            }
          },
          'locale' => 'en-US'
        },
        'fields' => {
          'sections' => [
            {
              'sys' => {
                'type' => 'Link',
                'linkType' => 'Entry',
                'id' => 'blockText1234'
              }
            }
          ]
        }
      })

      # assert
      expect(post.sections[0]).to be_a TestNamespace::Model::SectionBlockText
      expect(post.sections[0].text).to eq('Lorem Ipsum Dolor Sit Amet')
    end

    context 'when options: { preview: true }' do
      it 'find chooses preview_store' do
        expect(store).to_not receive(:find)

        allow(preview_store).to receive(:find)
          .with('1234', any_args)
          .and_return({
            'sys' => {
              'id' => '1234',
              'type' => 'Entry',
              'contentType' => {
                'sys' => {
                  'id' => 'blogPost'
                }
              },
              'locale' => 'en-US'
            },
          'fields' => {
            'title' => 'Lorem Ipsum'
          }
          })

        # act
        entry = TestNamespace::Model.find('1234', options: { preview: true })

        # assert
        expect(entry).to be_a(TestNamespace::Model::BlogPost)
        expect(entry.id).to eq('1234')
        expect(entry.title).to eq('Lorem Ipsum')
      end

      it 'find_by chooses preview_store' do
        expect(store).to_not receive(:find_by)

        allow(preview_store).to receive(:find_by)
          .with(content_type: 'blogPost', filter: { 'slug' => 'mister_roboto' }, options: {})
          .and_return(
            {
              'sys' => {
                'id' => '1234',
                'type' => 'Entry',
                'contentType' => {
                  'sys' => {
                    'id' => 'blogPost'
                  }
                },
                'locale' => 'en-US'
              }
            }
          )

        # act
        post = TestNamespace::Model::BlogPost.find_by(slug: 'mister_roboto', options: { preview: true })

        # assert
        expect(post.id).to eq('1234')
      end

      it 'find_all chooses preview_store' do
        expect(store).to_not receive(:find_all)

        allow(preview_store).to receive(:find_all)
          .with(content_type: 'blogPost', options: {})
          .and_return([
            {
              'sys' => {
                'id' => '1234',
                'type' => 'Entry',
                'contentType' => {
                  'sys' => {
                    'id' => 'blogPost'
                  }
                },
                'locale' => 'en-US'
              }
            },
            {
              'sys' => {
                'id' => '5678',
                'type' => 'Entry',
                'contentType' => {
                  'sys' => {
                    'id' => 'blogPost'
                  }
                },
                'locale' => 'en-US'
              }
            },
            {
              'sys' => {
                'id' => '9012',
                'type' => 'Entry',
                'contentType' => {
                  'sys' => {
                    'id' => 'blogPost'
                  }
                },
                'locale' => 'en-US'
              }
            }
          ].lazy)

        # act
        posts = TestNamespace::Model::BlogPost.find_all(options: { preview: true })

        # assert
        expect(posts.map(&:id).sort).to eq(
          %w[
            1234
            5678
            9012
          ]
        )
      end

      it 'links are resolved using preview store as well' do
        expect(store).to_not receive(:find)

        allow(preview_store).to receive(:find)
          .with('blockText1234', any_args)
          .and_return(
            {
              'sys' => {
                'type' => 'Entry',
                'contentType' => {
                  'sys' => {
                    'id' => 'sectionBlockText'
                  }
                },
                'locale' => 'en-US'
              },
              'fields' => {
                'text' => 'Lorem Ipsum Dolor Sit Amet'
              }
            }
          )
        allow(preview_store).to receive(:find)
          .with('blogPost1', any_args)
          .and_return({
            'sys' => {
              'id' => 'blogPost1',
              'type' => 'Entry',
              'contentType' => {
                'sys' => {
                  'id' => 'blogPost'
                }
              },
              'locale' => 'en-US'
            },
            'fields' => {
              'sections' => [
                {
                  'sys' => {
                    'type' => 'Link',
                    'linkType' => 'Entry',
                    'id' => 'blockText1234'
                  }
                }
              ]
            }
          })

        # act
        post = TestNamespace::Model::BlogPost.find('blogPost1', options: { preview: true })

        # assert
        expect(post.sections[0]).to be_a TestNamespace::Model::SectionBlockText
        expect(post.sections[0].text).to eq('Lorem Ipsum Dolor Sit Amet')
      end
    end

    it 'loads app-defined constant from namespace' do
      allow(store).to receive(:find)
        .and_return({
          'sys' => {
            'id' => '1234',
            'type' => 'Entry',
            'contentType' => {
              'sys' => {
                'id' => 'blogPost'
              }
            },
            'locale' => 'en-US'
          }
        })

      expect(TestNamespace).to receive(:const_get).with('BlogPost') do
        TestNamespace::BlogPost =
          Class.new(TestNamespace::Model::BlogPost) do
          end
      end

      # act
      button = TestNamespace::Model.find('1234')

      # assert
      expect(button).to be_a(TestNamespace::BlogPost)
    ensure
      TestNamespace.send(:remove_const, 'BlogPost')
    end

    it 'falls back to object if not found' do
      allow(store).to receive(:find)
        .and_return({
          'sys' => {
            'id' => '1234',
            'type' => 'Entry',
            'contentType' => {
              'sys' => {
                'id' => 'blogPost'
              }
            },
            'locale' => 'en-US'
          }
        })

      blog_post_class = nil
      allow(Object).to receive(:const_get).and_call_original
      expect(Object).to receive(:const_get).with('BlogPost') do
        blog_post_class =
          Class.new(TestNamespace::Model::BlogPost) do
          end
      end

      # act
      button = TestNamespace::Model.find('1234')

      # assert
      expect(button).to be_a(blog_post_class)
    end

    it 'two different namespaces have two different registries' do
      alternate_schema = WCC::Contentful::IndexedRepresentation.from_json <<~JSON
        {
          "Asset": {
            "fields": {
              "title": {
                "name": "title",
                "type": "String"
              },
              "description": {
                "name": "description",
                "type": "String"
              },
              "file": {
                "name": "file",
                "type": "Json"
              }
            },
            "name": "Asset",
            "content_type": "Asset"
          },
          "blogPost": {
            "fields": {
              "metadata": {
                "name": "metadata",
                "type": "Link",
                "required": false,
                "link_types": [
                  "pageMetadata"
                ]
              }
            },
            "name": "BlogPost",
            "content_type": "blogPost"
          },
          "pageMetadata": {
            "fields": {
              "alt": {
                "name": "alt",
                "type": "String",
                "required": true
              }
            },
            "name": "PageMetadata",
            "content_type": "pageMetadata"
          }
        }
      JSON

      alternate_services = double('services 2',
        store: double('store 2'),
        instrumentation: ActiveSupport::Notifications)

      TestNamespace2::Model.configure(
        schema: alternate_schema,
        services: alternate_services
      )

      # Register a subclass of meta in testnamespace2
      TestNamespace2Meta = Class.new(TestNamespace2::Model::PageMetadata)
      expect(TestNamespace2::Model.registry['pageMetadata']).to eq(TestNamespace2Meta)

      # When we lookup a model from TestNamespace, we should not get a TestNamespace2 class...
      allow(store).to receive(:find)
        .with('blog-post-1', any_args)
        .and_return JSON.parse <<~JSON
          {
            "sys": {
              "id": "blog-post-1",
              "type": "Entry",
              "contentType": {
                "sys": {
                  "type": "Link",
                  "linkType": "ContentType",
                  "id": "blogPost"
                }
              },
              "locale": "en-US"
            },
            "fields": {
              "title": "5 Characteristics Of A Godly Man",
              "metadata": {
                "sys": {
                  "type": "Link",
                  "linkType": "Entry",
                  "id": "metadata-1"
                }
              }
            }
          }
        JSON
      post = TestNamespace::Model::BlogPost.find('blog-post-1')
      expect(post).to be_a(TestNamespace::Model::BlogPost)

      # When we follow the links, it should not get us a TestNamespace2 class...
      allow(store).to receive(:find)
        .with('metadata-1', any_args)
        .and_return JSON.parse <<~JSON
          {
            "sys": {
              "id": "metadata-1",
              "type": "Entry",
              "contentType": {
                "sys": {
                  "type": "Link",
                  "linkType": "ContentType",
                  "id": "pageMetadata"
                }
              },
              "locale": "en-US"
            },
            "fields": {
              "metaDescription": "How do I become a Godly man? Learn five characteristics of a Godly man and learn about how to become the man God created you to be."
            }
          }
        JSON
      expect(post.metadata).to be_a(TestNamespace::Model::PageMetadata)
    end
  end

  describe '.configure' do
    it 'applies custom instrumentation adapter to the whole stack' do
      instrumentation = double('instrumentation')

      TestNamespace::Model.configure do |config|
        config.space = 'test'
        config.schema_file = path_to_fixture('contentful/blog-contentful-schema.json')
        config.instrumentation_adapter = instrumentation
      end

      stub_request(:get, /\/(entries|assets)\/test/)
        .to_return(status: 404)

      events = []
      allow(instrumentation).to receive(:instrument) do |name, _, &block|
        events << name
        block.call
      end

      expect(ActiveSupport::Notifications).to_not receive(:instrument)
      expect(instrumentation).to receive(:instrument)
        .at_least(:once)

      # act
      TestNamespace::Model::BlogPost.find('test')

      expect(events).to eq(
        [
          'find.model.contentful.wcc',
          'find.store.contentful.wcc',
          'entries.simpleclient.contentful.wcc',
          'get_http.simpleclient.contentful.wcc'
        ]
      )
    end

    it 'uses connected rich text renderer in services' do
      my_renderer =
        Class.new(WCC::Contentful::RichTextRenderer) do
          def call
            [configuration, store, model_namespace]
          end
        end

      TestNamespace::Model.configure do |config|
        config.schema_file = path_to_fixture('contentful/blog-contentful-schema.json')
        config.rich_text_renderer = my_renderer
      end

      config, store, ns = TestNamespace::Model.services.rich_text_renderer.call(double('doc'))
      expect(config).to eq(TestNamespace::Model.configuration)
      expect(store).to eq(TestNamespace::Model.services.store)
      expect(ns).to eq(TestNamespace::Model)
    end
  end

  def reset_test_namespace!
    consts = TestNamespace::Model.constants(false).map(&:to_s).uniq
    consts.each do |c|
      TestNamespace::Model.send(:remove_const, c.split(':').last)
    rescue StandardError => e
      warn e
    end
    TestNamespace::Model.instance_variable_get('@registry').clear
    TestNamespace::Model.instance_variable_set('@schema', nil)
    TestNamespace::Model.instance_variable_set('@services', nil)
    TestNamespace::Model.instance_variable_set('@configuration', nil)
  end

  module TestNamespace # rubocop:disable Style/ClassAndModuleChildren
    class Model
      include WCC::Contentful::ModelAPI
    end
  end

  module TestNamespace2 # rubocop:disable Style/ClassAndModuleChildren
    class Model
      include WCC::Contentful::ModelAPI
    end
  end
end
