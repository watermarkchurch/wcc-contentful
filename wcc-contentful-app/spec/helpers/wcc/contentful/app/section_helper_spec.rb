# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WCC::Contentful::App::SectionHelper, type: :helper do
  let(:markdown_string_with_links_that_have_classes) {
    <<-STRING
      Ministry by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas.
      Just relax. [Watermark Community Church](http://www.watermark.org){: .button-medium .green} ok.
      Last line goes here [Test](https://test.com).
    STRING
  }

  let(:markdown_string_with_links_that_have_classes2) {
    <<-STRING
      Ministry by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas.
      Ministry by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas.
      Ministry by [Awaken](/awaken \"Awaken's Homepage\"){: .button .white} in Dallas, Texas.
    STRING
  }

  let(:markdown_string_with_classless_link) {
    'Test line goes here [Test](https://test.com).'
  }

  let(:markdown_string_without_links) {
    'nothin to see here'
  }

  describe '#markdown' do
    it 'returns string wrapped in div' do
      rendered_html = helper.markdown(markdown_string_without_links)

      expect(rendered_html).to have_selector('div.formatted-content')
    end

    context 'when markdown link has an absolute url' do
      it "returns the absolute url with target='_blank'" do
        html_to_render =
          helper.markdown(
            '[Watermark Community Church](http://www.watermark.org)'
          )

        expect(html_to_render).to have_link(
          'Watermark Community Church',
          href: 'http://www.watermark.org'
        )
        expect(html_to_render).to have_selector(
          :css,
          'a[href="http://www.watermark.org"][target="_blank"]'
        )
      end
    end

    context 'when markdown link has an absolute url with a class' do
      it "returns the absolute url with target='_blank' and class" do
        html_to_render =
          helper.markdown(
            '[Watermark Community Church](http://www.watermark.org){: .btn .btn-primary}'
          )

        expect(html_to_render).to have_link(
          'Watermark Community Church',
          href: 'http://www.watermark.org',
          class: 'btn btn-primary'
        )
        expect(html_to_render).to have_selector(
          :css,
          'a[href="http://www.watermark.org"][target="_blank"]'
        )
      end
    end

    context 'when markdown link has a relative url' do
      it "returns the relative url without target='_blank'" do
        html_to_render =
          helper.markdown(
            "[Awaken's Homepage](/awaken)"
          )

        expect(html_to_render).to have_link("Awaken's Homepage", href: '/awaken')
        expect(html_to_render).to_not have_selector(:css, 'a[href="/awaken"][target="_blank"]')
      end
    end

    context 'when markdown link has a relative url with a class' do
      it "returns the relative url without target='_blank' but with the class" do
        html_to_render =
          helper.markdown(
            "[Awaken's Homepage](/awaken){: .btn .btn-primary}"
          )

        expect(html_to_render).to have_link(
          "Awaken's Homepage",
          href: '/awaken',
          class: 'btn btn-primary'
        )
        expect(html_to_render).to_not have_selector(:css, 'a[href="/awaken"][target="_blank"]')
      end
    end

    context 'when markdown link has a hash location' do
      it "returns the hash location without target='_blank'" do
        html_to_render =
          helper.markdown(
            "[Awaken's Homepage](#awaken)"
          )

        expect(html_to_render).to have_link("Awaken's Homepage", href: '#awaken')
        expect(html_to_render).to_not have_selector(
          :css,
          'a[href="#awaken"][target="_blank"]'
        )
      end
    end

    context 'when markdown link has a hash location with a class' do
      it "returns the hash location without target='_blank' but with the class" do
        html_to_render =
          helper.markdown(
            "[Awaken's Homepage](#awaken){: .btn .btn-primary}"
          )

        expect(html_to_render).to have_link(
          "Awaken's Homepage",
          href: '#awaken',
          class: 'btn btn-primary'
        )
        expect(html_to_render).to_not have_selector(:css, 'a[href="#awaken"][target="_blank"]')
      end
    end

    context 'when markdown link text has a single quote in it' do
      it 'renders the quote as a part of the link text' do
        html_to_render =
          helper.markdown(
            "[Children's](https://watermark.formstack.com/forms/childrensvolunteer)"
          )

        expect(html_to_render).to have_link("Children's", href: 'https://watermark.formstack.com/forms/childrensvolunteer')
      end
    end

    context 'when markdown link text has a single quote and class' do
      it 'renders the quote as a part of the link text' do
        html_to_render =
          helper.markdown(
            "[Children's](https://watermark.formstack.com/forms){: .btn .btn-primary}"
          )

        expect(html_to_render).to have_link(
          "Children's",
          href: 'https://watermark.formstack.com/forms',
          class: 'btn btn-primary'
        )
      end
    end

    context 'when markdown link is a mailto link' do
      it 'renders the mailto link' do
        html_to_render =
          helper.markdown(
            '[request application](mailto:students@watermark.org)'
          )

        expect(html_to_render).to have_link(
          'request application',
          href: 'mailto:students@watermark.org'
        )
      end

      it "does not include target='_blank'" do
        html_to_render =
          helper.markdown(
            '[request application](mailto:students@watermark.org)'
          )

        expect(html_to_render).to_not have_selector(
          :css,
          'a[href="mailto:students@watermark.org"][target="_blank"]'
        )
      end
    end

    context 'when markdown link is a mailto link and has a class' do
      it 'renders the mailto link' do
        html_to_render =
          helper.markdown(
            '[request application](mailto:students@watermark.org){: .btn .btn-primary}'
          )

        expect(html_to_render).to have_link(
          'request application',
          href: 'mailto:students@watermark.org',
          class: 'btn btn-primary'
        )
      end
    end

    context 'when markdown includes links with classes' do
      it 'uses those classes in the hyperlinks within the html to be rendered' do
        html_to_render =
          helper.markdown(markdown_string_with_links_that_have_classes)

        expect(html_to_render).to have_link('Awaken', href: '/awaken', class: 'button white')
        expect(html_to_render).to have_link(
          'Watermark Community Church',
          href: 'http://www.watermark.org',
          class: 'button-medium green'
        )
      end
    end

    context 'when markdown includes the same link with classes multiple times' do
      it 'builds the hyperlink with classes each time it appears in the markdown' do
        html_to_render =
          helper.markdown(markdown_string_with_links_that_have_classes2)

        expect(html_to_render).to have_link('Awaken', href: '/awaken', class: 'button white', count: 3)
      end
    end

    context 'when markdown receives the same text twice' do
      it 'applies the classes to the hyperlinks both times' do
        html_to_render =
          helper.markdown(markdown_string_with_links_that_have_classes)

        html_to_render2 =
          helper.markdown(markdown_string_with_links_that_have_classes)

        expect(html_to_render).to have_link('Awaken', href: '/awaken', class: 'button white', count: 1)
        expect(html_to_render2).to have_link('Awaken', href: '/awaken', class: 'button white', count: 1)
      end
    end

    context 'when markdown does NOT include links with classes' do
      it 'returns html with hyperlinks that do not have class attributes' do
        html_to_render =
          helper.markdown(markdown_string_with_classless_link)

        expect(html_to_render).to include('<a target="_blank" href="https://test.com">Test</a>')
      end
    end

    context 'when only class syntax is passed {: .this } without link' do
      it 'returns the {: .this } within the html to be rendered' do
        markdown_string = 'Just some content {: .this }'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include('{: .this }')
      end
    end

    context 'when class syntax is used but without a dot on the class {: this }' do
      it 'returns the {: this } within the html to be rendered' do
        markdown_string = 'Just some content {: this }'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include('{: this }')
      end
    end

    context 'when only class syntax is passed {: .this } without link' do
      it 'returns the {: .this } within the html to be rendered' do
        markdown_string = 'Just some content {: .this }'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include('{: .this }')
      end
    end

    context 'When given: [links with a newline]\n(https://www.test.com){: .newline }' do
      it 'will render the html hyperlink without using the class' do
        markdown_string =
          "some before text [links with a newline]\n(https://www.test.com){: .newline }"\
          ' and some after text'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to have_link(href: 'https://www.test.com')
        expect(html_to_render).to_not have_selector('.newline')
      end

      it 'will render the class as plain text next to the hyperlink' do
        markdown_string =
          "some before text [links with a newline]\n(https://www.test.com){: .newline }"\
          ' and some after text'
        html_to_render =
          helper.markdown(markdown_string)
        expect(html_to_render).to include(
          '<a target="_blank" href="https://www.test.com">links with a newline</a>{: .newline }'
        )
      end
    end

    context 'When given: [newline after the parens](http://www.google.com)\n{: .test }' do
      it 'will render the html hyperlink without using the class' do
        markdown_string =
          "some before text [newline after the parens](http://www.google.com)\n{: .test }"\
          ' and some after text'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include(
          '<a target="_blank" href="http://www.google.com">newline after the parens</a>'
        )
      end
      it 'will render <br>\n{: .test } after the converted hyperlink' do
        markdown_string =
          "some before text [newline after the parens](http://www.google.com)\n{: .test }"\
          ' and some after text'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include(
          "<a target=\"_blank\" href=\"http://www.google.com\">newline after the parens</a><br>\n"\
          '{: .test }'
        )
      end
    end

    context 'When class doesn\'t begin with a space: [forget spaces](http://www.google.com){:.test}' do
      it 'should still apply the classes to the hyperlink' do
        markdown_string =
          'some before text [forget spaces](http://www.google.com){:.test} and some after text'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include('class="test "')
      end
    end

    context 'When classes have no space: [no space](http://www.google.com){: .btn.btn-primary }' do
      it 'should still apply the classes to the hyperlink' do
        markdown_string =
          'some before text [no space](http://www.google.com){: .btn.btn-primary } and some after text'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include('class="btn btn-primary "')
      end
    end

    context 'when content of link matches the class name given' do
      it 'should apply the the class to the hyperlink with no conflict' do
        markdown_string =
          <<-STRING
            some before text
            [text or .text that matches a class](/home "text or .text"){: .text }
            and some after text
          STRING
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include('class="text "')
      end
    end

    it 'renders tables with bootstrap .table class' do
      html = helper.markdown(<<~MARKDOWN)
        | col1 | col2 |
        | ---- | ---- |
        | val1 | val2 |
        | val3 | val4 |
      MARKDOWN

      expect(html).to include('<table class="table')
      expect(html).to match(/<tr>\s*<th>\s*col1/)
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
        links_with_classes = helper.gather_links_with_classes_data(link_data_arr)[0]

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

        raw_classes = helper.gather_links_with_classes_data(links_with_classes_arr)[1]

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

      transformed_text = helper.remove_markdown_href_class_syntax(raw_classes, text)

      expect(transformed_text).to_not include('{: .button .white}')
      expect(transformed_text).to eq(text_without_class_syntax)
    end
  end

  describe '#url_and_title' do
    context 'when markdown link has an absolute url' do
      it 'returns the absolute url' do
        markdown_link = 'http://www.watermark.org "Watermark Community Church"'
        url = helper.url_and_title(markdown_link)[0]

        expect(url).to eq('http://www.watermark.org')
      end
    end

    context 'when markdown link has a relative url' do
      it 'returns the relative url' do
        markdown_link = '/awaken "Awaken\'s Homepage"'
        url = helper.url_and_title(markdown_link)[0]

        expect(url).to eq('/awaken')
      end
    end

    context 'when markdown link has a hash location' do
      it 'returns the hash location' do
        markdown_link = '#awaken "Awaken\'s Homepage"'
        url = helper.url_and_title(markdown_link)[0]

        expect(url).to eq('#awaken')
      end
    end

    context 'when markdown link includes a title' do
      it 'returns the title' do
        markdown_link = 'http://www.watermark.org "Watermark Community Church"'
        title = helper.url_and_title(markdown_link)[1]

        expect(title).to eq('"Watermark Community Church"')
      end
    end

    context 'when markdown link does not include a title' do
      it 'returns nil in the title slot' do
        markdown_link = 'http://www.watermark.org'
        title = helper.url_and_title(markdown_link)[1]

        expect(title).to be_nil
      end
    end

    context 'when markdown link is missing protocol' do
      it 'returns nil in the title slot' do
        markdown_link = 'www.watermark.org'
        url = helper.url_and_title(markdown_link)[0]

        expect(url).to eq('www.watermark.org')
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
