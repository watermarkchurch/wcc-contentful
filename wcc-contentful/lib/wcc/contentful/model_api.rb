# frozen_string_literal: true

module WCC::Contentful::ModelAPI
  extend ActiveSupport::Concern

  included do
    # We use a class var here because this is a global registry for all subclasses
    # of this namespace
    @@registry = {} # rubocop:disable Style/ClassVars
  end

  class_methods do
    def schema(schema_json = nil, file: nil)
      raise ArgumentError, 'Schema can only be set once!' if @schema && (schema_json || file)
      return @schema if @schema

      schema_json ||= JSON.parse(File.read(file))['contentTypes'] if file
      unless schema_json
        raise ArgumentError, 'Please give either a JSON array of content types or file to load from'
      end

      @schema = WCC::Contentful::ContentTypeIndexer.from_json_schema(schema_json).types
      WCC::Contentful::ModelBuilder.new(@schema, namespace: self).build_models
      @schema
    end

    def store(new_store = nil)
      if new_store.present?
        @store = new_store
      else
        @store
      end
    end

    def preview_store(new_store = nil)
      if new_store.present?
        @preview_store = new_store
      else
        @preview_store
      end
    end

    # Finds an Entry or Asset by ID in the configured contentful space
    # and returns an initialized instance of the appropriate model type.
    #
    # Makes use of the {WCC::Contentful::Services#store configured store}
    # to access the Contentful CDN.
    def find(id, options: nil)
      options ||= {}
      store = options[:preview] ? preview_store : self.store
      raw = store.find(id, options.except(*WCC::Contentful::ModelMethods::MODEL_LAYER_CONTEXT_KEYS))

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
      begin
        # The app may have defined a model and we haven't loaded it yet
        const = Object.const_missing(const_name)
        return const if const && const < WCC::Contentful::Model
      rescue NameError => e
        raise e unless e.message =~ /uninitialized constant #{const_name}/

        nil
      end

      # Autoloading couldn't find their model - we'll register our own.
      const = WCC::Contentful::Model.const_get(
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
