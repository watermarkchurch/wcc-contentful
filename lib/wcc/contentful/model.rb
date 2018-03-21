
# frozen_string_literal: true

class WCC::Contentful::Model
  extend WCC::Contentful::Helpers
  extend WCC::Contentful::ModelValidators

  class << self
    ##
    # The configured store which executes all model queries against either the
    # Contentful CDN or a locally-downloaded copy.
    #
    # See the {sync_store}[rdoc-ref:WCC::Contentful::Configuration.sync_store] parameter
    # on the WCC::Contentful::Configuration class.
    attr_accessor :store
  end

  def self.all_models
    WCC::Contentful::Model.constants(false).map { |k| WCC::Contentful::Model.const_get(k) }
  end

  ##
  # Finds an Entry or Asset by ID in the configured contentful space
  # and returns an initialized instance of the appropriate model type.
  #
  # Makes use of the configured {store}[rdoc-ref:WCC::Contentful::Model.store]
  # to access the Contentful CDN.
  def self.find(id, context = nil)
    return unless raw = store.find(id)

    content_type = content_type_from_raw(raw)

    const = WCC::Contentful::Model.const_get(constant_from_content_type(content_type))
    const.new(raw, context)
  end
end
