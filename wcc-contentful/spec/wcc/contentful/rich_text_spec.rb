# frozen_string_literal: true

RSpec.describe WCC::Contentful::RichText do
  let(:document) {
    JSON.parse(load_fixture('contentful/block-text-with-rich-text.json'))
      .dig('items', 0, 'fields', 'richBody', 'en-US')
  }

  let(:fixture) {
    document
  }

  subject {
    described_class.tokenize(fixture)
  }

  it { is_expected.to be_a WCC::Contentful::RichText::Document }

  it 'cannot set node values' do
    expect {
      subject.rich_body['content'] = 'test'
    }.to raise_error(NameError)
  end

  # RichText structs should be as similar to a Hash as possible.
  shared_examples 'WCC::Contentful::RichText::Node' do
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
    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('document') }

    it 'can deep dig' do
      expect(
        subject.dig('content', 2, 'content', 2, 'data', 'target', 'sys', 'id')
      ).to eq('1D9ASgqWylh9frKnBv8pSM')
    end
  end

  describe WCC::Contentful::RichText::Paragraph do
    let(:fixture) {
      document.dig('content', 2)
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('paragraph') }
  end

  describe WCC::Contentful::RichText::Blockquote do
    let(:fixture) {
      document.dig('content', 3)
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('blockquote') }
  end

  describe WCC::Contentful::RichText::Text do
    let(:fixture) {
      document.dig('content', 4, 'content', 0)
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('text') }
  end

  describe WCC::Contentful::RichText::EmbeddedEntryInline do
    let(:fixture) {
      document.dig('content', 9, 'content', 1)
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('embedded-entry-inline') }
  end

  describe WCC::Contentful::RichText::EmbeddedEntryBlock do
    let(:fixture) {
      document.dig('content', 7)
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('embedded-entry-block') }
  end

  describe WCC::Contentful::RichText::EmbeddedAssetBlock do
    let(:fixture) {
      document.dig('content', 5)
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('embedded-asset-block') }
  end

  describe WCC::Contentful::RichText::Heading1 do
    let(:fixture) {
      {
        'nodeType' => 'heading-1',
        'data' => {},
        'content' => [
          {
            'nodeType' => 'text',
            'value' => 'The Meaning Behind Our Name',
            'marks' => [],
            'data' => {}
          }
        ]
      }
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('heading-1') }
  end

  describe WCC::Contentful::RichText::Heading2 do
    let(:fixture) {
      document.dig('content', 0)
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('heading-2') }
  end

  describe WCC::Contentful::RichText::Heading3 do
    let(:fixture) {
      document.dig('content', 1)
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('heading-3') }
  end

  describe WCC::Contentful::RichText::Heading4 do
    let(:fixture) {
      {
        'nodeType' => 'heading-4',
        'data' => {},
        'content' => [
          {
            'nodeType' => 'text',
            'value' => 'The Meaning Behind Our Name',
            'marks' => [],
            'data' => {}
          }
        ]
      }
    }

    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('heading-4') }
  end

  describe WCC::Contentful::RichText::Heading5 do
    let(:fixture) {
      {
        'nodeType' => 'heading-5',
        'data' => {},
        'content' => [
          {
            'nodeType' => 'text',
            'value' => 'The Meaning Behind Our Name',
            'marks' => [],
            'data' => {}
          }
        ]
      }
    }
    it_behaves_like 'WCC::Contentful::RichText::Node'
    it { is_expected.to have_node_type('heading-5') }
  end
end

RSpec::Matchers.define :have_node_type do |expected|
  match do |actual|
    actual.node_type == expected &&
      actual['nodeType'] == expected
  end
end
