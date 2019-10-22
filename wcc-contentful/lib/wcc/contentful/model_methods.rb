# frozen_string_literal: true

# This module is included by all {WCC::Contentful::Model models} and defines instance
# methods that are not dynamically generated.
#
# @api Model
module WCC::Contentful::ModelMethods
  include WCC::Contentful::Instrumentation

  # The set of options keys that are specific to the Model layer and shouldn't
  # be passed down to the Store layer.
  MODEL_LAYER_CONTEXT_KEYS = %i[
    preview
    backlinks
  ].freeze

  # Resolves all links in an entry to the specified depth.
  #
  # Each link in the entry is recursively retrieved from the store until the given
  # depth is satisfied.  Depth resolution is unlimited, circular references will
  # be resolved to the same object.
  #
  # @param [Fixnum] depth how far to recursively resolve.  Must be >= 1
  # @param [Array<String, Symbol>] fields (optional) A subset of fields whose
  #   links should be resolved.  Defaults to all fields.
  # @param [Hash] context passed to the resolved model's `new` function to provide
  #   contextual information ex. current locale.
  #   See {WCC::Contentful::ModelSingletonMethods#find Model#find}, {WCC::Contentful::Sys#context}
  # @param [Hash] options The remaining optional parameters, defined below
  # @option options [Symbol] circular_reference Determines how circular references are
  #   handled.  `:raise` causes a {WCC::Contentful::CircularReferenceError} to be raised,
  #   `:ignore` will cause the field to remain unresolved, and any other value (or nil)
  #   will cause the field to point to the previously resolved ruby object for that ID.
  def resolve(depth: 1, fields: nil, context: sys.context.to_h, **options)
    raise ArgumentError, "Depth must be > 0 (was #{depth})" unless depth && depth > 0
    return self if resolved?(depth: depth, fields: fields)

    fields = fields.map { |f| f.to_s.camelize(:lower) } if fields.present?
    fields ||= self.class::FIELDS

    typedef = self.class.content_type_definition
    links = fields.select { |f| %i[Asset Link].include?(typedef.fields[f].type) }

    raw_link_ids =
      links.map { |field_name| raw.dig('fields', field_name, sys.locale) }
        .flat_map do |raw_value|
          _try_map(raw_value) { |v| v.dig('sys', 'id') if v.dig('sys', 'type') == 'Link' }
        end
    raw_link_ids = raw_link_ids.compact
    backlinked_ids = (context[:backlinks]&.map { |m| m.id } || [])

    has_unresolved_raw_links = (raw_link_ids - backlinked_ids).any?
    if has_unresolved_raw_links
      raw =
        _instrument 'resolve', id: id, depth: depth, backlinks: backlinked_ids do
          # use include param to do resolution
          self.class.store(context[:preview])
            .find_by(content_type: self.class.content_type,
                     filter: { 'sys.id' => id },
                     options: context.except(*MODEL_LAYER_CONTEXT_KEYS).merge!({
                       include: [depth, 10].min
                     }))
        end
      unless raw
        raise WCC::Contentful::ResolveError, "Cannot find #{self.class.content_type} with ID #{id}"
      end

      @raw = raw.freeze
      links.each { |f| instance_variable_set('@' + f, raw.dig('fields', f, sys.locale)) }
    end

    links.each { |f| _resolve_field(f, depth, context, options) }
    self
  end

  # Determines whether the object has been resolved up to the prescribed depth.
  def resolved?(depth: 1, fields: nil)
    raise ArgumentError, "Depth must be > 0 (was #{depth})" unless depth && depth > 0

    fields = fields.map { |f| f.to_s.camelize(:lower) } if fields.present?
    fields ||= self.class::FIELDS

    typedef = self.class.content_type_definition
    links = fields.select { |f| %i[Asset Link].include?(typedef.fields[f].type) }
    links.all? { |f| _resolved_field?(f, depth) }
  end

  # Turns the current model into a hash representation as though it had been retrieved from
  # the Contentful API.
  #
  # This differs from `#raw` in that it recursively includes the `#to_h`
  # of resolved links.  It also sets the fields to the value for the entry's `#sys.locale`,
  # as though the entry had been retrieved from the API with `locale={#sys.locale}` rather
  # than `locale=*`.
  def to_h(stack = nil)
    raise WCC::Contentful::CircularReferenceError.new(stack, id) if stack&.include?(id)

    stack = [*stack, id]
    typedef = self.class.content_type_definition
    fields =
      typedef.fields.each_with_object({}) do |(name, field_def), h|
        if field_def.type == :Link || field_def.type == :Asset
          if _resolved_field?(name, 0)
            val = public_send(name)
            val =
              _try_map(val) { |v| v.to_h(stack) }
          else
            ids = field_def.array ? public_send("#{name}_ids") : public_send("#{name}_id")
            val =
              _try_map(ids) do |id|
                {
                  'sys' => {
                    'type' => 'Link',
                    'linkType' => field_def.type == :Asset ? 'Asset' : 'Entry',
                    'id' => id
                  }
                }
              end
          end
        else
          val = public_send(name)
          val = _try_map(val) { |v| v.respond_to?(:to_h) ? v.to_h.stringify_keys! : v }
        end

        h[name] = val
      end

    {
      'sys' => { 'locale' => @sys.locale }.merge!(@raw['sys']),
      'fields' => fields
    }
  end

  delegate :to_json, to: :to_h

  protected

  def _instrumentation_event_prefix
    '.model.contentful.wcc'
  end

  private

  def _resolve_field(field_name, depth = 1, context = {}, options = {})
    return if depth <= 0

    var_name = '@' + field_name
    return unless val = instance_variable_get(var_name)

    context = sys.context.to_h.merge(context)
    # load a single link from a raw link or entry, by either finding it via the API
    # or instantiating it directly from a raw entry
    load =
      ->(raw) {
        id = raw.dig('sys', 'id')
        already_resolved = context[:backlinks]&.find { |m| m.id == id }

        new_context = context.merge({ backlinks: [self, *context[:backlinks]].freeze })

        if already_resolved && %i[ignore raise].include?(options[:circular_reference])
          raise WCC::Contentful::CircularReferenceError.new(
            new_context[:backlinks].map(&:id).reverse,
            id
          )
        end

        # Use the already resolved circular reference, or resolve a link, or
        # instantiate from already resolved raw entry data.
        m = already_resolved ||
          if raw.dig('sys', 'type') == 'Link'
            _instrument 'resolve',
              id: self.id, depth: depth, backlinks: context[:backlinks]&.map(&:id) do
              WCC::Contentful::Model.find(id, options: new_context)
            end
          else
            WCC::Contentful::Model.new_from_raw(raw, new_context)
          end

        m.resolve(depth: depth - 1, context: new_context, **options) if m && depth > 1
        m
      }

    begin
      val = _try_map(val) { |v| load.call(v) }

      instance_variable_set(var_name + '_resolved', val)
    rescue WCC::Contentful::CircularReferenceError
      raise unless options[:circular_reference] == :ignore
    end
  end

  def _resolved_field?(field_name, depth = 1)
    var_name = '@' + field_name
    raw = instance_variable_get(var_name)
    return true if raw.nil? || (raw.is_a?(Array) && raw.all?(&:nil?))
    return false unless val = instance_variable_get(var_name + '_resolved')
    return true if depth <= 1

    return val.resolved?(depth: depth - 1) unless val.is_a? Array

    val.all? { |i| i.nil? || i.resolved?(depth: depth - 1) }
  end

  def _try_map(val)
    if val.is_a? Array
      return val&.map do |item|
        yield item unless item.nil?
      end
    end

    yield val unless val.nil?
  end
end
