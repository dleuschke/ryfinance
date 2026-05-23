require "rake/testtask"
require_relative "lib/ryfinance/version"

Rake::TestTask.new(:test) do |task|
  task.libs << "lib" << "test"
  task.pattern = "test/**/*_test.rb"
end

namespace :test do
  desc "Run opt-in live Yahoo smoke tests"
  Rake::TestTask.new(:live) do |task|
    task.libs << "lib" << "test"
    task.pattern = "test/live_smoke.rb"
  end
end

desc "Build the ryfinance gem"
task :build do
  sh "gem build ryfinance.gemspec"
end

namespace :release do
  desc "Check release metadata before publishing"
  task :check do
    version = Ryfinance::VERSION
    changelog = File.read("CHANGELOG.md")
    api_reference = File.read("docs/api.md")
    spec = Gem::Specification.load("ryfinance.gemspec")

    abort "CHANGELOG.md is missing an entry for #{version}" unless changelog.include?("## #{version}")
    abort "docs/api.md does not mention RYFinance #{version}" unless api_reference.include?("RYFinance #{version}")
    abort "ryfinance.gemspec version does not match #{version}" unless spec.version.to_s == version
    abort "ryfinance.gemspec does not package CHANGELOG.md" unless spec.files.include?("CHANGELOG.md")
  end
end

desc "Run the same checks used by CI"
task ci: [:test, :build, "release:check"]

task default: :test
