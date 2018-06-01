
# frozen_string_literal: true

##
# This module is included by all models and defines instance
# methods that are not dynamically generated.
module WCC::Contentful::ModelMethods
  def resolve(depth: 1, fields: nil, context: {})
    raise ArgumentError, "Depth must be > 0 (was #{depth})" unless depth && depth > 0

    fields = fields.map { |f| f.to_s.camelize(:lower) } if fields.present?

    fields ||= self.class::FIELDS

    typedef = self.class.content_type_definition
    links = fields.select { |f| %i[Asset Link].include?(typedef.fields[f].type) }
    links.each { |f| _resolve_field(f, depth, context) }
    self
  end

  def to_h(stack = nil)
    raise WCC::Contentful::CircularReferenceError, stack.join(' -> ') if stack&.include?(id)
    stack = [*stack, id]

    fields =
      self.class::FIELDS.each_with_object({}) do |field, h|
        if val = instance_variable_get('@' + field + '_resolved')
          val =
            if val.is_a? Array
              val.map { |v| v ? v.to_h(stack) : v }
            else
              val.to_h(stack)
            end
        end

        h[field] = val || instance_variable_get('@' + field)
      end

    {
      sys: { 'locale' => @sys.locale }.merge!(@raw['sys']),
      fields: fields
    }
  end

  def to_json
    to_h.to_json
  end

  private

  def _resolve_field(field_name, depth = 1, context = {})
    var_name = '@' + field_name
    return unless val = instance_variable_get(var_name)

    context[id] ||= self
    load =
      ->(raw) {
        id = raw.dig('sys', 'id')
        return context[id] if context.key?(id)
        m = context[id] =
              if raw.dig('sys', 'type') == 'Link'
                WCC::Contentful::Model.find(id)
              else
                content_type = content_type_from_raw(raw)
                const = WCC::Contentful::Model.resolve_constant(content_type)
                const.new(raw, context)
              end

        m.resolve(depth: depth - 1, context: context) if m && depth > 1
        m
      }

    val =
      if val.is_a? Array
        val.map { |v| load.call(v) if v }
      elsif val
        load.call(val)
      end

    instance_variable_set(var_name + '_resolved', val)
  end
end
