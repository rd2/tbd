# MIT License
#
# Copyright (c) 2020-2022 Denis Bourgeois & Dan Macumber
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
    return "Consult rd2.github.io/tbd"
  end

  # define the arguments that the user will input
  def arguments(model = nil)
    args = OpenStudio::Measure::OSArgumentVector.new

    alter_model = OpenStudio::Measure::OSArgument.makeBoolArgument("alter_model", false)
    alter_model.setDisplayName("Alter OpenStudio model (Apply Measures Now)")
    alter_model.setDescription("For EnergyPlus simulations, leave CHECKED. For iterative exploration with Apply Measures Now, UNCHECK to preserve original OpenStudio model.")
    alter_model.setDefaultValue(true)
    args << alter_model

    load_tbd_json = OpenStudio::Measure::OSArgument.makeBoolArgument("load_tbd_json", false)
    load_tbd_json.setDisplayName("Load 'tbd.json'")
    load_tbd_json.setDescription("Loads existing 'tbd.json' file (under '/files'), may override 'default thermal bridge' set.")
    load_tbd_json.setDefaultValue(false)
    args << load_tbd_json

    choices = OpenStudio::StringVector.new
    psi = PSI.new
    psi.set.keys.each { |k| choices << k.to_s }

    option = OpenStudio::Measure::OSArgument.makeChoiceArgument("option", choices, false)
    option.setDisplayName("Default thermal bridge set")
    option.setDescription("e.g. 'poor', 'regular', 'efficient', 'code' (may be overridden by 'tbd.json' file).")
    option.setDefaultValue("poor (BETBG)")
    args << option

    write_tbd_json = OpenStudio::Measure::OSArgument.makeBoolArgument("write_tbd_json", false)
    write_tbd_json.setDisplayName("Write 'tbd.out.json'")
    write_tbd_json.setDescription("Write out 'tbd.out.json' file e.g., to customize for subsequent runs (edit, and place under '/files' as 'tbd.json').")
    write_tbd_json.setDefaultValue(false)
    args << write_tbd_json

    walls  = {s: {}, choix: OpenStudio::StringVector.new, dft: "ALL wall constructions"}
    roofs  = {s: {}, choix: OpenStudio::StringVector.new, dft: "ALL roof constructions"}
    floors = {s: {}, choix: OpenStudio::StringVector.new, dft: "ALL floor constructions"}

    if model
      model.getSurfaces.each do |s|
        type = s.surfaceType.downcase
        next unless type == "wall" || type == "roofceiling" || type == "floor"
        next unless s.outsideBoundaryCondition.downcase == "outdoors"
        next if s.construction.empty?
        next if s.construction.get.to_LayeredConstruction.empty?
        lc = s.construction.get.to_LayeredConstruction.get
        r = rsi(lc, s.filmResistance)
        i, t, lr = deratableLayer(lc)
        a = lc.getNetArea

        faces = walls[:s]  if type == "wall"
        faces = roofs[:s]  if type == "roofceiling"
        faces = floors[:s] if type == "floor"
        faces[lc.nameString] = {r: r, lr: lr, i: i, t: t, a: a}
      end

      walls[:s][walls[:dft]] = {r: 0, lr: 0, i: -1, t: "", a: 100000000000000}
      walls[:s].sort_by{ |k,v| v[:a] }.to_h
      walls[:s][walls[:dft]][:a] = 0
      walls[:s].keys.each { |id| walls[:choix] << id }

      roofs[:s][roofs[:dft]] = {r: 0, lr: 0, i: -1, t: "", a: 100000000000000}
      roofs[:s].sort_by{ |k,v| v[:a] }.to_h
      roofs[:s][roofs[:dft]][:a] = 0
      roofs[:s].keys.each { |id| roofs[:choix] << id }

      floors[:s][floors[:dft]] = {r: 0, lr: 0, i: -1, t: "", a: 100000000000000}
      floors[:s].sort_by{ |k,v| v[:a] }.to_h
      floors[:s][floors[:dft]][:a] = 0
      floors[:s].keys.each { |id| floors[:choix] << id }
    end

    uprate_walls = OpenStudio::Measure::OSArgument.makeBoolArgument("uprate_walls", false)
    uprate_walls.setDisplayName("Uprate wall construction(s)")
    uprate_walls.setDescription("Uprates selected wall construction(s), to meet overall Ut target")
    uprate_walls.setDefaultValue(false)
    args << uprate_walls

    uprate_roofs = OpenStudio::Measure::OSArgument.makeBoolArgument("uprate_roofs", false)
    uprate_roofs.setDisplayName("Uprate roof construction(s)")
    uprate_roofs.setDescription("Uprates selected roof construction(s), to meet overall Ut target")
    uprate_roofs.setDefaultValue(false)
    args << uprate_roofs

    uprate_floors = OpenStudio::Measure::OSArgument.makeBoolArgument("uprate_floors", false)
    uprate_floors.setDisplayName("Uprate floor construction(s)")
    uprate_floors.setDescription("Uprates selected floor construction(s), to meet overall Ut target")
    uprate_floors.setDefaultValue(false)
    args << uprate_floors

    wall_ut = OpenStudio::Measure::OSArgument.makeDoubleArgument("wall_ut", false)
    wall_ut.setDisplayName("Wall Ut target (W/m2•K)")
    wall_ut.setDescription("Overall Ut target to meet for wall construction(s)")
    wall_ut.setDefaultValue(0.210) # (NECB 2017, climate zone 7)
    args << wall_ut

    roof_ut = OpenStudio::Measure::OSArgument.makeDoubleArgument("roof_ut", false)
    roof_ut.setDisplayName("Roof Ut target (W/m2•K)")
    roof_ut.setDescription("Overall Ut target to meet for roof construction(s)")
    roof_ut.setDefaultValue(0.138) # (NECB 2017, climate zone 7)
    args << roof_ut

    floor_ut = OpenStudio::Measure::OSArgument.makeDoubleArgument("floor_ut", false)
    floor_ut.setDisplayName("Floor Ut target (W/m2•K)")
    floor_ut.setDescription("Overall Ut target to meet for floor construction(s)")
    floor_ut.setDefaultValue(0.162) # (NECB 2017, climate zone 7)
    args << floor_ut

    wall_option = OpenStudio::Measure::OSArgument.makeChoiceArgument("wall_option", walls[:choix], false)
    wall_option.setDisplayName("Wall construction(s) to 'uprate'")
    wall_option.setDescription("Target 1x (or 'ALL') wall construction(s) to 'uprate'")
    wall_option.setDefaultValue(walls[:dft])
    args << wall_option

    roof_option = OpenStudio::Measure::OSArgument.makeChoiceArgument("roof_option", roofs[:choix], false)
    roof_option.setDisplayName("Roof construction(s) to 'uprate'")
    roof_option.setDescription("Target 1x (or 'ALL') roof construction(s) to 'uprate'")
    roof_option.setDefaultValue(roofs[:dft])
    args << roof_option

    floor_option = OpenStudio::Measure::OSArgument.makeChoiceArgument("floor_option", floors[:choix], false)
    floor_option.setDisplayName("Floor construction(s) to 'uprate'")
    floor_option.setDescription("Target 1x (or 'ALL') floor construction(s) to 'uprate'")
    floor_option.setDefaultValue(floors[:dft])
    args << floor_option

    gen_UA_report = OpenStudio::Measure::OSArgument.makeBoolArgument("gen_UA_report", false)
    gen_UA_report.setDisplayName("Generate UA' report")
    gen_UA_report.setDescription("Compare ∑U•A + ∑PSI•L + ∑KHI•n : 'Design' vs UA' reference (see pull-down option below).")
    gen_UA_report.setDefaultValue(false)
    args << gen_UA_report

    ua_reference = OpenStudio::Measure::OSArgument.makeChoiceArgument("ua_reference", choices, true)
    ua_reference.setDisplayName("UA' reference")
    ua_reference.setDescription("e.g. 'poor', 'regular', 'efficient', 'code'.")
    ua_reference.setDefaultValue("code (Quebec)")
    args << ua_reference

    gen_kiva = OpenStudio::Measure::OSArgument.makeBoolArgument("gen_kiva", false)
    gen_kiva.setDisplayName("Generate Kiva inputs")
    gen_kiva.setDescription("Generates Kiva settings & objects for surfaces with 'foundation' boundary conditions (not 'ground').")
    gen_kiva.setDefaultValue(false)
    args << gen_kiva

    gen_kiva_force = OpenStudio::Measure::OSArgument.makeBoolArgument("gen_kiva_force", false)
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
    alter = runner.getBoolArgumentValue("alter_model", user_arguments)
    load_tbd_json = runner.getBoolArgumentValue("load_tbd_json", user_arguments)
    option = runner.getStringArgumentValue("option", user_arguments)
    uprate_walls = runner.getBoolArgumentValue("uprate_walls", user_arguments)
    uprate_roofs = runner.getBoolArgumentValue("uprate_roofs", user_arguments)
    uprate_floors = runner.getBoolArgumentValue("uprate_floors", user_arguments)
    wall_ut = runner.getDoubleArgumentValue("wall_ut", user_arguments)
    roof_ut = runner.getDoubleArgumentValue("roof_ut", user_arguments)
    floor_ut = runner.getDoubleArgumentValue("floor_ut", user_arguments)
    wall_option = runner.getStringArgumentValue("wall_option", user_arguments)
    roof_option = runner.getStringArgumentValue("roof_option", user_arguments)
    floor_option = runner.getStringArgumentValue("floor_option", user_arguments)
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
