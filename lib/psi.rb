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
      if m.thermalResistance < 0.001 || m.thermalResistance < r
        i += 1
        next
      else
        r                 = m.thermalResistance
        index             = i
        type              = :massless
      end
    end

    unless m.to_StandardOpaqueMaterial.empty?
      m                 = m.to_StandardOpaqueMaterial.get
      k                 = m.thermalConductivity
      d                 = m.thickness
      if d < 0.003 || k > 3.0 || d / k < r
        i += 1
        next
      else
        r                 = d / k
        index             = i
        type              = :standard
      end
    end
    i += 1
  end
  return index, type, r
end

def derate(os_model, os_surface, id, surface, c, index, type, r)
  m = nil
  if surface.has_key?(:heatloss)                   &&
    surface.has_key?(:net)                         &&
    surface[:heatloss].is_a?(Numeric)              &&
    surface[:net].is_a?(Numeric)                   &&
    id == os_surface.nameString                    &&
    index != nil                                   &&
    index.is_a?(Integer)                           &&
    index >= 0                                     &&
    r.is_a?(Numeric)                               &&
    r >= 0.001                                     &&
    (type == :massless || type == :standard)       &&
    / tbd/i.match(c.nameString) == nil # skip if already derated

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
                     m.setName("#{id} m tbd")

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
                     m.setName("#{id} m tbd")
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

def processTBD(os_model, psi_set)
  surfaces = {}

  os_model_class = OpenStudio::Model::Model
  raise "Empty OpenStudio Model"    unless os_model
  raise "Empty PSI set"             unless psi_set
  raise "Invalid OpenStudio Model"  unless os_model.is_a?(os_model_class)
  raise "Invalid PSI set"           unless psi_set.is_a?(Hash)

  os_building = os_model.getBuilding

  # Create the Topolys Model.
  t_model = Topolys::Model.new

  # Fetch OpenStudio (opaque) surfaces & key attributes.
  os_model.getSurfaces.each do |s|
    next if s.space.empty?
    space = s.space.get
    id    = s.nameString

    # Site-specific (or absolute, or true) surface normal.
    t, r = transforms(os_model, space)
    n = trueNormal(s, r)

    type = :floor
    type = :ceiling if /ceiling/i.match(s.surfaceType)
    type = :wall    if /wall/i.match(s.surfaceType)

    ground   = s.isGroundSurface
    boundary = s.outsideBoundaryCondition
    points   = (t * s.vertices).map{ |v| Topolys::Point3D.new(v.x, v.y, v.z) }
    minz     = (points.map{ |p| p.z }).min

    # Content of the hash will evolve over the next few hundred lines.
    surfaces[id] = {
      type:     type,
      ground:   ground,
      boundary: boundary,
      space:    space,
      gross:    s.grossArea,
      net:      s.netArea,
      points:   points,
      minz:     minz,
      n:        n
    }
  end # (opaque) surfaces populated

  # Fetch OpenStudio subsurfaces & key attributes.
  os_model.getSubSurfaces.each do |s|
    next if s.space.empty?
    next if s.surface.empty?
    space = s.space.get
    dad   = s.surface.get.nameString
    id    = s.nameString

    # Site-specific (or absolute, or true) surface normal.
    t, r = transforms(os_model, space)
    n = trueNormal(s, r)

    type = :skylight
    type = :window if /window/i.match(s.subSurfaceType)
    type = :door if /door/i.match(s.subSurfaceType)

    points = (t * s.vertices).map{ |v| Topolys::Point3D.new(v.x, v.y, v.z) }
    minz = (points.map{ |p| p.z }).min

    # For every kid, there's a dad somewhere ...
    surfaces.each do |identifier, properties|
      if identifier == dad
        sub = { points: points, minz: minz, n: n }
        if type == :window
          properties[:windows] = {} unless properties.has_key?(:windows)
          properties[:windows][id] = sub
        elsif type == :door
          properties[:doors] = {} unless properties.has_key?(:doors)
          properties[:doors][id] = sub
        else # skylight
          properties[:skylights] = {} unless properties.has_key?(:skylights)
          properties[:skylights][id] = sub
        end
      end
    end
  end # (opaque) surface "dads" populated with subsurface "kids"

  # Sort kids.
  surfaces.values.each do |p|
    if p.has_key?(:windows)
      p[:windows] = p[:windows].sort_by{ |_, pp| pp[:minz] }.to_h
    end
    if p.has_key?(:doors)
      p[:doors] = p[:doors].sort_by{ |_, pp| pp[:minz] }.to_h
    end
    if p.has_key?(:skylights)
      p[:skylights] = p[:skylights].sort_by{ |_, pp| pp[:minz] }.to_h
    end
  end

  # Split "surfaces" hash into "floors", "ceilings" and "walls" hashes.
  floors = surfaces.select{ |i, p| p[:type] == :floor }
  floors = floors.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h

  ceilings = surfaces.select{ |i, p| p[:type] == :ceiling }
  ceilings = ceilings.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h

  walls = surfaces.select{|i, p| p[:type] == :wall }
  walls = walls.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h

  # Remove ":type" (now redundant).
  surfaces.values.each do |p| p.delete_if { |ii, _| ii == :type }; end

  # Fetch OpenStudio shading surfaces & key attributes.
  shades = {}
  os_model.getShadingSurfaces.each do |s|
    next if s.shadingSurfaceGroup.empty?
    group = s.shadingSurfaceGroup.get
    id = s.nameString

    # Site-specific (or absolute, or true) surface normal. Shading surface
    # groups may also be linked to (rotated) spaces.
    t, r = transforms(os_model, group)
    shading = group.to_ShadingSurfaceGroup
    unless shading.empty?
      unless shading.get.space.empty?
        r += shading.get.space.get.directionofRelativeNorth
      end
    end
    n = trueNormal(s, r)

    points = (t * s.vertices).map{ |v| Topolys::Point3D.new(v.x, v.y, v.z) }
    minz = (points.map{ |p| p.z }).min

    shades[id] = {
      group:  group,
      points: points,
      minz:   minz,
      n:      n
    }
  end # shading surfaces populated

  # Mutually populate TBD & Topolys surfaces. Keep track of created "holes".
  holes = {}
  floor_holes = populateTBDdads(t_model, floors)
  ceiling_holes = populateTBDdads(t_model, ceilings)
  wall_holes = populateTBDdads(t_model, walls)

  holes.merge!(floor_holes)
  holes.merge!(ceiling_holes)
  holes.merge!(wall_holes)

  populateTBDdads(t_model, shades)

  # Loop through Topolys edges and populate TBD edge hash. Initially, there
  # should be a one-to-one correspondence between Topolys and TBD edge
  # objects. TBD edges shared only by non-deratable surfaces (e.g. 2x interior
  # walls, or outer edges of shadng surfaces) will either be removed from the
  # hash, or ignored (on the fence right now). Use Topolys-generated
  # identifiers as unique edge hash keys.
  edges = {}

  # Start with hole edges.
  holes.each do |id, wire|
    wire.edges.each do |e|
      unless edges.has_key?(e.id)
        edges[e.id] = { length: e.length,
                        v0: e.v0,
                        v1: e.v1,
                        surfaces: {}}
      end
      unless edges[e.id][:surfaces].has_key?(wire.attributes[:id])
        edges[e.id][:surfaces][wire.attributes[:id]] = { wire: wire.id }
      end
    end
  end

  # Next, floors, ceilings & walls; then shades.
  tbdSurfaceEdges(floors, edges)
  tbdSurfaceEdges(ceilings, edges)
  tbdSurfaceEdges(walls, edges)
  tbdSurfaceEdges(shades, edges)

  # Thermal bridging characteristics of edges are determined - in part - by
  # relative polar position of linked surfaces (or wires) around each edge.
  # This characterization is key in distinguishing concave from convex edges.

  # For each linked surface (or rather surface wires), set polar position
  # around edge with respect to a reference vector (perpendicular to the
  # edge), +clockwise as one is looking in the opposite position of the edge
  # vector. For instance, a vertical edge has a reference vector pointing
  # North - surfaces eastward of the edge are (0°,180°], while surfaces
  # westward of the edge are (180°,360°].

  # Much of the following code is of a topological nature, and should ideally
  # (or eventually) become available functionality offered by Topolys. Topolys
  # "wrappers" like TBD are good test beds to identify desired functionality
  # for future Topolys enhancements.
  zenith = Topolys::Vector3D.new(0, 0, 1).freeze
  north  = Topolys::Vector3D.new(0, 1, 0).freeze
  east   = Topolys::Vector3D.new(1, 0, 0).freeze

  edges.values.each do |edge|
    origin      = edge[:v0].point
    terminal    = edge[:v1].point

    horizontal  = false
    horizontal  = true if (origin.z - terminal.z).abs < 0.01
    vertical    = false
    vertical    = true if (origin.x - terminal.x).abs < 0.01 &&
                          (origin.y - terminal.y).abs < 0.01

    edge_V = terminal - origin
    edge_plane = Topolys::Plane3D.new(origin, edge_V)

    if vertical
      reference_V = north.dup
    elsif horizontal
      reference_V = zenith.dup
    else # project zenith vector unto edge plane
      reference = edge_plane.project(origin + zenith)
      reference_V = reference - origin
    end

    edge[:surfaces].each do |id, surface|
      # Loop through each linked wire and determine farthest point from
      # edge while ensuring candidate point is not aligned with edge.
      t_model.wires.each do |wire|
        if surface[:wire] == wire.id # there should be a unique match
          normal = surfaces[id][:n]         if surfaces.has_key?(id)
          normal = holes[id].attributes[:n] if holes.has_key?(id)
          normal = shades[id][:n]           if shades.has_key?(id)

          farthest = Topolys::Point3D.new(origin.x, origin.y, origin.z)
          farthest_V = farthest - origin # zero magnitude, initially

          inverted = false

          i_origin = wire.points.index(origin)
          i_terminal = wire.points.index(terminal)
          i_last = wire.points.size - 1

          if i_terminal == 0
            inverted = true unless i_origin == i_last
          elsif i_origin == i_last
            inverted = true unless i_terminal == 0
          else
            inverted = true unless i_terminal - i_origin == 1
          end

          wire.points.each do |point|
            next if point == origin
            next if point == terminal
            point_on_plane = edge_plane.project(point)
            origin_point_V = point_on_plane - origin
            point_V_magnitude = origin_point_V.magnitude
            next unless point_V_magnitude > 0.01

            # Generate a plane between origin, terminal & point. Only consider
            # planes that share the same normal as wire.
            if inverted
              plane = Topolys::Plane3D.from_points(terminal, origin, point)
            else
              plane = Topolys::Plane3D.from_points(origin, terminal, point)
            end

            next unless (normal.x - plane.normal.x).abs < 0.01 &&
                        (normal.y - plane.normal.y).abs < 0.01 &&
                        (normal.z - plane.normal.z).abs < 0.01

            if point_V_magnitude > farthest_V.magnitude
              farthest = point
              farthest_V = origin_point_V
            end
          end

          angle = reference_V.angle(farthest_V)

          # Adjust angle [180°, 360°] if necessary.
          adjust = false

          if vertical
            adjust = true if east.dot(farthest_V) < -0.01
          else
            if north.dot(farthest_V).abs < 0.01            ||
              (north.dot(farthest_V).abs - 1).abs < 0.01
                adjust = true if east.dot(farthest_V) < -0.01
            else
              adjust = true if north.dot(farthest_V) < -0.01
            end
          end

          angle = 2 * Math::PI - angle if adjust
          angle -= 2 * Math::PI if (angle - 2 * Math::PI).abs < 0.01

          # store angle
          surface[:angle] = angle
          farthest_V.normalize!
          surface[:polar] = farthest_V
          surface[:normal] = normal
        end
      end # end of edge-linked, surface-to-wire loop
    end # end of edge-linked surface loop

    # sort angles
    edge[:surfaces] = edge[:surfaces].sort_by{ |i, p| p[:angle] }.to_h
  end # end of edge loop

  # Topolys edges may constitute thermal bridges (and therefore thermally
  # derate linked OpenStudio surfaces), depending on a number of factors such
  # as surface types and boundary conditions. Thermal bridging attributes
  # (type & PSI-value pairs) are grouped into PSI sets (method argument).
  edges.values.each do |edge|
    next unless edge.has_key?(:surfaces)
    next unless edge[:surfaces].size > 1

    # Skip unless one (at least) linked surface is deratable, i.e.
    # outside-facing floor, ceiling or wall. Ground-facing surfaces
    # are equally processed (up to a point), as the coupling of TBD
    # edges and OpenStudio/EnergyPlus ground-facing surfaces
    # isn't currently enabled, e.g. KIVA ... TO DO.
    deratable = false
    edge[:surfaces].each do |id, surface|
      deratable = true if floors.has_key?(id)
      deratable = true if ceilings.has_key?(id)
      deratable = true if walls.has_key?(id)
    end
    next unless deratable

    psi = {}
    edge[:surfaces].keys.each do |id|
      next unless surfaces.has_key?(id)
      # Skipping the :party wall label for now. Criteria determining party
      # wall edges from TBD edges is to be determined. Most likely scenario
      # seems to be an edge linking only 1x outside-facing or ground-facing
      # surface with only 1x adiabatic surface. Warrants separate tests.
      # TO DO.

      # Label edge as :grade if linked to:
      #   1x ground-facing surface (e.g. slab or wall)
      #   1x outside-facing surface (i.e. normally a wall)
      unless psi.has_key?(:grade)
        edge[:surfaces].keys.each do |i|
          next unless surfaces.has_key?(i)
          next unless surfaces[i][:boundary].downcase == "Outdoors"
          next unless surfaces[id].has_key?(:ground)
          next unless surfaces[id][:ground]
          psi[:grade] = psi_set[:grade]
        end
      end

      # Label edge as :balcony if linked to:
      #   1x floor
      #   1x shade
      unless psi.has_key?(:balcony)
        edge[:surfaces].keys.each do |i|
          next unless shades.has_key?(i)
          next unless floors.has_key?(id)
          psi[:balcony] = psi_set[:balcony]
        end
      end

      # Label edge as :parapet if linked to:
      #   1x outside-facing wall &
      #   1x outside-facing ceiling
      unless psi.has_key?(:parapet)
        edge[:surfaces].keys.each do |i|
          next unless walls.has_key?(i)
          next unless walls[i][:boundary].downcase == "outdoors"
          next unless ceilings.has_key?(id)
          next unless ceilings[id][:boundary].downcase == "outdoors"
          psi[:parapet] = psi_set[:parapet]
        end
      end

      # Repeat for exposed floors vs walls, as :parapet is currently a
      # proxy for intersections between exposed floors & walls
      unless psi.has_key?(:parapet)
        edge[:surfaces].keys.each do |i|
          next unless walls.has_key?(i)
          next unless walls[i][:boundary].downcase == "outdoors"
          next unless floors.has_key?(id)
          next unless floors[id][:boundary].downcase == "outdoors"
          psi[:parapet] = psi_set[:parapet]
        end
      end

      # Repeat for exposed floors vs roofs, as :parapet is currently a
      # proxy for intersections between exposed floors & roofs
      unless psi.has_key?(:parapet)
        edge[:surfaces].keys.each do |i|
          next unless ceilings.has_key?(i)
          next unless ceilings[i][:boundary].downcase == "outdoors"
          next unless floors.has_key?(id)
          next unless floors[id][:boundary].downcase == "outdoors"
          psi[:parapet] = psi_set[:parapet]
        end
      end

      # Label edge as :rimjoist if linked to:
      #   1x outside-facing wall &
      #   1x floor
      unless psi.has_key?(:rimjoist)
        edge[:surfaces].keys.each do |i|
          next unless floors.has_key?(i)
          next unless walls.has_key?(id)
          next unless walls[id][:boundary].downcase == "outdoors"
          psi[:rimjoist] = psi_set[:rimjoist]
        end
      end

      # Label edge as :fenestration if linked to:
      #   1x subsurface
      unless psi.has_key?(:fenestration)
        edge[:surfaces].keys.each do |i|
          next unless holes.has_key?(i)
          psi[:fenestration] = psi_set[:fenestration]
        end
      end

      # Label edge as :concave or :convex (corner) if linked to:
      #   2x outside-facing walls (& relative polar positions of walls)
      unless psi.has_key?(:concave)
        edge[:surfaces].keys.each do |i|
          next if i == id
          next unless walls.has_key?(i)
          next unless walls[i][:boundary].downcase == "outdoors"
          next unless walls.has_key?(id)
          next unless walls[id][:boundary].downcase == "outdoors"

          s1 = edge[:surfaces][id]
          s2 = edge[:surfaces][i]

          angle = s2[:angle] - s1[:angle]
          next unless angle > 0
          next unless (2 * Math::PI - angle).abs > 0
          next if angle > 3 * Math::PI / 4 && angle < 5 * Math::PI / 4

          n1_d_p2 = s1[:normal].dot(s2[:polar])
          p1_d_n2 = s1[:polar].dot(s2[:normal])
          psi[:concave] = psi_set[:concave] if n1_d_p2 > 0 && p1_d_n2 > 0
          psi[:convex]  = psi_set[:convex]  if n1_d_p2 < 0 && p1_d_n2 < 0
        end
      end
    end # edge's surfaces loop

    edge[:psi] = psi unless psi.empty?
  end # edge loop

  # Loop through each edge and assign heat loss to linked surfaces.
  edges.each do |identifier, edge|
    next unless edge.has_key?(:psi)
    psi = edge[:psi].values.max
    next unless psi > 0.01
    bridge = { psi: psi,
               type: edge[:psi].key(psi),
               length: edge[:length] }

    # Retrieve valid linked surfaces as deratables.
    deratables = {}
    edge[:surfaces].each do |id, surface|
      next unless surfaces.has_key?(id)
      next unless surfaces[id][:boundary].downcase == "outdoors"
      deratables[id] = surface
    end

    # Retrieve linked openings.
    openings = {}
    if edge[:psi].has_key?(:fenestration)
      edge[:surfaces].each do |id, surface|
        next unless holes.has_key?(id)
        openings[id] = surface
      end
    end

    next if openings.size > 1 # edge links 2x openings

    # Prune if edge links an opening and its parent, as well as 1x other
    # opaque surface (i.e. corner window derates neighbour - not parent).
    if deratables.size > 1 && openings.size > 0
      deratables.each do |id, deratable|
        if surfaces[id].has_key?(:windows)
          surfaces[id][:windows].keys.each do |i|
            deratables.delete(id) if openings.has_key?(i)
          end
        end
        if surfaces[id].has_key?(:doors)
          surfaces[id][:doors].keys.each do |i|
            deratables.delete(id) if openings.has_key?(i)
          end
        end
        if surfaces[id].has_key?(:skylights)
          surfaces[id][:skylights].keys.each do |i|
            deratables.delete(id) if openings.has_key?(i)
          end
        end
      end
    end

    next unless deratables.size > 0

    # Split thermal bridge heat loss equally amongst deratable surfaces.
    bridge[:psi] /= deratables.size

    # Assign heat loss from thermal bridges to surfaces.
    deratables.each do |id, deratable|
      surfaces[id][:edges] = {} unless surfaces[id].has_key?(:edges)
      surfaces[id][:edges][identifier] = bridge
    end
  end

  # Assign thermal bridging heat loss [in W/K] to each deratable surface.
  surfaces.values.each do |surface|
    next unless surface.has_key?(:edges)
    surface[:heatloss] = 0
    surface[:edges].values.each do |edge|
      surface[:heatloss] += edge[:psi] * edge[:length]
    end
  end

  # Derated (cloned) constructions are unique to each deratable surface.
  # Unique construction names are prefixed with the surface name,
  # and suffixed with " tbd", indicating that the construction is
  # henceforth thermally derated. The " tbd" expression is also key in
  # avoiding inadvertent derating - TBD will not derate constructions
  # (or rather materials) having " tbd" in its OpenStudio name.
  surfaces.each do |id, surface|
    next unless surface.has_key?(:edges)
    os_model.getSurfaces.each do |s|
      next unless id == s.nameString
      next if s.space.empty?
      space = s.space.get

      # Retrieve current surface construction.
      current_c = nil
      defaulted = false
      if s.isConstructionDefaulted
        # Check for space default set.
        space_default_set = space.defaultConstructionSet
        unless space_default_set.empty?
          space_default_set = space_default_set.get
          current_c = space_default_set.getDefaultConstruction(s)
          next if current_c.empty?
          current_c = current_c.get
          defaulted = true
        end

        # Check for building default set.
        building_default_set = os_building.defaultConstructionSet
        unless building_default_set.empty? || defaulted
          building_default_set = building_default_set.get
          current_c = building_default_set.getDefaultConstruction(s)
          next if current_c.empty?
          current_c = current_c.get
          defaulted = true
        end

        # No space or building defaults - resort to first set @model level.
        model_default_sets = os_model.getDefaultConstructionSets
        unless model_default_sets.empty? || defaulted
          model_default_set = model_default_sets.first
          current_c = model_default_set.getDefaultConstruction(s)
          next if current_c.empty?
          current_c = current_c.get
          defaulted = true
        end

        next unless defaulted
        construction_name = current_c.nameString
        c = current_c.clone(os_model).to_Construction.get

      else # ... no defaults - surface-specific construction
        current_c = s.construction.get
        construction_name = current_c.nameString
        c = current_c.clone(os_model).to_Construction.get
      end

      # index - of layer/material (to derate) in cloned construction
      # type  - either massless (RSi) or standard (k + d)
      # r     - initial RSi value of the targeted layer to derate
      index, type, r = deratableLayer(c)

      index = nil unless index.is_a?(Numeric) &&
                         index >=0            &&
                         index < c.layers.size

      # m     - newly derated, cloned material
      m = nil
      m = derate(os_model, s, id, surface, c, index, type, r) unless index.nil?

      # "m" may be nilled simply because the targeted construction has already
      # been derated, i.e. holds " tbd" in its name. Names of cloned/derated
      # constructions (due to TBD) include the surface name (since derated
      # constructions are unique to each surface) and the suffix " c tbd".
      unless m.nil?
        c.setLayer(index, m)
        c.setName("#{id} c tbd")

        # Compute current RSi value from layers.
        current_R = s.filmResistance
        current_c.to_Construction.get.layers.each do |l|
          r = 0
          unless l.to_MasslessOpaqueMaterial.empty?
            l = l.to_MasslessOpaqueMaterial.get
            r = l.to_MasslessOpaqueMaterial.get.thermalResistance
          end

          unless l.to_StandardOpaqueMaterial.empty?
            l = l.to_StandardOpaqueMaterial.get
            k = l.thermalConductivity
            d = l.thickness
            r = d / k
          end
          current_R += r
        end

        s.setConstruction(c)

        # Compute updated RSi value from layers. Revise to use
        # "thermalConductance" and/or "uFactor"
        updated_R = s.filmResistance
        updated_c = s.construction.get
        updated_c.to_Construction.get.layers.each do |l|
          r = 0
          unless l.to_MasslessOpaqueMaterial.empty?
            l = l.to_MasslessOpaqueMaterial.get
            r = l.thermalResistance
          end

          unless l.to_StandardOpaqueMaterial.empty?
            l = l.to_StandardOpaqueMaterial.get
            k = l.thermalConductivity
            d = l.thickness
            r = d / k
          end
          updated_R += r
        end

        ratio  = -(current_R - updated_R) * 100 / current_R
        surface[:ratio] = ratio
      end
    end
  end
end
