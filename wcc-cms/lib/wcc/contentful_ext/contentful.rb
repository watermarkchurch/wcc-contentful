# frozen_string_literal: true

gem 'wcc-contentful'
require_relative './contentful/model_validators'

# The root namespace of the wcc-contentful gem
#
# Initialize the gem with the `configure` and `init` methods inside your
# initializer.
module WCC::Contentful

  # Runs validations over the content types returned from the Contentful API.
  # Validations are configured on predefined model classes using the
  # `validate_field` directive.  Example:
  #    validate_field :top_button, :Link, :optional, link_to: 'menuButton'
  # This results in a WCC::Contentful::ValidationError
  # if the 'topButton' field in the 'menu' content type is not a link.
  def self.validate_models!
    # Ensure application models are loaded before we validate
    Dir[Rails.root.join('app/models/**/*.rb')].each { |file| require file } if defined?(Rails)

    content_types = WCC::Contentful::ModelValidators.transform_content_types_for_validation(
      @content_types
    )
    errors = WCC::Contentful::Model.schema.call(content_types)
    raise WCC::Contentful::ValidationError, errors.errors unless errors.success?
  end
end
