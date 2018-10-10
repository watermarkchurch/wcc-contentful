# frozen_string_literal: true

namespace :wcc_contentful do
  desc 'Validates content types in your space against the validations defined on your models'
  task :validate, :environment do |_t|
    # Ensure application models are loaded before we validate
    Rails.application.eager_load!

    client = Services.instance.management_client ||
      Services.instance.client

    content_types = client.content_types(limit: 1000).items

    content_types = WCC::Contentful::ModelValidators
      .transform_content_types_for_validation(content_types)

    errors = WCC::Contentful::Model.schema.call(content_types)
    raise WCC::Contentful::ValidationError, errors.errors unless errors.success?
  end
end
