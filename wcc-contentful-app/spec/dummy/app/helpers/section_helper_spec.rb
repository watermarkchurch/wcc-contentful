# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::App::SectionHelper, type: :helper do
  let(:markdown_string_with_links_that_have_classes) {
    "Ministry developed by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas."\
    " Just relax. [Watermark Community Church](http://www.watermark.org){: .button-medium .green} ok."\
    " Last line goes here [Test](https://test.com)."
  }

  let(:markdown_string_with_classless_link) {
    "Test line goes here [Test](https://test.com)."
  }

  let(:markdown_string_without_links) {
    "nothin to see here"
  }

  describe '#links_within_markdown' do
    context 'when given markdown that includes links' do
      it 'returns an array that is not empty' do
        markdown_links = helper.links_within_markdown(markdown_string_with_links_that_have_classes)

        expect(markdown_links).not_to be_empty
      end
      it 'returns an array of all the links in that markdown' do
        markdown_links = helper.links_within_markdown(markdown_string_with_links_that_have_classes)
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
            ],
            [
              '[Test](https://test.com)',
              'Test',
              'https://test.com',
              nil
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

  describe '#gather_links_with_classes_data' do
    context 'when given links that include classes' do
      it 'returns an array of two arrays that are not empty' do
        links_with_classes_arr =
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
        returned_value = helper.gather_links_with_classes_data(links_with_classes_arr)

        expect(returned_value).not_to be_empty
        expect(returned_value[0]).not_to be_empty
        expect(returned_value[1]).not_to be_empty
      end

      it 'returns an array that only has the links that include classes' do
        link_data_arr =
          [
            [
              '[Test](https://test.com)',
              'Test',
              'https://test.com',
              nil
            ],
            [
              '[Awaken](/awaken "Awaken\'s Homepage"){: .button .white}',
              'Awaken',
              '/awaken "Awaken\'s Homepage"',
              '{: .button .white}'
            ]
          ]

        expected_links_with_classes =
          [
            [
              '/awaken',
              '"Awaken\'s Homepage"',
              'Awaken',
              'button white '
            ]
          ]
        links_with_classes, raw_classes = helper.gather_links_with_classes_data(link_data_arr)

        expect(links_with_classes.count).to eq(1)
        expect(links_with_classes).to match_array(expected_links_with_classes)
        expect(links_with_classes).to_not include(link_data_arr[0])
      end

      it 'returns an array that only has the raw classes' do
        links_with_classes_arr =
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
        
        expected_raw_classes =
          [
            '{: .button .white}',
            '{: .button-medium .green}'
          ]
        
        links_with_classes, raw_classes = helper.gather_links_with_classes_data(links_with_classes_arr)
        expect(raw_classes).to match_array(expected_raw_classes)
      end
    end

    context 'when given links that don\'t include classes' do
      it 'returns an array of two empty arrays' do
        links_without_classes_arr =
          [
            [
              '[Test](https://test.com)',
              'Test',
              'https://test.com',
              nil
            ]
          ]
        returned_value = helper.gather_links_with_classes_data(links_without_classes_arr)

        expect(returned_value).to_not be_empty
        expect(returned_value[0]).to be_empty
        expect(returned_value[1]).to be_empty
      end
    end
  end
end