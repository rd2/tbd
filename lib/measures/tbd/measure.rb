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
    gen_kiva.setDescription("Generate OSM Kiva settings and objects if model surfaces have foundation boundary conditions")
    gen_kiva.setDefaultValue(true)
    args << gen_kiva

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

    if gen_kiva
      # Although one may choose to auto-generate Kiva settings and objects,
      # there must be at least one valid foundation-facing floor in the model.
      kiva = false
      surfaces.values.each do |surface|
        next if kiva
        kiva = true if surface.has_key?(:kiva)
      end

      if kiva
        arg = "TotalExposedPerimeter"
        foundation_kiva_settings = model.getFoundationKivaSettings
        foundation_kiva_settings.setName("TBD-generated Kiva settings template")

        # Generic 1" XPS insulation.
        xps_25mm = OpenStudio::Model::StandardOpaqueMaterial.new(model)
        xps_25mm.setName("XPS_25mm")
        xps_25mm.setRoughness("Rough")
        xps_25mm.setThickness(0.0254)
        xps_25mm.setConductivity(0.029)
        xps_25mm.setDensity(28)
        xps_25mm.setSpecificHeat(1450)
        xps_25mm.setThermalAbsorptance(0.9)
        xps_25mm.setSolarAbsorptance(0.7)

        # Typical circa-1980 slab-on-grade (perimeter) insulation setup.
        kiva_slab = OpenStudio::Model::FoundationKiva.new(model)
        kiva_slab.setName("Kiva slab")
        kiva_slab.setInteriorHorizontalInsulationMaterial(xps_25mm)
        kiva_slab.setInteriorHorizontalInsulationWidth(0.6)

        # Basement wall setup (full-height insulation as construction layer)
        kiva_basement = OpenStudio::Model::FoundationKiva.new(model)
        kiva_basement.setName("Kiva basement")

        # Once XPS and slab/basement objects are generated, assign either other.
        surfaces.each do |id, surface|
          next unless surface.has_key?(:kiva)
          next unless surface.has_key?(:exposed)
          next unless surface[:exposed] > 0.001
          next unless surface[:kiva] == :basement || surface[:kiva] == :slab

          found = false
          model.getSurfaces.each do |s|
            next unless s.nameString == id
            next unless s.outsideBoundaryCondition.downcase == "foundation"

            found = true
            s.createSurfacePropertyExposedFoundationPerimeter(arg, surface[:exposed])
            s.setAdjacentFoundation(kiva_basement) if surface[:kiva] == :basement
            s.setAdjacentFoundation(kiva_slab) if surface[:kiva] == :slab
          end

          # Loop through basement wall surfaces and assign foundation object.
          surfaces.each do |i, surf|
            next unless found
            next unless surf.has_key?(:foundation)
            next unless id == surf[:foundation]

            model.getSurfaces.each do |ss|
              next unless ss.nameString == i
              next unless ss.outsideBoundaryCondition.downcase == "foundation"
              ss.setAdjacentFoundation(kiva_basement) if surface[:kiva] == :basement
              ss.setAdjacentFoundation(kiva_slab) if surface[:kiva] == :slab
            end
          end
        end
      end
    end

    return true
  end
end

# register the measure to be used by the application
TBDMeasure.new.registerWithApplication
