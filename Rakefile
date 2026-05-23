require "rake/testtask"

Rake::TestTask.new(:test) do |task|
  task.libs << "lib" << "test"
  task.pattern = "test/**/*_test.rb"
end

desc "Build the ryfinance gem"
task :build do
  sh "gem build ryfinance.gemspec"
end

task default: :test

