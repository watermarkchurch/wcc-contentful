# frozen_string_literal: true

class WCC::Contentful::Model::SiteConfig < WCC::Contentful::Model
  def self.instance(preview = false)
    find_by(foreign_key: 'default', options: { include: 4, preview: preview })
  end
end
