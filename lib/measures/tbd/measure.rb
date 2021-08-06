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
  require_relative "resources/conditioned.rb"
  require_relative "resources/framedivider.rb"
  require_relative "resources/ua.rb"
  require_relative "resources/geometry.rb"
  require_relative "resources/model.rb"
  require_relative "resources/transformation.rb"
  require_relative "resources/version.rb"
  require_relative "resources/log.rb"
end

##
# TBD exit strategy. Outputs TBD model content/results if out && io are TRUE.
# Generates log errors and warnings, even if io or out are FALSE.
#
# @param [Runner] runner OpenStudio Measure runner
# @param [Bool] gen_ua True if user wishes to generate UA' metric/report
# @param [String] ref UA' reference
# @param [Bool] setpoints True if model zones have valid T° setpoints
# @param [Bool] out True if user wishes to output detailed TBD content/results
# @param [Hash] io TBD input/output content
# @param [Hash] surfaces TBD derated surfaces
#
# @return [Bool] Returns true if TBD Measure is successful.
def exitTBD(runner, gen_ua = false, ref = "", setpoints = false, out = false, io = nil, surfaces = nil)
  # Generated files target a design context ( >= WARN ) ... change TBD log_level
  # for debugging purposes. By default, log_status is set below DEBUG while
  # log_level is set @WARN. Example: "TBD.set_log_level(TBD::DEBUG)".

  status = TBD.msg(TBD.status)
  status = TBD.msg(TBD::INFO) if TBD.status.zero?

  unless io && surfaces
    if TBD.fatal?
      status = "Halting all TBD processes, halting OpenStudio"
    else
      status = "Halting all TBD processes, yet running OpenStudio"
    end
  end

  io = {} unless io

  seed_file = runner.workflow.seedFile
  seed_file = seed_file.get.to_s unless seed_file.empty?
  description = "Thermal Bridging and Derating"
  description += " - '#{seed_file}'" unless seed_file.empty?
  io[:description] = description unless io.has_key?(:description)

  unless io.has_key?(:schema)
    io[:schema] = "https://github.com/rd2/tbd/blob/master/tbd.schema.json"
  end

  tbd_log = { date: Time.now, status: status }

  ua = ua_summary(surfaces, ref) if surfaces && gen_ua
  unless TBD.fatal? || ua.empty?
    if ua.has_key?(:bloc1) || ua.has_key?(:bloc2)
      runner.registerInfo("  -  ")
      output = "∑U•A + ∑PSI•L + ∑KHI•n"
      output += " : Design vs '#{ref}'" unless ref.empty?
      runner.registerInfo(output)
    end

    if ua.has_key?(:bloc1)
      pro = 0
      pro = ua[:bloc1][:pro].values.reduce(:+) if ua[:bloc1].has_key?(:pro)
      if pro > TOL
        output = "  - fully-heated: "
        output += ("%.1f" % pro).rjust(7) + " W/K"

        if ua[:bloc1].has_key?(:ref)
          rf = ua[:bloc1][:ref].values.reduce(:+)
          output += " vs " + ("%.1f" % rf).rjust(7) + " W/K"
          ratio = nil
          ratio = (100.0 * (pro - rf) / rf).abs if rf > TOL
          ratio = ("+%.1f" % ratio).rjust(8) + "%" if ratio && pro > rf
          ratio = ("-%.1f" % ratio).rjust(8) + "%" if ratio && pro < rf
          output += ratio if ratio
        end
        runner.registerInfo(output)

        ua[:bloc1][:pro].each do |id, pro|
          output = "  --- #{id.to_s.rjust(10)}: "
          output += ("%.1f" % pro).rjust(7) + " W/K"
          if ua[:bloc1].has_key?(:ref) && ua[:bloc1][:ref].has_key?(id)
            rf = ua[:bloc1][:ref][id]
            output += " vs " + ("%.1f" % rf).rjust(7) + " W/K"
            ratio = nil
            ratio = (100.0 * (pro - rf) / rf).abs if rf > TOL
            ratio = ("+%.1f" % ratio).rjust(8) + "%" if ratio && pro > rf
            ratio = ("-%.1f" % ratio).rjust(8) + "%" if ratio && pro < rf
            output += ratio if ratio
          end
          runner.registerInfo(output)
        end
      end
    end

    if ua.has_key?(:bloc2)
      pro = 0
      pro = ua[:bloc2][:pro].values.reduce(:+) if ua[:bloc2].has_key?(:pro)
      if pro > TOL
        output = "  -  semi-heated: "
        output += ("%.1f" % pro).rjust(7) + " W/K"

        if ua[:bloc2].has_key?(:ref)
          rf = ua[:bloc2][:ref].values.reduce(:+)
          output += " vs " + ("%.1f" % rf).rjust(7) + " W/K"
          ratio = nil
          ratio = (100.0 * (pro - rf) / rf).abs if rf > TOL
          ratio = ("+%.1f" % ratio).rjust(8) + "%" if ratio && pro > rf
          ratio = ("-%.1f" % ratio).rjust(8) + "%" if ratio && pro < rf
          output += ratio if ratio
        end
        runner.registerInfo(output)

        ua[:bloc2][:pro].each do |id, pro|
          output = "  --- #{id.to_s.rjust(10)}: "
          output += ("%.1f" % pro).rjust(7) + " W/K"
          if ua[:bloc2].has_key?(:ref) && ua[:bloc2][:ref].has_key?(id)
            rf = ua[:bloc2][:ref][id]
            output += " vs " + ("%.1f" % rf).rjust(7) + " W/K"
            ratio = nil
            ratio = (100.0 * (pro - rf) / rf).abs if rf > TOL
            ratio = ("+%.1f" % ratio).rjust(8) + "%" if ratio && pro > rf
            ratio = ("-%.1f" % ratio).rjust(8) + "%" if ratio && pro < rf
            output += ratio if ratio
          end
          runner.registerInfo(output)
        end
      end
    end
    runner.registerInfo("  -  ")
  end

  tbd_log[:ua] = ua unless ua.empty?

  results = []
  if surfaces
    surfaces.each do |id, surface|
      next if TBD.fatal?
      next unless surface.has_key?(:ratio)
      ratio  = ("%4.1f" % surface[:ratio]).rjust(7)
      output = "RSi derated by #{ratio}% : #{id}"
      results << output
      runner.registerInfo(output)
    end
  end
  tbd_log[:results] = results unless results.empty?

  tbd_msgs = []
  TBD.logs.each do |l|
    tbd_msgs << { level: TBD.tag(l[:level]), message: l[:message] }
    if l[:level] > TBD::INFO
      runner.registerWarning("(#{TBD.tag(l[:level])}) #{l[:message]}")
    else
      runner.registerInfo("(#{TBD.tag(l[:level])}) #{l[:message]}")
    end
  end
  tbd_log[:messages] = tbd_msgs unless tbd_msgs.empty?

  io[:log] = tbd_log

  # User's may not be requesting detailed output - delete non-essential items.
  io.delete(:psis)        unless out
  io.delete(:khis)        unless out
  io.delete(:building)    unless out
  io.delete(:stories)     unless out
  io.delete(:spacetypes)  unless out
  io.delete(:spaces)      unless out
  io.delete(:surfaces)    unless out
  io.delete(:edges)       unless out

  # Deterministic sorting
  io[:schema]       = io.delete(:schema)      if io.has_key?(:schema)
  io[:description]  = io.delete(:description) if io.has_key?(:description)
  io[:log]          = io.delete(:log)         if io.has_key?(:log)
  io[:psis]         = io.delete(:psis)        if io.has_key?(:psis)
  io[:khis]         = io.delete(:khis)        if io.has_key?(:khis)
  io[:building]     = io.delete(:building)    if io.has_key?(:building)
  io[:stories]      = io.delete(:stories)     if io.has_key?(:stories)
  io[:spacetypes]   = io.delete(:spacetypes)  if io.has_key?(:spacetypes)
  io[:spaces]       = io.delete(:spaces)      if io.has_key?(:spaces)
  io[:surfaces]     = io.delete(:surfaces)    if io.has_key?(:surfaces)
  io[:edges]        = io.delete(:edges)       if io.has_key?(:edges)

  out_dir = '.'
  file_paths = runner.workflow.absoluteFilePaths

  # Apply Measure Now does not copy files from first path back to generated_files
  if file_paths.size >= 2 && File.exists?(file_paths[1].to_s) &&
     (/WorkingFiles/.match(file_paths[1].to_s) || /files/.match(file_paths[1].to_s))
    out_dir = file_paths[1].to_s
  elsif !file_paths.empty? && File.exists?(file_paths.first.to_s)
    out_dir = file_paths.first.to_s
  end

  out_path = File.join(out_dir, "tbd.out.json")

  # Make sure data is written to the disk one way or the other.
  File.open(out_path, 'w') do |file|
    file.puts JSON::pretty_generate(io)
    begin
      file.fsync
    rescue StandardError
      file.flush
    end
  end

  if TBD.fatal?
    runner.registerError(status + " - see 'tbd.out.json'")
    return false
  elsif TBD.error? || TBD.warn?
    runner.registerWarning(status + " - see 'tbd.out.json'")
    return true
  else
    runner.registerInfo(status + " - see 'tbd.out.json'")
    return true
  end
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
    return "Derates opaque constructions from major thermal bridges."
  end

  # human readable description of modeling approach
  def modeler_description
    return "(see github.com/rd2/tbd)"
  end

  # define the arguments that the user will input
  def arguments(model)
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
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    load_tbd_json = runner.getBoolArgumentValue("load_tbd_json", user_arguments)
    option = runner.getStringArgumentValue("option", user_arguments)
    write_tbd_json = runner.getBoolArgumentValue("write_tbd_json", user_arguments)
    gen_UA = runner.getBoolArgumentValue("gen_UA_report", user_arguments)
    ua_ref = runner.getStringArgumentValue("ua_reference", user_arguments)
    gen_kiva = runner.getBoolArgumentValue("gen_kiva", user_arguments)
    gen_kiva_force = runner.getBoolArgumentValue("gen_kiva_force", user_arguments)

    # use the built-in error checking
    return false unless runner.validateUserArguments(arguments(model), user_arguments)

    TBD.clean!

    io_path = nil
    if load_tbd_json
      io_path = runner.workflow.findFile('tbd.json')
      if io_path.empty?
        TBD.log(TBD::FATAL, "Can't find 'tbd.json' - simulation halted")
        return exitTBD(runner)
      else
        io_path = io_path.get.to_s
        #TBD.log(TBD::INFO, "Using inputs from #{io_path}")  # for debugging
        #runner.registerInfo("Using inputs from #{io_path}") # for debugging
      end
    end

    # Process all ground-facing surfaces as foundation-facing.
    if gen_kiva_force
      gen_kiva = true
      model.getSurfaces.each do |s|
        next unless s.isGroundSurface
        construction = s.construction.get
        s.setOutsideBoundaryCondition("Foundation")
        s.setConstruction(construction)
      end
    end

    schema_path = nil
    io, surfaces = processTBD(model, option, io_path, schema_path, gen_UA, ua_ref, gen_kiva)

    t = heatingTemperatureSetpoints?(model)
    t = coolingTemperatureSetpoints?(model) || t

    return exitTBD(runner, gen_UA, ua_ref, t, write_tbd_json, io, surfaces)
  end
end

# register the measure to be used by the application
TBDMeasure.new.registerWithApplication
