
# frozen_string_literal: true

module FixturesHelper
  def load_fixture(file_name)
    file = "#{File.dirname(__FILE__)}/fixtures/#{file_name}"
    return File.read(file) if File.exist?(file)
  end
end
