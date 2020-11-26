begin
  # try to load from the gems
  $STARTING_DIR = Dir.pwd
  require "topolys"
  require "psi"
rescue LoadError
  if $STARTING_DIR != Dir.pwd
    Dir.chdir($STARTING_DIR)
  end
  # load from measure resource dir
  require_relative "resources/psi.rb"
  require_relative "resources/geometry.rb"
  require_relative "resources/model.rb"
  require_relative "resources/transformation.rb"
  require_relative "resources/version.rb"
end

# start the measure
class TBDMeasure < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return "Thermal Bridging & Derating (TBD)"
  end

  # human readable description
  def description
    return "Thermally derates opaque constructions from major thermal bridges"
  end

  # human readable description of modeling approach
  def modeler_description
    return "(see github.com/rd2/tbd)"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    load_tbd_json = OpenStudio::Measure::OSArgument.makeBoolArgument("load_tbd_json", true, false)
    load_tbd_json.setDisplayName("Load TBD.json")
    load_tbd_json.setDescription("Loads existing TDB.json from model directory, overrides other arguments if true.")
    load_tbd_json.setDefaultValue(false)
    args << load_tbd_json

    choices = OpenStudio::StringVector.new
    psi = PSI.new
    psi.set.keys.each do |k| choices << k.to_s; end
    option = OpenStudio::Measure::OSArgument.makeChoiceArgument("option", choices, true)
    option.setDisplayName("Default thermal bridge option to use if not reading TDB.json")
    option.setDescription("e.g. poor, regular, efficient, code")
    option.setDefaultValue("poor (BC Hydro)")
    args << option

    write_tbd_json = OpenStudio::Measure::OSArgument.makeBoolArgument("write_tbd_json", true, false)
    write_tbd_json.setDisplayName("Write TBD.json")
    write_tbd_json.setDescription("Write TBD.json to customize for subsequent runs, edit and place in model directory")
    write_tbd_json.setDefaultValue(true)
    args << write_tbd_json

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    load_tbd_json = runner.getBoolArgumentValue("load_tbd_json", user_arguments)

    option = runner.getStringArgumentValue("option", user_arguments)

    write_tbd_json = runner.getBoolArgumentValue("write_tbd_json", user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    io_path = nil
    schema_path = nil

    if load_tbd_json
      io_path = runner.workflow.findFile('tbd.json')
      if io_path.empty?
        runner.registerError("Cannot find tbd.json")
        return false
      else
        io_path = io_path.get.to_s
        runner.registerInfo("Using inputs from #{io_path}")
      end
    end

    # DLM: can processTBD also return the content of the TBD JSON to write?
    surfaces = processTBD(model, option, io_path, schema_path)
    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        output = "#{name} RSi derated by #{ratio}%"
        runner.registerInfo(output)
      end
    end

    if write_tbd_json
      out_path = './tbd.out.json'
      runner.registerInfo("Writing #{out_path} in #{Dir.pwd}")
      File.open(out_path, 'w') do |file|
        # DLM: this is where it would be convienent to write out the TDB JSON file
        # I don't think surfaces is what we want to write? how do we get the content
        # for the TBD JSON?
        file.puts '{}'
        #file.puts JSON::pretty_generate(surfaces)

        # make sure data is written to the disk one way or the other
        begin
          file.fsync
        rescue StandardError
          file.flush
        end
      end
    end

    return true
  end
end

# register the measure to be used by the application
TBDMeasure.new.registerWithApplication
