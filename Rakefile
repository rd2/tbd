require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
    t.rspec_opts = '--exclude-pattern \'spec/**/*suite_spec.rb\''
end

task default: :spec

desc "Update Library Files"
task :libraries do
  puts "Updating Library Files"

  require "fileutils"

  libs = ["topolys", "osut", "oslg", "tbd"]
  lib_files = {}

  $LOAD_PATH.each do |load_path|
    libs.each do |l|
      if load_path.include?(l)
        lib_files[l] = Dir.glob(File.join(load_path, "#{l}/*.rb"))

        unless l == "topolys"
          lib_files[l].delete_if { |f| f.include?("version.rb") }
        end

        puts "#{l} lib files:"
        lib_files[l].each { |lf| puts "... #{lf}" }
        puts
      end
    end
  end

  dirs = Dir.glob(File.join(__dir__, "lib/measures/*"))

  dirs.each do |dir|
    lib_files.each do |l, files|
      files.each { |file| FileUtils.cp(file, "#{dir}/resources/.") }
    end
  end
end

desc "Update Measure"
task :measure do
  puts "Updating Measure"

  require "openstudio"
  require "open3"

  cli = OpenStudio.getOpenStudioCLI
  command = "#{cli} measure -t './lib/measures'"
  puts command
  out, err, ps = Open3.capture3({"BUNDLE_GEMFILE"=>nil}, command)
  raise "Failed to update measures\n\n#{out}\n\n#{err}" unless ps.success?
end
task :measure => [:libraries]

namespace "osm_suite" do
  desc "Clean OSM Test Suite"
  task :clean do
    puts "Cleaning OSM Test Suite"
    osm_suite_runs_dir = File.join(__dir__, "spec", "osm_suite_runs")
    FileUtils.rm_rf(osm_suite_runs_dir) if File.exists?(osm_suite_runs_dir)
  end

  desc "Run OSM Test Suite"
  RSpec::Core::RakeTask.new(:run) do |t|
    t.rspec_opts = "--pattern \'spec/tbd_osm_suite_spec.rb\'"
  end
  task :run => [:measure]
end

namespace "prototype_suite" do
  desc "Clean Prototype Test Suite"
  task :clean do
    puts "Cleaning Prototype Test Suite"
    prototype_suite_runs_dir = File.join(__dir__, "spec", "prototype_suite_runs")
    FileUtils.rm_rf(prototype_suite_runs_dir) if File.exists?(prototype_suite_runs_dir)
  end

  desc "Run Prototype Test Suite"
  RSpec::Core::RakeTask.new(:run) do |t|
    t.rspec_opts = "--pattern \'spec/tbd_prototype_suite_spec.rb\'"
  end
  task :run => [:measure]
end

desc "Clean All Test Suites"
task :suites_clean do
  puts "Cleaning All Test Suites"
end
task :suites_clean => ["osm_suite:clean", "prototype_suite:clean"]

desc "Run All Test Suites"
task :suites_run do
  puts "Running All Test Suites"
end
task :suites_run => ["osm_suite:run", "prototype_suite:run"]

# default spec test depends on updating measure and library files
task :spec => [:measure]
