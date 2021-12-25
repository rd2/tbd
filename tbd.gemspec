lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "tbd/version"

Gem::Specification.new do |spec|
  spec.name          = "tbd"
  spec.version       = TBD::VERSION
  spec.platform      = Gem::Platform::RUBY
  spec.authors       = ["Denis Bourgeois & Dan Macumber"]
  spec.email         = ["denis@rd2.ca"]

  spec.summary       = ""
  spec.description   = ""
  spec.homepage      = "https://github.com/rd2/tbd"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/v#{spec.version}"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"

  spec.files         = "git ls-files -z".split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.add_dependency "topolys"

  if /^2.2/.match(RUBY_VERSION)
    spec.required_ruby_version = "~> 2.2.0"

    spec.add_development_dependency "bundler",        "~> 1.17.1"
    spec.add_development_dependency "public_suffix",  "~> 3.1.1"
    spec.add_development_dependency "json-schema",    "~> 2.7.0"
    spec.add_development_dependency "parallel",       "~> 1.19.2"
    spec.add_development_dependency "rake",           "~> 12.3"
    spec.add_development_dependency "rspec",          "~> 3.7.0"
    spec.add_development_dependency "rubocop",        "~> 0.54.0"
    spec.add_development_dependency "yard",           "~> 0.9"

    spec.add_development_dependency "openstudio-common-measures", "~> 0.1.2"
    spec.add_development_dependency "openstudio-model-articulation", "~> 0.1.1"
  elsif /^2.5/.match(RUBY_VERSION)
    spec.required_ruby_version = "~> 2.5.0"

    spec.add_development_dependency "bundler",        "~> 2.1"
    spec.add_development_dependency "public_suffix",  "~> 3.1.1"
    spec.add_development_dependency "json-schema",    "~> 2.7.0"
    spec.add_development_dependency "parallel",       "~> 1.19.2"
    spec.add_development_dependency "rake",           "~> 13.0"
    spec.add_development_dependency "rspec",          "~> 3.9"
    spec.add_development_dependency "rubocop",        "~> 1.15.0"
    spec.add_development_dependency "yard",           "~> 0.9"

    spec.add_development_dependency "openstudio-common-measures", "~> 0.2.1"
    spec.add_development_dependency "openstudio-model-articulation", "~> 0.3.1"
  else
    spec.required_ruby_version = "~> 2.7.0"

    spec.add_development_dependency "bundler",        "~> 2.1"
    spec.add_development_dependency "public_suffix",  "~> 3.1.1"
    spec.add_development_dependency "json-schema",    "~> 2.7.0"
    spec.add_development_dependency "parallel",       "~> 1.19.2"
    spec.add_development_dependency "rake",           "~> 13.0"
    spec.add_development_dependency "rspec",          "~> 3.9"
    spec.add_development_dependency "rubocop",        "~> 1.15.0"
    spec.add_development_dependency "yard",           "~> 0.9"

    spec.add_development_dependency "openstudio-common-measures", "~> 0.5.0"
    spec.add_development_dependency "openstudio-model-articulation", "~> 0.5.0"
  end
end
