# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::App::SectionHelper, type: :helper do
  let(:markdown_string_with_links) {
    "Ministry developed by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas."\
    " Just relax. [Watermark Community Church](http://www.watermark.org){: .button-medium .green}"
  }

  let(:markdown_string_without_links) {
    "nothin to see here"
  }

  describe '#links_within_markdown' do
    context 'when given markdown that includes links' do
      it 'returns an array that is not empty' do
        markdown_links = helper.links_within_markdown(markdown_string_with_links)

        expect(markdown_links).not_to be_empty
      end
      it 'returns an array of all the links in that markdown' do
        markdown_links = helper.links_within_markdown(markdown_string_with_links)
        expected_array =
          [
            [
              '[Awaken](/awaken "Awaken\'s Homepage"){: .button .white}',
              'Awaken',
              '/awaken "Awaken\'s Homepage"',
              '{: .button .white}'
            ],
            [
              '[Watermark Community Church](http://www.watermark.org){: .button-medium .green}',
              'Watermark Community Church',
              'http://www.watermark.org',
              '{: .button-medium .green}'
            ]
          ]
        expect(markdown_links).to match_array(expected_array)
      end
    end

    context 'when given markdown that doesn\'t include links' do
      it 'returns an empty array' do
        expect(helper.links_within_markdown(markdown_string_without_links)).to be_empty
      end
    end
  end
end