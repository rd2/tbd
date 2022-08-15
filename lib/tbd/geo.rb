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
  # @param pts [Array] a 1D array of 3D Topolys points (min 2x)
  #
  # @return [Hash] vx: 3D Topolys vertices Array; w: corresponding Topolys::Wire
  # @return [Hash] vx: nil; w: nil (if invalid input)
  def objects(model = nil, pts = [])
    mth = "OSut::#{__callee__}"
    cl  = Topolys::Model
    obj = { vx: nil, w: nil }

    return mismatch("model", model, cl, mth, DBG, obj)   unless model.is_a?(cl)
    return mismatch("points", pts, Array, mth, DBG, obj) unless pts.is_a?(Array)

    log(DBG, "#{pts.size}? need +2 Topolys points (#{mth})") unless pts.size > 2
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
  # plane as 'dad(s)' - TBD corrects auch cases elsewhere.
  #
  # @param model [Topolys::Model] a model
  # @param boys [Hash] a collection of TBD subsurfaces
  #
  # @return [Array] 3D Topolys wires of 'holes' (made by kids)
  def kids(model = nil, boys = {})
    mth = "OSut::#{__callee__}"
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
    mth   = "OSut::#{__callee__}"
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
    mth = "OSut::#{__callee__}"

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
  # Generate offset vertices by a certain width.
  #
  # @param pts [Array] OpenStudio Point3D vector/array
  # @param width [Float] offset width (m)
  #
  # @return [Array] offset Topolys 3D points
  # @return [Array] original OpenStudio points if failed
  def offset(pts = [], width = 0)
    mth = "TBD::#{__callee__}"

    valid = pts.is_a?(OpenStudio::Point3dVector) || pts.is_a?(Array)
    return mismatch("pts", pts, cl1, mth, DBG, pts) unless valid
    return invalid("width", mth, 2, DBG, pts) unless width.respond_to?(:to_f)

    width = width.to_f
    return pts if width < TOL
    four = true if pts.size == 4

    ptz     = {}
    ptz[:A] = {}
    ptz[:B] = {}
    ptz[:C] = {}
    ptz[:D] = {} if four

    ptz[:A][:pt] = Topolys::Point3D.new(pts[0].x, pts[0].y, pts[0].z)
    ptz[:B][:pt] = Topolys::Point3D.new(pts[1].x, pts[1].y, pts[1].z)
    ptz[:C][:pt] = Topolys::Point3D.new(pts[2].x, pts[2].y, pts[2].z)
    ptz[:D][:pt] = Topolys::Point3D.new(pts[3].x, pts[3].y, pts[3].z) if four

    # Generate vector pairs, from next point & from previous point.
    #
    #
    #
    #
    #
    #
    #             A <---------- B
    #              ^
    #               \
    #                \
    #                 C (or D)
    #
    ptz[:A][:from_next] = ptz[:A][:pt] - ptz[:B][:pt]
    ptz[:A][:from_prev] = ptz[:A][:pt] - ptz[:C][:pt] unless four
    ptz[:A][:from_prev] = ptz[:A][:pt] - ptz[:D][:pt] if four

    ptz[:B][:from_next] = ptz[:B][:pt] - ptz[:C][:pt]
    ptz[:B][:from_prev] = ptz[:B][:pt] - ptz[:A][:pt]

    ptz[:C][:from_next] = ptz[:C][:pt] - ptz[:A][:pt] unless four
    ptz[:C][:from_next] = ptz[:C][:pt] - ptz[:D][:pt] if four
    ptz[:C][:from_prev] = ptz[:C][:pt] - ptz[:B][:pt]

    ptz[:D][:from_next] = ptz[:D][:pt] - ptz[:A][:pt] if four
    ptz[:D][:from_prev] = ptz[:D][:pt] - ptz[:C][:pt] if four

    # Generate 3D plane from vectors.
    #
    #
    #             |  <<< 3D plane ... from point A, with normal B>A
    #             |
    #             |
    #             |
    # <---------- A <---------- B
    #             |\
    #             | \
    #             |  \
    #             |   C (or D)
    #
    ptz[:A][:pl_from_next] = Topolys::Plane3D.new(ptz[:A][:pt], ptz[:A][:from_next])
    ptz[:A][:pl_from_prev] = Topolys::Plane3D.new(ptz[:A][:pt], ptz[:A][:from_prev])

    ptz[:B][:pl_from_next] = Topolys::Plane3D.new(ptz[:B][:pt], ptz[:B][:from_next])
    ptz[:B][:pl_from_prev] = Topolys::Plane3D.new(ptz[:B][:pt], ptz[:B][:from_prev])

    ptz[:C][:pl_from_next] = Topolys::Plane3D.new(ptz[:C][:pt], ptz[:C][:from_next])
    ptz[:C][:pl_from_prev] = Topolys::Plane3D.new(ptz[:C][:pt], ptz[:C][:from_prev])

    ptz[:D][:pl_from_next] = Topolys::Plane3D.new(ptz[:D][:pt], ptz[:D][:from_next]) if four
    ptz[:D][:pl_from_prev] = Topolys::Plane3D.new(ptz[:D][:pt], ptz[:D][:from_prev]) if four

    # Project an extended point (pC) unto 3D plane.
    #
    #             pC   <<< projected unto extended B>A 3D plane
    #        eC   |
    #          \  |
    #           \ |
    #            \|
    # <---------- A <---------- B
    #             |\
    #             | \
    #             |  \
    #             |   C (or D)
    #
    ptz[:A][:prev_unto_next_pl] = ptz[:A][:pl_from_next].project(ptz[:A][:pt] +
                                  ptz[:A][:from_prev])
    ptz[:A][:next_unto_prev_pl] = ptz[:A][:pl_from_prev].project(ptz[:A][:pt] +
                                  ptz[:A][:from_next])

    ptz[:B][:prev_unto_next_pl] = ptz[:B][:pl_from_next].project(ptz[:B][:pt] +
                                  ptz[:B][:from_prev])
    ptz[:B][:next_unto_prev_pl] = ptz[:B][:pl_from_prev].project(ptz[:B][:pt] +
                                  ptz[:B][:from_next])

    ptz[:C][:prev_unto_next_pl] = ptz[:C][:pl_from_next].project(ptz[:C][:pt] +
                                  ptz[:C][:from_prev])
    ptz[:C][:next_unto_prev_pl] = ptz[:C][:pl_from_prev].project(ptz[:C][:pt] +
                                  ptz[:C][:from_next])

    ptz[:D][:prev_unto_next_pl] = ptz[:D][:pl_from_next].project(ptz[:D][:pt] +
                                  ptz[:D][:from_prev]) if four
    ptz[:D][:next_unto_prev_pl] = ptz[:D][:pl_from_prev].project(ptz[:D][:pt] +
                                  ptz[:D][:from_next]) if four

    # Generate vector from point (e.g. A) to projected extended point (pC).
    #
    #             pC
    #        eC   ^
    #          \  |
    #           \ |
    #            \|
    # <---------- A <---------- B
    #             |\
    #             | \
    #             |  \
    #             |   C (or D)
    #
    ptz[:A][:n_prev_unto_next_pl] = ptz[:A][:prev_unto_next_pl] - ptz[:A][:pt]
    ptz[:A][:n_next_unto_prev_pl] = ptz[:A][:next_unto_prev_pl] - ptz[:A][:pt]

    ptz[:B][:n_prev_unto_next_pl] = ptz[:B][:prev_unto_next_pl] - ptz[:B][:pt]
    ptz[:B][:n_next_unto_prev_pl] = ptz[:B][:next_unto_prev_pl] - ptz[:B][:pt]

    ptz[:C][:n_prev_unto_next_pl] = ptz[:C][:prev_unto_next_pl] - ptz[:C][:pt]
    ptz[:C][:n_next_unto_prev_pl] = ptz[:C][:next_unto_prev_pl] - ptz[:C][:pt]

    ptz[:D][:n_prev_unto_next_pl] = ptz[:D][:prev_unto_next_pl] - ptz[:D][:pt] if four
    ptz[:D][:n_next_unto_prev_pl] = ptz[:D][:next_unto_prev_pl] - ptz[:D][:pt] if four

    # Fetch angle between both extended vectors (A>pC & A>pB), then normalize (Cn).
    #
    #             pC
    #        eC   ^
    #          \  |
    #           \ Cn
    #            \|
    # <---------- A <---------- B
    #             |\
    #             | \
    #             |  \
    #             |   C (or D)
    #
    ptz[:A][:angle] = ptz[:A][:n_prev_unto_next_pl].angle(ptz[:A][:n_next_unto_prev_pl])
    ptz[:B][:angle] = ptz[:B][:n_prev_unto_next_pl].angle(ptz[:B][:n_next_unto_prev_pl])
    ptz[:C][:angle] = ptz[:C][:n_prev_unto_next_pl].angle(ptz[:C][:n_next_unto_prev_pl])
    ptz[:D][:angle] = ptz[:D][:n_prev_unto_next_pl].angle(ptz[:D][:n_next_unto_prev_pl]) if four

    # Generate new 3D points A', B', C' (and D') ... zigzag.
    #
    #
    #
    #
    #     A' ---------------------- B'
    #      \
    #       \      A <---------- B
    #        \      \
    #         \      \
    #          \      \
    #           C'      C
    ptz[:A][:from_next].normalize!
    ptz[:A][:n_prev_unto_next_pl].normalize!
    ptz[:A][:p] = ptz[:A][:pt] + (ptz[:A][:n_prev_unto_next_pl] * width) +
                 (ptz[:A][:from_next] * width * Math.tan(ptz[:A][:angle]/2))

    ptz[:B][:from_next].normalize!
    ptz[:B][:n_prev_unto_next_pl].normalize!
    ptz[:B][:p] = ptz[:B][:pt] + (ptz[:B][:n_prev_unto_next_pl] * width) +
                 (ptz[:B][:from_next] * width * Math.tan(ptz[:B][:angle]/2))

    ptz[:C][:from_next].normalize!
    ptz[:C][:n_prev_unto_next_pl].normalize!
    ptz[:C][:p] = ptz[:C][:pt] + (ptz[:C][:n_prev_unto_next_pl] * width) +
                 (ptz[:C][:from_next] * width * Math.tan(ptz[:C][:angle]/2))

    if four
      ptz[:D][:from_next].normalize!
      ptz[:D][:n_prev_unto_next_pl].normalize!
      ptz[:D][:p] = ptz[:D][:pt] + (ptz[:D][:n_prev_unto_next_pl] * width) +
                   (ptz[:D][:from_next] * width * Math.tan(ptz[:D][:angle]/2))
    end

    ptz
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
      id       = s.nameString
      valid    = s.vertices.size == 3 || s.vertices.size == 4
      log(ERR, "Skipping '#{id}': vertex # 3 or 4 (#{mth})")        unless valid
      next                                                          unless valid
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
        unhinged = true unless s.plane.equal(surface.plane)
      end

      zero = s.grossArea < TOL
      log(ERR, "Skipping '#{id}': gross area ~zero (#{mth})")            if zero
      next                                                               if zero
      c = s.construction
      log(ERR, "Skipping '#{id}': missing construction (#{mth})")    if c.empty?
      next                                                           if c.empty?
      c = c.get.to_LayeredConstruction
      log(ERR, "Skipping '#{id}': must be a #{cl3} (#{mth})")        if c.empty?
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
      # resistances). This is the least accurate option, especially if
      # subsurfaces have Frame & Divider objects, or irregular geometry.
      u = s.uFactor
      u = u.get                                                  unless u.empty?

      if tubular & s.respond_to?(:daylightingDeviceTubular)       # OSM > v3.3.0
        unless s.daylightingDeviceTubular.empty?
          r = s.daylightingDeviceTubular.get.effectiveThermalResistance
          u = 1 / r if r > TOL
        end
      end

      if s.respond_to?(:assemblyUFactor)     # favour this U-factor unless empty
        u = s.assemblyUFactor.get unless s.assemblyUFactor.empty?
      end

      unless u.is_a?(Numeric)
        u = s.additionalProperties.getFeatureAsDouble("uFactor")
      end

      unless u.is_a?(Numeric)
        r = rsi(c, surface.filmResistance)
        log(ERR, "Skipping '#{id}': U-factor unavailable (#{mth})") if r < TOL
        next if r < TOL
        u = 1 / r
      end

      # Should verify convexity of vertex wire/face ...
      #
      #       A
      #      / \
      #     /   \
      #    /     \
      #   / C --- D    <<< allowed as OpenStudio/E+ subsurface?
      #  / /
      #  B
      #
      # Should convert (annoying) 4-point subsurface into triangle ...
      #        A
      #       / \
      #      /   \
      #     /     \
      #    B - C - D   <<< allowed as OpenStudio/E+ subsurface?
      #
      four = s.vertices.size == 4

      if tubular || s.windowPropertyFrameAndDivider.empty?
        vec = s.vertices
        area = s.grossArea
        n = s.outwardNormal if unhinged
      else
        fd = true
        width = s.windowPropertyFrameAndDivider.get.frameWidth
        ptz = offset(s.vertices, width)

        # Re-convert Topolys 3D points into OpenStudio 3D points.
        vec = OpenStudio::Point3dVector.new
        vec << OpenStudio::Point3d.new(ptz[:A][:p].x,
                                       ptz[:A][:p].y,
                                       ptz[:A][:p].z)
        vec << OpenStudio::Point3d.new(ptz[:B][:p].x,
                                       ptz[:B][:p].y,
                                       ptz[:B][:p].z)
        vec << OpenStudio::Point3d.new(ptz[:C][:p].x,
                                       ptz[:C][:p].y,
                                       ptz[:C][:p].z)
        vec << OpenStudio::Point3d.new(ptz[:D][:p].x,
                                       ptz[:D][:p].y,
                                       ptz[:D][:p].z) if four
        area = OpenStudio::getArea(vec).get
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

      subs[id] = sub
    end

    valid = true
    # Test for conflicts (with fits?, overlaps?) between surfaces to determine
    # whether to keep original points or switch to std::vector of revised
    # coordinates, offset by Frame & Divider frame width. This will also
    # inadvertently catch pre-existing (yet nonetheless invalid) OpenStudio
    # inputs (without Frame & Dividers).
    subs.each do |id, sub|
      break                                                         unless fd
      break                                                         unless valid
      valid = fits?(sub[:points], surface.vertices, id, nom)
      log(ERR, "Skipping '#{id}': can't fit in '#{nom}' (#{mth})")  unless valid

      subs.each do |i, sb|
        break                                                       unless valid
        next if i == id
        oops = overlaps?(sb[:points], sub[:points], id, nom)
        log(ERR, "Skipping '#{id}': overlaps sibling '#{i}' (#{mth})")  if oops
        valid = false                                                   if oops
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
          surf[types]     = {} unless surf.key?(types)
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
    cl = OpenStudio::Model::Model

    return mismatch("model", model, cl, mth)           unless model.is_a?(cl)
    return mismatch("walls", walls, Hash, mth)         unless walls.is_a?(Hash)
    return mismatch("floors", floors, Hash, mth)       unless floors.is_a?(Hash)
    return mismatch("edges", edges, Hash, mth)         unless edges.is_a?(Hash)

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
    #
    # TO-DO: Check in.idf vs in.osm for any deviation from default values as
    # specified in the IO Reference Manual. One way to expose in-built default
    # parameters (in the future), e.g.:
    #
    #   foundation_kiva_settings = model.getFoundationKivaSettings
    #   soil_k = foundation_kiva_settings.soilConductivity
    #   foundation_kiva_settings.setSoilConductivity(soil_k)

    # Generic 1" XPS insulation (for slab-on-grade setup) - unused if basement.
    xps25 = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    xps25.setName("XPS 25mm")
    xps25.setRoughness("Rough")
    xps25.setThickness(0.0254)
    xps25.setConductivity(0.029)
    xps25.setDensity(28)
    xps25.setSpecificHeat(1450)
    xps25.setThermalAbsorptance(0.9)
    xps25.setSolarAbsorptance(0.7)

    # Tag foundation-facing floors, then walls.
    edges.values.each do |edge|
      edge[:surfaces].keys.each do |id|

        # Start by processing edge-linked foundation-facing floors.
        next unless floors.key?(id)
        next unless floors[id][:boundary].downcase == "foundation"

        # By default, foundation floors are initially slabs-on-grade.
        floors[id][:kiva] = :slab

        # Re(tag) floors as basements if foundation-facing walls.
        edge[:surfaces].keys.each do |i|
          next unless walls.key?(i)
          next unless walls[i][:boundary].downcase == "foundation"
          next if walls[i].key?(:kiva)

          # (Re)tag as :basement if edge-linked foundation walls.
          floors[id][:kiva] = :basement
          walls[i][:kiva] = id
        end
      end
    end

    # Fetch exposed perimeters.
    edges.values.each do |edge|
      edge[:surfaces].keys.each do |id|
        next unless floors.key?(id)
        next unless floors[id].key?(:kiva)

        # Initialize if first iteration.
        floors[id][:exposed] = 0.0 unless floors[id].key?(:exposed)

        edge[:surfaces].keys.each do |i|
          next unless walls.key?(i)
          b = walls[i][:boundary].downcase
          next unless b == "outdoors"
          floors[id][:exposed] += edge[:length]
        end
      end
    end

    # Generate unique Kiva foundation per foundation-facing floor.
    edges.values.each do |edge|
      edge[:surfaces].keys.each do |id|
        next unless floors.key?(id)
        next unless floors[id].key?(:kiva)
        next if floors[id].key?(:foundation)

        floors[id][:foundation] = OpenStudio::Model::FoundationKiva.new(model)

        # It's assumed that generated foundation walls have insulated
        # constructions. Perimeter insulation for slabs-on-grade.
        # Typical circa-1980 slab-on-grade (perimeter) insulation setup.
        if floors[id][:kiva] == :slab
          floors[id][:foundation].setInteriorHorizontalInsulationMaterial(xps25)
          floors[id][:foundation].setInteriorHorizontalInsulationWidth(0.6)
        end

        # Locate OSM surface and assign Kiva foundation & perimeter objects.
        found = false

        model.getSurfaces.each do |s|
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
          ep = floors[id][:exposed]
          #ep = TOL if ep < TOL
          perimeter = s.createSurfacePropertyExposedFoundationPerimeter(arg, ep)

          # The following 5x lines are a (temporary?) fix for exposed perimeter
          # lengths of 0m - a perfectly valid entry in an IDF, e.g. "core" slab.
          # Unfortunately OpenStudio (currently) rejects 0 as an inclusive
          # minimum value. So despite passing a valid 0 "exp" argument,
          # OpenStudio does not initialize the "TotalExposedPerimeter" entry.
          # Compare relevant EnergyPlus vs OpenStudio .idd entries.
          #
          # The fix: if a valid Kiva exposed perimeter is equal or less than
          # 1mm, fetch perimeter object and attempt to explicitely set the
          # exposed perimeter length to 0m. If unsuccessful (situation remains
          # unfixed), then set to 1mm. Simulations results should be virtually
          # identical.
          unless ep > 0.001 || perimeter.empty?
            perimeter = perimeter.get
            success = perimeter.setTotalExposedPerimeter(0)
            perimeter.setTotalExposedPerimeter(0.001) unless success
          end

        end
        kiva = found
      end
    end

    # Link foundation walls to right Kiva foundation objects (if applicable).
    edges.values.each do |edge|
      edge[:surfaces].keys.each do |i|
        next unless walls.key?(i)
        next unless walls[i].key?(:kiva)
        id = walls[i][:kiva]
        next unless floors.key?(id)
        next unless floors[id].key?(:foundation)

        # Locate OSM wall.
        model.getSurfaces.each do |s|
          next unless s.nameString == i
          s.setAdjacentFoundation(floors[id][:foundation])
          s.setConstruction(s.construction.get)
        end
      end
    end

    kiva
  end
end
