# frozen_string_literal: true
require 'contentful_model'

module WCC::Contentful
  class Redirect < ContentfulModel::Base
    return_nil_for_empty :url, :pageReference
    class_attribute :load_depth
    self.load_depth = 10
    self.content_type_id = 'redirect'

    def self.find_by_slug(slug)
      self.find_by(slug: slug).load_children(load_depth).load.first
    end

    def location
      if !self.url.nil?
        return self.url
      elsif !self.pageReference.nil?
        return "/#{self.pageReference.url}"
      else
        return nil
      end
    end
  end
end