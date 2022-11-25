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
  # Sources for thermal bridge types and default KHI & PSI values/sets:
  #
  # a) BETBG = Building Envelope Thermal Bridging Guide v1.4 (or higher):
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
    # @return [Hash] KHI library
    attr_reader :point

    ##
    # Construct a new KHI library (with defaults).
    def initialize
      @point = {}

      # The following are defaults. Users may edit these defaults,
      # append new key:value pairs, or even read-in other pairs on file.
      # Units are in W/K.
      @point["poor (BETBG)"          ] = 0.900 # detail 5.7.2 BETBG
      @point["regular (BETBG)"       ] = 0.500 # detail 5.7.4 BETBG
      @point["efficient (BETBG)"     ] = 0.150 # detail 5.7.3 BETBG
      @point["code (Quebec)"         ] = 0.500 # art. 3.3.1.3. NECB-QC
      @point["uncompliant (Quebec)"  ] = 1.000 # Guide
      @point["(non thermal bridging)"] = 0.000
    end

    ##
    # Append a new KHI entry, based on a TBD JSON-formatted KHI object (requires
    # a valid, unique :id key and valid :point value).
    #
    # @param k [Hash] a new KHI entry
    #
    # @return [Bool] true if successfully appended
    # @return [Bool] false if invalid input
    def append(k = {})
      mth = "TBD::#{__callee__}"
      a   = false

      return TBD.mismatch("KHI", k, Hash, mth, DBG, a)     unless k.is_a?(Hash)
      return TBD.hashkey("KHI id", k, :id, mth, DBG, a)    unless k.key?(:id)
      return TBD.hashkey("KHI pt", k, :point, mth, DBG, a) unless k.key?(:point)

      if @point.key?(k[:id])
        TBD.log(ERR, "Skipping '#{k[:id]}': existing KHI entry (#{mth})")
        return false
      end

      @point[k[:id]] = k[:point]

      true
    end
  end

  ##
  # Library of linear thermal bridges (e.g. corners, balconies). Each key:value
  # entry requires a unique identifier e.g. "poor (BETBG)" and a (partial or
  # complete) set of PSI-values in W/K per linear meter.
  class PSI
    # @return [Hash] PSI set
    attr_reader :set

    # @return [Hash] shorthand listing of PSI types in a set
    attr_reader :has

    # @return [Hash] shorthand listing of PSI values in a set
    attr_reader :val

    ##
    # Construct a new PSI library (with defaults)
    def initialize
      @set = {}
      @has = {}
      @val = {}

      # The following are default PSI values (* published, ** calculated). Users
      # may edit these sets, add new sets here, or read-in custom sets from a
      # TBD JSON input file. PSI units are in W/K per linear meter. The spandrel
      # sets are added as practical suggestions in early design stages.

      # Convex vs concave PSI adjustments may be warranted if there is a
      # mismatch between dimensioning conventions (interior vs exterior) used
      # for the OpenStudio model (OSM) vs published PSI data. For instance, the
      # BETBG data reflects an interior dimensioning convention, while ISO
      # 14683 reports PSI values for both conventions. The following may be
      # used (with caution) to adjust BETBG PSI values for convex corners when
      # using outside dimensions for an OSM.
      #
      # PSIe = PSIi + U * 2(Li-Le), where:
      #   PSIe = adjusted PSI                                        (W/K per m)
      #   PSIi = initial published PSI                               (W/K per m)
      #      U = average clear field U-factor of adjacent walls         (W/m2.K)
      #     Li = from interior corner to edge of "zone of influence"         (m)
      #     Le = from exterior corner to edge of "zone of influence"         (m)
      #
      #  Li-Le = wall thickness e.g., -0.25m (negative here as Li < Le)
      @set["poor (BETBG)"] =
      {
        rimjoist:      1.000, # *
        parapet:       0.800, # *
        fenestration:  0.500, # *
        corner:        0.850, # *
        balcony:       1.000, # *
        party:         0.850, # *
        grade:         0.850, # *
        joint:         0.300, # *
        transition:    0.000
      }.freeze               # based on INTERIOR dimensions (p.15 BETBG)
      self.gen("poor (BETBG)")

      @set["regular (BETBG)"] =
      {
        rimjoist:      0.500, # *
        parapet:       0.450, # *
        fenestration:  0.350, # *
        corner:        0.450, # *
        balcony:       0.500, # *
        party:         0.450, # *
        grade:         0.450, # *
        joint:         0.200, # *
        transition:    0.000
      }.freeze               # based on INTERIOR dimensions (p.15 BETBG)
      self.gen("regular (BETBG)")

      @set["efficient (BETBG)"] =
      {
        rimjoist:      0.200, # *
        parapet:       0.200, # *
        fenestration:  0.200, # *
        corner:        0.200, # *
        balcony:       0.200, # *
        party:         0.200, # *
        grade:         0.200, # *
        joint:         0.100, # *
        transition:    0.000
      }.freeze               # based on INTERIOR dimensions (p.15 BETBG)
      self.gen("efficient (BETBG)")

      @set["spandrel (BETBG)"] =
      {
        rimjoist:      0.615, # * Detail 1.2.1
        parapet:       1.000, # * Detail 1.3.2
        fenestration:  0.000, # * ... generally part of clear-field RSi
        corner:        0.425, # * Detail 1.4.1
        balcony:       1.110, # * Detail 8.1.9/9.1.6
        party:         0.990, # ** ... similar to parapet/balcony
        grade:         0.880, # * Detail 2.5.1
        joint:         0.500, # * Detail 3.3.2
        transition:    0.000
      }.freeze               # "conventional", closer to window wall spandrels
      self.gen("spandrel (BETBG)")

      @set["spandrel HP (BETBG)"] =
      {
        rimjoist:      0.170, # * Detail 1.2.7
        parapet:       0.660, # * Detail 1.3.2
        fenestration:  0.000, # * ... generally part of clear-field RSi
        corner:        0.200, # * Detail 1.4.2
        balcony:       0.400, # * Detail 9.1.15
        party:         0.500, # ** ... similar to parapet/balcony
        grade:         0.880, # * Detail 2.5.1
        joint:         0.140, # * Detail 7.4.2
        transition:    0.000
      }.freeze               # "good/high performance" curtainwall spandrels
      self.gen("spandrel HP (BETBG)")

      @set["code (Quebec)"] = # NECB-QC (code-compliant) defaults:
      {
        rimjoist:      0.300, # *
        parapet:       0.325, # *
        fenestration:  0.200, # *
        corner:        0.300, # ** not explicitely stated
        balcony:       0.500, # *
        party:         0.450, # *
        grade:         0.450, # *
        joint:         0.200, # *
        transition:    0.000
      }.freeze               # based on EXTERIOR dimensions (art. 3.1.1.6)
      self.gen("code (Quebec)")

      @set["uncompliant (Quebec)"] = # NECB-QC (non-code-compliant) defaults:
      {
        rimjoist:      0.850, # *
        parapet:       0.800, # *
        fenestration:  0.500, # *
        corner:        0.850, # ** not explicitely stated
        balcony:       1.000, # *
        party:         0.850, # *
        grade:         0.850, # *
        joint:         0.500, # *
        transition:    0.000
      }.freeze               # based on EXTERIOR dimensions (art. 3.1.1.6)
      self.gen("uncompliant (Quebec)")

      @set["(non thermal bridging)"] = # ... would not derate surfaces:
      {
        rimjoist:      0.000,
        parapet:       0.000,
        fenestration:  0.000,
        corner:        0.000,
        balcony:       0.000,
        party:         0.000,
        grade:         0.000,
        joint:         0.000,
        transition:    0.000
      }.freeze
      self.gen("(non thermal bridging)")
    end

    ##
    # Generate PSI set shorthand listings (requires a valid id).
    #
    # @param id [String] a PSI set identifier
    #
    # @return [Bool] true if successful in generating PSI set shorthands
    # @return [Bool] false if invalid input
    def gen(id = "")
      mth = "TBD::#{__callee__}"
      a   = false

      return TBD.mismatch("id", id, String, mth, DBG, a) unless id.is_a?(String)
      return TBD.hashkey(id, @set, id, mth, ERR, a)      unless @set.key?(id)

      h                   = {} # true/false if PSI set has PSI type
      h[:joint          ] = @set[id].key?(:joint          )
      h[:transition     ] = @set[id].key?(:transition     )
      h[:fenestration   ] = @set[id].key?(:fenestration   )
      h[:head           ] = @set[id].key?(:head           )
      h[:headconcave    ] = @set[id].key?(:headconcave    )
      h[:headconvex     ] = @set[id].key?(:headconvex     )
      h[:sill           ] = @set[id].key?(:sill           )
      h[:sillconcave    ] = @set[id].key?(:sillconcave    )
      h[:sillconvex     ] = @set[id].key?(:sillconvex     )
      h[:jamb           ] = @set[id].key?(:jamb           )
      h[:jambconcave    ] = @set[id].key?(:jambconcave    )
      h[:jambconvex     ] = @set[id].key?(:jambconvex     )
      h[:corner         ] = @set[id].key?(:corner         )
      h[:cornerconcave  ] = @set[id].key?(:cornerconcave  )
      h[:cornerconvex   ] = @set[id].key?(:cornerconvex   )
      h[:parapet        ] = @set[id].key?(:parapet        )
      h[:partyconcave   ] = @set[id].key?(:parapetconcave )
      h[:parapetconvex  ] = @set[id].key?(:parapetconvex  )
      h[:party          ] = @set[id].key?(:party          )
      h[:partyconcave   ] = @set[id].key?(:partyconcave   )
      h[:partyconvex    ] = @set[id].key?(:partyconvex    )
      h[:grade          ] = @set[id].key?(:grade          )
      h[:gradeconcave   ] = @set[id].key?(:gradeconcave   )
      h[:gradeconvex    ] = @set[id].key?(:gradeconvex    )
      h[:balcony        ] = @set[id].key?(:balcony        )
      h[:balconyconcave ] = @set[id].key?(:balconyconcave )
      h[:balconyconvex  ] = @set[id].key?(:balconyconvex  )
      h[:rimjoist       ] = @set[id].key?(:rimjoist       )
      h[:rimjoistconcave] = @set[id].key?(:rimjoistconcave)
      h[:rimjoistconvex ] = @set[id].key?(:rimjoistconvex )
      @has[id]            = h

      v            = {} # PSI-value (W/K per linear meter)
      v[:joint   ] = 0; v[:transition     ] = 0; v[:fenestration  ] = 0
      v[:head    ] = 0; v[:headconcave    ] = 0; v[:headconvex    ] = 0
      v[:sill    ] = 0; v[:sillconcave    ] = 0; v[:sillconvex    ] = 0
      v[:jamb    ] = 0; v[:jambconcave    ] = 0; v[:jambconvex    ] = 0
      v[:corner  ] = 0; v[:cornerconcave  ] = 0; v[:cornerconvex  ] = 0
      v[:parapet ] = 0; v[:parapetconcave ] = 0; v[:parapetconvex ] = 0
      v[:party   ] = 0; v[:partyconcave   ] = 0; v[:partyconvex   ] = 0
      v[:grade   ] = 0; v[:gradeconcave   ] = 0; v[:gradeconvex   ] = 0
      v[:balcony ] = 0; v[:balconyconcave ] = 0; v[:balconyconvex ] = 0
      v[:rimjoist] = 0; v[:rimjoistconcave] = 0; v[:rimjoistconvex] = 0

      v[:joint          ] = @set[id][:joint          ] if h[:joint          ]
      v[:transition     ] = @set[id][:transition     ] if h[:transition     ]
      v[:fenestration   ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:head           ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:headconcave    ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:headconvex     ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:sill           ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:sillconcave    ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:sillconvex     ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:jamb           ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:jambconcave    ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:jambconvex     ] = @set[id][:fenestration   ] if h[:fenestration   ]
      v[:head           ] = @set[id][:head           ] if h[:head           ]
      v[:headconcave    ] = @set[id][:head           ] if h[:head           ]
      v[:headconvex     ] = @set[id][:head           ] if h[:head           ]
      v[:sill           ] = @set[id][:sill           ] if h[:sill           ]
      v[:sillconcave    ] = @set[id][:sill           ] if h[:sill           ]
      v[:sillconvex     ] = @set[id][:sill           ] if h[:sill           ]
      v[:jamb           ] = @set[id][:jamb           ] if h[:jamb           ]
      v[:jambconcave    ] = @set[id][:jamb           ] if h[:jamb           ]
      v[:jambconvex     ] = @set[id][:jamb           ] if h[:jamb           ]
      v[:headconcave    ] = @set[id][:headconcave    ] if h[:headconcave    ]
      v[:headconvex     ] = @set[id][:headconvex     ] if h[:headconvex     ]
      v[:sillconcave    ] = @set[id][:sillconcave    ] if h[:sillconcave    ]
      v[:sillconvex     ] = @set[id][:sillconvex     ] if h[:sillconvex     ]
      v[:jambconcave    ] = @set[id][:jambconcave    ] if h[:jambconcave    ]
      v[:jambconvex     ] = @set[id][:jambconvex     ] if h[:jambconvex     ]
      v[:corner         ] = @set[id][:corner         ] if h[:corner         ]
      v[:cornerconcave  ] = @set[id][:corner         ] if h[:corner         ]
      v[:cornerconvex   ] = @set[id][:corner         ] if h[:corner         ]
      v[:cornerconcave  ] = @set[id][:cornerconcave  ] if h[:cornerconcave  ]
      v[:cornerconvex   ] = @set[id][:cornerconvex   ] if h[:cornerconvex   ]
      v[:parapet        ] = @set[id][:parapet        ] if h[:parapet        ]
      v[:parapetconcave ] = @set[id][:parapet        ] if h[:parapet        ]
      v[:parapetconvex  ] = @set[id][:parapet        ] if h[:parapet        ]
      v[:parapetconcave ] = @set[id][:parapetconcave ] if h[:parapetconcave ]
      v[:parapetconvex  ] = @set[id][:parapetconvex  ] if h[:parapetconvex  ]
      v[:party          ] = @set[id][:party          ] if h[:party          ]
      v[:partyconcave   ] = @set[id][:party          ] if h[:party          ]
      v[:partyconvex    ] = @set[id][:party          ] if h[:party          ]
      v[:partyconcave   ] = @set[id][:partyconcave   ] if h[:partyconcave   ]
      v[:partyconvex    ] = @set[id][:partyconvex    ] if h[:partyconvex    ]
      v[:grade          ] = @set[id][:grade          ] if h[:grade          ]
      v[:gradeconcave   ] = @set[id][:grade          ] if h[:grade          ]
      v[:gradeconvex    ] = @set[id][:grade          ] if h[:grade          ]
      v[:gradeconcave   ] = @set[id][:gradeconcave   ] if h[:gradeconcave   ]
      v[:gradeconvex    ] = @set[id][:gradeconvex    ] if h[:gradeconvex    ]
      v[:balcony        ] = @set[id][:balcony        ] if h[:balcony        ]
      v[:balconyconcave ] = @set[id][:balcony        ] if h[:balcony        ]
      v[:balconyconvex  ] = @set[id][:balcony        ] if h[:balcony        ]
      v[:balconyconcave ] = @set[id][:balconyconcave ] if h[:balconyconcave ]
      v[:balconyconvex  ] = @set[id][:balconyconvex  ] if h[:balconyconvex  ]
      v[:rimjoist       ] = @set[id][:rimjoist       ] if h[:rimjoist       ]
      v[:rimjoistconcave] = @set[id][:rimjoist       ] if h[:rimjoist       ]
      v[:rimjoistconvex ] = @set[id][:rimjoist       ] if h[:rimjoist       ]
      v[:rimjoistconcave] = @set[id][:rimjoistconcave] if h[:rimjoistconcave]
      v[:rimjoistconvex ] = @set[id][:rimjoistconvex ] if h[:rimjoistconvex ]

      max = [v[:parapetconcave], v[:parapetconvex]].max
      v[:parapet] = max unless @has[:parapet]
      @val[id] = v

      true
    end

    ##
    # Append a new PSI set, based on a TBD JSON-formatted PSI set object -
    # requires a valid, unique :id.
    #
    # @param set [Hash] a new PSI set
    #
    # @return [Bool] true if successfully appended
    # @return [Bool] false if invalid input
    def append(set = {})
      mth = "TBD::#{__callee__}"
      a   = false

      return TBD.mismatch("set", set, Hash, mth, DBG, a)  unless set.is_a?(Hash)
      return TBD.hashkey("set id", set, :id, mth, DBG, a) unless set.key?(:id)

      exists = @set.key?(set[:id])
      TBD.log(ERR, "'#{set[:id]}': existing PSI set (#{mth})")         if exists
      return false                                                     if exists

      s = {}
      # Most PSI types have concave and convex variants, depending on the polar
      # position of deratable surfaces about an edge-as-thermal-bridge. One
      # exception is :fenestration, which TBD later breaks down into :head,
      # :sill or :jamb edge types. Another exception is a :joint edge: a PSI
      # type that is not autoassigned to an edge (i.e., only via a TBD JSON
      # input file). Finally, transitions are autoassigned by TBD when an edge
      # is "flat", i.e, no noticeable polar angle difference between surfaces.
      s[:rimjoist       ] = set[:rimjoist       ] if set.key?(:rimjoist       )
      s[:rimjoistconcave] = set[:rimjoistconcave] if set.key?(:rimjoistconcave)
      s[:rimjoistconvex ] = set[:rimjoistconvex ] if set.key?(:rimjoistconvex )
      s[:parapet        ] = set[:parapet        ] if set.key?(:parapet        )
      s[:parapetconcave ] = set[:parapetconcave ] if set.key?(:parapetconcave )
      s[:parapetconvex  ] = set[:parapetconvex  ] if set.key?(:parapetconvex  )
      s[:head           ] = set[:head           ] if set.key?(:head           )
      s[:headconcave    ] = set[:headconcave    ] if set.key?(:headconcave    )
      s[:headconvex     ] = set[:headconvex     ] if set.key?(:headconvex     )
      s[:sill           ] = set[:sill           ] if set.key?(:sill           )
      s[:sillconcave    ] = set[:sillconcave    ] if set.key?(:sillconcave    )
      s[:sillconvex     ] = set[:sillconvex     ] if set.key?(:sillconvex     )
      s[:jamb           ] = set[:jamb           ] if set.key?(:jamb           )
      s[:jambconcave    ] = set[:jambconcave    ] if set.key?(:jambconcave    )
      s[:jambconvex     ] = set[:jambconvex     ] if set.key?(:jambconcave    )
      s[:corner         ] = set[:corner         ] if set.key?(:corner         )
      s[:cornerconcave  ] = set[:cornerconcave  ] if set.key?(:cornerconcave  )
      s[:cornerconvex   ] = set[:cornerconvex   ] if set.key?(:cornerconvex   )
      s[:balcony        ] = set[:balcony        ] if set.key?(:balcony        )
      s[:balconyconcave ] = set[:balconyconcave ] if set.key?(:balconyconcave )
      s[:balconyconvex  ] = set[:balconyconvex  ] if set.key?(:balconyconvex  )
      s[:party          ] = set[:party          ] if set.key?(:party          )
      s[:partyconcave   ] = set[:partyconcave   ] if set.key?(:partyconcave   )
      s[:partyconvex    ] = set[:partyconvex    ] if set.key?(:partyconvex    )
      s[:grade          ] = set[:grade          ] if set.key?(:grade          )
      s[:gradeconcave   ] = set[:gradeconcave   ] if set.key?(:gradeconcave   )
      s[:gradeconvex    ] = set[:gradeconvex    ] if set.key?(:gradeconvex    )
      s[:fenestration   ] = set[:fenestration   ] if set.key?(:fenestration   )
      s[:joint          ] = set[:joint          ] if set.key?(:joint          )
      s[:transition     ] = set[:transition     ] if set.key?(:transition     )

      s[:joint          ] = 0.000             unless set.key?(:joint          )
      s[:transition     ] = 0.000             unless set.key?(:transition     )

      @set[set[:id]] = s
      self.gen(set[:id])

      true
    end

    ##
    # Return PSI set shorthands. The return Hash holds 2x keys ... has: a Hash
    # of true/false (values) for any admissible PSI type (keys), and val: a Hash
    # of PSI-values for any admissible PSI type (default: 0.0 W/K per meter).
    #
    # @param id [String] a PSI set identifier
    #
    # @return [Hash] has: Hash of true/false, val: Hash of PSI values
    # @return [Hash] has: empty Hash, val: empty Hash (if invalid/missing set)
    def shorthands(id = "")
      mth = "TBD::#{__callee__}"
      cl  = String
      sh  = { has: {}, val: {} }

      return TBD.mismatch("id", id, String, mth, DBG, sh)   unless id.is_a?(cl)
      return TBD.hashkey(id, @set, id, mth, ERR, sh)        unless @set.key?(id)
      return TBD.hashkey(id, @has, id, mth, ERR, sh)        unless @has.key?(id)
      return TBD.hashkey(id, @val, id, mth, ERR, sh)        unless @val.key?(id)

      sh[:has] = @has[id]
      sh[:val] = @val[id]

      sh
    end

    ##
    # Validate whether a given PSI set has a complete list of PSI type:values.
    #
    # @param id [String] a PSI set identifier
    #
    # @return [Bool] true if found and is complete
    # @return [Bool] false if invalid input
    def complete?(id = "")
      mth = "TBD::#{__callee__}"
      a   = false

      return TBD.mismatch("id", id, String, mth, DBG, a) unless id.is_a?(String)
      return TBD.hashkey(id, @set, id, mth, ERR, a)      unless @set.key?(id)
      return TBD.hashkey(id, @has, id, mth, ERR, a)      unless @has.key?(id)
      return TBD.hashkey(id, @val, id, mth, ERR, a)      unless @val.key?(id)

      holes = []
      holes << :head                                if @has[id][:head          ]
      holes << :sill                                if @has[id][:sill          ]
      holes << :jamb                                if @has[id][:jamb          ]
      ok = holes.size == 3
      ok = true                                     if @has[id][:fenestration  ]
      return false unless ok

      corners = []
      corners << :concave                           if @has[id][:cornerconcave ]
      corners << :convex                            if @has[id][:cornerconvex  ]
      ok = corners.size == 2
      ok = true                                     if @has[id][:corner        ]
      return false unless ok

      parapets = []
      parapets << :concave                          if @has[id][:parapetconcave]
      parapets << :convex                           if @has[id][:parapetconvex ]
      ok = parapets.size == 2
      ok = true                                     if @has[id][:parapet       ]
      return false unless ok
      return false                              unless @has[id][:party         ]
      return false                              unless @has[id][:grade         ]
      return false                              unless @has[id][:balcony       ]
      return false                              unless @has[id][:rimjoist      ]

      ok
    end

    ##
    # Return safe PSI type if missing input from PSI set (based on inheritance).
    #
    # @param id [String] a PSI set identifier
    # @param type [Symbol] a PSI type, e.g. :rimjoistconcave
    #
    # @return [Symbol] safe PSI type
    # @return [Nil] if invalid input or no safe PSI type found
    def safe(id = "", type = nil)
      mth = "TBD::#{__callee__}"
      cl1 = String
      cl2 = Symbol

      return TBD.mismatch("id", id, cl1, mth)             unless id.is_a?(cl1)
      return TBD.mismatch("type", type, cl2, mth, ERR)    unless type.is_a?(cl2)
      return TBD.hashkey(id, @set, id, mth, ERR)          unless @set.key?(id)
      return TBD.hashkey(id, @has, id, mth, ERR)          unless @has.key?(id)

      safer = type

      unless @has[id][safer]
        concave = type.to_s.include?("concave")
        convex  = type.to_s.include?("convex")
        safer = type.to_s.chomp("concave").to_sym if concave
        safer = type.to_s.chomp("convex").to_sym  if convex

        unless @has[id][safer]
          safer = :fenestration if safer == :head
          safer = :fenestration if safer == :sill
          safer = :fenestration if safer == :jamb
        end
      end

      return safer if @has[id][safer]

      nil
    end
  end

  ##
  # Process TBD JSON inputs, after TBD has processed OpenStudio model variables
  # and retrieved corresponding Topolys model surface/edge properties. TBD user
  # inputs allow customization of default assumptions and inferred values.
  # If successful, "edges" (input) may inherit additional properties, e.g.:
  # edge-specific PSI set (defined in TBD JSON file), edge-specific PSI type
  # (e.g. "corner", defined in TBD JSON file), project-wide PSI set (if absent
  # from TBD JSON file).
  #
  # @param s [Hash] preprocessed TBD surfaces
  # @param e [Hash] preprocessed TBD edges
  # @param argh [Hash] arguments
  #
  # @return [Hash] io: JSON inputs (Hash), psi:/khi: new (enriched) sets (Hash)
  # @return [Hash] io: empty Hash if invalid input
  def inputs(s = {}, e = {}, argh = {})
    mth = "TBD::#{__callee__}"
    opt = :option
    ipt = { io: {}, psi: PSI.new, khi: KHI.new }
    io  = {}

    return mismatch("s", s, Hash, mth, DBG, ipt)         unless s.is_a?(Hash)
    return mismatch("e", s, Hash, mth, DBG, ipt)         unless e.is_a?(Hash)
    return mismatch("argh", s, Hash, mth, DBG, ipt)      unless argh.is_a?(Hash)
    return hashkey("argh", argh, opt, mth, DBG, ipt)     unless argh.key?(opt)

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
      # We nonetheless recommend that users rely on the json-schema gem, or an
      # online linter, prior to using TBD. The following checks focus on content
      # - ignoring bad JSON input otherwise caught via JSON validation.
      #
      # A side note: JSON validation relies on case-senitive string comparisons
      # (e.g. OpenStudio space or surface names, vs corresponding TBD JSON
      # identifiers). So "Space-1" doesn't match "SPACE-1" - head's up.
      if sch
        require "json-schema"

        return invalid("JSON schema", mth, 0, FTL, ipt) unless File.exist?(sch)
        return empty("JSON schema", mth, FTL, ipt) if File.zero?(sch)
        schema = File.read(sch)
        schema = JSON.parse(schema, symbolize_names: true)
        valid  = JSON::Validator.validate!(schema, io)
        return invalid("JSON schema validation", mth, 0, FTL, ipt) unless valid
      end

      # Append JSON entries to library of linear & point thermal bridges.
      io[:psis].each { |psi| ipt[:psi].append(psi) }           if io.key?(:psis)
      io[:khis].each { |khi| ipt[:khi].append(khi) }           if io.key?(:khis)

      # JSON-defined or user-selected, building PSI set must be complete/valid.
      io[:building] = { psi: argh[opt] } unless io.key?(:building)
      bdg = io[:building]
      ok = bdg.key?(:psi)
      return hashkey("Building PSI", bdg, :psi, mth, FTL, ipt)         unless ok
      ok = ipt[:psi].complete?(bdg[:psi])
      return invalid("Complete building PSI", mth, 0, FTL, ipt)        unless ok

      # Validate remaining (optional) JSON entries.
      [:stories, :spacetypes, :spaces].each do |types|
        key = :story
        key = :stype if types == :spacetypes
        key = :space if types == :spaces

        if io.key?(types)
          io[types].each do |type|
            next unless type.key?(:psi)
            next unless type.key?(:id)
            s1 = "JSON/OSM '#{type[:id]}' (#{mth})"
            s2 = "JSON/PSI '#{type[:id]}' set (#{mth})"
            match = false

            s.values.each do |props|         # TBD model surface linked to type?
              break if match
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
          surfaces  = edge[:surfaces]
          type      = edge[:type].to_sym
          safer     = ipt[:psi].safe(bdg[:psi], type)                 # fallback
          log(ERR, "Skipping invalid edge PSI '#{type}' (#{mth})") unless safer
          next unless safer
          valid = true

          surfaces.each do |surface|             #   TBD edge's surfaces on file
            e.values.each do |ee|                #           TBD edges in memory
              break unless valid                 #  if previous anomaly detected
              next      if ee.key?(:io_type)     #  validated from previous loop
              next  unless ee.key?(:surfaces)
              surfs      = ee[:surfaces]
              next  unless surfs.key?(surface)

              # An edge on file is valid if ALL of its listed surfaces together
              # connect at least one or more TBD/Topolys model edges in memory.
              # Each of the latter may connect e.g. 3x TBD/Topolys surfaces,
              # but the list of surfaces on file may be shorter, e.g. only 2x.
              match = true
              surfaces.each { |id| match = false unless surfs.key?(id) }
              next unless match

              if edge.key?(:length)                                   # optional
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

              if edge.key?(:psi)                                      # optional
                set = edge[:psi]

                if ipt[:psi].set.key?(set)
                  saferr       = ipt[:psi].safe(set, type)
                  ee[:io_set ] = set                                   if saferr
                  ee[:io_type] = type                                  if saferr
                  log(ERR, "Invalid '#{set}': '#{type}' (#{mth})") unless saferr
                  valid = false                                    unless saferr
                else
                  log(ERR, "Missing edge PSI '#{set}' (#{mth})")
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
      ok = ipt[:psi].complete?(argh[opt])
      io[:building] = { psi: argh[opt] }                                   if ok
      log(FTL, "Incomplete building PSI set '#{argh[opt]}' (#{mth})")  unless ok
      return ipt                                                       unless ok
    end

    ipt[:io] = io

    ipt
  end

  ##
  # Thermally derate insulating material within construction.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param id [String] surface identifier
  # @param surface [Hash] a TBD surface
  # @param lc [OpenStudio::Model::LayeredConstruction] a layered construction
  #
  # @return [OpenStudio::Model::Material] derated (cloned) material
  # @return [NilClass] if invalid input
  def derate(model = nil, id = "", s = {}, lc = nil)
    mth = "TBD::#{__callee__}"
    m   = nil
    k1  = :heatloss
    k2  = :ltype
    k3  = :construction
    k4  = :index
    cl1 = OpenStudio::Model::Model
    cl2 = OpenStudio::Model::LayeredConstruction
    cl3 = Numeric
    cl4 = Symbol
    cl5 = Integer

    return mismatch("model", model, cl, mth)           unless model.is_a?(cl1)
    return mismatch("id", id, String, mth)             unless id.is_a?(String)
    return mismatch(id, s, Hash, mth)                  unless s.is_a?(Hash)
    return mismatch("lc", lc, Hash, mth)               unless lc.is_a?(cl2)
    return hashkey("'#{id}' W/K", s, k1, mth)          unless s.key?(k1)
    return invalid("'#{id}' W/K", mth, 3)              unless s[k1]
    return mismatch("'#{id}' W/K", s[k1], cl3, mth)    unless s[k1].is_a?(cl3)
    return zero("'#{id}' W/K", mth, WRN)                   if s[k1].abs < TOL
    return hashkey("'#{id}' m2", s, :net, mth)         unless s.key?(:net)
    return invalid("'#{id}' m2", mth, 3)               unless s[:net]
    return mismatch("'#{id}' m2", s[:net], cl3, mth)   unless s[:net].is_a?(cl3)
    return zero("'#{id}' m2", mth, WRN)                    if s[:net].abs < TOL
    return hashkey("'#{id}' type", s, k2, mth)         unless s.key?(k2)
    return invalid("'#{id}' type", mth, 3)             unless s[k2]
    return mismatch("'#{id}' type", s[k2], cl4, mth)   unless s[k2].is_a?(cl4)

    ok = s[k2] == :massless || s[k2] == :standard

    return invalid("'#{id}' type", mth, 3)             unless ok
    return hashkey("'#{id}' construction", s, k3, mth) unless s.key?(k3)
    return hashkey("'#{id}' index", s, k4, mth)        unless s.key?(k4)
    return invalid("'#{id}' index", mth, 3)            unless s[k4]
    return mismatch("'#{id}' index", s[k4], cl5, mth)  unless s[k4].is_a?(cl5)
    return negative("'#{id}' index", mth)                  if s[k4] < 0
    return hashkey("'#{id}' Rsi", s, :r, mth)          unless s.key?(:r)
    return invalid("'#{id}' Rsi", mth, 3)              unless s[:r]
    return mismatch("'#{id}' Rsi", s[:r], cl3, mth)    unless s[:r].is_a?(cl3)
    return zero("'#{id}' Rsi", mth, WRN)                   if s[:r].abs < 0.001

    derated = lc.nameString.include?(" tbd")
    log(WRN, "Won't derate '#{id}': already derated (#{mth})")        if derated
    return m                                                          if derated

    index = s[:index]
    ltype = s[:ltype]
    r     = s[:r]
    u     = s[:heatloss] / s[:net]
    loss  = 0
    de_u  = 1 / r + u                                                # derated U
    de_r  = 1 / de_u                                                 # derated R

    if ltype == :massless
      m    = lc.getLayer(index).to_MasslessOpaqueMaterial
      return invalid("'#{id}' massless layer?", mth, 0)              if m.empty?
      m    = m.get
      up   = ""
      up   = "uprated "                     if m.nameString.include?(" uprated")
      m    = m.clone(model).to_MasslessOpaqueMaterial.get
             m.setName("#{id} #{up}m tbd")
      de_r = 0.001                                           unless de_r > 0.001
      loss = (de_u - 1 / de_r) * s[:net]                     unless de_r > 0.001
             m.setThermalResistance(de_r)
    else
      m    = lc.getLayer(index).to_StandardOpaqueMaterial
      return invalid("'#{id}' standard layer?", mth, 0)              if m.empty?
      m    = m.get
      up   = ""
      up   = "uprated "                     if m.nameString.include?(" uprated")
      m    = m.clone(model).to_StandardOpaqueMaterial.get
             m.setName("#{id} #{up}m tbd")
      k    = m.thermalConductivity

      if de_r > 0.001
        d  = de_r * k

        unless d > 0.003
          d    = 0.003
          k    = d / de_r
          k    = 3                                                  unless k < 3
          loss = (de_u - k / d) * s[:net]                           unless k < 3
        end
      else                                                 # de_r < 0.001 m2.K/W
        d    = 0.001 * k
        d    = 0.003                                            unless d > 0.003
        k    = d / 0.001                                        unless d > 0.003
        loss = (de_u - k / d) * s[:net]
      end

      m.setThickness(d)
      m.setThermalConductivity(k)
    end

    if m && loss > TOL
      s[:r_heatloss] = loss
      h_loss = format "%.3f", s[:r_heatloss]
      log(WRN, "Won't assign #{h_loss} W/K to '#{id}': too conductive (#{mth})")
    end

    m
  end

  ##
  # Process TBD objects, based on OpenStudio model (OSM) and Topolys model,
  # and derate admissible envelope surfaces by substituting insulating material
  # within surface multilayered constructions with derated clones. Returns a
  # hash holding 2x key:value pairs ... io: objects for JSON serialization and
  # surfaces: derated TBD surfaces.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param argh [Hash] TBD arguments
  #
  # @return [Hash] io: (Hash), surfaces: (Hash)
  # @return [Hash] io: nil, surfaces: nil (if invalid input)
  def process(model = nil, argh = {})
    mth = "TBD::#{__callee__}"
    cl  = OpenStudio::Model::Model
    tbd = { io: nil, surfaces: {} }

    return mismatch("model", model, cl, mth, DBG, tbd) unless model.is_a?(cl)
    return mismatch("argh", argh, Hash, mth, DBG, tbd) unless argh.is_a?(Hash)

    argh                 = {}                       if argh.empty?
    argh[:option       ] = ""                   unless argh.key?(:option       )
    argh[:io_path      ] = nil                  unless argh.key?(:io_path      )
    argh[:schema_path  ] = nil                  unless argh.key?(:schema_path  )
    argh[:uprate_walls ] = false                unless argh.key?(:uprate_walls )
    argh[:uprate_roofs ] = false                unless argh.key?(:uprate_roofs )
    argh[:uprate_floors] = false                unless argh.key?(:uprate_floors)
    argh[:wall_ut      ] = 0                    unless argh.key?(:wall_ut      )
    argh[:roof_ut      ] = 0                    unless argh.key?(:roof_ut      )
    argh[:floor_ut     ] = 0                    unless argh.key?(:floor_ut     )
    argh[:wall_option  ] = ""                   unless argh.key?(:wall_option  )
    argh[:roof_option  ] = ""                   unless argh.key?(:roof_option  )
    argh[:floor_option ] = ""                   unless argh.key?(:floor_option )
    argh[:gen_ua       ] = false                unless argh.key?(:gen_ua       )
    argh[:ua_ref       ] = ""                   unless argh.key?(:ua_ref       )
    argh[:gen_kiva     ] = false                unless argh.key?(:gen_kiva     )

    # Create the Topolys Model.
    t_model = Topolys::Model.new

    # "true" if any space/zone holds valid setpoint temperatures. With invalid
    # inputs, these 2x methods return "false", ignoring any
    # setpoint-based logic, e.g. semi-heated spaces (DEBUG errors are logged).
    setpoints = heatingTemperatureSetpoints?(model)
    setpoints = coolingTemperatureSetpoints?(model) || setpoints

    # "true" if any space/zone is part of an HVAC air loop. With invalid inputs,
    # the method returns "false", ignoring any air-loop related logic, e.g.
    # plenum zones as HVAC objects (DEBUG errors are logged).
    airloops = airLoopsHVAC?(model)

    model.getSurfaces.sort_by { |s| s.nameString }.each do |s|
      # Fetch key attributes of opaque surfaces. Method returns nil with invalid
      # input (DEBUG and ERROR messages may be logged). TBD ignores them.
      surface = properties(model, s)
      next if   surface.nil?

      # Similar to "setpoints?" methods above, the boolean methods below also
      # return "false" with invalid inputs, ignoring any space/zone
      # conditioning-based logic (e.g. semi-heated spaces, mislabelling a
      # plenum as an unconditioned zone).
      if setpoints
        if surface[:space].thermalZone.empty?
          plenum = plenum?(surface[:space], airloops, setpoints)
          surface[:conditioned] = false unless plenum
        else
          zone = surface[:space].thermalZone.get
          heat = maxHeatScheduledSetpoint(zone)
          cool = minCoolScheduledSetpoint(zone)

          unless heat[:spt] || cool[:spt]
            plenum     = plenum?(surface[:space], airloops, setpoints)
            heat[:spt] = 21                   if plenum
            cool[:spt] = 24                   if plenum
            surface[:conditioned] = false unless plenum
          end

          free = heat[:spt] && heat[:spt] < -40 && cool[:spt] && cool[:spt] > 40
          surface[:conditioned] = false if free
        end
      end

      surface[:heating] = heat[:spt] if heat[:spt]  # if valid heating setpoints
      surface[:cooling] = cool[:spt] if cool[:spt]  # if valid cooling setpoints

      tbd[:surfaces][s.nameString] = surface
    end                                            # (opaque) surfaces populated

    return empty("TBD surfaces", mth, ERR, tbd) if tbd[:surfaces].empty?

    # TBD only derates constructions of opaque surfaces in CONDITIONED spaces,
    # ... if facing outdoors or facing UNENCLOSED/UNCONDITIONED spaces.
    tbd[:surfaces].each do |id, surface|
      surface[:deratable] = false

      next unless surface[:conditioned]
      next     if surface[:ground]

      unless surface[:boundary].downcase == "outdoors"
        next unless tbd[:surfaces].key?(surface[:boundary])
        next if tbd[:surfaces][surface[:boundary]][:conditioned]
      end

      ok = surface.key?(:index)
      surface[:deratable] = true                                           if ok
      log(ERR, "Skipping '#{id}': insulating layer? (#{mth})")         unless ok
    end

    [:windows, :doors, :skylights].each do |holes|                   # sort kids
      tbd[:surfaces].values.each do |surface|
        ok = surface.key?(holes)
        surface[holes] = surface[holes].sort_by { |_, s| s[:minz] }.to_h   if ok
      end
    end

    # Split "surfaces" hash into "floors", "ceilings" and "walls" hashes.
    floors   = tbd[:surfaces].select { |_, s| s[:type] == :floor    }
    ceilings = tbd[:surfaces].select { |_, s| s[:type] == :ceiling  }
    walls    = tbd[:surfaces].select { |_, s| s[:type] == :wall     }
    floors   = floors.sort_by        { |_, s| [s[:minz], s[:space]] }.to_h
    ceilings = ceilings.sort_by      { |_, s| [s[:minz], s[:space]] }.to_h
    walls    = walls.sort_by         { |_, s| [s[:minz], s[:space]] }.to_h

    # Fetch OpenStudio shading surfaces & key attributes.
    shades = {}

    model.getShadingSurfaces.each do |s|
      id      = s.nameString
      empty   = s.shadingSurfaceGroup.empty?
      log(ERR, "Can't process '#{id}' transformation (#{mth})")         if empty
      next                                                              if empty
      group   = s.shadingSurfaceGroup.get
      shading = group.to_ShadingSurfaceGroup
      tr      = transforms(model, group)
      ok      = tr[:t] && tr[:r]
      t       = tr[:t]
      log(FTL, "Can't process '#{id}' transformation (#{mth})")        unless ok
      return tbd                                                       unless ok

      unless shading.empty?
        empty = shading.get.space.empty?
        tr[:r] += shading.get.space.get.directionofRelativeNorth    unless empty
      end

      n = trueNormal(s, tr[:r])
      log(FTL, "Can't process '#{id}' true normal (#{mth})")            unless n
      return tbd                                                        unless n

      points = (t * s.vertices).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }
      minz = ( points.map { |p| p.z } ).min
      shades[id] = { group:  group, points: points, minz: minz, n: n }
    end                                             # shading surfaces populated

    # Mutually populate TBD & Topolys surfaces. Keep track of created "holes".
    holes         = {}
    floor_holes   = dads(t_model, floors  )
    ceiling_holes = dads(t_model, ceilings)
    wall_holes    = dads(t_model, walls   )

    holes.merge!(floor_holes  )
    holes.merge!(ceiling_holes)
    holes.merge!(wall_holes   )
    dads(t_model, shades)

    # Loop through Topolys edges and populate TBD edge hash. Initially, there
    # should be a one-to-one correspondence between Topolys and TBD edge
    # objects. Use Topolys-generated identifiers as unique edge hash keys.
    edges = {}

    holes.each do |id, wire|                             # start with hole edges
      wire.edges.each do |e|
        i = e.id
        l = e.length
        ok = edges.key?(i)
        edges[i] = { length: l, v0: e.v0, v1: e.v1, surfaces: {} }     unless ok
        ok = edges[i][:surfaces].key?(wire.attributes[:id])
        edges[i][:surfaces][wire.attributes[:id]] = { wire: wire.id }  unless ok
      end
    end

    # Next, floors, ceilings & walls; then shades.
    faces(floors, edges  )
    faces(ceilings, edges)
    faces(walls, edges   )
    faces(shades, edges  )

    # Generate OSM Kiva settings and objects if foundation-facing floors.
    # returns false if partial failure (log failure eventually).
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
      horizontal = dz.abs < TOL
      vertical   = dx < TOL && dy < TOL
      edge_V     = terminal - origin

      invalid("1x edge length < TOL", mth, 0, ERROR) if edge_V.magnitude < TOL
      next                                           if edge_V.magnitude < TOL

      edge_plane = Topolys::Plane3D.new(origin, edge_V)

      if vertical
        reference_V = north.dup
      elsif horizontal
        reference_V = zenith.dup
      else                               # project zenith vector unto edge plane
        reference = edge_plane.project(origin + zenith)
        reference_V = reference - origin
      end

      edge[:surfaces].each do |id, surface|
        # Loop through each linked wire and determine farthest point from
        # edge while ensuring candidate point is not aligned with edge.
        t_model.wires.each do |wire|
          next unless surface[:wire] == wire.id       # should be a unique match
          normal     = tbd[:surfaces][id][:n]   if tbd[:surfaces].key?(id)
          normal     = holes[id].attributes[:n] if holes.key?(id)
          normal     = shades[id][:n]           if shades.key?(id)
          farthest   = Topolys::Point3D.new(origin.x, origin.y, origin.z)
          farthest_V = farthest - origin             # zero magnitude, initially
          inverted   = false
          i_origin   = wire.points.index(origin)
          i_terminal = wire.points.index(terminal)
          i_last     = wire.points.size - 1

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

            point_on_plane    = edge_plane.project(point)
            origin_point_V    = point_on_plane - origin
            point_V_magnitude = origin_point_V.magnitude
            next unless point_V_magnitude > TOL

            # Generate a plane between origin, terminal & point. Only consider
            # planes that share the same normal as wire.
            if inverted
              plane = Topolys::Plane3D.from_points(terminal, origin, point)
            else
              plane = Topolys::Plane3D.from_points(origin, terminal, point)
            end

            next unless (normal.x - plane.normal.x).abs < TOL &&
                        (normal.y - plane.normal.y).abs < TOL &&
                        (normal.z - plane.normal.z).abs < TOL

            farther    = point_V_magnitude > farthest_V.magnitude
            farthest   = point          if farther
            farthest_V = origin_point_V if farther
          end

          puts "ADDITION!!"                      if id == "ADDITION"
          puts "#{reference_V} vs #{farthest_V}" if id == "ADDITION"

          angle = reference_V.angle(farthest_V)
          invalid("#{id} polar angle", mth, 0, ERROR, 0) if angle.nil?
          angle = 0                                      if angle.nil?

          adjust = false              # adjust angle [180°, 360°] if necessary

          if vertical
            adjust = true if east.dot(farthest_V) < -TOL
          else
            if north.dot(farthest_V).abs < TOL ||
              (north.dot(farthest_V).abs - 1).abs < TOL
              adjust = true if east.dot(farthest_V) < -TOL
            else
              adjust = true if north.dot(farthest_V) < -TOL
            end
          end

          angle  = 2 * Math::PI - angle if adjust
          angle -= 2 * Math::PI         if (angle - 2 * Math::PI).abs < TOL
          surface[:angle ] = angle
          farthest_V.normalize!
          surface[:polar ] = farthest_V
          surface[:normal] = normal
        end                           # end of edge-linked, surface-to-wire loop
      end                                      # end of edge-linked surface loop

      edge[:horizontal] = horizontal
      edge[:vertical  ] = vertical
      edge[:surfaces  ] = edge[:surfaces].sort_by{ |i, p| p[:angle] }.to_h
    end                                                       # end of edge loop

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

    psi    = json[:io][:building][:psi]           # default building PSI on file
    shorts = json[:psi].shorthands(psi)
    empty  = shorts[:has].empty? || shorts[:val].empty?
    log(FTL, "Invalid or incomplete building PSI set (#{mth})")         if empty
    return tbd                                                          if empty

    edges.values.each do |edge|
      next unless edge.key?(:surfaces)
      deratables = []

      edge[:surfaces].keys.each do |id|
        next unless tbd[:surfaces].key?(id)
        deratables << id if tbd[:surfaces][id][:deratable]
      end

      next if deratables.empty?
      set = {}

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
        is            = {}
        is[:head    ] = set.keys.to_s.include?("head"    )
        is[:sill    ] = set.keys.to_s.include?("sill"    )
        is[:jamb    ] = set.keys.to_s.include?("jamb"    )
        is[:corner  ] = set.keys.to_s.include?("corner"  )
        is[:parapet ] = set.keys.to_s.include?("parapet" )
        is[:party   ] = set.keys.to_s.include?("party"   )
        is[:grade   ] = set.keys.to_s.include?("grade"   )
        is[:balcony ] = set.keys.to_s.include?("balcony" )
        is[:rimjoist] = set.keys.to_s.include?("rimjoist")

        # Label edge as :head, :sill or :jamb if linked to:
        #   1x subsurface
        edge[:surfaces].keys.each do |i|
          break    if is[:head] || is[:sill] || is[:jamb]
          next     if deratables.include?(i)
          next unless holes.key?(i)

          gardian = ""
          gardian = id if deratables.size == 1                      #   just dad

          if gardian.empty?                                         # seek uncle
            pops   = {}                                             #      kids?
            uncles = {}                                             #    nieces?
            boys   = []                                             #       kids
            nieces = []                                             #     nieces
            uncle  = deratables.first unless deratables.first == id # uncle 1st?
            uncle  = deratables.last  unless deratables.last  == id # uncle 2nd?

            pops[:w  ] = tbd[:surfaces][id   ].key?(:windows  )
            pops[:d  ] = tbd[:surfaces][id   ].key?(:doors    )
            pops[:s  ] = tbd[:surfaces][id   ].key?(:skylights)
            uncles[:w] = tbd[:surfaces][uncle].key?(:windows  )
            uncles[:d] = tbd[:surfaces][uncle].key?(:doors    )
            uncles[:s] = tbd[:surfaces][uncle].key?(:skylights)

            boys   += tbd[:surfaces][id   ][:windows  ].keys if   pops[:w]
            boys   += tbd[:surfaces][id   ][:doors    ].keys if   pops[:d]
            boys   += tbd[:surfaces][id   ][:skylights].keys if   pops[:s]
            nieces += tbd[:surfaces][uncle][:windows  ].keys if uncles[:w]
            nieces += tbd[:surfaces][uncle][:doors    ].keys if uncles[:d]
            nieces += tbd[:surfaces][uncle][:skylights].keys if uncles[:s]

            gardian = uncle if   boys.include?(i)
            gardian = id    if nieces.include?(i)
          end

          next if gardian.empty?
          s1      = edge[:surfaces][gardian]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          # Subsurface edges are tagged as :head, :sill or :jamb, regardless
          # of building PSI set subsurface tags. If the latter is simply
          # :fenestration, then its (single) PSI value is systematically
          # attributed to subsurface :head, :sill & :jamb edges. If absent,
          # concave or convex variants also inherit from base type.
          #
          # TBD tags a subsurface edge as :jamb if the subsurface is "flat".
          # If not flat, TBD tags a horizontal edge as either :head or :sill
          # based on the polar angle of the subsurface around the edge vs sky
          # zenith. Otherwise, all other subsurface edges are tagged as :jamb.
          if ((s2[:normal].dot(zenith)).abs - 1).abs < TOL
            set[:jamb       ] = shorts[:val][:jamb       ] if flat
            set[:jambconcave] = shorts[:val][:jambconcave] if concave
            set[:jambconvex ] = shorts[:val][:jambconvex ] if convex
             is[:jamb       ] = true
          else
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
          end
        end

        # Label edge as :cornerconcave or :cornerconvex if linked to:
        #   2x deratable walls & f(relative polar wall vectors around edge)
        edge[:surfaces].keys.each do |i|
          break     if is[:corner]
          break unless deratables.size == 2
          break unless walls.key?(id)
          next      if i == id
          next unless deratables.include?(i)
          next unless walls.key?(i)

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)

          set[:cornerconcave] = shorts[:val][:cornerconcave] if concave
          set[:cornerconvex ] = shorts[:val][:cornerconvex ] if convex
           is[:corner       ] = true
        end

        # Label edge as :parapet if linked to:
        #   1x deratable wall
        #   1x deratable ceiling
        edge[:surfaces].keys.each do |i|
          break     if is[:parapet]
          break unless deratables.size == 2
          break unless ceilings.key?(id)
          next      if i == id
          next  unless deratables.include?(i)
          next  unless walls.key?(i)

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          set[:parapet       ] = shorts[:val][:parapet       ] if flat
          set[:parapetconcave] = shorts[:val][:parapetconcave] if concave
          set[:parapetconvex ] = shorts[:val][:parapetconvex ] if convex
           is[:parapet       ] = true
        end

        # Label edge as :party if linked to:
        #   1x adiabatic surface
        #   1x (only) deratable surface
        edge[:surfaces].keys.each do |i|
          break     if is[:party]
          break unless deratables.size == 1
          next      if i == id
          next  unless tbd[:surfaces].key?(i)
          next      if holes.key?(i)
          next      if shades.key?(i)
          next  unless tbd[:surfaces][i][:boundary].downcase == "adiabatic"

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
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

        # Label edge as :rimjoist (or :balcony) if linked to:
        #   1x deratable surface
        #   1x CONDITIONED floor
        #   1x shade (optional)
        balcony = false

        edge[:surfaces].keys.each do |i|
          break          if balcony
          next           if i == id
          balcony = true if shades.key?(i)
        end

        edge[:surfaces].keys.each do |i|
          break     if is[:rimjoist] || is[:balcony]
          break unless deratables.size == 2
          break     if floors.key?(id)
          next      if i == id
          next  unless floors.key?(i)
          next  unless floors[i].key?(:conditioned)
          next  unless floors[i][:conditioned]
          next      if floors[i][:ground]

          other = deratables.first unless deratables.first == id
          other = deratables.last  unless deratables.last  == id

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][other]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          if balcony
            set[:balcony        ] = shorts[:val][:balcony        ] if flat
            set[:balconyconcave ] = shorts[:val][:balconyconcave ] if concave
            set[:balconyconvex  ] = shorts[:val][:balconyconvex  ] if convex
             is[:balcony        ] = true
          else
            set[:rimjoist       ] = shorts[:val][:rimjoist       ] if flat
            set[:rimjoistconcave] = shorts[:val][:rimjoistconcave] if concave
            set[:rimjoistconvex ] = shorts[:val][:rimjoistconvex ] if convex
             is[:rimjoist       ] = true
          end
        end
      end                                                 # edge's surfaces loop

      edge[:psi] = set unless set.empty?
      edge[:set] = psi unless set.empty?
    end                                                              # edge loop

    # Tracking (mild) transitions between deratable surfaces around edges that
    # have not been previously tagged.
    edges.values.each do |edge|
      next     if edge.key?(:psi)
      next unless edge.key?(:surfaces)
      deratable = false

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
    if json[:io]
      if json[:io].key?(:subsurfaces) # reset subsurface U-factors (if on file)
        json[:io][:subsurfaces].each do |sub|
          next unless sub.key?(:id)
          next unless sub.key?(:usi)
          match = false

          tbd[:surfaces].values.each do |surface|
            break if match

            [:windows, :doors, :skylights].each do |types|
              if surface.key?(types)
                surface[types].each do |id, opening|
                  break                   if match
                  next                unless opening.key?(:u)
                  match = true            if sub[:id] == id
                  opening[:u] = sub[:usi] if sub[:id] == id
                end
              end
            end
          end
        end
      end

      [:stories, :spacetypes, :spaces].each do |groups|
        key = :story
        key = :stype if groups == :spacetypes
        key = :space if groups == :spaces
        next     unless json[:io].key?(groups)

        json[:io][groups].each do |group|
          next unless group.key?(:id)
          next unless group.key?(:psi)
          next unless json[:psi].set.key?(group[:psi])
          sh        = json[:psi].shorthands(group[:psi])
          next     if sh[:val].empty?

          edges.values.each do |edge|
            next     if edge.key?(:io_set)
            next unless edge.key?(:psi)
            next unless edge.key?(:surfaces)

            edge[:surfaces].keys.each do |id|
              next unless tbd[:surfaces].key?(id)
              next unless tbd[:surfaces][id].key?(key)
              next unless group[:id] == tbd[:surfaces][id][key].nameString

              edge[groups]              = {}            unless edge.key?(groups)
              edge[groups][group[:psi]] = {}
              set                       = {}

              if edge.key?(:io_type)
                safer = json[:psi].safe(group[:psi], edge[:io_type])
                set[edge[:io_type]] = sh[:val][safer]                   if safer
              else
                edge[:psi].keys.each do |type|
                  safer = json[:psi].safe(group[:psi], type)
                  set[type] = sh[:val][safer]                           if safer
                end
              end

              edge[groups][group[:psi]] = set                  unless set.empty?
            end
          end
        end

        # TBD/Topolys edges will generally be linked to more than one surface
        # and hence to more than one story. It is possible for a TBD JSON file
        # to hold 2x story PSI sets that end up targetting one or more edges
        # common to both stories. In such cases, TBD retains the most conductive
        # PSI type/value from either story PSI set.
        edges.values.each do |edge|
          next unless edge.key?(:psi)
          next unless edge.key?(groups)

          edge[:psi].keys.each do |type|
            vals = {}

            edge[groups].keys.each do |set|
              sh        = json[:psi].shorthands(set)
              next if     sh[:val].empty?
              safer     = json[:psi].safe(set, type)
              vals[set] = sh[:val][safer] if safer
            end

            next if             vals.empty?
            edge[:psi ][type] = vals.values.max
            edge[:sets]       = {} unless edge.key?(:sets)
            edge[:sets][type] = vals.key(vals.values.max)
          end
        end
      end

      if json[:io].key?(:surfaces)
        json[:io][:surfaces].each do |surface|
          next unless surface.key?(:id)
          next unless surface.key?(:psi)
          next unless json[:psi].set.key?(surface[:psi])
          sh        = json[:psi].shorthands(surface[:psi])
          next     if sh[:val].empty?

          edges.values.each do |edge|
            next     if edge.key?(:io_set)
            next unless edge.key?(:psi)
            next unless edge.key?(:surfaces)

            edge[:surfaces].each do |id, s|
              next unless tbd[:surfaces].key?(id)
              next unless surface[:id] == id
              set = {}

              if edge.key?(:io_type)
                safer = json[:psi].safe(surface[:psi], edge[:io_type])
                set[:io_type] = sh[:val][safer]                         if safer
              else
                edge[:psi].keys.each do |type|
                  safer = json[:psi].safe(surface[:psi], type)
                  set[type] = sh[:val][safer]                           if safer
                end
              end

              s[:psi] = set           unless set.empty?
              s[:set] = surface[:psi] unless set.empty?
            end
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
              next     unless s.key?(:psi)
              next     unless s.key?(:set)
              next         if s[:set].empty?
              sh            = json[:psi].shorthands(s[:set])
              next         if sh[:val].empty?
              safer         = json[:psi].safe(s[:set], type)
              vals[s[:set]] = sh[:val][safer] if safer
            end

            next             if vals.empty?
            edge[:psi][type]  = vals.values.max
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

    # Loop through each edge and assign heat loss to linked surfaces.
    edges.each do |identifier, edge|
      next unless  edge.key?(:psi)
      rsi        = 0
      max        = edge[:psi].values.max
      type       = edge[:psi].key(max)
      length     = edge[:length]
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
      next if apertures.size > 1                        # edge links 2x openings

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
          s[:heatloss]    = 0 unless s.key?(:heatloss)
          s[:heatloss]   += json[:khi].point[k[:id]] * k[:count]
          s[:pts]         = {} unless s.key?(:pts)
          s[:pts][k[:id]] = { val: json[:khi].point[k[:id]], n: k[:count] }
        end
      end
    end

    # If user has selected a Ut to meet, e.g. argh'ments:
    #   :uprate_walls
    #   :wall_ut
    #   :wall_option
    # (same triple arguments for roofs and exposed floors)
    # ... first 'uprate' targeted insulation layers (see ua.rb) before derating.
    # Check for new argh keys [:wall_uo], [:roof_uo] and/or [:floor_uo].
    up = argh[:uprate_walls] || argh[:uprate_roofs] || argh[:uprate_floors]
    uprate(model, tbd[:surfaces], argh)                                    if up

    # Derated (cloned) constructions are unique to each deratable surface.
    # Unique construction names are prefixed with the surface name,
    # and suffixed with " tbd", indicating that the construction is
    # henceforth thermally derated. The " tbd" expression is also key in
    # avoiding inadvertent derating - TBD will not derate constructions
    # (or rather layered materials) having " tbd" in their OpenStudio name.
    tbd[:surfaces].each do |id, surface|
      next unless surface.key?(:construction)
      next unless surface.key?(:index       )
      next unless surface.key?(:ltype       )
      next unless surface.key?(:r           )
      next unless surface.key?(:edges       )
      next unless surface.key?(:heatloss    )
      next unless surface[:heatloss].abs > TOL

      model.getSurfaces.each do |s|
        next unless id == s.nameString
        index           = surface[:index       ]
        current_c       = surface[:construction]
        c               = current_c.clone(model).to_LayeredConstruction.get
        m               = nil
        m               = derate(model, id, surface, c)                 if index
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
          surface[:u    ] = 1 / current_R       # un-derated U-factors (for UA')
        end
      end
    end

    # Ensure deratable surfaces have U-factors (even if NOT derated).
    tbd[:surfaces].each do |id, surface|
      next unless surface[:deratable]
      next unless surface.key?(:construction)
      next     if surface.key?(:u)
      s         = model.getSurfaceByName(id)
      log(ERR, "Skipping missing surface '#{id}' (#{mth})")          if s.empty?
      next                                                           if s.empty?
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
      next  unless e.key?(:psi)
      next  unless e.key?(:set)
      v          = e[:psi].values.max
      set        = e[:set]
      t          = e[:psi].key(v)
      l          = e[:length]
      edge       = { psi: set, type: t, length: l, surfaces: e[:surfaces].keys }
      edge[:v0x] = e[:v0].point.x
      edge[:v0y] = e[:v0].point.y
      edge[:v0z] = e[:v0].point.z
      edge[:v1x] = e[:v1].point.x
      edge[:v1y] = e[:v1].point.y
      edge[:v1z] = e[:v1].point.z

      json[:io][:edges] << edge
    end

    empty = json[:io][:edges].empty?
    json[:io][:edges].sort_by { |e| [ e[:v0x], e[:v0y], e[:v0z],
                                      e[:v1x], e[:v1y], e[:v1z] ] } unless empty
    json[:io].delete(:edges)                                            if empty

    # Populate UA' trade-off reference values (optional).
    ua = argh[:gen_ua] && argh[:ua_ref] && argh[:ua_ref] == "code (Quebec)"
    qc33(tbd[:surfaces], json[:psi], setpoints)                            if ua

    tbd[:io] = json[:io]

    tbd
  end

  ##
  # TBD exit strategy for OpenStudio Measures. May write out TBD model
  # content/results if requested (see argh). Always writes out minimal logs,
  # (see tbd.out.json).
  #
  # @param runner [Runner] OpenStudio Measure runner
  # @param argh [Hash] TBD arguments
  #
  # @return [Bool] true if TBD Measure is successful
  def exit(runner = nil, argh = {})
    # Generated files target a design context ( >= WARN ) ... change TBD log
    # level for debugging purposes. By default, log status is set < DBG
    # while log level is set @INF.
    state = msg(status)
    state = msg(INF)          if status.zero?
    argh            = {}  unless argh.is_a?(Hash)
    argh[:io      ] = nil unless argh.key?(:io)
    argh[:surfaces] = nil unless argh.key?(:surfaces)

    unless argh[:io] && argh[:surfaces]
      state = "Halting all TBD processes, yet running OpenStudio"
      state = "Halting all TBD processes, and halting OpenStudio"      if fatal?
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

    groups              = { wall: {}, roof: {}, floor: {} }
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
      output = "An initial #{label.to_s} Uo of #{uo} W/m2•K is required to "   \
               "achieve an overall Ut of #{ut} W/m2•K for #{g[:op]}"
      u_t << output
      runner.registerInfo(output)
    end

    tbd_log[:ut] = u_t unless u_t.empty?
    ua_md_en     = nil
    ua_md_fr     = nil
    ua           = nil
    ok           = argh[:surfaces] && argh[:gen_ua]
    ua           = ua_summary(tbd_log[:date], argh)                        if ok

    unless fatal? || ua.nil? || ua.empty?
      if ua.key?(:en)
        if ua[:en].key?(:b1) || ua[:en].key?(:b2)
          runner.registerInfo("-")
          runner.registerInfo(ua[:model])
          tbd_log[:ua] = {}
          ua_md_en     = ua_md(ua, :en)
          ua_md_fr     = ua_md(ua, :fr)
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
        ratio     = format("%4.1f", surface[:ratio])
        output    = "RSi derated by #{ratio}% : #{id}"

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
    match1 = /WorkingFiles/.match(file_paths[1].to_s)
    match2 = /files/.match(file_paths[1].to_s)
    match  = match1 || match2

    if file_paths.size >= 2 && File.exists?(file_paths[1].to_s) && match
      out_dir = file_paths[1].to_s
    elsif !file_paths.empty? && File.exists?(file_paths.first.to_s)
      out_dir = file_paths.first.to_s
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

    unless TBD.fatal? || ua.nil? || ua.empty?
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
