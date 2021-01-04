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
    return "Thermal Bridging and Derating - TBD"
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
    load_tbd_json.setDisplayName("Load tbd.json")
    load_tbd_json.setDescription("Loads existing tbd.json from model files directory, overrides other arguments if true.")
    load_tbd_json.setDefaultValue(false)
    args << load_tbd_json

    choices = OpenStudio::StringVector.new
    psi = PSI.new
    psi.set.keys.each do |k| choices << k.to_s; end
    option = OpenStudio::Measure::OSArgument.makeChoiceArgument("option", choices, true)
    option.setDisplayName("Default thermal bridge option to use if not reading tbd.json")
    option.setDescription("e.g. poor, regular, efficient, code")
    option.setDefaultValue("poor (BC Hydro)")
    args << option

    write_tbd_json = OpenStudio::Measure::OSArgument.makeBoolArgument("write_tbd_json", true, false)
    write_tbd_json.setDisplayName("Write tbd.out.json")
    write_tbd_json.setDescription("Write tbd.out.json to customize for subsequent runs. Edit and place in model files directory as tbd.json")
    write_tbd_json.setDefaultValue(true)
    args << write_tbd_json

    gen_kiva = OpenStudio::Measure::OSArgument.makeBoolArgument("gen_kiva", true, false)
    gen_kiva.setDisplayName("Generate Kiva inputs")
    gen_kiva.setDescription("Generate OSM Kiva settings and objects if model surfaces have 'foundation' boundary conditions")
    gen_kiva.setDefaultValue(true)
    args << gen_kiva

    gen_kiva_force = OpenStudio::Measure::OSArgument.makeBoolArgument("gen_kiva_force", true, false)
    gen_kiva_force.setDisplayName("Force-generate Kiva inputs")
    gen_kiva_force.setDescription("Overwrites all 'ground' boundary conditions as 'foundation' before generating OSM Kiva inputs")
    gen_kiva_force.setDefaultValue(false)
    args << gen_kiva_force

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    load_tbd_json = runner.getBoolArgumentValue("load_tbd_json", user_arguments)

    option = runner.getStringArgumentValue("option", user_arguments)

    write_tbd_json = runner.getBoolArgumentValue("write_tbd_json", user_arguments)

    gen_kiva = runner.getBoolArgumentValue("gen_kiva", user_arguments)

    gen_kiva_force = runner.getBoolArgumentValue("gen_kiva_force", user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    io_path = nil
    schema_path = nil

    if load_tbd_json
      runner.workflow.absoluteFilePaths.each {|p| runner.registerInfo("Searching for tbd.json in #{p}")}
      io_path = runner.workflow.findFile('tbd.json')
      if io_path.empty?
        runner.registerError("Cannot find tbd.json")
        return false
      else
        io_path = io_path.get.to_s
        runner.registerInfo("Using inputs from #{io_path}")
      end
    end

    # Process all ground-facing surfaces as foundation-facing.
    if gen_kiva_force
      gen_kiva = true
      model.getSurfaces.each do |s|
        next unless s.isGroundSurface
        s.outsideBoundaryCondition == "Foundation"
      end
    end

    io, surfaces = processTBD(model, option, io_path, schema_path, gen_kiva)

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        output = "#{name} RSi derated by #{ratio}%"
        runner.registerInfo(output)
      end
    end

    if write_tbd_json
      out_dir = '.'
      file_paths = runner.workflow.absoluteFilePaths
      file_paths.each {|p| runner.registerInfo("Searching for out_dir in #{p}")}

      # Apply Measure Now does not copy files from first path back to generated_files
      if file_paths.size >=2 && (/WorkingFiles/.match(file_paths[1].to_s) || /files/.match(file_paths[1].to_s)) && File.exists?(file_paths[1].to_s)
        out_dir = file_paths[1].to_s
      elsif !file_paths.empty? && File.exists?(file_paths.first.to_s)
        out_dir = file_paths.first.to_s
      end

      out_path = File.join(out_dir, 'tbd.out.json')
      runner.registerInfo("Writing #{out_path} in #{Dir.pwd}")

      File.open(out_path, 'w') do |file|
        file.puts JSON::pretty_generate(io)

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
