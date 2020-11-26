begin
  # try to load from the gems
  require "topolys"
  require "psi"
rescue LoadError
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
    psi = PSI.new

    choices = OpenStudio::StringVector.new
    psi.set.keys.each do |k| choices << k.to_s; end
    option = OpenStudio::Measure::OSArgument.makeChoiceArgument("option", choices, true)
    option.setDisplayName("Thermal bridge option")
    option.setDescription("e.g. poor, regular, efficient, code")
    option.setDefaultValue("poor (BC Hydro)")
    args << option

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    option = runner.getStringArgumentValue("option", user_arguments)
    psi = PSI.new
    set = psi.set[option]

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    io, surfaces = processTBD(model, set)
    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        output = "#{name} RSi derated by #{ratio}%"
        runner.registerInfo(output)
      end
    end

    return true
  end
end

# register the measure to be used by the application
TBDMeasure.new.registerWithApplication
