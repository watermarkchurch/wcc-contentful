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

  let(:content_type) {
    {
      'sys' => {
        'type' => 'Link',
        'linkType' => 'ContentType',
        'id' => 'toJsonTest'
      }
    }
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

  let(:store) {
    double
  }

  subject {
    WCC::Contentful::Model::ToJsonTest.new(raw)
  }

  before do
    builder = WCC::Contentful::ModelBuilder.new({ 'toJsonTest' => typedef })
    builder.build_models

    allow(WCC::Contentful::Model).to receive(:store)
      .and_return(store)
  end

  describe '#resolve' do
    it 'raises argument error for depth 0' do
      expect {
        subject.resolve(depth: 0)
      }.to raise_error(ArgumentError)
    end

    it 'resolves links for depth 1' do
      resolved = make_resolved(depth: 1)

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 1 }).once
        .and_return(resolved)

      expect(WCC::Contentful::Model).to_not receive(:find)

      # act
      result = subject.resolve

      # assert
      expect(subject.some_link.name).to eq('unresolved1.2')
      expect(subject.items.map(&:name)).to eq(%w[unresolved1.3 unresolved1.4])
      expect(result).to equal(subject)
    end

    it 'recursively resolves links for further depth' do
      resolved = make_resolved(depth: 10, fields: ['someLink'])
      deep_resolved = raw.deep_dup
      deep_resolved['sys']['id'] = '1.2'
      deep_resolved['fields'].merge!({
        'items' => nil,
        'someLink' => { 'en-US' => {
          'sys' => { 'id' => 'deep1', 'type' => 'Entry', 'contentType' => content_type },
          'fields' => { 'name' => { 'en-US' => 'number 11' } }
        } }
      })

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 10 }).once
        .and_return(resolved)
      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1.2' },
              options: { include: 1 }).once
        .and_return(deep_resolved)

      # act
      subject.resolve(depth: 11, fields: [:some_link])

      # assert
      # walk the whole tree down to number 11
      links = []
      current = subject
      while current = current.some_link
        links << current.name
      end

      expect(links).to eq(
        [
          'resolved9',
          'resolved8',
          'resolved7',
          'resolved6',
          'resolved5',
          'resolved4',
          'resolved3',
          'resolved2',
          'resolved1',
          'unresolved1.2',
          'number 11'
        ]
      )
    end

    it 'stops when it hits a circular reference' do
      raw['fields']['someLink'] = nil

      raw3 = raw.deep_dup
      raw3['sys']['id'] = '3'
      # circular back to 1
      raw3['fields']['items']['en-US'] = [
        { 'sys' => { 'id' => '1' } }
      ]

      resolved = raw.deep_dup
      resolved['fields']['items'] = { 'en-US' => [raw3] }

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 10 }).once
        .and_return(resolved)

      expect(WCC::Contentful::Model).to_not receive(:find)

      # act
      subject.resolve(depth: 99)

      # assert
      expect(subject.items[0].items[0]).to equal(subject)
    end

    it 'raises on circular reference when given option circular_reference: :raise' do
      raw['fields']['someLink'] = nil

      raw3 = raw.deep_dup
      raw3['sys']['id'] = '3'
      # circular back to 1
      raw3['fields']['items']['en-US'] = [
        { 'sys' => { 'id' => '1' } }
      ]

      resolved = raw.deep_dup
      resolved['fields']['items'] = { 'en-US' => [raw3] }

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 10 }).once
        .and_return(resolved)

      expect(WCC::Contentful::Model).to_not receive(:find)

      # act
      expect {
        subject.resolve(depth: 99, circular_reference: :raise)
      }.to raise_error(WCC::Contentful::CircularReferenceError)
    end

    it 'does not resolve circular reference when given option circular_reference: :ignore' do
      raw['fields']['someLink'] = nil

      raw3 = raw.deep_dup
      raw3['sys']['id'] = '3'
      # circular back to 1
      raw3['fields']['items']['en-US'] = [
        { 'sys' => { 'id' => '1' } }
      ]

      resolved = raw.deep_dup
      resolved['fields']['items'] = { 'en-US' => [raw3] }

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 10 }).once
        .and_return(resolved)

      expect(WCC::Contentful::Model).to_not receive(:find)

      # act
      subject.resolve(depth: 99, circular_reference: :ignore)

      # assert
      expect(subject.items[0].resolved?(fields: [:items])).to be false
      expect {
        subject.to_json
      }.to_not raise_error
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

    it 'exits early if already resolved to depth' do
      link = double(resolved?: true)
      subject.instance_variable_set('@someLink_resolved', link)
      subject.instance_variable_set('@items_resolved', [link, link])

      expect(WCC::Contentful::Model).to_not receive(:find)

      # act
      resolved = subject.resolve(depth: 2)

      # assert
      expect(link).to have_received(:resolved?).exactly(3).times.with(depth: 1)
      expect(resolved).to equal(subject)
    end

    it 're-resolves to deeper depth' do
      resolved = make_resolved(depth: 1, fields: 'someLink')
      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 1 }).once
        .and_return(resolved)

      second_resolved = make_resolved(depth: 1, fields: 'someLink')
      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1.2' },
              options: { include: 1 }).once
        .and_return(second_resolved)

      expect(WCC::Contentful::Model).to_not receive(:find)
      subject.resolve(depth: 1)

      # act
      subject.resolve(depth: 2)

      # assert
      expect(subject.some_link.some_link.name).to eq('unresolved1.2')
    end

    it 're-resolves circular reference further down the tree' do
      expect(WCC::Contentful::Model).to_not receive(:find)
      expect(store).to_not receive(:find)

      resolved1 = raw.deep_dup
      # another reference that was resolved
      raw2 = raw.deep_dup
      raw2['sys']['id'] = '2'
      raw2['fields']['items'] = nil
      raw2['fields']['someLink']['en-US'] = { 'sys' => { 'type' => 'Link', 'id' => '4' } }
      resolved1['fields']['someLink']['en-US'] = raw2

      raw3 = raw.deep_dup
      raw3['sys']['id'] = '3'
      raw3['fields']['someLink'] = nil
      # circular back to 1
      raw3['fields']['items']['en-US'] = [
        { 'sys' => { 'type' => 'Link', 'id' => '1' } }
      ]
      resolved1['fields']['items'] = { 'en-US' => [raw3] }

      # subject now has two children:
      #   someLink => '2'
      #   items[0] => '3'
      subject = WCC::Contentful::Model::ToJsonTest.new(resolved1).resolve(depth: 1)
      expect(subject.some_link.id).to eq('2')
      expect(subject.some_link).to_not be_resolved

      resolved3 = raw3.deep_dup
      # a resolved circular ref back to '1'
      raw3['fields']['items']['en-US'] = [
        resolved1
      ]

      # this happens in the call to #resolve on items[0]
      allow(store).to receive(:find_by)
        .with(hash_including(content_type: 'toJsonTest',
                             filter: { 'sys.id' => '3' })).once
        .and_return(resolved3)

      # this happens when the link from '2' => '4' gets resolved
      resolved2 = raw2.deep_dup
      raw2['fields']['someLink']['en-US'] =
        { 'sys' => { 'type' => 'Entry', 'id' => '4', 'contentType' => content_type } }
      allow(store).to receive(:find_by)
        .with(hash_including(content_type: 'toJsonTest',
                             filter: { 'sys.id' => '2' })).once
        .and_return(resolved2)

      # act
      # the entry with ID '3' gets resolved here -
      # level 1 resolves items[0] on '3' back to subject which is in the backlinks
      # level 2 was resolved earlier on subject
      # level 3 resolves some_link on '2' which points to '4'
      subject.items[0].resolve(depth: 3)

      # assert
      expect(subject.items[0].items[0].some_link.id).to eq('2')
      expect(subject.items[0].items[0].some_link).to be_resolved
      expect(subject.items[0].items[0].some_link.some_link.id).to eq('4')
    end

    it 'keeps track of backlinks' do
      resolved = make_resolved(depth: 2)

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 1 }).once
        .and_return(resolved)

      expect(WCC::Contentful::Model).to_not receive(:find)

      # act
      subject.resolve

      # assert
      expect(subject.some_link.sys.context.backlinks[0]).to equal(subject)
      expect(subject.items[0].sys.context.backlinks[0]).to equal(subject)

      expect(subject.some_link.some_link.sys.context.backlinks[0])
        .to equal(subject.some_link)
      expect(subject.some_link.some_link.sys.context.backlinks[1])
        .to equal(subject)
    end
  end

  describe '#resolved?' do
    it 'raises argument error for depth 0' do
      expect {
        subject.resolved?(depth: 0)
      }.to raise_error(ArgumentError)
    end

    it 'returns false when links not resolved' do
      # act
      result = subject.resolved?

      # assert
      expect(result).to be false
    end

    it 'returns true when broken links are nil' do
      raw['fields']['someLink']['en-US'] = nil
      raw['fields']['items']['en-US'] = [nil, nil]

      # act
      result = subject.resolved?

      # assert
      expect(result).to be true
    end

    it 'returns true when no links in array' do
      raw['fields']['someLink']['en-US'] = nil
      raw['fields']['items']['en-US'] = []

      # act
      result = subject.resolved?

      # assert
      expect(result).to be true
    end

    it 'returns false when a single link is not resolved' do
      subject.instance_variable_set('@items_resolved', [double, double])

      # act
      result = subject.resolved?

      # assert
      expect(result).to be false
    end

    it 'returns true when all links are resolved' do
      subject.instance_variable_set('@someLink_resolved', double)
      subject.instance_variable_set('@items_resolved', [double, double])

      # act
      result = subject.resolved?

      # assert
      expect(result).to be true
    end

    it 'calls into sub-links when depth > 1' do
      link = double
      item = double
      subject.instance_variable_set('@someLink_resolved', link)
      subject.instance_variable_set('@items_resolved', [nil, item])

      expect(link).to receive(:resolved?).with(depth: 1).and_return(true)
      expect(item).to receive(:resolved?).with(depth: 1).and_return(true)

      # act
      result = subject.resolved?(depth: 2)

      # assert
      expect(result).to be true
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
      resolved = make_resolved(depth: 1)

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 1 }).once
        .and_return(resolved)

      subject.resolve

      # act
      json = JSON.parse(subject.to_json)

      # assert
      expect(json.dig('fields', 'someLink', 'fields')).to eq({
        'name' => 'unresolved1.2',
        'blob' => { 'some' => { 'data' => 3 } },
        'someLink' => { 'sys' => { 'type' => 'Link', 'linkType' => 'Entry', 'id' => '2' } },
        'items' => []
      })
      expect(json.dig('fields', 'items', 1, 'fields')).to eq({
        'name' => 'unresolved1.4',
        'blob' => { 'some' => { 'data' => 3 } },
        'someLink' => { 'sys' => { 'type' => 'Link', 'linkType' => 'Entry', 'id' => '2' } },
        'items' => []
      })
    end

    it 'raises circular reference exception' do
      raw['fields']['someLink'] = nil

      raw3 = raw.deep_dup
      raw3['sys']['id'] = '3'
      # circular back to 1
      raw3['fields']['items']['en-US'] = [
        { 'sys' => { 'id' => '1' } }
      ]

      resolved = raw.deep_dup
      resolved['fields']['items'] = { 'en-US' => [raw3] }

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 10 }).once
        .and_return(resolved)

      subject.resolve(depth: 99)

      # act
      expect {
        subject.to_json
      }.to raise_error(WCC::Contentful::CircularReferenceError)
    end
  end

  describe '#to_h' do
    it 'makes a json-equivalent hash' do
      resolved = make_resolved(depth: 1)

      expect(store).to receive(:find_by)
        .with(content_type: 'toJsonTest',
              filter: { 'sys.id' => '1' },
              options: { include: 1 }).once
        .and_return(resolved)

      subject.resolve

      # act
      h = subject.to_h

      # assert
      expect(h.dig('fields', 'someLink', 'fields')).to eq({
        'name' => 'unresolved1.2',
        'blob' => { 'some' => { 'data' => 3 } },
        'someLink' => { 'sys' => { 'type' => 'Link', 'linkType' => 'Entry', 'id' => '2' } },
        'items' => []
      })

      round_trip = JSON.parse(h.to_json)
      expect(h).to eql(round_trip)
    end
  end

  def make_resolved(depth: 1, fields: %w[someLink items])
    resolved = raw.deep_dup
    resolved['sys']['id'] = "resolved#{depth}"

    if depth > 1
      link = make_resolved(depth: depth - 1, fields: fields) if fields.include?('someLink')
      items =
        if fields.include?('items')
          1.upto(2).map do
            make_resolved(depth: depth - 1, fields: fields)
          end
        end
    else
      link = unresolved("#{depth}.2") if fields.include?('someLink')
      items =
        ([unresolved("#{depth}.3"), unresolved("#{depth}.4")] if fields.include?('items'))
    end

    resolved['fields'].merge!({
      'name' => { 'en-US' => "resolved#{depth}" },
      'someLink' => { 'en-US' => link },
      'items' => { 'en-US' => items }
    })
    resolved
  end

  def unresolved(id)
    fake = raw.deep_dup
    fake['sys']['id'] = id
    fake['fields']['name']['en-US'] = "unresolved#{id}"
    fake['fields']['items']['en-US'] = nil
    fake
  end
end
