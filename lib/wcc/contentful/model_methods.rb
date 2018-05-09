
# frozen_string_literal: true

##
# This module is included by all models and defines instance
# methods that are not dynamically generated.
module WCC::Contentful::ModelMethods
  def resolve(**options)
    depth = options[:depth] ||= 1
    raise ArgumentError, "Depth must be > 1 (was #{depth})" unless depth > 0

    fields = options.delete(:fields)
    fields = fields.present? ? fields.map { |f| f.to_s.camelize(:lower) } : self.class::FIELDS

    typedef = self.class.content_type_definition
    links = fields.select { |f| %i[Asset Link].include?(typedef.fields[f].type) }
    options[id] = self
    links.each { |f| _resolve_field(f, options) }
  end

  private

  def _resolve_field(field_name, context = {})
    var_name = '@' + field_name
    return unless val = instance_variable_get(var_name)

    depth = context.delete(:depth) || 1
    load =
      ->(id) {
        return context[id] if context[id]
        m = WCC::Contentful::Model.find(id)
        m.resolve({ depth: depth - 1 }.merge!(context)) if depth > 1
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
