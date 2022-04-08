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

  # number of processors to use
  nproc = [1, Parallel.processor_count - 2].max

  # Fetch 'OpenStudio Results' measure (if missing).
  measure = "openstudio_results"
  measures_pth = File.join(__dir__, "files/measures", measure)
  unless Dir.exist?(measures_pth)
    src_pth = ""
    $LOAD_PATH.each do |load_path|
      if load_path.include?("openstudio-common-measures")
        src_pth = File.join(load_path, "measures", measure)
      end
    end
    FileUtils.copy_entry src_pth, measures_pth
  end

  template_osw = nil
  template_osw_file = File.join(__dir__, 'files/osws/osm_suite.osw')
  File.open(template_osw_file, 'r') do |f|
    template_osw = JSON.parse(f.read, {symbolize_names: true})
  end

  osm_suite_runs_dir = File.join(__dir__, 'osm_suite_runs')
  FileUtils.mkdir_p(osm_suite_runs_dir)

  seed_osms = []
  # seed_osms << 'seb.osm'
  # seed_osms << 'test_seb.osm'
  # seed_osms << 'test_secondaryschool.osm'
  seed_osms << 'test_smalloffice.osm'
  seed_osms << 'test_warehouse.osm'

  weather_files = {}
  # weather_files['seb.osm'] = 'srrl_2013_amy.epw'
  # weather_files['test_seb.osm'] = 'srrl_2013_amy.epw'
  # weather_files['test_secondaryschool.osm'] = 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw'
  weather_files['test_smalloffice.osm'] = 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw'
  weather_files['test_warehouse.osm'] = 'USA_TX_El.Paso.Intl.AP.722700_TMY3.epw'

  tbd_options = []
  tbd_options << "skip"
  # tbd_options << "poor (BETBG)"
  # tbd_options << "regular (BETBG)"
  # tbd_options << "efficient (BETBG)"
  # tbd_options << "spandrel (BETBG)"
  tbd_options << "spandrel HP (BETBG)"
  tbd_options << "code (Quebec)"
  # tbd_options << "uncompliant (Quebec)"
  tbd_options << "(non thermal bridging)"

  combos = []
  seed_osms.each do |seed_osm|
    tbd_options.each do |tbd_option|
      combos << [seed_osm, tbd_option]
    end
  end

  Parallel.each(combos, in_threads: nproc) do |combo|
    seed_osm = combo[0]
    tbd_option = combo[1]
    test_case_name = "#{seed_osm}_#{tbd_option}".gsub('.', '_')

    test_dir = File.join(osm_suite_runs_dir, test_case_name)
    if File.exist?(test_dir) && File.exist?(File.join(test_dir, 'out.osw'))
      next
    end

    FileUtils.mkdir_p(test_dir)

    osw = Marshal.load( Marshal.dump(template_osw) )
    osw[:seed_file] = seed_osm
    osw[:weather_file] = weather_files[seed_osm]
    if tbd_option == 'skip'
      osw[:steps][0][:arguments][:__SKIP__] = true
    else
      osw[:steps][0][:arguments][:option] = tbd_option
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
  seed_osms.each do |seed_osm|
    results = {}
    tbd_options.each do |tbd_option|
      test_case_name = "#{seed_osm}_#{tbd_option}".gsub('.', '_')
      out_osw_file = File.join(osm_suite_runs_dir, test_case_name, 'out.osw')

      results[tbd_option] = {}
      File.open(out_osw_file, 'r') do |f|
        results[tbd_option] = JSON.parse(f.read, {symbolize_names: true})
      end
    end

    it "compares results for #{seed_osm}" do
      puts "seed_osm = #{seed_osm}"
      tbd_options.each do |tbd_option|
        completed_status = results[tbd_option][:completed_status]
        expect(completed_status).to eq("Success")
        tbd_result = results[tbd_option][:steps][0][:result]
        os_result = results[tbd_option][:steps][1][:result]
        total_site_energy = os_result[:step_values].select{|v| v[:name] == 'total_site_energy'}
        puts "  tbd_option = #{tbd_option}"
        puts "    tbd_success = #{tbd_result[:step_result]}"
        puts "    os_success = #{os_result[:step_result]}"
        puts "    total_site_energy = #{total_site_energy[0][:value]}"
      end
    end
  end

end
