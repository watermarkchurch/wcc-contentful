# frozen_string_literal: true

RSpec.describe WCC::Contentful::RichText do
  let(:fixture) {
    JSON.parse(load_fixture('contentful/block-text-with-rich-text.json'))
      .dig('items', 0, 'fields', 'richBody', 'en-US')
  }

  subject {
    WCC::Contentful::RichText.tokenize(fixture)
  }

  it { is_expected.to be_a WCC::Contentful::RichText::Document }

  it 'cannot set node values' do
    expect {
      subject.rich_body['content'] = 'test'
    }.to raise_error(NameError)
  end

  # RichText structs should be as similar to a Hash as possible.
  shared_examples 'hash interface' do
    it 'enumerates keys' do
      expect(fixture.keys.length).to be > 0
      expect(subject.keys).to eq(fixture.keys)
    end

    it 'enumerates with each' do
      count = 0
      subject.each do |(key, value)|
        # values should match what you get when calling the method defined by key
        expect(value).to eq(subject.public_send(key))
        count += 1
      end
      expect(fixture.length).to be > 0
      expect(count).to eq(fixture.length)

      # returns an array of tuples when no block provided
      expect(subject.each.length).to eq(fixture.length)
    end

    it 'responds to :[] method' do
      expect(fixture['nodeType']).to be_present
      expect(subject['nodeType']).to eq(fixture['nodeType'])
    end

    it 'responds to :dig method' do
      expect(subject.dig('nodeType')).to eq(fixture['nodeType'])
    end
  end

  describe WCC::Contentful::RichText::Document do
    it_behaves_like 'hash interface'
  end
end
