# frozen_string_literal: true

module WCC::Contentful::ModelAPI
  extend ActiveSupport::Concern

  included do
    include WCC::Contentful::Instrumentation

    # override class-level _instrumentation from WCC::Contentful::Instrumentation
    def self._instrumentation
      services.instrumentation
    end

    # We use a class var here because this is a global registry for all subclasses
    # of this namespace
    @@registry = {} # rubocop:disable Style/ClassVars
  end

  class_methods do
    attr_reader :configuration

    def configure(configuration = nil, schema: nil, services: nil)
      configuration ||= @configuration || WCC::Contentful::Configuration.new
      yield(configuration) if block_given?

      @schema = schema if schema
      @services = services if services
      @configuration = configuration.freeze

      WCC::Contentful::ModelBuilder.new(self.schema, namespace: self).build_models
      nil
    end

    def services
      @services ||=
        # try looking up the class heierarchy
        (superclass.services if superclass.respond_to?(:services)) ||
        # create it if we have a configuration
        WCC::Contentful::Services.new(configuration)
    end

    def store(preview = nil)
      ActiveSupport::Deprecation.warn('Use services.store instead')

      preview ? services.preview_store : services.store
    end

    def schema
      return @schema if @schema

      file = configuration.schema_file
      schema_json = JSON.parse(File.read(file))['contentTypes']
      unless schema_json
        raise ArgumentError, 'Please give either a JSON array of content types or file to load from'
      end

      @schema = WCC::Contentful::ContentTypeIndexer.from_json_schema(schema_json).types
    end

    # Finds an Entry or Asset by ID in the configured contentful space
    # and returns an initialized instance of the appropriate model type.
    #
    # Makes use of the {WCC::Contentful::Services#store configured store}
    # to access the Contentful CDN.
    def find(id, options: nil)
      options ||= {}
      store = options[:preview] ? services.preview_store : services.store
      raw =
        _instrumentation.instrument 'find.model.contentful.wcc', id: id, options: options do
          store.find(id, options.except(*WCC::Contentful::ModelMethods::MODEL_LAYER_CONTEXT_KEYS))
        end

      new_from_raw(raw, options) if raw.present?
    end

    # Creates a new initialized instance of the appropriate model type for the
    # given raw value.  The raw value must be the same format as returned from one
    # of the stores for a given object.
    def new_from_raw(raw, context = nil)
      content_type = WCC::Contentful::Helpers.content_type_from_raw(raw)
      const = resolve_constant(content_type)
      const.new(raw, context)
    end

    # Accepts a content type ID as a string and returns the Ruby constant
    # stored in the registry that represents this content type.
    def resolve_constant(content_type)
      raise ArgumentError, 'content_type cannot be nil' unless content_type

      const = @@registry[content_type]
      return const if const

      const_name = WCC::Contentful::Helpers.constant_from_content_type(content_type).to_s
      parent = try(:parent) || module_parent
      begin
        # The app may have defined a model and we haven't loaded it yet
        const = parent.const_missing(const_name)
        return const if const && const < self
      rescue NameError => e
        raise e unless e.message =~ /uninitialized constant (.+::)*#{const_name}/

        nil
      end

      # Autoloading couldn't find their model - we'll register our own.
      const = const_get(
        WCC::Contentful::Helpers.constant_from_content_type(content_type)
      )
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
    def register_for_content_type(content_type = nil, klass: nil)
      klass ||= self
      raise ArgumentError, "#{klass} must be a class constant!" unless klass.respond_to?(:new)

      content_type ||= WCC::Contentful::Helpers.content_type_from_constant(klass)

      @@registry[content_type] = klass
    end

    # Returns the current registry of content type names to constants.
    def registry
      return {} unless @@registry

      @@registry.dup.freeze
    end

    def reload!
      registry = self.registry
      registry.each do |(content_type, klass)|
        const_name = klass.name
        begin
          # the const_name is fully qualified so search from root
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
    def registered?(content_type)
      @@registry[content_type]
    end
  end
end
