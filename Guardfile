# A guardfile for making Danger Plugins
# For more info see https://github.com/guard/guard#readme

# To run, use `bundle exec guard`.

group :red_green_refactor, halt_on_fail: true do
  guard :rspec, cmd: 'bundle exec rspec' do
    require 'guard/rspec/dsl'
    dsl = Guard::RSpec::Dsl.new(self)

    # RSpec files
    rspec = dsl.rspec
    watch(rspec.spec_helper) { rspec.spec_dir }
    watch(rspec.spec_support) { rspec.spec_dir }
    watch(rspec.spec_files)

    # Ruby files
    ruby = dsl.ruby
    watch(%r{lib/wcc/(.+)\.rb$}) { |m| rspec.spec.call("wcc/#{m[1]}") }
    watch(%r{lib/generators/(.+)\.rb$}) { |m| rspec.spec.call("generators/#{m[1]}") }
  end

  guard :rubocop, cli: ['--display-cop-names'] do
    watch(%r{.+\.rb$})
    watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
  end
end

group :autofix do
  guard :rubocop, all_on_start: false, cli: ['--auto-correct', '--display-cop-names'] do
    watch(%r{.+\.rb$})
    watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| File.dirname(m[0]) }
  end
end

scope group: :red_green_refactor
