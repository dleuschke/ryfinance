# frozen_string_literal: true

require_relative "lib/ryfinance/version"

Gem::Specification.new do |spec|
  spec.name = "ryfinance"
  spec.version = Ryfinance::VERSION
  spec.authors = ["RYFinance contributors"]
  spec.email = ["maintainers@example.com"]

  spec.summary = "Ruby-first access to Yahoo Finance data."
  spec.description = "RYFinance is a Ruby-first gem that ports the core user-facing workflow of Python's yfinance library: ticker history, quote info, corporate actions, options, ETF and mutual fund data, search, lookup, WebSocket streaming, and multi-ticker downloads."
  spec.homepage = "https://github.com/dleuschke/ryfinance"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir["lib/**/*.rb", "README.md", "CHANGELOG.md", "LICENSE.txt", "docs/**/*.md"]
  spec.bindir = "exe"
  spec.executables = []
  spec.require_paths = ["lib"]

  spec.add_dependency "csv", ">= 3.0", "< 4"
  spec.add_dependency "json", ">= 2.0", "< 3"
  spec.add_dependency "net-http", ">= 0.4", "< 1"
  spec.add_dependency "async", ">= 2.0", "< 3"
  spec.add_dependency "async-websocket", ">= 0.25", "< 1"
  spec.add_dependency "base64", ">= 0.2", "< 1"
  spec.add_dependency "google-protobuf", ">= 4.0", "< 5"
end
