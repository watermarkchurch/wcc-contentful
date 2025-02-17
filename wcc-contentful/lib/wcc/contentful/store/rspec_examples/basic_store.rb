# frozen_string_literal: true

# rubocop:disable Style/BlockDelimiters

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
          "revision": 2
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

  describe '#set/#find' do
    describe 'ensures that the stored value is of type Hash' do
      it 'should not raise an error if value is a Hash' do
        data = {
          'sys' => { 'id' => 'sync:token', 'type' => 'token' },
          'token' => 'state'
        }

        # assert
        expect { subject.set('sync:token', data) }.to_not raise_error
      end

      it 'should raise an error if the value is not a Hash' do
        data = 'jenny_8675309'
        expect { subject.set('sync:token', data) }.to raise_error(ArgumentError)
      end
    end

    it 'stores and finds data by ID' do
      data = {
        'sys' => { 'id' => '1234' },
        'key' => 'val',
        '1' => { 'deep' => 9 }
      }

      # act
      subject.set('1234', data)
      found = subject.find('1234')

      # assert
      expect(found).to eq(data)
    end

    it 'find returns nil if key doesnt exist' do
      data = {
        'sys' => { 'id' => '1234' },
        'key' => 'val',
        '1' => { 'deep' => 9 }
      }
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
      data = {
        'sys' => { 'id' => '1234', 'revision' => 1 },
        'key' => 'val',
        '1' => { 'deep' => 9 }
      }
      data2 = {
        'sys' => { 'id' => '1234', 'revision' => 2 },
        'key' => 'val',
        '1' => { 'deep' => 11 }
      }

      # act
      prior1 = subject.set('1234', data)
      prior2 = subject.set('1234', data2)

      # assert
      expect(prior1).to be_nil
      expect(prior2).to eq(data)
      expect(subject.find('1234')).to eq(data2)
    end

    it 'modifying found entry does not modify underlying data' do
      subject.index(entry)

      # act
      found = subject.find('1qLdW7i7g4Ycq6i4Cckg44')
      found['fields']['slug']['en-US'] = 'new slug'

      # assert
      found2 = subject.find('1qLdW7i7g4Ycq6i4Cckg44')
      expect(found2.dig('fields', 'slug', 'en-US')).to eq('redirect-with-slug-and-url')
    end

    it 'stores metadata including tags' do
      entry_with_tags = JSON.parse <<~JSON
        {
          "metadata": {
            "tags": [
              {
                "sys": {
                  "type": "Link",
                  "linkType": "Tag",
                  "id": "ministry_careers-in-motion"
                }
              }
            ],
            "concepts": []
          },
          "sys": {
            "space": {
              "sys": {
                "type": "Link",
                "linkType": "Space",
                "id": "hw5pse7y1ojx"
              }
            },
            "id": "1h5ce0SYZq8cELhESiJFkA",
            "type": "Entry",
            "createdAt": "2020-02-06T20:25:19.188Z",
            "updatedAt": "2024-11-21T19:02:37.381Z",
            "environment": {
              "sys": {
                "id": "dev",
                "type": "Link",
                "linkType": "Environment"
              }
            },
            "publishedVersion": 73,
            "revision": 7,
            "contentType": {
              "sys": {
                "type": "Link",
                "linkType": "ContentType",
                "id": "page"
              }
            }
          },
          "fields": {
            "title": {
              "en-US": "Finances and Career Care"
            },
            "slug": {
              "en-US": "/ministries/financialcareers"
            },
            "sections": {
              "en-US": [
                {
                  "sys": {
                    "type": "Link",
                    "linkType": "Entry",
                    "id": "4agnOGg0LQZrCbF4OeMEbj"
                  }
                },
                {
                  "sys": {
                    "type": "Link",
                    "linkType": "Entry",
                    "id": "614GfdpLaD5gjc0U3sITXY"
                  }
                },
                {
                  "sys": {
                    "type": "Link",
                    "linkType": "Entry",
                    "id": "xM5NWKiZSRUoUxXvoiYW4"
                  }
                }
              ]
            }
          }
        }
      JSON

      # act
      subject.set('1h5ce0SYZq8cELhESiJFkA', entry_with_tags)
      found = subject.find('1h5ce0SYZq8cELhESiJFkA')

      # assert
      expect(found.dig('metadata', 'tags', 0, 'sys', 'id')).to eq('ministry_careers-in-motion')
    end
  end

  describe '#delete' do
    it 'deletes an item out of the store' do
      data = {
        'sys' => { 'id' => '1234' },
        'key' => 'val',
        '1' => { 'deep' => 9 }
      }
      subject.set('9999', data)

      # act
      deleted = subject.delete('9999')

      # assert
      expect(deleted).to eq(data)
      expect(subject.find('9999')).to be_nil
    end

    it "returns nil if item doesn't exist" do
      data = {
        'sys' => { 'id' => '9999' },
        'key' => 'val',
        '1' => { 'deep' => 9 }
      }
      subject.set('9999', data)

      # act
      deleted = subject.delete('asdf')

      # assert
      expect(deleted).to be_nil
      expect(subject.find('9999')).to eq(data)
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
      existing = {
        'sys' => { 'id' => '3pWma8spR62aegAWAWacyA', 'revision' => 1 },
        'test' => { 'data' => 'asdf' }
      }
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
      updated['sys']['revision'] = 3
      updated['fields']['title']['en-US'] = 'test title'

      subject.index(updated)

      # act
      latest = subject.index(initial)

      # assert
      expect(latest).to eq(updated)
      expect(subject.find('3pWma8spR62aegAWAWacyA')).to eq(updated)
    end

    it 'removes a "DeletedEntry"' do
      existing = {
        'sys' => { 'id' => '6HQsABhZDiWmi0ekCouUuy' },
        'test' => { 'data' => 'asdf' }
      }
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
      existing = {
        'sys' => { 'id' => '3pWma8spR62aegAWAWacyA' },
        'test' => { 'data' => 'asdf' }
      }
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

    it 'modifying found entry does not modify underlying data' do
      subject.index(entry)

      # act
      found = subject.find_by(filter: { 'sys.id' => '1qLdW7i7g4Ycq6i4Cckg44' }, content_type: 'redirect')
      found['fields']['slug']['en-US'] = 'new slug'

      # assert
      found2 = subject.find_by(filter: { 'sys.id' => '1qLdW7i7g4Ycq6i4Cckg44' }, content_type: 'redirect')
      expect(found2.dig('fields', 'slug', 'en-US')).to eq('redirect-with-slug-and-url')
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

    it 'modifying found entry does not modify underlying data' do
      subject.index(entry)

      # act
      found = subject.find_all(content_type: 'redirect').eq('sys.id', '1qLdW7i7g4Ycq6i4Cckg44').first
      found['fields']['slug']['en-US'] = 'new slug'

      # assert
      found2 = subject.find_all(content_type: 'redirect').eq('sys.id', '1qLdW7i7g4Ycq6i4Cckg44').first
      expect(found2.dig('fields', 'slug', 'en-US')).to eq('redirect-with-slug-and-url')
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

# rubocop:enable Style/BlockDelimiters
