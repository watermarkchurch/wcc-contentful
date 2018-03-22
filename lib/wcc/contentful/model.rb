
# frozen_string_literal: true

class WCC::Contentful::Model
  extend WCC::Contentful::Helpers
  extend WCC::Contentful::ModelValidators

  # The Model base class maintains a registry which is best expressed as a
  # class var.
  # rubocop:disable Style/ClassVars

  class << self
    ##
    # The configured store which executes all model queries against either the
    # Contentful CDN or a locally-downloaded copy.
    #
    # See the {sync_store}[rdoc-ref:WCC::Contentful::Configuration.sync_store] parameter
    # on the WCC::Contentful::Configuration class.
    attr_accessor :store
  end

  @@registry = {}

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

    const = @@registry[content_type]
    const ||= WCC::Contentful::Model.const_get(constant_from_content_type(content_type))

    const.new(raw, context)
  end

  def self.register_mapping(content_type_mapping)
    content_type_mapping.each do |name, const|
      raise ArgumentError, "#{name} must be a string!" unless name.is_a?(String)
      unless const.respond_to?(:new)
        raise ArgumentError, "#{content_type_mapping} must be a class constant!"
      end
    end
    @@registry.merge!(content_type_mapping)
  end

  def self.register_for_content_type(content_type = nil, klass: nil)
    klass ||= self
    raise ArgumentError, "#{klass} must be a class constant!" unless klass.respond_to?(:new)
    content_type ||= content_type_from_constant(klass)
    raise ArgumentError, "Cannot determine content type for constant #{klass}" unless content_type

    puts "registering #{klass} for #{content_type}"
    @@registry[content_type] = klass
  end

  def self.register_model_class(klass)
    raise ArgumentError, "#{klass} must be a class constant!" unless klass.respond_to?(:new)
    content_type = content_type_from_constant(klass)
    raise ArgumentError, "Cannot determine content type for constant #{klass}" unless content_type

    @@registry[content_type] = klass
  end

  def self.registry
    return {} unless @@registry
    @@registry.dup.freeze
  end

  def self.registered?(content_type)
    @@registry.key?(content_type)
  end
end

# rubocop:enable Style/ClassVars
