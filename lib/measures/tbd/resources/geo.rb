# MIT License
#
# Copyright (c) 2020-2023 Denis Bourgeois & Dan Macumber
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

module TBD
  ##
  # Checks whether 2 edges share Topolys vertex pairs.
  #
  # @param [Hash] e1 first edge
  # @param [Hash] e2 second edge
  # @option e1 [Topolys::Point3D] :v0 origin vertex
  # @option e1 [Topolys::Point3D] :v1 terminal vertex
  # @param tol [Numeric] tolerance (OSut::TOL) in m
  #
  # @return [Bool] whether edges share vertex pairs
  # @return [false] if invalid input (see logs)
  def matches?(e1 = {}, e2 = {}, tol = TOL)
    mth = "TBD::#{__callee__}"
    cl  = Topolys::Point3D
    a   = false
    return mismatch("e1", e1, Hash, mth, DBG, a)       unless e1.is_a?(Hash)
    return mismatch("e2", e2, Hash, mth, DBG, a)       unless e2.is_a?(Hash)
    return mismatch("e2", e2, Hash, mth, DBG, a)       unless e2.is_a?(Hash)

    return hashkey("e1", e1, :v0, mth, DBG, a)         unless e1.key?(:v0)
    return hashkey("e1", e1, :v1, mth, DBG, a)         unless e1.key?(:v1)
    return hashkey("e2", e2, :v0, mth, DBG, a)         unless e2.key?(:v0)
    return hashkey("e2", e2, :v1, mth, DBG, a)         unless e2.key?(:v1)

    return mismatch("e1:v0", e1[:v0], cl, mth, DBG, a) unless e1[:v0].is_a?(cl)
    return mismatch("e1:v1", e1[:v1], cl, mth, DBG, a) unless e1[:v1].is_a?(cl)
    return mismatch("e2:v0", e2[:v0], cl, mth, DBG, a) unless e2[:v0].is_a?(cl)
    return mismatch("e2:v1", e2[:v1], cl, mth, DBG, a) unless e2[:v1].is_a?(cl)

    e1_vector = e1[:v1] - e1[:v0]
    e2_vector = e2[:v1] - e2[:v0]

    return zero("e1", mth, DBG, a) if e1_vector.magnitude < TOL
    return zero("e2", mth, DBG, a) if e2_vector.magnitude < TOL

    return mismatch("e1", e1, Hash, mth, DBG, a) unless tol.is_a?(Numeric)
    return zero("tol", mth, DBG, a)                  if tol < TOL

    return true if
    (
      (
        ( (e1[:v0].x - e2[:v0].x).abs < tol &&
          (e1[:v0].y - e2[:v0].y).abs < tol &&
          (e1[:v0].z - e2[:v0].z).abs < tol
        ) ||
        ( (e1[:v0].x - e2[:v1].x).abs < tol &&
          (e1[:v0].y - e2[:v1].y).abs < tol &&
          (e1[:v0].z - e2[:v1].z).abs < tol
        )
      ) &&
      (
        ( (e1[:v1].x - e2[:v0].x).abs < tol &&
          (e1[:v1].y - e2[:v0].y).abs < tol &&
          (e1[:v1].z - e2[:v0].z).abs < tol
        ) ||
        ( (e1[:v1].x - e2[:v1].x).abs < tol &&
          (e1[:v1].y - e2[:v1].y).abs < tol &&
          (e1[:v1].z - e2[:v1].z).abs < tol
        )
      )
    )

    false
  end

  ##
  # Returns Topolys vertices and a Topolys wire from Topolys points. If
  # missing, it populates the Topolys model with the vertices and wire.
  #
  # @param model [Topolys::Model] a model
  # @param pts [Array<Topolys::Point3D>] 3D points
  #
  # @return [Hash] vx: (Array<Topolys::Vertex>); w: (Topolys::Wire)
  # @return [Hash] vx: nil, w: nil if invalid input (see logs)
  def objects(model = nil, pts = [])
    mth = "TBD::#{__callee__}"
    cl1 = Topolys::Model
    cl2 = Array
    cl3 = Topolys::Point3D
    obj = { vx: nil, w: nil }
    return mismatch("model", model, cl1, mth, DBG, obj) unless model.is_a?(cl1)
    return mismatch("points",  pts, cl2, mth, DBG, obj) unless pts.is_a?(cl2)

    pts.each do |pt|
      return mismatch("point", pt, cl3, mth, DBG, obj) unless pt.is_a?(cl3)
    end

    obj[:vx] = model.get_vertices(pts)
    obj[:w ] = model.get_wire(obj[:vx])

    obj
  end

  ##
  # Adds a collection of TBD sub surfaces ('kids') to a Topolys model,
  # including vertices, wires & holes. A sub surface is typically 'hinged',
  # i.e. along the same 3D plane as its base surface (or 'dad'). In rare cases
  # such as domes of tubular daylighting devices (TDDs), a sub surface may be
  # 'unhinged'.
  #
  # @param model [Topolys::Model] a model
  # @param [Hash] boys a collection of TBD subsurfaces
  # @option boys [Array<Topolys::Point3D>] :points sub surface 3D points
  # @option boys [Bool] :unhinged whether same 3D plane as base surface
  # @option boys [OpenStudio::Vector3d] :n outward normal
  #
  # @return [Array<Topolys::Wire>] holes cut out by kids (see logs if empty)
  def kids(model = nil, boys = {})
    mth   = "TBD::#{__callee__}"
    cl1   = Topolys::Model
    cl2   = Hash
    holes = []
    return mismatch("model", model, cl1, mth, DBG, {}) unless model.is_a?(cl1)
    return mismatch("boys",   boys, cl2, mth, DBG, {}) unless boys.is_a?(cl2)

    boys.each do |id, props|
      obj = objects(model, props[:points])
      next unless obj[:w]

      obj[:w].attributes[:id      ] = id
      obj[:w].attributes[:unhinged] = props[:unhinged] if props.key?(:unhinged)
      obj[:w].attributes[:n       ] = props[:n       ] if props.key?(:n)

      props[:hole] = obj[:w]
      holes << obj[:w]
    end

    holes
  end

  ##
  # Adds a collection of bases surfaces ('dads') to a Topolys model, including
  # vertices, wires, holes & faces. Also populates the model with sub surfaces
  # ('kids').
  #
  # @param model [Topolys::Model] a model
  # @param [Hash] pops base surfaces
  # @option pops [OpenStudio::Point3dVector] :points base surface 3D points
  # @option pops [Hash] :windows incorporated windows (see kids)
  # @option pops [Hash] :doors incorporated doors (see kids)
  # @option pops [Hash] :skylights incorporated skylights (see kids)
  # @option pops [OpenStudio::Vector3D] :n outward normal
  #
  # @return [Hash] 3D Topolys wires of 'holes' (made by kids)
  def dads(model = nil, pops = {})
    mth   = "TBD::#{__callee__}"
    cl1   = Topolys::Model
    cl2   = Hash
    holes = {}
    return mismatch("model", model, cl2, mth, DBG, {}) unless model.is_a?(cl1)
    return mismatch("pops",   pops, cl2, mth, DBG, {}) unless pops.is_a?(cl2)

    pops.each do |id, props|
      hols   = []
      hinged = []
      obj    = objects(model, props[:points])
      next unless obj[:vx] && obj[:w]

      hols += kids(model, props[:windows  ]) if props.key?(:windows)
      hols += kids(model, props[:doors    ]) if props.key?(:doors)
      hols += kids(model, props[:skylights]) if props.key?(:skylights)

      hols.each { |hol| hinged << hol unless hol.attributes[:unhinged] }

      face = model.get_face(obj[:w], hinged)
      msg  = "Unable to retrieve valid 'dad' (#{mth})"
      log(DBG, msg) unless face
      next          unless face

      face.attributes[:id] = id
      face.attributes[:n ] = props[:n] if props.key?(:n)

      props[:face] = face

      hols.each { |hol| holes[hol.attributes[:id]] = hol }
    end

    holes
  end

  ##
  # Populates TBD edges with linked Topolys faces.
  #
  # @param [Hash] s TBD surfaces
  # @option s [Topolys::Face] :face a Topolys face
  # @param [Hash] e TBD edges
  # @option e [Numeric] :length edge length
  # @option e [Topolys::Vertex] :v0 edge origin vertex
  # @option e [Topolys::Vertex] :v1 edge terminal vertex
  #
  # @return [Bool] whether successful in populating faces
  # @return [false] if invalid input (see logs)
  def faces(s = {}, e = {})
    mth = "TBD::#{__callee__}"
    return mismatch("surfaces", s, Hash, mth, DBG, false) unless s.is_a?(Hash)
    return mismatch("edges",    e, Hash, mth, DBG, false) unless e.is_a?(Hash)

    s.each do |id, props|
      unless props.key?(:face)
        log(DBG, "Missing Topolys face '#{id}' (#{mth})")
        next
      end

      props[:face].wires.each do |wire|
        wire.edges.each do |edge|
          unless e.key?(edge.id)
            e[edge.id] = { length: edge.length,
                               v0: edge.v0,
                               v1: edge.v1,
                         surfaces: {} }
          end

          unless e[edge.id][:surfaces].key?(id)
            e[edge.id][:surfaces][id] = { wire: wire.id }
          end
        end
      end
    end

    true
  end

  ##
  # Returns site (or true) Topolys normal vector of OpenStudio surface.
  #
  # @param s [OpenStudio::Model::PlanarSurface] a planar surface
  # @param r [#to_f] a group/site rotation angle [0,2PI) radians
  #
  # @return [Topolys::Vector3D] true normal vector of s
  # @return [nil] if invalid input (see logs)
  def trueNormal(s = nil, r = 0)
    mth = "TBD::#{__callee__}"
    cl  = OpenStudio::Model::PlanarSurface
    return mismatch("surface", s, cl, mth)   unless s.is_a?(cl)
    return invalid("rotation angle", mth, 2) unless r.respond_to?(:to_f)

    r = -r.to_f * Math::PI / 180.0
    vx = s.outwardNormal.x * Math.cos(r) - s.outwardNormal.y * Math.sin(r)
    vy = s.outwardNormal.x * Math.sin(r) + s.outwardNormal.y * Math.cos(r)
    vz = s.outwardNormal.z
    Topolys::Vector3D.new(vx, vy, vz)
  end

  ##
  # Fetches OpenStudio surface properties, including opening areas & vertices.
  #
  # @param surface [OpenStudio::Model::Surface] a surface
  # @param [Hash] argh TBD arguments
  # @option argh [Bool] :setpoints whether model holds thermal zone setpoints
  #
  # @return [Hash] TBD surface with key attributes (see )
  # @return [nil] if invalid input (see logs)
  def properties(surface = nil, argh = {})
    mth = "TBD::#{__callee__}"
    cl1 = OpenStudio::Model::Surface
    cl2 = OpenStudio::Model::LayeredConstruction
    cl3 = Hash
    return mismatch("surface", surface, cl1, mth) unless surface.is_a?(cl1)
    return mismatch("argh"   , argh   , cl3, mth) unless argh.is_a?(cl3)

    nom    = surface.nameString
    surf   = {}
    subs   = {}
    fd     = false
    return invalid("#{nom}",     mth, 1, FTL) if poly(surface).empty?
    return empty("#{nom} space", mth,    ERR) if surface.space.empty?

    space  = surface.space.get
    stype  = space.spaceType
    story  = space.buildingStory
    tr     = transforms(space)
    return   invalid("#{nom} transform", mth, 0, FTL) unless tr[:t] && tr[:r]

    t      = tr[:t]
    n      = trueNormal(surface, tr[:r])
    return   invalid("#{nom} normal", mth, 0, FTL) unless n

    type   = surface.surfaceType.downcase
    facing = surface.outsideBoundaryCondition
    setpts = setpoints(space)

    if facing.downcase == "surface"
      empty = surface.adjacentSurface.empty?
      return invalid("#{nom}: adjacent surface", mth, 0, ERR) if empty

      facing = surface.adjacentSurface.get.nameString
    end

    unless surface.construction.empty?
      construction = surface.construction.get.to_LayeredConstruction

      unless construction.empty?
        construction = construction.get
        lyr          = insulatingLayer(construction)
        lyr[:index]  = nil unless lyr[:index].is_a?(Numeric)
        lyr[:index]  = nil unless lyr[:index] >= 0
        lyr[:index]  = nil unless lyr[:index] < construction.layers.size

        if lyr[:index]
          surf[:construction] = construction
          # index: ... of layer/material (to derate) within construction
          # ltype: either :massless (RSi) or :standard (k + d)
          # r    : initial RSi value of the indexed layer to derate
          surf[:index] = lyr[:index]
          surf[:ltype] = lyr[:type ]
          surf[:r    ] = lyr[:r    ]
        end
      end
    end

    unless argh.key?(:setpoints)
      heat = heatingTemperatureSetpoints?(model)
      cool = coolingTemperatureSetpoints?(model)
      argh[:setpoints] = heat || cool
    end

    if argh[:setpoints]
      surf[:heating] = setpts[:heating] unless setpts[:heating].nil?
      surf[:cooling] = setpts[:cooling] unless setpts[:cooling].nil?
    else
      surf[:heating] = 21.0
      surf[:cooling] = 24.0
    end

    surf[:conditioned] = surf.key?(:heating) || surf.key?(:cooling)
    surf[:space      ] = space
    surf[:boundary   ] = facing
    surf[:ground     ] = surface.isGroundSurface
    surf[:type       ] = :floor
    surf[:type       ] = :ceiling      if type.include?("ceiling")
    surf[:type       ] = :wall         if type.include?("wall"   )
    surf[:stype      ] = stype.get unless stype.empty?
    surf[:story      ] = story.get unless story.empty?
    surf[:n          ] = n
    surf[:gross      ] = surface.grossArea
    surf[:filmRSI    ] = surface.filmResistance
    surf[:spandrel   ] = spandrel?(surface)

    surface.subSurfaces.sort_by { |s| s.nameString }.each do |s|
      next if poly(s).empty?

      id  = s.nameString
      typ = surface.surfaceType.downcase

      unless (3..4).cover?(s.vertices.size)
        log(ERR, "Skipping '#{id}': vertex # 3 or 4 (#{mth})")
        next
      end

      vec  = s.vertices
      area = s.grossArea
      mult = s.multiplier

      # An OpenStudio subsurface has a "type" (string), either defaulted during
      # initialization or explicitely set by the user (from a built-in list):
      #
      #   OpenStudio::Model::SubSurface.validSubSurfaceTypeValues
      #   - "FixedWindow"
      #   - "OperableWindow"
      #   - "Door"
      #   - "GlassDoor"
      #   - "OverheadDoor"
      #   - "Skylight"
      #   - "TubularDaylightDome"
      #   - "TubularDaylightDiffuser"
      typ = s.subSurfaceType.downcase

      # An OpenStudio default subsurface construction set can hold unique
      # constructions assigned for each of these admissible types. In addition,
      # type assignment determines whether frame/divider attributes can be
      # linked to a subsurface (this shortlist has evolved between OpenStudio
      # releases). Type assignment is relied upon when calculating (admissible)
      # fenestration areas. TBD also relies on OpenStudio subsurface type
      # assignment, with resulting TBD tags being a bit more concise, e.g.:
      #
      #   - :window includes "FixedWindow" and "OperableWindow"
      #   - :door includes "Door", "OverheadWindow" and "GlassDoor"
      #     ... a (roof) access roof hatch should be assigned as a "Door"
      #   - :skylight includes "Skylight", "TubularDaylightDome", etc.
      #
      type = :skylight
      type = :window if typ.include?("window") # operable or not
      type = :door   if typ.include?("door")   # fenestrated or not

      # In fact, ANY subsurface other than :window or :door is tagged as
      # :skylight, e.g. a glazed floor opening (CN, Calgary, Tokyo towers). This
      # happens to reflect OpenStudio default initialization behaviour. For
      # instance, a subsurface added to an exposed (horizontal) floor in
      # OpenStudio is automatically assigned a "Skylight" type. This is similar
      # to the auto-assignment of (opaque) walls, roof/ceilings and floors
      # (based on surface tilt) in OpenStudio.
      #
      # When it comes to major thermal bridging, ASHRAE 90.1 (2022) makes a
      # clear distinction between "vertical fenestration" (a defined term) and
      # all other subsurfaces. "Vertical fenestration" would include both
      # instances of "Window", as well as "GlassDoor". It would exclude however
      # a non-fenestrated "door" (another defined term), like "Door" &
      # "OverheadDoor", as well as skylights. TBD tracks relevant subsurface
      # attributes via a handful of boolean variables:
      glazed   = type == :door && typ.include?("glass")   # fenestrated door
      tubular  =                  typ.include?("tubular") # dome or diffuser
      domed    =                  typ.include?("dome")    # (tubular) dome
      unhinged = false                                    # (tubular) dome

      # It would be tempting (and simple) to have TBD further validate whether a
      # "GlassDoor" is actually integrated within a (vertical) wall. The
      # automated type assignment in OpenStudio is very simple and reliable (as
      # discussed in the preceding paragraphs), yet users can nonetheless reset
      # this explicitly. For instance, while a vertical surface may indeed be
      # auto-assigned "Wall", a modeller can just as easily reset its type as
      # "Floor". Although OpenStudio supports 90.1 rules by default, it's not
      # enforced. TBD retains the same approach: for whatever osbcur reason a
      # modeller may decide (and hopefully the "authority having jurisdiction"
      # may authorize) to reset a wall as a "Floor" or a roof skylight as a
      # "GlassDoor", TBD maintains the same OpenStudio policy. Either OpenStudio
      # (and consequently EnergyPlus) sub/surface type assignment is reliable,
      # or it is not.

      # Determine if TDD dome subsurface is 'unhinged', i.e. unconnected to its
      # base surface (not same 3D plane).
      if domed
        unhinged = true unless s.plane.equal(surface.plane)
        n = s.outwardNormal if unhinged
      end

      if area < TOL
        log(ERR, "Skipping '#{id}': gross area ~zero (#{mth})")
        next
      end

      c = s.construction

      if c.empty?
        log(ERR, "Skipping '#{id}': missing construction (#{mth})")
        next
      end

      c = c.get.to_LayeredConstruction

      if c.empty?
        log(WRN, "Skipping '#{id}': subs limited to #{cl2} (#{mth})")
        next
      end

      c = c.get

      # A subsurface may have an overall U-factor set by the user - a less
      # accurate option, yet easier to process (and often the only option
      # available). With EnergyPlus' "simple window" model, a subsurface's
      # construction has a single SimpleGlazing material/layer holding the
      # whole product U-factor.
      #
      #   https://bigladdersoftware.com/epx/docs/9-6/engineering-reference/
      #   window-calculation-module.html#simple-window-model
      #
      # TBD will instead rely on Tubular Daylighting Device (TDD) effective
      # dome-to-diffuser RSi-factors (if valid).
      #
      #   https://bigladdersoftware.com/epx/docs/9-6/engineering-reference/
      #   daylighting-devices.html#tubular-daylighting-devices
      #
      # In other cases, TBD will recover an 'additional property' tagged
      # "uFactor", assigned either to the individual subsurface itself, or else
      # assigned to its referenced construction (a more generic fallback).
      #
      # If all else fails, TBD will calculate an approximate whole product
      # U-factor by adding up the subsurface's layered construction material
      # thermal resistances (as well as the subsurface's parent surface film
      # resistances). This is the least reliable option, especially if
      # subsurfaces have Frame & Divider objects, or irregular geometry.
      u = s.uFactor
      u = u.get unless u.empty?

      if tubular & s.respond_to?(:daylightingDeviceTubular) # OSM > v3.3.0
        unless s.daylightingDeviceTubular.empty?
          r = s.daylightingDeviceTubular.get.effectiveThermalResistance
          u = 1 / r if r > TOL
        end
      end

      unless u.is_a?(Numeric)
        u = s.additionalProperties.getFeatureAsDouble("uFactor")
      end

      unless u.is_a?(Numeric)
        r = rsi(c, surface.filmResistance)

        if r < TOL
          log(ERR, "Skipping '#{id}': U-factor unavailable (#{mth})")
          next
        end

        u = 1 / r
      end

      frame = s.allowWindowPropertyFrameAndDivider
      frame = false if s.windowPropertyFrameAndDivider.empty?

      if frame
        fd    = true
        width = s.windowPropertyFrameAndDivider.get.frameWidth
        vec   = offset(vec, width, 300)
        area  = OpenStudio.getArea(vec)

        if area.empty?
          log(ERR, "Skipping '#{id}': invalid offset (#{mth})")
          next
        end

        area = area.get
      end

      sub = { v:        s.vertices,
              points:   vec,
              n:        n,
              gross:    s.grossArea,
              area:     area,
              mult:     mult,
              type:     type,
              u:        u,
              unhinged: unhinged }

      sub[:glazed] = true if glazed
      subs[id    ] = sub
    end

    valid = true
    # Test for conflicts (with fits?, overlaps?) between sub/surfaces to
    # determine whether to keep original points or switch to std::vector of
    # revised coordinates, offset by Frame & Divider frame width. This will
    # also inadvertently catch pre-existing (yet nonetheless invalid)
    # OpenStudio inputs (without Frame & Dividers).
    subs.each do |id, sub|
      break unless fd
      break unless valid

      valid = fits?(sub[:points], surface.vertices)
      log(ERR, "Skipping '#{id}': can't fit in '#{nom}' (#{mth})") unless valid

      subs.each do |i, sb|
        break unless valid
        next      if i == id

        if overlaps?(sb[:points], sub[:points])
          log(ERR, "Skipping '#{id}': overlaps sibling '#{i}' (#{mth})")
          valid = false
        end
      end
    end

    if fd
      subs.values.each { |sub| sub[:gross ] = sub[:area ] }     if valid
      subs.values.each { |sub| sub[:points] = sub[:v    ] } unless valid
      subs.values.each { |sub| sub[:area  ] = sub[:gross] } unless valid
    end

    subarea = 0

    subs.values.each { |sub| subarea += sub[:area] * sub[:mult] }

    surf[:net] = surf[:gross] - subarea

    # Tranform final Point 3D sets, and store.
    pts = (t * surface.vertices).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }

    surf[:points] = pts
    surf[:minz  ] = ( pts.map { |pt| pt.z } ).min

    subs.each do |id, sub|
      pts = (t * sub[:points]).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }

      sub[:points] = pts
      sub[:minz  ] = ( pts.map { |p| p.z } ).min

      [:windows, :doors, :skylights].each do |types|
        type = types.slice(0..-2).to_sym
        next unless sub[:type] == type

        surf[types]     = {} unless surf.key?(types)
        surf[types][id] = sub
      end
    end

    surf
  end

  ##
  # Validates whether edge surfaces form a concave angle, as seen from outside.
  #
  # @param [Hash] s1 first TBD surface
  # @param [Hash] s2 second TBD surface
  # @option s1 [Topolys::Vector3D] :normal surface normal vector
  # @option s1 [Topolys::Vector3D] :polar vector around edge
  # @option s1 [Numeric] :angle polar angle vs reference (e.g. North, Zenith)
  #
  # @return [Bool] true if angle between surfaces is concave
  # @return [false] if invalid input (see logs)
  def concave?(s1 = nil, s2 = nil)
    mth = "TBD::#{__callee__}"
    return mismatch("s1", s1, Hash, mth, DBG, false) unless s1.is_a?(Hash)
    return mismatch("s2", s2, Hash, mth, DBG, false) unless s2.is_a?(Hash)
    return false if s1 == s2

    return hashkey("s1", s1,  :angle, mth, DBG, false) unless s1.key?(:angle)
    return hashkey("s2", s2,  :angle, mth, DBG, false) unless s2.key?(:angle)
    return hashkey("s1", s1, :normal, mth, DBG, false) unless s1.key?(:normal)
    return hashkey("s2", s2, :normal, mth, DBG, false) unless s2.key?(:normal)
    return hashkey("s1", s1,  :polar, mth, DBG, false) unless s1.key?(:polar)
    return hashkey("s2", s2,  :polar, mth, DBG, false) unless s2.key?(:polar)

    valid1 = s1[:angle].is_a?(Numeric)
    valid2 = s2[:angle].is_a?(Numeric)
    return mismatch("s1 angle", s1[:angle], Numeric, DBG, false) unless valid1
    return mismatch("s1 angle", s1[:angle], Numeric, DBG, false) unless valid2

    angle = 0
    angle = s2[:angle] - s1[:angle] if s2[:angle] > s1[:angle]
    angle = s1[:angle] - s2[:angle] if s1[:angle] > s2[:angle]
    return false if angle < TOL
    return false unless (2 * Math::PI - angle).abs > TOL
    return false if angle > 3 * Math::PI / 4 && angle < 5 * Math::PI / 4

    n1_d_p2 = s1[:normal].dot(s2[:polar])
    p1_d_n2 = s1[:polar].dot(s2[:normal])
    return true if n1_d_p2 > 0 && p1_d_n2 > 0

    false
  end

  ##
  # Validates whether edge surfaces form a convex angle, as seen from outside.
  #
  # @param [Hash] s1 first TBD surface
  # @param [Hash] s2 second TBD surface
  # @option s1 [Topolys::Vector3D] :normal surface normal vector
  # @option s1 [Topolys::Vector3D] :polar vector around edge
  # @option s1 [Numeric] :angle polar angle vs reference (e.g. North, Zenith)
  #
  # @return [Bool] true if angle between surfaces is convex
  # @return [false] if invalid input (see logs)
  def convex?(s1 = nil, s2 = nil)
    mth = "TBD::#{__callee__}"
    return mismatch("s1", s1, Hash, mth, DBG, false) unless s1.is_a?(Hash)
    return mismatch("s2", s2, Hash, mth, DBG, false) unless s2.is_a?(Hash)
    return false if s1 == s2

    return hashkey("s1", s1,  :angle, mth, DBG, false) unless s1.key?(:angle)
    return hashkey("s2", s2,  :angle, mth, DBG, false) unless s2.key?(:angle)
    return hashkey("s1", s1, :normal, mth, DBG, false) unless s1.key?(:normal)
    return hashkey("s2", s2, :normal, mth, DBG, false) unless s2.key?(:normal)
    return hashkey("s1", s1,  :polar, mth, DBG, false) unless s1.key?(:polar)
    return hashkey("s2", s2,  :polar, mth, DBG, false) unless s2.key?(:polar)

    valid1 = s1[:angle].is_a?(Numeric)
    valid2 = s2[:angle].is_a?(Numeric)
    return mismatch("s1 angle", s1[:angle], Numeric, DBG, false) unless valid1
    return mismatch("s1 angle", s1[:angle], Numeric, DBG, false) unless valid2

    angle = 0
    angle = s2[:angle] - s1[:angle] if s2[:angle] > s1[:angle]
    angle = s1[:angle] - s2[:angle] if s1[:angle] > s2[:angle]
    return false if angle < TOL
    return false unless (2 * Math::PI - angle).abs > TOL
    return false if angle > 3 * Math::PI / 4 && angle < 5 * Math::PI / 4

    n1_d_p2 = s1[:normal].dot(s2[:polar])
    p1_d_n2 = s1[:polar].dot(s2[:normal])
    return true if n1_d_p2 < 0 && p1_d_n2 < 0

    false
  end

  ##
  # Purge existing KIVA-related objects in an OpenStudio model. Resets ground-
  # facing surface outside boundary condition to "Ground" or "Foundation".
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param boundary ["Ground", "Foundation"] new outside boundary condition
  #
  # @return [Bool] true if model is free of KIVA-related objects
  # @return [false] if invalid input (see logs)
  def resetKIVA(model = nil, boundary = "Foundation")
    mth = "TBD::#{__callee__}"
    cl  = OpenStudio::Model::Model
    ck1 = model.is_a?(cl)
    ck2 = boundary.respond_to?(:to_s)
    kva = false
    b   = ["Ground", "Foundation"]
    return mismatch("model"   , model   , cl    , mth, DBG, kva) unless ck1
    return mismatch("boundary", boundary, String, mth, DBG, kva) unless ck2

    boundary.capitalize!
    return invalid("boundary", mth, 2, DBG, kva) unless b.include?(boundary)

    # Reset surface KIVA-related objects.
    model.getSurfaces.each do |surface|
      kva = true unless surface.adjacentFoundation.empty?
      kva = true unless surface.surfacePropertyExposedFoundationPerimeter.empty?
      surface.resetAdjacentFoundation
      surface.resetSurfacePropertyExposedFoundationPerimeter
      next unless surface.isGroundSurface
      next unless surface.outsideBoundaryCondition.capitalize == boundary

      lc = surface.construction.empty? ? nil : surface.construction.get
      surface.setOutsideBoundaryCondition(boundary)
      next if boundary == "Ground"
      next if lc.nil?

      surface.setConstruction(lc) if surface.construction.empty?
    end

    perimeters = model.getSurfacePropertyExposedFoundationPerimeters

    kva = true unless perimeters.empty?

    # Remove KIVA exposed perimeters.
    perimeters.each { |perimeter| perimeter.remove }

    # Remove KIVA custom blocks, & foundations.
    model.getFoundationKivas.each do |kiva|
      kiva.removeAllCustomBlocks
      kiva.remove
    end

    log(INF, "Purged KIVA objects from model (#{mth})") if kva

    true
  end

  ##
  # Generates Kiva settings and objects if model surfaces have 'foundation'
  # boundary conditions.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param floors [Hash] TBD floors
  # @param walls [Hash] TBD walls
  # @param edges [Hash] TBD edges (many linking floors & walls
  #
  # @return [Bool] true if Kiva foundations are successfully generated
  # @return [false] if invalid input (see logs)
  def kiva(model = nil, walls = {}, floors = {}, edges = {})
    mth = "TBD::#{__callee__}"
    cl1 = OpenStudio::Model::Model
    cl2 = Hash
    a   = false
    return mismatch("model" ,  model, cl1, mth, DBG, a) unless model.is_a?(cl1)
    return mismatch("walls" ,  walls, cl2, mth, DBG, a) unless walls.is_a?(cl2)
    return mismatch("floors", floors, cl2, mth, DBG, a) unless floors.is_a?(cl2)
    return mismatch("edges" ,  edges, cl2, mth, DBG, a) unless edges.is_a?(cl2)

    # Check for existing KIVA objects.
    kva = false
    kva = true unless model.getSurfacePropertyExposedFoundationPerimeters.empty?
    kva = true unless model.getFoundationKivas.empty?

    if kva
      log(ERR, "Exiting - KIVA objects in model (#{mth})")
      return a
    else
      kva = true
    end

    # Pre-validate foundation-facing constructions.
    model.getSurfaces.each do |s|
      id = s.nameString
      construction = s.construction
      next unless s.outsideBoundaryCondition.downcase == "foundation"

      if construction.empty?
        log(ERR, "Invalid construction for #{id} (#{mth})")
        kva = false
      else
        construction = construction.get.to_LayeredConstruction

        if construction.empty?
          log(ERR, "Invalid layered constructions for #{id} (#{mth})")
          kva = false
        else
          construction = construction.get

          unless standardOpaqueLayers?(construction)
            log(ERR, "Non-standard materials for #{id} (#{mth})")
            kva = false
          end
        end
      end
    end

    return a unless kva

    # Strictly relying on Kiva's total exposed perimeter approach.
    arg  = "TotalExposedPerimeter"
    kiva = true
    # The following is loosely adapted from:
    #
    #   github.com/NREL/OpenStudio-resources/blob/develop/model/
    #   simulationtests/foundation_kiva.rb ... thanks.
    #
    # Access to KIVA settings. This is usually not required (the default KIVA
    # settings are fine), but its explicit inclusion in the model does offer
    # users easy access to further tweak settings, e.g. soil properties if
    # required. Initial tests show slight differences in simulation results
    # w/w/o explcit inclusion of the KIVA settings template in the model.
    settings = model.getFoundationKivaSettings

    k = settings.soilConductivity
    settings.setSoilConductivity(k)

    # Tag foundation-facing floors, then walls.
    edges.each do |code1, edge|
      edge[:surfaces].keys.each do |id|
        next unless floors.key?(id)
        next unless floors[id][:boundary].downcase == "foundation"
        next     if floors[id].key?(:kiva)

        floors[id][:kiva   ] = :slab # initially slabs-on-grade
        floors[id][:exposed] = 0.0   # slab-on-grade or walkout perimeter

        # Loop around current edge.
        edge[:surfaces].keys.each do |i|
          next     if i == id
          next unless walls.key?(i)
          next unless walls[i][:boundary].downcase == "foundation"
          next     if walls[i].key?(:kiva)

          floors[id][:kiva] = :basement
          walls[i  ][:kiva] = id
        end

        # Loop around current edge.
        edge[:surfaces].keys.each do |i|
          next     if i == id
          next unless walls.key?(i)
          next unless walls[i][:boundary].downcase == "outdoors"

          floors[id][:exposed] += edge[:length]
        end

        # Loop around other floor edges.
        edges.each do |code2, e|
          next if code1 == code2 #  skip - same edge

          e[:surfaces].keys.each do |i|
            next unless i == id # good - same floor

            e[:surfaces].keys.each do |ii|
              next     if i == ii
              next unless walls.key?(ii)
              next unless walls[ii][:boundary].downcase == "foundation"
              next     if walls[ii].key?(:kiva)

              floors[id][:kiva] = :basement
              walls[ii ][:kiva] = id
            end

            e[:surfaces].keys.each do |ii|
              next    if i == ii
              next unless walls.key?(ii)
              next unless walls[ii][:boundary].downcase == "outdoors"

              floors[id][:exposed] += e[:length]
            end
          end
        end

        foundation = OpenStudio::Model::FoundationKiva.new(model)
        foundation.setName("KIVA Foundation Floor #{id}")
        floor = model.getSurfaceByName(id)
        kiva  = false if floor.empty?
        next          if floor.empty?

        floor          = floor.get
        construction   = floor.construction
        kiva = false  if construction.empty?
        next          if construction.empty?

        construction   = construction.get
        floor.setAdjacentFoundation(foundation)
        floor.setConstruction(construction)
        ep   = floors[id][:exposed]
        per  = floor.createSurfacePropertyExposedFoundationPerimeter(arg, ep)
        kiva = false  if per.empty?
        next          if per.empty?

        per            = per.get
        perimeter      = per.totalExposedPerimeter
        kiva = false  if perimeter.empty?
        next          if perimeter.empty?

        perimeter      = perimeter.get

        if ep < 0.001
          ok   = per.setTotalExposedPerimeter(0.000)
          ok   = per.setTotalExposedPerimeter(0.001) unless ok
          kiva = false                               unless ok
        elsif (perimeter - ep).abs < TOL
          xps25 = model.getStandardOpaqueMaterialByName("XPS 25mm")

          if xps25.empty?
            xps25 = OpenStudio::Model::StandardOpaqueMaterial.new(model)
            xps25.setName("XPS 25mm")
            xps25.setRoughness("Rough")
            xps25.setThickness(0.0254)
            xps25.setConductivity(0.029)
            xps25.setDensity(28)
            xps25.setSpecificHeat(1450)
            xps25.setThermalAbsorptance(0.9)
            xps25.setSolarAbsorptance(0.7)
          else
            xps25 = xps25.get
          end

          foundation.setInteriorHorizontalInsulationMaterial(xps25)
          foundation.setInteriorHorizontalInsulationWidth(0.6)
        end

        floors[id][:foundation] = foundation
      end
    end

    walls.each do |i, wall|
      next unless wall.key?(:kiva)

      id = walls[i][:kiva]
      next unless floors.key?(id)
      next unless floors[id].key?(:foundation)

      mur = model.getSurfaceByName(i) # locate OpenStudio wall
      kiva = false if mur.empty?
      next         if mur.empty?

      mur           = mur.get
      construction  = mur.construction
      kiva = false if construction.empty?
      next         if construction.empty?

      construction  = construction.get
      mur.setAdjacentFoundation(floors[id][:foundation])
      mur.setConstruction(construction)
    end

    kiva
  end
end
