# frozen_string_literal: true

require 'contentful_model'

module WCC::Contentful
  class Redirect < ContentfulModel::Base
    return_nil_for_empty :url, :pageReference
    class_attribute :load_depth
    self.load_depth = 10
    self.content_type_id = 'redirect'

    def self.find_by_slug(slug)
      find_by(slug: slug.downcase).load_children(load_depth).load.first
    end

    def location
      if !url.nil?
        url
      elsif valid_page_reference?(pageReference)
        "/#{pageReference.url}"
      end
    end

    def valid_page_reference?(page_ref)
      if page_ref.nil? || defined?(page_ref.url).nil?
        false
      else
        true
      end
    end
  end
end
