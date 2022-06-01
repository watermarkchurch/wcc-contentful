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
      expect(subject.each.map(&:first)).to eq(fixture.keys)
    end

    it 'responds to :[] method' do
      expect(fixture['nodeType']).to be_present
      expect(subject['nodeType']).to eq(fixture['nodeType'])
    end

    it 'cannot set values' do
      described_class.members.each do |member|
        expect {
          subject[member.to_s] = 'test'
        }.to raise_error(NameError)

        expect {
          subject.public_send("#{member}=", 'test')
        }.to raise_error(NameError)
      end
    end

    it 'responds to :dig method' do
      expect(subject.dig('nodeType')).to eq(fixture['nodeType'])
    end
  end

  describe WCC::Contentful::RichText::Document do
    it { is_expected.to be_a WCC::Contentful::RichText::Document }
    it { is_expected.to have_node_type('document') }

    it_behaves_like 'WCC::Contentful::RichText::Node'

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

    it { is_expected.to be_a WCC::Contentful::RichText::Paragraph }
    it { is_expected.to have_node_type('paragraph') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
  end

  describe WCC::Contentful::RichText::Blockquote do
    let(:fixture) {
      document.dig('content', 3)
    }

    it { is_expected.to be_a WCC::Contentful::RichText::Blockquote }
    it { is_expected.to have_node_type('blockquote') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
  end

  describe WCC::Contentful::RichText::Text do
    let(:fixture) {
      document.dig('content', 4, 'content', 0)
    }

    it { is_expected.to be_a WCC::Contentful::RichText::Text }
    it { is_expected.to have_node_type('text') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
  end

  describe WCC::Contentful::RichText::EmbeddedEntryInline do
    let(:fixture) {
      document.dig('content', 9, 'content', 1)
    }

    it { is_expected.to be_a WCC::Contentful::RichText::EmbeddedEntryInline }
    it { is_expected.to have_node_type('embedded-entry-inline') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
  end

  describe WCC::Contentful::RichText::EmbeddedEntryBlock do
    let(:fixture) {
      document.dig('content', 7)
    }

    it { is_expected.to be_a WCC::Contentful::RichText::EmbeddedEntryBlock }
    it { is_expected.to have_node_type('embedded-entry-block') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
  end

  describe WCC::Contentful::RichText::EmbeddedAssetBlock do
    let(:fixture) {
      document.dig('content', 5)
    }

    it { is_expected.to be_a WCC::Contentful::RichText::EmbeddedAssetBlock }
    it { is_expected.to have_node_type('embedded-asset-block') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
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

    it { is_expected.to be_a WCC::Contentful::RichText::Heading1 }
    it { is_expected.to have_node_type('heading-1') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
  end

  describe WCC::Contentful::RichText::Heading2 do
    let(:fixture) {
      document.dig('content', 0)
    }

    it { is_expected.to be_a WCC::Contentful::RichText::Heading2 }
    it { is_expected.to have_node_type('heading-2') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
  end

  describe WCC::Contentful::RichText::Heading3 do
    let(:fixture) {
      document.dig('content', 1)
    }

    it { is_expected.to be_a WCC::Contentful::RichText::Heading3 }
    it { is_expected.to have_node_type('heading-3') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
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

    it { is_expected.to be_a WCC::Contentful::RichText::Heading4 }
    it { is_expected.to have_node_type('heading-4') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
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

    it { is_expected.to be_a WCC::Contentful::RichText::Heading5 }
    it { is_expected.to have_node_type('heading-5') }

    it_behaves_like 'WCC::Contentful::RichText::Node'
  end
end

RSpec::Matchers.define :have_node_type do |expected|
  match do |actual|
    actual.node_type == expected &&
      actual['nodeType'] == expected
  end
end
