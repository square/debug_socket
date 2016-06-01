# TODO switch back to bundler gem tasks when opensourcing
#require "bundler/gem_tasks"
require "sq/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

task default: [:spec, :rubocop]
