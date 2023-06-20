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
          "some before text [links with a newline]\n(https://www.test.com){: .newline } " \
          'and some after text'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to have_link(href: 'https://www.test.com')
        expect(html_to_render).to_not have_selector('.newline')
      end

      it 'will render the class as plain text next to the hyperlink' do
        markdown_string =
          "some before text [links with a newline]\n(https://www.test.com){: .newline } " \
          'and some after text'
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
          "some before text [newline after the parens](http://www.google.com)\n{: .test } " \
          'and some after text'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include(
          '<a target="_blank" href="http://www.google.com">newline after the parens</a>'
        )
      end
      it 'will render <br>\n{: .test } after the converted hyperlink' do
        markdown_string =
          "some before text [newline after the parens](http://www.google.com)\n{: .test } " \
          'and some after text'
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render).to include(
          "<a target=\"_blank\" href=\"http://www.google.com\">newline after the parens</a><br>\n" \
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

    context 'when content includes marks' do
      it 'should apply the class to strikethrough marks' do
        markdown_string =
          <<-STRING
            [~~some strikethrough text~~ some normal text](/home){: .text }
          STRING
        html_to_render =
          helper.markdown(markdown_string)

        expect(html_to_render.strip).to eq <<~HTML.strip
          <div class="formatted-content"><p><a href="/home" class="text"><del>some strikethrough text</del> some normal text</a></p>
          </div>
        HTML
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

    it 'allows setting :with_toc_data option' do
      html = helper.markdown <<~MARKDOWN, with_toc_data: true
        # some h1
        some text
        ## some h2
        some more text
      MARKDOWN

      expect(html).to include('<h1 id="some-h1">some h1</h1>')
      expect(html).to include('<h2 id="some-h2">some h2</h2>')
    end
  end
end
