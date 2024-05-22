# MIT License
#
# Copyright (c) 2020-2024 Denis Bourgeois & Dan Macumber
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
  # Calculates construction Uo (including surface film resistances) to meet Ut.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param lc [OpenStudio::Model::LayeredConstruction] a layered construction
  # @param id [#to_s] layered construction identifier
  # @param hloss [Numeric] heat loss from major thermal bridging, in W/K
  # @param film [Numeric] target surface film resistance, in m2•K/W
  # @param ut [Numeric] target overall Ut for lc, in W/m2•K
  #
  # @return [Hash] uo: lc Uo [W/m2•K] to meet Ut, m: uprated lc layer
  # @return [Hash] uo: (nil), m: (nil) if invalid input (see logs)
  def uo(model = nil, lc = nil, id = "", hloss = 0.0, film = 0.0, ut = 0.0)
    mth = "TBD::#{__callee__}"
    res = { uo: nil, m: nil }
    cl1 = OpenStudio::Model::Model
    cl2 = OpenStudio::Model::LayeredConstruction
    cl3 = Numeric
    cl4 = String
    id  = trim(id)
    return mismatch("model", model, cl1, mth, DBG, res) unless model.is_a?(cl1)
    return mismatch("id"   ,    id, cl4, mth, DBG, res)     if id.empty?
    return mismatch("lc"   ,    lc, cl2, mth, DBG, res) unless lc.is_a?(cl2)
    return mismatch("hloss", hloss, cl3, mth, DBG, res) unless hloss.is_a?(cl3)
    return mismatch("film" ,  film, cl3, mth, DBG, res) unless film.is_a?(cl3)
    return mismatch("Ut"   ,    ut, cl3, mth, DBG, res) unless ut.is_a?(cl3)

    loss        = 0.0 # residual heatloss (not assigned) [W/K]
    area        = lc.getNetArea
    lyr         = insulatingLayer(lc)
    lyr[:index] = nil unless lyr[:index].is_a?(Numeric)
    lyr[:index] = nil unless lyr[:index] >= 0
    lyr[:index] = nil unless lyr[:index] < lc.layers.size
    return invalid("#{id} layer index", mth, 3, ERR, res) unless lyr[:index]
    return zero("#{id}: heatloss"     , mth,    WRN, res) unless hloss > TOL
    return zero("#{id}: films"        , mth,    WRN, res) unless film  > TOL
    return zero("#{id}: Ut"           , mth,    WRN, res) unless ut    > TOL
    return invalid("#{id}: Ut"        , mth, 6, WRN, res) unless ut    < 5.678
    return zero("#{id}: net area (m2)", mth,    ERR, res) unless area  > TOL

    # First, calculate initial layer RSi to initially meet Ut target.
    rt     = 1 / ut              # target construction Rt
    ro     = rsi(lc, film)       # current construction Ro
    new_r  = lyr[:r] + (rt - ro) # new, un-derated layer RSi
    new_u  = 1 / new_r

    # Then, uprate (if possible) to counter expected thermal bridging effects.
    u_psi  = hloss / area        # from psi+khi
    new_u -= u_psi               # uprated layer USi to counter psi+khi
    new_r  = 1 / new_u           # uprated layer RSi to counter psi+khi
    return zero("#{id}: new Rsi", mth, ERR, res) unless new_r > 0.001

    if lyr[:type] == :massless
      m     = lc.getLayer(lyr[:index]).to_MasslessOpaqueMaterial
      return  invalid("#{id} massless layer?", mth, 0, DBG, res) if m.empty?

      m     = m.get.clone(model).to_MasslessOpaqueMaterial.get
              m.setName("#{id} uprated")
      new_r = 0.001                      unless new_r > 0.001
      loss  = (new_u - 1 / new_r) * area unless new_r > 0.001
              m.setThermalResistance(new_r)
    else # type == :standard
      m     = lc.getLayer(lyr[:index]).to_StandardOpaqueMaterial
      return  invalid("#{id} standard layer?", mth, 0, DBG, res) if m.empty?

      m     = m.get.clone(model).to_StandardOpaqueMaterial.get
              m.setName("#{id} uprated")
      k     = m.thermalConductivity

      if new_r > 0.001
        d   = new_r * k

        unless d > 0.003
          d    = 0.003
          k    = d / new_r
          k    = 3.0                    unless k < 3.0
          loss = (new_u - k / d) * area unless k < 3.0
        end
      else # new_r < 0.001 m2•K/W
        d    = 0.001 * k
        d    = 0.003     unless d > 0.003
        k    = d / 0.001 unless d > 0.003
        loss = (new_u - k / d) * area
      end

      if m.setThickness(d)
        m.setThermalConductivity(k)
      else
        return invalid("Can't uprate #{id}: #{d} > 3m", mth, 0, ERR, res)
      end
    end

    return invalid("Can't ID insulating layer", mth, 0, ERR, res) unless m

    lc.setLayer(lyr[:index], m)
    uo = 1 / rsi(lc, film)

    if loss > TOL
      h_loss = format "%.3f", loss
      return invalid("Can't assign #{h_loss} W/K to #{id}", mth, 0, ERR, res)
    end

    res[:uo] = uo
    res[:m ] = m

    res
  end

  ##
  # Uprates insulation layer of construction, based on user-selected Ut (argh).
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param [Hash] s preprocessed collection of TBD surfaces
  # @option s [:wall, :ceiling, :floor] :type surface type
  # @option s [Bool] :deratable whether surface can be thermally bridged
  # @option s [OpenStudio::LayeredConstruction] :construction construction
  # @option s [#to_i] :index deratable construction layer index
  # @option s [:massless, :standard] :ltype indexed layer type
  # @option s [#to_f] :filmRSI air film resistances (optional)
  # @option s [#to_f] :r thermal resistance (RSI) of indexed layer
  # @param [Hash] argh TBD arguments
  # @option argh [Bool] :uprate_walls (false) whether to uprate walls
  # @option argh [Bool] :uprate_roofs (false) whether to uprate roofs
  # @option argh [Bool] :uprate_floors (false) whether to uprate floors
  # @option argh [#to_f] :wall_ut (5.678) uprated wall Usi-factor target
  # @option argh [#to_f] :roof_ut (5.678) uprated roof Usi-factor target
  # @option argh [#to_f] :floor_ut (5.678) uprated floor Usi-factor target
  # @option argh [#to_s] :wall_option ("") construction to uprate (or "all")
  # @option argh [#to_s] :roof_option ("") construction to uprate (or "all")
  # @option argh [#to_s] :floor_option ("") construction to uprate (or "all")
  #
  # @return [Bool] whether successfully uprated
  # @return [false] if invalid input (see logs)
  def uprate(model = nil, s = {}, argh = {})
    mth    = "TBD::#{__callee__}"
    cl1    = OpenStudio::Model::Model
    cl2    = Hash
    cl3    = OpenStudio::Model::LayeredConstruction
    tout   = []
    tout  << "all wall constructions"
    tout  << "all roof constructions"
    tout  << "all floor constructions"
    a      = false
    groups = { wall: {}, roof: {}, floor: {} }
    return mismatch("model"   , model, cl1, mth, DBG, a) unless model.is_a?(cl1)
    return mismatch("surfaces",     s, cl2, mth, DBG, a) unless s.is_a?(cl2)
    return mismatch("argh"    , model, cl1, mth, DBG, a) unless argh.is_a?(cl2)

    argh[:uprate_walls ] = false unless argh.key?(:uprate_walls)
    argh[:uprate_roofs ] = false unless argh.key?(:uprate_roofs)
    argh[:uprate_floors] = false unless argh.key?(:uprate_floors)
    argh[:wall_ut      ] = 5.678 unless argh.key?(:wall_ut)
    argh[:roof_ut      ] = 5.678 unless argh.key?(:roof_ut)
    argh[:floor_ut     ] = 5.678 unless argh.key?(:floor_ut)
    argh[:wall_option  ] = ""    unless argh.key?(:wall_option)
    argh[:roof_option  ] = ""    unless argh.key?(:roof_option)
    argh[:floor_option ] = ""    unless argh.key?(:floor_option)

    argh[:wall_option  ] = trim(argh[:wall_option ])
    argh[:roof_option  ] = trim(argh[:roof_option ])
    argh[:floor_option ] = trim(argh[:floor_option])

    groups[:wall ][:up] = argh[:uprate_walls ]
    groups[:roof ][:up] = argh[:uprate_roofs ]
    groups[:floor][:up] = argh[:uprate_floors]
    groups[:wall ][:ut] = argh[:wall_ut      ]
    groups[:roof ][:ut] = argh[:roof_ut      ]
    groups[:floor][:ut] = argh[:floor_ut     ]

    groups[:wall ][:op] = trim(argh[:wall_option  ])
    groups[:roof ][:op] = trim(argh[:roof_option  ])
    groups[:floor][:op] = trim(argh[:floor_option ])

    groups.each do |type, g|
      next unless g[:up]
      next unless g[:ut].is_a?(Numeric)
      next unless g[:ut] < 5.678
      next     if g[:ut] < 0

      typ  = type
      typ  = :ceiling if typ == :roof
      coll = {}
      area = 0
      film = 100000000000000
      lc   = nil
      id   = ""
      op   = g[:op].downcase
      all  = tout.include?(op)

      if g[:op].empty?
        log(ERR, "Construction (#{type}) to uprate? (#{mth})")
      elsif all
        s.each do |nom, surface|
          next unless surface.key?(:deratable   )
          next unless surface.key?(:type        )
          next unless surface.key?(:construction)
          next unless surface.key?(:filmRSI     )
          next unless surface.key?(:index       )
          next unless surface.key?(:ltype       )
          next unless surface.key?(:r           )
          next unless surface[:deratable   ]
          next unless surface[:type        ] == typ
          next unless surface[:construction].is_a?(cl3)
          next     if surface[:index       ].nil?

          # Retain lowest surface film resistance (e.g. tilted surfaces).
          c    = surface[:construction]
          i    = c.nameString
          aire = c.getNetArea
          film = surface[:filmRSI] if surface[:filmRSI] < film

          # Retain construction covering largest area. The following conditional
          # is reliable UNLESS linked to other deratable surface types e.g. both
          # floors AND walls (see "elsif lc" corrections below).
          if aire > area
            lc   = c
            area = aire
            id   = i
          end

          coll[i] = { area: aire, lc: c, s: {} }  unless coll.key?(i)
          coll[i][:s][nom] = { a: surface[:net] } unless coll[i][:s].key?(nom)
        end
      else
        id = g[:op]
        lc = model.getConstructionByName(id)
        log(ERR, "Construction '#{id}'? (#{mth})")         if lc.empty?
        next                                               if lc.empty?

        lc = lc.get.to_LayeredConstruction
        log(ERR, "'#{id}' layered construction? (#{mth})") if lc.empty?
        next                                               if lc.empty?

        lc       = lc.get
        area     = lc.getNetArea
        coll[id] = { area: area, lc: lc, s: {} }

        s.each do |nom, surface|
          next unless surface.key?(:deratable   )
          next unless surface.key?(:type        )
          next unless surface.key?(:construction)
          next unless surface.key?(:filmRSI     )
          next unless surface.key?(:index       )
          next unless surface.key?(:ltype       )
          next unless surface.key?(:r           )
          next unless surface[:deratable   ]
          next unless surface[:type        ] == typ
          next unless surface[:construction].is_a?(cl3)
          next     if surface[:index       ].nil?

          i = surface[:construction].nameString
          next unless i == id

          # Retain lowest surface film resistance (e.g. tilted surfaces).
          film = surface[:filmRSI] if surface[:filmRSI] < film

          coll[i][:s][nom] = { a: surface[:net] } unless coll[i][:s].key?(nom)
        end
      end

      if coll.empty?
        log(ERR, "No #{type} construction to uprate - skipping (#{mth})")
        next
      elsif lc
        # Valid layered construction - good to uprate!
        lyr         = insulatingLayer(lc)
        lyr[:index] = nil unless lyr[:index].is_a?(Numeric)
        lyr[:index] = nil unless lyr[:index] >= 0
        lyr[:index] = nil unless lyr[:index] < lc.layers.size

        log(ERR, "Insulation index for '#{id}'? (#{mth})") unless lyr[:index]
        next                                               unless lyr[:index]

        # Ensure lc is exclusively linked to deratable surfaces of right type.
        # If not, assign new lc clone to non-targeted surfaces.
        s.each do |nom, surface|
          next unless surface.key?(:type        )
          next unless surface.key?(:deratable   )
          next unless surface.key?(:construction)
          next unless surface[:construction].is_a?(cl3)
          next unless surface[:construction] == lc

          ok = true
          ok = false unless surface[:type     ] == typ
          ok = false unless surface[:deratable]
          ok = false unless coll.key?(id)
          ok = false unless coll[id][:s].key?(nom)

          unless ok
            log(WRN, "Cloning '#{nom}' construction - not '#{id}' (#{mth})")
            sss = model.getSurfaceByName(nom)
            next if sss.empty?

            sss    = sss.get
            cloned = lc.clone(model).to_LayeredConstruction.get
            cloned.setName("#{nom} - cloned")
            sss.setConstruction(cloned)
            surface[:construction] = cloned
            coll[id][:s].delete(nom)
          end
        end

        hloss = 0 # sum of applicable psi+khi-related losses [W/K]

        # Tally applicable psi+khi losses. Possible construction reassignment.
        coll.each do |i, col|
          col[:s].keys.each do |nom|
            next unless s.key?(nom)
            next unless s[nom].key?(:construction)
            next unless s[nom].key?(:index)
            next unless s[nom].key?(:ltype)
            next unless s[nom].key?(:r)

            # Tally applicable psi+khi.
            hloss += s[nom][:heatloss    ] if s[nom].key?(:heatloss)
            next  if s[nom][:construction] == lc

            # Reassign construction unless referencing lc.
            sss = model.getSurfaceByName(nom)
            next if sss.empty?

            sss = sss.get

            if sss.isConstructionDefaulted
              set = defaultConstructionSet(sss) # building? story?
              constructions = set.defaultExteriorSurfaceConstructions

              unless constructions.empty?
                constructions = constructions.get
                constructions.setWallConstruction(lc)        if typ == :wall
                constructions.setFloorConstruction(lc)       if typ == :floor
                constructions.setRoofCeilingConstruction(lc) if typ == :ceiling
              end
            else
              sss.setConstruction(lc)
            end

            s[nom][:construction] = lc          # reset TBD attributes
            s[nom][:index       ] = lyr[:index]
            s[nom][:ltype       ] = lyr[:type ]
            s[nom][:r           ] = lyr[:r    ] # temporary
          end
        end

        # Merge to ensure a single entry for coll Hash.
        coll.each do |i, col|
          next if i == id

          col[:s].each do |nom, sss|
            coll[id][:s][nom] = sss unless coll[id][:s].key?(nom)
          end
        end

        coll.delete_if { |i, _| i != id }

        unless coll.size == 1
          log(DBG, "Collection == 1? for '#{id}' (#{mth})")
          next
        end

        coll[id][:area] = lc.getNetArea
        res = uo(model, lc, id, hloss, film, g[:ut])

        unless res[:uo] && res[:m]
          log(ERR, "Unable to uprate '#{id}' (#{mth})")
          next
        end

        lyr = insulatingLayer(lc)

        # Loop through coll :s, and reset :r - likely modified by uo().
        coll.values.first[:s].keys.each do |nom|
          next unless s.key?(nom)
          next unless s[nom].key?(:index)
          next unless s[nom].key?(:ltype)
          next unless s[nom].key?(:r    )
          next unless s[nom][:index] == lyr[:index]
          next unless s[nom][:ltype] == lyr[:type ]

          s[nom][:r] = lyr[:r] # uprated insulating RSi factor, before derating
        end

        argh[:wall_uo ] = res[:uo] if typ == :wall
        argh[:roof_uo ] = res[:uo] if typ == :ceiling
        argh[:floor_uo] = res[:uo] if typ == :floor
      else
        log(ERR, "Nilled construction to uprate - (#{mth})")
        return false
      end
    end

    true
  end

  ##
  # Sets reference values for points, edges & surfaces (& subsurfaces) to
  # compute Quebec energy code (Section 3.3) UA' comparison (2021).
  #
  # @param [Hash] s TBD surfaces (keys: Openstudio surface names)
  # @option s [Bool] :deratable whether surface is deratable, s[][:deratable]
  # @option s [:wall, :ceiling, :floor] :type TBD surface type
  # @option s [#to_f] :heating applicable heating setpoint temperature in °C
  # @option s [#to_f] :cooling applicable cooling setpoint temperature in °C
  # @option s [Hash] :windows TBD surface-specific windows e.g. s[][:windows]
  # @option s [Hash] :doors TBD surface-specific doors
  # @option s [Hash] :skylights TBD surface-specific skylights
  # @option s [Hash] :pts point thermal bridges, e.g. s[][:pts] see KHI class
  # @option s [Hash] :edges TBD edges (keys: Topolys edge identifiers)
  # @param sets [TBD::PSI] a TBD model's PSI sets
  # @param spts [Bool] whether OpenStudio model holds heating/cooling setpoints
  #
  # @return [Bool] whether successful in generating UA' reference values
  # @return [false] if invalid inputs (see logs)
  def qc33(s = {}, sets = nil, spts = true)
    mth = "TBD::#{__callee__}"
    cl1 = Hash
    cl2 = TBD::PSI
    return mismatch("surfaces", s, cl1, mth, DBG, false) unless s.is_a?(cl1)
    return mismatch("sets",  sets, cl1, mth, DBG, false) unless sets.is_a?(cl2)

    shorts = sets.shorthands("code (Quebec)")
    empty  = shorts[:has].empty? || shorts[:val].empty?
    log(DBG, "Missing QC PSI set for 3.3 UA' tradeoff (#{mth})") if empty
    return false                                                 if empty

    ok = [true, false].include?(spts)
    log(DBG, "setpoints must be true or false for 3.3 UA' tradeoff") unless ok
    return false                                                     unless ok

    s.each do |id, surface|
      next unless surface.key?(:deratable)
      next unless surface[:deratable]
      next unless surface.key?(:type)

      heating = -50     if spts
      cooling =  50     if spts
      heating =  21 unless spts
      cooling =  24 unless spts
      heating = surface[:heating] if surface.key?(:heating)
      cooling = surface[:cooling] if surface.key?(:cooling)

      # Start with surface U-factors.
      ref = 1 / 5.46
      ref = 1 / 3.60 if surface[:type] == :wall

      # Adjust for lower heating setpoint (assumes -25°C design conditions).
      ref *= 43 / (heating + 25) if heating < 18 && cooling > 40

      surface[:ref] = ref

      if surface.key?(:skylights) # loop through subsurfaces
        ref = 2.85
        ref *= 43 / (heating + 25) if heating < 18 && cooling > 40

        surface[:skylights].values.map { |skylight| skylight[:ref] = ref }
      end

      if surface.key?(:windows)
        ref = 2.0
        ref *= 43 / (heating + 25) if heating < 18 && cooling > 40

        surface[:windows].values.map { |window| window[:ref] = ref }
      end

      if surface.key?(:doors)
        surface[:doors].each do |i, door|
          ref = 0.9
          ref = 2.0 if door.key?(:glazed) && door[:glazed]
          ref *= 43 / (heating + 25) if heating < 18 && cooling > 40
          door[:ref] = ref
        end
      end

      # Loop through point thermal bridges.
      surface[:pts].map { |i, pt| pt[:ref] = 0.5 } if surface.key?(:pts)

      # Loop through linear thermal bridges.
      if surface.key?(:edges)
        surface[:edges].values.each do |edge|
          next unless edge.key?(:type)
          next unless edge.key?(:ratio)

          safe = sets.safe("code (Quebec)", edge[:type])
          edge[:ref] = shorts[:val][safe] * edge[:ratio] if safe
        end
      end
    end

    true
  end

  ##
  # Generates multilingual UA' summary.
  #
  # @param date [Time] Time stamp
  # @param [Hash] argh TBD arguments
  # @option argh [#to_s] :seed OpenStudio file, e.g. "school23.osm"
  # @option argh [#to_s] :ua_ref reference ruleset e.g. "code (Quebec)"
  # @option argh [Hash] :surfaces set of TBD surfaces (see )
  # @option argh [#to_s] :version OpenStudio SDK, e.g. "3.6.1"
  # @option argh [Hash] :io TBD input/output variables (see TBD JSON schema)
  #
  # @return [Hash] binned values for UA' (see logs if empty)
  def ua_summary(date = Time.now, argh = {})
    mth = "TBD::#{__callee__}"
    cl1 = Time
    cl2 = String
    cl3 = Hash
    ua  = {}
    return mismatch("date", date, cl1, mth, DBG, ua) unless date.is_a?(cl1)
    return mismatch("argh", argh, cl3, mth, DBG, ua) unless argh.is_a?(cl3)

    argh[:seed    ] = ""  unless argh.key?(:seed)
    argh[:ua_ref  ] = ""  unless argh.key?(:ua_ref)
    argh[:surfaces] = nil unless argh.key?(:surfaces)
    argh[:version ] = ""  unless argh.key?(:version)
    argh[:io      ] = {}  unless argh.key?(:io)

    file = argh[:seed    ]
    ref  = argh[:ua_ref  ]
    s    = argh[:surfaces]
    v    = argh[:version ]
    io   = argh[:io      ]
    return mismatch(    "seed", file, cl2, mth, DBG, ua) unless file.is_a?(cl2)
    return mismatch( "UA' ref",  ref, cl2, mth, DBG, ua) unless ref.is_a?(cl2)
    return mismatch( "version",    v, cl2, mth, DBG, ua) unless v.is_a?(cl2)
    return mismatch("surfaces",    s, cl3, mth, DBG, ua) unless s.is_a?(cl3)
    return mismatch(      "io",   io, cl3, mth, DBG, ua) unless io.is_a?(cl3)
    return empty(   "surfaces",            mth, WRN, ua)     if s.empty?

    argh[:io][:description] = ""  unless argh[:io].key?(:description)
    descr = argh[:io][:description]

    ua[:descr  ] = ""
    ua[:file   ] = ""
    ua[:version] = ""
    ua[:model  ] = "∑U•A + ∑PSI•L + ∑KHI•n"
    ua[:date   ] = date
    ua[:descr  ] = descr unless descr.nil? || descr.empty?
    ua[:file   ] = file  unless file.nil?  || file.empty?
    ua[:version] = v     unless v.nil?     || v.empty?

    [:en, :fr].each { |lang| ua[lang] = {} }

    ua[:en][:notes] = "Automated assessment from the OpenStudio Measure, "\
      "Thermal Bridging and Derating (TBD). Open source and MIT-licensed, "\
      "TBD is provided as is (without warranty). Procedures are documented "\
      "in the source code: https://github.com/rd2/tbd. "

    ua[:fr][:notes] = "Analyse automatisée à partir de la measure "\
      "OpenStudio, 'Thermal Bridging and Derating' (ou TBD). Distribuée "\
      "librement (licence MIT), TBD est offerte telle quelle (sans "\
      "garantie). L'approche est documentée au sein du code source : "\
      "https://github.com/rd2/tbd."

    walls  = { net: 0, gross: 0, subs: 0 }
    roofs  = { net: 0, gross: 0, subs: 0 }
    floors = { net: 0, gross: 0, subs: 0 }
    areas  = { walls: walls, roofs: roofs, floors: floors }
    has    = {}
    val    = {}
    psi    = PSI.new

    unless ref.empty?
      shorts = psi.shorthands(ref)
      empty  = shorts[:has].empty? && shorts[:val].empty?
      has    = shorts[:has]                      unless empty
      val    = shorts[:val]                      unless empty
      log(ERR, "Invalid UA' reference set (#{mth})") if empty

      unless empty
        ua[:model] += " : Design vs '#{ref}'"

        case ref
        when "code (Quebec)"
          ua[:en][:objective] = "COMPLIANCE ASSESSMENT"
          ua[:en][:details  ] = []
          ua[:en][:details  ] << "Quebec Construction Code, Chapter I.1"
          ua[:en][:details  ] << "NECB 2015, modified version (2020)"
          ua[:en][:details  ] << "Division B, Section 3.3"
          ua[:en][:details  ] << "Building Envelope Trade-off Path"

          ua[:en][:notes] << " Calculations comply with Section 3.3 "\
            "requirements. Results are based on user input not subject to "\
            "prior validation (see DESCRIPTION), and as such the assessment "\
            "shall not be considered as a certification of compliance."

          ua[:fr][:objective] = "ANALYSE DE CONFORMITÉ"
          ua[:fr][:details  ] = []
          ua[:fr][:details  ] << "Code de construction du Québec, Chapitre I.1"
          ua[:fr][:details  ] << "CNÉB 2015, version modifiée (2020)"
          ua[:fr][:details  ] << "Division B, Section 3.3"
          ua[:fr][:details  ] << "Méthode des solutions de remplacement"

          ua[:fr][:notes] << " Les calculs sont conformes aux dispositions "\
            "de la Section 3.3. Les résultats sont tributaires d'intrants "\
            "fournis par l'utilisateur, sans validation préalable (voir "\
            "DESCRIPTION). Ce document ne peut constituer une attestation de "\
            "conformité."
        else
          ua[:en][:objective] = "UA'"
          ua[:fr][:objective] = "UA'"
        end
      end
    end

    # Set up 2x heating setpoint (HSTP) "blocks" (or bins):
    #   bloc1: spaces/zones with HSTP >= 18°C
    #   bloc2: spaces/zones with HSTP < 18°C
    #   (ref: 2021 Quebec energy code 3.3. UA' trade-off methodology)
    #   (... can be extended in the future to cover other standards)
    #
    # Determine UA' compliance separately for (i) bloc1 & (ii) bloc2.
    #
    # Each block's UA' = ∑ U•area + ∑ PSI•length + ∑ KHI•count
    blc = { walls:   0, roofs:     0, floors:    0, doors:     0,
            windows: 0, skylights: 0, rimjoists: 0, parapets:  0,
            trim:    0, corners:   0, balconies: 0, grade:     0,
            other:   0 } # party edges, expansion joints, spandrel edges, etc.

    b1       = {}
    b2       = {}
    b1[:pro] = blc       #  proposed design
    b1[:ref] = blc.clone #        reference
    b2[:pro] = blc.clone #  proposed design
    b2[:ref] = blc.clone #        reference

    # Loop through surfaces, subsurfaces and edges and populate bloc1 & bloc2.
    s.each do |id, surface|
      next unless surface.key?(:deratable)
      next unless surface[:deratable]
      next unless surface.key?(:type)

      type = surface[:type]
      next unless [:wall, :ceiling, :floor].include?(type)
      next unless surface.key?(:net)
      next unless surface[:net] > TOL
      next unless surface.key?(:u)
      next unless surface[:u] > TOL

      heating   = 21.0
      heating   = surface[:heating] if surface.key?(:heating)
      bloc      = b1
      bloc      = b2 if heating < 18
      reference = surface.key?(:ref)

      if type == :wall
        areas[:walls][:net ] += surface[:net]
        bloc[:pro][:walls  ] += surface[:net] * surface[:u  ]
        bloc[:ref][:walls  ] += surface[:net] * surface[:ref]     if reference
        bloc[:ref][:walls  ] += surface[:net] * surface[:u  ] unless reference
      elsif type == :ceiling
        areas[:roofs][:net ] += surface[:net]
        bloc[:pro][:roofs  ] += surface[:net] * surface[:u  ]
        bloc[:ref][:roofs  ] += surface[:net] * surface[:ref]     if reference
        bloc[:ref][:roofs  ] += surface[:net] * surface[:u  ] unless reference
      else
        areas[:floors][:net] += surface[:net]
        bloc[:pro][:floors ] += surface[:net] * surface[:u  ]
        bloc[:ref][:floors ] += surface[:net] * surface[:ref]     if reference
        bloc[:ref][:floors ] += surface[:net] * surface[:u  ] unless reference
      end

      [:doors, :windows, :skylights].each do |subs|
        next unless surface.key?(subs)

        surface[subs].values.each do |sub|
          next unless sub.key?(:gross)
          next unless sub.key?(:u    )
          next unless sub[:gross] > TOL
          next unless sub[:u    ] > TOL

          gross  = sub[:gross]
          gross *= sub[:mult ]                           if sub.key?(:mult)
          areas[:walls ][:subs] += gross                 if type == :wall
          areas[:roofs ][:subs] += gross                 if type == :ceiling
          areas[:floors][:subs] += gross                 if type == :floor
          bloc[:pro    ][subs ] += gross * sub[:u  ]
          bloc[:ref    ][subs ] += gross * sub[:ref]     if sub.key?(:ref)
          bloc[:ref    ][subs ] += gross * sub[:u  ] unless sub.key?(:ref)
        end
      end

      if surface.key?(:edges)
        surface[:edges].values.each do |edge|
          next unless edge.key?(:type)
          next unless edge.key?(:length)
          next unless edge[:length] > TOL
          next unless edge.key?(:psi)

          loss = edge[:length] * edge[:psi]
          type = edge[:type].to_s.downcase

          if edge[:type].to_s.downcase.include?("balcony")
            bloc[:pro][:balconies] += loss
          elsif edge[:type].to_s.downcase.include?("door")
            bloc[:pro][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("skylight")
            bloc[:pro][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("fenestration")
            bloc[:pro][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("head")
            bloc[:pro][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("sill")
            bloc[:pro][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("jamb")
            bloc[:pro][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("rimjoist")
            bloc[:pro][:rimjoists] += loss
          elsif edge[:type].to_s.downcase.include?("parapet")
            bloc[:pro][:parapets ] += loss
          elsif edge[:type].to_s.downcase.include?("roof")
            bloc[:pro][:parapets ] += loss
          elsif edge[:type].to_s.downcase.include?("corner")
            bloc[:pro][:corners  ] += loss
          elsif edge[:type].to_s.downcase.include?("grade")
            bloc[:pro][:grade    ] += loss
          else
            bloc[:pro][:other    ] += loss
          end

          next if val.empty?
          next if ref.empty?

          safer = psi.safe(ref, edge[:type])
          ok    = edge.key?(:ref)
          loss  = edge[:length] * edge[:ref]                    if ok
          loss  = edge[:length] * val[safer] * edge[:ratio] unless ok

          if edge[:type].to_s.downcase.include?("balcony")
            bloc[:ref][:balconies] += loss
          elsif edge[:type].to_s.downcase.include?("door")
            bloc[:ref][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("skylight")
            bloc[:ref][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("fenestration")
            bloc[:ref][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("head")
            bloc[:ref][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("sill")
            bloc[:ref][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("jamb")
            bloc[:ref][:trim     ] += loss
          elsif edge[:type].to_s.downcase.include?("rimjoist")
            bloc[:ref][:rimjoists] += loss
          elsif edge[:type].to_s.downcase.include?("parapet")
            bloc[:ref][:parapets ] += loss
          elsif edge[:type].to_s.downcase.include?("roof")
            bloc[:ref][:parapets ] += loss
          elsif edge[:type].to_s.downcase.include?("corner")
            bloc[:ref][:corners  ] += loss
          elsif edge[:type].to_s.downcase.include?("grade")
            bloc[:ref][:grade    ] += loss
          else
            bloc[:ref][:other    ] += loss
          end
        end
      end

      if surface.key?(:pts)
        surface[:pts].values.each do |pts|
          next unless pts.key?(:val)
          next unless pts.key?(:n)

          bloc[:pro][:other] += pts[:val] * pts[:n]
          next unless pts.key?(:ref)

          bloc[:ref][:other] += pts[:ref] * pts[:n]
        end
      end
    end

    [:en, :fr].each do |lang|
      blc = [:b1, :b2]

      blc.each do |b|
        bloc    = b1
        bloc    = b2 if b == :b2
        pro_sum = bloc[:pro].values.reduce(:+)
        ref_sum = bloc[:ref].values.reduce(:+)

        if pro_sum > TOL || ref_sum > TOL
          ratio = nil
          ratio = (100.0 * (pro_sum - ref_sum) / ref_sum).abs if ref_sum > TOL
          str   = format("%.1f W/K (vs %.1f W/K)", pro_sum, ref_sum)
          str  += format(" +%.1f%%", ratio) if ratio && pro_sum > ref_sum # **
          str  += format(" -%.1f%%", ratio) if ratio && pro_sum < ref_sum
          ua[lang][b] = {}

          if b == :b1
            ua[:en][b][:summary] = "heated : #{str}"       if lang == :en
            ua[:fr][b][:summary] = "chauffé : #{str}"      if lang == :fr
          else
            ua[:en][b][:summary] = "semi-heated : #{str}"  if lang == :en
            ua[:fr][b][:summary] = "semi-chauffé : #{str}" if lang == :fr
          end

          bloc[:pro].each do |k, v|
            rf = bloc[:ref][k]
            next if v < TOL && rf < TOL
            ratio = nil
            ratio = (100.0 * (v - rf) / rf).abs            if rf > TOL
            str   = format("%.1f W/K (vs %.1f W/K)", v, rf)
            str  += format(" +%.1f%%", ratio)              if ratio && v > rf
            str  += format(" -%.1f%%", ratio)              if ratio && v < rf

            case k
            when :walls
              ua[:en][b][k] = "walls : #{str}"             if lang == :en
              ua[:fr][b][k] = "murs : #{str}"              if lang == :fr
            when :roofs
              ua[:en][b][k] = "roofs : #{str}"             if lang == :en
              ua[:fr][b][k] = "toits : #{str}"             if lang == :fr
            when :floors
              ua[:en][b][k] = "floors : #{str}"            if lang == :en
              ua[:fr][b][k] = "planchers : #{str}"         if lang == :fr
            when :doors
              ua[:en][b][k] = "doors : #{str}"             if lang == :en
              ua[:fr][b][k] = "portes : #{str}"            if lang == :fr
            when :windows
              ua[:en][b][k] = "windows : #{str}"           if lang == :en
              ua[:fr][b][k] = "fenêtres : #{str}"          if lang == :fr
            when :skylights
              ua[:en][b][k] = "skylights : #{str}"         if lang == :en
              ua[:fr][b][k] = "lanterneaux : #{str}"       if lang == :fr
            when :rimjoists
              ua[:en][b][k] = "rimjoists : #{str}"         if lang == :en
              ua[:fr][b][k] = "rives : #{str}"             if lang == :fr
            when :parapets
              ua[:en][b][k] = "parapets : #{str}"          if lang == :en
              ua[:fr][b][k] = "parapets : #{str}"          if lang == :fr
            when :trim
              ua[:en][b][k] = "trim : #{str}"              if lang == :en
              ua[:fr][b][k] = "chassis : #{str}"           if lang == :fr
            when :corners
              ua[:en][b][k] = "corners : #{str}"           if lang == :en
              ua[:fr][b][k] = "coins : #{str}"             if lang == :fr
            when :balconies
              ua[:en][b][k] = "balconies : #{str}"         if lang == :en
              ua[:fr][b][k] = "balcons : #{str}"           if lang == :fr
            when :grade
              ua[:en][b][k] = "grade : #{str}"             if lang == :en
              ua[:fr][b][k] = "tracé : #{str}"             if lang == :fr
            else
              ua[:en][b][k] = "other : #{str}"             if lang == :en
              ua[:fr][b][k] = "autres : #{str}"            if lang == :fr
            end
          end

          # Deterministic sorting.
          ua[lang][b][:summary] = ua[lang][b].delete(:summary)

          ua[lang][b].keys.each { |k| ua[lang][b][k] = ua[lang][b].delete(k) }
        end
      end
    end

    # Areas (m2).
    areas[:walls ][:gross] = areas[:walls ][:net] + areas[:walls ][:subs]
    areas[:roofs ][:gross] = areas[:roofs ][:net] + areas[:roofs ][:subs]
    areas[:floors][:gross] = areas[:floors][:net] + areas[:floors][:subs]

    ua[:en][:areas] = {}
    ua[:fr][:areas] = {}

    str  = format("walls : %.1f m2 (net)", areas[:walls][:net])
    str += format(", %.1f m2 (gross)", areas[:walls][:gross])
    ua[:en][:areas][:walls]  = str unless areas[:walls ][:gross] < TOL

    str  = format("roofs : %.1f m2 (net)", areas[:roofs][:net])
    str += format(", %.1f m2 (gross)", areas[:roofs][:gross])
    ua[:en][:areas][:roofs]  = str unless areas[:roofs ][:gross] < TOL

    str  = format("floors : %.1f m2 (net)", areas[:floors][:net])
    str += format(", %.1f m2 (gross)", areas[:floors][:gross])
    ua[:en][:areas][:floors] = str unless areas[:floors][:gross] < TOL

    str  = format("murs : %.1f m2 (net)", areas[:walls][:net])
    str += format(", %.1f m2 (brut)", areas[:walls][:gross])
    ua[:fr][:areas][:walls]  = str unless areas[:walls ][:gross] < TOL

    str  = format("toits : %.1f m2 (net)", areas[:roofs][:net])
    str += format(", %.1f m2 (brut)", areas[:roofs][:gross])
    ua[:fr][:areas][:roofs]  = str unless areas[:roofs ][:gross] < TOL

    str  = format("planchers : %.1f m2 (net)", areas[:floors][:net])
    str += format(", %.1f m2 (brut)", areas[:floors][:gross])
    ua[:fr][:areas][:floors] = str unless areas[:floors][:gross] < TOL

    ua
  end

  ##
  # Generates MD-formatted, UA' summary file.
  #
  # @param [#key?] ua preprocessed collection of UA-related strings
  # option ua [#to_s] :objective ua[lang][:objective] = "COMPLIANCE [...]"
  # option ua [#&] :details ua[lang][:details] = "QC Energy Code [...]"
  # option ua [#to_s] :model "∑U•A + ∑PSI•L + ∑KHI•n [...]"
  # option ua [#key?] :b1 TB block of CONDITIONED spaces, ua[lang][:b1]
  # option ua [#key?] :b2 TB block of SEMIHEATED spaces, ua[lang][:b2]
  # option ua [#to_s] :descr user-provided project/summary description
  # option ua [#to_s] :file OpenStudio file, e.g. "school23.osm"
  # option ua [#to_s] :version OpenStudio SDK, e.g. "3.6.1"
  # option ua [Time] :date time signature
  # option ua [#to_s] :notes advisory info, ua[lang][:notes]
  # option ua [#key?] :areas binned areas (String), ua[lang][:areas][:walls]
  # @param lang [#to_sym] selected language, :en or :fr
  #
  # @return [Array<String>] MD-formatted strings (see logs if empty)
  def ua_md(ua = {}, lang = :en)
    mth    = "TBD::#{__callee__}"
    report = []
    ck1    = ua.respond_to?(:key?)
    ck2    = lang.respond_to?(:to_sym)
    return mismatch(  "ua",   ua,   Hash, mth, DBG, report) unless ck1
    return mismatch("lang", lang, Symbol, mth, DBG, report) unless ck2

    lang = lang.to_sym
    return hashkey("language", ua, lang, mth, DBG, report) unless ua.key?(lang)
    return empty("ua"                  , mth, DBG, report)     if ua.empty?

    if ua[lang].key?(:objective) && ua[lang][:objective].respond_to?(:to_s)
      report << "# #{ua[lang][:objective].to_s}   "
      report << "   "
    end

    if ua[lang].key?(:details) && ua[lang][:details].respond_to?(:&)
      ua[lang][:details].each do |d|
        report << "#{d.to_s}   " if d.respond_to?(:to_s)
      end

      report << "   "
    end

    if ua.key?(:model) && ua[:model].respond_to?(:to_s)
      report << "##### SUMMARY   "   if lang == :en
      report << "##### SOMMAIRE   "  if lang == :fr
      report << "   "
      report << "#{ua[:model].to_s}   "
      report << "   "
    end

    if ua[lang].key?(:b1) && ua[lang][:b1].key?(:summary)
      last = ua[lang][:b1].keys.to_a.last
      report << "* #{ua[lang][:b1][:summary]}"

      ua[lang][:b1].each do |k, v|
        next                     if k == :summary
        report << "  * #{v}" unless k == last
        report << "  * #{v}   "  if k == last
        report << "   "          if k == last
      end
      report << "   "
    end

    if ua[lang].key?(:b2) && ua[lang][:b2].key?(:summary)
      last = ua[lang][:b2].keys.to_a.last
      report << "* #{ua[lang][:b2][:summary]}"

      ua[lang][:b2].each do |k, v|
        next                      if k == :summary
        report << "  * #{v}"  unless k == last
        report << "  * #{v}   "   if k == last
        report << "   "           if k == last
      end
      report << "   "
    end

    if ua.key?(:date)
      report << "##### DESCRIPTION   "
      report << "   "
      report << "* project : #{ua[:descr]}" if ua.key?(:descr) && lang == :en
      report << "* projet : #{ua[:descr]}"  if ua.key?(:descr) && lang == :fr
      model  = ""
      model  = "* model : #{ua[:file]}"     if ua.key?(:file)  && lang == :en
      model  = "* modèle : #{ua[:file]}"    if ua.key?(:file)  && lang == :fr
      model += " (v#{ua[:version]})"        if ua.key?(:version)
      report << model                   unless model.empty?
      report << "* TBD : v3.4.2"
      report << "* date : #{ua[:date]}"

      if lang == :en
        report << "* status : #{msg(status)}" unless status.zero?
        report << "* status : success !"          if status.zero?
      elsif lang == :fr
        report << "* statut : #{msg(status)}" unless status.zero?
        report << "* statut : succès !"           if status.zero?
      end
      report << "   "
    end

    if ua[lang].key?(:areas)
      report << "##### AREAS   " if lang == :en
      report << "##### AIRES   " if lang == :fr
      report << "   "
      ok = ua[lang][:areas].key?(:walls)
      report << "* #{ua[lang][:areas][:walls]}"  if ok
      ok = ua[lang][:areas].key?(:roofs)
      report << "* #{ua[lang][:areas][:roofs]}"  if ok
      ok = ua[lang][:areas].key?(:floors)
      report << "* #{ua[lang][:areas][:floors]}" if ok
      report << "   "
    end

    if ua[lang].key?(:notes)
      report << "##### NOTES   "
      report << "   "
      report << "#{ua[lang][:notes]}   "
      report << "   "
    end

    report
  end
end
