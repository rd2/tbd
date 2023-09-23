# MIT License
#
# Copyright (c) 2020-2023 Denis Bourgeois & Dan Macumber
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require "openstudio"
require "openstudio/measure/ShowRunnerOutput"
require "minitest/autorun"
require "fileutils"

require_relative "../measure.rb"


class TBDTest < Minitest::Test
  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    measure = TBDMeasure.new
    model = OpenStudio::Model::Model.new
    arguments = measure.arguments(model)
    assert_equal(16, arguments.size)
  end

  def test_no_load_tbd_json
    measure = TBDMeasure.new

    # Output directories.
    seed_dir = File.join(__dir__, "output/no_load_tbd_json/")
    FileUtils.mkdir_p(seed_dir)
    seed_path = File.join(seed_dir, "in.osm")

    # Create runner with empty OSW, and example test model.
    osw = OpenStudio::WorkflowJSON.new
    osw.setSeedFile(seed_path)
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::exampleModel
    model.save(seed_path, true)

    # Get measure arguments.
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # Hash of argument values (defaults from measure.rb for other arguments).
    argh                   = {}
    argh["option"        ] = "efficient (BETBG)"
    argh["write_tbd_json"] = true
    argh["gen_UA_report" ] = true
    argh["wall_option"   ] = "ALL wall constructions"
    argh["wall_ut"       ] = 0.5

    # Populate arguments with specified hash value if specified.
    arguments.each do |arg|
      temp_arg_var = arg.clone
      assert(temp_arg_var.setValue(argh[arg.name])) if argh.key?(arg.name)
      argument_map[arg.name] = temp_arg_var
    end

    # Run the measure and assert that it ran correctly.
    Dir.chdir(seed_dir)
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.empty?)
    assert(result.errors.empty?)

    # Save the model to test output directory.
    output_path = File.join(seed_dir, "out.osm")
    model.save(output_path, true)
  end

  def test_load_tbd_json
    measure = TBDMeasure.new

    # Output directories.
    seed_dir = File.join(__dir__, "output/load_tbd_json/")
    FileUtils.mkdir_p(seed_dir)
    seed_path = File.join(seed_dir, "in.osm")

    # Create runner with empty OSW, and example test model.
    osw = OpenStudio::WorkflowJSON.new
    osw.setSeedFile(seed_path)
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::exampleModel
    model.save(seed_path, true)

    # Copy tdb.json next to seed.
    origin_pth = File.join(__dir__, "tbd_full_PSI.json")
    target_pth = File.join(seed_dir, "tbd.json")
    FileUtils.cp(origin_pth, target_pth)

    # Get measure arguments.
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # Hash of argument values (defaults from measure.rb for other arguments).
    argh                   = {}
    argh["load_tbd_json" ] = true

    # Populate arguments with specified hash value if specified.
    arguments.each do |arg|
      temp_arg_var = arg.clone
      assert(temp_arg_var.setValue(argh[arg.name])) if argh.key?(arg.name)
      argument_map[arg.name] = temp_arg_var
    end

    # Run the measure and assert that it ran correctly.
    Dir.chdir(seed_dir)
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Success", result.value.valueName)
    assert(result.warnings.empty?)
    assert(result.errors.empty?)

    # Save the model to test output directory.
    output_path = File.join(seed_dir, "out.osm")
    model.save(output_path, true)
  end

  def test_load_tbd_json_error
    measure = TBDMeasure.new

    # Output directories.
    seed_dir = File.join(__dir__, "output/load_tbd_json_error/")
    FileUtils.mkdir_p(seed_dir)
    seed_path = File.join(seed_dir, "in.osm")

    # Create runner with empty OSW, and example test model.
    osw = OpenStudio::WorkflowJSON.new
    osw.setSeedFile(seed_path)
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::exampleModel
    model.save(seed_path, true)

    # POSTULATED USER ERROR: Do not copy tdb.json next to seed.

    # Get measure arguments.
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # Hash of argument values (defaults from measure.rb for other arguments).
    argh                   = {}
    argh["load_tbd_json" ] = true

    # Populate argument with specified hash value if specified.
    arguments.each do |arg|
      temp_arg_var = arg.clone
      assert(temp_arg_var.setValue(argh[arg.name])) if argh.key?(arg.name)
      argument_map[arg.name] = temp_arg_var
    end

    # Run the measure, assert that it did not run correctly.
    Dir.chdir(seed_dir)
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Fail", result.value.valueName)

    assert(result.warnings.size == 1)
    message = result.warnings[0].logMessage
    puts message
    assert(message.include?("Can't find 'tbd.json' - simulation halted"))

    assert(result.errors.size == 1)
    message = result.errors[0].logMessage
    puts message
    assert(message.include?("Halting all TBD processes, "))
    assert(message.include?("and halting OpenStudio - see 'tbd.out.json'"))

    # Save the model to test output directory.
    output_path = File.join(seed_dir, "out.osm")
    model.save(output_path, true)
  end

  def test_tbd_kiva_massless_error
    measure = TBDMeasure.new

    # Output directories.
    seed_dir = File.join(__dir__, "output/tbd_kiva_massless_error/")
    FileUtils.mkdir_p(seed_dir)
    seed_path = File.join(seed_dir, "in.osm")

    # Create runner with empty OSW, and example test model.
    osw = OpenStudio::WorkflowJSON.new
    osw.setSeedFile(seed_path)
    runner = OpenStudio::Measure::OSRunner.new(osw)
    model = OpenStudio::Model::exampleModel
    model.save(seed_path, true)

    # Copy tdb.json next to seed.
    origin_pth = File.join(__dir__, "tbd_full_PSI.json")
    target_pth = File.join(seed_dir, "tbd.json")
    FileUtils.cp(origin_pth, target_pth)

    # Get measure arguments.
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # Hash of argument values (defaults from measure.rb for other arguments).
    argh                   = {}
    argh["gen_kiva_force"] = true

    # POSTULATED USER ERROR : Slab on grade construction holds a massless layer.

    # Populate argument with specified hash value if specified.
    arguments.each do |arg|
      temp_arg_var = arg.clone
      assert(temp_arg_var.setValue(argh[arg.name])) if argh.key?(arg.name)
      argument_map[arg.name] = temp_arg_var
    end

    # Run the measure, assert that it did not run correctly.
    Dir.chdir(seed_dir)
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Fail", result.value.valueName)
    assert(result.warnings.empty?)
    assert(result.errors.size == 4)

    result.errors.each do |error|
      assert(error.logMessage.include?("KIVA requires standard materials ("))
    end

    # Save the model to test output directory. There should be neither instance
    # of KIVA objects nor TBD derated materials/constructions.
    output_path = File.join(seed_dir, "out.osm")
    model.save(output_path, true)
  end
end
