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
  # Sources for thermal bridge types and default KHI- & PSI-factor sets:
  #
  # a) BETBG = Building Envelope Thermal Bridging Guide v1.4 (or newer):
  #
  #   www.bchydro.com/content/dam/BCHydro/customer-portal/documents/power-smart/
  #   business/programs/BETB-Building-Envelope-Thermal-Bridging-Guide-v1-4.pdf
  #
  # b) ISO 14683 (Appendix C): www.iso.org/standard/65706.html
  #
  # c) NECB-QC = Québec's energy code for new commercial buildings:
  #
  #   www2.publicationsduquebec.gouv.qc.ca/dynamicSearch/
  #   telecharge.php?type=1&file=72541.pdf
  #
  #   www.rbq.gouv.qc.ca/domaines-dintervention/efficacite-energetique/
  #   la-formation/autres-batiments-outils-educatifs.html

  ##
  # Library of point thermal bridges (e.g. columns). Each key:value entry
  # requires a unique identifier e.g. "poor (BETBG)" and a KHI-value in W/K.
  class KHI
    extend OSut

    # @return [Hash] KHI library
    attr_reader :point

    ##
    # Constructs a new KHI library (with defaults).
    def initialize
      @point = {}

      # The following are built-in KHI-factors. Users may append new key:value
      # pairs, preferably through a TBD JSON input file. Units are in W/K.
      @point["poor (BETBG)"               ] = 0.900 # detail 5.7.2 BETBG
      @point["regular (BETBG)"            ] = 0.500 # detail 5.7.4 BETBG
      @point["efficient (BETBG)"          ] = 0.150 # detail 5.7.3 BETBG
      @point["code (Quebec)"              ] = 0.500 # art. 3.3.1.3. NECB-QC
      @point["uncompliant (Quebec)"       ] = 1.000 # NECB-QC Guide
      @point["90.1.22|steel.m|default"    ] = 0.480 # steel/metal, compliant
      @point["90.1.22|steel.m|unmitigated"] = 0.920 # steel/metal, non-compliant
      @point["90.1.22|mass.ex|default"    ] = 0.330 # ext/integral, compliant
      @point["90.1.22|mass.ex|unmitigated"] = 0.460 # ext/integral, non-compliant
      @point["90.1.22|mass.in|default"    ] = 0.330 # interior mass, compliant
      @point["90.1.22|mass.in|unmitigated"] = 0.460 # interior, non-compliant
      @point["90.1.22|wood.fr|default"    ] = 0.040 # compliant
      @point["90.1.22|wood.fr|unmitigated"] = 0.330 # non-compliant
      @point["(non thermal bridging)"     ] = 0.000 # defaults to 0
    end

    ##
    # Appends a new KHI entry.
    #
    # @param [Hash] k a new KHI entry
    # @option k [#to_s] :id name
    # @option k [#to_f] :point conductance, in W/K
    #
    # @return [Bool] whether KHI entry is successfully appended
    # @return [false] if invalid input (see logs)
    def append(k = {})
      mth = "TBD::#{__callee__}"
      a   = false
      ck1 = k.respond_to?(:key?)
      return mismatch("KHI"     , k, Hash  , mth, DBG, a) unless ck1
      return hashkey("KHI id"   , k, :id   , mth, DBG, a) unless k.key?(:id)
      return hashkey("KHI point", k, :point, mth, DBG, a) unless k.key?(:point)

      id = trim(k[:id])
      ck1 = id.empty?
      ck2 = k[:point].respond_to?(:to_f)
      return mismatch("KHI id"   , k[:id   ], String, mth, ERR, a)     if ck1
      return mismatch("KHI point", k[:point], Float , mth, ERR, a) unless ck2

      if @point.key?(id)
        log(ERR, "Skipping '#{id}': existing KHI entry (#{mth})")
        return false
      end

      @point[id] = k[:point].to_f

      true
    end
  end

  ##
  # Library of linear thermal bridges (e.g. corners, balconies). Each key:value
  # entry requires a unique identifier e.g. "poor (BETBG)" and a (partial or
  # complete) set of PSI-factors in W/K per linear meter.
  class PSI
    extend OSut

    # @return [Hash] PSI set
    attr_reader :set

    # @return [Hash] shorthand listing of PSI types in a set
    attr_reader :has

    # @return [Hash] shorthand listing of PSI-factors in a set
    attr_reader :val

    ##
    # Constructs a new PSI library (with defaults)
    def initialize
      @set = {}
      @has = {}
      @val = {}

      # The following are built-in PSI-factor sets, more often predefined sets
      # published in guides or energy codes. Users may append new sets,
      # preferably through a TBD JSON input file. Units are in W/K per meter.
      #
      # The provided "spandrel" sets are suitable for early design.
      #
      # Convex vs concave PSI adjustments may be warranted if there is a
      # mismatch between dimensioning conventions (interior vs exterior) used
      # for the OpenStudio model vs published PSI data. For instance, the BETBG
      # data reflects an interior dimensioning convention, while ISO 14683
      # reports PSI-factors for both conventions. The following may be used
      # (with caution) to adjust BETBG PSI-factors for convex corners when
      # using outside dimensions for an OpenStudio model.
      #
      # PSIe = PSIi + U * 2(Li-Le), where:
      #   PSIe = adjusted PSI W/K per m
      #   PSIi = initial published PSI, in W/K per m
      #      U = average clear field U-factor of adjacent walls, in W/m2•K
      #     Li = 'interior corner to edge' length of "zone of influence", in m
      #     Le = 'exterior corner to edge' length of "zone of influence", in m
      #
      #  Li-Le = wall thickness e.g., -0.25m (negative here as Li < Le)

      # Based on INTERIOR dimensioning (p.15 BETBG).
      @set["poor (BETBG)"] =
      {
        rimjoist:        1.000000, # re: BETBG
        parapet:         0.800000, # re: BETBG
        roof:            0.800000, # same as parapet
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.500000, # re: BETBG
        door:            0.500000, # inferred, same as (vertical) fenestration
        skylight:        0.500000, # inferred, same as (vertical) fenestration
        spandrel:        0.155000, # Detail 5.4.4
        corner:          0.850000, # re: BETBG
        balcony:         1.000000, # re: BETBG
        balconysill:     1.000000, # same as balcony
        balconydoorsill: 1.000000, # same as balconysill
        party:           0.850000, # re: BETBG
        grade:           0.850000, # re: BETBG
        joint:           0.300000, # re: BETBG
        transition:      0.000000  # defaults to 0
      }.freeze

      # Based on INTERIOR dimensioning (p.15 BETBG).
      @set["regular (BETBG)"] =
      {
        rimjoist:        0.500000, # re: BETBG
        parapet:         0.450000, # re: BETBG
        roof:            0.450000, # same as parapet
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.350000, # re: BETBG
        door:            0.350000, # inferred, same as (vertical) fenestration
        skylight:        0.350000, # inferred, same as (vertical) fenestration
        spandrel:        0.155000, # Detail 5.4.4
        corner:          0.450000, # re: BETBG
        balcony:         0.500000, # re: BETBG
        balconysill:     0.500000, # same as balcony
        balconydoorsill: 0.500000, # same as balconysill
        party:           0.450000, # re: BETBG
        grade:           0.450000, # re: BETBG
        joint:           0.200000, # re: BETBG
        transition:      0.000000  # defaults to 0
      }.freeze

      # Based on INTERIOR dimensioning (p.15 BETBG).
      @set["efficient (BETBG)"] =
      {
        rimjoist:        0.200000, # re: BETBG
        parapet:         0.200000, # re: BETBG
        roof:            0.200000, # same as parapet
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.199999, # re: BETBG
        door:            0.199999, # inferred, same as (vertical) fenestration
        skylight:        0.199999, # inferred, same as (vertical) fenestration
        spandrel:        0.155000, # Detail 5.4.4
        corner:          0.200000, # re: BETBG
        balcony:         0.200000, # re: BETBG
        balconysill:     0.200000, # same as balcony
        balconydoorsill: 0.200000, # same as balconysill
        party:           0.200000, # re: BETBG
        grade:           0.200000, # re: BETBG
        joint:           0.100000, # re: BETBG
        transition:      0.000000  # defaults to 0
      }.freeze

      # "Conventional", closer to window wall spandrels.
      @set["spandrel (BETBG)"] =
      {
        rimjoist:        0.615000, # Detail 1.2.1
        parapet:         1.000000, # Detail 1.3.2
        roof:            1.000000, # same as parapet
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.000000, # inferred, generally part of clear-field RSi
        door:            0.000000, # inferred, generally part of clear-field RSi
        skylight:        0.350000, # same as "regular (BETBG)"
        spandrel:        0.155000, # Detail 5.4.4
        corner:          0.425000, # Detail 1.4.1
        balcony:         1.110000, # Detail 8.1.9/9.1.6
        balconysill:     1.110000, # same as balcony
        balconydoorsill: 1.110000, # same as balconysill
        party:           0.990000, # inferred, similar to parapet/balcony
        grade:           0.880000, # Detail 2.5.1
        joint:           0.500000, # Detail 3.3.2
        transition:      0.000000  # defaults to 0
      }.freeze

      # "GoodHigh performance" curtainwall spandrels.
      @set["spandrel HP (BETBG)"] =
      {
        rimjoist:        0.170000, # Detail 1.2.7
        parapet:         0.660000, # Detail 1.3.2
        roof:            0.660000, # same as parapet
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.000000, # inferred, generally part of clear-field RSi
        door:            0.000000, # inferred, generally part of clear-field RSi
        skylight:        0.350000, # same as "regular (BETBG)"
        spandrel:        0.155000, # Detail 5.4.4
        corner:          0.200000, # Detail 1.4.2
        balcony:         0.400000, # Detail 9.1.15
        balconysill:     0.400000, # same as balcony
        balconydoorsill: 0.400000, # same as balconysill
        party:           0.500000, # inferred, similar to parapet/balcony
        grade:           0.880000, # Detail 2.5.1
        joint:           0.140000, # Detail 7.4.2
        transition:      0.000000  # defaults to 0
      }.freeze

      # CCQ, Chapitre I1, code-compliant defaults.
      @set["code (Quebec)"] =
      {
        rimjoist:        0.300000, # re I1
        parapet:         0.325000, # re I1
        roof:            0.325000, # same as parapet
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.200000, # re I1
        door:            0.200000, # re I1
        skylight:        0.200000, # re I1
        spandrel:        0.155000, # BETBG Detail 5.4.4 (same as uncompliant)
        corner:          0.300000, # inferred from description, not explicitely set
        balcony:         0.500000, # re I1
        balconysill:     0.500000, # same as balcony
        balconydoorsill: 0.500000, # same as balconysill
        party:           0.450000, # re I1
        grade:           0.450000, # re I1
        joint:           0.200000, # re I1
        transition:      0.000000  # defaults to 0
      }.freeze

      # CCQ, Chapitre I1, non-code-compliant defaults.
      @set["uncompliant (Quebec)"] =
      {
        rimjoist:        0.850000, # re I1
        parapet:         0.800000, # re I1
        roof:            0.800000, # same as parapet
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.500000, # re I1
        door:            0.500000, # re I1
        skylight:        0.500000, # re I1
        spandrel:        0.155000, # BETBG Detail 5.4.4 (same as compliant)
        corner:          0.850000, # inferred from description, not explicitely set
        balcony:         1.000000, # re I1
        balconysill:     1.000000, # same as balcony
        balconydoorsill: 1.000000, # same as balconysill
        party:           0.850000, # re I1
        grade:           0.850000, # re I1
        joint:           0.500000, # re I1
        transition:      0.000000  # defaults to 0
      }.freeze

      # ASHRAE 90.1 2022 (A10) "default" steel-framed and metal buildings.
      @set["90.1.22|steel.m|default"] =
      {
        rimjoist:        0.307000, # "intermediate floor to wall intersection"
        parapet:         0.260000, # "parapet" edge
        roof:            0.020000, # (non-parapet) "roof" edge
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.194000, # "wall to vertical fenestration intersection"
        door:            0.000000, # (unspecified, defaults to 0)
        skylight:        0.000000, # (unspecified, defaults to 0)
        spandrel:        0.000001, # (unspecified, defaults to 0)
        corner:          0.000002, # (unspecified, defaults to 0)
        balcony:         0.307000, # "intermediate floor balcony/overhang" edge
        balconysill:     0.307000, # "intermediate floor balcony" edge (when sill)
        balconydoorsill: 0.307000, # same as balcony
        party:           0.000001, # (unspecified, defaults to 0)
        grade:           0.000001, # (unspecified, defaults to 0)
        joint:           0.376000, # placeholder for "cladding support"
        transition:      0.000000  # defaults to 0
      }.freeze

      # ASHRAE 90.1 2022 (A10) "unmitigated" steel-framed and metal buildings.
      @set["90.1.22|steel.m|unmitigated"] =
      {
        rimjoist:        0.842000, # "intermediate floor to wall intersection"
        parapet:         0.500000, # "parapet" edge
        roof:            0.650000, # (non-parapet) "roof" edge
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.505000, # "wall to vertical fenestration intersection"
        door:            0.000000, # (unspecified, defaults to 0)
        skylight:        0.000000, # (unspecified, defaults to 0)
        spandrel:        0.000001, # (unspecified, defaults to 0)
        corner:          0.000002, # (unspecified, defaults to 0)
        balcony:         0.842000, # "intermediate floor balcony/overhang" edge
        balconysill:     1.686000, # "intermediate floor balcony" edge (when sill)
        balconydoorsill: 0.842000, # same as balcony
        party:           0.000001, # (unspecified, defaults to 0)
        grade:           0.000001, # (unspecified, defaults to 0)
        joint:           0.554000, # placeholder for "cladding support"
        transition:      0.000000  # defaults to 0
      }.freeze

      # ASHRAE 90.1 2022 (A10) "default" exterior/integral mass walls.
      @set["90.1.22|mass.ex|default"] =
      {
        rimjoist:        0.205000, # "intermediate floor to wall intersection"
        parapet:         0.217000, # "parapet" edge
        roof:            0.150000, # (non-parapet) "roof" edge
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.226000, # "wall to vertical fenestration intersection"
        door:            0.000000, # (unspecified, defaults to 0)
        skylight:        0.000000, # (unspecified, defaults to 0)
        spandrel:        0.000001, # (unspecified, defaults to 0)
        corner:          0.000002, # (unspecified, defaults to 0)
        balcony:         0.205000, # "intermediate floor balcony/overhang" edge
        balconysill:     0.307000, # "intermediate floor balcony" edge (when sill)
        balconydoorsill: 0.205000, # same as balcony
        party:           0.000001, # (unspecified, defaults to 0)
        grade:           0.000001, # (unspecified, defaults to 0)
        joint:           0.322000, # placeholder for "cladding support"
        transition:      0.000000  # defaults to 0
      }.freeze

      # ASHRAE 90.1 2022 (A10) "unmitigated" exterior/integral mass walls.
      @set["90.1.22|mass.ex|unmitigated"] =
      {
        rimjoist:        0.824000, # "intermediate floor to wall intersection"
        parapet:         0.412000, # "parapet" edge
        roof:            0.750000, # (non-parapet) "roof" edge
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.325000, # "wall to vertical fenestration intersection"
        door:            0.000000, # (unspecified, defaults to 0)
        skylight:        0.000000, # (unspecified, defaults to 0)
        spandrel:        0.000001, # (unspecified, defaults to 0)
        corner:          0.000002, # (unspecified, defaults to 0)
        balcony:         0.824000, # "intermediate floor balcony/overhang" edge
        balconysill:     1.686000, # "intermediate floor balcony" edge (when sill)
        balconydoorsill: 0.824000, # same as balcony
        party:           0.000001, # (unspecified, defaults to 0)
        grade:           0.000001, # (unspecified, defaults to 0)
        joint:           0.476000, # placeholder for "cladding support"
        transition:      0.000000  # defaults to 0
      }.freeze

      # ASHRAE 90.1 2022 (A10) "default" interior mass walls.
      @set["90.1.22|mass.in|default"] =
      {
        rimjoist:        0.495000, # "intermediate floor to wall intersection"
        parapet:         0.393000, # "parapet" edge
        roof:            0.150000, # (non-parapet) "roof" edge
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.143000, # "wall to vertical fenestration intersection"
        door:            0.000000, # (unspecified, defaults to 0)
        skylight:        0.000000, # (unspecified, defaults to 0)
        spandrel:        0.000000, # (unspecified, defaults to 0)
        corner:          0.000001, # (unspecified, defaults to 0)
        balcony:         0.495000, # "intermediate floor balcony/overhang" edge
        balconysill:     0.307000, # "intermediate floor balcony" edge (when sill)
        balconydoorsill: 0.495000, # same as balcony
        party:           0.000001, # (unspecified, defaults to 0)
        grade:           0.000001, # (unspecified, defaults to 0)
        joint:           0.322000, # placeholder for "cladding support"
        transition:      0.000000  # defaults to 0
      }.freeze

      # ASHRAE 90.1 2022 (A10) "unmitigated" interior mass walls.
      @set["90.1.22|mass.in|unmitigated"] =
      {
        rimjoist:        0.824000, # "intermediate floor to wall intersection"
        parapet:         0.884000, # "parapet" edge
        roof:            0.750000, # (non-parapet) "roof" edge
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.543000, # "wall to vertical fenestration intersection"
        door:            0.000000, # (unspecified, defaults to 0)
        skylight:        0.000000, # (unspecified, defaults to 0)
        spandrel:        0.000000, # (unspecified, defaults to 0)
        corner:          0.000001, # (unspecified, defaults to 0)
        balcony:         0.824000, # "intermediate floor balcony/overhang" edge
        balconysill:     1.686000, # "intermediate floor balcony" edge (when sill)
        balconydoorsill: 0.824000, # same as balcony
        party:           0.000001, # (unspecified, defaults to 0)
        grade:           0.000001, # (unspecified, defaults to 0)
        joint:           0.476000, # placeholder for "cladding support"
        transition:      0.000000  # defaults to 0
      }.freeze

      # ASHRAE 90.1 2022 (A10) "default" wood-framed (and other) walls.
      @set["90.1.22|wood.fr|default"] =
      {
        rimjoist:        0.084000, # "intermediate floor to wall intersection"
        parapet:         0.056000, # "parapet" edge
        roof:            0.020000, # (non-parapet) "roof" edge
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.171000, # "wall to vertical fenestration intersection"
        door:            0.000000, # (unspecified, defaults to 0)
        skylight:        0.000000, # (unspecified, defaults to 0)
        spandrel:        0.000000, # (unspecified, defaults to 0)
        corner:          0.000001, # (unspecified, defaults to 0)
        balcony:         0.084000, # "intermediate floor balcony/overhang" edge
        balconysill:     0.171001, # same as :fenestration
        balconydoorsill: 0.084000, # same as balcony
        party:           0.000001, # (unspecified, defaults to 0)
        grade:           0.000001, # (unspecified, defaults to 0)
        joint:           0.074000, # placeholder for "cladding support"
        transition:      0.000000  # defaults to 0
      }.freeze

      # ASHRAE 90.1 2022 (A10) "unmitigated" wood-framed (and other) walls.
      @set["90.1.22|wood.fr|unmitigated"] =
      {
        rimjoist:        0.582000, # "intermediate floor to wall intersection"
        parapet:         0.056000, # "parapet" edge
        roof:            0.150000, # (non-parapet) "roof" edge
        ceiling:         0.000000, # e.g. suspended ceiling tiles
        fenestration:    0.260000, # "wall to vertical fenestration intersection"
        door:            0.000000, # (unspecified, defaults to 0)
        skylight:        0.000000, # (unspecified, defaults to 0)
        spandrel:        0.000000, # (unspecified, defaults to 0)
        corner:          0.000001, # (unspecified, defaults to 0)
        balcony:         0.582000, # same as :rimjoist
        balconysill:     0.582000, # same as :rimjoist
        balconydoorsill: 0.582000, # same as balcony
        party:           0.000001, # (unspecified, defaults to 0)
        grade:           0.000001, # (unspecified, defaults to 0)
        joint:           0.322000, # placeholder for "cladding support"
        transition:      0.000000  # defaults to 0
      }.freeze

      @set["(non thermal bridging)"] =
      {
        rimjoist:        0.000000, # defaults to 0
        parapet:         0.000000, # defaults to 0
        roof:            0.000000, # defaults to 0
        ceiling:         0.000000, # defaults to 0
        fenestration:    0.000000, # defaults to 0
        door:            0.000000, # defaults to 0
        skylight:        0.000000, # defaults to 0
        spandrel:        0.000000, # defaults to 0
        corner:          0.000000, # defaults to 0
        balcony:         0.000000, # defaults to 0
        balconysill:     0.000000, # defaults to 0
        balconydoorsill: 0.000000, # defaults to 0
        party:           0.000000, # defaults to 0
        grade:           0.000000, # defaults to 0
        joint:           0.000000, # defaults to 0
        transition:      0.000000  # defaults to 0
      }.freeze

      @set.keys.each { |k| self.gen(k) }
    end

    ##
    # Generates PSI set shorthand listings.
    #
    # @param id PSI set identifier
    #
    # @return [Bool] whether successful in generating PSI set shorthands
    # @return [false] if invalid input (see logs)
    def gen(id = "")
      mth = "TBD::#{__callee__}"
      return hashkey(id, @set, id, mth, ERR, false) unless @set.key?(id)

      h                          = {} # true/false if PSI set has PSI type
      h[:joint                 ] = @set[id].key?(:joint)
      h[:transition            ] = @set[id].key?(:transition)
      h[:fenestration          ] = @set[id].key?(:fenestration)
      h[:head                  ] = @set[id].key?(:head)
      h[:headconcave           ] = @set[id].key?(:headconcave)
      h[:headconvex            ] = @set[id].key?(:headconvex)
      h[:sill                  ] = @set[id].key?(:sill)
      h[:sillconcave           ] = @set[id].key?(:sillconcave)
      h[:sillconvex            ] = @set[id].key?(:sillconvex)
      h[:jamb                  ] = @set[id].key?(:jamb)
      h[:jambconcave           ] = @set[id].key?(:jambconcave)
      h[:jambconvex            ] = @set[id].key?(:jambconvex)
      h[:door                  ] = @set[id].key?(:door)
      h[:doorhead              ] = @set[id].key?(:doorhead)
      h[:doorheadconcave       ] = @set[id].key?(:doorheadconcave)
      h[:doorheadconvex        ] = @set[id].key?(:doorheadconvex)
      h[:doorsill              ] = @set[id].key?(:doorsill)
      h[:doorsillconcave       ] = @set[id].key?(:doorsillconcave)
      h[:doorsillconvex        ] = @set[id].key?(:doorsillconvex)
      h[:doorjamb              ] = @set[id].key?(:doorjamb)
      h[:doorjambconcave       ] = @set[id].key?(:doorjambconcave)
      h[:doorjambconvex        ] = @set[id].key?(:doorjambconvex)
      h[:skylight              ] = @set[id].key?(:skylight)
      h[:skylighthead          ] = @set[id].key?(:skylighthead)
      h[:skylightheadconcave   ] = @set[id].key?(:skylightheadconcave)
      h[:skylightheadconvex    ] = @set[id].key?(:skylightheadconvex)
      h[:skylightsill          ] = @set[id].key?(:skylightsill)
      h[:skylightsillconcave   ] = @set[id].key?(:skylightsillconcave)
      h[:skylightsillconvex    ] = @set[id].key?(:skylightsillconvex)
      h[:skylightjamb          ] = @set[id].key?(:skylightjamb)
      h[:skylightjambconcave   ] = @set[id].key?(:skylightjambconcave)
      h[:skylightjambconvex    ] = @set[id].key?(:skylightjambconvex)
      h[:spandrel              ] = @set[id].key?(:spandrel)
      h[:spandrelconcave       ] = @set[id].key?(:spandrelconcave)
      h[:spandrelconvex        ] = @set[id].key?(:spandrelconvex)
      h[:corner                ] = @set[id].key?(:corner)
      h[:cornerconcave         ] = @set[id].key?(:cornerconcave)
      h[:cornerconvex          ] = @set[id].key?(:cornerconvex)
      h[:party                 ] = @set[id].key?(:party)
      h[:partyconcave          ] = @set[id].key?(:partyconcave)
      h[:partyconvex           ] = @set[id].key?(:partyconvex)
      h[:parapet               ] = @set[id].key?(:parapet)
      h[:partyconcave          ] = @set[id].key?(:parapetconcave)
      h[:parapetconvex         ] = @set[id].key?(:parapetconvex)
      h[:roof                  ] = @set[id].key?(:roof)
      h[:roofconcave           ] = @set[id].key?(:roofconcave)
      h[:roofconvex            ] = @set[id].key?(:roofconvex)
      h[:ceiling               ] = @set[id].key?(:ceiling)
      h[:ceilingconcave        ] = @set[id].key?(:ceilingconcave)
      h[:ceilingconvex         ] = @set[id].key?(:ceilingconvex)
      h[:grade                 ] = @set[id].key?(:grade)
      h[:gradeconcave          ] = @set[id].key?(:gradeconcave)
      h[:gradeconvex           ] = @set[id].key?(:gradeconvex)
      h[:balcony               ] = @set[id].key?(:balcony)
      h[:balconyconcave        ] = @set[id].key?(:balconyconcave)
      h[:balconyconvex         ] = @set[id].key?(:balconyconvex)
      h[:balconysill           ] = @set[id].key?(:balconysill)
      h[:balconysillconcave    ] = @set[id].key?(:balconysillconvex)
      h[:balconysillconvex     ] = @set[id].key?(:balconysillconvex)
      h[:balconydoorsill       ] = @set[id].key?(:balconydoorsill)
      h[:balconydoorsillconcave] = @set[id].key?(:balconydoorsillconvex)
      h[:balconydoorsillconvex ] = @set[id].key?(:balconydoorsillconvex)
      h[:rimjoist              ] = @set[id].key?(:rimjoist)
      h[:rimjoistconcave       ] = @set[id].key?(:rimjoistconcave)
      h[:rimjoistconvex        ] = @set[id].key?(:rimjoistconvex)
      @has[id]                   = h

      v                   = {} # PSI-value (W/K per linear meter)
      v[:door           ] = 0; v[:fenestration          ] = 0; v[:skylight             ] = 0
      v[:head           ] = 0; v[:headconcave           ] = 0; v[:headconvex           ] = 0
      v[:sill           ] = 0; v[:sillconcave           ] = 0; v[:sillconvex           ] = 0
      v[:jamb           ] = 0; v[:jambconcave           ] = 0; v[:jambconvex           ] = 0
      v[:doorhead       ] = 0; v[:doorheadconcave       ] = 0; v[:doorconvex           ] = 0
      v[:doorsill       ] = 0; v[:doorsillconcave       ] = 0; v[:doorsillconvex       ] = 0
      v[:doorjamb       ] = 0; v[:doorjambconcave       ] = 0; v[:doorjambconvex       ] = 0
      v[:skylighthead   ] = 0; v[:skylightheadconcave   ] = 0; v[:skylightconvex       ] = 0
      v[:skylightsill   ] = 0; v[:skylightsillconcave   ] = 0; v[:skylightsillconvex   ] = 0
      v[:skylightjamb   ] = 0; v[:skylightjambconcave   ] = 0; v[:skylightjambconvex   ] = 0
      v[:spandrel       ] = 0; v[:spandrelconcave       ] = 0; v[:spandrelconvex       ] = 0
      v[:corner         ] = 0; v[:cornerconcave         ] = 0; v[:cornerconvex         ] = 0
      v[:parapet        ] = 0; v[:parapetconcave        ] = 0; v[:parapetconvex        ] = 0
      v[:roof           ] = 0; v[:roofconcave           ] = 0; v[:roofconvex           ] = 0
      v[:ceiling        ] = 0; v[:ceilingconcave        ] = 0; v[:ceilingconvex        ] = 0
      v[:party          ] = 0; v[:partyconcave          ] = 0; v[:partyconvex          ] = 0
      v[:grade          ] = 0; v[:gradeconcave          ] = 0; v[:gradeconvex          ] = 0
      v[:balcony        ] = 0; v[:balconyconcave        ] = 0; v[:balconyconvex        ] = 0
      v[:balconysill    ] = 0; v[:balconysillconcave    ] = 0; v[:balconysillconvex    ] = 0
      v[:balconydoorsill] = 0; v[:balconydoorsillconcave] = 0; v[:balconydoorsillconvex] = 0
      v[:rimjoist       ] = 0; v[:rimjoistconcave       ] = 0; v[:rimjoistconvex       ] = 0
      v[:joint          ] = 0; v[:transition            ] = 0

      v[:joint                 ] = @set[id][:joint                 ] if h[:joint                 ]
      v[:transition            ] = @set[id][:transition            ] if h[:transition            ]
      v[:fenestration          ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:head                  ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:headconcave           ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:headconvex            ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:sill                  ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:sillconcave           ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:sillconvex            ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:jamb                  ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:jambconcave           ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:jambconvex            ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:door                  ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorhead              ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorheadconcave       ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorheadconvex        ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorsill              ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorsillconcave       ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorsillconvex        ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorjamb              ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorjambconcave       ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:doorjambconvex        ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylight              ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylighthead          ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylightheadconcave   ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylightheadconvex    ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylightsill          ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylightsillconcave   ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylightsillconvex    ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylightjamb          ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylightjambconcave   ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:skylightjambconvex    ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:door                  ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorhead              ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorheadconcave       ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorheadconvex        ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorsill              ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorsillconcave       ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorsillconvex        ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorjamb              ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorjambconcave       ] = @set[id][:door                  ] if h[:door                  ]
      v[:doorjambconvex        ] = @set[id][:door                  ] if h[:door                  ]
      v[:skylight              ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylighthead          ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylightheadconcave   ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylightheadconvex    ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylightsill          ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylightsillconcave   ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylightsillconvex    ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylightjamb          ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylightjambconcave   ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:skylightjambconvex    ] = @set[id][:skylight              ] if h[:skylight              ]
      v[:head                  ] = @set[id][:head                  ] if h[:head                  ]
      v[:headconcave           ] = @set[id][:head                  ] if h[:head                  ]
      v[:headconvex            ] = @set[id][:head                  ] if h[:head                  ]
      v[:sill                  ] = @set[id][:sill                  ] if h[:sill                  ]
      v[:sillconcave           ] = @set[id][:sill                  ] if h[:sill                  ]
      v[:sillconvex            ] = @set[id][:sill                  ] if h[:sill                  ]
      v[:jamb                  ] = @set[id][:jamb                  ] if h[:jamb                  ]
      v[:jambconcave           ] = @set[id][:jamb                  ] if h[:jamb                  ]
      v[:jambconvex            ] = @set[id][:jamb                  ] if h[:jamb                  ]
      v[:doorhead              ] = @set[id][:doorhead              ] if h[:doorhead              ]
      v[:doorheadconcave       ] = @set[id][:doorhead              ] if h[:doorhead              ]
      v[:doorheadconvex        ] = @set[id][:doorhead              ] if h[:doorhead              ]
      v[:doorsill              ] = @set[id][:doorsill              ] if h[:doorsill              ]
      v[:doorsillconcave       ] = @set[id][:doorsill              ] if h[:doorsill              ]
      v[:doorsillconvex        ] = @set[id][:doorsill              ] if h[:doorsill              ]
      v[:doorjamb              ] = @set[id][:doorjamb              ] if h[:doorjamb              ]
      v[:doorjambconcave       ] = @set[id][:doorjamb              ] if h[:doorjamb              ]
      v[:doorjambconvex        ] = @set[id][:doorjamb              ] if h[:doorjamb              ]
      v[:skylighthead          ] = @set[id][:skylighthead          ] if h[:skylighthead          ]
      v[:skylightheadconcave   ] = @set[id][:skylighthead          ] if h[:skylighthead          ]
      v[:skylightheadconvex    ] = @set[id][:skylighthead          ] if h[:skylighthead          ]
      v[:skylightsill          ] = @set[id][:skylightsill          ] if h[:skylightsill          ]
      v[:skylightsillconcave   ] = @set[id][:skylightsill          ] if h[:skylightsill          ]
      v[:skylightsillconvex    ] = @set[id][:skylightsill          ] if h[:skylightsill          ]
      v[:skylightjamb          ] = @set[id][:skylightjamb          ] if h[:skylightjamb          ]
      v[:skylightjambconcave   ] = @set[id][:skylightjamb          ] if h[:skylightjamb          ]
      v[:skylightjambconvex    ] = @set[id][:skylightjamb          ] if h[:skylightjamb          ]
      v[:headconcave           ] = @set[id][:headconcave           ] if h[:headconcave           ]
      v[:headconvex            ] = @set[id][:headconvex            ] if h[:headconvex            ]
      v[:sillconcave           ] = @set[id][:sillconcave           ] if h[:sillconcave           ]
      v[:sillconvex            ] = @set[id][:sillconvex            ] if h[:sillconvex            ]
      v[:jambconcave           ] = @set[id][:jambconcave           ] if h[:jambconcave           ]
      v[:jambconvex            ] = @set[id][:jambconvex            ] if h[:jambconvex            ]
      v[:doorheadconcave       ] = @set[id][:doorheadconcave       ] if h[:doorheadconcave       ]
      v[:doorheadconvex        ] = @set[id][:doorheadconvex        ] if h[:doorheadconvex        ]
      v[:doorsillconcave       ] = @set[id][:doorsillconcave       ] if h[:doorsillconcave       ]
      v[:doorsillconvex        ] = @set[id][:doorsillconvex        ] if h[:doorsillconvex        ]
      v[:doorjambconcave       ] = @set[id][:doorjambconcave       ] if h[:doorjambconcave       ]
      v[:doorjambconvex        ] = @set[id][:doorjambconvex        ] if h[:doorjambconvex        ]
      v[:skylightheadconcave   ] = @set[id][:skylightheadconcave   ] if h[:skylightheadconcave   ]
      v[:skylightheadconvex    ] = @set[id][:skylightheadconvex    ] if h[:skylightheadconvex    ]
      v[:skylightsillconcave   ] = @set[id][:skylightsillconcave   ] if h[:skylightsillconcave   ]
      v[:skylightsillconvex    ] = @set[id][:skylightsillconvex    ] if h[:skylightsillconvex    ]
      v[:skylightjambconcave   ] = @set[id][:skylightjambconcave   ] if h[:skylightjambconcave   ]
      v[:skylightjambconvex    ] = @set[id][:skylightjambconvex    ] if h[:skylightjambconvex    ]
      v[:spandrel              ] = @set[id][:spandrel              ] if h[:spandrel              ]
      v[:spandrelconcave       ] = @set[id][:spandrel              ] if h[:spandrel              ]
      v[:spandrelconvex        ] = @set[id][:spandrel              ] if h[:spandrel              ]
      v[:spandrelconcave       ] = @set[id][:spandrelconcave       ] if h[:spandrelconcave       ]
      v[:spandrelconvex        ] = @set[id][:spandrelconvex        ] if h[:spandrelconvex        ]
      v[:corner                ] = @set[id][:corner                ] if h[:corner                ]
      v[:cornerconcave         ] = @set[id][:corner                ] if h[:corner                ]
      v[:cornerconvex          ] = @set[id][:corner                ] if h[:corner                ]
      v[:cornerconcave         ] = @set[id][:cornerconcave         ] if h[:cornerconcave         ]
      v[:cornerconvex          ] = @set[id][:cornerconvex          ] if h[:cornerconvex          ]
      v[:parapet               ] = @set[id][:roof                  ] if h[:roof                  ]
      v[:parapetconcave        ] = @set[id][:roof                  ] if h[:roof                  ]
      v[:parapetconvex         ] = @set[id][:roof                  ] if h[:roof                  ]
      v[:parapetconcave        ] = @set[id][:roofconcave           ] if h[:roofconcave           ]
      v[:parapetconvex         ] = @set[id][:roofconvex            ] if h[:roofconvex            ]
      v[:parapet               ] = @set[id][:parapet               ] if h[:parapet               ]
      v[:parapetconcave        ] = @set[id][:parapet               ] if h[:parapet               ]
      v[:parapetconvex         ] = @set[id][:parapet               ] if h[:parapet               ]
      v[:parapetconcave        ] = @set[id][:parapetconcave        ] if h[:parapetconcave        ]
      v[:parapetconvex         ] = @set[id][:parapetconvex         ] if h[:parapetconvex         ]
      v[:roof                  ] = @set[id][:parapet               ] if h[:parapet               ]
      v[:roofconcave           ] = @set[id][:parapet               ] if h[:parapet               ]
      v[:roofconvex            ] = @set[id][:parapet               ] if h[:parapet               ]
      v[:roofconcave           ] = @set[id][:parapetconcave        ] if h[:parapetconcave        ]
      v[:roofconvex            ] = @set[id][:parapetxonvex         ] if h[:parapetconvex         ]
      v[:roof                  ] = @set[id][:roof                  ] if h[:roof                  ]
      v[:roofconcave           ] = @set[id][:roof                  ] if h[:roof                  ]
      v[:roofconvex            ] = @set[id][:roof                  ] if h[:roof                  ]
      v[:roofconcave           ] = @set[id][:roofconcave           ] if h[:roofconcave           ]
      v[:roofconvex            ] = @set[id][:roofconvex            ] if h[:roofconvex            ]
      v[:ceiling               ] = @set[id][:ceiling               ] if h[:ceiling               ]
      v[:ceilingconcave        ] = @set[id][:ceiling               ] if h[:ceiling               ]
      v[:ceilingconvex         ] = @set[id][:ceiling               ] if h[:ceiling               ]
      v[:ceilingconcave        ] = @set[id][:ceilingconcave        ] if h[:ceilingconcave        ]
      v[:ceilingconvex         ] = @set[id][:ceilingconvex         ] if h[:ceilingconvex         ]
      v[:party                 ] = @set[id][:party                 ] if h[:party                 ]
      v[:partyconcave          ] = @set[id][:party                 ] if h[:party                 ]
      v[:partyconvex           ] = @set[id][:party                 ] if h[:party                 ]
      v[:partyconcave          ] = @set[id][:partyconcave          ] if h[:partyconcave          ]
      v[:partyconvex           ] = @set[id][:partyconvex           ] if h[:partyconvex           ]
      v[:grade                 ] = @set[id][:grade                 ] if h[:grade                 ]
      v[:gradeconcave          ] = @set[id][:grade                 ] if h[:grade                 ]
      v[:gradeconvex           ] = @set[id][:grade                 ] if h[:grade                 ]
      v[:gradeconcave          ] = @set[id][:gradeconcave          ] if h[:gradeconcave          ]
      v[:gradeconvex           ] = @set[id][:gradeconvex           ] if h[:gradeconvex           ]
      v[:balcony               ] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconyconcave        ] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconyconvex         ] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconyconcave        ] = @set[id][:balconyconcave        ] if h[:balconyconcave        ]
      v[:balconyconvex         ] = @set[id][:balconyconvex         ] if h[:balconyconvex         ]
      v[:balconysill           ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:balconysillconcave    ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:balconysillconvex     ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:balconydoorsill       ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:balconydoorsillconcave] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:balconydoorsillconvex ] = @set[id][:fenestration          ] if h[:fenestration          ]
      v[:balconysill           ] = @set[id][:sill                  ] if h[:sill                  ]
      v[:balconysillconcave    ] = @set[id][:sill                  ] if h[:sill                  ]
      v[:balconysillconvex     ] = @set[id][:sill                  ] if h[:sill                  ]
      v[:balconysillconcave    ] = @set[id][:sillconcave           ] if h[:sillconcave           ]
      v[:balconysillconvex     ] = @set[id][:sillconvex            ] if h[:sillconvex            ]
      v[:balconydoorsill       ] = @set[id][:sill                  ] if h[:sill                  ]
      v[:balconydoorsillconcave] = @set[id][:sill                  ] if h[:sill                  ]
      v[:balconydoorsillconvex ] = @set[id][:sill                  ] if h[:sill                  ]
      v[:balconydoorsillconcave] = @set[id][:sillconcave           ] if h[:sillconcave           ]
      v[:balconydoorsillconvex ] = @set[id][:sillconvex            ] if h[:sillconvex            ]
      v[:balconysill           ] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconysillconcave    ] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconysillconvex     ] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconysillconcave    ] = @set[id][:balconyconcave        ] if h[:balconyconcave        ]
      v[:balconysillconvex     ] = @set[id][:balconyconvex         ] if h[:balconycinvex         ]
      v[:balconydoorsill       ] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconydoorsillconcave] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconydoorsillconvex ] = @set[id][:balcony               ] if h[:balcony               ]
      v[:balconydoorsillconcave] = @set[id][:balconyconcave        ] if h[:balconyconcave        ]
      v[:balconydoorsillconvex ] = @set[id][:balconyconvex         ] if h[:balconycinvex         ]
      v[:balconysill           ] = @set[id][:balconysill           ] if h[:balconysill           ]
      v[:balconysillconcave    ] = @set[id][:balconysill           ] if h[:balconysill           ]
      v[:balconysillconvex     ] = @set[id][:balconysill           ] if h[:balconysill           ]
      v[:balconysillconcave    ] = @set[id][:balconysillconcave    ] if h[:balconysillconcave    ]
      v[:balconysillconvex     ] = @set[id][:balconysillconvex     ] if h[:balconysillconvex     ]
      v[:balconydoorsill       ] = @set[id][:balconysill           ] if h[:balconysill           ]
      v[:balconydoorsillconcave] = @set[id][:balconysill           ] if h[:balconysill           ]
      v[:balconydoorsillconvex ] = @set[id][:balconysill           ] if h[:balconysill           ]
      v[:balconydoorsillconcave] = @set[id][:balconysillconcave    ] if h[:balconysillconcave    ]
      v[:balconydoorsillconvex ] = @set[id][:balconysillconvex     ] if h[:balconysillconvex     ]
      v[:balconydoorsill       ] = @set[id][:balconydoorsill       ] if h[:balconydoorsill       ]
      v[:balconydoorsillconcave] = @set[id][:balconydoorsill       ] if h[:balconydoorsill       ]
      v[:balconydoorsillconvex ] = @set[id][:balconydoorsill       ] if h[:balconydoorsill       ]
      v[:balconydoorsillconcave] = @set[id][:balconydoorsillconcave] if h[:balconydoorsillconcave]
      v[:balconydoorsillconvex ] = @set[id][:balconydoorsillconvex ] if h[:balconydoorsillconvex ]
      v[:rimjoist              ] = @set[id][:rimjoist              ] if h[:rimjoist              ]
      v[:rimjoistconcave       ] = @set[id][:rimjoist              ] if h[:rimjoist              ]
      v[:rimjoistconvex        ] = @set[id][:rimjoist              ] if h[:rimjoist              ]
      v[:rimjoistconcave       ] = @set[id][:rimjoistconcave       ] if h[:rimjoistconcave       ]
      v[:rimjoistconvex        ] = @set[id][:rimjoistconvex        ] if h[:rimjoistconvex        ]

      max = [v[:parapetconcave], v[:parapetconvex]].max
      v[:parapet] = max unless @has[:parapet]

      max = [v[:roofconcave], v[:roofconvex]].max
      v[:roof] = max unless @has[:roof]

      @val[id] = v

      true
    end

    ##
    # Appends a new PSI set.
    #
    # @param [Hash] set a new PSI set
    # @option set [#to_s] :id PSI set identifier
    # @option set [#to_f] :rimjoist intermediate floor-to-wall intersection
    # @option set [#to_f] :rimjoistconcave basilaire variant
    # @option set [#to_f] :rimjoistconvex cantilever variant
    # @option set [#to_f] :parapet roof-to-wall intersection
    # @option set [#to_f] :parapetconcave basilaire variant
    # @option set [#to_f] :parapetconvex typical
    # @option set [#to_f] :roof roof-to-wall intersection
    # @option set [#to_f] :roofconcave basilaire variant
    # @option set [#to_f] :roofconvex typical
    # @option set [#to_f] :ceiling intermediate (uninsulated) ceiling perimeter
    # @option set [#to_f] :ceilingconcave cantilever variant
    # @option set [#to_f] :ceilingconvex colonnade variant
    # @option set [#to_f] :fenestration head/sill/jamb interface
    # @option set [#to_f] :head (fenestrated) header interface
    # @option set [#to_f] :headconcave (fenestrated) basilaire variant
    # @option set [#to_f] :headconvex  (fenestrated) parapet variant
    # @option set [#to_f] :sill (fenestrated) threshold/sill interface
    # @option set [#to_f] :sillconcave (fenestrated) basilaire variant
    # @option set [#to_f] :sillconvex (fenestrated) cantilever variant
    # @option set [#to_f] :jamb (fenestrated) side jamb interface
    # @option set [#to_f] :jambconcave (fenestrated) interior corner variant
    # @option set [#to_f] :jambconvex (fenestrated) exterior corner variant
    # @option set [#to_f] :door (opaque) head/sill/jamb interface
    # @option set [#to_f] :doorhead (opaque) header interface
    # @option set [#to_f] :doorheadconcave (opaque) basilaire variant
    # @option set [#to_f] :doorheadconvex (opaque) parapet variant
    # @option set [#to_f] :doorsill (opaque) threshold interface
    # @option set [#to_f] :doorsillconcave (opaque) basilaire variant
    # @option set [#to_f] :doorsillconvex (opaque) cantilever variant
    # @option set [#to_f] :doorjamb (opaque) side jamb interface
    # @option set [#to_f] :doorjambconcave (opaque) interior corner variant
    # @option set [#to_f] :doorjambconvex (opaque) exterior corner variant
    # @option set [#to_f] :skylight to roof interface
    # @option set [#to_f] :skylighthead header interface
    # @option set [#to_f] :skylightheadconcave basilaire variant
    # @option set [#to_f] :skylightheadconvex parapet variant
    # @option set [#to_f] :skylightsill sill interface
    # @option set [#to_f] :skylightsillconcave basilaire variant
    # @option set [#to_f] :skylightsillconvex cantilever variant
    # @option set [#to_f] :skylightjamb side jamb interface
    # @option set [#to_f] :skylightjambconcave (opaque) interior corner variant
    # @option set [#to_f] :skylightjambconvex (opaque) parapet variant
    # @option set [#to_f] :spandrel spandrel/other interface
    # @option set [#to_f] :spandrelconcave interior corner variant
    # @option set [#to_f] :spandrelconvex exterior corner variant
    # @option set [#to_f] :corner corner intersection
    # @option set [#to_f] :cornerconcave interior corner variant
    # @option set [#to_f] :cornerconvex exterior corner variant
    # @option set [#to_f] :balcony intermediate floor-balcony intersection
    # @option set [#to_f] :balconyconcave basilaire variant
    # @option set [#to_f] :balconyconvex cantilever variant
    # @option set [#to_f] :balconysill intermediate floor-balcony-fenestration intersection
    # @option set [#to_f] :balconysilloncave basilaire variant
    # @option set [#to_f] :balconysillconvex cantilever variant
    # @option set [#to_f] :balconydoorsill intermediate floor-balcony-door intersection
    # @option set [#to_f] :balconydoorsilloncave basilaire variant
    # @option set [#to_f] :balconydoorsillconvex cantilever variant
    # @option set [#to_f] :party demising surface intersection
    # @option set [#to_f] :partyconcave interior corner or basilaire variant
    # @option set [#to_f] :partyconvex exterior corner or cantilever variant
    # @option set [#to_f] :grade foundation wall or slab-on-grade intersection
    # @option set [#to_f] :gradeconcave cantilever variant
    # @option set [#to_f] :gradeconvex basilaire variant
    # @option set [#to_f] :joint strong ~coplanar joint
    # @option set [#to_f] :transition mild ~coplanar transition
    #
    # @return [Bool] whether PSI set is successfully appended
    # @return [false] if invalid input (see logs)
    def append(set = {})
      mth = "TBD::#{__callee__}"
      a   = false
      s   = {}
      return mismatch("set"  , set, Hash, mth, DBG, a) unless set.is_a?(Hash)
      return hashkey("set id", set, :id , mth, DBG, a) unless set.key?(:id)

      id = trim(set[:id])
      return mismatch("set ID", set[:id], String, mth, ERR, a) if id.empty?

      if @set.key?(id)
        log(ERR, "'#{id}': existing PSI set (#{mth})")
        return a
      end

      # Most PSI types have concave and convex variants, depending on the polar
      # position of deratable surfaces about an edge-as-thermal-bridge. One
      # exception is :fenestration, which TBD later breaks down into :head,
      # :sill or :jamb edge types. Another exception is a :joint edge: a PSI
      # type that is not autoassigned to an edge (i.e., only via a TBD JSON
      # input file). Finally, transitions are autoassigned by TBD when an edge
      # is "flat", i.e, no noticeable polar angle difference between surfaces.
      s[:rimjoist              ] = set[:rimjoist              ] if set.key?(:rimjoist)
      s[:rimjoistconcave       ] = set[:rimjoistconcave       ] if set.key?(:rimjoistconcave)
      s[:rimjoistconvex        ] = set[:rimjoistconvex        ] if set.key?(:rimjoistconvex)
      s[:parapet               ] = set[:parapet               ] if set.key?(:parapet)
      s[:parapetconcave        ] = set[:parapetconcave        ] if set.key?(:parapetconcave)
      s[:parapetconvex         ] = set[:parapetconvex         ] if set.key?(:parapetconvex)
      s[:roof                  ] = set[:roof                  ] if set.key?(:roof)
      s[:roofconcave           ] = set[:roofconcave           ] if set.key?(:roofconcave)
      s[:roofconvex            ] = set[:roofconvex            ] if set.key?(:roofconvex)
      s[:ceiling               ] = set[:ceiling               ] if set.key?(:ceiling)
      s[:ceilingconcave        ] = set[:ceilingconcave        ] if set.key?(:ceilingconcave)
      s[:ceilingconvex         ] = set[:ceilingconvex         ] if set.key?(:ceilingconvex)
      s[:fenestration          ] = set[:fenestration          ] if set.key?(:fenestration)
      s[:head                  ] = set[:head                  ] if set.key?(:head)
      s[:headconcave           ] = set[:headconcave           ] if set.key?(:headconcave)
      s[:headconvex            ] = set[:headconvex            ] if set.key?(:headconvex)
      s[:sill                  ] = set[:sill                  ] if set.key?(:sill)
      s[:sillconcave           ] = set[:sillconcave           ] if set.key?(:sillconcave)
      s[:sillconvex            ] = set[:sillconvex            ] if set.key?(:sillconvex)
      s[:jamb                  ] = set[:jamb                  ] if set.key?(:jamb)
      s[:jambconcave           ] = set[:jambconcave           ] if set.key?(:jambconcave)
      s[:jambconvex            ] = set[:jambconvex            ] if set.key?(:jambconvex)
      s[:door                  ] = set[:door                  ] if set.key?(:door)
      s[:doorhead              ] = set[:doorhead              ] if set.key?(:doorhead)
      s[:doorheadconcave       ] = set[:doorheadconcave       ] if set.key?(:doorheadconcave)
      s[:doorheadconvex        ] = set[:doorheadconvex        ] if set.key?(:doorheadconvex)
      s[:doorsill              ] = set[:doorsill              ] if set.key?(:doorsill)
      s[:doorsillconcave       ] = set[:doorsillconcave       ] if set.key?(:doorsillconcave)
      s[:doorsillconvex        ] = set[:doorsillconvex        ] if set.key?(:doorsillconvex)
      s[:doorjamb              ] = set[:doorjamb              ] if set.key?(:doorjamb)
      s[:doorjambconcave       ] = set[:doorjambconcave       ] if set.key?(:doorjambconcave)
      s[:doorjambconvex        ] = set[:doorjambconvex        ] if set.key?(:doorjambconvex)
      s[:skylight              ] = set[:skylight              ] if set.key?(:skylight)
      s[:skylighthead          ] = set[:skylighthead          ] if set.key?(:skylighthead)
      s[:skylightheadconcave   ] = set[:skylightheadconcave   ] if set.key?(:skylightheadconcave)
      s[:skylightheadconvex    ] = set[:skylightheadconvex    ] if set.key?(:skylightheadconvex)
      s[:skylightsill          ] = set[:skylightsill          ] if set.key?(:skylightsill)
      s[:skylightsillconcave   ] = set[:skylightsillconcave   ] if set.key?(:skylightsillconcave)
      s[:skylightsillconvex    ] = set[:skylightsillconvex    ] if set.key?(:skylightsillconvex)
      s[:skylightjamb          ] = set[:skylightjamb          ] if set.key?(:skylightjamb)
      s[:skylightjambconcave   ] = set[:skylightjambconcave   ] if set.key?(:skylightjambconcave)
      s[:skylightjambconvex    ] = set[:skylightjambconvex    ] if set.key?(:skylightjambconvex)
      s[:spandrel              ] = set[:spandrel              ] if set.key?(:spandrel)
      s[:spandrelconcave       ] = set[:spandrelconcave       ] if set.key?(:spandrelconcave)
      s[:spandrelconvex        ] = set[:spandrelconvex        ] if set.key?(:spandrelconvex)
      s[:corner                ] = set[:corner                ] if set.key?(:corner)
      s[:cornerconcave         ] = set[:cornerconcave         ] if set.key?(:cornerconcave)
      s[:cornerconvex          ] = set[:cornerconvex          ] if set.key?(:cornerconvex)
      s[:balcony               ] = set[:balcony               ] if set.key?(:balcony)
      s[:balconyconcave        ] = set[:balconyconcave        ] if set.key?(:balconyconcave)
      s[:balconyconvex         ] = set[:balconyconvex         ] if set.key?(:balconyconvex)
      s[:balconysill           ] = set[:balconysill           ] if set.key?(:balconysill)
      s[:balconysillconcave    ] = set[:balconysillconcave    ] if set.key?(:balconysillconcave)
      s[:balconysillconvex     ] = set[:balconysillconvex     ] if set.key?(:balconysillconvex)
      s[:balconydoorsill       ] = set[:balconydoorsill       ] if set.key?(:balconydoorsill)
      s[:balconydoorsillconcave] = set[:balconydoorsillconcave] if set.key?(:balconydoorsillconcave)
      s[:balconydoorsillconvex ] = set[:balconydoorsillconvex ] if set.key?(:balconydoorsillconvex)
      s[:party                 ] = set[:party                 ] if set.key?(:party)
      s[:partyconcave          ] = set[:partyconcave          ] if set.key?(:partyconcave)
      s[:partyconvex           ] = set[:partyconvex           ] if set.key?(:partyconvex)
      s[:grade                 ] = set[:grade                 ] if set.key?(:grade)
      s[:gradeconcave          ] = set[:gradeconcave          ] if set.key?(:gradeconcave)
      s[:gradeconvex           ] = set[:gradeconvex           ] if set.key?(:gradeconvex)
      s[:joint                 ] = set[:joint                 ] if set.key?(:joint)
      s[:transition            ] = set[:transition            ] if set.key?(:transition)

      s[:joint                 ] = 0.000  unless set.key?(:joint)
      s[:transition            ] = 0.000  unless set.key?(:transition)
      s[:ceiling               ] = 0.000  unless set.key?(:ceiling)

      @set[id] = s
      self.gen(id)

      true
    end

    ##
    # Returns PSI set shorthands. The return Hash holds 2 keys, has: a Hash
    # of true/false (values) for any admissible PSI type (keys), and val: a
    # Hash of PSI-factors (values) for any admissible PSI type (keys).
    # PSI-factors default to 0 W/K per linear meter if missing from set.
    #
    # @param id [#to_s] PSI set identifier
    # @example intermediate floor slab intersection
    #   shorthands("90.1.22|steel.m|default")
    #
    # @return [Hash] has: Hash (Bool), val: Hash (PSI factors) see logs if empty
    def shorthands(id = "")
      mth = "TBD::#{__callee__}"
      sh  = { has: {}, val: {} }
      id  = trim(id)
      return mismatch("set ID", id, String, mth, ERR, a)      if id.empty?
      return hashkey(id, @set , id,         mth, ERR, sh) unless @set.key?(id)
      return hashkey(id, @has , id,         mth, ERR, sh) unless @has.key?(id)
      return hashkey(id, @val , id,         mth, ERR, sh) unless @val.key?(id)

      sh[:has] = @has[id]
      sh[:val] = @val[id]

      sh
    end

    ##
    # Validates whether a given PSI set has a complete list of PSI type:values.
    #
    # @param id [#to_s] PSI set identifier
    #
    # @return [Bool] whether provided PSI set is held in memory and is complete
    # @return [false] if invalid input (see logs)
    def complete?(id = "")
      mth = "TBD::#{__callee__}"
      a   = false
      id  = trim(id)
      return mismatch("set ID", id, String, mth, ERR, a)     if id.empty?
      return hashkey(id, @set , id,         mth, ERR, a) unless @set.key?(id)
      return hashkey(id, @has , id,         mth, ERR, a) unless @has.key?(id)
      return hashkey(id, @val , id,         mth, ERR, a) unless @val.key?(id)

      holes = []
      holes << :head       if @has[id][:head          ]
      holes << :sill       if @has[id][:sill          ]
      holes << :jamb       if @has[id][:jamb          ]
      ok = holes.size == 3
      ok = true            if @has[id][:fenestration  ]
      return false     unless ok

      corners = []
      corners << :concave  if @has[id][:cornerconcave ]
      corners << :convex   if @has[id][:cornerconvex  ]
      ok = corners.size == 2
      ok = true            if @has[id][:corner        ]
      return false     unless ok

      parapets = []
      roofs    = []
      parapets << :concave if @has[id][:parapetconcave]
      parapets << :convex  if @has[id][:parapetconvex ]
      roofs    << :concave if @has[id][:roofconcave   ]
      parapets << :convex  if @has[id][:roofconvex    ]
      ok = parapets.size == 2 || roofs.size == 2
      ok = true            if @has[id][:parapet       ]
      ok = true            if @has[id][:roof          ]
      return false     unless ok
      return false     unless @has[id][:party         ]
      return false     unless @has[id][:grade         ]
      return false     unless @has[id][:balcony       ]
      return false     unless @has[id][:rimjoist      ]

      ok
    end

    ##
    # Returns safe PSI type if missing from PSI set (based on inheritance).
    #
    # @param id [#to_s] PSI set identifier
    # @param type [#to_sym] PSI type
    # @example intermediate floor slab intersection
    #   safe("90.1.22|wood.fr|unmitigated", :rimjoistconcave)
    #
    # @return [Symbol] safe PSI type
    # @return [nil] if invalid inputs (see logs)
    def safe(id = "", type = nil)
      mth = "TBD::#{__callee__}"
      id  = trim(id)
      ck1 = id.empty?
      ck2 = type.respond_to?(:to_sym)
      return mismatch("set ID", id, String, mth)          if ck1
      return mismatch("type", type, Symbol, mth)      unless ck2
      return hashkey(id, @set,  id,         mth, ERR) unless @set.key?(id)
      return hashkey(id, @has,  id,         mth, ERR) unless @has.key?(id)

      safer = type.to_sym

      unless @has[id][safer]
        concave = safer.to_s.include?("concave")
        convex  = safer.to_s.include?("convex")
        safer   = safer.to_s.chomp("concave").to_sym if concave
        safer   = safer.to_s.chomp("convex").to_sym  if convex
      end

      unless @has[id][safer]
        safer = :fenestration if safer == :head
        safer = :fenestration if safer == :sill
        safer = :fenestration if safer == :jamb
        safer = :door         if safer == :doorhead
        safer = :door         if safer == :doorsill
        safer = :door         if safer == :doorjamb
        safer = :skylight     if safer == :skylighthead
        safer = :skylight     if safer == :skylightsill
        safer = :skylight     if safer == :skylightjamb
      end

      unless @has[id][safer]
        safer = :fenestration if safer == :skylight
        safer = :fenestration if safer == :door
      end

      return safer if @has[id][safer]

      nil
    end
  end

  ##
  # Processes TBD JSON inputs, after TBD has preprocessed OpenStudio model
  # variables and retrieved corresponding Topolys model surface/edge
  # properties. TBD user inputs allow customization of default assumptions and
  # inferred values. If successful, "edges" (input) may inherit additional
  # properties, e.g.: edge-specific PSI set (defined in TBD JSON file),
  # edge-specific PSI type (e.g. "corner", defined in TBD JSON file),
  # project-wide PSI set (if absent from TBD JSON file).
  #
  # @param [Hash] s TBD surfaces (keys: Openstudio surface names)
  # @option s [Hash] :windows TBD surface-specific windows e.g. s[][:windows]
  # @option s [Hash] :doors TBD surface-specific doors
  # @option s [Hash] :skylights TBD surface-specific skylights
  # @option s [OpenStudio::Model::BuildingStory] :story OpenStudio story
  # @option s ["Wall", "RoofCeiling", "Floor"] :stype OpenStudio surface type
  # @option s [OpenStudio::Model::Space] :space OpenStudio space
  # @param [Hash] e TBD edges (keys: Topolys edge identifiers)
  # @option e [Hash] :surfaces linked TBD surfaces e.g. e[][:surfaces]
  # @option e [#to_f] :length edge length in m
  # @option e [Topolys::Point3D] :v0 origin vertex
  # @option e [Topolys::Point3D] :v1 terminal vertex
  # @param [Hash] argh TBD arguments
  # @option argh [#to_s] :option selected PSI set
  # @option argh [#to_s] :io_path tbd.json input file path
  # @option argh [#to_s] :schema_path TBD JSON schema file path
  #
  # @return [Hash] io: (Hash), psi:/khi: enriched sets (see logs if empty)
  def inputs(s = {}, e = {}, argh = {})
    mth = "TBD::#{__callee__}"
    opt = :option
    ipt = { io: {}, psi: PSI.new, khi: KHI.new }
    io  = {}
    return mismatch("s"   , s   , Hash, mth, DBG, ipt) unless s.is_a?(Hash)
    return mismatch("e"   , e   , Hash, mth, DBG, ipt) unless e.is_a?(Hash)
    return mismatch("argh", argh, Hash, mth, DBG, ipt) unless argh.is_a?(Hash)
    return hashkey("argh" , argh, opt , mth, DBG, ipt) unless argh.key?(opt)

    argh[:io_path    ] = nil unless argh.key?(:io_path)
    argh[:schema_path] = nil unless argh.key?(:schema_path)

    pth = argh[:io_path    ]
    sch = argh[:schema_path]

    if pth && (pth.is_a?(String) || pth.is_a?(Hash))
      if pth.is_a?(Hash)
        io = pth
      else
        return empty("JSON file", mth, FTL, ipt) unless File.size?(pth)

        io = File.read(pth)
        io = JSON.parse(io, symbolize_names: true)
        return mismatch("io", io, Hash, mth, FTL, ipt) unless io.is_a?(Hash)
      end

      # Schema validation is not yet supported in the OpenStudio Application.
      # It is nonetheless recommended that users rely on the json-schema gem,
      # or an online linter, prior to using TBD. The following checks focus on
      # content - ignoring bad JSON input otherwise caught via JSON validation.
      #
      # A side note: JSON validation relies on case-senitive string comparisons
      # (e.g. OpenStudio space or surface names, vs corresponding TBD JSON
      # identifiers). So "Space-1" doesn't match "SPACE-1" ... head's up!
      if sch
        require "json-schema"
        return invalid("JSON schema", mth, 3, FTL, ipt) unless File.exist?(sch)
        return empty("JSON schema"  , mth,    FTL, ipt)     if File.zero?(sch)

        schema = File.read(sch)
        schema = JSON.parse(schema, symbolize_names: true)
        valid  = JSON::Validator.validate!(schema, io)
        return invalid("JSON schema validation", mth, 3, FTL, ipt) unless valid
      end

      # Append JSON entries to library of linear & point thermal bridges.
      io[:psis].each { |psi| ipt[:psi].append(psi) } if io.key?(:psis)
      io[:khis].each { |khi| ipt[:khi].append(khi) } if io.key?(:khis)

      # JSON-defined or user-selected, building PSI set must be complete/valid.
      io[:building] = { psi: argh[opt] } unless io.key?(:building)
      bdg = io[:building]
      ok  = bdg.key?(:psi)
      return hashkey("Building PSI", bdg, :psi, mth, FTL, ipt)  unless ok

      ok = ipt[:psi].complete?(bdg[:psi])
      return invalid("Complete building PSI", mth, 3, FTL, ipt) unless ok

      # Validate remaining (optional) JSON entries.
      [:stories, :spacetypes, :spaces].each do |types|
        key = :story
        key = :stype if types == :spacetypes
        key = :space if types == :spaces

        if io.key?(types)
          io[types].each do |type|
            next unless type.key?(:psi)
            next unless type.key?(:id )

            s1 = "JSON/OSM '#{type[:id]}' (#{mth})"
            s2 = "JSON/PSI '#{type[:id]}' set (#{mth})"
            match = false

            s.values.each do |props| # TBD surface linked to type?
              break    if match
              next unless props.key?(key)

              match = type[:id] == props[key].nameString
            end

            log(ERR, s1) unless match
            log(ERR, s2) unless ipt[:psi].set.key?(type[:psi])
          end
        end
      end

      if io.key?(:surfaces)
        io[:surfaces].each do |surface|
          next unless surface.key?(:id)

          s1 = "JSON/OSM surface '#{surface[:id]}' (#{mth})"
          log(ERR, s1) unless s.key?(surface[:id])

          # surfaces can OPTIONALLY hold custom PSI sets and/or KHI data
          if surface.key?(:psi)
            s2 = "JSON/OSM surface/set '#{surface[:id]}' (#{mth})"
            log(ERR, s2) unless ipt[:psi].set.key?(surface[:psi])
          end

          if surface.key?(:khis)
            surface[:khis].each do |khi|
              next unless khi.key?(:id)

              s3 = "JSON/KHI surface '#{surface[:id]}' '#{khi[:id]}' (#{mth})"
              log(ERR, s3) unless ipt[:khi].point.key?(khi[:id])
            end
          end
        end
      end

      if io.key?(:subsurfaces)
        io[:subsurfaces].each do |sub|
          next unless sub.key?(:id)
          next unless sub.key?(:usi)

          match = false

          s.each do |id, surface|
            break if match

            [:windows, :doors, :skylights].each do |holes|
              if surface.key?(holes)
                surface[holes].keys.each do |id|
                  break if match

                  match = sub[:id] == id
                end
              end
            end
          end

          log(ERR, "JSON/OSM subsurface '#{sub[:id]}' (#{mth})") unless match
        end
      end

      if io.key?(:edges)
        io[:edges].each do |edge|
          next unless edge.key?(:type)
          next unless edge.key?(:surfaces)

          surfaces = edge[:surfaces]
          type     = edge[:type].to_sym
          safer    = ipt[:psi].safe(bdg[:psi], type) # fallback
          log(ERR, "Skipping invalid edge PSI '#{type}' (#{mth})") unless safer
          next unless safer

          valid = true

          surfaces.each do |surface|         #   TBD edge's surfaces on file
            e.values.each do |ee|            #           TBD edges in memory
              break unless valid             #  if previous anomaly detected
              next      if ee.key?(:io_type) #  validated from previous loop
              next  unless ee.key?(:surfaces)

              surfs      = ee[:surfaces]
              next  unless surfs.key?(surface)

              # An edge on file is valid if ALL of its listed surfaces together
              # connect at least 1 or more TBD/Topolys model edges in memory.
              # Each of the latter may connect e.g. 3 TBD/Topolys surfaces,
              # but the list of surfaces on file may be shorter, e.g. only 2.
              match = true
              surfaces.each { |id| match = false unless surfs.key?(id) }
              next unless match

              if edge.key?(:length) # optional
                next unless (ee[:length] - edge[:length]).abs < TOL
              end

              # Optionally, edge coordinates may narrow down potential matches.
              if edge.key?(:v0x) || edge.key?(:v0y) || edge.key?(:v0z) ||
                 edge.key?(:v1x) || edge.key?(:v1y) || edge.key?(:v1z)

                unless edge.key?(:v0x) && edge.key?(:v0y) && edge.key?(:v0z) &&
                       edge.key?(:v1x) && edge.key?(:v1y) && edge.key?(:v1z)
                  log(ERR, "Mismatch '#{surface}' edge vertices (#{mth})")
                  valid = false
                  next
                end

                e1 = {}
                e2 = {}
                e1[:v0] = Topolys::Point3D.new(edge[:v0x].to_f,
                                               edge[:v0y].to_f,
                                               edge[:v0z].to_f)
                e1[:v1] = Topolys::Point3D.new(edge[:v1x].to_f,
                                               edge[:v1y].to_f,
                                               edge[:v1z].to_f)
                e2[:v0] = ee[:v0].point
                e2[:v1] = ee[:v1].point
                next unless matches?(e1, e2)
              end

              if edge.key?(:psi) # optional
                set = edge[:psi]

                if ipt[:psi].set.key?(set)
                  saferr       = ipt[:psi].safe(set, type)
                  ee[:io_set ] = set                               if saferr
                  ee[:io_type] = type                              if saferr
                  log(ERR, "Invalid #{set}: #{type} (#{mth})") unless saferr
                  valid = false                                unless saferr
                else
                  log(ERR, "Missing edge PSI #{set} (#{mth})")
                  valid = false
                end
              else
                ee[:io_type] = type # success: matching edge - setting edge type
              end
            end
          end
        end
      end
    else
      # No (optional) user-defined TBD JSON input file. In such cases, provided
      # argh[:option] must refer to a valid PSI set. If valid, all edges inherit
      # a default PSI set (without KHI entries).
      msg = "Incomplete building PSI set '#{argh[opt]}' (#{mth})"
      ok  = ipt[:psi].complete?(argh[opt])

      io[:building] = { psi: argh[opt] } if ok
      log(FTL, msg)                  unless ok
      return ipt                     unless ok
    end

    ipt[:io] = io

    ipt
  end

  ##
  # Thermally derates insulating material within construction.
  #
  # @param id [#to_s] surface identifier
  # @param [Hash] s TBD surface parameters
  # @option s [#to_f] :heatloss heat loss from major thermal bridging, in W/K
  # @option s [#to_f] :net surface net area, in m2
  # @option s [:massless, :standard] :ltype indexed layer type
  # @option s [#to_i] :index deratable construction layer index
  # @option s [#to_f] :r deratable layer Rsi-factor, in m2•K/W
  # @param lc [OpenStudio::Model::LayeredConstruction] a layered construction
  #
  # @return [OpenStudio::Model::Material] derated (cloned) material
  # @return [nil] if invalid input (see logs)
  def derate(id = "", s = {}, lc = nil)
    mth = "TBD::#{__callee__}"
    m   = nil
    id  = trim(id)
    kys = [:heatloss, :net, :ltype, :index, :r]
    ck1 = s.is_a?(Hash)
    ck2 = lc.is_a?(OpenStudio::Model::LayeredConstruction)
    return mismatch("id"                , id, cl6, mth)     if id.empty?
    return mismatch("#{id} surface"     , s , cl1, mth) unless ck1
    return mismatch("#{id} construction", lc, cl2, mth) unless ck2

    kys.each do |k|
      tag = "#{id} #{k}"
      return hashkey(tag, s, k, mth, ERR) unless s.key?(k)

      case k
      when :heatloss
        return mismatch(tag, s[k], Numeric, mth) unless s[k].respond_to?(:to_f)
        return zero(tag, mth, WRN)                   if s[k].to_f.abs < 0.001
      when :net, :r
        return mismatch(tag, s[k], Numeric, mth) unless s[k].respond_to?(:to_f)
        return negative(tag, mth, 2, ERR)            if s[k].to_f < 0
        return zero(tag, mth, WRN)                   if s[k].to_f.abs < 0.001
      when :index
        return mismatch(tag, s[k], Numeric, mth) unless s[k].respond_to?(:to_i)
        return negative(tag, mth, 2, ERR)            if s[k].to_f < 0
      else # :ltype
        next if [:massless, :standard].include?(s[k])
        return invalid(tag, mth, 2, ERR)
      end
    end

    if lc.nameString.downcase.include?(" tbd")
      log(WRN, "Won't derate '#{id}': tagged as derated (#{mth})")
      return m
    end

    model = lc.model
    ltype = s[:ltype   ]
    index = s[:index   ].to_i
    net   = s[:net     ].to_f
    r     = s[:r       ].to_f
    u     = s[:heatloss].to_f / net
    loss  = 0
    de_u  = 1 / r + u # derated U
    de_r  = 1 / de_u  # derated R

    if ltype == :massless
      m    = lc.getLayer(index).to_MasslessOpaqueMaterial
      return invalid("#{id} massless layer?", mth, 0) if m.empty?
      m    = m.get
      up   = ""
      up   = "uprated " if m.nameString.downcase.include?(" uprated")
      m    = m.clone(model).to_MasslessOpaqueMaterial.get
             m.setName("#{id} #{up}m tbd")
      de_r = 0.001                   unless de_r > 0.001
      loss = (de_u - 1 / de_r) * net unless de_r > 0.001
             m.setThermalResistance(de_r)
    else
      m    = lc.getLayer(index).to_StandardOpaqueMaterial
      return invalid("#{id} standard layer?", mth, 0) if m.empty?
      m    = m.get
      up   = ""
      up   = "uprated " if m.nameString.downcase.include?(" uprated")
      m    = m.clone(model).to_StandardOpaqueMaterial.get
             m.setName("#{id} #{up}m tbd")
      k    = m.thermalConductivity

      if de_r > 0.001
        d  = de_r * k

        unless d > 0.003
          d    = 0.003
          k    = d / de_r
          k    = 3                    unless k < 3
          loss = (de_u - k / d) * net unless k < 3
        end
      else # de_r < 0.001 m2•K/W
        d    = 0.001 * k
        d    = 0.003                  unless d > 0.003
        k    = d / 0.001              unless d > 0.003
        loss = (de_u - k / d) * net
      end

      m.setThickness(d)
      m.setThermalConductivity(k)
    end

    if m && loss > TOL
      s[:r_heatloss] = loss
      hl = format "%.3f", s[:r_heatloss]
      log(WRN, "Won't assign #{hl} W/K to '#{id}': too conductive (#{mth})")
    end

    m
  end

  ##
  # Processes TBD objects, based on an OpenStudio and generated Topolys model,
  # and derates admissible envelope surfaces by substituting insulating
  # materials with derated clones, within surface multilayered constructions.
  # Returns a Hash holding 2 key:value pairs; io: objects for JSON
  # serialization, and surfaces: derated TBD surfaces (see exit method).
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param [Hash] argh TBD arguments
  # @option argh [#to_s] :option selected PSI set
  # @option argh [#to_s] :io_path tbd.json input file path
  # @option argh [#to_s] :schema_path TBD JSON schema file path
  # @option argh [Bool] :parapet (true) wall-roof edge as parapet
  # @option argh [Bool] :uprate_walls whether to uprate walls
  # @option argh [Bool] :uprate_roofs whether to uprate roofs
  # @option argh [Bool] :uprate_floors whether to uprate floors
  # @option argh [Bool] :wall_ut uprated wall Ut target in W/m2•K
  # @option argh [Bool] :roof_ut uprated roof Ut target in W/m2•K
  # @option argh [Bool] :floor_ut uprated floor Ut target in W/m2•K
  # @option argh [#to_s] :wall_option wall construction to uprate (or "all")
  # @option argh [#to_s] :roof_option roof construction to uprate (or "all")
  # @option argh [#to_s] :floor_option floor construction to uprate (or "all")
  # @option argh [Bool] :gen_ua whether to generate a UA' report
  # @option argh [#to_s] :ua_ref selected UA' ruleset
  # @option argh [Bool] :gen_kiva whether to generate KIVA inputs
  # @option argh [#to_f] :sub_tol proximity tolerance between edges in m
  #
  # @return [Hash] io: (Hash), surfaces: (Hash)
  # @return [Hash] io: nil, surfaces: nil if invalid input (see logs)
  def process(model = nil, argh = {})
    mth = "TBD::#{__callee__}"
    cl  = OpenStudio::Model::Model
    tbd = { io: nil, surfaces: {} }
    return mismatch("model", model, cl, mth, DBG, tbd) unless model.is_a?(cl)
    return mismatch("argh", argh, Hash, mth, DBG, tbd) unless argh.is_a?(Hash)

    argh                 = {}           if argh.empty?
    argh[:option       ] = ""       unless argh.key?(:option)
    argh[:io_path      ] = nil      unless argh.key?(:io_path)
    argh[:schema_path  ] = nil      unless argh.key?(:schema_path)
    argh[:parapet      ] = true     unless argh.key?(:parapet)
    argh[:uprate_walls ] = false    unless argh.key?(:uprate_walls)
    argh[:uprate_roofs ] = false    unless argh.key?(:uprate_roofs)
    argh[:uprate_floors] = false    unless argh.key?(:uprate_floors)
    argh[:wall_ut      ] = 0        unless argh.key?(:wall_ut)
    argh[:roof_ut      ] = 0        unless argh.key?(:roof_ut)
    argh[:floor_ut     ] = 0        unless argh.key?(:floor_ut)
    argh[:wall_option  ] = ""       unless argh.key?(:wall_option)
    argh[:roof_option  ] = ""       unless argh.key?(:roof_option)
    argh[:floor_option ] = ""       unless argh.key?(:floor_option)
    argh[:gen_ua       ] = false    unless argh.key?(:gen_ua)
    argh[:ua_ref       ] = ""       unless argh.key?(:ua_ref)
    argh[:gen_kiva     ] = false    unless argh.key?(:gen_kiva)
    argh[:reset_kiva   ] = false    unless argh.key?(:reset_kiva)
    argh[:sub_tol      ] = TBD::TOL unless argh.key?(:sub_tol)

    # Ensure true or false: whether to generate KIVA inputs.
    unless [true, false].include?(argh[:gen_kiva])
      return invalid("generate KIVA option", mth, 0, DBG, tbd)
    end

    # Ensure true or false: whether to first purge (existing) KIVA inputs.
    unless [true, false].include?(argh[:reset_kiva])
      return invalid("reset KIVA option", mth, 0, DBG, tbd)
    end

    # Create the Topolys Model.
    t_model = Topolys::Model.new

    # "true" if any space/zone holds valid setpoint temperatures. With invalid
    # inputs, these 2x methods return "false", ignoring any
    # setpoint-based logic, e.g. semi-heated spaces (DEBUG errors are logged).
    heated = heatingTemperatureSetpoints?(model)
    cooled = coolingTemperatureSetpoints?(model)
    argh[:setpoints] = heated || cooled

    model.getSurfaces.sort_by { |s| s.nameString }.each do |s|
      # Fetch key attributes of opaque surfaces (and any linked sub surfaces).
      # Method returns nil with invalid input (see logs); TBD ignores them.
      surface = properties(s, argh)
      tbd[:surfaces][s.nameString] = surface unless surface.nil?
    end

    return empty("TBD surfaces", mth, ERR, tbd) if tbd[:surfaces].empty?

    # TBD only derates constructions of opaque surfaces in CONDITIONED spaces,
    # ... if facing outdoors or facing UNENCLOSED/UNCONDITIONED spaces.
    tbd[:surfaces].each do |id, surface|
      surface[:deratable] = false
      next unless surface[:conditioned]
      next     if surface[:ground     ]

      unless surface[:boundary].downcase == "outdoors"
        next unless tbd[:surfaces].key?(surface[:boundary])
        next     if tbd[:surfaces][surface[:boundary]][:conditioned]
      end

      if surface.key?(:index)
        surface[:deratable] = true
      else
        log(ERR, "Skipping '#{id}': insulating layer? (#{mth})")
      end
    end

    # Sort subsurfaces before processing.
    [:windows, :doors, :skylights].each do |holes|
      tbd[:surfaces].values.each do |surface|
        next unless surface.key?(holes)

        surface[holes] = surface[holes].sort_by { |_, s| s[:minz] }.to_h
      end
    end

    # Split "surfaces" hash into "floors", "ceilings" and "walls" hashes.
    floors   = tbd[:surfaces].select { |_, s| s[:type] == :floor   }
    ceilings = tbd[:surfaces].select { |_, s| s[:type] == :ceiling }
    walls    = tbd[:surfaces].select { |_, s| s[:type] == :wall    }

    floors   = floors.sort_by   { |_, s| [s[:minz], s[:space]] }.to_h
    ceilings = ceilings.sort_by { |_, s| [s[:minz], s[:space]] }.to_h
    walls    = walls.sort_by    { |_, s| [s[:minz], s[:space]] }.to_h

    # Fetch OpenStudio shading surfaces & key attributes.
    shades = {}

    model.getShadingSurfaces.each do |s|
      id    = s.nameString
      group = s.shadingSurfaceGroup
      log(ERR, "Can't process '#{id}' transformation (#{mth})") if group.empty?
      next                                                      if group.empty?

      group   = group.get
      tr      = transforms(group)
      t       = tr[:t] if tr[:t] && tr[:r]

      log(ERR, "Can't process '#{id}' transformation (#{mth})") unless t
      next                                                      unless t

      space   = group.space
      tr[:r] += space.get.directionofRelativeNorth unless space.empty?
      n       = truNormal(s, tr[:r])
      log(ERR, "Can't process '#{id}' true normal (#{mth})") unless n
      next                                                   unless n

      points = (t * s.vertices).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }

      minz = ( points.map { |p| p.z } ).min

      shades[id] = { group: group, points: points, minz: minz, n: n }
    end

    # Mutually populate TBD & Topolys surfaces. Keep track of created "holes".
    holes         = {}
    floor_holes   = dads(t_model, floors)
    ceiling_holes = dads(t_model, ceilings)
    wall_holes    = dads(t_model, walls)

    holes.merge!(floor_holes)
    holes.merge!(ceiling_holes)
    holes.merge!(wall_holes)
    dads(t_model, shades)

    # Loop through Topolys edges and populate TBD edge hash. Initially, there
    # should be a one-to-one correspondence between Topolys and TBD edge
    # objects. Use Topolys-generated identifiers as unique edge hash keys.
    edges = {}

    # Start with hole edges.
    holes.each do |id, wire|
      wire.edges.each do |e|
        i  = e.id
        l  = e.length
        ex = edges.key?(i)

        edges[i] = { length: l, v0: e.v0, v1: e.v1, surfaces: {} } unless ex

        next if edges[i][:surfaces].key?(wire.attributes[:id])

        edges[i][:surfaces][wire.attributes[:id]] = { wire: wire.id }
      end
    end

    # Next, floors, ceilings & walls; then shades.
    faces(floors  , edges)
    faces(ceilings, edges)
    faces(walls   , edges)
    faces(shades  , edges)

    # Purge existing KIVA objects from model.
    if argh[:reset_kiva]
      kva = false
      kva = true unless model.getSurfacePropertyExposedFoundationPerimeters.empty?
      kva = true unless model.getFoundationKivas.empty?

      if kva
        if argh[:gen_kiva]
          resetKIVA(model, "Foundation")
        else
          resetKIVA(model, "Ground")
        end
      end
    end

    # Generate OSM Kiva settings and objects if foundation-facing floors.
    # Returns false if partial failure (log failure eventually).
    kiva(model, walls, floors, edges) if argh[:gen_kiva]

    # Thermal bridging characteristics of edges are determined - in part - by
    # relative polar position of linked surfaces (or wires) around each edge.
    # This attribute is key in distinguishing concave from convex edges.
    #
    # For each linked surface (or rather surface wires), set polar position
    # around edge with respect to a reference vector (perpendicular to the
    # edge), +clockwise as one is looking in the opposite position of the edge
    # vector. For instance, a vertical edge has a reference vector pointing
    # North - surfaces eastward of the edge are (0°,180°], while surfaces
    # westward of the edge are (180°,360°].
    #
    # Much of the following code is of a topological nature, and should ideally
    # (or eventually) become available functionality offered by Topolys. Topolys
    # "wrappers" like TBD are good, short-term test beds to identify desired
    # features for future Topolys enhancements.
    zenith = Topolys::Vector3D.new(0, 0, 1).freeze
    north  = Topolys::Vector3D.new(0, 1, 0).freeze
    east   = Topolys::Vector3D.new(1, 0, 0).freeze

    edges.values.each do |edge|
      origin     = edge[:v0].point
      terminal   = edge[:v1].point
      dx         = (origin.x - terminal.x).abs
      dy         = (origin.y - terminal.y).abs
      dz         = (origin.z - terminal.z).abs
      horizontal = dz < TOL
      vertical   = dx < TOL && dy < TOL
      edge_V     = terminal - origin
      next if edge_V.magnitude < TOL

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
          next unless surface[:wire] == wire.id # should be a unique match

          normal       = tbd[:surfaces][id][:n]   if tbd[:surfaces].key?(id)
          normal       = holes[id].attributes[:n] if holes.key?(id)
          normal       = shades[id][:n]           if shades.key?(id)
          farthest     = Topolys::Point3D.new(origin.x, origin.y, origin.z)
          farthest_V   = farthest - origin # zero magnitude, initially
          farthest_mag = 0

          wire.points.each do |point|
            next if point == origin
            next if point == terminal

            point_on_plane = edge_plane.project(point)
            origin_point_V = point_on_plane - origin
            point_V_mag    = origin_point_V.magnitude
            next unless point_V_mag > TOL
            next unless point_V_mag > farthest_mag

            farthest    = point
            farthest_V  = origin_point_V
            fathest_mag = point_V_mag
          end

          angle  = reference_V.angle(farthest_V)
          angle  = 0 if angle.nil?
          adjust = false # adjust angle [180°, 360°] if necessary

          if vertical
            adjust = true if east.dot(farthest_V) < -TOL
          else
            dN  = north.dot(farthest_V)
            dN1 = north.dot(farthest_V).abs - 1

            if dN.abs < TOL || dN1.abs < TOL
              adjust = true if east.dot(farthest_V) < -TOL
            else
              adjust = true if dN < -TOL
            end
          end

          angle  = 2 * Math::PI - angle if adjust
          angle -= 2 * Math::PI         if (angle - 2 * Math::PI).abs < TOL
          surface[:angle ] = angle
          farthest_V.normalize!
          surface[:polar ] = farthest_V
          surface[:normal] = normal
        end # end of edge-linked, surface-to-wire loop
      end # end of edge-linked surface loop

      edge[:horizontal] = horizontal
      edge[:vertical  ] = vertical
      edge[:surfaces  ] = edge[:surfaces].sort_by{ |_, p| p[:angle] }.to_h
    end # end of edge loop

    # Topolys edges may constitute thermal bridges (and therefore thermally
    # derate linked OpenStudio opaque surfaces), depending on a number of
    # factors such as surface type, space conditioning and boundary conditions.
    # Thermal bridging attributes (type & PSI-value pairs) are grouped into PSI
    # sets, normally accessed through the :option user argument (in the
    # OpenStudio Measure interface).
    #
    # Process user-defined TBD JSON file inputs if file exists & valid:
    #   :io holds valid TBD JSON file entries
    #   :psi holds TBD PSI sets (built-in defaults + those on file)
    #   :khi holds TBD KHI points (built-in defaults + those on file)
    #
    # Without an input JSON file, a valid 'json' Hash simply holds:
    #   :io[:building][:psi] ... a single valid, default PSI set for all edges
    #   :psi                 ... built-in TBD PSI sets
    #   :khi                 ... built-in TBD KHI points
    json = inputs(tbd[:surfaces], edges, argh)

    # A user-defined TBD JSON input file can hold a number of anomalies that
    # won't affect results, such as custom PSI sets that aren't referenced
    # elsewhere (similar to OpenStudio materials on file that aren't referenced
    # by any OpenStudio construction). This may trigger 'warnings' in the log
    # file, but they're in principle benign.
    #
    # A user-defined JSON input file can instead hold a number of more serious
    # anomalies that risk generating erroneous or unintended results. They're
    # logged as well, yet it remains up to the user to decide how serious a risk
    # this may be. If a custom edge is defined on file (e.g., "expansion joint"
    # thermal bridge instead of a "transition") yet TBD is unable to match
    # it against OpenStudio and/or Topolys edges (or surfaces), then TBD
    # will log this as an error while simply 'skipping' the anomaly (TBD will
    # otherwise ignore the requested change and pursue its processes).
    #
    # There are 2 types of errors that are considered FATAL when processing
    # user-defined TBD JSON input files:
    #   - incorrect JSON formatting of the input file (can't parse)
    #   - TBD is unable to identify a 'complete' building-level PSI set
    #     (either a bad argument from the Measure, or bad input on file).
    #
    # ... in such circumstances, TBD will halt all processes and exit while
    # signaling to OpenStudio to halt its own processes (e.g., not launch an
    # EnergyPlus simulation). This is similar to accessing an invalid .osm file.
    return tbd if fatal?

    psi    = json[:io][:building][:psi] # default building PSI on file
    shorts = json[:psi].shorthands(psi)

    if shorts[:has].empty? || shorts[:val].empty?
      log(FTL, "Invalid or incomplete building PSI set (#{mth})")
      return tbd
    end

    edges.values.each do |edge|
      next unless edge.key?(:surfaces)

      deratables = []
      set        = {}

      edge[:surfaces].keys.each do |id|
        next unless tbd[:surfaces].key?(id)

        deratables << id if tbd[:surfaces][id][:deratable]
      end

      next if deratables.empty?

      if edge.key?(:io_type)
        bdg = json[:psi].safe(psi, edge[:io_type]) # building safe type fallback
        edge[:sets] = {} unless edge.key?(:sets)
        edge[:sets][edge[:io_type]] = shorts[:val][bdg] # building safe fallback
        set[edge[:io_type]] = shorts[:val][bdg]
        edge[:psi] = set

        if edge.key?(:io_set) && json[:psi].set.key?(edge[:io_set])
          type = json[:psi].safe(edge[:io_set], edge[:io_type])
          edge[:set] = edge[:io_set] if type
        end

        match = true
      end

      edge[:surfaces].keys.each do |id|
        break    if match
        next unless tbd[:surfaces].key?(id)
        next unless deratables.include?(id)

        # Evaluate current set content before processing a new linked surface.
        is                    = {}
        is[:doorhead        ] = set.keys.to_s.include?("doorhead")
        is[:doorsill        ] = set.keys.to_s.include?("doorsill")
        is[:doorjamb        ] = set.keys.to_s.include?("doorjamb")
        is[:skylighthead    ] = set.keys.to_s.include?("skylighthead")
        is[:skylightsill    ] = set.keys.to_s.include?("skylightsill")
        is[:skylightjamb    ] = set.keys.to_s.include?("skylightjamb")
        is[:spandrel        ] = set.keys.to_s.include?("spandrel")
        is[:corner          ] = set.keys.to_s.include?("corner")
        is[:parapet         ] = set.keys.to_s.include?("parapet")
        is[:roof            ] = set.keys.to_s.include?("roof")
        is[:ceiling         ] = set.keys.to_s.include?("ceiling")
        is[:party           ] = set.keys.to_s.include?("party")
        is[:grade           ] = set.keys.to_s.include?("grade")
        is[:balcony         ] = set.keys.to_s.include?("balcony")
        is[:balconysill     ] = set.keys.to_s.include?("balconysill")
        is[:balconydoorsill ] = set.keys.to_s.include?("balconydoorsill")
        is[:rimjoist        ] = set.keys.to_s.include?("rimjoist")

        if is.empty?
          is[:head] = set.keys.to_s.include?("head")
          is[:sill] = set.keys.to_s.include?("sill")
          is[:jamb] = set.keys.to_s.include?("jamb")
        end

        # Label edge as ...
        #         :head,         :sill,         :jamb (vertical fenestration)
        #     :doorhead,     :doorsill,     :doorjamb (opaque door)
        # :skylighthead, :skylightsill, :skylightjamb (all other cases)
        #
        # ... if linked to:
        #   1x subsurface (vertical or non-vertical)
        edge[:surfaces].keys.each do |i|
          break    if is[:head        ]
          break    if is[:sill        ]
          break    if is[:jamb        ]
          break    if is[:doorhead    ]
          break    if is[:doorsill    ]
          break    if is[:doorjamb    ]
          break    if is[:skylighthead]
          break    if is[:skylightsill]
          break    if is[:skylightjamb]
          next     if deratables.include?(i)
          next unless holes.key?(i)

          # In most cases, subsurface edges simply delineate the rough opening
          # of its base surface (here, a "gardian"). Door sills, corner windows,
          # as well as a subsurface header aligned with a plenum "floor"
          # (ceiling tiles), are common instances where a subsurface edge links
          # 2x (opaque) surfaces. Deratable surface "id" may not be the gardian
          # of subsurface "i" - the latter may be a neighbour. The single
          # surface to derate is not the gardian in such cases.
          gardian = deratables.size == 1 ? id : ""
          target  = gardian

          # Retrieve base surface's subsurfaces.
          windows   = tbd[:surfaces][id].key?(:windows)
          doors     = tbd[:surfaces][id].key?(:doors)
          skylights = tbd[:surfaces][id].key?(:skylights)

          windows   =   windows ? tbd[:surfaces][id][:windows  ] : {}
          doors     =     doors ? tbd[:surfaces][id][:doors    ] : {}
          skylights = skylights ? tbd[:surfaces][id][:skylights] : {}

          # The gardian is "id" if subsurface "ids" holds "i".
          ids = windows.keys + doors.keys + skylights.keys

          if gardian.empty?
            other = deratables.first == id ? deratables.last : deratables.first

            gardian = ids.include?(i) ? id : other
            target  = ids.include?(i) ? other : id

            windows   = tbd[:surfaces][gardian].key?(:windows)
            doors     = tbd[:surfaces][gardian].key?(:doors)
            skylights = tbd[:surfaces][gardian].key?(:skylights)

            windows   =   windows ? tbd[:surfaces][gardian][:windows  ] : {}
            doors     =     doors ? tbd[:surfaces][gardian][:doors    ] : {}
            skylights = skylights ? tbd[:surfaces][gardian][:skylights] : {}

            ids = windows.keys + doors.keys + skylights.keys
          end

          unless ids.include?(i)
            log(ERR, "Orphaned subsurface #{i} (mth)")
            next
          end

          window   =   windows.key?(i) ?   windows[i] : {}
          door     =     doors.key?(i) ?     doors[i] : {}
          skylight = skylights.key?(i) ? skylights[i] : {}

          sub = window   unless window.empty?
          sub = door     unless door.empty?
          sub = skylight unless skylight.empty?

          window = sub[:type] == :window
          door   = sub[:type] == :door
          glazed = door && sub.key?(:glazed) && sub[:glazed]

          s1      = edge[:surfaces][target]
          s2      = edge[:surfaces][i      ]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          # Subsurface edges are tagged as head, sill or jamb, regardless of
          # building PSI set subsurface-related tags. If the latter is simply
          # :fenestration, then its single PSI factor is systematically
          # assigned to e.g. a window's :head, :sill & :jamb edges.
          #
          # Additionally, concave or convex variants also inherit from the base
          # type if undefined in the PSI set.
          #
          # If a subsurface is not horizontal, TBD tags any horizontal edge as
          # either :head or :sill based on the polar angle of the subsurface
          # around the edge vs sky zenith. Otherwise, all other subsurface edges
          # are tagged as :jamb.
          if ((s2[:normal].dot(zenith)).abs - 1).abs < TOL # horizontal surface
            if glazed || window
              set[:jamb       ] = shorts[:val][:jamb       ] if flat
              set[:jambconcave] = shorts[:val][:jambconcave] if concave
              set[:jambconvex ] = shorts[:val][:jambconvex ] if convex
               is[:jamb       ] = true
            elsif door
              set[:doorjamb       ] = shorts[:val][:doorjamb       ] if flat
              set[:doorjambconcave] = shorts[:val][:doorjambconcave] if concave
              set[:doorjambconvex ] = shorts[:val][:doorjambconvex ] if convex
               is[:doorjamb       ] = true
            else
              set[:skylightjamb       ] = shorts[:val][:skylightjamb       ] if flat
              set[:skylightjambconcave] = shorts[:val][:skylightjambconcave] if concave
              set[:skylightjambconvex ] = shorts[:val][:skylightjambconvex ] if convex
               is[:skylightjamb       ] = true
            end
          else
            if glazed || window
              if edge[:horizontal]
                if s2[:polar].dot(zenith) < 0
                  set[:head       ] = shorts[:val][:head       ] if flat
                  set[:headconcave] = shorts[:val][:headconcave] if concave
                  set[:headconvex ] = shorts[:val][:headconvex ] if convex
                   is[:head       ] = true
                else
                  set[:sill       ] = shorts[:val][:sill       ] if flat
                  set[:sillconcave] = shorts[:val][:sillconcave] if concave
                  set[:sillconvex ] = shorts[:val][:sillconvex ] if convex
                   is[:sill       ] = true
                end
              else
                set[:jamb       ] = shorts[:val][:jamb       ] if flat
                set[:jambconcave] = shorts[:val][:jambconcave] if concave
                set[:jambconvex ] = shorts[:val][:jambconvex ] if convex
                 is[:jamb       ] = true
              end
            elsif door
              if edge[:horizontal]
                if s2[:polar].dot(zenith) < 0

                  set[:doorhead       ] = shorts[:val][:doorhead       ] if flat
                  set[:doorheadconcave] = shorts[:val][:doorheadconcave] if concave
                  set[:doorheadconvex ] = shorts[:val][:doorheadconvex ] if convex
                   is[:doorhead       ] = true
                else
                  set[:doorsill       ] = shorts[:val][:doorsill       ] if flat
                  set[:doorsillconcave] = shorts[:val][:doorsillconcave] if concave
                  set[:doorsillconvex ] = shorts[:val][:doorsillconvex ] if convex
                   is[:doorsill       ] = true
                end
              else
                set[:doorjamb       ] = shorts[:val][:doorjamb       ] if flat
                set[:doorjambconcave] = shorts[:val][:doorjambconcave] if concave
                set[:doorjambconvex ] = shorts[:val][:doorjambconvex ] if convex
                 is[:doorjamb       ] = true
              end
            else
              if edge[:horizontal]
                if s2[:polar].dot(zenith) < 0
                  set[:skylighthead       ] = shorts[:val][:skylighthead       ] if flat
                  set[:skylightheadconcave] = shorts[:val][:skylightheadconcave] if concave
                  set[:skylightheadconvex ] = shorts[:val][:skylightheadconvex ] if convex
                   is[:skylighthead       ] = true
                else
                  set[:skylightsill       ] = shorts[:val][:skylightsill       ] if flat
                  set[:skylightsillconcave] = shorts[:val][:skylightsillconcave] if concave
                  set[:skylightsillconvex ] = shorts[:val][:skylightsillconvex ] if convex
                   is[:skylightsill       ] = true
                end
              else
                set[:skylightjamb       ] = shorts[:val][:skylightjamb       ] if flat
                set[:skylightjambconcave] = shorts[:val][:skylightjambconcave] if concave
                set[:skylightjambconvex ] = shorts[:val][:skylightjambconvex ] if convex
                 is[:skylightjamb       ] = true
              end
            end
          end
        end

        # Label edge as :spandrel if linked to:
        #   1x deratable, non-spandrel wall
        #   1x deratable, spandrel wall
        edge[:surfaces].keys.each do |i|
          break     if is[:spandrel]
          break unless deratables.size == 2
          break unless walls.key?(id)
          break unless walls[id][:spandrel]
          next      if i == id
          next  unless deratables.include?(i)
          next  unless walls.key?(i)
          next      if walls[i][:spandrel]

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i ]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          set[:spandrel       ] = shorts[:val][:spandrel       ] if flat
          set[:spandrelconcave] = shorts[:val][:spandrelconcave] if concave
          set[:spandrelconvex ] = shorts[:val][:spandrelconvex ] if convex
           is[:spandrel       ] = true
        end

        # Label edge as :cornerconcave or :cornerconvex if linked to:
        #   2x deratable walls & f(relative polar wall vectors around edge)
        edge[:surfaces].keys.each do |i|
          break     if is[:corner]
          break unless deratables.size == 2
          break unless walls.key?(id)
          next      if i == id
          next  unless deratables.include?(i)
          next  unless walls.key?(i)

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)

          set[:cornerconcave] = shorts[:val][:cornerconcave] if concave
          set[:cornerconvex ] = shorts[:val][:cornerconvex ] if convex
           is[:corner       ] = true
        end

        # Label edge as :ceiling if linked to:
        #   +1 deratable surface(s)
        #   1x underatable CONDITIONED floor linked to an unoccupied space
        #   1x adjacent CONDITIONED ceiling linked to an occupied space
        edge[:surfaces].keys.each do |i|
          break     if is[:ceiling]
          break unless deratables.size > 0
          break     if floors.key?(id)
          next      if i == id
          next  unless floors.key?(i)
          next      if floors[i][:ground     ]
          next  unless floors[i][:conditioned]
          next      if floors[i][:occupied   ]

          ceiling = floors[i][:boundary]
          next unless ceilings.key?(ceiling)
          next unless ceilings[ceiling][:conditioned]
          next unless ceilings[ceiling][:occupied   ]

          other = deratables.first unless deratables.first == id
          other = deratables.last  unless deratables.last  == id
          other = id                   if deratables.size  == 1

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][other]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          set[:ceiling       ] = shorts[:val][:ceiling       ] if flat
          set[:ceilingconcave] = shorts[:val][:ceilingconcave] if concave
          set[:ceilingconvex ] = shorts[:val][:ceilingconvex ] if convex
           is[:ceiling       ] = true
        end

        # Label edge as :parapet/:roof if linked to:
        #   1x deratable wall
        #   1x deratable ceiling
        edge[:surfaces].keys.each do |i|
          break     if is[:parapet]
          break     if is[:roof   ]
          break unless deratables.size == 2
          break unless ceilings.key?(id)
          next      if i == id
          next  unless deratables.include?(i)
          next  unless walls.key?(i)

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i ]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          if argh[:parapet]
            set[:parapet       ] = shorts[:val][:parapet       ] if flat
            set[:parapetconcave] = shorts[:val][:parapetconcave] if concave
            set[:parapetconvex ] = shorts[:val][:parapetconvex ] if convex
             is[:parapet       ] = true
          else
            set[:roof       ] = shorts[:val][:roof       ] if flat
            set[:roofconcave] = shorts[:val][:roofconcave] if concave
            set[:roofconvex ] = shorts[:val][:roofconvex ] if convex
             is[:roof       ] = true
          end
        end

        # Label edge as :party if linked to:
        #   1x OtherSideCoefficients surface
        #   1x (only) deratable surface
        edge[:surfaces].keys.each do |i|
          break     if is[:party]
          break unless deratables.size == 1
          next      if i == id
          next  unless tbd[:surfaces].key?(i)
          next      if holes.key?(i)
          next      if shades.key?(i)

          facing = tbd[:surfaces][i][:boundary].downcase
          next unless facing == "othersidecoefficients"

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i ]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          set[:party       ] = shorts[:val][:party       ] if flat
          set[:partyconcave] = shorts[:val][:partyconcave] if concave
          set[:partyconvex ] = shorts[:val][:partyconvex ] if convex
           is[:party       ] = true
        end

        # Label edge as :grade if linked to:
        #   1x surface (e.g. slab or wall) facing ground
        #   1x surface (i.e. wall) facing outdoors
        edge[:surfaces].keys.each do |i|
          break     if is[:grade]
          break unless deratables.size == 1
          next      if i == id
          next  unless tbd[:surfaces].key?(i)
          next  unless tbd[:surfaces][i].key?(:ground)
          next  unless tbd[:surfaces][i][:ground]

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          set[:grade       ] = shorts[:val][:grade       ] if flat
          set[:gradeconcave] = shorts[:val][:gradeconcave] if concave
          set[:gradeconvex ] = shorts[:val][:gradeconvex ] if convex
           is[:grade       ] = true
        end

        # Label edge as :rimjoist, :balcony, :balconysill or :balconydoorsill,
        # if linked to:
        #   1x deratable surface
        #   1x CONDITIONED floor
        #   1x shade (optional)
        #   1x subsurface (optional)
        balcony         = false
        balconysill     = false # vertical fenestration
        balconydoorsill = false # opaque door

        # Despite referring to 'sill' or 'doorsill', a 'balconysill' or
        # 'balconydoorsill' edge may instead link (rarer) cases of balcony and a
        # fenestration/door head. ASHRAE 90.1 2022 does not make the distinction
        # between sill vs head when intermediate floor, balcony and vertical
        # fenestration meet. 'Sills' are simply the most common occurrence.
        edge[:surfaces].keys.each do |i|
          break if is[:ceiling]
          break if balcony
          next  if i == id

          balcony = shades.key?(i)
        end

        edge[:surfaces].keys.each do |i|
          break unless balcony
          break     if balconysill
          break     if balconydoorsill
          next      if i == id
          next  unless holes.key?(i)

          # Deratable surface "id" may not be the gardian of "i" (see sills).
          gardian = deratables.size == 1 ? id : ""
          target  = gardian

          # Retrieve base surface's subsurfaces.
          windows   = tbd[:surfaces][id].key?(:windows)
          doors     = tbd[:surfaces][id].key?(:doors)
          skylights = tbd[:surfaces][id].key?(:skylights)

          windows   =   windows ? tbd[:surfaces][id][:windows  ] : {}
          doors     =     doors ? tbd[:surfaces][id][:doors    ] : {}
          skylights = skylights ? tbd[:surfaces][id][:skylights] : {}

          # The gardian is "id" if subsurface "ids" holds "i".
          ids = windows.keys + doors.keys + skylights.keys

          if gardian.empty?
            other = deratables.first == id ? deratables.last : deratables.first

            gardian = ids.include?(i) ? id : other
            target  = ids.include?(i) ? other : id

            windows   = tbd[:surfaces][gardian].key?(:windows)
            doors     = tbd[:surfaces][gardian].key?(:doors)
            skylights = tbd[:surfaces][gardian].key?(:skylights)

            windows   =   windows ? tbd[:surfaces][gardian][:windows  ] : {}
            doors     =     doors ? tbd[:surfaces][gardian][:doors    ] : {}
            skylights = skylights ? tbd[:surfaces][gardian][:skylights] : {}

            ids = windows.keys + doors.keys + skylights.keys
          end

          unless ids.include?(i)
            log(ERR, "Balcony sill: orphaned subsurface #{i} (mth)")
            next
          end

          window   =   windows.key?(i) ?   windows[i] : {}
          door     =     doors.key?(i) ?     doors[i] : {}
          skylight = skylights.key?(i) ? skylights[i] : {}

          sub = window   unless window.empty?
          sub = door     unless door.empty?
          sub = skylight unless skylight.empty?

          window = sub[:type] == :window
          door   = sub[:type] == :door
          glazed = door && sub.key?(:glazed) && sub[:glazed]

          if window || glazed
            balconysill = true
          elsif door
            balconydoorsill = true
          end
        end

        edge[:surfaces].keys.each do |i|
          break     if is[:ceiling        ]
          break     if is[:rimjoist       ]
          break     if is[:balcony        ]
          break     if is[:balconysill    ]
          break     if is[:balconydoorsill]
          break unless deratables.size > 0
          break     if floors.key?(id)
          next      if i == id
          next  unless floors.key?(i)
          next      if floors[i][:ground     ]
          next  unless floors[i][:conditioned]

          other = deratables.first unless deratables.first == id
          other = deratables.last  unless deratables.last  == id
          other = id                   if deratables.size  == 1

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][other]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          if balconydoorsill
            set[:balconydoorsill       ] = shorts[:val][:balconydoorsill       ] if flat
            set[:balconydoorsillconcave] = shorts[:val][:balconydoorsillconcave] if concave
            set[:balconydoorsillconvex ] = shorts[:val][:balconydoorsillconvex ] if convex
             is[:balconydoorsill       ] = true
          elsif balconysill
            set[:balconysill           ] = shorts[:val][:balconysill           ] if flat
            set[:balconysillconcave    ] = shorts[:val][:balconysillconcave    ] if concave
            set[:balconysillconvex     ] = shorts[:val][:balconysillconvex     ] if convex
             is[:balconysill           ] = true
          elsif balcony
            set[:balcony               ] = shorts[:val][:balcony               ] if flat
            set[:balconyconcave        ] = shorts[:val][:balconyconcave        ] if concave
            set[:balconyconvex         ] = shorts[:val][:balconyconvex         ] if convex
             is[:balcony               ] = true
          else
            set[:rimjoist              ] = shorts[:val][:rimjoist              ] if flat
            set[:rimjoistconcave       ] = shorts[:val][:rimjoistconcave       ] if concave
            set[:rimjoistconvex        ] = shorts[:val][:rimjoistconvex        ] if convex
             is[:rimjoist              ] = true
          end
        end
      end # edge's surfaces loop

      edge[:psi] = set unless set.empty?
      edge[:set] = psi unless set.empty?
    end # edge loop

    # Tracking (mild) transitions between deratable surfaces around edges that
    # have not been previously tagged.
    edges.values.each do |edge|
      deratable = false
      next     if edge.key?(:psi)
      next unless edge.key?(:surfaces)

      edge[:surfaces].keys.each do |id|
        next unless tbd[:surfaces].key?(id)
        next unless tbd[:surfaces][id][:deratable]

        deratable = tbd[:surfaces][id][:deratable]
      end

      next unless deratable

      edge[:psi] = { transition: 0.000 }
      edge[:set] = json[:io][:building][:psi]
    end

    # 'Unhinged' subsurfaces, like Tubular Daylight Device (TDD) domes,
    # usually don't share edges with parent surfaces, e.g. floating 300mm above
    # parent roof surface. Add parent surface ID to unhinged edges.
    edges.values.each do |edge|
      next     if edge.key?(:psi)
      next unless edge.key?(:surfaces)
      next unless edge[:surfaces].size == 1

      id        = edge[:surfaces].first.first
      next unless holes.key?(id)
      next unless holes[id].attributes.key?(:unhinged)
      next unless holes[id].attributes[:unhinged]

      subsurface = model.getSubSurfaceByName(id)
      next      if subsurface.empty?

      subsurface = subsurface.get
      surface    = subsurface.surface
      next      if surface.empty?

      nom        = surface.get.nameString
      next  unless tbd[:surfaces].key?(nom)
      next  unless tbd[:surfaces][nom].key?(:conditioned)
      next  unless tbd[:surfaces][nom][:conditioned]

      edge[:surfaces][nom] = {}

      set        = {}
      set[:jamb] = shorts[:val][:jamb]
      edge[:psi] = set
      edge[:set] = json[:io][:building][:psi]
    end

    if json[:io]
      # Reset subsurface U-factors (if on file).
      if json[:io].key?(:subsurfaces)
        json[:io][:subsurfaces].each do |sub|
          match = false
          next unless sub.key?(:id)
          next unless sub.key?(:usi)

          tbd[:surfaces].values.each do |surface|
            break if match

            [:windows, :doors, :skylights].each do |types|
              break    if match
              next unless surface.key?(types)

              surface[types].each do |id, opening|
                break    if match
                next unless opening.key?(:u)
                next unless sub[:id] == id

                opening[:u] = sub[:usi]
                match       = true
              end
            end
          end
        end
      end

      # Reset wall-to-roof intersection type (if on file) ... per group.
      [:stories, :spacetypes, :spaces].each do |groups|
        key = :story
        key = :stype if groups == :spacetypes
        key = :space if groups == :spaces
        next unless json[:io].key?(groups)

        json[:io][groups].each do |group|
          next unless group.key?(:id)
          next unless group.key?(:parapet)

          edges.values.each do |edge|
            match = false
            next unless edge.key?(:psi)
            next unless edge.key?(:surfaces)
            next     if edge.key?(:io_type)

            edge[:surfaces].keys.each do |id|
              break    if match
              next unless tbd[:surfaces].key?(id)
              next unless tbd[:surfaces][id].key?(key)

              match = group[:id] == tbd[:surfaces][id][key].nameString
            end

            next unless match

            parapets = edge[:psi].keys.select {|ty| ty.to_s.include?("parapet")}
            roofs    = edge[:psi].keys.select {|ty| ty.to_s.include?("roof")}

            if group[:parapet]
              next unless parapets.empty?
              next     if roofs.empty?

              type = :parapet
              type = :parapetconcave if roofs.first.to_s.include?("concave")
              type = :parapetconvex  if roofs.first.to_s.include?("convex")

              edge[:psi][type] = shorts[:val][type]
              roofs.each {|ty| edge[:psi].delete(ty)}
            else
              next unless roofs.empty?
              next     if parapets.empty?

              type = :roof
              type = :roofconcave if parapets.first.to_s.include?("concave")
              type = :roofconvex  if parapets.first.to_s.include?("convex")

              edge[:psi][type] = shorts[:val][type]

              parapets.each { |ty| edge[:psi].delete(ty) }
            end
          end
        end
      end

      # Reset wall-to-roof intersection type (if on file) - individual surfaces.
      if json[:io].key?(:surfaces)
        json[:io][:surfaces].each do |surface|
          next unless surface.key?(:parapet)
          next unless surface.key?(:id)

          edges.values.each do |edge|
            next     if edge.key?(:io_type)
            next unless edge.key?(:psi)
            next unless edge.key?(:surfaces)
            next unless edge[:surfaces].keys.include?(surface[:id])

            parapets = edge[:psi].keys.select {|ty| ty.to_s.include?("parapet")}
            roofs    = edge[:psi].keys.select {|ty| ty.to_s.include?("roof")}


            if surface[:parapet]
              next unless parapets.empty?
              next     if roofs.empty?

              type = :parapet
              type = :parapetconcave if roofs.first.to_s.include?("concave")
              type = :parapetconvex  if roofs.first.to_s.include?("convex")

              edge[:psi][type] = shorts[:val][type]
              roofs.each {|ty| edge[:psi].delete(ty)}
            else
              next unless roofs.empty?
              next     if parapets.empty?

              type = :roof
              type = :roofconcave if parapets.first.to_s.include?("concave")
              type = :roofconvex  if parapets.first.to_s.include?("convex")

              edge[:psi][type] = shorts[:val][type]
              parapets.each {|ty| edge[:psi].delete(ty)}
            end
          end
        end
      end

      # A priori, TBD applies (default) :building PSI types and values to
      # individual edges. If a TBD JSON input file holds custom PSI sets for:
      #   :stories
      #   :spacetypes
      #   :surfaces
      #   :edges
      # ... that may apply to individual edges, then the default :building PSI
      # types and/or values are overridden, as follows:
      #   custom :stories    PSI sets trump :building PSI sets
      #   custom :spacetypes PSI sets trump aforementioned PSI sets
      #   custom :spaces     PSI sets trump aforementioned PSI sets
      #   custom :surfaces   PSI sets trump aforementioned PSI sets
      #   custom :edges      PSI sets trump aforementioned PSI sets
      [:stories, :spacetypes, :spaces].each do |groups|
        key = :story
        key = :stype if groups == :spacetypes
        key = :space if groups == :spaces
        next unless json[:io].key?(groups)

        json[:io][groups].each do |group|
          next unless group.key?(:id)
          next unless group.key?(:psi)
          next unless json[:psi].set.key?(group[:psi])

          sh = json[:psi].shorthands(group[:psi])
          next if sh[:val].empty?

          edges.values.each do |edge|
            match = false
            next unless edge.key?(:psi)
            next unless edge.key?(:surfaces)
            next     if edge.key?(:io_set)

            edge[:surfaces].keys.each do |id|
              break    if match
              next unless tbd[:surfaces].key?(id)
              next unless tbd[:surfaces][id].key?(key)

              match = group[:id] == tbd[:surfaces][id][key].nameString
            end

            next unless match

            set                       = {}
            edge[groups]              = {} unless edge.key?(groups)
            edge[groups][group[:psi]] = {}

            if edge.key?(:io_type)
              safer = json[:psi].safe(group[:psi], edge[:io_type])
              set[edge[:io_type]] = sh[:val][safer] if safer
            else
              edge[:psi].keys.each do |type|
                safer = json[:psi].safe(group[:psi], type)
                set[type] = sh[:val][safer] if safer
              end
            end

            edge[groups][group[:psi]] = set unless set.empty?
          end
        end

        # TBD/Topolys edges will generally be linked to more than one surface
        # and hence to more than one group. It is possible for a TBD JSON file
        # to hold 2x group PSI sets that end up targetting one or more edges
        # common to both groups. In such cases, TBD retains the most conductive
        # PSI type/value from either group PSI set.
        edges.values.each do |edge|
          next unless edge.key?(:psi)
          next unless edge.key?(groups)

          edge[:psi].keys.each do |type|
            vals = {}

            edge[groups].keys.each do |set|
              sh = json[:psi].shorthands(set)
              next if sh[:val].empty?

              safer     = json[:psi].safe(set, type)
              vals[set] = sh[:val][safer] if safer
            end

            next if vals.empty?

            edge[:psi ][type] = vals.values.max
            edge[:sets]       = {} unless edge.key?(:sets)
            edge[:sets][type] = vals.key(vals.values.max)
          end
        end
      end

      if json[:io].key?(:surfaces)
        json[:io][:surfaces].each do |surface|
          next unless surface.key?(:psi)
          next unless surface.key?(:id)
          next unless tbd[:surfaces].key?(surface[:id ])
          next unless json[:psi].set.key?(surface[:psi])

          sh = json[:psi].shorthands(surface[:psi])
          next if sh[:val].empty?

          edges.values.each do |edge|
            next     if edge.key?(:io_set)
            next unless edge.key?(:psi)
            next unless edge.key?(:surfaces)
            next unless edge[:surfaces].keys.include?(surface[:id])

            s   = edge[:surfaces][surface[:id]]
            set = {}

            if edge.key?(:io_type)
              safer = json[:psi].safe(surface[:psi], edge[:io_type])
              set[:io_type] = sh[:val][safer] if safer
            else
              edge[:psi].keys.each do |type|
                safer = json[:psi].safe(surface[:psi], type)
                set[type] = sh[:val][safer] if safer
              end
            end

            next if set.empty?

            s[:psi] = set
            s[:set] = surface[:psi]
          end
        end

        # TBD/Topolys edges will generally be linked to more than one surface. A
        # TBD JSON file may hold 2x surface PSI sets that target a shared edge.
        # TBD retains the most conductive PSI type/value from either set.
        edges.values.each do |edge|
          next unless edge.key?(:psi)
          next unless edge.key?(:surfaces)

          edge[:psi].keys.each do |type|
            vals = {}

            edge[:surfaces].each do |id, s|
              next unless s.key?(:psi)
              next unless s.key?(:set)
              next     if s[:set].empty?

              sh = json[:psi].shorthands(s[:set])
              next if sh[:val].empty?

              safer         = json[:psi].safe(s[:set], type)
              vals[s[:set]] = sh[:val][safer] if safer
            end

            next if vals.empty?

            edge[:psi ][type] = vals.values.max
            edge[:sets]       = {} unless edge.key?(:sets)
            edge[:sets][type] = vals.key(vals.values.max)
          end
        end
      end

      # Loop through all customized edges on file w/w/o a custom PSI set.
      edges.values.each do |edge|
        next unless edge.key?(:psi)
        next unless edge.key?(:io_type)
        next unless edge.key?(:surfaces)

        if edge.key?(:io_set)
          next unless json[:psi].set.key?(edge[:io_set])

          set = edge[:io_set]
        else
          next unless edge[:sets].key?(edge[:io_type])
          next unless json[:psi].set.key?(edge[:sets][edge[:io_type]])

          set = edge[:sets][edge[:io_type]]
        end

        sh = json[:psi].shorthands(set)
        next if sh[:val].empty?

        safer = json[:psi].safe(set, edge[:io_type])
        next unless safer

        if edge.key?(:io_set)
          edge[:psi] = {}
          edge[:set] = edge[:io_set]
        else
          edge[:sets] = {} unless edge.key?(:sets)
          edge[:sets][edge[:io_type]] = sh[:val][safer]
        end

        edge[:psi][edge[:io_type]] = sh[:val][safer]
      end
    end

    # Fetch edge multipliers for subsurfaces, if applicable.
    edges.values.each do |edge|
      next     if edge.key?(:mult) # skip if already assigned
      next unless edge.key?(:surfaces)
      next unless edge.key?(:psi)

      ok = false

      edge[:psi].keys.each do |k|
        break if ok

        jamb = k.to_s.include?("jamb")
        sill = k.to_s.include?("sill")
        head = k.to_s.include?("head")
        ok   = jamb || sill || head
      end

      next unless ok  # if OK, edge links subsurface(s) ... yet which one(s)?

      edge[:surfaces].each do |id, surface|
        next unless tbd[:surfaces].key?(id) # look up parent (opaque) surface

        [:windows, :doors, :skylights].each do |subtypes|
          next unless tbd[:surfaces][id].key?(subtypes)

          tbd[:surfaces][id][subtypes].each do |nom, sub|
            next unless edge[:surfaces].key?(nom)
            next unless sub[:mult] > 1

            # An edge may be tagged with (potentially conflicting) multipliers.
            # This is only possible if the edge links 2 subsurfaces, e.g. a
            # shared jamb between window & door. By default, TBD tags common
            # subsurface edges as (mild) "transitions" (i.e. PSI 0 W/K•m), so
            # there would be no point in assigning an edge multiplier. Users
            # can however reset an edge type via a TBD JSON input file (e.g.
            # "joint" instead of "transition"). It would be a very odd choice,
            # but TBD doesn't prohibit it. If linked subsurfaces have different
            # multipliers (e.g. 2 vs 3), TBD tracks the highest value.
            edge[:mult] = sub[:mult] unless edge.key?(:mult)
            edge[:mult] = sub[:mult]     if sub[:mult] > edge[:mult]
          end
        end
      end
    end

    # Unless a user has set the thermal bridge type of an individual edge via
    # JSON input, reset any subsurface's head, sill or jamb edges as (mild)
    # transitions when in close proximity to another subsurface edge. Both
    # edges' origin and terminal vertices must be in close proximity. Edges
    # of unhinged subsurfaces are ignored.
    edges.each do |id, edge|
      nb    = 0 # linked subsurfaces (i.e. "holes")
      match = false
      next if edge.key?(:io_type) # skip if set in JSON
      next unless edge.key?(:v0)
      next unless edge.key?(:v1)
      next unless edge.key?(:psi)
      next unless edge.key?(:surfaces)

      edge[:surfaces].keys.each do |identifier|
        break    if match
        next unless holes.key?(identifier)

        if holes[identifier].attributes.key?(:unhinged)
          nb = 0 if holes[identifier].attributes[:unhinged]
          break  if holes[identifier].attributes[:unhinged]
        end

        nb += 1
        match = true if nb > 1
      end

      if nb == 1 # linking 1x subsurface, search for 1x other.
        e1 = { v0: edge[:v0].point, v1: edge[:v1].point }

        edges.each do |nom, e|
          nb = 0
          break    if match
          next     if nom == id
          next     if e.key?(:io_type)
          next unless e.key?(:psi)
          next unless e.key?(:surfaces)

          e[:surfaces].keys.each do |identifier|
            next unless holes.key?(identifier)

            if holes[identifier].attributes.key?(:unhinged)
              nb = 0 if holes[identifier].attributes[:unhinged]
              break  if holes[identifier].attributes[:unhinged]
            end

            nb += 1
          end

          next unless nb == 1 # only process edge if linking 1x subsurface

          e2 = { v0: e[:v0].point, v1: e[:v1].point }
          match = matches?(e1, e2, argh[:sub_tol])
        end
      end

      next unless match

      edge[:psi] = { transition: 0.000 }
      edge[:set] = json[:io][:building][:psi]
    end

    # Loop through each edge and assign heat loss to linked surfaces.
    edges.each do |identifier, edge|
      next unless  edge.key?(:psi)

      rsi        = 0
      max        = edge[:psi   ].values.max
      type       = edge[:psi   ].key(max)
      length     = edge[:length]
      length    *= edge[:mult  ] if edge.key?(:mult)
      bridge     = { psi: max, type: type, length: length }
      deratables = {}
      apertures  = {}

      if edge.key?(:sets) && edge[:sets].key?(type)
        edge[:set] = edge[:sets][type] unless edge.key?(:io_set)
      end

      # Retrieve valid linked surfaces as deratables.
      edge[:surfaces].each do |id, s|
        next unless tbd[:surfaces].key?(id)
        next unless tbd[:surfaces][id][:deratable]

        deratables[id] = s
      end

      edge[:surfaces].each { |id, s| apertures[id] = s if holes.key?(id) }
      next if apertures.size > 1 # edge links 2x openings

      # Prune dad if edge links an opening, its dad and an uncle.
      if deratables.size > 1 && apertures.size > 0
        deratables.each do |id, deratable|
          [:windows, :doors, :skylights].each do |types|
            next unless tbd[:surfaces][id].key?(types)

            tbd[:surfaces][id][types].keys.each do |sub|
              deratables.delete(id) if apertures.key?(sub)
            end
          end
        end
      end

      next if deratables.empty?

      # Sum RSI of targeted insulating layer from each deratable surface.
      deratables.each do |id, deratable|
        next unless tbd[:surfaces][id].key?(:r)

        rsi += tbd[:surfaces][id][:r]
      end

      # Assign heat loss from thermal bridges to surfaces, in proportion to
      # insulating layer thermal resistance.
      deratables.each do |id, deratable|
        ratio = 0
        ratio = tbd[:surfaces][id][:r] / rsi if rsi > 0.001
        loss  = bridge[:psi] * ratio
        b     = { psi: loss, type: bridge[:type], length: length, ratio: ratio }
        tbd[:surfaces][id][:edges] = {} unless tbd[:surfaces][id].key?(:edges)
        tbd[:surfaces][id][:edges][identifier] = b
      end
    end

    # Assign thermal bridging heat loss [in W/K] to each deratable surface.
    tbd[:surfaces].each do |id, surface|
      next unless surface.key?(:edges)

      surface[:heatloss] = 0
      e = surface[:edges].values

      e.each { |edge| surface[:heatloss] += edge[:psi] * edge[:length] }
    end

    # Add point conductances (W/K x count), in TBD JSON file (under surfaces).
    tbd[:surfaces].each do |id, s|
      next unless s[:deratable]
      next unless json[:io]
      next unless json[:io].key?(:surfaces)

      json[:io][:surfaces].each do |surface|
        next unless surface.key?(:khis)
        next unless surface.key?(:id)
        next unless surface[:id] == id

        surface[:khis].each do |k|
          next unless k.key?(:id)
          next unless k.key?(:count)
          next unless json[:khi].point.key?(k[:id])
          next unless json[:khi].point[k[:id]] > 0.001

          s[:heatloss]  = 0 unless s.key?(:heatloss)
          s[:heatloss] += json[:khi].point[k[:id]] * k[:count]
          s[:pts     ]  = {} unless s.key?(:pts)

          s[:pts][k[:id]] = { val: json[:khi].point[k[:id]], n: k[:count] }
        end
      end
    end

    # If user has selected a Ut to meet, e.g. argh'ments:
    #   :uprate_walls
    #   :wall_ut
    #   :wall_option ... (same triple arguments for roofs and exposed floors)
    #
    # ... first 'uprate' targeted insulation layers (see ua.rb) before derating.
    # Check for new argh keys [:wall_uo], [:roof_uo] and/or [:floor_uo].
    up = argh[:uprate_walls] || argh[:uprate_roofs] || argh[:uprate_floors]
    uprate(model, tbd[:surfaces], argh) if up

    # Derated (cloned) constructions are unique to each deratable surface.
    # Unique construction names are prefixed with the surface name,
    # and suffixed with " tbd", indicating that the construction is
    # henceforth thermally derated. The " tbd" expression is also key in
    # avoiding inadvertent derating - TBD will not derate constructions
    # (or rather layered materials) having " tbd" in their OpenStudio name.
    tbd[:surfaces].each do |id, surface|
      next unless surface.key?(:construction)
      next unless surface.key?(:index)
      next unless surface.key?(:ltype)
      next unless surface.key?(:r)
      next unless surface.key?(:edges)
      next unless surface.key?(:heatloss)
      next unless surface[:heatloss].abs > TOL

      s = model.getSurfaceByName(id)
      next if s.empty?

      s = s.get

      index     = surface[:index       ]
      current_c = surface[:construction]
      c         = current_c.clone(model).to_LayeredConstruction.get
      m         = nil
      m         = derate(id, surface, c) if index
      # m may be nilled simply because the targeted construction has already
      # been derated, i.e. holds " tbd" in its name. Names of cloned/derated
      # constructions (due to TBD) include the surface name (since derated
      # constructions are now unique to each surface) and the suffix " c tbd".
      if m
        c.setLayer(index, m)
        c.setName("#{id} c tbd")
        current_R = rsi(current_c, s.filmResistance)

        # In principle, the derated "ratio" could be calculated simply by
        # accessing a surface's uFactor. Yet air layers within constructions
        # (not air films) are ignored in OpenStudio's uFactor calculation.
        # An example would be 25mm-50mm pressure-equalized air gaps behind
        # brick veneer. This is not always compliant to some energy codes.
        # TBD currently factors-in air gap (and exterior cladding) R-values.
        #
        # If one comments out the following loop (3 lines), tested surfaces
        # with air layers will generate discrepencies between the calculed RSi
        # value above and the inverse of the uFactor. All other surface
        # constructions pass the test.
        #
        # if ((1/current_R) - s.uFactor.to_f).abs > 0.005
        #   puts "#{s.nameString} - Usi:#{1/current_R} UFactor: #{s.uFactor}"
        # end
        s.setConstruction(c)

        # If the derated surface construction separates CONDITIONED space from
        # UNCONDITIONED or UNENCLOSED space, then derate the adjacent surface
        # construction as well (unless defaulted).
        if s.outsideBoundaryCondition.downcase == "surface"
          unless s.adjacentSurface.empty?
            adjacent = s.adjacentSurface.get
            nom      = adjacent.nameString
            default  = adjacent.isConstructionDefaulted == false

            if default  && tbd[:surfaces].key?(nom)
              current_cc = tbd[:surfaces][nom][:construction]
              cc         = current_cc.clone(model).to_LayeredConstruction.get
              cc.setLayer(tbd[:surfaces][nom][:index], m)
              cc.setName("#{nom} c tbd")
              adjacent.setConstruction(cc)
            end
          end
        end

        # Compute updated RSi value from layers.
        updated_c = s.construction.get.to_LayeredConstruction.get
        updated_R = rsi(updated_c, s.filmResistance)
        ratio     = -(current_R - updated_R) * 100 / current_R

        surface[:ratio] = ratio if ratio.abs > TOL
        surface[:u    ] = 1 / current_R # un-derated U-factors (for UA')
      end
    end

    # Ensure deratable surfaces have U-factors (even if NOT derated).
    tbd[:surfaces].each do |id, surface|
      next unless surface[:deratable]
      next unless surface.key?(:construction)
      next     if surface.key?(:u)

      s   = model.getSurfaceByName(id)
      msg = "Skipping missing surface '#{id}' (#{mth})"
      log(ERR, msg) if s.empty?
      next          if s.empty?

      surface[:u] = 1.0 / rsi(surface[:construction], s.get.filmResistance)
    end

    json[:io][:edges] = []
    # Enrich io with TBD/Topolys edge info before returning:
    #   1. edge custom PSI set, if on file
    #   2. edge PSI type
    #   3. edge length (m)
    #   4. edge origin & end vertices
    #   5. array of linked outside- or ground-facing surfaces
    edges.values.each do |e|
      next unless e.key?(:psi)
      next unless e.key?(:set)

      v    = e[:psi].values.max
      set  = e[:set]
      t    = e[:psi].key(v)
      l    = e[:length]
      l   *= e[:mult] if e.key?(:mult)
      edge = { psi: set, type: t, length: l, surfaces: e[:surfaces].keys }

      edge[:v0x] = e[:v0].point.x
      edge[:v0y] = e[:v0].point.y
      edge[:v0z] = e[:v0].point.z
      edge[:v1x] = e[:v1].point.x
      edge[:v1y] = e[:v1].point.y
      edge[:v1z] = e[:v1].point.z

      json[:io][:edges] << edge
    end

    if json[:io][:edges].empty?
      json[:io].delete(:edges)
    else
      json[:io][:edges].sort_by { |e| [ e[:v0x], e[:v0y], e[:v0z],
                                        e[:v1x], e[:v1y], e[:v1z] ] }
    end

    # Populate UA' trade-off reference values (optional).
    if argh[:gen_ua] && argh[:ua_ref]
      case argh[:ua_ref]
      when "code (Quebec)"
        qc33(tbd[:surfaces], json[:psi], argh[:setpoints])
      end
    end

    tbd[:io       ] = json[:io     ]
    argh[:io      ] = tbd[:io      ]
    argh[:surfaces] = tbd[:surfaces]
    argh[:version ] = model.getVersion.versionIdentifier

    tbd
  end

  ##
  # Exits TBD Measures. Writes out TBD model content and results if requested.
  # Always writes out minimal logs (see "tbd.out.json" file).
  #
  # @param runner [Runner] OpenStudio Measure runner
  # @param [Hash] argh TBD arguments
  # @option argh [Hash] :io TBD input/output variables (see TBD JSON schema)
  # @option argh [Hash] :surfaces TBD surfaces (keys: Openstudio surface names)
  # @option argh [#to_s] :seed OpenStudio file, e.g. "school23.osm"
  # @option argh [#to_s] :version :version OpenStudio SDK, e.g. "3.6.1"
  # @option argh [Bool] :gen_ua whether to generate a UA' report
  # @option argh [#to_s] :ua_ref selected UA' ruleset
  # @option argh [Bool] :setpoints whether OpenStudio model holds setpoints
  # @option argh [Bool] :write_tbd whether to output a JSON file
  # @option argh [Bool] :uprate_walls whether to uprate walls
  # @option argh [Bool] :uprate_roofs whether to uprate roofs
  # @option argh [Bool] :uprate_floors whether to uprate floors
  # @option argh [#to_f] :wall_ut uprated wall Ut target in W/m2•K
  # @option argh [#to_f] :roof_ut uprated roof Ut target in W/m2•K
  # @option argh [#to_f] :floor_ut uprated floor Ut target in W/m2•K
  # @option argh [#to_s] :wall_option wall construction to uprate (or "all")
  # @option argh [#to_s] :roof_option roof construction to uprate (or "all")
  # @option argh [#to_s] :floor_option floor construction to uprate (or "all")
  # @option argh [#to_f] :wall_uo required wall Uo to achieve Ut in W/m2•K
  # @option argh [#to_f] :roof_uo required roof Uo to achieve Ut in W/m2•K
  # @option argh [#to_f] :floor_uo required floor Uo to achieve Ut in W/m2•K
  #
  # @return [Bool] whether TBD Measure is successful (see logs)
  def exit(runner = nil, argh = {})
    # Generated files target a design context ( >= WARN ) ... change TBD log
    # level for debugging purposes. By default, log status is set < DBG
    # while log level is set @INF.
    groups = { wall: {}, roof: {}, floor: {} }
    state  = msg(status)
    state  = msg(INF)         if status.zero?
    argh            = {}  unless argh.is_a?(Hash)
    argh[:io      ] = nil unless argh.key?(:io)
    argh[:surfaces] = nil unless argh.key?(:surfaces)

    unless argh[:io] && argh[:surfaces]
      state = "Halting all TBD processes, yet running OpenStudio"
      state = "Halting all TBD processes, and halting OpenStudio" if fatal?
    end

    argh[:io           ] = {}    unless argh[:io]
    argh[:seed         ] = ""    unless argh.key?(:seed         )
    argh[:version      ] = ""    unless argh.key?(:version      )
    argh[:gen_ua       ] = false unless argh.key?(:gen_ua       )
    argh[:ua_ref       ] = ""    unless argh.key?(:ua_ref       )
    argh[:setpoints    ] = false unless argh.key?(:setpoints    )
    argh[:write_tbd    ] = false unless argh.key?(:write_tbd    )
    argh[:uprate_walls ] = false unless argh.key?(:uprate_walls )
    argh[:uprate_roofs ] = false unless argh.key?(:uprate_roofs )
    argh[:uprate_floors] = false unless argh.key?(:uprate_floors)
    argh[:wall_ut      ] = 5.678 unless argh.key?(:wall_ut      )
    argh[:roof_ut      ] = 5.678 unless argh.key?(:roof_ut      )
    argh[:floor_ut     ] = 5.678 unless argh.key?(:floor_ut     )
    argh[:wall_option  ] = ""    unless argh.key?(:wall_option  )
    argh[:roof_option  ] = ""    unless argh.key?(:roof_option  )
    argh[:floor_option ] = ""    unless argh.key?(:floor_option )
    argh[:wall_uo      ] = nil   unless argh.key?(:wall_ut      )
    argh[:roof_uo      ] = nil   unless argh.key?(:roof_ut      )
    argh[:floor_uo     ] = nil   unless argh.key?(:floor_ut     )

    groups[:wall ][:up] = argh[:uprate_walls ]
    groups[:roof ][:up] = argh[:uprate_roofs ]
    groups[:floor][:up] = argh[:uprate_floors]
    groups[:wall ][:ut] = argh[:wall_ut      ]
    groups[:roof ][:ut] = argh[:roof_ut      ]
    groups[:floor][:ut] = argh[:floor_ut     ]
    groups[:wall ][:op] = argh[:wall_option  ]
    groups[:roof ][:op] = argh[:roof_option  ]
    groups[:floor][:op] = argh[:floor_option ]
    groups[:wall ][:uo] = argh[:wall_uo      ]
    groups[:roof ][:uo] = argh[:roof_uo      ]
    groups[:floor][:uo] = argh[:floor_uo     ]

    io               = argh[:io       ]
    out              = argh[:write_tbd]
    descr            = ""
    descr            = argh[:seed] unless argh[:seed].empty?
    io[:description] = descr       unless io.key?(:description)
    descr            = io[:description]

    schema_pth  = "https://github.com/rd2/tbd/blob/master/tbd.schema.json"
    io[:schema] = schema_pth unless io.key?(:schema)
    tbd_log     = { date: Time.now, status: state }
    u_t         = []

    groups.each do |label, g|
      next     if fatal?
      next unless g[:uo]
      next unless g[:uo].is_a?(Numeric)

      uo     = format("%.3f", g[:uo])
      ut     = format("%.3f", g[:ut])
      output = "An initial #{label.to_s} Uo of #{uo} W/m2•K is required to " \
               "achieve an overall Ut of #{ut} W/m2•K for #{g[:op]}"
      u_t << output
      runner.registerInfo(output)
    end

    tbd_log[:ut] = u_t unless u_t.empty?
    ua_md_en     = nil
    ua_md_fr     = nil
    ua           = nil
    ok           = argh[:surfaces] && argh[:gen_ua]
    ua           = ua_summary(tbd_log[:date], argh) if ok

    unless fatal? || ua.nil? || ua.empty?
      if ua.key?(:en)
        if ua[:en].key?(:b1) || ua[:en].key?(:b2)
          tbd_log[:ua] = {}
          runner.registerInfo("-")
          runner.registerInfo(ua[:model])
          ua_md_en = ua_md(ua, :en)
          ua_md_fr = ua_md(ua, :fr)
        end

        if ua[:en].key?(:b1) && ua[:en][:b1].key?(:summary)
          runner.registerInfo(" - #{ua[:en][:b1][:summary]}")

          ua[:en][:b1].each do |k, v|
            runner.registerInfo(" --- #{v}") unless k == :summary
          end

          tbd_log[:ua][:bloc1] = ua[:en][:b1]
        end

        if ua[:en].key?(:b2) && ua[:en][:b2].key?(:summary)
          runner.registerInfo(" - #{ua[:en][:b2][:summary]}")

          ua[:en][:b2].each do |k, v|
            runner.registerInfo(" --- #{v}") unless k == :summary
          end

          tbd_log[:ua][:bloc2] = ua[:en][:b2]
        end
      end

      runner.registerInfo(" -")
    end

    results = []

    if argh[:surfaces]
      argh[:surfaces].each do |id, surface|
        next     if fatal?
        next unless surface.key?(:ratio)

        ratio  = format("%4.1f", surface[:ratio])
        output = "RSi derated by #{ratio}% : #{id}"
        results << output
        runner.registerInfo(output)
      end
    end

    tbd_log[:results] = results unless results.empty?
    tbd_msgs = []

    logs.each do |l|
      tbd_msgs << { level: tag(l[:level]), message: l[:message] }

      runner.registerWarning(l[:message]) if l[:level] >  INF
      runner.registerInfo(l[:message])    if l[:level] <= INF
    end

    tbd_log[:messages] = tbd_msgs unless tbd_msgs.empty?
    io[:log]           = tbd_log

    # User's may not be requesting detailed output - delete non-essential items.
    io.delete(:psis      ) unless out
    io.delete(:khis      ) unless out
    io.delete(:building  ) unless out
    io.delete(:stories   ) unless out
    io.delete(:spacetypes) unless out
    io.delete(:spaces    ) unless out
    io.delete(:surfaces  ) unless out
    io.delete(:edges     ) unless out

    # Deterministic sorting
    io[:schema     ] = io.delete(:schema     ) if io.key?(:schema     )
    io[:description] = io.delete(:description) if io.key?(:description)
    io[:log        ] = io.delete(:log        ) if io.key?(:log        )
    io[:psis       ] = io.delete(:psis       ) if io.key?(:psis       )
    io[:khis       ] = io.delete(:khis       ) if io.key?(:khis       )
    io[:building   ] = io.delete(:building   ) if io.key?(:building   )
    io[:stories    ] = io.delete(:stories    ) if io.key?(:stories    )
    io[:spacetypes ] = io.delete(:spacetypes ) if io.key?(:spacetypes )
    io[:spaces     ] = io.delete(:spaces     ) if io.key?(:spaces     )
    io[:surfaces   ] = io.delete(:surfaces   ) if io.key?(:surfaces   )
    io[:edges      ] = io.delete(:edges      ) if io.key?(:edges      )

    out_dir = '.'
    file_paths = runner.workflow.absoluteFilePaths

    # 'Apply Measure Now' won't cp files from 1st path back to generated_files.
    match1 = /WorkingFiles/.match(file_paths[1].to_s.strip)
    match2 = /files/.match(file_paths[1].to_s.strip)
    match  = match1 || match2

    if file_paths.size >= 2 && File.exist?(file_paths[1].to_s.strip) && match
      out_dir = file_paths[1].to_s.strip
    elsif !file_paths.empty? && File.exist?(file_paths.first.to_s.strip)
      out_dir = file_paths.first.to_s.strip
    end

    out_path = File.join(out_dir, "tbd.out.json")

    File.open(out_path, 'w') do |file|
      file.puts JSON::pretty_generate(io)
      # Make sure data is written to the disk one way or the other.
      begin
        file.fsync
      rescue StandardError
        file.flush
      end
    end

    unless fatal? || ua.nil? || ua.empty?
      unless ua_md_en.nil? || ua_md_en.empty?
        ua_path = File.join(out_dir, "ua_en.md")

        File.open(ua_path, 'w') do |file|
          file.puts ua_md_en

          begin
            file.fsync
          rescue StandardError
            file.flush
          end
        end
      end

      unless ua_md_fr.nil? || ua_md_fr.empty?
        ua_path = File.join(out_dir, "ua_fr.md")

        File.open(ua_path, 'w') do |file|
          file.puts ua_md_fr

          begin
            file.fsync
          rescue StandardError
            file.flush
          end
        end
      end
    end

    if fatal?
      runner.registerError("#{state} - see 'tbd.out.json'")
      return false
    elsif error? || warn?
      runner.registerWarning("#{state} - see 'tbd.out.json'")
      return true
    else
      runner.registerInfo("#{state} - see 'tbd.out.json'")
      return true
    end
  end
end
