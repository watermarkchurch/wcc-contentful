# frozen_string_literal: true

require_relative './model_api'

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
  include WCC::Contentful::ModelAPI

  class << self
    def const_missing(name)
      type = WCC::Contentful::Helpers.content_type_from_constant(name)
      raise WCC::Contentful::ContentTypeNotFoundError,
        "Content type '#{type}' does not exist in the space"
    end
  end
end
