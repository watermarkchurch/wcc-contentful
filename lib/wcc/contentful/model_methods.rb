
# frozen_string_literal: true

##
# This module is included by all models and defines instance
# methods that are not dynamically generated.
module WCC::Contentful::ModelMethods
  def resolve(depth: 1, fields: nil)
    raise ArgumentError, "Depth must be > 0 (was #{depth})" unless depth && depth > 0

    fields = fields.map { |f| f.to_s.camelize(:lower) } if fields.present?

    _resolve(depth, fields)
  end

  def _resolve(depth, fields = nil, context = {})
    fields ||= self.class::FIELDS

    typedef = self.class.content_type_definition
    links = fields.select { |f| %i[Asset Link].include?(typedef.fields[f].type) }
    links.each { |f| _resolve_field(f, depth, context) }
  end

  private

  def _resolve_field(field_name, depth = 1, context = {})
    var_name = '@' + field_name
    return unless val = instance_variable_get(var_name)

    context[id] ||= self
    load =
      ->(id) {
        return context[id] if context.key?(id)
        m = context[id] = WCC::Contentful::Model.find(id)

        m._resolve(depth - 1, nil, context) if m && depth > 1
        m
      }

    val =
      if val.is_a? Array
        val.map { |v| load.call(v.dig('sys', 'id')) }
      else
        load.call(val.dig('sys', 'id'))
      end

    instance_variable_set(var_name + '_resolved', val)
  end
end
