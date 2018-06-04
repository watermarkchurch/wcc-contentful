# frozen_string_literal: true

RSpec.shared_examples 'contentful store' do
  describe '#set/#find' do
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
  end

  describe '#index' do
    let(:entry) {
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
            }
          }
        }
      JSON
    }

    let(:asset) {
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
    }

    let(:deleted_entry) {
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
    }

    let(:deleted_asset) {
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
    }

    it 'stores an "Entry"' do
      # act
      prev = subject.index(entry)

      # assert
      expect(prev).to eq(entry)
      expect(subject.find('1qLdW7i7g4Ycq6i4Cckg44')).to eq(entry)
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
      expect(subject.find('3pWma8spR62aegAWAWacyA')).to eq(asset)
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

    it 'recursively resolves links if include > 0' do
      root = {
        'sys' => {
          'id' => 'root',
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
      shallow =
        1.upto(3).map do |i|
          {
            'sys' => { 'id' => "shallow#{i}", 'contentType' => make_link_to('shallow', 'ContentType') },
            'fields' => { 'name' => { 'en-US' => "shallow#{i}" } }
          }
        end
      deep =
        1.upto(2).map do |i|
          {
            'sys' => { 'id' => "deep#{i}", 'contentType' => make_link_to('deep', 'ContentType') },
            'fields' => {
              'name' => { 'en-US' => "deep#{i}" },
              'subLink' => { 'en-US' => make_link_to("shallow#{i}") }
            }
          }
        end

      [root, *shallow, *deep].each { |d| subject.set(d.dig('sys', 'id'), d) }

      # act
      found = subject.find_by(content_type: 'root', filter: { name: 'root' }, query: {
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
      root = {
        'sys' => {
          'id' => 'root',
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
      shallow =
        1.upto(3).map do |i|
          {
            'sys' => { 'id' => "shallow#{i}", 'contentType' => make_link_to('shallow', 'ContentType') },
            'fields' => { 'name' => { 'en-US' => "shallow#{i}" } }
          }
        end
      deep =
        1.upto(2).map do |i|
          {
            'sys' => { 'id' => "deep#{i}", 'contentType' => make_link_to('deep', 'ContentType') },
            'fields' => {
              'name' => { 'en-US' => "deep#{i}" },
              'subLink' => { 'en-US' => make_link_to("shallow#{i}") }
            }
          }
        end

      [root, *shallow, *deep].each { |d| subject.set(d.dig('sys', 'id'), d) }

      # act
      found = subject.find_by(content_type: 'root', filter: { name: 'root' }, query: {
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
      found = subject.find_all(content_type: 'test2')

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
