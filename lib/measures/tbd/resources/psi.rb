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

# Set 10mm tolerance for edge (thermal bridge) vertices.
TOL = 0.01

# Sources for thermal bridge types and/or linked default KHI & PSI values/sets:

# BETBG = Building Envelope Thermal Bridging Guide v1.4
# www.bchydro.com/content/dam/BCHydro/customer-portal/documents/power-smart/
# business/programs/BETB-Building-Envelope-Thermal-Bridging-Guide-v1-4.pdf

# ISO 14683 (Appendix C) www.iso.org/standard/65706.html

# NECB-QC: Québec's energy code for new commercial buildings
# www2.publicationsduquebec.gouv.qc.ca/dynamicSearch/telecharge.php?type=1&file=72541.pdf

##
# Library of point thermal bridges (e.g. columns). Each key:value entry
# requires a unique identifier e.g. "poor (BETBG)" and a KHI-value in W/K.
class KHI
  # @return [Hash] KHI library
  attr_reader :point

  ##
  # Construct a new KHI library (with defaults)
  def initialize
    @point = {}

    # The following are defaults. Users may edit these defaults,
    # append new key:value pairs, or even read-in other pairs on file.
    # Units are in W/K.
    @point[ "poor (BETBG)" ]            = 0.900 # detail 5.7.2 BETBG
    @point[ "regular (BETBG)" ]         = 0.500 # detail 5.7.4 BETBG
    @point[ "efficient (BETBG)" ]       = 0.150 # detail 5.7.3 BETBG
    @point[ "code (Quebec)" ]           = 0.500 # art. 3.3.1.3. NECB-QC
    @point[ "(non thermal bridging)" ]  = 0.000
  end

  ##
  # Append a new KHI pair, based on a TBD JSON-formatted KHI object.
  # Requires a valid, unique :id
  #
  # @param [Hash] k A (identifier):(KHI) pair
  def append(k)
    if k.is_a?(Hash) && k.has_key?(:id)
      id = k[:id]
      @point[id] = k[:point] unless @point.has_key?(id)
      # should log message if duplicate attempt
    end
    # should log message if else
  end
end

##
# Library of linear thermal bridges (e.g. corners, balconies). Each key:value
# entry requires a unique identifier e.g. "poor (BETBG)" and a (partial or
# complete) set of PSI-values in W/K per linear meter.
class PSI
  # @return [Hash] PSI set
  attr_reader :set

  ##
  # Construct a new PSI library (with defaults)
  def initialize
    @set = {}

    # The following are defaults PSI values (* published, ** calculated). Users
    # may edit these sets, add new sets here, or read-in bespoke sets from a TBD
    # JSON input file. PSI units are in W/K per linear meter.

    # Convex or concave corner PSI adjustments may be warranted if there is a
    # mismatch between dimensioning conventions (interior vs exterior) used for
    # the OSM vs published PSI data. For instance, the BETBG data reflects an
    # interior dimensioning convention, while ISO 14683 reports PSI values for
    # both conventions. The following may be used to adjust BETBG PSI values for
    # convex corners when using outside dimensions for an OSM.
    #
    # PSIe = PSIi + U * 2(Li-Le), where:
    #   PSIe = adjusted PSI                                          (W/K per m)
    #   PSIi = initial published PSI                                 (W/K per m)
    #      U = average clear field U-factor of adjacent walls           (W/m2.K)
    #     Li = from interior corner to edge of "zone of influence"           (m)
    #     Le = from exterior corner to edge of "zone of influence"           (m)
    #
    #  Li-Le = wall thickness e.g., -0.25m (negative here as Li < Le)
    #
    # TO DO: Allow negative PSI values (see ISO 14683).

    @set[ "poor (BETBG)" ] =
    {
      rimjoist:     1.000, # *
      parapet:      0.800, # *
      fenestration: 0.500, # *
      concave:      0.850, # *
      convex:       0.850, # *
      balcony:      1.000, # *
      party:        0.850, # *
      grade:        0.850  # *
    }.freeze               # based on INTERIOR dimensions (p.15 BETBG)

    @set[ "regular (BETBG)" ] =
    {
      rimjoist:     0.500, # *
      parapet:      0.450, # *
      fenestration: 0.350, # *
      concave:      0.450, # *
      convex:       0.450, # *
      balcony:      0.500, # *
      party:        0.450, # *
      grade:        0.450  # *
    }.freeze               # based on INTERIOR dimensions (p.15 BETBG)

    @set[ "efficient (BETBG)" ] =
    {
      rimjoist:     0.200, # *
      parapet:      0.200, # *
      fenestration: 0.200, # *
      concave:      0.200, # *
      convex:       0.200, # *
      balcony:      0.200, # *
      party:        0.200, # *
      grade:        0.200  # *
    }.freeze               # based on INTERIOR dimensions (p.15 BETBG)

    @set[ "code (Quebec)" ] = # NECB-QC (code-compliant) defaults:
    {
      rimjoist:     0.300, # *
      parapet:      0.325, # *
      fenestration: 0.350, # ** "regular (BETBG)"
      concave:      0.300, # ** (see convex)
      convex:       0.300, # ** "regular (BETBG)", adjusted for ext. dimension
      balcony:      0.500, # *
      party:        0.450, # ** "regular (BETBG)"
      grade:        0.450  # *
    }.freeze               # based on EXTERIOR dimensions (art. 3.1.1.6)

    @set[ "(non thermal bridging)" ] = # ... would not derate surfaces:
    {
      rimjoist:     0.000, #
      parapet:      0.000, #
      fenestration: 0.000, #
      concave:      0.000, #
      convex:       0.000, #
      balcony:      0.000, #
      party:        0.000, #
      grade:        0.000  #
    }.freeze
  end

  ##
  # Append a new PSI set, based on a TBD JSON-formatted PSI set object.
  # Requires a valid, unique :id.
  #
  # @param [Hash] p A (identifier):(PSI set) pair
  def append(p)
    if p.is_a?(Hash) && p.has_key?(:id)
      id = p[:id]
      unless @set.has_key?(id)       # should log message if duplication attempt
        @set[id] = {}

        @set[id][:rimjoist]     = p[:rimjoist]     if p.has_key?(:rimjoist)
        @set[id][:parapet]      = p[:parapet]      if p.has_key?(:parapet)
        @set[id][:fenestration] = p[:fenestration] if p.has_key?(:fenestration)
        @set[id][:concave]      = p[:concave]      if p.has_key?(:concave)
        @set[id][:convex]       = p[:convex]       if p.has_key?(:convex)
        @set[id][:balcony]      = p[:balcony]      if p.has_key?(:balcony)
        @set[id][:party]        = p[:party]        if p.has_key?(:party)
        @set[id][:grade]        = p[:grade]        if p.has_key?(:grade)
      end
    end
    # should log if else message
  end

  ##
  # Validate whether a stored PSI set has a complete list of PSI type:values
  #
  # @param [String] s A PSI set identifier
  #
  # @return [Boolean] Returns true if stored and has a complete PSI set
  def complete?(s) # true/false
    answer = @set.has_key?(s)
    answer = answer && @set[s].has_key?(:rimjoist)
    answer = answer && @set[s].has_key?(:parapet)
    answer = answer && @set[s].has_key?(:fenestration)
    answer = answer && @set[s].has_key?(:concave)
    answer = answer && @set[s].has_key?(:convex)
    answer = answer && @set[s].has_key?(:balcony)
    answer = answer && @set[s].has_key?(:party)
    answer = answer && @set[s].has_key?(:grade)
    answer
  end
end

##
# Check for matching vertex pairs between edges (10mm tolerance).
# @param [Hash] e1 First edge
# @param [Hash] e2 Second edge
#
# @return [Boolean] Returns true if edges share vertex pairs
def matches?(e1, e2)
  raise "matches? missing edges" unless e1 && e2
  raise "matches? missing :v0 for e1" unless e1.has_key?(:v0)
  raise "matches? missing :v1 for e1" unless e1.has_key?(:v1)
  raise "matches? missing :v0 for e2" unless e2.has_key?(:v0)
  raise "matches? missing :v1 for e2" unless e2.has_key?(:v1)
  raise "e1 v0: #{e1[:v0].class}? expected a Topolys point3D" unless e1[:v0].is_a?(Topolys::Point3D)
  raise "e1 v1: #{e1[:v1].class}? expected a Topolys point3D" unless e1[:v1].is_a?(Topolys::Point3D)
  raise "e2 v0: #{e1[:v0].class}? expected a Topolys point3D" unless e2[:v0].is_a?(Topolys::Point3D)
  raise "e2 v1: #{e1[:v1].class}? expected a Topolys point3D" unless e2[:v1].is_a?(Topolys::Point3D)

  answer = false
  e1_vector = e1[:v1] - e1[:v0]
  e2_vector = e2[:v1] - e2[:v0]
  raise "matches? e1 length <= 10mm" if e1_vector.magnitude < TOL
  raise "matches? e2 length <= 10mm" if e2_vector.magnitude < TOL

  answer = true if
  (
    (
      ( (e1[:v0].x - e2[:v0].x).abs < TOL &&
        (e1[:v0].y - e2[:v0].y).abs < TOL &&
        (e1[:v0].z - e2[:v0].z).abs < TOL
      ) ||
      ( (e1[:v0].x - e2[:v1].x).abs < TOL &&
        (e1[:v0].y - e2[:v1].y).abs < TOL &&
        (e1[:v0].z - e2[:v1].z).abs < TOL
      )
    ) &&
    (
      ( (e1[:v1].x - e2[:v0].x).abs < TOL &&
        (e1[:v1].y - e2[:v0].y).abs < TOL &&
        (e1[:v1].z - e2[:v0].z).abs < TOL
      ) ||
      ( (e1[:v1].x - e2[:v1].x).abs < TOL &&
        (e1[:v1].y - e2[:v1].y).abs < TOL &&
        (e1[:v1].z - e2[:v1].z).abs < TOL
      )
    )
  )
  answer
end

##
# Process TBD user inputs, after TBD has processed OpenStudio model variables
# and retrieved corresponding Topolys model surface/edge properties. TBD user
# inputs allow customization of default assumptions and inferred values.
# If successful, "edges" (input) may inherit additional properties, e.g.:
# :io_set  = edge-specific PSI set, held in TBD JSON file
# :io_type = edge-specific PSI type (e.g. "corner"), held in TBD JSON file
# :io_unit = project-wide PSI set, if absent from TBD JSON file
#
# @param [Hash] surfaces Preprocessed collection of TBD surfaces
# @param [Hash] edges Preprocessed collection TBD edges
# @param [String] set Default) PSI set identifier, can be "" (empty)
# @param [String] io_path Path to a user-set TBD JSON input file (optional)
# @param [String] schema_path Path to a TBD JSON schema file (optional)
#
# @return [Hash] Returns a JSON-generated collection of user inputs
# @return [Hash] Returns a new PSI library, enriched with optional sets on file
# @return [Hash] Returns a new KHI library, enriched with optional pairs on file
def processTBDinputs(surfaces, edges, set, io_path = nil, schema_path = nil)
  # In the near future, the bulk of the "raises" in processTBDinputs will
  # be logged as mild or severe warnings, possibly halting all TBD processes
  # The OpenStudio/EnergyPlus model would remain unaltered (or un-derated).

  # JSON validation relies on case-senitive string comparisons (e.g. OpenStudio
  # space or surface names, vs corresponding TBD JSON identifiers). So "Space-1"
  # would not match "SPACE-1". A head's up ...
  io = {}
  psi = PSI.new                  # PSI hash, initially holding built-in defaults
  khi = KHI.new                  # KHI hash, initially holding built-in defaults

  raise "processTBDinputs: invalid TBD surfaces?" unless surfaces
  unless surfaces.is_a?(Hash)
    raise "processTBDinputs: TBD surfaces class #{surfaces.class}?"
  end

  raise "processTBDinputs: invalid TBD edges?" unless edges
  unless edges.is_a?(Hash)
    raise "processTBDinputs: TBD edges class #{edges.class}?"
  end

  if io_path && File.size?(io_path) # optional input file exists and is non-zero
    io_c = File.read(io_path)
    io = JSON.parse(io_c, symbolize_names: true)

    # schema validation is not yet supported in the OpenStudio Application
    if schema_path
      require "json-schema"

      raise "processTBDinputs: TBD schema file?" unless File.exist?(schema_path)
      raise "processTBDinputs: Empty TBD schema file?" if File.zero?(schema_path)
      schema_c = File.read(schema_path)
      schema = JSON.parse(schema_c, symbolize_names: true)

      if !JSON::Validator.validate!(schema, io)
        # Log severe warning: enable to parse (invalid) user TBD JSON file
      end
    end

    # Clear any stored log messages ... TO DO

    if io.has_key?(:psis)                    # library of linear thermal bridges
      io[:psis].each do |p| psi.append(p); end
    end

    if io.has_key?(:khis)                     # library of point thermal bridges
      io[:khis].each do |k| khi.append(k); end
    end

    if io.has_key?(:unit)
      raise "Unit PSI?" unless io[:unit].first.has_key?(:psi)
    else
      # No unit PSI - "set" must default to a built-in PSI set.
      io[:unit] = [{ psi: set }]               # i.e. default PSI set & no KHI's
    end

    p = io[:unit].first[:psi]
    raise "Incomplete PSI set #{p}" unless psi.complete?(p)

    if io.has_key?(:stories)
      io[:stories].each do |story|
        next unless story.has_key?(:id)
        next unless story.has_key?(:psi)
        i = story[:id]
        p = story[:psi]
        raise "#{i} PSI mismatch" unless psi.set.has_key?(p)
        # ... later, validate "id" vs OSM/IDF group names (ZoneLists?)
      end
    end

    if io.has_key?(:spaces)
      io[:spaces].each do |space|
        next unless space.has_key?(:id)
        next unless space.has_key?(:psi)
        i = space[:id]
        p = space[:psi]

        # Validate if space "id" is found in surfaces hash
        match = false
        surfaces.values.each do |properties|
          next if match
          next unless properties.has_key?(:space)
          sp = properties[:space]
          match = true if i == sp.nameString
        end
        raise "Mismatch OpenStudio #{i}" unless match
        raise "#{i} PSI mismatch" unless psi.set.has_key?(p)
      end
    end

    if io.has_key?(:surfaces)
      io[:surfaces].each do |surface|
        next unless surface.has_key?(:id)
        i = surface[:id]
        raise "Mismatch OpenStudio #{i}" unless surfaces.has_key?(i)

        # surfaces can optionally hold custom PSI sets and/or KHI data
        if surface.has_key?(:psi)
          p = surface[:psi]
          raise "#{i} PSI mismatch" unless psi.set.has_key?(p)
        end

        if surface.has_key?(:khis)
          surface[:khis].each do |k|
            next unless k.has_key?(:id)
            ii = k[:id]
            raise "#{i} KHI #{ii} mismatch" unless khi.point.has_key?(ii)
          end
        end
      end
    end

    if io.has_key?(:edges)
      io[:edges].each do |edge|
        next unless edge.has_key?(:type)
        next unless edge.has_key?(:surfaces)
        t = edge[:type].to_sym

        # One or more edges on file are valid if all their listed surfaces
        # together connect at least one or more edges in TBD/Topolys (in
        # memory). The latter may connect e.g. 3x TBD/Topolys surfaces, but
        # the list of surfaces on file may be shorter, e.g. only 2x surfaces.
        n = 0
        edge[:surfaces].each do |s|                       # JSON objects on file
          edges.values.each do |e|               # TBD/Topolys objects in memory
            next if e.has_key?(:io_type)
            match = false
            next unless e.has_key?(:surfaces)
            next unless e[:surfaces].has_key?(s)
            match = true   # ... yet all JSON surfaces must be linked in Topolys
            edge[:surfaces].each do |ss|
              match = false unless e[:surfaces].has_key?(ss)
            end

            next unless match
            if edge.has_key?(:length)    # optional, narrows down search (~10mm)
              match = false unless (e[:length] - edge[:length]).abs < TOL
            end

            if edge.has_key?(:v0x) ||
               edge.has_key?(:v0y) ||
               edge.has_key?(:v0z) ||
               edge.has_key?(:v1x) ||
               edge.has_key?(:v1y) ||
               edge.has_key?(:v1z)

              unless edge.has_key?(:v0x) &&
                     edge.has_key?(:v0y) &&
                     edge.has_key?(:v0z) &&
                     edge.has_key?(:v1x) &&
                     edge.has_key?(:v1y) &&
                     edge.has_key?(:v1z)
                raise "Edge vertices must come in pairs"          # all or none
              end
              e1 = {}
              e2 = {}
              e1[:v0] = Topolys::Point3D.new(edge[:v0x].to_f, edge[:v0y].to_f, edge[:v0z].to_f)
              e1[:v1] = Topolys::Point3D.new(edge[:v1x].to_f, edge[:v1y].to_f, edge[:v1z].to_f)
              e2[:v0] = e[:v0].point
              e2[:v1] = e[:v1].point
              match = matches?(e1, e2)
            end

            next unless match
            e[:io_type] = t
            n += 1
            if edge.has_key?(:psi)                                    # optional
              p = edge[:psi]
              raise "PSI mismatch" unless psi.set.has_key?(p)
              raise "#{p} missing PSI #{t}" unless psi.set[p].has_key?(t)
              e[:io_set] = p
            end
          end
        end
        if n == 0
          puts edge[:surfaces]
          raise "Edge: missing OpenStudio match"
        end
      end
    end
  else
    # No (optional) user-defined TBD JSON input file.
    # In such cases, "set" must refer to a valid PSI set
    raise "Incomplete PSI set #{set}" unless psi.complete?(set)
    io[:unit] = [{ psi: set }]                 # i.e. default PSI set & no KHI's
  end

  return io, psi, khi
end

##
# Return OpenStudio site/space transformation & rotation
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [OpenStudio::Model::Space or ::ShadingSurfaceGroup] group An OS group
#
# @return [OpenStudio::Transformation] Returns group vs site transformation
# @return [Float] Returns site + group rotation angle [0,2PI) radians
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

##
# Return site-specific (or absolute) Topolys surface normal
#
# @param [OpenStudio::Model::PlanarSurface] s An OS planar surface
# @param [Float] r A rotation angle [0,2PI) radians
#
# @return [OpenStudio::Vector3D] Returns normal vector <x,y,z> of s
def trueNormal(s, r)
  if s && r
    c = OpenStudio::Model::PlanarSurface
    raise "Expected #{c} - got #{s.class}" unless s.is_a?(c)
    raise "Expected a numeric - got #{r.class}" unless r.is_a?(Numeric)

    n = Topolys::Vector3D.new(s.outwardNormal.x * Math.cos(r) -
                              s.outwardNormal.y * Math.sin(r),               # x
                              s.outwardNormal.x * Math.sin(r) +
                              s.outwardNormal.y * Math.cos(r),               # y
                              s.outwardNormal.z)                             # z
  end
end

##
# Return Topolys vertices and a Topolys wire from Topolys points. As
# a side effect, it will - if successful - also populate the Topolys
# model with the vertices and wire.
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [Array] points A 1D array of 3D Topolys points (min 2x)
#
# @return [Array] Returns a 1D array of 3D Topolys vertices
# @return [Topolys::Wire] Returns a corresponding Topolys wire
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

##
# Populate collection of TBD "kids", i.e. subsurfaces, relying on Topolys. As
# a side effect, it will - if successful - also populate the Topolys
# model with Topolys vertices, wires, holes.
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [Hash] kids A collection of TBD subsurfaces
#
# @return [Array] Returns a 1D array of 3D Topolys holes, i.e. wires
def populateTBDkids(model, kids)
  holes = []
  if model && kids
    unless model.is_a?(Topolys::Model)
      raise "Expected Topolys model - got #{model.class}"
    end
    unless kids.is_a?(Hash)
      raise "Expected hash of TBD surfaces - got a #{kids.class}"
    end
    kids.each do |id, properties|
      vtx, hole = topolysObjects(model, properties[:points])
      hole.attributes[:id] = id
      hole.attributes[:n] = properties[:n] if properties.has_key?(:n)
      properties[:hole] = hole
      holes << hole
    end
  end
  holes
end

##
# Populate hash of TBD "dads", i.e. (parent) surfaces, relying on Topolys. As
# a side effect, it will - if successful - also populate the Topolys
# model with Topolys vertices, wires, holes & faces.
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [Hash] dads A collection of TBD (parent) surfaces
#
# @return [Array] Returns a 1D array of 3D Topolys parent holes, i.e. wires
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

      # Create surface holes for kids.
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

      # Populate hash of created holes (to return).
      holes.each do |h| tbd_holes[h.attributes[:id]] = h; end
    end
  end
  tbd_holes
end

##
# Populate TBD edges with linked Topolys faces.
#
# @param [Hash] surfaces A collection of TBD surfaces
# @param [Hash] edges A collection TBD edges
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


##
# Generate OSM Kiva settings and objects if model surfaces have 'foundation'
# boundary conditions.
#
# @param [OpenStudio::Model::Model] os_model An OS model
# @param [Hash] floors TBD-generated floors
# @param [Hash] walls TBD-generated walls
# @param [Hash] edges TBD-generated edges (many linking floors & walls
#
# @return [Bool] Returns true if all Kiva foundations are successfully generated.
def generateKiva(os_model, walls, floors, edges)
  # Strictly rely on Kiva's total exposed perimeter approach.
  arg = "TotalExposedPerimeter"
  kiva = true

  # The following is loosely adapted from:
  # https://github.com/NREL/OpenStudio-resources/blob/develop/model/simulationtests/foundation_kiva.rb
  # ... thanks.

  # Generate template for KIVA settings. This is usually not required (the
  # default KIVA settings are fine), but its explicit inclusion in the OSM
  # does offer users easy access to further (manually) tweak settings e.g.,
  # soil properties if required. Initial tests show slight differences in
  # simulation results w/w/o explcit inclusion of the KIVA settings template
  # in the OSM. TO-DO: Check in.idf vs in.osm for any deviation from default
  # values as specified in the IO Reference Manual.
  foundation_kiva_settings = os_model.getFoundationKivaSettings

  # One way to expose in-built default parameters (in the future), e.g.:
  # soil_k = foundation_kiva_settings.soilConductivity
  # foundation_kiva_settings.setSoilConductivity(soil_k)

  # Generic 1" XPS insulation (for slab-on-grade setup) - unused if basement.
  xps_25mm = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
  xps_25mm.setRoughness("Rough")
  xps_25mm.setThickness(0.0254)
  xps_25mm.setConductivity(0.029)
  xps_25mm.setDensity(28)
  xps_25mm.setSpecificHeat(1450)
  xps_25mm.setThermalAbsorptance(0.9)
  xps_25mm.setSolarAbsorptance(0.7)

  # Tag foundation-facing floors, then walls.
  edges.values.each do |edge|
    edge[:surfaces].keys.each do |id|

      # Start by processing edge-linked foundation-facing floors.
      next unless floors.has_key?(id)
      next unless floors[id][:boundary].downcase == "foundation"

      # A match, yet skip if previously processed.
      next if floors[id].has_key?(:kiva)

      # By default, foundation floors are initially slabs-on-grade.
      floors[id][:kiva] = :slab

      # Re(tag) floors as basements if foundation-facing walls.
      edge[:surfaces].keys.each do |i|
        next unless walls.has_key?(i)
        next unless walls[i][:boundary].downcase == "foundation"
        next if walls[i].has_key?(:kiva)

        # (Re)tag as :basement if edge-linked foundation walls.
        floors[id][:kiva] = :basement
        walls[i][:kiva] = id
      end
    end
  end

  # Fetch exposed perimeters.
  edges.values.each do |edge|
    edge[:surfaces].keys.each do |id|
      next unless floors.has_key?(id)
      next unless floors[id].has_key?(:kiva)

      # Initialize if first iteration.
      floors[id][:exposed] = 0.0 unless floors[id].has_key?(:exposed)

      edge[:surfaces].keys.each do |i|
        next unless walls.has_key?(i)
        b = walls[i][:boundary].downcase
        next unless b == "foundation" || b == "outdoors"
        floors[id][:exposed] += edge[:length]
      end
    end
  end

  # Generate unique Kiva foundation per foundation-facing floor.
  edges.values.each do |edge|
    edge[:surfaces].keys.each do |id|
      next unless floors.has_key?(id)
      next unless floors[id].has_key?(:kiva)
      next if floors[id].has_key?(:foundation)

      floors[id][:foundation] = OpenStudio::Model::FoundationKiva.new(os_model)

      # It's assumed that generated foundation walls have insulated
      # constructions. Perimeter insulation for slabs-on-grade.
      # Typical circa-1980 slab-on-grade (perimeter) insulation setup.
      if floors[id][:kiva] == :slab
        floors[id][:foundation].setInteriorHorizontalInsulationMaterial(xps_25mm)
        floors[id][:foundation].setInteriorHorizontalInsulationWidth(0.6)
      end

      # Locate OSM surface and assign Kiva foundation & perimeter objects.
      found = false
      os_model.getSurfaces.each do |s|
        next unless s.nameString == id
        next unless s.outsideBoundaryCondition.downcase == "foundation"
        found = true

        # Retrieve surface (standard) construction (which may be defaulted)
        # before assigning a Kiva Foundation object to the surface. Then
        # reassign the construction (no longer defaulted).
        construction = s.construction.get
        s.setAdjacentFoundation(floors[id][:foundation])
        s.setConstruction(construction)

        # Generate surface's Kiva exposed perimeter object.
        exp = floors[id][:exposed]
        #exp = 0.01 if exp < 0.01
        perimeter = s.createSurfacePropertyExposedFoundationPerimeter(arg, exp)

        # The following 5x lines are a (temporary?) fix for exposed perimeter
        # lengths of 0m - a perfectly valid entry in an IDF (e.g. "core" slab).
        # Unfortunately OpenStudio (currently) rejects 0 as an inclusive minimum
        # value. So despite passing a valid 0 "exp" argument, OpenStudio does
        # not initialize the "TotalExposedPerimeter" entry. Compare relevant
        # EnergyPlus vs OpenStudio .idd entries.

        # The fix: if a valid Kiva exposed perimeter is equal or less than 1mm,
        # fetch the perimeter object and attempt to explicitely set the exposed
        # perimeter length to 0m. If unsuccessful (situation remains unfixed),
        # then set to 1mm. Simulations results should be virtually identical.
        unless exp > 0.001 || perimeter.empty?
          perimeter = perimeter.get
          success = perimeter.setTotalExposedPerimeter(0)
          perimeter.setTotalExposedPerimeter(0.001) unless success
        end

      end
      kiva = false unless found
    end
  end

  # Link foundation walls to right Kiva foundation objects (if applicable).
  edges.values.each do |edge|
    edge[:surfaces].keys.each do |i|
      next unless walls.has_key?(i)
      next unless walls[i].has_key?(:kiva)
      id = walls[i][:kiva]
      next unless floors.has_key?(id)
      next unless floors[id].has_key?(:foundation)

      # Locate OSM wall.
      os_model.getSurfaces.each do |s|
        next unless s.nameString == i
        s.setAdjacentFoundation(floors[id][:foundation])
        s.setConstruction(s.construction.get)
      end
    end
  end

  kiva
end

##
# Identifies a layered construction's insulating (or deratable) layer.
#
# @param [OpenStudio::Model::Construction] construction An OS construction
#
# @return [Integer] Returns index of insulating material within construction
# @return [Symbol] Returns type of insulating material (:standard or :massless)
# @return [Float] Returns insulating layer thermal resistance [m2.K/W]
def deratableLayer(construction)
  # Identify insulating material (and key attributes) within a construction.
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

##
# Thermally derate insulating material within construction.
#
# @param [OpenStudio::Model::Model] os_model An OS model
# @param [String] id Insulating material identifier
# @param [Hash] surface A TBD surface
# @param [OpenStudio::Model::Construction] c An OS construction
# @param [Integer] index Position of layer (to derate) within c
# @param [Symbol] type Insulating material type (:standard or :massless)
# @param [Float] r Thermal resistance of insulating layer [m2.K/W]
#
# @return [OpenStudio::Model::Material] Returns derated (cloned) material
def derate(os_model, id, surface, c, index, type, r)
  m = nil
  if surface.has_key?(:heatloss)                   &&
    surface.has_key?(:net)                         &&
    surface[:heatloss].is_a?(Numeric)              &&
    surface[:net].is_a?(Numeric)                   &&
    index != nil                                   &&
    index.is_a?(Integer)                           &&
    index >= 0                                     &&
    r.is_a?(Numeric)                               &&
    r >= 0.001                                     &&
    (type == :massless || type == :standard)       &&
    / tbd/i.match(c.nameString) == nil                 # skip if already derated

    u              = surface[:heatloss] / surface[:net]
    loss           = 0.0
    de_u           = 1.0 / r + u                                     # derated U
    de_r           = 1.0 / de_u                                      # derated R

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

    else                                                     # type == :standard
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
        else                                               # de_r < 0.001 m2.K/W
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
  m
end

##
# Process TBD inputs from OpenStudio and Topolys, and derate admissible envelope
# surfaces by substituting insulating material within surface constructions with
# derated clones.
#
# @param [OpenStudio::Model::Model] os_model An OS model
# @param [String] psi_set Default PSI set identifier, can be "" (empty)
# @param [String] io_path Path to a user-set TBD JSON input file (optional)
# @param [String] schema_path Path to a TBD JSON schema file (optional)
# @param [Bool] gen_kiva Have TBD generate Kiva objects
#
# @return [Hash] Returns TBD collection of objects for JSON serialization
# @return [Hash] Returns collection of derated TBD surfaces
def processTBD(os_model, psi_set, io_path = nil, schema_path = nil, gen_kiva)
  surfaces = {}

  os_model_class = OpenStudio::Model::Model
  raise "Empty OpenStudio Model"    unless os_model
  raise "Invalid OpenStudio Model"  unless os_model.is_a?(os_model_class)

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
  end                                              # (opaque) surfaces populated

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
  end                 # (opaque) surface "dads" populated with subsurface "kids"

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
  end                                               # shading surfaces populated

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

  # Generate OSM Kiva settings and objects if foundation-facing floors.
  # 'kiva' == false if partial failure (log failure eventually).
  kiva = generateKiva(os_model, walls, floors, edges) if gen_kiva

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
    else                                 # project zenith vector unto edge plane
      reference = edge_plane.project(origin + zenith)
      reference_V = reference - origin
    end

    edge[:surfaces].each do |id, surface|
      # Loop through each linked wire and determine farthest point from
      # edge while ensuring candidate point is not aligned with edge.
      t_model.wires.each do |wire|
        if surface[:wire] == wire.id            # there should be a unique match
          normal = surfaces[id][:n]         if surfaces.has_key?(id)
          normal = holes[id].attributes[:n] if holes.has_key?(id)
          normal = shades[id][:n]           if shades.has_key?(id)

          farthest = Topolys::Point3D.new(origin.x, origin.y, origin.z)
          farthest_V = farthest - origin             # zero magnitude, initially

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
      end                             # end of edge-linked, surface-to-wire loop
    end                                        # end of edge-linked surface loop

    # sort angles
    edge[:surfaces] = edge[:surfaces].sort_by{ |i, p| p[:angle] }.to_h
  end                                                         # end of edge loop

  # Topolys edges may constitute thermal bridges (and therefore thermally
  # derate linked OpenStudio surfaces), depending on a number of factors such
  # as surface types and boundary conditions. Thermal bridging attributes
  # (type & PSI-value pairs) are grouped into PSI sets (method argument).

  # Process user-defined TBD JSON file inputs if file exists & valid:
  #   "io" holds valid TBD JSON hash from file
  #   "io_p" holds TBD PSI sets (built-in defaults & those on file)
  #   "io_k" holds TBD KHI points (built-in defaults & those on file)
  io, io_p, io_k = processTBDinputs(surfaces, edges, psi_set, io_path, schema_path)

  edges.values.each do |edge|
    next unless edge.has_key?(:surfaces)
    next unless edge[:surfaces].size > 1 #       may need to revisit e.g. :party

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

    psi = {}                                           # edge-specific PSI types
    p = io[:unit].first[:psi]                                 # default unit PSI

    match = false
    if edge.has_key?(:io_type)                # customized edge in TBD JSON file
      match = true
      t = edge[:io_type]
      p = edge[:io_set]       if edge.has_key?(:io_set)
      edge[:set] = p          if io_p.set.has_key?(p)
      psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
    end

    edge[:surfaces].keys.each do |id|
      next if match                                         # skip if customized
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
          next unless surfaces[i][:boundary].downcase == "outdoors"
          next unless surfaces[id].has_key?(:ground)
          next unless surfaces[id][:ground]
          psi[:grade] = io_p.set[p][:grade]
        end
      end

      # Label edge as :balcony if linked to:
      #   1x floor
      #   1x shade
      unless psi.has_key?(:balcony)
        edge[:surfaces].keys.each do |i|
          next unless shades.has_key?(i)
          next unless floors.has_key?(id)
          psi[:balcony] = io_p.set[p][:balcony]
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
          psi[:parapet] = io_p.set[p][:parapet]
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
          psi[:parapet] = io_p.set[p][:parapet]
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
          psi[:parapet] = io_p.set[p][:parapet]
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
          psi[:rimjoist] = io_p.set[p][:rimjoist]
        end
      end

      # Label edge as :fenestration if linked to:
      #   1x subsurface
      unless psi.has_key?(:fenestration)
        edge[:surfaces].keys.each do |i|
          next unless holes.has_key?(i)
          psi[:fenestration] = io_p.set[p][:fenestration]
        end
      end

      # Label edge as :concave or :convex (corner) if linked to:
      #   2x outside-facing walls (& relative polar positions of walls)
      unless psi.has_key?(:concave) || psi.has_key?(:convex)
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
          psi[:concave] = io_p.set[p][:concave] if n1_d_p2 > 0 && p1_d_n2 > 0
          psi[:convex]  = io_p.set[p][:convex]  if n1_d_p2 < 0 && p1_d_n2 < 0
        end
      end
    end                                                   # edge's surfaces loop

    edge[:psi] = psi unless psi.empty?
    edge[:set] = p unless psi.empty?
  end                                                                # edge loop

  # Generate OSM Kiva settings and objects if foundation-facing floors.
  # 'kiva' == false if partial failure (log failure eventually).
  # kiva = generateKiva(os_model, walls, floors, edges) if gen_kiva

  # In the preceding loop, TBD initially sets individual edge PSI types/values
  # to those of the project-wide :unit set. If the TBD JSON file holds custom
  # :story, :space or :surface PSI sets that are applicable to individual edges,
  # then those override the default :unit ones.

  # For now, the link between TBD :stories and OSM BuildingStories isn't yet
  # completed/tested, so ignored for now ...
  # openstudio-sdk-documentation.s3.amazonaws.com/cpp/OpenStudio-2.9.0-doc/model/html/classopenstudio_1_1model_1_1_building_story.html
  if io
    # if io.has_key?(:stories)                    # ... will override :unit sets
    # end

    if io.has_key?(:spaces)                    # ... will override :stories sets
      io[:spaces].each do |space|
        next unless space.has_key?(:id)
        next unless space.has_key?(:psi)
        i = space[:id]
        p = space[:psi]
        next unless io_p.set.has_key?(p)

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)   # open to transition edges TO DO ...
          next if edge.has_key?(:io_set)    # customized edge WITH custom PSI
          next unless edge.has_key?(:surfaces)

          # TBD/Topolys edges will generally be linked to more than one surface
          # and hence to more than one space. It is possible for a TBD JSON file
          # to hold 2x space PSI sets that affect one or more edges common to
          # both spaces. As with Ruby and JSON hashes, the last processed TBD
          # JSON space PSI set will supersede preceding ones. Caution ...
          # Future revisons to TBD JSON I/O validation, e.g. log warning?
          edge[:surfaces].keys.each do |id|
            next unless surfaces.has_key?(id)
            next unless surfaces[id].has_key?(:space)
            sp = surfaces[id][:space]
            next unless i == sp.nameString

            if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
              t = edge[:io_type]
              next unless io_p.set[p].has_key?(t)
              psi = {}
              psi[t] = io_p.set[p][t]
              edge[:psi] = psi
            else
              edge[:psi].keys.each do |t|
                edge[:psi][t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
              end
            end
            edge[:set] = p
          end
        end
      end
    end

    if io.has_key?(:surfaces)                   # ... will override :spaces sets
      io[:surfaces].each do |surface|
        next unless surface.has_key?(:id)
        next unless surface.has_key?(:psi)
        i = surface[:id]
        p = surface[:psi]
        next unless io_p.set.has_key?(p)

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)   # open to transition edges TO DO ...
          next if edge.has_key?(:io_set)    # customized edge WITH custom PSI
          next unless edge.has_key?(:surfaces)

          # TBD/Topolys edges will generally be linked to more than one
          # surface. It is possible for a TBD JSON file to hold 2x surface PSI
          # sets that affect one or more edges common to both surfaces. As
          # with Ruby and JSON hashes, the last processed TBD JSON surface PSI
          # set will supersede preceding ones. Caution ...
          # Future revisons to TBD JSON I/O validation, e.g. log warning?
          edge[:surfaces].keys.each do |s|
            next unless surfaces.has_key?(s)
            next unless i == s
            if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
              t = edge[:io_type]
              next unless io_p.set[p].has_key?(t)
              psi = {}
              psi[t] = io_p.set[p][t]
              edge[:psi] = psi
            else
              edge[:psi] = {} unless edge.has_key?(:psi)
              edge[:psi].keys.each do |t|
                edge[:psi][t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
              end
            end
            edge[:set] = p
          end
        end
      end
    end

    # Loop through all customized edges on file WITH a custom PSI set
    edges.values.each do |edge|
      next unless edge.has_key?(:psi)      # open to transition edges TO DO ...
      next unless edge.has_key?(:io_set)
      next unless edge.has_key?(:io_type)
      next unless edge.has_key?(:surfaces)

      t = edge[:io_type]
      p = edge[:io_set]
      next unless io_p.set.has_key?(p)
      next unless io_p.set[p].has_key?(t)
      psi = {}
      psi[t] = io_p.set[p][t]
      edge[:psi] = psi
      edge[:set] = p
    end
  end

  # Loop through each edge and assign heat loss to linked surfaces.
  edges.each do |identifier, edge|
    next unless edge.has_key?(:psi)

    psi = edge[:psi].values.max

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
  surfaces.each do |id, surface|
    next unless surface.has_key?(:edges)
    surface[:heatloss] = 0
    surface[:edges].values.each do |edge|
      surface[:heatloss] += edge[:psi] * edge[:length]
    end
  end

  # Add point conductances (W/K x count), held in TBD JSON file (under surfaces)
  surfaces.each do |id, surface|
    next unless surface[:boundary].downcase == "outdoors"
    next unless io
    next unless io.has_key?(:surfaces)
    io[:surfaces].each do |s|
      next unless s.has_key?(:id)
      next unless s.has_key?(:khis)
      next unless id == s[:id]
      s[:khis].each do |k|
        next unless k.has_key?(:id)
        next unless k.has_key?(:count)
        next unless io_k.point.has_key?(k[:id])
        next unless io_k.point[k[:id]] > 0.000
        surface[:heatloss] = 0 unless surface.has_key?(:heatloss)
        surface[:heatloss] += io_k.point[k[:id]] * k[:count]
      end
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
    next unless surface.has_key?(:heatloss)
    next unless surface[:heatloss] > 0.01
    os_model.getSurfaces.each do |s|
      next unless id == s.nameString
      current_c = s.construction.get
      next if current_c.nil?
      construction_name = current_c.nameString
      c = current_c.clone(os_model).to_Construction.get

      # index - of layer/material (to derate) in cloned construction
      # type  - either massless (RSi) or standard (k + d)
      # r     - initial RSi value of the targeted layer to derate
      index, type, r = deratableLayer(c)

      index = nil unless index.is_a?(Numeric) &&
                         index >=0            &&
                         index < c.layers.size

      # m ... newly derated, cloned material
      m = nil
      m = derate(os_model, id, surface, c, index, type, r) unless index.nil?

      # m may be nilled simply because the targeted construction has already
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

        # In principle, the derated "ratio" could be calculated simply by
        # accessing a surface's uFactor. However, it appears that air layers
        # within constructions (not air films) are ignored in OpenStudio's
        # uFactor calculation. An example would be 25mm-50mm air gaps behind
        # brick veneer.
        #
        # If one comments-out the following loop (3 lines), tested surfaces
        # with air layers will generate discrepencies between the calculed RSi
        # value above and the inverse of the uFactor. All other surface
        # constructions pass the test.
        #
        # if ((1/current_R) - s.uFactor.to_f).abs > 0.005
        #   puts "#{s.nameString} - Usi:#{1/current_R} UFactor: #{s.uFactor}"
        # end

        s.setConstruction(c)

        # Compute updated RSi value from layers.
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

  io[:edges] = []

  # Enrich io with TBD/Topolys edge info before returning:
  # 1. edge custom PSI set, if on file
  # 2. edge PSI type
  # 3. edge length (m)
  # 4. edge origin & end vertices
  # 5. array of linked outside- or ground-facing surfaces
  edges.values.each do |e|
    next unless e.has_key?(:psi)
    next unless e.has_key?(:set)
    v = e[:psi].values.max
    p = e[:set]
    next unless v > 0.000
    t = e[:psi].key(v)
    l = e[:length]
    edge = { psi: p, type: t, length: l, surfaces: e[:surfaces].keys }
    edge[:v0x] = e[:v0].point.x
    edge[:v0y] = e[:v0].point.y
    edge[:v0z] = e[:v0].point.z
    edge[:v1x] = e[:v1].point.x
    edge[:v1y] = e[:v1].point.y
    edge[:v1z] = e[:v1].point.z
    io[:edges] << edge
  end
  io.delete(:edges) unless io[:edges].size > 0

  return io, surfaces
end
