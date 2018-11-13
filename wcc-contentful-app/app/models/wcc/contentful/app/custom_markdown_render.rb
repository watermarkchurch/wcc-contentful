# frozen_string_literal: true

module WCC::Contentful::App
  class CustomMarkdownRender < Redcarpet::Render::HTML
    def initialize(options)
      super
      @links_with_classes = options[:links_with_classes]
    end

    def link(link, title, content)
      target = url_target(link)
      if link_with_class_data =
           @links_with_classes.find do |link_with_class|
             link_with_class[0] == link &&
                 link_with_class[2] == CGI.unescape_html(content)
           end
        link_class = link_with_class_data[3]
        "<a href=\"#{link}\" title=\"#{title}\" class=\"#{link_class}\" #{target}>#{content}</a>"
      else
        "<a href=\"#{link}\" title=\"#{title}\" #{target}>#{content}</a>"
      end
    end

    def url_target(url)
      "target='_blank'" if url.scan(/(\s|^)(https?:\/\/\S*)/).present?
    end
  end
end
