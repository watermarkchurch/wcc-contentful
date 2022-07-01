# frozen_string_literal: true

WCC::Contentful::Sys =
  Struct.new(
    :id,
    :type,
    :locale,
    :space,
    :created_at,
    :updated_at,
    :revision,
    :context
  ) do
    # rubocop:disable Lint/ConstantDefinitionInBlock
    ATTRIBUTES = %i[
      id
      type
      locale
      space
      created_at
      updated_at
      revision
      context
    ].freeze
    # rubocop:enable Lint/ConstantDefinitionInBlock

    undef []=
    ATTRIBUTES.each { |a| __send__(:undef_method, "#{a}=") }
  end
