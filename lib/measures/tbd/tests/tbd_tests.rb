require "openstudio"
require "openstudio/measure/ShowRunnerOutput"
require "minitest/autorun"
require_relative "../measure.rb"
require "fileutils"

class TBDTest < Minitest::Test
  # def setup
  # end

  # def teardown
  # end

  def test_number_of_arguments_and_argument_names
    # create an instance of the measure
    measure = TBDMeasure.new
    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(3, arguments.size)
  end

  def test_no_load_tbd_json
    # create an instance of the measure
    measure = TBDMeasure.new

    # Output dirs
    seed_dir = File.join(File.dirname(__FILE__), 'output/no_load_tbd_json/')
    FileUtils.mkdir_p(seed_dir)
    seed_path = File.join(seed_dir, 'in.osm')

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    osw.setSeedFile(seed_path)
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # create example test model
    model = OpenStudio::Model::exampleModel
    model.save(seed_path, true)

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    Dir.chdir(seed_dir)
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert(result.warnings.empty?)

    # save the model to test output directory
    #output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    #model.save(output_file_path, true)
  end

  def test_load_tbd_json
    # create an instance of the measure
    measure = TBDMeasure.new

    # Output dirs
    seed_dir = File.join(File.dirname(__FILE__), 'output/load_tbd_json/')
    FileUtils.mkdir_p(seed_dir)
    seed_path = File.join(seed_dir, 'in.osm')

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    osw.setSeedFile(seed_path)
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # create example test model
    model = OpenStudio::Model::exampleModel
    model.save(seed_path, true)

    # copy tdb.json next to seed
    FileUtils.cp(File.join(File.dirname(__FILE__), 'tbd_full_PSI.json'), File.join(seed_dir, 'tbd.json'))

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {"load_tbd_json" => true}
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    Dir.chdir(seed_dir)
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)
    assert(result.warnings.empty?)

    # save the model to test output directory
    #output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    #model.save(output_file_path, true)
  end

  def test_load_tbd_json_error
    # create an instance of the measure
    measure = TBDMeasure.new

    # Output dirs
    seed_dir = File.join(File.dirname(__FILE__), 'output/load_tbd_json_error/')
    FileUtils.mkdir_p(seed_dir)
    seed_path = File.join(seed_dir, 'in.osm')

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    osw.setSeedFile(seed_path)
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # create example test model
    model = OpenStudio::Model::exampleModel
    model.save(seed_path, true)

    # do not copy tdb.json next to seed

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {"load_tbd_json" => true}
    # using defaults values from measure.rb for other arguments

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    Dir.chdir(seed_dir)
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result)

    # assert that it ran correctly
    assert_equal('Fail', result.value.valueName)
    assert(result.errors.size == 1)
    assert(result.warnings.empty?)

    # save the model to test output directory
    #output_file_path = "#{File.dirname(__FILE__)}//output/test_output.osm"
    #model.save(output_file_path, true)
  end
end
