require "open3"
require "openstudio"

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
  it "it can run all the measure tests" do
    measure_dir = File.join(File.dirname(__FILE__), "../lib/measures")
    measure_tests = Dir.glob(measure_dir + "/*/tests/*.rb")
    measure_tests.each do |measure_test|
      command = "'#{OpenStudio::getOpenStudioCLI}' '#{measure_test}'"
      puts command
      stdout_str, stderr_str, status = Open3.capture3(get_clean_env, command)
      expect(status.success?).to be(true)
    end
  end
end
