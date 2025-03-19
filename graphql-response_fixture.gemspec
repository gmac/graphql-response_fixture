# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "graphql/response_fixture/version"

Gem::Specification.new do |spec|
  spec.name          = "graphql-response_fixture"
  spec.version       = GraphQL::ResponseFixture::VERSION
  spec.authors       = ["Greg MacWilliam"]
  spec.summary       = "Validate that a GraphQL response fixture matches its test query."
  spec.description   = "Validate that a GraphQL response fixture matches its test query."
  spec.homepage      = "https://github.com/gmac/graphql-response_fixture"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata    = {
    "homepage_uri" => "https://github.com/gmac/graphql-response_fixture",
    "changelog_uri" => "https://github.com/gmac/graphql-response_fixture/releases",
    "source_code_uri" => "https://github.com/gmac/graphql-response_fixture",
    "bug_tracker_uri" => "https://github.com/gmac/graphql-response_fixture/issues",
  }

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^test/})
  end
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "graphql", ">= 2.0.0"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "minitest", "~> 5.12"
end
