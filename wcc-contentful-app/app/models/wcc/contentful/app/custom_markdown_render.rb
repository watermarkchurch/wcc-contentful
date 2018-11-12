# frozen_string_literal: true

module WCC::Contentful::App
  class CustomMarkdownRender < Redcarpet::Render::HTML
    def initialize(options)
      super
      @links_with_classes = options[:links_with_classes]
    end
  
    def link(link, title, content)
      target = url_target(link)
      if link_with_class =
          @links_with_classes.detect do |link_with_class|
            link_with_class[0] == link &&
              link_with_class[2] == CGI.unescape_html(content)
          end
        link_class = link_with_class[3]
        "<a href=\"#{link}\" title=\"#{title}\" class=\"#{link_class}\" #{target}>#{content}</a>"
      else
        "<a href=\"#{link}\" title=\"#{title}\" #{target}>#{content}</a>"
      end
    end

    def url_target(url)
      if url.scan(/(\s|^)(https?:\/\/\S*)/).present?
        "target='_blank'"
      else
        nil
      end
    end
  end
end
