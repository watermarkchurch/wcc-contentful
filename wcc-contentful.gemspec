
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "wcc/contentful/version"

Gem::Specification.new do |spec|
  spec.name          = "wcc-contentful"
  spec.version       = WCC::Contentful::VERSION
  spec.authors       = ["Watermark Dev"]
  spec.email         = ["dev@watermark.org"]

  spec.summary       = File.readlines("README.md").join
  spec.description   = %q{Contentful API wrapper library for Watermark apps}
  spec.homepage      = "https://github.com/watermarkchurch/wcc-contentful"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_dependency "contentful_model", "~> 0.2.0"
end
