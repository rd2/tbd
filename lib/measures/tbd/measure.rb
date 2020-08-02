begin
  # try to load from the gem
  require 'topolys'
rescue LoadError
  require File.join(File.dirname(__FILE__), 'resources/geometry.rb')
  require File.join(File.dirname(__FILE__), 'resources/model.rb')
  require File.join(File.dirname(__FILE__), 'resources/transformation.rb')
  require File.join(File.dirname(__FILE__), 'resources/version.rb')
end

# start the measure
class TBD < OpenStudio::Measure::ModelMeasure
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
    return "(see https://github.com/rd2/tbd.git)"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    #psi = TBD::PSIs.new
    
    #choices = OpenStudio::StringVector.new
    #psi.set.keys.each do |k| choices << k.to_s; end
    #option = OpenStudio::Measure::OSArgument.makeChoiceArgument("option", choices, true)
    #option.setDisplayName("Thermal bridge option")
    #option.setDescription("e.g. poor, regular, efficient, code")
    #option.setDefaultValue("poor (BC Hydro)")
    #args << option

    return args
  end
  
  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    # assign the user inputs to variables
    #option = runner.getStringArgumentValue("option", user_arguments)
    #psi = TBD::PSIs.new
    #set = psi.set[option]

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    tpm = Topolys::Model.new
    
    surface_structs = []
    model.getSpaces.each do |space|
      t = space.siteTransformation
      space.surfaces.each do |surface|
        points = []
        temp = t * surface.vertices
        temp.each {|v| points << Topolys::Point3D.new(v.x, v.y, v.z)}
        surface_type = surface.surfaceType
        gross_area = surface.grossArea
        surface_structs << {  surface: surface,
                              surface_type: surface_type,
                              gross_area: gross_area,
                              points: points,
                              space: space,
                              face: nil,
                              shell: nil}
      end
    end
    
    surface_types = ["Floor", "RoofCeiling", "Wall"]
    surface_structs.sort! do |x, y| 
      if ( x[:surface_type] == y[:surface_type] )
        x[:gross_area] <=> x[:gross_area]
      else
        x[:surface_type] <=> y[:surface_type]
      end
    end
    #surface_structs.each {|s| puts "#{s[:surface_type]}, #{s[:gross_area]}"}
    
    n = surface_structs.size
    (0...n).each do |i|
      points = surface_structs[i][:points]
      puts "points = #{points}"
      vertices = tpm.get_vertices(points)
      #puts "vertices = #{vertices}" # DLM: why does this line blow up?
      wire = tpm.get_wire(vertices)
      puts "wire = #{wire}"
      face = tpm.get_face(wire, [])
      puts "face = #{face}"
      surface_structs[i][:face] = face
    end
    
    model.getSpaces.each do |space|
      structs = surface_structs.select{|ss| ss[:space].handle == space.handle}
      faces = structs.map{|ss| ss[:face]}
      #puts "faces = #{faces}" # DLM: why does this line blow up?
      puts "faces = #{faces.size}"
      shell = tpm.get_shell(faces)
      puts "shell = #{shell}, closed = #{shell.closed?}"
    end
    
    # install graphviz and make sure dot is in the path
    tpm.save_graphviz('shell.dot')
    system('dot shell.dot -Tpdf -o shell.pdf')

    return true
  end
end

# register the measure to be used by the application
TBD.new.registerWithApplication
