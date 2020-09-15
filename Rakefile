require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = '--exclude-pattern \'spec/**/*suite_spec.rb\''
end

require "rubocop/rake_task"
RuboCop::RakeTask.new

task default: :spec

desc "Update Library Files"
task :update_library_files do
  puts "Updating Library Files"

  require "fileutils"

  lib_files = []
  $:.each do |load_path|
    if /topolys/.match(load_path)
      lib_files.concat( Dir.glob(File.join(load_path, "topolys/*.rb")) )
    elsif /tbd/.match(load_path)
      lib_files.concat( Dir.glob(File.join(load_path, "*.rb")) )
      lib_files.concat( Dir.glob(File.join(load_path, "tbd/*.rb")) )
    end
  end
  puts lib_files

  measure_resources = Dir.glob("./lib/measures/*/resources")

  lib_files.each do |lib_file|
    measure_resources.each do |measure_resource|
      FileUtils.cp(lib_file, "#{measure_resource}/.")
    end
  end
end

desc "Update Measure"
task :update_measure do
  puts "Updating Measure"

  require 'openstudio'

  cli = OpenStudio.getOpenStudioCLI
  command = "#{cli} measure -t './measures'"
  system({"BUNDLE_GEMFILE"=>nil}, command)
end
task :update_measure => [:update_library_files]

namespace "osm_suite" do
  desc "Clean OSM Test Suite"
  task :clean do
    puts "Cleaning OSM Test Suite"
    osm_suite_runs_dir = File.join(File.dirname(__FILE__), 'spec', 'osm_suite_runs')
    FileUtils.rm_rf(osm_suite_runs_dir) if File.exists?(osm_suite_runs_dir)
  end

  desc "Run OSM Test Suite"
  RSpec::Core::RakeTask.new(:run) do |t|
    t.rspec_opts = '--pattern \'spec/tbd_osm_suite_spec.rb\''
  end
  task :run => [:update_measure]
end

namespace "prototype_suite" do
  desc "Clean Prototype Test Suite"
  task :clean do
    puts "Cleaning Prototype Test Suite"
    prototype_suite_runs_dir = File.join(File.dirname(__FILE__), 'spec', 'prototype_suite_runs')
    FileUtils.rm_rf(prototype_suite_runs_dir) if File.exists?(prototype_suite_runs_dir)
  end

  desc "Run Prototype Test Suite"
  RSpec::Core::RakeTask.new(:run) do |t|
    t.rspec_opts = '--pattern \'spec/tbd_prototype_suite_spec.rb\''
  end
  task :run => [:update_measure]
end

task :clean_suites => ["osm_suite:clean", "prototype_suite:clean"]
task :run_suites => ["osm_suite:run", "prototype_suite:run"]

# default spec test depends on updating measure and library files
task :spec => [:update_measure]
