# frozen_string_literal: true

class WCC::Contentful::Model::Redirect < WCC::Contentful::Model
  def href
    if !url.nil?
      url
    elsif valid_page_reference?(pageReference)
      "/#{pageReference.url}"
    end
  end

  def valid_page_reference?(page_ref)
    if !page_ref.nil? || !defined?(page_ref.url).nil?
      true
    else
      false
    end
  end
end
