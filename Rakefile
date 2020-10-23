require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.verbose = true
  t.warning = true
  t.test_files = ["test/integration_test.rb"]
end

task :default => :test
