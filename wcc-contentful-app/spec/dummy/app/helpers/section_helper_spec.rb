# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::App::SectionHelper, type: :helper do
  let(:markdown_string_with_links_that_have_classes) {
    +"Ministry developed by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas."\
    " Just relax. [Watermark Community Church](http://www.watermark.org){: .button-medium .green} ok."\
    " Last line goes here [Test](https://test.com)."
  }

  let(:markdown_string_with_classless_link) {
    "Test line goes here [Test](https://test.com)."
  }

  let(:markdown_string_without_links) {
    "nothin to see here"
  }

  describe '#markdown' do
    context 'when markdown includes links with classes' do
      it 'uses those classes in the hyperlinks within the html to be rendered' do
        html_to_render =
          helper.markdown(markdown_string_with_links_that_have_classes)

        expect(html_to_render).to include("class=\"button white \"")
        expect(html_to_render).to include("class=\"button-medium green \"")
        expect(html_to_render).to include(
          "<a href=\"/awaken\" title=\"Awaken's Homepage\" class=\"button white \" >Awaken</a>"
        )
      end
    end

    context 'when markdown does NOT include links with classes' do
      it 'returns html with hyperlinks that do not have class attributes' do
        html_to_render =
          helper.markdown(markdown_string_with_classless_link)

        expect(html_to_render).to_not include("class=")
        expect(html_to_render).to include("<a href=\"https://test.com\" target=\"_blank\">Test</a>")
      end
    end

    context 'when only class syntax is passed {: .this } without link' do
      it 'returns the {: .this } within the html to be rendered' do
        markdown_string = "Just some content {: .this }"
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include("{: .this }")
      end
    end
  end

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

  describe '#remove_markdown_href_class_syntax' do
    it "removes all of the '{: .button}' syntax from markdown text" do
      raw_classes =
        [
          '{: .button .white}',
          '{: .button-medium .green}'
        ]
      text =
        +"Ministry developed by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas."\
        " Just relax. [Watermark Community Church](http://www.watermark.org){: .button-medium .green} ok."\
        " Last line goes here [Test](https://test.com)."
      
      expect(text.include? '{: .button .white}').to be true

      helper.remove_markdown_href_class_syntax(raw_classes, text)

      expect(text.include? '{: .button .white}').to be false
    end
  end

  describe '#url_and_title' do
    context 'when markdown link has an absolute url' do
      it 'returns the absolute url' do
        markdown_link = 'http://www.watermark.org "Watermark Community Church"'
        url, title = helper.url_and_title(markdown_link)

        expect(url).to eq('http://www.watermark.org')
      end
    end

    context 'when markdown link has a relative url' do
      it 'returns the relative url' do
        markdown_link = '/awaken "Awaken\'s Homepage"'
        url, title = helper.url_and_title(markdown_link)

        expect(url).to eq('/awaken')
      end
    end

    context 'when markdown link includes a title' do
      it 'returns the title' do
        markdown_link = 'http://www.watermark.org "Watermark Community Church"'
        url, title = helper.url_and_title(markdown_link)

        expect(title).to eq('"Watermark Community Church"')
      end
    end

    context 'when markdown link does not include a title' do
      it 'returns nil in the title slot' do
        markdown_link = 'http://www.watermark.org'
        url, title = helper.url_and_title(markdown_link)

        expect(title).to be_nil
      end
    end
  end

  describe '#capture_individual_classes' do
    it 'receives a string and returns an array' do
      raw_class = '{: .button .white}'
      classes = helper.capture_individual_classes(raw_class)

      expect(classes).not_to be_empty
    end

    it 'takes classes from a specific string syntax and pushes them into an array' do
      raw_class = '{: .button .white}'
      expected_array_of_classes =
        ['.button', '.white']
      classes = helper.capture_individual_classes(raw_class)

      expect(classes).to match_array(expected_array_of_classes)
    end
  end

  describe '#combine_individual_classes_to_one_string' do
    it 'receives an array of classes and returns those classes as a string' do
      array_of_classes = ['.button', '.white']
      class_string = helper.combine_individual_classes_to_one_string(array_of_classes)

      expect(class_string).to eq('button white ')
    end
  end
end