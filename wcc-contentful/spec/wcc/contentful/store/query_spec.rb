# frozen_string_literal: true

require 'wcc/contentful/store/query'

RSpec.describe WCC::Contentful::Store::Query do
  let(:store) {
    double('store')
  }

  subject {
    described_class.new(store, content_type: 'test')
  }

  describe '.normalize_condition_path' do
    it 'does not mangle an explicit path' do
      path = described_class.normalize_condition_path(['fields', 'a', 'en-US'])

      expect(path).to eq(['fields', 'a', 'en-US'])
    end

    it 'inserts fields and locale' do
      path = described_class.normalize_condition_path(['a'])

      expect(path).to eq(['fields', 'a', 'en-US'])
    end

    it 'inserts fields' do
      path = described_class.normalize_condition_path(['a', 'en-US'])

      expect(path).to eq(['fields', 'a', 'en-US'])
    end

    it 'inserts locale' do
      path = described_class.normalize_condition_path(%w[fields a])

      expect(path).to eq(['fields', 'a', 'en-US'])
    end

    it 'allows an explicit field named "fields"' do
      path = described_class.normalize_condition_path(%w[fields fields])

      expect(path).to eq(['fields', 'fields', 'en-US'])
    end

    it 'handles a join' do
      path = described_class.normalize_condition_path(%w[page slug])

      expect(path).to eq(['fields', 'page', 'en-US', 'fields', 'slug', 'en-US'])
    end

    it 'infers sys' do
      path = described_class.normalize_condition_path(['id'])

      expect(path).to eq(%w[sys id])
    end

    it 'infers sys after a join' do
      path = described_class.normalize_condition_path(['page', 'en-US', 'id'])

      expect(path).to eq(%w[fields page en-US sys id])
    end

    it 'allows explicit sys' do
      path = described_class.normalize_condition_path('sys.contentType.sys.id'.split('.'))

      expect(path).to eq(%w[sys contentType sys id])
    end
  end

  WCC::Contentful::Store::Query::OPERATORS.each do |op|
    describe "##{op}" do
      it 'adds a condition' do
        query = subject.public_send(op, 'f', 'test')

        cond = query.conditions[0]
        expect(cond&.path).to eq(['fields', 'f', 'en-US'])
        expect(cond.op).to eq(op)
        expect(cond.expected).to eq('test')
        expect(query.conditions.length).to eq(1)
      end

      it 'appends a second condition' do
        query = subject.eq(:a, 1).public_send(op, 'f', 'test')

        cond = query.conditions[1]
        expect(cond&.path).to eq(['fields', 'f', 'en-US'])
        expect(cond.op).to eq(op)
        expect(cond.expected).to eq('test')
        expect(query.conditions.length).to eq(2)
      end
    end
  end

  describe '#apply' do
    it 'adds a single condition' do
      query = subject.apply({ f: 'test' })

      cond = query.conditions[0]
      expect(cond&.path).to eq(['fields', 'f', 'en-US'])
      expect(cond.op).to eq(:eq)
      expect(cond.expected).to eq('test')
      expect(query.conditions.length).to eq(1)
    end

    it 'appends a second condition' do
      query = subject.eq(:a, 1).apply({ 'f' => 'test' })

      cond = query.conditions[1]
      expect(cond&.path).to eq(['fields', 'f', 'en-US'])
      expect(cond.op).to eq(:eq)
      expect(cond.expected).to eq('test')
      expect(query.conditions.length).to eq(2)
    end

    WCC::Contentful::Store::Query::OPERATORS.each do |op|
      context "{ #{op}: value }" do
        it 'adds appropriate op condition' do
          query = subject.apply({
            'f' => {
              op => 'test'
            }
          })

          cond = query.conditions[0]
          expect(cond&.path).to eq(['fields', 'f', 'en-US'])
          expect(cond.op).to eq(op)
          expect(cond.expected).to eq('test')
          expect(query.conditions.length).to eq(1)
        end
      end
    end

    it 'adds multiple conditions at once' do
      query = subject.apply({
        'fields' => {
          'f' => 'test',
          'f2' => { lt: 2 }
        }
      })

      cond0 = query.conditions[0]
      expect(cond0&.path).to eq(['fields', 'f', 'en-US'])
      expect(cond0.op).to eq(:eq)
      expect(cond0.expected).to eq('test')

      cond1 = query.conditions[1]
      expect(cond1&.path).to eq(['fields', 'f2', 'en-US'])
      expect(cond1.op).to eq(:lt)
      expect(cond1.expected).to eq(2)
      expect(query.conditions.length).to eq(2)
    end

    it 'adds dot-path notation conditions' do
      query = subject.apply({
        'sys.contentType.sys.id' => 'button',
        'fields.link.en-US.sys.contentType.sys.id' => 'page',
        'link.slug' => { ne: '/test' }
      })

      cond0 = query.conditions[0]
      expect(cond0&.path).to eq(%w[sys contentType sys id])
      expect(cond0.op).to eq(:eq)
      expect(cond0.expected).to eq('button')

      cond1 = query.conditions[1]
      expect(cond1&.path).to eq(['fields', 'link', 'en-US', 'sys', 'contentType', 'sys', 'id'])
      expect(cond1.op).to eq(:eq)
      expect(cond1.expected).to eq('page')

      cond2 = query.conditions[2]
      expect(cond2&.path).to eq(['fields', 'link', 'en-US', 'fields', 'slug', 'en-US'])
      expect(cond2.op).to eq(:ne)
      expect(cond2.expected).to eq('/test')

      expect(query.conditions.length).to eq(3)
    end
  end
end
