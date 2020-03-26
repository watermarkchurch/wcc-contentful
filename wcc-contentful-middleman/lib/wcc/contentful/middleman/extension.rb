

class WCC::Contentful::Middleman::Extension < ::Middleman::Extension
  option :my_option, 'default', 'An example option'

  def initialize(app, options_hash={}, &block)
    # Call super to build options from the options_hash
    super

    # Require libraries only when activated
    require 'wcc/contentful'

    # set up your extension
    # puts options.my_option
  end

  def after_configuration
    # Do something
    WCC::Contentful.init!
  end

  # A Sitemap Manipulator
  # def manipulate_resource_list(resources)
  # end

  # helpers do
  #   def a_helper
  #   end
  # end
end