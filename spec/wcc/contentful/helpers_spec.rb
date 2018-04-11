# frozen_string_literal: true

RSpec.describe WCC::Contentful::Helpers do
  let(:helper) { described_class }

  describe '.constant_from_content_type' do
    it 'returns a string representing a ruby class name' do
      expect(helper.constant_from_content_type('some_class'))
        .to be_a(String)
    end

    it 'classifies the argument' do
      expect(helper.constant_from_content_type('some_class'))
        .to eq('SomeClass')
    end

    it 'removes all space and special characters' do
      expect(helper.constant_from_content_type('Section: Featured Items'))
        .to eq('SectionFeaturedItems')
    end

    it 'uniformly handles dashes and underscores' do
      expect(helper.constant_from_content_type('some-content_type'))
        .to eq('SomeContentType')
    end
  end
end
