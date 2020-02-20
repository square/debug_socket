# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new

# enable ObjectSpace in jruby
ENV["JRUBY_OPTS"] ||= ""
ENV["JRUBY_OPTS"] += " --debug -X+O"

task default: %i[spec rubocop]
