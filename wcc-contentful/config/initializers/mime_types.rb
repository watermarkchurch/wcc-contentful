# frozen_string_literal: true

# https://www.contentful.com/developers/docs/references/content-management-api/
Mime::Type.register 'application/vnd.contentful.management.v1+json', :json_mgmt
# https://www.contentful.com/developers/docs/references/content-delivery-api/
Mime::Type.register 'application/vnd.contentful.delivery.v1+json',   :json_cda

Mime::Type.register 'application/json', :json, [
  'application/vnd.contentful.management.v1+json',
  'application/vnd.contentful.delivery.v1+json',
  'application/json'
]
