# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::Middleware::Store do
  let(:next_store) { double }
  let(:implementation) {
    Class.new do
      include WCC::Contentful::Middleware::Store
    end
  }

  subject(:instance) {
    implementation.new.tap { |i| i.store = next_store }
  }

  before do
    allow(WCC::Contentful).to receive(:types)
      .and_return({
        'test1' => double(fields: {
          'exclude' => double(name: 'name', type: :Boolean, array: false),
          'link' => double(name: 'link', type: :Link, array: false),
          'links' => double(name: 'links', type: :Link, array: true)
        })
      })
  end

  %i[
    index
    index?
  ].each do |method|
    it "delegates #{method} to backing store" do
      expect(next_store).to receive(method)

      subject.public_send(method)
    end
  end

  it 'delegates Enumerable methods to lazy enum' do
    sys_arr = [sys, sys, sys]
    entries = [
      {
        'sys' => sys_arr[0],
        'fields' => {
          'a' => 1
        }
      }, {
        'sys' => sys_arr[1],
        'fields' => {
          'a' => 2
        }
      }, {
        'sys' => sys_arr[2],
        'fields' => {
          'a' => 3
        }
      }
    ]
    enum =
      Enumerator.new do |y|
        y << entries.shift until entries.empty?
      end
    enum = enum.lazy

    allow(next_store).to receive(:find_all)
      .and_return(double('lazy query', to_enum: enum))

    result = instance.find_all

    result = result.take(2).to_a
    # critical - did it not iterate the third time?
    expect(entries).to eq([
                            {
                              'sys' => sys_arr[2],
                              'fields' => {
                                'a' => 3
                              }
                            }
                          ])
    expect(result.length).to eq(2)
  end

  it 'delegates Count to query not to enum' do
    query = double('lazy query')
    expect(query).to receive(:count)
      .and_return(512)

    allow(next_store).to receive(:find_all)
      .and_return(query)

    result = instance.find_all

    expect(result.count).to eq(512)
  end

  context 'has select?' do
    let(:implementation) {
      Class.new do
        include WCC::Contentful::Middleware::Store

        def select?(entry, _options)
          entry.dig('fields', 'exclude', 'en-US') != true
        end
      end
    }

    describe '#find' do
      it 'returns entry that matches select?' do
        entry = {
          'sys' => sys,
          'fields' => {
            'exclude' => nil
          }
        }
        expect(next_store).to receive(:find)
          .with('1234', **{})
          .and_return(entry)

        # act
        found = instance.find('1234')

        expect(found).to eq(entry)
      end

      it 'returns nil for entry that doesnt match select?' do
        entry = {
          'sys' => sys,
          'fields' => {
            'exclude' => { 'en-US' => true }
          }
        }
        expect(next_store).to receive(:find)
          .with('1234', **{})
          .and_return(entry)

        # act
        found = instance.find('1234')

        expect(found).to be nil
      end

      it 'passes hint options through' do
        entry = {
          'sys' => sys,
          'fields' => {
            'exclude' => { 'en-US' => true }
          }
        }
        expect(next_store).to receive(:find)
          .with('1234', { hint: 'test', option2: 'test2' })
          .and_return(entry)

        # act
        instance.find('1234', hint: 'test', option2: 'test2')
      end
    end

    describe '#find_by' do
      it 'returns entry that matches select?' do
        entry = {
          'sys' => sys,
          'fields' => {
            'exclude' => nil
          }
        }
        expect(next_store).to receive(:find_by)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: {})
          .and_return(entry)

        # act
        found = instance.find_by(content_type: 'test', filter: { 'sys.id' => '1234' })

        expect(found).to eq(entry)
      end

      it 'returns nil for entry that doesnt match select?' do
        entry = {
          'fields' => {
            'exclude' => { 'en-US' => true }
          }
        }
        expect(next_store).to receive(:find_by)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: {})
          .and_return(entry)

        # act
        found = instance.find_by(content_type: 'test', filter: { 'sys.id' => '1234' })

        expect(found).to be nil
      end

      it 'resolves as broken link for linked entry that doesnt match select?' do
        entry = {
          'sys' => sys,
          'fields' => {
            'link' => {
              'en-US' => {
                'sys' => {
                  'id' => '5678',
                  'type' => 'Entry',
                  'contentType' => content_type
                },
                'fields' => {
                  'exclude' => { 'en-US' => true }
                }
              }
            }
          }
        }
        expect(next_store).to receive(:find_by)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: { include: 1 })
          .and_return(entry)

        # act
        found = instance.find_by(content_type: 'test',
          filter: { 'sys.id' => '1234' },
          options: { include: 1 })

        expect(found).to eq({
          'sys' => entry['sys'],
          'fields' => {
            'link' => {
              'en-US' => {
                'sys' => {
                  'id' => '5678',
                  'type' => 'Link',
                  'linkType' => 'Entry'
                }
              }
            }
          }
        })
      end
    end

    describe '#find_all' do
      it 'returns only entries that matches select?' do
        entries = [
          {
            'sys' => sys,
            'fields' => {
              'exclude' => nil
            }
          }, {
            'sys' => sys,
            'fields' => {
              'exclude' => { 'en-US' => true }
            }
          }, {
            'sys' => sys,
            'fields' => {
              'exclude' => { 'en-US' => false }
            }
          }
        ]
        expect(next_store).to receive(:find_all)
          .with(content_type: 'test', filter: { 'test' => 'ok' }, options: {})
          .and_return(entries)

        # act
        found = instance.find_all(content_type: 'test', filter: { 'test' => 'ok' })

        expect(found.to_a).to eq([
                                   entries[0],
                                   entries[2]
                                 ])
      end

      it 'resolves as broken link for linked entry that doesnt match select?' do
        entries = [
          {
            'sys' => sys,
            'fields' => {
              'link' => {
                'en-US' => {
                  'sys' => {
                    'id' => '5678',
                    'type' => 'Entry',
                    'contentType' => content_type
                  },
                  'fields' => {
                    'exclude' => { 'en-US' => true }
                  }
                }
              }
            }
          }
        ]
        expect(next_store).to receive(:find_all)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: { include: 1 })
          .and_return(entries)

        # act
        found = instance.find_all(content_type: 'test',
          filter: { 'sys.id' => '1234' },
          options: { include: 1 })

        expect(found.to_a).to eq([
                                   {
                                     'sys' => entries.dig(0, 'sys'),
                                     'fields' => {
                                       'link' => {
                                         'en-US' => {
                                           'sys' => {
                                             'id' => '5678',
                                             'type' => 'Link',
                                             'linkType' => 'Entry'
                                           }
                                         }
                                       }
                                     }
                                   }
                                 ])
      end

      it 'can apply filter' do
        entries = [
          {
            'sys' => sys,
            'fields' => {
              'exclude' => nil
            }
          }, {
            'sys' => sys,
            'fields' => {
              'exclude' => { 'en-US' => true }
            }
          }, {
            'sys' => sys,
            'fields' => {
              'exclude' => { 'en-US' => false }
            }
          }
        ]
        query_double = double('query')
        expect(next_store).to receive(:find_all)
          .with(content_type: 'test', options: {})
          .and_return(query_double)

        expect(query_double).to receive(:apply)
          .with({ 'test' => 'ok' }, any_args)
          .and_return(query_double)
        allow(query_double).to receive(:to_enum)
          .and_return(entries)

        # act
        query = instance.find_all(content_type: 'test')
        query.apply({ 'test' => 'ok' })
        found = query.to_a

        expect(found).to eq([
                              entries[0],
                              entries[2]
                            ])
        expect(found.count).to eq(2)
      end

      it 'Does not delegate count to the query b/c it has to go through #select' do
        query = double('lazy query')
        expect(query).to_not receive(:count)

        allow(next_store).to receive(:find_all)
          .and_return(query)

        result = instance.find_all

        expect {
          result.count
        }.to raise_error(NameError)
      end
    end
  end

  context 'has transform' do
    let(:implementation) {
      Class.new do
        include WCC::Contentful::Middleware::Store

        def transform(entry, _options)
          entry['fields']['excluded'] = { 'en-US' => 'no' }
          entry
        end
      end
    }

    describe '#find' do
      it 'transforms the entry' do
        entry = {
          'sys' => sys,
          'fields' => {
            'exclude' => nil
          }
        }
        expect(next_store).to receive(:find)
          .with('1234', **{})
          .and_return(entry)

        # act
        found = instance.find('1234')

        expect(found.dig('fields', 'excluded', 'en-US')).to eq 'no'
      end
    end

    describe '#find_by' do
      it 'transforms the entry' do
        entry = {
          'sys' => sys,
          'fields' => {
            'exclude' => nil
          }
        }
        expect(next_store).to receive(:find_by)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: {})
          .and_return(entry)

        # act
        found = instance.find_by(content_type: 'test', filter: { 'sys.id' => '1234' })

        expect(found.dig('fields', 'excluded', 'en-US')).to eq 'no'
      end

      it 'transforms the entry even in a resolved include' do
        entry = {
          'sys' => sys,
          'fields' => {
            'link' => {
              'en-US' => {
                'sys' => {
                  'id' => '5678',
                  'type' => 'Entry',
                  'contentType' => content_type
                },
                'fields' => {
                  'exclude' => { 'en-US' => true }
                }
              }
            }
          }
        }
        expect(next_store).to receive(:find_by)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: { include: 1 })
          .and_return(entry)

        # act
        found = instance.find_by(content_type: 'test',
          filter: { 'sys.id' => '1234' },
          options: { include: 1 })

        expect(found.dig('fields', 'link', 'en-US', 'fields', 'excluded', 'en-US'))
          .to eq 'no'
      end
    end

    describe '#find_all' do
      it 'transforms all entries' do
        entries = [
          {
            'sys' => sys,
            'fields' => {
              'exclude' => nil
            }
          }, {
            'sys' => sys,
            'fields' => {
              'exclude' => { 'en-US' => true }
            }
          }, {
            'sys' => sys,
            'fields' => {
              'exclude' => { 'en-US' => false }
            }
          }
        ]
        expect(next_store).to receive(:find_all)
          .with(content_type: 'test', filter: { 'test' => 'ok' }, options: {})
          .and_return(entries)

        # act
        found = instance.find_all(content_type: 'test', filter: { 'test' => 'ok' })

        found.to_a.each do |entry|
          expect(entry.dig('fields', 'excluded', 'en-US')).to eq 'no'
        end
      end

      it 'transforms resolved entries too' do
        entries = [
          {
            'sys' => sys,
            'fields' => {
              'link' => {
                'en-US' => {
                  'sys' => {
                    'id' => '5678',
                    'type' => 'Entry',
                    'contentType' => content_type
                  },
                  'fields' => {
                    'exclude' => { 'en-US' => true }
                  }
                }
              }
            }
          }
        ]
        expect(next_store).to receive(:find_all)
          .with(content_type: 'test', filter: { 'sys.id' => '1234' }, options: { include: 1 })
          .and_return(entries)

        # act
        found = instance.find_all(content_type: 'test',
          filter: { 'sys.id' => '1234' },
          options: { include: 1 })

        expect(found.to_a[0].dig('fields', 'link', 'en-US', 'fields', 'excluded', 'en-US'))
          .to eq 'no'
      end
    end
  end

  def sys
    {
      'id' => SecureRandom.urlsafe_base64,
      'type' => 'Entry',
      'contentType' => content_type
    }
  end

  def content_type
    {
      'sys' => {
        'linkType' => 'ContentType',
        'type' => 'Link',
        'id' => 'test1'
      }
    }
  end
end
