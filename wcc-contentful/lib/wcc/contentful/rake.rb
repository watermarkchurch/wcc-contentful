# frozen_string_literal: true

Dir[File.join(File.dirname(__FILE__), '../../tasks/**/*.rake')]
  .each { |f| load f }
