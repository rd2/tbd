require "openstudio"

begin
  # try to load from the gem
  require "topolys"
rescue LoadError
  require_relative "geometry.rb"
  require_relative "model.rb"
  require_relative "transformation.rb"
  require_relative "version.rb"
end

# Returns site/space transformation & rotation
def transforms(model, group)
  if model && group
    unless model.is_a?(OpenStudio::Model::Model)
      raise "Expected OpenStudio model - got #{model.class}"
    end
    unless group.is_a?(OpenStudio::Model::Space)               ||
           group.is_a?(OpenStudio::Model::ShadingSurfaceGroup)
      raise "Expected OpenStudio group - got a #{group.class}"
    end
    t = group.siteTransformation
    r = group.directionofRelativeNorth + model.getBuilding.northAxis
    return t, r
  end
end

# Returns site-specific (or absolute) Topolys surface normal
def trueNormal(s, r)
  if s && r
    c = OpenStudio::Model::PlanarSurface
    raise "Expected #{c} - got #{s.class}" unless s.is_a?(c)
    raise "Expected a numeric - got #{r.class}" unless r.is_a?(Numeric)

    n = Topolys::Vector3D.new(s.outwardNormal.x * Math.cos(r) -
                              s.outwardNormal.y * Math.sin(r), # x
                              s.outwardNormal.x * Math.sin(r) +
                              s.outwardNormal.y * Math.cos(r), # y
                              s.outwardNormal.z)               # z
    return n
  end
end

# Returns Topolys vertices and a Topolys wire from Topolys points. As
# a side effect, it will - if successful - also populate the Topolys
# model with the vertices and wire.
def topolysObjects(model, points)
  if model && points
    unless model.is_a?(Topolys::Model)
      raise "Expected Topolys model - got #{model.class}"
    end
    unless points.is_a?(Array)
      raise "Expected array of Topolys points - got a #{points.class}"
    end
    unless points.size > 2
      raise "Expected more than 2 points - got #{points.size}"
    end

    vertices = model.get_vertices(points)
    wire = model.get_wire(vertices)
    return vertices, wire
  end
end

# Populates hash of TBD kids, relying on Topolys. As
# a side effect, it will - if successful - also populate the Topolys
# model with Topolys vertices, wires, holes.
def populateTBDkids(model, kids)
  holes = []
  if model && kids
    unless model.is_a?(Topolys::Model)
      raise "Expected Topolys model - got #{model.class}"
    end
    unless kids.is_a?(Hash)
      raise "Expected hash of TBD surafces - got a #{kids.class}"
    end
    kids.each do |id, properties|
      vtx, hole = topolysObjects(model, properties[:points])
      hole.attributes[:id] = id
      hole.attributes[:n] = properties[:n] if properties.has_key?(:n)
      properties[:hole] = hole
      holes << hole
    end
  end
  return holes
end

# Populates hash of TBD surfaces, relying on Topolys. As
# a side effect, it will - if successful - also populate the Topolys
# model with Topolys vertices, wires, holes & faces.
def populateTBDdads(model, dads)
  tbd_holes = {}

  if model && dads
    unless model.is_a?(Topolys::Model)
      raise "Expected Topolys model - got #{model.class}"
    end
    unless dads.is_a?(Hash)
      raise "Expected hash of TBD surfaces - got a #{dads.class}"
    end

    dads.each do |id, properties|
      vertices, wire = topolysObjects(model, properties[:points])

      # create surface holes for kids
      holes = []
      if properties.has_key?(:windows)
        holes += populateTBDkids(model, properties[:windows])
      end
      if properties.has_key?(:doors)
        holes += populateTBDkids(model, properties[:doors])
      end
      if properties.has_key?(:skylights)
        holes += populateTBDkids(model, properties[:skylights])
      end

      face = model.get_face(wire, holes)
      raise "Cannot build face for #{id}" if face.nil?

      face.attributes[:id] = id
      face.attributes[:n] = properties[:n] if properties.has_key?(:n)
      properties[:face] = face

      # populate hash of created holes (to return)
      holes.each do |h| tbd_holes[h.attributes[:id]] = h; end
    end
  end
  return tbd_holes
end

def tbdSurfaceEdges(surfaces, edges)
  if surfaces
    unless surfaces.is_a?(Hash)
      raise "Expected hash of TBD surfaces - got a #{surfaces.class}"
    end
    unless edges.is_a?(Hash)
      raise "Expected hash of TBD edges - got a #{edges.class}"
    end

    surfaces.each do |id, properties|
      unless properties.has_key?(:face)
        raise "Missing Topolys face for #{id}"
      end
      properties[:face].wires.each do |wire|
        wire.edges.each do |e|
          unless edges.has_key?(e.id)
            edges[e.id] = {length: e.length,
                           v0: e.v0,
                           v1: e.v1,
                           surfaces: {}}
          end
          unless edges[e.id][:surfaces].has_key?(id)
            edges[e.id][:surfaces][id] = {wire: wire.id}
          end
        end
      end
    end
  end
end

def deratableLayer(construction)
  # identify insulating material (and key attributes) within a construction
  r                     = 0.0         # R-value of insulating material
  index                 = nil         # index of insulating material
  type                  = nil         # nil, :massless; or :standard
  i                     = 0           # iterator

  construction.layers.each do |m|
    unless m.to_MasslessOpaqueMaterial.empty?
      m                 = m.to_MasslessOpaqueMaterial.get
      next unless         m.thermalResistance > 0.001
      next unless         m.thermalResistance > r
      r                 = m.thermalResistance
      index             = i
      type              = :massless
      i += 1
    end

    unless m.to_StandardOpaqueMaterial.empty?
      m                 = m.to_StandardOpaqueMaterial.get
      k                 = m.thermalConductivity
      d                 = m.thickness
      next unless         d > 0.003
      next unless         k < 3.0
      next unless         d / k > r
      r                 = d / k
      index             = i
      type              = :standard
      i += 1
    end
  end
  return index, type, r
end

def derate(os_model, os_surface, id, surface, c, index, type, r)
  m = nil
  if surface.has_key?(:heatloss)                    &&
     surface.has_key?(:net)                         &&
     surface[:heatloss].is_a?(Numeric)              &&
     surface[:net].is_a?(Numeric)                   &&
     id == os_surface.nameString                    &&
     index != nil                                   &&
     index.is_a?(Integer)                           &&
     index >= 0                                     &&
     r.is_a?(Numeric)                               &&
     r >= 0.001                                     &&
     / tbd/i.match(c.nameString) == nil             &&
     (type == :massless || type == :standard)

     u              = surface[:heatloss] / surface[:net]
     loss           = 0.0
     de_u           = 1.0 / r + u                       # derated U
     de_r           = 1.0 / de_u                        # derated R

     if type == :massless
       m            = c.getLayer(index).to_MasslessOpaqueMaterial
       unless m.empty?
         m          = m.get
         m          = m.clone(os_model)
         m          = m.to_MasslessOpaqueMaterial.get
                      m.setName("#{id} #{m.nameString} tbd")

         unless de_r > 0.001
           de_r     = 0.001
           de_u     = 1.0 / de_r
           loss     = (de_u - 1.0 / r) / surface[:net]
         end
         m.setThermalResistance(de_r)
       end
     else # type == :standard
       m            = c.getLayer(index).to_StandardOpaqueMaterial
       unless m.empty?
         m          = m.get
         m          = m.clone(os_model)
         m          = m.to_StandardOpaqueMaterial.get
                      m.setName("#{id} #{m.nameString} tbd")
         k          = m.thermalConductivity
         if de_r > 0.001
           d        = de_r * k
           unless d > 0.003
             d      = 0.003
             k      = d / de_r
             unless k < 3.0
               k    = 3.0
               loss = (k / d - 1.0 / r) / surface[:net]
             end
           end
         else       # de_r < 0.001 m2.K/W
           d        = 0.001 * k
           unless d > 0.003
             d      = 0.003
             k      = d / 0.001
           end
           loss     = (k / d - 1.0 / r) / surface[:net]
         end

         m.setThickness(d)
         m.setThermalConductivity(k)
       end
     end

     unless m.nil?
       surface[:r_heatloss] = loss if loss > 0
     end
   end
   return m
end

class PSI
  # @return [Hash] PSI set
  attr_reader :set

  def initialize
    @set = {}

    # The following examples are defaults (* stated, ** presumed). Users may edit
    # these sets, add new sets, or even read-in other sets on file.
    @set[ "poor (BC Hydro)" ] =
    {
      rimjoist:     1.000, # *
      parapet:      0.800, # *
      fenestration: 0.500, # *
      concave:      0.850, # *
      convex:       0.850, # *
      balcony:      1.000, # *
      party:        1.000, # **
      grade:        1.000  # **
    }.freeze

    @set[ "regular (BC Hydro)" ] =
    {
      rimjoist:     0.500, # *
      parapet:      0.450, # *
      fenestration: 0.350, # *
      concave:      0.450, # *
      convex:       0.450, # *
      balcony:      0.500, # *
      party:        0.500, # **
      grade:        0.450  # *
    }.freeze

    @set[ "efficient (BC Hydro)" ] =
    {
      rimjoist:     0.200, # *
      parapet:      0.200, # *
      fenestration: 0.200, # *
      concave:      0.200, # *
      convex:       0.200, # *
      balcony:      0.200, # *
      party:        0.200, # *
      grade:        0.200  # *
    }.freeze
    # www.bchydro.com/content/dam/BCHydro/customer-portal/documents/power-smart/
    # business/programs/BETB-Building-Envelope-Thermal-Bridging-Guide-v1-3.pdf

    @set[ "code (Quebec)" ] = # NECB-QC (code-compliant) defaults:
    {
      rimjoist:     0.300, # *
      parapet:      0.325, # *
      fenestration: 0.350, # **
      concave:      0.450, # **
      convex:       0.450, # **
      balcony:      0.500, # *
      party:        0.500, # **
      grade:        0.450  # *
    }.freeze
    # www2.publicationsduquebec.gouv.qc.ca/dynamicSearch/telecharge.php?type=1&file=72541.pdf

    @set[ "(without thermal bridges)" ] = # ... would not derate surfaces:
    {
      rimjoist:     0.000, #
      parapet:      0.000, #
      fenestration: 0.000, #
      concave:      0.000, #
      convex:       0.000, #
      balcony:      0.000, #
      party:        0.000, # **
      grade:        0.000  # *
    }.freeze
  end
end
