# frozen_string_literal: true

# Constructs new connected RichTextRenderer instances w/ needed dependencies
class RichTextRendererFactory
  def initialize(implementation_class, services: WCC::Contentful::Services.instance)
    @implementation_class = implementation_class
    @services = services
  end

  def new(document)
    @implementation_class.new(document).tap do |renderer|
      # Inject any dependencies that the renderer needs (except itself to avoid infinite recursion)
      @services.inject_into(renderer, except: [:rich_text_renderer])
    end
  end

  def call(document)
    new(document).call
  end
end
