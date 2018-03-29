
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

    def const_missing(name)
      raise WCC::Contentful::ContentTypeNotFoundError,
        "Content type '#{content_type_from_constant(name)}' does not exist in the space"
    end
  end

  @@registry = {}

  def self.all_models
    # TODO: this needs to use the registry but it's OK for now cause we only
    # use it in specs
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

    unless const = @@registry[content_type]
      begin
        # The app may have defined a model and we haven't loaded it yet
        const = Object.const_missing(constant_from_content_type(content_type).to_s)
      rescue NameError
        nil
      end
    end
    unless const
      # Autoloading couldn't find their model - we'll register our own.
      const = WCC::Contentful::Model.const_get(constant_from_content_type(content_type))
      register_for_content_type(content_type, klass: const)
    end

    const.new(raw, context)
  end

  ##
  # Registers a class constant to be instantiated when resolving an instance
  # of the given content type.  This automatically happens for the first subclass
  # of a generated model type, example:
  #
  #   class MyMenu < WCC::Contentful::Model::Menu
  #   end
  #
  # In the above case, instances of MyMenu will be instantiated whenever a 'menu'
  # content type is resolved.
  # The mapping can be made explicit with the optional parameters.  Example:
  #
  #   class MyFoo < WCC::Contentful::Model::Foo
  #     register_for_content_type 'bar' # MyFoo is assumed
  #   end
  #
  #   # in initializers/wcc_contentful.rb
  #   WCC::Contentful::Model.register_for_content_type('bar', klass: MyFoo)
  def self.register_for_content_type(content_type = nil, klass: nil)
    klass ||= self
    raise ArgumentError, "#{klass} must be a class constant!" unless klass.respond_to?(:new)
    content_type ||= content_type_from_constant(klass)

    @@registry[content_type] = klass
  end

  ##
  # Returns the current registry of content type names to constants.
  def self.registry
    return {} unless @@registry
    @@registry.dup.freeze
  end

  ##
  # Checks if a content type has already been registered to a class and returns
  # that class.  If nil, the generated WCC::Contentful::Model::{content_type} class
  # will be resolved for this content type.
  def self.registered?(content_type)
    @@registry[content_type]
  end
end

# rubocop:enable Style/ClassVars
