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
  # Keep the async WebSocket stack compatible with the gem's Ruby 3.1 floor.
  spec.add_dependency "async", ">= 2.10", "< 2.25"
  spec.add_dependency "async-http", ">= 0.76", "< 0.89"
  spec.add_dependency "async-pool", ">= 0.9", "< 0.10"
  spec.add_dependency "async-websocket", ">= 0.25", "< 0.31"
  spec.add_dependency "console", ">= 1.29", "< 1.31"
  spec.add_dependency "io-endpoint", ">= 0.14", "< 0.18"
  spec.add_dependency "io-event", ">= 1.11", "< 1.12"
  spec.add_dependency "io-stream", ">= 0.6", "< 0.7"
  spec.add_dependency "metrics", ">= 0.12", "< 0.13"
  spec.add_dependency "protocol-http", ">= 0.49", "< 0.50"
  spec.add_dependency "protocol-http1", ">= 0.30", "< 0.31"
  spec.add_dependency "protocol-http2", ">= 0.22", "< 0.23"
  spec.add_dependency "protocol-rack", ">= 0.7", "< 0.12"
  spec.add_dependency "protocol-websocket", ">= 0.17", "< 0.18"
  spec.add_dependency "traces", ">= 0.15", "< 0.16"
  spec.add_dependency "base64", ">= 0.2", "< 1"
  spec.add_dependency "google-protobuf", ">= 4.0", "< 5"
end
