# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::App::MarkdownRenderer do
  let(:markdown_string_with_links_that_have_classes) {
    <<-STRING
      Ministry by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas.
      Just relax. [Watermark Community Church](http://www.watermark.org){: .button-medium .green} ok.
      Last line goes here [Test](https://test.com).
    STRING
  }

  let(:markdown_string_without_links) {
    'nothin to see here'
  }

  describe '#links_within_markdown' do
    context 'when given markdown that includes links' do
      it 'returns an array that is not empty', focus: true do
        markdown_links = subject.send(:links_within_markdown,
          markdown_string_with_links_that_have_classes)

        expect(markdown_links).not_to be_empty
      end

      it 'returns an array of all the links in that markdown' do
        markdown_links = subject.send(:links_within_markdown,
          markdown_string_with_links_that_have_classes)
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
        expect(subject.send(:links_within_markdown, markdown_string_without_links)).to be_empty
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
        returned_value = subject.send(:gather_links_with_classes_data, links_with_classes_arr)

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
        links_with_classes = subject.send(:gather_links_with_classes_data, link_data_arr)[0]

        expect(links_with_classes.count).to eq(1)
        expect(links_with_classes).to match_array(expected_links_with_classes)
        expect(links_with_classes).to_not include(link_data_arr[0])
      end

      it 'returns an array that only has the raw classes', focus: true do
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

        raw_classes = subject.send(:gather_links_with_classes_data, links_with_classes_arr)[1]

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
        returned_value = subject.send(:gather_links_with_classes_data, links_without_classes_arr)

        expect(returned_value).to_not be_empty
        expect(returned_value[0]).to be_empty
        expect(returned_value[1]).to be_empty
      end
    end
  end

  describe '#remove_markdown_href_class_syntax' do
    it "returns the markdown text without all of the '{: .button}' syntax" do
      raw_classes =
        [
          '{: .button .white}',
          '{: .button-medium .green}'
        ]
      text =
        <<-STRING
          Ministry developed by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white}
           [Watermark Community Church](http://www.watermark.org){: .button-medium .green}
           [Test](https://test.com).
        STRING

      text_without_class_syntax =
        <<-STRING
          Ministry developed by [Awaken](/awaken \"Awaken's Homepage\")
           [Watermark Community Church](http://www.watermark.org)
           [Test](https://test.com).
        STRING

      expect(text).to include('{: .button .white}')

      transformed_text = subject.send(:remove_markdown_href_class_syntax, raw_classes, text)

      expect(transformed_text).to_not include('{: .button .white}')
      expect(transformed_text).to eq(text_without_class_syntax)
    end
  end

  describe '#url_and_title' do
    context 'when markdown link has an absolute url' do
      it 'returns the absolute url' do
        markdown_link = 'http://www.watermark.org "Watermark Community Church"'
        url = subject.send(:url_and_title, markdown_link)[0]

        expect(url).to eq('http://www.watermark.org')
      end
    end

    context 'when markdown link has a relative url' do
      it 'returns the relative url' do
        markdown_link = '/awaken "Awaken\'s Homepage"'
        url = subject.send(:url_and_title, markdown_link)[0]

        expect(url).to eq('/awaken')
      end
    end

    context 'when markdown link has a hash location' do
      it 'returns the hash location' do
        markdown_link = '#awaken "Awaken\'s Homepage"'
        url = subject.send(:url_and_title, markdown_link)[0]

        expect(url).to eq('#awaken')
      end
    end

    context 'when markdown link includes a title' do
      it 'returns the title' do
        markdown_link = 'http://www.watermark.org "Watermark Community Church"'
        title = subject.send(:url_and_title, markdown_link)[1]

        expect(title).to eq('"Watermark Community Church"')
      end
    end

    context 'when markdown link does not include a title' do
      it 'returns nil in the title slot' do
        markdown_link = 'http://www.watermark.org'
        title = subject.send(:url_and_title, markdown_link)[1]

        expect(title).to be_nil
      end
    end
  end

  describe '#capture_individual_classes' do
    it 'receives a string and returns an array' do
      raw_class = '{: .button .white}'
      classes = subject.send(:capture_individual_classes, raw_class)

      expect(classes).not_to be_empty
    end

    it 'takes classes from a specific string syntax and pushes them into an array' do
      raw_class = '{: .button .white}'
      expected_array_of_classes =
        ['.button', '.white']
      classes = subject.send(:capture_individual_classes, raw_class)

      expect(classes).to match_array(expected_array_of_classes)
    end
  end

  describe '#combine_individual_classes_to_one_string' do
    it 'receives an array of classes and returns those classes as a string' do
      array_of_classes = ['.button', '.white']
      class_string = subject.send(:combine_individual_classes_to_one_string, array_of_classes)

      expect(class_string).to eq('button white ')
    end
  end
end
