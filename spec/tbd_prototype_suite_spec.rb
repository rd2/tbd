require "open3"
require "json"
require "openstudio"
require 'parallel'

def get_clean_env
  new_env = {}
  new_env["BUNDLER_ORIG_MANPATH"] = nil
  new_env["BUNDLER_ORIG_PATH"] = nil
  new_env["BUNDLER_VERSION"] = nil
  new_env["BUNDLE_BIN_PATH"] = nil
  new_env["RUBYLIB"] = nil
  new_env["RUBYOPT"] = nil
  new_env["GEM_PATH"] = nil
  new_env["GEM_HOME"] = nil
  new_env["BUNDLE_GEMFILE"] = nil
  new_env["BUNDLE_PATH"] = nil
  new_env["BUNDLE_WITHOUT"] = nil

  return new_env
end

RSpec.describe TBD do

  # set force_clean to true if you want to force simulations to re-run
  # can also delete the test suite dir
  #force_clean = true
  force_clean = false

  # number of processors to use
  nproc = [1, Parallel.processor_count - 2].max

  template_osw = nil
  template_osw_file = File.join(__dir__, 'files/osws/prototype_suite.osw')
  File.open(template_osw_file, 'r') do |f|
    template_osw = JSON.parse(f.read, {symbolize_names: true})
  end

  test_suite_runs_dir = File.join(__dir__, 'prototype_suite_runs')
  if force_clean
    FileUtils.rm_rf(test_suite_runs_dir) if File.exists?(test_suite_runs_dir)
  end
  FileUtils.mkdir_p(test_suite_runs_dir)

  building_types = []
  #building_types << 'SecondarySchool'
  #building_types << 'PrimarySchool'
  building_types << 'SmallOffice'
  #building_types << 'MediumOffice'
  #building_types << 'LargeOffice'
  #building_types << 'SmallHotel'
  #building_types << 'LargeHotel'
  building_types << 'Warehouse'
  #building_types << 'RetailStandalone'
  #building_types << 'RetailStripmall'
  #building_types << 'QuickServiceRestaurant'
  #building_types << 'FullServiceRestaurant'
  #building_types << 'MidriseApartment'
  #building_types << 'HighriseApartment'
  #building_types << 'Hospital'
  #building_types << 'Outpatient'

  tbd_options = []
  tbd_options << "skip"
  #tbd_options << "poor (BETBG)"
  #tbd_options << "regular (BETBG)"
  #tbd_options << "efficient (BETBG)"
  tbd_options << "spandrel (BETBG)"
  tbd_options << "spandrel HP (BETBG)"
  tbd_options << "code (Quebec)"
  tbd_options << "uncompliant (Quebec)"
  tbd_options << "(non thermal bridging)"

  combos = []
  building_types.each do |building_type|
    tbd_options.each do |tbd_option|
      combos << [building_type, tbd_option]
    end
  end

  Parallel.each(combos, in_threads: nproc) do |combo|
    building_type = combo[0]
    tbd_option = combo[1]
    test_case_name = "#{building_type}_#{tbd_option}"

    test_dir = File.join(test_suite_runs_dir, test_case_name)
    if File.exist?(test_dir) && File.exist?(File.join(test_dir, 'out.osw'))
      next
    end

    FileUtils.mkdir_p(test_dir)

    osw = Marshal.load( Marshal.dump(template_osw) )
    osw[:steps][0][:arguments][:building_type] = building_type
    if tbd_option == 'skip'
      osw[:steps][1][:arguments][:__SKIP__] = true
    else
      osw[:steps][1][:arguments][:option] = tbd_option
    end

    osw_file = File.join(test_dir, 'in.osw')
    File.open(osw_file, 'w') do |f|
      f << JSON.pretty_generate(osw)
    end

    command = "'#{OpenStudio::getOpenStudioCLI}' run -w '#{osw_file}'"
    #puts command
    stdout_str, stderr_str, status = Open3.capture3(get_clean_env, command)

  end

  # compare results
  building_types.each do |building_type|
    results = {}
    tbd_options.each do |tbd_option|
      test_case_name = "#{building_type}_#{tbd_option}"
      out_osw_file = File.join(test_suite_runs_dir, test_case_name, 'out.osw')

      results[tbd_option] = {}
      File.open(out_osw_file, 'r') do |f|
        results[tbd_option] = JSON.parse(f.read, {symbolize_names: true})
      end
    end

    it "compares results for #{building_type}" do
      puts "building_type = #{building_type}"
      tbd_options.each do |tbd_option|
        puts "  tbd_option = #{tbd_option}"
        completed_status = results[tbd_option][:completed_status]
        expect(completed_status).to eq("Success")
        tbd_result = results[tbd_option][:steps][1][:result]
        os_result = results[tbd_option][:steps][2][:result]
        total_site_energy = os_result[:step_values].select{|v| v[:name] == 'total_site_energy'}
        puts "    tbd_success = #{tbd_result[:step_result]}"
        puts "    os_success = #{os_result[:step_result]}"
        puts "    total_site_energy = #{total_site_energy[0][:value]}"
      end
    end
  end

end
