# frozen_string_literal: true

module WCC::Contentful::App
  class CustomMarkdownRender < Redcarpet::Render::HTML
    def initialize(options)
      super
      @options = options
    end

    def link(link, title, content)
      link_with_class_data =
        @options[:links_with_classes]&.find do |link_with_class|
          link_with_class[0] == link &&
            link_with_class[2] == CGI.unescape_html(content)
        end

      link_class = link_with_class_data ? link_with_class_data[3] : nil
      ActionController::Base.helpers.link_to(
        content,
        link,
        hyperlink_attributes(title, link, link_class)
      )
    end

    def hyperlink_attributes(title, url, link_class = nil)
      link_attrs = { title: title, class: link_class }

      link_attrs[:target] = '_blank' if use_target_blank?(url)

      return link_attrs unless @options[:link_attributes]

      @options[:link_attributes].merge(link_attrs)
    end

    def use_target_blank?(url)
      url.scan(/(\s|^)(https?:\/\/\S*)/).present?
    end
  end
end
