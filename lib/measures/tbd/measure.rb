require_relative "resources/version"
require_relative "resources/geometry"
require_relative "resources/transformation"
require_relative "resources/model"

require_relative "resources/psi"
require_relative "resources/conditioned"
require_relative "resources/framedivider"
require_relative "resources/ua"
require_relative "resources/log"

# start the measure
class TBDMeasure < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return "Thermal Bridging and Derating - TBD"
  end

  # human readable description
  def description
    return "Derates opaque constructions from major thermal bridges."
  end

  # human readable description of modeling approach
  def modeler_description
    return "(see github.com/rd2/tbd)"
  end

  # define the arguments that the user will input
  def arguments(model = nil)
    args = OpenStudio::Measure::OSArgumentVector.new

    load_tbd_json = OpenStudio::Measure::OSArgument.makeBoolArgument("load_tbd_json", true, false)
    load_tbd_json.setDisplayName("Load 'tbd.json'")
    load_tbd_json.setDescription("Loads existing 'tbd.json' file from model 'files' directory, may override 'default thermal bridge' pull-down option.")
    load_tbd_json.setDefaultValue(false)
    args << load_tbd_json

    choices = OpenStudio::StringVector.new
    psi = PSI.new
    psi.set.keys.each { |k| choices << k.to_s }

    option = OpenStudio::Measure::OSArgument.makeChoiceArgument("option", choices, true)
    option.setDisplayName("Default thermal bridge option")
    option.setDescription("e.g. 'poor', 'regular', 'efficient', 'code' (may be overridden by 'tbd.json' file).")
    option.setDefaultValue("poor (BETBG)")
    args << option

    alter_model = OpenStudio::Measure::OSArgument.makeBoolArgument("alter_model", true, false)
    alter_model.setDisplayName("Alter OpenStudio model (Apply Measures Now)")
    alter_model.setDescription("For EnergyPlus simulations, leave checked. For iterative exploration with Apply Measures Now, uncheck to preserve original OpenStudio model.")
    alter_model.setDefaultValue(true)
    args << alter_model

    write_tbd_json = OpenStudio::Measure::OSArgument.makeBoolArgument("write_tbd_json", true, false)
    write_tbd_json.setDisplayName("Write 'tbd.out.json'")
    write_tbd_json.setDescription("Write 'tbd.out.json' file to customize for subsequent runs. Edit and place in model 'files' directory as 'tbd.json'.")
    write_tbd_json.setDefaultValue(false)
    args << write_tbd_json

    gen_UA_report = OpenStudio::Measure::OSArgument.makeBoolArgument("gen_UA_report", true, false)
    gen_UA_report.setDisplayName("Generate UA' report")
    gen_UA_report.setDescription("Compare ∑U•A + ∑PSI•L + ∑KHI•n (model vs UA' reference - see pull-down option below).")
    gen_UA_report.setDefaultValue(false)
    args << gen_UA_report

    ua_reference = OpenStudio::Measure::OSArgument.makeChoiceArgument("ua_reference", choices, true)
    ua_reference.setDisplayName("UA' reference")
    ua_reference.setDescription("e.g. 'poor', 'regular', 'efficient', 'code'.")
    ua_reference.setDefaultValue("code (Quebec)")
    args << ua_reference

    gen_kiva = OpenStudio::Measure::OSArgument.makeBoolArgument("gen_kiva", true, false)
    gen_kiva.setDisplayName("Generate Kiva inputs")
    gen_kiva.setDescription("Generate Kiva settings & objects for surfaces with 'foundation' boundary conditions (not 'ground').")
    gen_kiva.setDefaultValue(false)
    args << gen_kiva

    gen_kiva_force = OpenStudio::Measure::OSArgument.makeBoolArgument("gen_kiva_force", true, false)
    gen_kiva_force.setDisplayName("Force-generate Kiva inputs")
    gen_kiva_force.setDescription("Overwrites 'ground' boundary conditions as 'foundation' before generating Kiva inputs (recommended).")
    gen_kiva_force.setDefaultValue(false)
    args << gen_kiva_force

    return args
  end

  # define what happens when the measure is run
  def run(user_model, runner, user_arguments)
    super(user_model, runner, user_arguments)

    # assign the user inputs to variables
    load_tbd_json = runner.getBoolArgumentValue("load_tbd_json", user_arguments)
    option = runner.getStringArgumentValue("option", user_arguments)
    alter = runner.getBoolArgumentValue("alter_model", user_arguments)
    write_tbd_json = runner.getBoolArgumentValue("write_tbd_json", user_arguments)
    gen_UA = runner.getBoolArgumentValue("gen_UA_report", user_arguments)
    ua_ref = runner.getStringArgumentValue("ua_reference", user_arguments)
    gen_kiva = runner.getBoolArgumentValue("gen_kiva", user_arguments)
    gen_kiva_force = runner.getBoolArgumentValue("gen_kiva_force", user_arguments)

    # use the built-in error checking
    return false unless runner.validateUserArguments(arguments(user_model), user_arguments)

    TBD.clean!

    io_path = nil
    if load_tbd_json
      io_path = runner.workflow.findFile('tbd.json')
      if io_path.empty?
        TBD.log(TBD::FATAL, "Can't find 'tbd.json' - simulation halted")
        return exitTBD(user_model, runner)
      else
        io_path = io_path.get.to_s
        # TBD.log(TBD::INFO, "Using inputs from #{io_path}")  # for debugging
        # runner.registerInfo("Using inputs from #{io_path}") # for debugging
      end
    end

    # Process all ground-facing surfaces as foundation-facing.
    if gen_kiva_force
      gen_kiva = true
      user_model.getSurfaces.each do |s|
        next unless s.isGroundSurface
        construction = s.construction.get
        s.setOutsideBoundaryCondition("Foundation")
        s.setConstruction(construction)
      end
    end

    seed = runner.workflow.seedFile
    seed = File.basename(seed.get.to_s) unless seed.empty?
    seed = "OpenStudio model" if seed.empty? || seed == "temp_measure_manager.osm"

    if alter == false
      # Clone model.
      model = OpenStudio::Model::Model.new
      model.addObjects(user_model.toIdfFile.objects)
    else
      model = user_model
    end

    io, surfaces = processTBD(model, option, io_path, nil, gen_UA, ua_ref, gen_kiva)

    t = heatingTemperatureSetpoints?(model)
    t = coolingTemperatureSetpoints?(model) || t

    return exitTBD(model, runner, gen_UA, ua_ref, t, write_tbd_json, io, surfaces, seed)
  end
end

# register the measure to be used by the application
TBDMeasure.new.registerWithApplication
