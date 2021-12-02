require_relative "lib/tomo/plugin/example/version"

Gem::Specification.new do |spec|
  spec.name = "example"
  spec.version = Tomo::Plugin::Example::VERSION
  spec.authors = ["Example Owner"]
  spec.email = ["owner@example.com"]

  spec.summary = ""
  spec.homepage = "https://github.com/mattbrictson/tomo-plugin"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/mattbrictson/tomo-plugin/issues",
    "changelog_uri" => "https://github.com/mattbrictson/tomo-plugin/releases",
    "source_code_uri" => "https://github.com/mattbrictson/tomo-plugin",
    "homepage_uri" => spec.homepage,
    "rubygems_mfa_required" => "true"
  }

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[LICENSE.txt README.md {exe,lib}/**/*]).reject { |f| File.directory?(f) }
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "tomo", "~> 1.0"
end
