require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = "--exclude-pattern \'spec/**/*suite_spec.rb\'"
end

task default: :spec

desc "Update Library Files"
task :libraries do
  # puts "Updating Library Files"

  require "fileutils"

  libs  = ["topolys", "osut", "oslg", "tbd"]
  files = {}
  
  $:.each do |path|
    libs.each do |l|
      next unless path.include?(l)

      files[l] = Dir.glob(File.join(path, "#{l}/*.rb"))
      files[l].delete_if { |f| f.include?("version.rb") }  unless l == "topolys"
      # puts "#{l} lib files:"
      # files[l].each { |lf| puts "... #{lf}" }
      # puts
    end
  end

  dirs = Dir.glob(File.join(__dir__, "lib/measures/*"))

  dirs.each do |dir|
    files.values.each do |items|
      items.each { |file| FileUtils.cp(file, "#{dir}/resources/.") }
    end
  end
end

desc "Update Measure"
task measure: [:libraries] do
  # puts "Updating Measure"

  require "openstudio"
  require "open3"

  cli          = OpenStudio.getOpenStudioCLI
  command      = "#{cli} measure -t './lib/measures'"
  out, err, ps = Open3.capture3({ "BUNDLE_GEMFILE" => nil }, command)
  raise "Failed to update measures\n\n#{out}\n\n#{err}"       unless ps.success?
end

task spec: [:measure] # default spec test depends on updating measure, lib files
