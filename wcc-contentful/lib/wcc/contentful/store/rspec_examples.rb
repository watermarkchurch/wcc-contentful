# frozen_string_literal: true

# rubocop:disable Style/BlockDelimiters

# These shared examples are included to help you implement a new store from scratch.
# To get started implementing your store, require this file and then include the
# shared examples in your RSpec block.
#
# The shared examples take a hash which describes the feature set that this store
# implements.  All the additional features start out in the 'pending' state,
# once you've implemented that feature in your store then you can switch them
# to `true`.
#
# [:nested_queries] - This feature allows queries that reference a field on a
#    linked object, example: `Player.find_by(team: { slug: '/dallas-cowboys' })`.
#    This becomes essentially a JOIN.  For reference see the Postgres store.
# [:include_param] - This feature defines how the store respects the `include: n`
#    key in the Options hash.  Some stores can make use of this parameter to get
#    all linked entries of an object in a single query.
#    If your store does not respect the include parameter, then the Model layer
#    will be calling #find a lot in order to resolve linked entries.
#
# @example
#   require 'wcc/contentful/store/rspec_examples'
#   RSpec.describe MyStore do
#     subject { MyStore.new }
#
#     it_behaves_like 'contentful store', {
#       # nested_queries: true,
#       # include_param: true
#     }
#
RSpec.shared_examples 'contentful store' do |feature_set|
  feature_set = {
    nested_queries: 'pending',
    include_param: 'pending'
  }.merge(feature_set&.symbolize_keys || {})

  include_examples 'basic store'
  include_examples 'supports nested queries', feature_set[:nested_queries]
  include_examples 'supports include param', feature_set[:include_param]
end

RSpec.shared_examples 'basic store' do
  let(:entry) do
    JSON.parse(<<~JSON)
      {
        "sys": {
          "space": {
            "sys": {
              "type": "Link",
              "linkType": "Space",
              "id": "343qxys30lid"
            }
          },
          "id": "1qLdW7i7g4Ycq6i4Cckg44",
          "type": "Entry",
          "createdAt": "2018-03-09T23:39:27.737Z",
          "updatedAt": "2018-03-09T23:39:27.737Z",
          "revision": 1,
          "contentType": {
            "sys": {
              "type": "Link",
              "linkType": "ContentType",
              "id": "redirect"
            }
          }
        },
        "fields": {
          "slug": {
            "en-US": "redirect-with-slug-and-url"
          },
          "url": {
            "en-US": "http://www.google.com"
          },
          "page": {
            "en-US": {
              "sys": {
                "type": "Link",
                "linkType": "Entry",
                "id": "2zKTmej544IakmIqoEu0y8"
              }
            }
          }
        }
      }
    JSON
  end

  let(:page) do
    JSON.parse(<<~JSON)
      {
        "sys": {
          "space": {
            "sys": {
              "type": "Link",
              "linkType": "Space",
              "id": "343qxys30lid"
            }
          },
          "id": "2zKTmej544IakmIqoEu0y8",
          "type": "Entry",
          "createdAt": "2018-03-09T23:39:27.737Z",
          "updatedAt": "2018-03-09T23:39:27.737Z",
          "revision": 1,
          "contentType": {
            "sys": {
              "type": "Link",
              "linkType": "ContentType",
              "id": "page"
            }
          }
        },
        "fields": {
          "slug": {
            "en-US": "some-page"
          },
          "hero": {
            "en-US": {
              "sys": {
                "type": "Link",
                "linkType": "Asset",
                "id": "3pWma8spR62aegAWAWacyA"
              }
            }
          }
        }
      }
    JSON
  end

  let(:asset) do
    JSON.parse(<<~JSON)
      {
        "sys": {
          "space": {
            "sys": {
              "type": "Link",
              "linkType": "Space",
              "id": "343qxys30lid"
            }
          },
          "id": "3pWma8spR62aegAWAWacyA",
          "type": "Asset",
          "createdAt": "2018-02-12T19:53:39.309Z",
          "updatedAt": "2018-02-12T19:53:39.309Z",
          "revision": 1
        },
        "fields": {
          "title": {
            "en-US": "apple-touch-icon"
          },
          "file": {
            "en-US": {
              "url": "//images.contentful.com/343qxys30lid/3pWma8spR62aegAWAWacyA/1beaebf5b66d2405ff9c9769a74db709/apple-touch-icon.png",
              "details": {
                "size": 40832,
                "image": {
                  "width": 180,
                  "height": 180
                }
              },
              "fileName": "apple-touch-icon.png",
              "contentType": "image/png"
            }
          }
        }
      }
    JSON
  end

  before do
    allow(WCC::Contentful).to receive(:types)
      .and_return({
        'root' => double(fields: {
          'name' => double(name: 'name', type: :String, array: false),
          'link' => double(name: 'link', type: :Link, array: false),
          'links' => double(name: 'links', type: :Link, array: true)
        }),
        'shallow' => double(fields: {
          'name' => double(name: 'name', type: :String, array: false)
        }),
        'deep' => double(fields: {
          'name' => double(name: 'name', type: :String, array: false),
          'subLink' => double(name: 'subLink', type: :Link, array: false)
        })
      })
  end

  describe '#set/#find' do
    describe 'ensures that the stored value is of type Hash' do
      it 'should not raise an error if value is a Hash' do
        data = { token: 'jenny_8675309' }

        # assert
        expect { subject.set('sync:token', data) }.to_not raise_error
      end

      it 'should raise an error if the value is not a Hash' do
        data = 'jenny_8675309'
        expect { subject.set('sync:token', data) }.to raise_error(ArgumentError)
      end
    end

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

    it 'find accepts hint param' do
      subject.set('1qLdW7i7g4Ycq6i4Cckg44', entry)
      subject.set('3pWma8spR62aegAWAWacyA', asset)

      # act
      found_entry = subject.find('1qLdW7i7g4Ycq6i4Cckg44', hint: 'Entry')
      found_asset = subject.find('3pWma8spR62aegAWAWacyA', hint: 'Asset')

      # assert
      expect(found_entry.dig('sys', 'id')).to eq(entry.dig('sys', 'id'))
      expect(found_asset.dig('sys', 'id')).to eq(asset.dig('sys', 'id'))
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

    it 'instruments set' do
      data = { 'key' => 'val', '1' => { 'deep' => 9 } }

      expect {
        # act
        subject.set('1234', data)
      }.to instrument('set.store.contentful.wcc')
        .with(hash_including(id: '1234'))
    end

    it 'instruments find' do
      expect {
        # act
        subject.find('1234')
      }.to instrument('find.store.contentful.wcc')
        .with(hash_including(id: '1234'))
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

    it 'instruments delete' do
      expect {
        # act
        subject.delete('1234')
      }.to instrument('delete.store.contentful.wcc')
        .with(hash_including(id: '1234'))
    end
  end

  describe '#index' do
    let(:deleted_entry) do
      JSON.parse(<<~JSON)
        {
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "343qxys30lid"
              }
            },
            "id": "6HQsABhZDiWmi0ekCouUuy",
            "type": "DeletedEntry",
            "createdAt": "2018-03-13T19:45:44.454Z",
            "updatedAt": "2018-03-13T19:45:44.454Z",
            "deletedAt": "2018-03-13T19:45:44.454Z",
            "environment": {
              "sys": {
                "type": "Link",
                "linkType": "Environment",
                "id": "98322ee2-6dee-4651-b3a5-743be50fb107"
              }
            },
            "revision": 1
          }
        }
      JSON
    end

    let(:deleted_asset) do
      JSON.parse(<<~JSON)
        {
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "343qxys30lid"
              }
            },
            "id": "3pWma8spR62aegAWAWacyA",
            "type": "DeletedAsset",
            "createdAt": "2018-03-20T18:44:58.270Z",
            "updatedAt": "2018-03-20T18:44:58.270Z",
            "deletedAt": "2018-03-20T18:44:58.270Z",
            "environment": {
              "sys": {
                "type": "Link",
                "linkType": "Environment",
                "id": "98322ee2-6dee-4651-b3a5-743be50fb107"
              }
            },
            "revision": 1
          }
        }
      JSON
    end

    it 'stores an "Entry"' do
      # act
      prev = subject.index(entry)

      # assert
      expect(prev).to eq(entry)
      expect(subject.find('1qLdW7i7g4Ycq6i4Cckg44', hint: 'Entry')).to eq(entry)
    end

    it 'updates an "Entry" when exists' do
      existing = { 'test' => { 'data' => 'asdf' } }
      subject.set('1qLdW7i7g4Ycq6i4Cckg44', existing)

      # act
      latest = subject.index(entry)

      # assert
      expect(latest).to eq(entry)
      expect(subject.find('1qLdW7i7g4Ycq6i4Cckg44')).to eq(entry)
    end

    it 'does not overwrite an entry if revision is lower' do
      initial = entry
      updated = entry.deep_dup
      updated['sys']['revision'] = 2
      updated['fields']['slug']['en-US'] = 'test slug'

      subject.index(updated)

      # act
      latest = subject.index(initial)

      # assert
      expect(latest).to eq(updated)
      expect(subject.find('1qLdW7i7g4Ycq6i4Cckg44')).to eq(updated)
    end

    it 'stores an "Asset"' do
      # act
      latest = subject.index(asset)

      # assert
      expect(latest).to eq(asset)
      expect(subject.find('3pWma8spR62aegAWAWacyA', hint: 'Asset')).to eq(asset)
    end

    it 'updates an "Asset" when exists' do
      existing = { 'test' => { 'data' => 'asdf' } }
      subject.set('3pWma8spR62aegAWAWacyA', existing)

      # act
      latest = subject.index(asset)

      # assert
      expect(latest).to eq(asset)
      expect(subject.find('3pWma8spR62aegAWAWacyA')).to eq(asset)
    end

    it 'does not overwrite an asset if revision is lower' do
      initial = asset
      updated = asset.deep_dup
      updated['sys']['revision'] = 2
      updated['fields']['title']['en-US'] = 'test title'

      subject.index(updated)

      # act
      latest = subject.index(initial)

      # assert
      expect(latest).to eq(updated)
      expect(subject.find('3pWma8spR62aegAWAWacyA')).to eq(updated)
    end

    it 'removes a "DeletedEntry"' do
      existing = { 'test' => { 'data' => 'asdf' } }
      subject.set('6HQsABhZDiWmi0ekCouUuy', existing)

      # act
      latest = subject.index(deleted_entry)

      # assert
      expect(latest).to be_nil
      expect(subject.find('6HQsABhZDiWmi0ekCouUuy')).to be_nil
    end

    it 'does not remove if "DeletedEntry" revision is lower' do
      existing = entry
      existing['sys']['id'] = deleted_entry.dig('sys', 'id')
      existing['sys']['revision'] = deleted_entry.dig('sys', 'revision') + 1
      subject.index(existing)

      # act
      latest = subject.index(deleted_entry)

      # assert
      expect(latest).to eq(existing)
      expect(subject.find(deleted_entry.dig('sys', 'id'))).to eq(existing)
    end

    it 'removes a "DeletedAsset"' do
      existing = { 'test' => { 'data' => 'asdf' } }
      subject.set('3pWma8spR62aegAWAWacyA', existing)

      # act
      latest = subject.index(deleted_asset)

      # assert
      expect(latest).to be_nil
      expect(subject.find('3pWma8spR62aegAWAWacyA')).to be_nil
    end

    it 'does not remove if "DeletedAsset" revision is lower' do
      existing = asset
      existing['sys']['id'] = deleted_asset.dig('sys', 'id')
      existing['sys']['revision'] = deleted_asset.dig('sys', 'revision') + 1
      subject.index(existing)

      # act
      latest = subject.index(deleted_asset)

      # assert
      expect(latest).to eq(existing)
      expect(subject.find(deleted_asset.dig('sys', 'id'))).to eq(existing)
    end

    it 'instruments index set' do
      expect {
        expect {
          # act
          subject.index(entry)
        }.to instrument('index.store.contentful.wcc')
          .with(hash_including(id: '1qLdW7i7g4Ycq6i4Cckg44'))
      }.to instrument('set.store.contentful.wcc')
        .with(hash_including(id: '1qLdW7i7g4Ycq6i4Cckg44'))
    end

    it 'instruments index delete' do
      existing = { 'test' => { 'data' => 'asdf' } }
      subject.set('6HQsABhZDiWmi0ekCouUuy', existing)

      expect {
        expect {
          # act
          subject.index(deleted_entry)
        }.to instrument('index.store.contentful.wcc')
          .with(hash_including(id: '6HQsABhZDiWmi0ekCouUuy'))
      }.to instrument('delete.store.contentful.wcc')
        .with(hash_including(id: '6HQsABhZDiWmi0ekCouUuy'))
    end
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

    it 'returns nil when cant find content type' do
      content_types = %w[test1]
      data =
        1.upto(4).map do |i|
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
      nonexistent_content_type = subject.find_by(content_type: 'test2')

      # assert
      expect(nonexistent_content_type).to be nil
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

    it 'can find by ID directly' do
      [entry, page, asset].each { |d| subject.set(d.dig('sys', 'id'), d) }

      # act
      found = subject.find_by(content_type: 'Asset', filter: { id: '3pWma8spR62aegAWAWacyA' })

      # assert
      expect(found).to eq(asset)
    end

    it 'filter object can find value in array' do
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
      found = subject.find_by(content_type: 'test2', filter: { 'name' => { eq: 'test_2_5' } })

      # assert
      expect(found).to_not be_nil
      expect(found.dig('sys', 'id')).to eq('k5')
    end

    it 'allows properties named `*sys*`' do
      %w[One Two].each do |field|
        subject.set("id#{field}", {
          'sys' => {
            'id' => "id#{field}",
            'contentType' => {
              'sys' => {
                'id' => 'system'
              }
            }
          },
          'fields' => {
            'system' => {
              'en-US' => field
            }
          }
        })
      end

      # act
      found = subject.find_by(content_type: 'system', filter: { system: 'Two' })

      # assert
      expect(found).to_not be_nil
      expect(found.dig('sys', 'id')).to eq('idTwo')
      expect(found.dig('fields', 'system', 'en-US')).to eq('Two')
    end

    it 'instruments find_by' do
      expect {
        subject.find_by(content_type: 'test2')
      }.to instrument('find_by.store.contentful.wcc')
        .with(hash_including(content_type: 'test2'))
    end
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
      found = subject.find_all(content_type: 'test2').to_a

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

    it 'instruments find_all' do
      expect {
        subject.find_all(content_type: 'test2')
      }.to instrument('find_all.store.contentful.wcc')
        .with(hash_including(content_type: 'test2'))
    end
  end

  def make_link_to(id, link_type = 'Entry')
    {
      'sys' => {
        'type' => 'Link',
        'linkType' => link_type,
        'id' => id
      }
    }
  end
end

RSpec.shared_examples 'supports nested queries' do |feature_set|
  describe 'nested (join) queries' do
    before { skip('nested_queries feature not supported') } if feature_set == false
    before { pending('nested_queries feature to be implemented') } if feature_set&.to_s == 'pending'

    describe '#find_by' do
      before do
        # add a dummy redirect that we ought to pass over
        redirect2 = entry.deep_dup
        redirect2['sys']['id'] = 'wrong_one'
        redirect2['fields'].delete('page')
        subject.set('wrong_one', redirect2)

        [entry, page, asset].each { |d| subject.set(d.dig('sys', 'id'), d) }
      end

      it 'allows filtering by a reference field' do
        # act
        found = subject.find_by(
          content_type: 'redirect',
          filter: {
            page: {
              slug: { eq: 'some-page' }
            }
          }
        )

        # assert
        expect(found).to_not be_nil
        expect(found.dig('sys', 'id')).to eq('1qLdW7i7g4Ycq6i4Cckg44')
        expect(found.dig('sys', 'contentType', 'sys', 'id')).to eq('redirect')
      end

      it 'allows filtering by reference id' do
        # act
        found = subject.find_by(
          content_type: 'redirect',
          filter: { 'page' => { id: '2zKTmej544IakmIqoEu0y8' } }
        )

        # assert
        expect(found).to_not be_nil
        expect(found.dig('sys', 'id')).to eq('1qLdW7i7g4Ycq6i4Cckg44')
      end

      it 'handles explicitly specified sys attr' do
        # act
        found = subject.find_by(
          content_type: 'redirect',
          filter: {
            page: {
              'sys.contentType.sys.id' => 'page'
            }
          }
        )

        # assert
        expect(found).to_not be_nil
        expect(found.dig('sys', 'id')).to eq('1qLdW7i7g4Ycq6i4Cckg44')
      end
    end
  end
end

RSpec.shared_examples 'supports include param' do |feature_set|
  describe 'supports options: { include: >0 }' do
    before { skip('include_param feature not supported') } if feature_set == false
    before { pending('include_param feature not yet implemented') } if feature_set&.to_s == 'pending'

    let(:root) {
      {
        'sys' => {
          'id' => 'root',
          'type' => 'Entry',
          'contentType' => { 'sys' => { 'id' => 'root' } }
        },
        'fields' => {
          'name' => { 'en-US' => 'root' },
          'link' => { 'en-US' => make_link_to('deep1') },
          'links' => { 'en-US' => [
            make_link_to('shallow3'),
            make_link_to('deep2')
          ] }
        }
      }
    }

    def shallow(id = nil) # rubocop:disable Naming/UncommunicativeMethodParamName
      {
        'sys' => {
          'id' => "shallow#{id}",
          'type' => 'Entry',
          'contentType' => { 'sys' => { 'id' => 'shallow' } }
        },
        'fields' => { 'name' => { 'en-US' => "shallow#{id}" } }
      }
    end

    def deep(id, link = nil) # rubocop:disable Naming/UncommunicativeMethodParamName
      {
        'sys' => {
          'id' => "deep#{id}",
          'type' => 'Entry',
          'contentType' => { 'sys' => { 'id' => 'deep' } }
        },
        'fields' => {
          'name' => { 'en-US' => "deep#{id}" },
          'subLink' => { 'en-US' => link || make_link_to("shallow#{id}") }
        }
      }
    end

    describe '#find_by' do
      it 'recursively resolves links if include > 0' do
        [
          root,
          *1.upto(3).map { |i| shallow(i) },
          *1.upto(2).map { |i| deep(i) }
        ].each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'root', filter: { name: 'root' }, options: {
          include: 2
        })

        # assert
        expect(found.dig('sys', 'id')).to eq('root')

        # depth 1
        link = found.dig('fields', 'link', 'en-US')
        expect(link.dig('fields', 'name', 'en-US')).to eq('deep1')
        links = found.dig('fields', 'links', 'en-US')
        expect(links[0].dig('fields', 'name', 'en-US')).to eq('shallow3')

        # depth 2
        expect(link.dig('fields', 'subLink', 'en-US', 'fields', 'name', 'en-US'))
          .to eq('shallow1')
        expect(links[1].dig('fields', 'subLink', 'en-US', 'fields', 'name', 'en-US'))
          .to eq('shallow2')
      end

      it 'stops resolving links at include depth' do
        [
          root,
          *1.upto(3).map { |i| shallow(i) },
          *1.upto(2).map { |i| deep(i) }
        ].each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        found = subject.find_by(content_type: 'root', filter: { name: 'root' }, options: {
          include: 1
        })

        # assert
        expect(found.dig('sys', 'id')).to eq('root')

        # depth 1
        link = found.dig('fields', 'link', 'en-US')
        expect(link.dig('fields', 'name', 'en-US')).to eq('deep1')
        links = found.dig('fields', 'links', 'en-US')
        expect(links[0].dig('fields', 'name', 'en-US')).to eq('shallow3')

        # depth 2
        expect(link.dig('fields', 'subLink', 'en-US', 'sys', 'type'))
          .to eq('Link')
        expect(links[1].dig('fields', 'subLink', 'en-US', 'sys', 'type'))
          .to eq('Link')
      end

      1.upto(5).each do |depth|
        it "does not call into #find in order to resolve include: #{depth}" do
          skip("supported up to #{feature_set}") if feature_set.is_a?(Integer) && feature_set < depth

          items = [root]
          # 1..N
          1.upto(depth).map do |n|
            items << deep(n, make_link_to("deep#{n + 1}"))
          end
          items.each { |d| subject.set(d.dig('sys', 'id'), d) }

          # Expect
          expect(subject).to_not receive(:find)

          # act
          found = subject.find_by(content_type: 'root', filter: { name: 'root' }, options: {
            include: depth
          })

          link = found.dig('fields', 'link', 'en-US')
          1.upto(depth).each do |_n|
            expect(link.dig('sys', 'type')).to eq('Entry')
            link = link.dig('fields', 'subLink', 'en-US')
          end
          expect(link.dig('sys', 'type')).to eq('Link')
        end
      end

      it 'handles recursion' do
        items = [
          deep(0, make_link_to('deep1')),
          deep(1, make_link_to('deep0'))
        ]
        items.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        r0 = subject.find_by(content_type: 'deep', filter: { id: 'deep0' }, options: {
          include: 4
        })

        link = r0.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep1')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep0')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep1')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep0')
      end
    end

    describe '#find_all' do
      it 'recursively resolves links if include > 0' do
        [
          root,
          *1.upto(3).map { |i| shallow(i) },
          *1.upto(2).map { |i| deep(i) }
        ].each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        result = subject.find_all(content_type: 'root', options: {
          include: 2
        }).to_a

        # assert
        found = result.first
        expect(found.dig('sys', 'id')).to eq('root')

        # depth 1
        link = found.dig('fields', 'link', 'en-US')
        expect(link.dig('fields', 'name', 'en-US')).to eq('deep1')
        links = found.dig('fields', 'links', 'en-US')
        expect(links[0].dig('fields', 'name', 'en-US')).to eq('shallow3')

        # depth 2
        expect(link.dig('fields', 'subLink', 'en-US', 'fields', 'name', 'en-US'))
          .to eq('shallow1')
        expect(links[1].dig('fields', 'subLink', 'en-US', 'fields', 'name', 'en-US'))
          .to eq('shallow2')
      end

      it 'stops resolving links at include depth' do
        [
          root,
          *1.upto(3).map { |i| shallow(i) },
          *1.upto(2).map { |i| deep(i) }
        ].each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        result = subject.find_all(content_type: 'root', options: {
          include: 1
        }).to_a

        # assert
        found = result.first
        expect(found.dig('sys', 'id')).to eq('root')

        # depth 1
        link = found.dig('fields', 'link', 'en-US')
        expect(link.dig('fields', 'name', 'en-US')).to eq('deep1')
        links = found.dig('fields', 'links', 'en-US')
        expect(links[0].dig('fields', 'name', 'en-US')).to eq('shallow3')

        # depth 2
        expect(link.dig('fields', 'subLink', 'en-US', 'sys', 'type'))
          .to eq('Link')
        expect(links[1].dig('fields', 'subLink', 'en-US', 'sys', 'type'))
          .to eq('Link')
      end

      1.upto(5).each do |depth|
        it "does not call into #find in order to resolve include: #{depth}" do
          skip("supported up to #{feature_set}") if feature_set.is_a?(Integer) && feature_set < depth

          # 1..N
          items =
            0.upto(depth).map do |n|
              deep(n, make_link_to("deep#{n + 1}"))
            end
          items.each { |d| subject.set(d.dig('sys', 'id'), d) }

          # Expect
          expect(subject).to_not receive(:find)

          # act
          results = subject.find_all(content_type: 'deep', options: {
            include: depth
          }).to_a

          results.sort_by { |entry| entry.dig('sys', 'id') }.each_with_index do |found, n|
            link = found.dig('fields', 'subLink', 'en-US')
            1.upto(depth - n).each do |_n|
              expect(link.dig('sys', 'type')).to eq('Entry')
              link = link.dig('fields', 'subLink', 'en-US')
            end
            expect(link.dig('sys', 'type')).to eq('Link')
          end
          expect(results.length).to eq(items.length)
        end
      end

      it 'handles recursion' do
        items = [
          deep(0, make_link_to('deep1')),
          deep(1, make_link_to('deep0'))
        ]
        items.each { |d| subject.set(d.dig('sys', 'id'), d) }

        # act
        results = subject.find_all(content_type: 'deep', options: {
          include: 4
        }).to_a

        results = results.sort_by { |entry| entry.dig('sys', 'id') }

        r0 = results[0]
        link = r0.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep1')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep0')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep1')
        link = link.dig('fields', 'subLink', 'en-US')
        expect(link.dig('sys', 'type')).to eq('Entry')
        expect(link.dig('sys', 'id')).to eq('deep0')
      end
    end
  end
end

# rubocop:enable Style/BlockDelimiters
