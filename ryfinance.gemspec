# frozen_string_literal: true

require_relative "lib/ryfinance/version"

Gem::Specification.new do |spec|
  spec.name = "ryfinance"
  spec.version = Ryfinance::VERSION
  spec.authors = ["RYFinance contributors"]
  spec.email = ["maintainers@example.com"]

  spec.summary = "Ruby access to Yahoo Finance data with a yfinance-shaped API."
  spec.description = "RYFinance is a Ruby gem that ports the core user-facing workflow of Python's yfinance library: ticker history, quote info, corporate actions, options, search, and multi-ticker downloads."
  spec.homepage = "https://github.com/ryfinance/ryfinance"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/releases"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE.txt", "docs/**/*.md"]
  spec.bindir = "exe"
  spec.executables = []
  spec.require_paths = ["lib"]

  spec.add_dependency "csv", ">= 3.0", "< 4"
  spec.add_dependency "json", ">= 2.0", "< 3"
  spec.add_dependency "net-http", ">= 0.4", "< 1"
end
