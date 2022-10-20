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

module TBD
  ##
  # Check for matching Topolys vertex pairs between edges (within TOL).
  #
  # @param e1 [Hash] first edge
  # @param e2 [Hash] second edge
  #
  # @return [Bool] true if edges share vertex pairs
  # @return [Bool] false if invalid input
  def matches?(e1 = {}, e2 = {})
    mth = "TBD::#{__callee__}"
    cl  = Topolys::Point3D
    a   = false

    return mismatch("e1", e1, Hash, mth, DBG, a)        unless e1.is_a?(Hash)
    return mismatch("e2", e2, Hash, mth, DBG, a)        unless e2.is_a?(Hash)
    return hashkey("e1", e1, :v0, mth, DBG, a)          unless e1.key?(:v0)
    return hashkey("e1", e1, :v1, mth, DBG, a)          unless e1.key?(:v1)
    return hashkey("e2", e2, :v0, mth, DBG, a)          unless e2.key?(:v0)
    return hashkey("e2", e2, :v1, mth, DBG, a)          unless e2.key?(:v1)
    return mismatch("e1 :v0", e1[:v0], cl, mth, DBG, a) unless e1[:v0].is_a?(cl)
    return mismatch("e1 :v1", e1[:v1], cl, mth, DBG, a) unless e1[:v1].is_a?(cl)
    return mismatch("e2 :v0", e2[:v0], cl, mth, DBG, a) unless e2[:v0].is_a?(cl)
    return mismatch("e2 :v1", e2[:v1], cl, mth, DBG, a) unless e2[:v1].is_a?(cl)

    e1_vector = e1[:v1] - e1[:v0]
    e2_vector = e2[:v1] - e2[:v0]

    return zero("e1", mth, DBG, a) if e1_vector.magnitude < TOL
    return zero("e2", mth, DBG, a) if e2_vector.magnitude < TOL

    return true if
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

    false
  end

  ##
  # Return Topolys vertices and a Topolys wire from Topolys points. As a side
  # effect, it will - if successful - also populate the Topolys model with the
  # vertices and wire.
  #
  # @param model [Topolys::Model] a model
  # @param pts [Array] a 1D array of 3D Topolys points (min 3x)
  #
  # @return [Hash] vx: 3D Topolys vertices Array; w: corresponding Topolys::Wire
  # @return [Hash] vx: nil; w: nil (if invalid input)
  def objects(model = nil, pts = [])
    mth = "TBD::#{__callee__}"
    cl  = Topolys::Model
    obj = { vx: nil, w: nil }

    return mismatch("model", model, cl, mth, DBG, obj)   unless model.is_a?(cl)
    return mismatch("points", pts, Array, mth, DBG, obj) unless pts.is_a?(Array)

    log(DBG, "#{pts.size}? need +3 Topolys points (#{mth})") unless pts.size > 2
    return obj                                               unless pts.size > 2

    obj[:vx] = model.get_vertices(pts)
    obj[:w ] = model.get_wire(obj[:vx])

    obj
  end

  ##
  # Populate collection of TBD hinged 'kids' (subsurfaces), relying on Topolys.
  # As a side effect, it will - if successful - also populate a Topolys 'model'
  # with Topolys vertices, wires, holes. In rare cases such as domes of tubular
  # daylighting devices (TDDs), kids may be 'unhinged', i.e. not on same 3D
  # plane as 'dad(s)' - TBD corrects such cases elsewhere.
  #
  # @param model [Topolys::Model] a model
  # @param boys [Hash] a collection of TBD subsurfaces
  #
  # @return [Array] 3D Topolys wires of 'holes' (made by kids)
  def kids(model = nil, boys = {})
    mth = "TBD::#{__callee__}"
    cl  = Topolys::Model
    holes = []

    return mismatch("model", model, cl, mth, DBG, holes) unless model.is_a?(cl)
    return mismatch("boys", boys, Hash, mth, DBG, holes) unless boys.is_a?(Hash)

    boys.each do |id, props|
      obj = objects(model, props[:points])
      next unless obj[:w]
      obj[:w].attributes[:id      ] = id
      obj[:w].attributes[:unhinged] = props[:unhinged] if props.key?(:unhinged)
      obj[:w].attributes[:n       ] = props[:n]        if props.key?(:n)
      props[:hole]                  = obj[:w]
      holes << obj[:w]
    end

    holes
  end

  ##
  # Populate hash of TBD 'dads' (parent) surfaces, relying on Topolys. As a side
  # effect, it will - if successful - also populate the main Topolys model with
  # Topolys vertices, wires, holes & faces.
  #
  # @param model [Topolys::Model] a model
  # @param pops [Hash] a collection of TBD (parent) surfaces
  #
  # @return [Array] 3D Topolys wires of 'holes' (made by kids)
  def dads(model = nil, pops = {})
    mth   = "TBD::#{__callee__}"
    cl    = Topolys::Model
    holes = {}

    return mismatch("model", model, cl, mth, DBG, holes) unless model.is_a?(cl)
    return mismatch("pops", pops, Hash, mth, DBG, holes) unless pops.is_a?(Hash)

    pops.each do |id, props|
      hols   = []
      hinged = []
      obj    = objects(model, props[:points])
      next unless obj[:vx] && obj[:w]
      hols  += kids(model, props[:windows  ])          if props.key?(:windows  )
      hols  += kids(model, props[:doors    ])          if props.key?(:doors    )
      hols  += kids(model, props[:skylights])          if props.key?(:skylights)
      hols.each { |hol| hinged << hol unless hol.attributes[:unhinged] }
      face = model.get_face(obj[:w], hinged)
      log(DBG, "Unable to retrieve valid 'dad' (#{mth})")            unless face
      next                                                           unless face
      face.attributes[:id] = id
      face.attributes[:n]  = props[:n] if props.key?(:n)
      props[:face]         = face
      hols.each { |hol| holes[hol.attributes[:id]] = hol }
    end

    holes
  end

  ##
  # Populate TBD edges with linked Topolys faces.
  #
  # @param s [Hash] a collection of TBD surfaces
  # @param e [Hash] a collection TBD edges
  #
  # @return [Bool] true if successful
  # @return [Bool] false if invalid input
  def faces(s = {}, e = {})
    mth = "TBD::#{__callee__}"

    return mismatch("surfaces", s, Hash, mth, DBG, false)   unless s.is_a?(Hash)
    return mismatch("edges", e, Hash, mth, DBG, false)      unless e.is_a?(Hash)

    s.each do |id, props|
      log(DBG, "Missing Topolys face '#{id}' (#{mth})") unless props.key?(:face)
      next                                              unless props.key?(:face)

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
  # Validate whether an OpenStudio planar surface is safe for TBD to process.
  #
  # @param s [OpenStudio::Model::PlanarSurface] a surface
  #
  # @return [Bool] true if valid surface
  def validate(s = nil)
    mth = "TBD::#{__callee__}"
    cl = OpenStudio::Model::PlanarSurface

    return mismatch("surface", s, cl, mth, DBG, false)        unless s.is_a?(cl)

    id   = s.nameString
    size = s.vertices.size
    last = size - 1

    log(ERR, "#{id} #{size} vertices? need +3 (#{mth})")         unless size > 2
    return false                                                 unless size > 2

    [0, last].each do |i|
      v1 = s.vertices[i]
      v2 = s.vertices[i + 1]                                    unless i == last
      v2 = s.vertices.first                                         if i == last
      vector = v2 - v1
      bad = vector.length < TOL
      log(ERR, "#{id}: < #{TOL}m (#{mth})")                               if bad
      return false                                                        if bad
    end

    # Add as many extra tests as needed ...
    true
  end

  ##
  # Return site-specific (or true) Topolys normal vector of OpenStudio surface.
  #
  # @param s [OpenStudio::Model::PlanarSurface] a planar surface
  # @param r [Float] a group/site rotation angle [0,2PI) radians
  #
  # @return [Topolys::Vector3D] normal (Topolys) vector <x,y,z> of s
  # @return [NilClass] if invalid input
  def trueNormal(s = nil, r = 0)
    mth = "TBD::#{__callee__}"
    cl  = OpenStudio::Model::PlanarSurface

    return mismatch("surface", s, cl, mth)           unless s.is_a?(cl)
    return invalid("rotation angle", mth, 2)         unless r.respond_to?(:to_f)

    r = -r.to_f * Math::PI / 180.0
    vx = s.outwardNormal.x * Math.cos(r) - s.outwardNormal.y * Math.sin(r)
    vy = s.outwardNormal.x * Math.sin(r) + s.outwardNormal.y * Math.cos(r)
    vz = s.outwardNormal.z
    Topolys::Vector3D.new(vx, vy, vz)
  end

  ##
  # Fetch OpenStudio surface properties, including opening areas & vertices.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param surface [OpenStudio::Model::Surface] a surface
  #
  # @return [Hash] TBD surface with key attributes, including openings
  # @return [NilClass] if invalid input
  def properties(model = nil, surface = nil)
    mth = "TBD::#{__callee__}"
    cl1 = OpenStudio::Model::Model
    cl2 = OpenStudio::Model::Surface
    cl3 = OpenStudio::Model::LayeredConstruction

    return mismatch("model", model, cl1, mth)          unless model.is_a?(cl1)
    return mismatch("surface", surface, cl2, mth)      unless surface.is_a?(cl2)

    return nil unless validate(surface)

    nom    = surface.nameString
    surf   = {}
    subs   = {}
    fd     = false
    return   empty("'#{nom}' space", mth, ERR)           if surface.space.empty?
    space  = surface.space.get
    stype  = space.spaceType
    story  = space.buildingStory
    tr     = transforms(model, space)
    return   invalid("'#{nom}' transform", mth, 0, FTL)  unless tr[:t] && tr[:r]
    t      = tr[:t]
    n      = trueNormal(surface, tr[:r])
    return   invalid("'#{nom}' normal", mth, 0, FTL)     unless n
    type   = surface.surfaceType.downcase
    facing = surface.outsideBoundaryCondition

    if facing.downcase == "surface"
      empty = surface.adjacentSurface.empty?
      return invalid("'#{nom}': adjacent surface", mth, 0, ERR)         if empty
      facing = surface.adjacentSurface.get.nameString
    end

    unless surface.construction.empty?
      construction = surface.construction.get.to_LayeredConstruction

      unless construction.empty?
        construction = construction.get
        lyr          = insulatingLayer(construction)
        lyr[:index]  = nil         unless lyr[:index].is_a?(Numeric)
        lyr[:index]  = nil         unless lyr[:index] >= 0
        lyr[:index]  = nil         unless lyr[:index] < construction.layers.size

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

    surf[:conditioned] = true
    surf[:space      ] = space
    surf[:boundary   ] = facing
    surf[:ground     ] = surface.isGroundSurface
    surf[:type       ] = :floor
    surf[:type       ] = :ceiling                    if type.include?("ceiling")
    surf[:type       ] = :wall                       if type.include?("wall"   )
    surf[:stype      ] = stype.get               unless stype.empty?
    surf[:story      ] = story.get               unless story.empty?
    surf[:n          ] = n
    surf[:gross      ] = surface.grossArea

    surface.subSurfaces.sort_by { |s| s.nameString }.each do |s|
      next unless validate(s)

      id       = s.nameString
      valid    = s.vertices.size == 3 || s.vertices.size == 4
      log(ERR, "Skipping '#{id}': vertex # 3 or 4 (#{mth})")        unless valid
      next                                                          unless valid
      vec      = s.vertices
      area     = s.grossArea
      typ      = s.subSurfaceType.downcase
      type     = :skylight
      type     = :window       if typ.include?("window" )
      type     = :door         if typ.include?("door"   )
      glazed   = type == :door && typ.include?("glass"  )
      tubular  =                  typ.include?("tubular")
      domed    =                  typ.include?("dome"   )
      unhinged = false

      # Determine if TDD dome subsurface is unhinged i.e. unconnected to parent.
      if domed
        unhinged = true                      unless s.plane.equal(surface.plane)
        n        = s.outwardNormal               if unhinged
      end

      log(ERR, "Skipping '#{id}': gross area ~zero (#{mth})")      if area < TOL
      next                                                         if area < TOL
      c = s.construction
      log(ERR, "Skipping '#{id}': missing construction (#{mth})")    if c.empty?
      next                                                           if c.empty?
      c = c.get.to_LayeredConstruction
      log(WRN, "Skipping '#{id}': subs limited to #{cl3} (#{mth})")  if c.empty?
      next                                                           if c.empty?
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
      # dome-to-diffuser RSi values (if valid).
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
      u = u.get                                                  unless u.empty?

      if tubular & s.respond_to?(:daylightingDeviceTubular)       # OSM > v3.3.0
        unless s.daylightingDeviceTubular.empty?
          r = s.daylightingDeviceTubular.get.effectiveThermalResistance
          u = 1 / r                                                   if r > TOL
        end
      end

      unless u.is_a?(Numeric)
        u = s.additionalProperties.getFeatureAsDouble("uFactor")
      end

      unless u.is_a?(Numeric)
        r = rsi(c, surface.filmResistance)
        log(ERR, "Skipping '#{id}': U-factor unavailable (#{mth})")   if r < TOL
        next                                                          if r < TOL
        u = 1 / r
      end

      frame = s.allowWindowPropertyFrameAndDivider
      frame = false if s.windowPropertyFrameAndDivider.empty?

      if frame
        fd    = true
        width = s.windowPropertyFrameAndDivider.get.frameWidth
        vec   = offset(vec, width, 300)
        area  = OpenStudio.getArea(vec)
        log(ERR, "Skipping '#{id}': invalid offset (#{mth})") if area.empty?
        next                                                  if area.empty?
        area = area.get
      end

      sub = { v:        s.vertices,
              points:   vec,
              n:        n,
              gross:    s.grossArea,
              area:     area,
              type:     type,
              u:        u,
              unhinged: unhinged }

      sub[:glazed] = true if glazed
      subs[id]     = sub
    end

    valid = true
    # Test for conflicts (with fits?, overlaps?) between sub/surfaces to
    # determine whether to keep original points or switch to std::vector of
    # revised coordinates, offset by Frame & Divider frame width. This will
    # also inadvertently catch pre-existing (yet nonetheless invalid)
    # OpenStudio inputs (without Frame & Dividers).
    subs.each do |id, sub|
      break                                                         unless fd
      break                                                         unless valid
      valid = fits?(sub[:points], surface.vertices, id, nom)
      log(ERR, "Skipping '#{id}': can't fit in '#{nom}' (#{mth})")  unless valid

      subs.each do |i, sb|
        break                                                       unless valid
        next                                                          if i == id
        oops = overlaps?(sb[:points], sub[:points], id, nom)
        log(ERR, "Skipping '#{id}': overlaps sibling '#{i}' (#{mth})")   if oops
        valid = false                                                    if oops
      end
    end

    if fd
      subs.values.each { |sub| sub[:gross ] = sub[:area ] }             if valid
      subs.values.each { |sub| sub[:points] = sub[:v    ] }         unless valid
      subs.values.each { |sub| sub[:area  ] = sub[:gross] }         unless valid
    end

    subarea = 0
    subs.values.each { |sub| subarea += sub[:area] }
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

        if sub[:type] == type
          surf[types]     = {}                           unless surf.key?(types)
          surf[types][id] = sub
        end
      end
    end

    surf
  end

  ##
  # Validate whether edge surfaces form a concave angle, as seen from outside.
  #
  # @param s1 [Surface] first TBD surface
  # @param s2 [Surface] second TBD surface
  #
  # @return [Bool] true if angle between surfaces is concave
  # @return [Bool] false if invalid input
  def concave?(s1 = nil, s2 = nil)
    mth = "TBD::#{__callee__}"

    return mismatch("s1", s1, Hash, mth, DBG, false)     unless s1.is_a?(Hash)
    return mismatch("s2", s2, Hash, mth, DBG, false)     unless s2.is_a?(Hash)
    return hashkey("s1", s1, :angle, mth, DBG, false)    unless s1.key?(:angle)
    return hashkey("s2", s2, :angle, mth, DBG, false)    unless s2.key?(:angle)
    return hashkey("s1", s1, :normal, mth, DBG, false)   unless s1.key?(:normal)
    return hashkey("s2", s2, :normal, mth, DBG, false)   unless s2.key?(:normal)
    return hashkey("s1", s1, :polar, mth, DBG, false)    unless s1.key?(:polar)
    return hashkey("s2", s2, :polar, mth, DBG, false)    unless s2.key?(:polar)
    valid1 = s1[:angle].is_a?(Numeric)
    valid2 = s2[:angle].is_a?(Numeric)
    return mismatch("s1 angle", s1[:angle], Numeric, DBG, false)   unless valid1
    return mismatch("s1 angle", s1[:angle], Numeric, DBG, false)   unless valid2

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
  # Validate whether edge surfaces form a convex angle, as seen from outside.
  #
  # @param s1 [Surface] first TBD surface
  # @param s2 [Surface] second TBD surface
  #
  # @return [Bool] true if angle between surfaces is convex
  # @return [Bool] false if invalid input
  def convex?(s1 = nil, s2 = nil)
    mth = "TBD::#{__callee__}"

    return mismatch("s1", s1, Hash, mth, DBG, false)     unless s1.is_a?(Hash)
    return mismatch("s2", s2, Hash, mth, DBG, false)     unless s2.is_a?(Hash)
    return hashkey("s1", s1, :angle, mth, DBG, false)    unless s1.key?(:angle)
    return hashkey("s2", s2, :angle, mth, DBG, false)    unless s2.key?(:angle)
    return hashkey("s1", s1, :normal, mth, DBG, false)   unless s1.key?(:normal)
    return hashkey("s2", s2, :normal, mth, DBG, false)   unless s2.key?(:normal)
    return hashkey("s1", s1, :polar, mth, DBG, false)    unless s1.key?(:polar)
    return hashkey("s2", s2, :polar, mth, DBG, false)    unless s2.key?(:polar)
    valid1 = s1[:angle].is_a?(Numeric)
    valid2 = s2[:angle].is_a?(Numeric)
    return mismatch("s1 angle", s1[:angle], Numeric, DBG, false)   unless valid1
    return mismatch("s1 angle", s1[:angle], Numeric, DBG, false)   unless valid2

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
  # Generate Kiva settings and objects if model surfaces have 'foundation'
  # boundary conditions.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param floors [Hash] TBD floors
  # @param walls [Hash] TBD walls
  # @param edges [Hash] TBD edges (many linking floors & walls
  #
  # @return [Bool] true if Kiva foundations are successfully generated
  # @return [Bool] false if invalid input
  def kiva(model = nil, walls = {}, floors = {}, edges = {})
    mth = "TBD::#{__callee__}"
    cl1 = OpenStudio::Model::Model
    cl2 = Hash
    a   = false

    return mismatch("model", model, cl1, mth, DBG, a)   unless model.is_a?(cl1)
    return mismatch("walls", walls, cl2, mth, DBG, a)   unless walls.is_a?(cl2)
    return mismatch("floors", floors, cl2, mth, DBG, a) unless floors.is_a?(cl2)
    return mismatch("edges", edges, cl2, mth, DBG, a)   unless edges.is_a?(cl2)

    # Strictly relying on Kiva's total exposed perimeter approach.
    arg = "TotalExposedPerimeter"
    kiva = true
    # The following is loosely adapted from:
    #
    #   github.com/NREL/OpenStudio-resources/blob/develop/model/simulationtests/
    #   foundation_kiva.rb ... thanks.
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
        floors[id][:kiva   ] = :slab                  # initially slabs-on-grade
        floors[id][:exposed] = 0.0 # slab-on-grade or basement walkout perimeter

        edge[:surfaces].keys.each do |i|              # loop around current edge
          next     if i == id
          next unless walls.key?(i)
          next unless walls[i][:boundary].downcase == "foundation"
          next     if walls[i].key?(:kiva)
          floors[id][:kiva] = :basement
          walls[i  ][:kiva] = id
        end

        edge[:surfaces].keys.each do |i|              # loop around current edge
          next     if i == id
          next unless walls.key?(i)
          next unless walls[i][:boundary].downcase == "outdoors"
          floors[id][:exposed] += edge[:length]
        end

        edges.each do |code2, e|                 # loop around other floor edges
          next if code1 == code2                             #  skip - same edge

          e[:surfaces].keys.each do |i|
            next unless i == id                              # good - same floor

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
        kiva = false if per.empty?
        next         if per.empty?
        per           = per.get
        perimeter     = per.totalExposedPerimeter
        kiva = false if perimeter.empty?
        next         if perimeter.empty?
        perimeter     = perimeter.get

        if ep < 0.001
          ok   = per.setTotalExposedPerimeter(0.000)
          ok   = per.setTotalExposedPerimeter(0.001) unless ok
          kiva = false unless ok
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
      id        = walls[i][:kiva]
      next unless floors.key?(id)
      next unless floors[id].key?(:foundation)
      mur           = model.getSurfaceByName(i)         # locate OpenStudio wall
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
