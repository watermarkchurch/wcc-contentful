# frozen_string_literal: true

class WCC::Contentful::Model::SiteConfig < WCC::Contentful::Model
  def self.instance
    @instance ||= find_by(foreign_key: 'default')
  end
end
