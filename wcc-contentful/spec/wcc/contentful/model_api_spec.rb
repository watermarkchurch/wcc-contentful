# frozen_string_literal: true

require 'wcc/contentful/model_api'

RSpec.describe WCC::Contentful::ModelAPI do
  let(:store) {
    double('store')
  }

  let(:services) {
    double('services', store: store, instrumentation: ActiveSupport::Notifications)
  }

  before do
    reset_test_namespace!
  end

  context 'when configured' do
    before do
      TestNamespace.configure(services: services) do |config|
        config.schema_file = path_to_fixture('contentful/blog-contentful-schema.json')
      end
    end

    it 'builds classes under namespace' do
      expect(TestNamespace.constants(false).sort).to eq(
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
      migration = TestNamespace::MigrationHistory.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'migrationHistory'
            }
          }
        },
        'fields' => {
          'detail' => {
            'en-US' => [
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

    # Note: see code comment inside model_builder.rb for why we do not parse DateTime objects
    it 'does not parse date times' do
      # act
      post = TestNamespace::BlogPost.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'blogPost'
            }
          }
        },
        'fields' => {
          'publishAt' => {
            'en-US' => '2021-01-01'
          }
        }
      })

      # assert
      expect(post.publish_at).to be_a String
      expect(post.publish_at).to eq('2021-01-01')
    end

    it 'resolves linked types' do
      # act
      post = TestNamespace::BlogPost.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'blogPost'
            }
          }
        },
        'fields' => {
          'sections' => {
            'en-US' => [
              {
                'sys' => {
                  'type' => 'Entry',
                  'contentType' => {
                    'sys' => {
                      'id' => 'sectionBlockText'
                    }
                  }
                },
                'fields' => {
                  'text' => {
                    'en-US' => 'Lorem Ipsum Dolor Sit Amet'
                  }
                }
              }
            ]
          }
        }
      })

      # assert
      expect(post.sections[0]).to be_instance_of(TestNamespace::SectionBlockText)
      expect(post.sections[0].text).to eq('Lorem Ipsum Dolor Sit Amet')
    end

    it 'inherited class resolves linked types' do
      class MyBlogPost < TestNamespace::BlogPost
      end

      class MyBlockText < TestNamespace::SectionBlockText
      end

      # act
      post = MyBlogPost.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'blogPost'
            }
          }
        },
        'fields' => {
          'sections' => {
            'en-US' => [
              {
                'sys' => {
                  'type' => 'Entry',
                  'contentType' => {
                    'sys' => {
                      'id' => 'sectionBlockText'
                    }
                  }
                },
                'fields' => {
                  'text' => {
                    'en-US' => 'Lorem Ipsum Dolor Sit Amet'
                  }
                }
              }
            ]
          }
        }
      })

      # assert
      expect(post.sections[0]).to be_instance_of(MyBlockText)
      expect(post.sections[0].text).to eq('Lorem Ipsum Dolor Sit Amet')
    end

    it 'finds models by ID' do
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
            }
          },
          'fields' => {
            'title' => {
              'en-US' => 'Lorem Ipsum'
            }
          }
        })

      # act
      entry = TestNamespace.find('1234')

      # assert
      expect(entry).to be_a(TestNamespace::BlogPost)
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
            }
          },
          'fields' => {
            'title' => {
              'en-US' => 'Lorem Ipsum'
            }
          }
        })

      # act
      entry = TestNamespace::BlogPost.find('1234')

      # assert
      expect(entry).to be_a(TestNamespace::BlogPost)
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
            }
          },
          'fields' => {
            'title' => {
              'en-US' => 'Lorem Ipsum'
            }
          }
        })

      # act
      entry = TestNamespace::BlogPost.find('1234')

      # assert
      expect(entry).to be_a(TestNamespace::BlogPost)
      expect(entry.id).to eq('1234')
      expect(entry.title).to eq('Lorem Ipsum')
    end

    it 'instruments find' do
      allow(store).to receive(:find)
      # act
      expect {
        TestNamespace::BlogPost.find('1234')
      }.to instrument('find.model.contentful.wcc')
    end

    it 'subclass instruments find using configured instrumentation' do
      class MyBlogPost2 < TestNamespace::BlogPost
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
              }
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
              }
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
              }
            }
          }
        ].lazy)

      # act
      posts = TestNamespace::BlogPost.find_all

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
              }
            }
          }
        )

      # act
      post = TestNamespace::BlogPost.find_by(slug: 'mister_roboto')

      # assert
      expect(post.id).to eq('1234')
    end

    it 'calls into store to resolve linked types' do
      allow(store).to receive(:find)
        .with('blockText1234', anything)
        .and_return(
          {
            'sys' => {
              'type' => 'Entry',
              'contentType' => {
                'sys' => {
                  'id' => 'sectionBlockText'
                }
              }
            },
            'fields' => {
              'text' => {
                'en-US' => 'Lorem Ipsum Dolor Sit Amet'
              }
            }
          }
        )

      # act
      post = TestNamespace::BlogPost.new({
        'sys' => {
          'type' => 'Entry',
          'contentType' => {
            'sys' => {
              'id' => 'blogPost'
            }
          }
        },
        'fields' => {
          'sections' => {
            'en-US' => [
              {
                'sys' => {
                  'type' => 'Link',
                  'linkType' => 'Entry',
                  'id' => 'blockText1234'
                }
              }
            ]
          }
        }
      })

      # assert
      expect(post.sections[0]).to be_a TestNamespace::SectionBlockText
      expect(post.sections[0].text).to eq('Lorem Ipsum Dolor Sit Amet')
    end
  end

  describe '.configure' do
    it 'applies custom instrumentation adapter to the whole stack', focus: true do
      instrumentation = double('instrumentation')

      TestNamespace.configure do |config|
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
      TestNamespace::BlogPost.find('test')

      expect(events).to eq(
        [
          'find.model.contentful.wcc',
          'find.store.contentful.wcc',
          'entries.simpleclient.contentful.wcc',
          'get_http.simpleclient.contentful.wcc'
        ]
      )
    end
  end

  def reset_test_namespace!
    consts = TestNamespace.constants(false).map(&:to_s).uniq
    consts.each do |c|
      begin
        TestNamespace.send(:remove_const, c.split(':').last)
      rescue StandardError => e
        warn e
      end
    end
    TestNamespace.class_variable_get('@@registry').clear
    TestNamespace.instance_variable_set('@schema', nil)
    TestNamespace.instance_variable_set('@services', nil)
    TestNamespace.instance_variable_set('@configuration', nil)
  end

  class TestNamespace
    include WCC::Contentful::ModelAPI
  end
end
