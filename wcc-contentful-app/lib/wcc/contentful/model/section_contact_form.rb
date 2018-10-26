# frozen_string_literal: true

class WCC::Contentful::Model::SectionContactForm < WCC::Contentful::Model
  def page
    WCC::Contentful::Model::Page.find_by(sections: { id: id })
  end
end
