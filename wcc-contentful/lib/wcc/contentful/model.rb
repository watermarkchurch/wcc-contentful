# typed: true
# frozen_string_literal: true

# This is the top layer of the WCC::Contentful gem.  It exposes an API by which
# you can query for data from Contentful.  The API is only accessible after calling
# WCC::Contentful.init!
#
# The WCC::Contentful::Model class is the base class for all auto-generated model
# classes.  A model class represents a content type inside Contentful.  For example,
# the "page" content type is represented by a class named WCC::Contentful::Model::Page
#
# This WCC::Contentful::Model::Page class exposes the following API methods:
# * {WCC::Contentful::ModelSingletonMethods#find Page.find(id)}
#   finds a single Page by it's ID
# * {WCC::Contentful::ModelSingletonMethods#find_by Page.find_by(field: <value>)}
#   finds a single Page with the matching value for the specified field
# * {WCC::Contentful::ModelSingletonMethods#find_all Page.find_all(field: <value>)}
#   finds all instances of Page with the matching value for the specified field.
#   It returns a lazy iterator of Page objects.
#
# The returned objects are instances of WCC::Contentful::Model::Page, or whatever
# constant exists in the registry for the page content type.  You can register
# custom types to be instantiated for each content type.  If a Model is subclassed,
# the subclass is automatically registered.  This allows you to put models in your
# app's `app/models` directory:
#
#    class Page < WCC::Contentful::Model::Page; end
#
# and then use the API via those models:
#
#    # this returns a ::Page, not a WCC::Contentful::Model::Page
#    Page.find_by(slug: 'foo')
#
# Furthermore, anytime links are automatically resolved, the registered classes will
# be used:
#
#    Menu.find_by(name: 'home').buttons.first.linked_page # is a ::Page
#
# @api Model
class WCC::Contentful::Model
  extend WCC::Contentful::Helpers

  # The Model base class maintains a registry which is best expressed as a
  # class var.
  # rubocop:disable Style/ClassVars

  class << self
    include WCC::Contentful::ServiceAccessors

    def const_missing(name)
      raise WCC::Contentful::ContentTypeNotFoundError,
        "Content type '#{content_type_from_constant(name)}' does not exist in the space"
    end
  end

  @@registry = {}

  # Finds an Entry or Asset by ID in the configured contentful space
  # and returns an initialized instance of the appropriate model type.
  #
  # Makes use of the {WCC::Contentful::Services#store configured store}
  # to access the Contentful CDN.
  def self.find(id, context = nil)
    return unless raw = store.find(id)

    new_from_raw(raw, context)
  end

  # Creates a new initialized instance of the appropriate model type for the
  # given raw value.  The raw value must be the same format as returned from one
  # of the stores for a given object.
  def self.new_from_raw(raw, context = nil)
    content_type = content_type_from_raw(raw)
    const = resolve_constant(content_type)
    const.new(raw, context)
  end

  # Accepts a content type ID as a string and returns the Ruby constant
  # stored in the registry that represents this content type.
  def self.resolve_constant(content_type)
    raise ArgumentError, 'content_type cannot be nil' unless content_type

    const = @@registry[content_type]
    return const if const

    const_name = constant_from_content_type(content_type).to_s
    begin
      # The app may have defined a model and we haven't loaded it yet
      const = Object.const_missing(const_name)
      return const if const && const < WCC::Contentful::Model
    rescue NameError => e
      raise e unless e.message =~ /uninitialized constant #{const_name}/

      nil
    end

    # Autoloading couldn't find their model - we'll register our own.
    const = WCC::Contentful::Model.const_get(constant_from_content_type(content_type))
    register_for_content_type(content_type, klass: const)
  end

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

  # Returns the current registry of content type names to constants.
  def self.registry
    return {} unless @@registry

    @@registry.dup.freeze
  end

  def self.reload!
    registry = self.registry
    registry.each do |(content_type, klass)|
      const_name = klass.name
      begin
        const = Object.const_missing(const_name)
        register_for_content_type(content_type, klass: const) if const
      rescue NameError => e
        msg = "Error when reloading constant #{const_name} - #{e}"
        if defined?(Rails) && Rails.logger
          Rails.logger.error msg
        else
          puts msg
        end
      end
    end
  end

  # Checks if a content type has already been registered to a class and returns
  # that class.  If nil, the generated WCC::Contentful::Model::{content_type} class
  # will be resolved for this content type.
  def self.registered?(content_type)
    @@registry[content_type]
  end
end

# rubocop:enable Style/ClassVars
