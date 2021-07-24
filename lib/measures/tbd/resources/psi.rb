require "openstudio"

begin
  # Topolys: try to load from the gem
  require "topolys"
rescue LoadError
  require_relative "geometry.rb"
  require_relative "model.rb"
  require_relative "transformation.rb"
  require_relative "version.rb"
end

require_relative "conditioned.rb"
require_relative "framedivider.rb"
require_relative "log.rb"

# Set 10mm tolerance for edge (thermal bridge) vertices.
TOL = 0.01

# Sources for thermal bridge types and/or linked default KHI & PSI values/sets:

# BETBG = Building Envelope Thermal Bridging Guide v1.4
# www.bchydro.com/content/dam/BCHydro/customer-portal/documents/power-smart/
# business/programs/BETB-Building-Envelope-Thermal-Bridging-Guide-v1-4.pdf

# ISO 14683 (Appendix C) www.iso.org/standard/65706.html

# NECB-QC: Québec's energy code for new commercial buildings
# www2.publicationsduquebec.gouv.qc.ca/dynamicSearch/
# telecharge.php?type=1&file=72541.pdf

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
  #
  # @return [Bool] Returns true if successful in appending KHI pair
  def append(k)
    unless k.is_a?(Hash)
      TBD.log(TBD::ERROR, "Can't append invalid KHI pair - skipping")
      return false
    end
    unless k.has_key?(:id)
      TBD.log(TBD::ERROR, "Missing KHI pair ID - skipping")
      return false
    end
    if @point.has_key?(k[:id])
      TBD.log(TBD::ERROR, "Can't override '#{k[:id]}' KHI pair - skipping")
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
  # @return [Hash] shorthand listing of PSI types in a set
  # @return [Hash] shorthand listing of PSI values in a set
  attr_reader :set
  attr_reader :has
  attr_reader :val

  ##
  # Construct a new PSI library (with defaults)
  def initialize
    @set = {}
    @has = {}
    @val = {}

    # The following are default PSI values (* published, ** calculated). Users
    # may edit these sets, add new sets here, or read-in custom sets from a TBD
    # JSON input file. PSI units are in W/K per linear meter. The spandrel sets
    # are added as practical suggestions in early design stages.

    # Convex vs concave PSI adjustments may be warranted if there is a mismatch
    # between dimensioning conventions (interior vs exterior) used for the OSM
    # vs published PSI data. For instance, the BETBG data reflects an interior
    # dimensioning convention, while ISO 14683 reports PSI values for both
    # conventions. The following may be used to adjust BETBG PSI values for
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
    self.genShorthands("poor (BETBG)")

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
    self.genShorthands("regular (BETBG)")

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
    self.genShorthands("efficient (BETBG)")

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
    self.genShorthands("spandrel (BETBG)")

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
    }.freeze               # "good" to "high performance" curtainwall spandrels
    self.genShorthands("spandrel HP (BETBG)")

    @set["code (Quebec)"] = # NECB-QC (code-compliant) defaults:
    {
      rimjoist:      0.300, # *
      parapet:       0.325, # *
      fenestration:  0.350, # ** "regular (BETBG)"
      corner:        0.300, # ** "regular (BETBG)", adjusted for ext. dimension
      balcony:       0.500, # *
      party:         0.450, # ** "regular (BETBG)"
      grade:         0.450, # *
      joint:         0.200, # ** "regular (BETBG)"
      transition:    0.000
    }.freeze               # based on EXTERIOR dimensions (art. 3.1.1.6)
    self.genShorthands("code (Quebec)")

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
    self.genShorthands("(non thermal bridging)")
  end

  ##
  # Generate PSI set shorthand listings
  # Requires a valid, unique :id.
  #
  # @param [String] p A PSI set identifier
  #
  # @return [Bool] Returns true if successful in generating PSI set shorthands
  def genShorthands(p)
    unless @set.has_key?(p)
      TBD.log(TBD::DEBUG,
        "Can't generate PSI type shorthands with '#{p}' - skipping")
      return false
    end

    h = {}
    h[:joint]           = @set[p].has_key?(:joint)
    h[:transition]      = @set[p].has_key?(:transition)
    h[:fenestration]    = @set[p].has_key?(:fenestration)
    h[:head]            = @set[p].has_key?(:head)
    h[:headconcave]     = @set[p].has_key?(:headconcave)
    h[:headconvex]      = @set[p].has_key?(:headconvex)
    h[:sill]            = @set[p].has_key?(:sill)
    h[:sillconcave]     = @set[p].has_key?(:sillconcave)
    h[:sillconvex]      = @set[p].has_key?(:sillconvex)
    h[:jamb]            = @set[p].has_key?(:jamb)
    h[:jambconcave]     = @set[p].has_key?(:jambconcave)
    h[:jambconvex]      = @set[p].has_key?(:jambconvex)
    h[:corner]          = @set[p].has_key?(:corner)
    h[:cornerconcave]   = @set[p].has_key?(:cornerconcave)
    h[:cornerconvex]    = @set[p].has_key?(:cornerconvex)
    h[:parapet]         = @set[p].has_key?(:parapet)
    h[:partyconcave]    = @set[p].has_key?(:parapetconcave)
    h[:parapetconvex]   = @set[p].has_key?(:parapetconvex)
    h[:party]           = @set[p].has_key?(:party)
    h[:partyconcave]    = @set[p].has_key?(:partyconcave)
    h[:partyconvex]     = @set[p].has_key?(:partyconvex)
    h[:grade]           = @set[p].has_key?(:grade)
    h[:gradeconcave]    = @set[p].has_key?(:gradeconcave)
    h[:gradeconvex]     = @set[p].has_key?(:gradeconvex)
    h[:balcony]         = @set[p].has_key?(:balcony)
    h[:balconyconcave]  = @set[p].has_key?(:balconyconcave)
    h[:balconyconvex]   = @set[p].has_key?(:balconyconvex)
    h[:rimjoist]        = @set[p].has_key?(:rimjoist)
    h[:rimjoistconcave] = @set[p].has_key?(:rimjoistconcave)
    h[:rimjoistconvex]  = @set[p].has_key?(:rimjoistconvex)
    @has[p] = h

    v = {}
    v[:joint]    = 0; v[:transition]      = 0; v[:fenestration]   = 0
    v[:head]     = 0; v[:headconcave]     = 0; v[:headconvex]     = 0
    v[:sill]     = 0; v[:sillconcave]     = 0; v[:sillconvex]     = 0
    v[:jamb]     = 0; v[:jambconcave]     = 0; v[:jambconvex]     = 0
    v[:corner]   = 0; v[:cornerconcave]   = 0; v[:cornerconvex]   = 0
    v[:parapet]  = 0; v[:parapetconcave]  = 0; v[:parapetconvex]  = 0
    v[:party]    = 0; v[:partyconcave]    = 0; v[:partyconvex]    = 0
    v[:grade]    = 0; v[:gradeconcave]    = 0; v[:gradeconvex]    = 0
    v[:balcony]  = 0; v[:balconyconcave]  = 0; v[:balconyconvex]  = 0
    v[:rimjoist] = 0; v[:rimjoistconcave] = 0; v[:rimjoistconvex] = 0

    v[:joint]           = @set[p][:joint]           if h[:joint]
    v[:transition]      = @set[p][:transition]      if h[:transition]
    v[:fenestration]    = @set[p][:fenestration]    if h[:fenestration]
    v[:head]            = @set[p][:fenestration]    if h[:fenestration]
    v[:headconcave]     = @set[p][:fenestration]    if h[:fenestration]
    v[:headconvex]      = @set[p][:fenestration]    if h[:fenestration]
    v[:sill]            = @set[p][:fenestration]    if h[:fenestration]
    v[:sillconcave]     = @set[p][:fenestration]    if h[:fenestration]
    v[:sillconvex]      = @set[p][:fenestration]    if h[:fenestration]
    v[:jamb]            = @set[p][:fenestration]    if h[:fenestration]
    v[:jambconcave]     = @set[p][:fenestration]    if h[:fenestration]
    v[:jambconvex]      = @set[p][:fenestration]    if h[:fenestration]
    v[:head]            = @set[p][:head]            if h[:head]
    v[:headconcave]     = @set[p][:head]            if h[:head]
    v[:headconvex]      = @set[p][:head]            if h[:head]
    v[:sill]            = @set[p][:sill]            if h[:sill]
    v[:sillconcave]     = @set[p][:sill]            if h[:sill]
    v[:sillconvex]      = @set[p][:sill]            if h[:sill]
    v[:jamb]            = @set[p][:jamb]            if h[:jamb]
    v[:jambconcave]     = @set[p][:jamb]            if h[:jamb]
    v[:jambconvex]      = @set[p][:jamb]            if h[:jamb]
    v[:headconcave]     = @set[p][:headconcave]     if h[:headconcave]
    v[:headconvex]      = @set[p][:headconvex]      if h[:headconvex]
    v[:sillconcave]     = @set[p][:sillconcave]     if h[:sillconcave]
    v[:sillconvex]      = @set[p][:sillconvex]      if h[:sillconvex]
    v[:jambconcave]     = @set[p][:jambconcave]     if h[:jambconcave]
    v[:jambconvex]      = @set[p][:jambconvex]      if h[:jambconvex]
    v[:corner]          = @set[p][:corner]          if h[:corner]
    v[:cornerconcave]   = @set[p][:corner]          if h[:corner]
    v[:cornerconvex]    = @set[p][:corner]          if h[:corner]
    v[:cornerconcave]   = @set[p][:cornerconcave]   if h[:cornerconcave]
    v[:cornerconvex]    = @set[p][:cornerconvex]    if h[:cornerconvex]
    v[:parapet]         = @set[p][:parapet]         if h[:parapet]
    v[:parapetconcave]  = @set[p][:parapet]         if h[:parapet]
    v[:parapetconvex]   = @set[p][:parapet]         if h[:parapet]
    v[:parapetconcave]  = @set[p][:parapetconcave]  if h[:parapetconcave]
    v[:parapetconvex]   = @set[p][:parapetconvex]   if h[:parapetconvex]
    v[:party]           = @set[p][:party]           if h[:party]
    v[:partyconcave]    = @set[p][:party]           if h[:party]
    v[:partyconvex]     = @set[p][:party]           if h[:party]
    v[:partyconcave]    = @set[p][:partyconcave]    if h[:partyconcave]
    v[:partyconvex]     = @set[p][:partyconvex]     if h[:partyconvex]
    v[:grade]           = @set[p][:grade]           if h[:grade]
    v[:gradeconcave]    = @set[p][:grade]           if h[:grade]
    v[:gradeconvex]     = @set[p][:grade]           if h[:grade]
    v[:gradeconcave]    = @set[p][:gradeconcave]    if h[:gradeconcave]
    v[:gradeconvex]     = @set[p][:gradeconvex]     if h[:gradeconvex]
    v[:balcony]         = @set[p][:balcony]         if h[:balcony]
    v[:balconyconcave]  = @set[p][:balcony]         if h[:balcony]
    v[:balconyconvex]   = @set[p][:balcony]         if h[:balcony]
    v[:balconyconcave]  = @set[p][:balconyconcave]  if h[:balconyconcave]
    v[:balconyconvex]   = @set[p][:balconyconvex]   if h[:balconyconvex]
    v[:rimjoist]        = @set[p][:rimjoist]        if h[:rimjoist]
    v[:rimjoistconcave] = @set[p][:rimjoist]        if h[:rimjoist]
    v[:rimjoistconvex]  = @set[p][:rimjoist]        if h[:rimjoist]
    v[:rimjoistconcave] = @set[p][:rimjoistconcave] if h[:rimjoistconcave]
    v[:rimjoistconvex]  = @set[p][:rimjoistconvex]  if h[:rimjoistconvex]

    max = [v[:parapetconcave], v[:parapetconvex]].max
    v[:parapet] = max unless @has[:parapet]
    @val[p] = v
    true
  end

  ##
  # Append a new PSI set, based on a TBD JSON-formatted PSI set object.
  # Requires a valid, unique :id.
  #
  # @param [Hash] p A (identifier):(PSI set) pair
  #
  # @return [Bool] Returns true if successful in appending PSI set
  def append(p)
    unless p.is_a?(Hash)
      TBD.log(TBD::ERROR, "Can't append invalid PSI set - skipping")
      return false
    end
    unless p.has_key?(:id)
      TBD.log(TBD::ERROR, "Missing PSI set ID - skipping")
      return false
    end
    if @set.has_key?(p[:id])
      TBD.log(TBD::ERROR, "Can't override '#{p[:id]}' PSI set  - skipping")
      return false
    end

    s = {}
    # Most PSI types have concave and convex variants, depending on the polar
    # position of deratable surfaces around an edge-as-thermal-bridge. One
    # exception is :fenestration, which TBD later breaks down into :head, :sill
    # or :jamb edge types. Another exception is a :joint edge, a PSI type that
    # is not autoassigned to an edge (i.e., only via a TBD JSON input file).
    # Finally, transitions are autoassigned by TBD precively when an edge is
    # "flat" i.e., no noticeable polar angle difference between surfaces.
    s[:rimjoist]        = p[:rimjoist]        if p.has_key?(:rimjoist)
    s[:rimjoistconcave] = p[:rimjoistconcave] if p.has_key?(:rimjoistconcave)
    s[:rimjoistconvex]  = p[:rimjoistconvex]  if p.has_key?(:rimjoistconvex)
    s[:parapet]         = p[:parapet]         if p.has_key?(:parapet)
    s[:parapetconcave]  = p[:parapetconcave]  if p.has_key?(:parapetconcave)
    s[:parapetconvex]   = p[:parapetconvex]   if p.has_key?(:parapetconvex)
    s[:head]            = p[:head]            if p.has_key?(:head)
    s[:headconcave]     = p[:headconcave]     if p.has_key?(:headconcave)
    s[:headconvex]      = p[:headconvex]      if p.has_key?(:headconvex)
    s[:sill]            = p[:sill]            if p.has_key?(:sill)
    s[:sillconcave]     = p[:sillconcave]     if p.has_key?(:sillconcave)
    s[:sillconvex]      = p[:sillconvex]      if p.has_key?(:sillconvex)
    s[:jamb]            = p[:jamb]            if p.has_key?(:jamb)
    s[:jambconcave]     = p[:jambconcave]     if p.has_key?(:jambconcave)
    s[:jambconvex]      = p[:jambconvex]      if p.has_key?(:jambconcave)
    s[:corner]          = p[:corner]          if p.has_key?(:corner)
    s[:cornerconcave]   = p[:cornerconcave]   if p.has_key?(:cornerconcave)
    s[:cornerconvex]    = p[:cornerconvex]    if p.has_key?(:cornerconvex)
    s[:balcony]         = p[:balcony]         if p.has_key?(:balcony)
    s[:balconyconcave]  = p[:balconyconcave]  if p.has_key?(:balconyconcave)
    s[:balconyconvex]   = p[:balconyconvex]   if p.has_key?(:balconyconvex)
    s[:party]           = p[:party]           if p.has_key?(:party)
    s[:partyconcave]    = p[:partyconcave]    if p.has_key?(:partyconcave)
    s[:partyconvex]     = p[:partyconvex]     if p.has_key?(:partyconvex)
    s[:grade]           = p[:grade]           if p.has_key?(:grade)
    s[:gradeconcave]    = p[:gradeconcave]    if p.has_key?(:gradeconcave)
    s[:gradeconvex]     = p[:gradeconvex]     if p.has_key?(:gradeconvex)

    s[:fenestration]    = p[:fenestration]    if p.has_key?(:fenestration)
    s[:joint]           = p[:joint]           if p.has_key?(:joint)
    s[:transition]      = p[:transition]      if p.has_key?(:transition)

    s[:joint]           = 0.000 unless p.has_key?(:joint)
    s[:transition]      = 0.000 unless p.has_key?(:transition)

    @set[p[:id]] = s
    self.genShorthands(p[:id])
    true
  end

  ##
  # Generate shorthand hash of PSI content (empty hashes if invalid ID)
  #
  # @param [String] p A PSI set identifier
  #
  # @return [Hash] Returns true/false statements as to PSI content
  # @return [Hash] Returns implicitly calculated or explicitly-set PSI values
  def shorthands(p)
    h = {}
    v = {}
    return @has[p], @val[p] if @set.has_key?(p)
    return h, v
  end

  ##
  # Validate whether a stored PSI set has a complete list of PSI type:values
  #
  # @param [String] p A PSI set identifier
  #
  # @return [Bool] Returns true if stored and has a complete PSI set
  def complete?(p)
    unless @set.has_key?(p) && @has.has_key?(p) && @val.has_key?(p)
      TBD.log(TBD::ERROR,
        "Can't find #{p} PSI set (and assess if it's 'complete') - skipping")
      return false
    end

    holes = []
    holes << :head if @has[p][:head]
    holes << :sill if @has[p][:sill]
    holes << :jamb if @has[p][:jamb]
    ok = holes.size == 3
    ok = true if @has[p][:fenestration]
    return false unless ok

    corners = []
    corners << :concave if @has[p][:cornerconcave]
    corners << :convex  if @has[p][:cornerconvex]
    ok = corners.size == 2
    ok = true if @has[p][:corner]
    return false unless ok

    parapets = []
    parapets << :concave if @has[p][:parapetconcave]
    parapets << :convex  if @has[p][:parapetconvex]
    ok = parapets.size == 2
    ok = true if @has[p][:parapet]
    return false unless ok

    return false unless @has[p][:party]
    return false unless @has[p][:grade]
    return false unless @has[p][:balcony]
    return false unless @has[p][:rimjoist]
    ok
  end

  ##
  # Return safe PSI type if missing input from PSI set (relies on inheritance)
  # @param [String] p A PSI set identifier
  # @param [Hash] type PSI type e.g., :rimjoistconcave
  #
  # @return [Symbol] Returns safe type; nil if none were found
  def safeType(p, type)
    ok = @set.has_key?(p)
    tt = type
    tt = tt.to_sym unless tt.is_a?(Symbol)
    unless @has[p][tt]
      tt_concave = tt.to_s.include?("concave")
      tt_convex  = tt.to_s.include?("convex")
      tt = tt.to_s.chomp("concave").to_sym if tt_concave
      tt = tt.to_s.chomp("convex").to_sym  if tt_convex
      unless @has[p][tt]
        tt = :fenestration if tt == :head
        tt = :fenestration if tt == :sill
        tt = :fenestration if tt == :jamb
      end
    end
    return tt if @has[p][tt]
    nil
  end
end

##
# Check for matching vertex pairs between edges (10mm tolerance)
# @param [Hash] e1 First edge
# @param [Hash] e2 Second edge
#
# @return [Bool] Returns true if edges share vertex pairs
def matches?(e1, e2)
  unless e1 && e2
    TBD.log(TBD::DEBUG,
      "Invalid matching edge arguments - skipping")
    return false
  end
  unless e1.has_key?(:v0) && e1.has_key?(:v1) &&
         e2.has_key?(:v0) && e2.has_key?(:v1)
    TBD.log(TBD::DEBUG,
      "Missing vertices for matching edge(s) - skipping")
    return false
  end
  cl = Topolys::Point3D
  unless e1[:v0].is_a?(cl) && e1[:v1].is_a?(cl) &&
         e2[:v0].is_a?(cl) && e2[:v1].is_a?(cl)
    TBD.log(TBD::DEBUG,
      "#{cl}? Expecting Topolys 3D points for matching edge(s) - skipping")
    return false
  end

  e1_vector = e1[:v1] - e1[:v0]
  e2_vector = e2[:v1] - e2[:v0]
  if e1_vector.magnitude < TOL || e2_vector.magnitude < TOL
    TBD.log(TBD::DEBUG,
      "Matching edge lengths below TOL - skipping")
    return false
  end

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
# Process TBD user inputs, after TBD has processed OpenStudio model variables
# and retrieved corresponding Topolys model surface/edge properties. TBD user
# inputs allow customization of default assumptions and inferred values.
# If successful, "edges" (input) may inherit additional properties, e.g.:
# :io_set  = edge-specific PSI set, held in TBD JSON file
# :io_type = edge-specific PSI type (e.g. "corner"), held in TBD JSON file
# :io_building = project-wide PSI set, if absent from TBD JSON file
#
# @param [Hash] surfaces Preprocessed collection of TBD surfaces
# @param [Hash] edges Preprocessed collection TBD edges
# @param [String] set Default) PSI set identifier, can be "" (empty)
# @param [String] ioP Path to a user-set TBD JSON input file (optional)
# @param [String] schemaP Path to a TBD JSON schema file (optional)
#
# @return [Hash] Returns a JSON-generated collection of user inputs; nil if fail
# @return [Hash] Returns a new PSI library, enriched with optional sets on file
# @return [Hash] Returns a new KHI library, enriched with optional pairs on file
def processTBDinputs(surfaces, edges, set, ioP = nil, schemaP = nil)
  io  = {}
  psi = PSI.new                  # PSI hash, initially holding built-in defaults
  khi = KHI.new                  # KHI hash, initially holding built-in defaults

  unless surfaces && edges && surfaces.class == Hash && edges.class == Hash
    TBD.log(TBD::DEBUG,
      "Can't process JSON TBD inputs - invalid arguments")
    return io, psi, khi
  end

  if ioP && File.size?(ioP)         # optional input file exists and is non-zero
    ioC = File.read(ioP)
    io = JSON.parse(ioC, symbolize_names: true)

    # Schema validation is not yet supported in the OpenStudio Application.
    # JSON validation relies on case-senitive string comparisons (e.g.
    # OpenStudio space or surface names, vs corresponding TBD JSON identifiers).
    # So "Space-1" would not match "SPACE-1".Head's up for a future user guide.
    if schemaP
      require "json-schema"
      if File.exist?(schemaP)
        unless File.zero?(schemaP)
          schemaC = File.read(schemaP)
          schema = JSON.parse(schemaC, symbolize_names: true)
          unless JSON::Validator.validate!(schema, io)
            TBD.log(TBD::FATAL, "Invalid TBD JSON input file (vs schema)")
            return nil, psi, khi
          end
        else
          TBD.log(TBD::FATAL, "Empty TBD JSON schema file")
          return nil, psi, khi
        end
      else
        TBD.log(TBD::FATAL, "Can't locate/open TBD JSON schema file")
        return nil, psi, khi
      end
    end

    # Append to library of linear & point thermal bridges
    io[:psis].each { |p| psi.append(p) } if io.has_key?(:psis)
    io[:khis].each { |k| khi.append(k) } if io.has_key?(:khis)

    if io.has_key?(:building)
      unless io[:building].has_key?(:psi)
        TBD.log(TBD::FATAL, "Invalid building PSI set (TBD JSON file)")
        return nil, psi, khi
      end
    else
      # No building PSI on file - "set" must default to a built-in PSI set.
      io[:building] = { psi: set }             # i.e. default PSI set & no KHI's
    end

    p = io[:building][:psi]
    unless psi.complete?(p)
      TBD.log(TBD::FATAL, "Incomplete building PSI set '#{p}'")
      return nil, psi, khi
    end

    if io.has_key?(:stories)
      io[:stories].each do |story|
        if story.has_key?(:id) && story.has_key?(:psi)
          i = story[:id]
          match = false
          surfaces.values.each do |properties|
            next if match
            next unless properties.has_key?(:story)
            st = properties[:story]
            match = true if i = st.nameString
          end
          unless match
            TBD.log(TBD::ERROR, "Missing OSM story '#{i}' - skipping")
          end
          unless psi.set.has_key?(story[:psi])
            TBD.log(TBD::ERROR, "Missing story '#{i}' PSI set - skipping")
          end
        else
          TBD.log(TBD::FATAL, "Invalid story entry (TBD JSON file)")
          return nil, psi, khi
        end
      end
    end

    if io.has_key?(:spacetypes)
      io[:spacetypes].each do |stype|
        if stype.has_key?(:id) && stype.has_key?(:psi)
          i = stype[:id]
          match = false
          surfaces.values.each do |properties|
            next if match
            next unless properties.has_key?(:stype)
            spt = properties[:stype]
            match = true if i = spt.nameString
          end
          unless match
            TBD.log(TBD::ERROR, "Missing OSM spacetype '#{i}' - skipping")
          end
          unless psi.set.has_key?(stype[:psi])
            TBD.log(TBD::ERROR, "Missing spacetype '#{i}' PSI set - skipping")
          end
        else
          TBD.log(TBD::FATAL, "Invalid spacetype entry (TBD JSON file)")
          return nil, psi, khi
        end
      end
    end

    if io.has_key?(:spaces)
      io[:spaces].each do |space|
        if space.has_key?(:id) && space.has_key?(:psi)
          i = space[:id]
          match = false
          surfaces.values.each do |properties|
            next if match
            next unless properties.has_key?(:space)
            sp = properties[:space]
            match = true if i == sp.nameString
          end
          unless match
            TBD.log(TBD::ERROR, "Missing OSM space '#{i}' - skipping")
          end
          unless psi.set.has_key?(space[:psi])
            TBD.log(TBD::ERROR, "Missing space '#{i}' PSI set - skipping")
          end
        else
          TBD.log(TBD::FATAL, "Invalid space entry (TBD JSON file")
          return nil, psi, khi
        end
      end
    end

    if io.has_key?(:surfaces)
      io[:surfaces].each do |surface|
        if surface.has_key?(:id)
          i = surface[:id]
          unless surfaces.has_key?(i)
            TBD.log(TBD::ERROR, "Missing TBD surface '#{i}' - skipping")
          end

          # surfaces can optionally hold custom PSI sets and/or KHI data
          if surface.has_key?(:psi)
            unless psi.set.has_key?(surface[:psi])
              TBD.log(TBD::ERROR, "Missing surface '#{i}' PSI set - skipping")
            end
          end
          if surface.has_key?(:khis)
            surface[:khis].each do |k|
              next unless k.has_key?(:id)
              ii = k[:id]
              unless khi.point.has_key?(ii)
                TBD.log(TBD::ERROR, "Missing surface '#{i}' KHI pair '#{ii}'")
              end
            end
          end
        else
          TBD.log(TBD::FATAL, "Invalid surface entry (TBD JSON file)")
          return nil, psi, khi
        end
      end
    end

    if io.has_key?(:subsurfaces)
      io[:subsurfaces].each do |sub|
        if sub.has_key?(:id) && sub.has_key?(:usi)
          i = sub[:id]
          match = false
          surfaces.each do |id, surface|
            if surface.has_key?(:windows)
              surface[:windows].each do |ii, window|
                next if match
                match = true if i == ii
              end
            end
            if surface.has_key?(:doors)
              surface[:doors].each do |ii, door|
                next if match
                match = true if i == ii
              end
            end
            if surface.has_key?(:skylights)
              surface[:skylights].each do |ii, skylight|
                next if match
                match = true if i == ii
              end
            end
          end
          unless match
            TBD.log(TBD::ERROR, "Missing OSM subsurface '#{i}' - skipping")
          end
        else
          TBD.log(TBD::FATAL, "Invalid subsurface entry (TBD JSON file)")
          return nil, psi, khi
        end
      end
    end

    if io.has_key?(:edges)
      io[:edges].each do |edge|
        if edge.has_key?(:type) && edge.has_key?(:surfaces)
          t = edge[:type].to_sym
          tt = psi.safeType(p, t)    # 'complete' building PSI set as a fallback
          unless tt
            TBD.log(TBD::ERROR, "Invalid edge PSI type '#{t}' - skipping")
            next
          end
          # One or more edges on file are valid if all their listed surfaces
          # together connect at least one or more edges in TBD/Topolys (in
          # memory). The latter may connect e.g. 3x TBD/Topolys surfaces, but
          # the list of surfaces on file may be shorter, e.g. only 2x surfaces.
          valid = true
          edge[:surfaces].each do |s|                     # JSON objects on file
            edges.values.each do |e|             # TBD/Topolys objects in memory
              next unless valid                   # if previous anomaly detected
              next if e.has_key?(:io_type)        # validated from previous loop
              match = false
              next unless e.has_key?(:surfaces)
              next unless e[:surfaces].has_key?(s)

              match = true # ... yet all JSON surfaces must be linked in Topolys
              edge[:surfaces].each do |ss|
                match = false unless e[:surfaces].has_key?(ss)
              end
              next unless match

              if edge.has_key?(:length)  # optional, narrows down search (~10mm)
                match = false unless (e[:length] - edge[:length]).abs < TOL
              end
              next unless match

              if edge.has_key?(:v0x) ||     # optional, narrows down to vertices
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
                  TBD.log(TBD::ERROR, "Missing '#{s}' edge vertices - skipping")
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
                e2[:v0] = e[:v0].point
                e2[:v1] = e[:v1].point
                next unless matches?(e1, e2)
              end

              if edge.has_key?(:psi)                                  # optional
                pp = edge[:psi]
                if psi.set.has_key?(pp)
                  ttt = psi.safeType(pp, t)
                  if ttt
                    e[:io_set] = pp
                    e[:io_type] = t    # success - matching type with custom PSI
                  else
                    TBD.log(TBD::ERROR,
                      "Invalid '#{s}' '#{p}' type '#{t}' - skipping")
                    valid = false
                  end
                else
                  TBD.log(TBD::ERROR,
                    "Missing '#{s}' edge PSI set - skipping")
                  valid = false
                end
              else
                e[:io_type] = t     # success: matching edge - setting edge type
              end

            end
          end
        else
          TBD.log(TBD::FATAL, "Invalid edge entry (TBD JSON file)")
          return nil, psi, khi
        end
      end
    end
  else
    # No (optional) user-defined TBD JSON input file.
    # In such cases, "set" must refer to a valid PSI set
    if psi.complete?(set)
      io[:building] = { psi: set }             # i.e. default PSI set & no KHI's
    else
      TBD.log(TBD::FATAL, "Incomplete building PSI set '#{set}'")
      return nil, psi, khi
    end
  end
  return io, psi, khi
end

##
# Return OpenStudio site/space transformation & rotation; nil if unsuccessful
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [OpenStudio::Model::Space or ::ShadingSurfaceGroup] group An OS group
#
# @return [OpenStudio::Transformation] Returns group/site transformation
# @return [Float] Returns site + group rotation angle [0,2PI) radians
def transforms(model, group)
  gr1 = OpenStudio::Model::Space
  gr2 = OpenStudio::Model::ShadingSurfaceGroup
  unless model && group && model.is_a?(OpenStudio::Model::Model) &&
        (group.is_a?(gr1) || group.is_a?(gr2))
    TBD.log(TBD::DEBUG,
      "Invalid arguments for transformation/rotation - skipping")
    return nil, nil
  end

  t = group.siteTransformation
  r = group.directionofRelativeNorth + model.getBuilding.northAxis
  return t, r
end

##
# Return site-specific (or absolute) Topolys surface normal; nil unsuccessful
#
# @param [OpenStudio::Model::PlanarSurface] s An OS planar surface
# @param [Float] r A rotation angle [0,360) degrees
#
# @return [OpenStudio::Vector3D] Returns normal vector <x,y,z> of s
def trueNormal(s, r)
  unless s && r && s.is_a?(OpenStudio::Model::PlanarSurface) && r.is_a?(Numeric)
    TBD.log(TBD::DEBUG,
      "Invalid arguments for true normals - skipping")
    return nil
  end

  r = -r * Math::PI / 180.0
  Topolys::Vector3D.new(s.outwardNormal.x * Math.cos(r) -
                        s.outwardNormal.y * Math.sin(r),                     # x
                        s.outwardNormal.x * Math.sin(r) +
                        s.outwardNormal.y * Math.cos(r),                     # y
                        s.outwardNormal.z)                                   # z
end

##
# Validate whether edge surfaces form a concave angle, as seen from outside.
#
# @param [Surface] s1 A first TBD surface
# @param [Surface] s2 A second TBD surface
#
# @return [Bool] Returns true if angle between surfaces is concave; nil if fail.
def concave?(s1, s2)
  unless s1.is_a?(Hash)            && s2.is_a?(Hash)            &&
         s1.has_key?(:angle)       && s2.has_key?(:angle)       &&
         s1[:angle].is_a?(Numeric) && s2[:angle].is_a?(Numeric) &&
         s1.has_key?(:normal)      && s2.has_key?(:normal)      &&
         s1.has_key?(:polar)       && s2.has_key?(:polar)

    TBD.log(TBD::DEBUG,
      "Invalid arguments determining concavity - skipping")
    return false
  end

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
# @param [Surface] s1 A first TBD surface
# @param [Surface] s2 A second TBD surface
#
# @return [Bool] Returns true if angle between surfaces is convex
def convex?(s1, s2)
  unless s1.is_a?(Hash)            && s2.is_a?(Hash)            &&
         s1.has_key?(:angle)       && s2.has_key?(:angle)       &&
         s1[:angle].is_a?(Numeric) && s2[:angle].is_a?(Numeric) &&
         s1.has_key?(:normal)      && s2.has_key?(:normal)      &&
         s1.has_key?(:polar)       && s2.has_key?(:polar)

    TBD.log(TBD::DEBUG,
      "Invalid arguments determining convexity - skipping")
    return false
  end

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
# Return Topolys vertices and a Topolys wire from Topolys points. As
# a side effect, it will - if successful - also populate the Topolys
# model with the vertices and wire.
#
# @param [Topolys::Model] model An OS model
# @param [Array] points A 1D array of 3D Topolys points (min 2x)
#
# @return [Array] Returns a 1D array of 3D Topolys vertices
# @return [Topolys::Wire] Returns a corresponding Topolys wire
def topolysObjects(model, points)
  unless model && points
    TBD.log(TBD::DEBUG,
      "Invalid Topolys (objects) arguments - skipping")
    return nil, nil
  end
  unless model.is_a?(Topolys::Model)
    TBD.log(TBD::DEBUG,
      "#{model.class}? expected Topolys model (objects) - skipping")
    return nil, nil
  end
  unless points.is_a?(Array)
    TBD.log(TBD::DEBUG,
      "#{points.class}? expected Topolys points Array (objects) - skipping")
    return nil, nil
  end
  unless points.size > 2
    TBD.log(TBD::DEBUG,
      "#{points.size}? expected +2 Topolys points (objects) - skipping")
    return nil, nil
  end

  vertices = model.get_vertices(points)
  wire = model.get_wire(vertices)
  return vertices, wire
end

##
# Populate collection of TBD "kids", i.e. subsurfaces, relying on Topolys. As
# a side effect, it will - if successful - also populate the Topolys
# model with Topolys vertices, wires, holes.
#
# @param [Topolys::Model] model A Topolys model
# @param [Hash] kids A collection of TBD subsurfaces
#
# @return [Array] Returns a 1D array of 3D Topolys holes, i.e. wires
def populateTBDkids(model, kids)
  holes = []
  unless model && kids
    TBD.log(TBD::DEBUG,
      "Invalid TBD (kids) arguments - skipping")
    return holes
  end
  unless model.is_a?(Topolys::Model)
    TBD.log(TBD::DEBUG,
      "#{model.class}? expected Topolys model (kids) - skipping")
    return holes
  end
  unless kids.is_a?(Hash)
    TBD.log(TBD::DEBUG,
      "#{kids.class}? expected surface Hash (kids) - skipping")
    return holes
  end

  kids.each do |id, properties|
    vtx, hole = topolysObjects(model, properties[:points])
    if vtx && hole
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
# @param [Topolys::Model] model A Topolys model
# @param [Hash] dads A collection of TBD (parent) surfaces
#
# @return [Array] Returns a 1D array of 3D Topolys parent holes, i.e. wires
def populateTBDdads(model, dads)
  tbd_holes = {}
  unless model && dads
    TBD.logs(TBD::DEBUG,
      "Invalid TBD (dads) arguments - skipping")
    return tbd_holes
  end
  unless model.is_a?(Topolys::Model)
    TBD.log(TBD::DEBUG,
      "#{model.class}? expected Topolys model (dads) - skipping")
    return tbd_holes
  end
  unless dads.is_a?(Hash)
    TBD.log(TBD::DEBUG,
      "#{dads.class}? expected surface Hash (dads) - skipping")
    return tbd_holes
  end

  dads.each do |id, properties|
    vertices, wire = topolysObjects(model, properties[:points])
    next unless vertices && wire

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
    unless face
      TBD.log(TBD::DEBUG,
        "Unable to retrieve valid face (dads) - skipping")
      next
    end

    face.attributes[:id] = id
    face.attributes[:n] = properties[:n] if properties.has_key?(:n)
    properties[:face] = face

    # Populate hash of created holes (to return).
    holes.each { |h| tbd_holes[h.attributes[:id]] = h }
  end
  tbd_holes
end

##
# Populate TBD edges with linked Topolys faces.
#
# @param [Hash] surfaces A collection of TBD surfaces
# @param [Hash] edges A collection TBD edges
#
# @return [Bool] Returns true if successful
def tbdSurfaceEdges(surfaces, edges)
  unless surfaces && edges
    TBD.log(TBD::DEBUG,
      "Invalid TBD (edges) arguments - skipping")
    return false
  end
  unless surfaces.is_a?(Hash)
    TBD.log(TBD::DEBUG,
      "#{surfaces.class}? expected TBD surfaces Hash (edges) - skipping")
    return false
  end
  unless edges.is_a?(Hash)
    TBD.log(TBD::DEBUG,
      "#{edges.class}? expected TBD edges Hash (edges) - skipping")
    return false
  end

  surfaces.each do |id, properties|
    unless properties.has_key?(:face)
      TBD.log(TBD::DEBUG,
        "Missing Topolys face for '#{id}' (edges) - skipping")
      next
    end
    properties[:face].wires.each do |wire|
      wire.edges.each do |e|
        unless edges.has_key?(e.id)
          edges[e.id] = { length: e.length,
                          v0: e.v0,
                          v1: e.v1,
                          surfaces: {} }
        end
        unless edges[e.id][:surfaces].has_key?(id)
          edges[e.id][:surfaces][id] = { wire: wire.id }
        end
      end
    end
  end
  true
end

##
# Generate OSM Kiva settings and objects if model surfaces have 'foundation'
# boundary conditions.
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [Hash] floors TBD-generated floors
# @param [Hash] walls TBD-generated walls
# @param [Hash] edges TBD-generated edges (many linking floors & walls
#
# @return [Bool] Returns true if Kiva foundations are successfully generated.
def generateKiva(model, walls, floors, edges)
  unless model && walls && floors && edges
    TBD.log(TBD::DEBUG,
      "Invalid OpenStudio model, can't generate KIVA inputs - skipping")
    return false
  end
  cl = OpenStudio::Model::Model
  cl2 = model.class
  unless model.is_a?(cl)
    TBD.log(TBD::DEBUG,
      "#{cl2}? expected #{cl}, can't generate KIVA inputs - skipping")
    return false
  end
  cl2 = walls.class
  unless walls.is_a?(Hash)
    TBD.log(TBD::DEBUG,
      "#{cl2}? expected walls Hash, can't generate KIVA inputs - skipping")
    return false
  end
  cl2 = floors.class
  unless floors.is_a?(Hash)
    TBD.log(TBD::DEBUG,
      "#{cl2}? expected floors Hash, can't generate KIVA inputs - skipping")
    return false
  end
  cl2 = edges.class
  unless edges.is_a?(Hash)
    TBD.log(TBD::DEBUG,
      "#{cl2}? expected edges Hash, can't generate KIVA inputs - skipping")
    return false
  end

  # Strictly rely on Kiva's total exposed perimeter approach.
  arg = "TotalExposedPerimeter"
  kiva = true

  # The following is loosely adapted from:
  # github.com/NREL/OpenStudio-resources/blob/develop/model/simulationtests/
  # foundation_kiva.rb ... thanks.

  # Generate template for KIVA settings. This is usually not required (the
  # default KIVA settings are fine), but its explicit inclusion in the OSM
  # does offer users easy access to further (manually) tweak settings e.g.,
  # soil properties if required. Initial tests show slight differences in
  # simulation results w/w/o explcit inclusion of the KIVA settings template
  # in the OSM. TO-DO: Check in.idf vs in.osm for any deviation from default
  # values as specified in the IO Reference Manual.
  foundation_kiva_settings = model.getFoundationKivaSettings

  # One way to expose in-built default parameters (in the future), e.g.:
  # soil_k = foundation_kiva_settings.soilConductivity
  # foundation_kiva_settings.setSoilConductivity(soil_k)

  # Generic 1" XPS insulation (for slab-on-grade setup) - unused if basement.
  xps25mm = OpenStudio::Model::StandardOpaqueMaterial.new(model)
  xps25mm.setRoughness("Rough")
  xps25mm.setThickness(0.0254)
  xps25mm.setConductivity(0.029)
  xps25mm.setDensity(28)
  xps25mm.setSpecificHeat(1450)
  xps25mm.setThermalAbsorptance(0.9)
  xps25mm.setSolarAbsorptance(0.7)

  # Tag foundation-facing floors, then walls.
  edges.values.each do |edge|
    edge[:surfaces].keys.each do |id|

      # Start by processing edge-linked foundation-facing floors.
      next unless floors.has_key?(id)
      next unless floors[id][:boundary].downcase == "foundation"

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
        next unless b == "outdoors"
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

      floors[id][:foundation] = OpenStudio::Model::FoundationKiva.new(model)

      # It's assumed that generated foundation walls have insulated
      # constructions. Perimeter insulation for slabs-on-grade.
      # Typical circa-1980 slab-on-grade (perimeter) insulation setup.
      if floors[id][:kiva] == :slab
        floors[id][:foundation].setInteriorHorizontalInsulationMaterial(xps25mm)
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
        exp = floors[id][:exposed]
        #exp = TOL if exp < TOL
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
      model.getSurfaces.each do |s|
        next unless s.nameString == i
        s.setAdjacentFoundation(floors[id][:foundation])
        s.setConstruction(s.construction.get)
      end
    end
  end
  kiva
end

##
# Returns total air film resistance for fenestration (future use)
#
# @param [Float] usi A fenestrated construction's U-factor in W/m2.K
#
# @return [Float] Returns total air film resistance in m2.K/W (0.1216 if errors)
def glazingAirFilmRSi(usi = 5.85)
  # The sum of thermal resistances of calculated exterior and interior film
  # coefficients under standard winter conditions are taken from:
  # https://bigladdersoftware.com/epx/docs/9-5/engineering-reference/
  # window-calculation-module.html#simple-window-model
  #
  # These remain acceptable approximations for flat windows, yet likely
  # unsuitable for subsurfaces with curved or projecting shapes like domed
  # skylights. Given TBD UA' calculation requirements (i.e. reporting only, not
  # affecting simulation inputs), the solution (if ever used) would be
  # considered an adequate fix, awaiting eventual OpenStudio (and EnergyPlus)
  # upgrades to report NFRC 100 (or ISO) air film resistances under standard
  # winter conditions.
  #
  # For U-factors above 8.0 W/m2.K (or invalid input), the function will return
  # 0.1216 m2.K/W, which corresponds to a construction with a single glass layer
  # of thickness 2mm & k = ~0.6 W/m.K, based on the output of the models.
  #
  # The EnergyPlus Engineering calculations were designed for vertical windows
  # - not horizontal, slanted or domed surfaces.
  unless usi && usi.is_a?(Numeric) && usi > TOL
    TBD.log(TBD::DEBUG,
      "Invalid U-factor, can't calculate air film resistance - skipping")
    return 0.4216
  end
  if usi > 8.0
    TBD.log(TBD::WARN,
      "'#{id}' U-factor > 8.0 W/m2.K - using airfilm RSi of 0.1216 m2.K/W")
    return 0.1216
  end

  rsi = 1.0 / (0.025342 * usi + 29.163853)                        # exterior ...

  if usi < 5.85
    return rsi + 1.0 / (0.359073 * Math.log(usi) + 6.949915)    # ... + interior
  else
    return rsi + 1.0 / (1.788041 * usi - 2.886625)              # ... + interior
  end
end

##
# Returns a construction's standard thermal resistance (with air films).
#
# @param [OpenStudio::Model::Construction] construction An OS construction
# @param [Float] film_RSi Thermal resistance of surface air films (m2.K/W)
# @param [Float] temperature Gas temperature (°C) [optional]
#
# @return [Float] Returns construction's calculated RSi; 0 if error
def rsi(construction, film_RSi, temperature = 0.0)
  # This is adapted from BTAP's Material Module's "get_conductance" (Phyl Lopez)
  # https://github.com/NREL/OpenStudio-Prototype-Buildings/blob/
  # c3d5021d8b7aef43e560544699fb5c559e6b721d/lib/btap/measures/
  # btap_equest_converter/envelope.rb#L122
  #
  # Convert C to K.
  t =  temperature + 273.0

  rsi = 0
  unless construction && construction.is_a?(OpenStudio::Model::Construction)
    TBD.log(TBD::DEBUG,
      "Invalid construction, can't calculate RSi - skipping")
    return rsi
  end
  unless film_RSi && film_RSi.is_a?(Numeric)
    TBD.log(TBD::DEBUG,
      "Invalid surface film resistance, can't calculate RSi - skipping")
    return rsi
  end
  rsi = film_RSi

  construction.layers.each do |m|
    # Fenestration materials first (ignoring shades, screens, etc.)
    unless m.to_SimpleGlazing.empty?
      return 1.0 / m.to_SimpleGlazing.get.uFactor              # no need to loop
    end
    unless m.to_StandardGlazing.empty?
      rsi += m.to_StandardGlazing.get.thermalResistance
    end
    unless m.to_RefractionExtinctionGlazing.empty?
      rsi += m.to_RefractionExtinctionGlazing.get.thermalResistance
    end
    unless m.to_Gas.empty?
      rsi += m.to_Gas.get.getThermalResistance(t)
    end
    unless m.to_GasMixture.empty?
      rsi += m.to_GasMixture.get.getThermalResistance(t)
    end

    # Opaque materials next.
    unless m.to_OpaqueMaterial.empty?
      rsi += m.to_OpaqueMaterial.get.thermalResistance
    end
    unless m.to_MasslessOpaqueMaterial.empty?
      rsi += m.to_MasslessOpaqueMaterial.get.thermalResistance
    end
    unless m.to_RoofVegetation.empty?
      rsi += m.to_RoofVegetation.get.thermalResistance
    end
    unless m.to_AirGap.empty?
      rsi += m.to_AirGap.get.getThermalResistance
    end
  end

  rsi
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
  r                = 0.0                        # R-value of insulating material
  index            = nil                        # index of insulating material
  type             = nil                        # nil, :massless; :standard
  i                = 0                          # iterator

  unless construction && construction.is_a?(OpenStudio::Model::Construction)
    TBD.log(TBD::DEBUG,
      "Invalid construction, can't derate insulation layer - skipping")
    return index, type, r
  end

  construction.layers.each do |m|
    unless m.to_MasslessOpaqueMaterial.empty?
      m            = m.to_MasslessOpaqueMaterial.get
      if m.thermalResistance < 0.001 || m.thermalResistance < r
        i += 1
        next
      else
        r          = m.thermalResistance
        index      = i
        type       = :massless
      end
    end

    unless m.to_StandardOpaqueMaterial.empty?
      m            = m.to_StandardOpaqueMaterial.get
      k            = m.thermalConductivity
      d            = m.thickness
      if d < 0.003 || k > 3.0 || d / k < r
        i += 1
        next
      else
        r          = d / k
        index      = i
        type       = :standard
      end
    end

    i += 1
  end
  return index, type, r
end

##
# Thermally derate insulating material within construction.
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [String] id Surface identifier
# @param [Hash] surface A TBD surface
# @param [OpenStudio::Model::Construction] c An OS construction
#
# @return [OpenStudio::Model::Material] Returns derated (cloned) material
def derate(model, id, surface, c)
  m = nil
  cl1 = OpenStudio::Model::Model
  cl2 = OpenStudio::Model::Construction

  unless model && id && surface && c
    TBD.log(TBD::DEBUG,
      "Can't derate insulation, invalid arguments - skipping")
    return m
  end
  unless id.is_a?(String)
    TBD.log(TBD::DEBUG,
      "Can't derate insulation, #{id.class}? expected an ID String - skipping")
    return m
  end
  unless model.is_a?(cl1)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', #{model.class}? expected #{cl1} - skipping")
    return m
  end
  unless surface.is_a?(Hash)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', #{surface.class}? expected a Hash - skipping")
    return m
  end
  unless c.is_a?(cl2)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', #{c.class}? expected #{cl2} - skipping")
    return m
  end
  unless surface.has_key?(:heatloss)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', no calculated heatloss - skipping")
    return m
  end
  unless surface[:heatloss].is_a?(Numeric)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', non-numeric heatloss - skipping")
    return m
  end
  if surface[:heatloss].abs < TOL
    TBD.log(TBD::WARN,
      "Won't derate '#{id}', heatloss below #{TOL} - skipping")
    return m
  end
  unless surface.has_key?(:net)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', missing surface net area - skipping")
    return m
  end
  unless surface[:net].is_a?(Numeric)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', non-numeric surface net area - skipping")
    return m
  end
  if surface[:net] < TOL
    TBD.log(TBD::WARN,
      "Won't derate '#{id}', surface net area below #{TOL} - skipping")
    return m
  end
  unless surface.has_key?(:ltype)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', missing material type - skipping")
    return m
  end
  unless surface[:ltype] == :massless || surface[:ltype] == :standard
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', must be Standard or Massless - skipping")
    return m
  end
  unless surface.has_key?(:construction)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', missing parent construction - skipping")
    return m
  end
  unless surface.has_key?(:index)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', missing material index - skipping")
    return m
  end
  unless surface[:index]
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', invalid material index - skipping")
    return m
  end
  unless surface[:index].is_a?(Integer)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', non-integer material index - skipping")
    return m
  end
  if surface[:index] < 0
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', material index < 0 - skipping")
    return m
  end
  unless surface.has_key?(:r)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', invalid material RSi value - skipping")
    return m
  end
  unless surface[:r].is_a?(Numeric)
    TBD.log(TBD::DEBUG,
      "Can't derate '#{id}', non-numeric material RSi value - skipping")
    return m
  end
  if surface[:r] < 0.001
    TBD.log(TBD::WARN,
      "Won't derate '#{id}', material RSi value below MIN - skipping")
    return m
  end
  unless / tbd/i.match(c.nameString) == nil
    TBD.log(TBD::WARN,
      "Won't derate '#{id}', material already derated - skipping")
    return m
  end

  index          = surface[:index]
  ltype          = surface[:ltype]
  r              = surface[:r]
  u              = surface[:heatloss] / surface[:net]
  loss           = 0.0
  de_u           = 1.0 / r + u                                       # derated U
  de_r           = 1.0 / de_u                                        # derated R

  if ltype == :massless
    m            = c.getLayer(index).to_MasslessOpaqueMaterial

    unless m.empty?
      m          = m.get
      m          = m.clone(model)
      m          = m.to_MasslessOpaqueMaterial.get
                   m.setName("'#{id}' m tbd")

      unless de_r > 0.001
        de_r     = 0.001
        loss     = (de_u - 1.0 / de_r) * surface[:net]
      end
      m.setThermalResistance(de_r)
    end

  else                                                      # ltype == :standard
    m            = c.getLayer(index).to_StandardOpaqueMaterial
    unless m.empty?
      m          = m.get
      m          = m.clone(model)
      m          = m.to_StandardOpaqueMaterial.get
                   m.setName("'#{id}' m tbd")
      k          = m.thermalConductivity
      if de_r > 0.001
        d        = de_r * k
        unless d > 0.003
          d      = 0.003
          k      = d / de_r
          unless k < 3.0
            k    = 3.0

            loss = (de_u - k / d) * surface[:net]
          end
        end
      else                                                 # de_r < 0.001 m2.K/W
        d        = 0.001 * k
        unless d > 0.003
          d      = 0.003
          k      = d / 0.001
        end
        loss     = (de_u - k / d) * surface[:net]
      end

      m.setThickness(d)
      m.setThermalConductivity(k)
    end
  end

  if m && loss > TOL
    surface[:r_heatloss] = loss
    h_loss  = format "%.3f", surface[:r_heatloss]
    TBD.log(TBD::WARN,
      "Won't assign #{h_loss} W/K to '#{id}', too conductive - skipping")
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
# @param [String] ioP Path to a user-set TBD JSON input file (optional)
# @param [String] schemaP Path to a TBD JSON schema file (optional)
# @param [Bool] g_UA Have TBD generate UA' report (optional)
# @param [String] ref U & PSI reference (optional)
# @param [Bool] g_kiva Have TBD generate Kiva objects
#
# @return [Hash] Returns TBD collection of objects for JSON serialization
# @return [Hash] Returns collection of derated TBD surfaces
def processTBD(
  os_model,
  psi_set,
  ioP     = nil,
  schemaP = nil,
  g_UA    = false,
  ref     = "",
  g_kiva  = false)

  unless os_model
    TBD.log(TBD::DEBUG,
      "Can't process TBD, unable to find or open OSM (argument) - exiting")
    return nil, nil
  end
  cl = OpenStudio::Model::Model
  unless os_model.is_a?(cl)
    TBD.log(TBD::DEBUG,
      "Can't process TBD, #{os_model.class}? expected '#{cl}' - exiting")
    return nil, nil
  end
  unless g_UA == true || g_UA == false
    TBD.log(TBD::DEBUG,
      "Can't process TBD (UA), #{g_UA.class}? expected true or false - exiting")
    return nil, nil
  end
  unless g_kiva == true || g_kiva == false
    TBD.log(TBD::DEBUG,
      "Can't process TBD, #{g_kiva.class}? expected true or false - exiting")
    return nil, nil
  end

  os_building = os_model.getBuilding

  # Create the Topolys Model.
  t_model = Topolys::Model.new

  # "true" if any OSM space/zone holds setpoint temperatures. If OSM holds
  # invalid inputs, the function(s) will log DEBUG errors yet simply exit with
  # "false", ignoring any setpoint-based logic (e.g., semi-heated spaces).
  setpoints = heatingTemperatureSetpoints?(os_model)
  setpoints = coolingTemperatureSetpoints?(os_model) || setpoints

  # "true" if any OSM space/zone is part of an HVAC air loop. If OSM holds
  # invalid inputs, the function will simply return "false", and so TBD will
  # ignore any air-loop related logic (e.g., plenum zones as HVAC objects).
  airloops = airLoopsHVAC?(os_model)

  # Fetch OpenStudio (opaque) surfaces & key attributes.
  surfaces = {}
  os_model.getSurfaces.each do |s|
    id = s.nameString

    if s.space.empty?
      TBD.log(TBD::ERROR,
        "Processing TBD, can't find space holding surface '#{id}' - skipping")
      next
    end
    space = s.space.get

    ground   = s.isGroundSurface
    boundary = s.outsideBoundaryCondition
    if boundary.downcase == "surface"
      if s.adjacentSurface.empty?
        TBD.log(TBD::ERROR,
          "Processing TBD, can't find adjacent surface to '#{id}'  - skipping")
        next
      end
      adjacent = s.adjacentSurface.get.nameString
      if os_model.getSurfaceByName(adjacent).empty?
        TBD.log(TBD::ERROR,
          "Processing TBD, '#{id}' vs '#{adjacent}' mismatch - skipping")
        next
      end
      boundary = adjacent
    end

    # Similar to "setpoints?" functions above, the boolean functions below will
    # also return "false" when encountering invalid OSM inputs, ignoring any
    # space conditioning-based logic (e.g., semi-heated spaces, mislabelling a
    # plenum as an unconditioned zone).
    conditioned = true
    if setpoints
      if space.thermalZone.empty?
        conditioned = false unless plenum?(space, airloops, setpoints)
      else
        zone = space.thermalZone.get
        heating, _ = maxHeatScheduledSetpoint(zone)
        cooling, _ = minCoolScheduledSetpoint(zone)
        unless heating || cooling
          conditioned = false unless plenum?(space, airloops, setpoints)
        end
      end
    end

    # Site-specific (or absolute, or true) surface normal.
    t, r = transforms(os_model, space)
    unless t && r
      TBD.log(TBD::FATAL,
        "Can't process '#{id}' transformation")
      return nil, nil
    end
    n = trueNormal(s, r)
    unless n
      TBD.log(TBD::FATAL,
        "Can't process '#{id}' true normal")
      return nil, nil
    end

    type = :floor
    type = :ceiling if /ceiling/i.match(s.surfaceType)
    type = :wall    if /wall/i.match(s.surfaceType)

    points = (t * s.vertices).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }
    minz   = (points.map{ |p| p.z }).min

    # Content of the hash will evolve over the next few hundred lines.
    surfaces[id] = {
      type:         type,
      conditioned:  conditioned,
      ground:       ground,
      boundary:     boundary,
      space:        space,
      gross:        s.grossArea,
      points:       points,
      minz:         minz,
      n:            n
    }
    surfaces[id][:heating] = heating if heating     # if valid heating setpoints
    surfaces[id][:cooling] = cooling if cooling     # if valid cooling setpoints
    a = space.spaceType.empty?
    surfaces[id][:stype] = space.spaceType.get unless a
    a = space.buildingStory.empty?
    surfaces[id][:story] = space.buildingStory.get unless a

    unless s.construction.empty?
      construction = s.construction.get.to_Construction.get
      # index  - of layer/material (to derate) in construction
      # ltype  - either massless (RSi) or standard (k + d)
      # r      - initial RSi value of the indexed layer to derate
      index, ltype, r = deratableLayer(construction)
      index = nil unless index.is_a?(Numeric)
      index = nil unless index >= 0
      index = nil unless index < construction.layers.size
      if index
        surfaces[id][:construction] = construction
        surfaces[id][:index]        = index
        surfaces[id][:ltype]        = ltype
        surfaces[id][:r]            = r
      end
    end
  end                                              # (opaque) surfaces populated

  # TBD only derates constructions of opaque surfaces in CONDITIONED spaces, if
  # facing outdoors or facing UNCONDITIONED space.
  surfaces.each do |id, surface|
    surface[:deratable] = false
    next unless surface.has_key?(:conditioned)
    next unless surface[:conditioned]
    next if surface[:ground]

    b = surface[:boundary]
    if b.downcase == "outdoors"
      if surface.has_key?(:index)
        surface[:deratable] = true
      else
        TBD.log(TBD::ERROR,
          "Can't derate '#{id}', too conductive - skipping")
      end
    else
      next unless surfaces.has_key?(b)
      next unless surfaces[b].has_key?(:conditioned)
      next if surfaces[b][:conditioned]
      if surface.has_key?(:index)
        surface[:deratable] = true
      else
        TBD.log(TBD::ERROR,
          "Can't derate '#{id}', too conductive - skipping")
      end
    end
  end

  if surfaces.empty?
    TBD.log(TBD::ERROR,
      "Can't identify any surfaces to derate")
    return nil, nil
  end

  # Fetch OpenStudio subsurfaces & key attributes.
  os_model.getSubSurfaces.each do |s|
    id = s.nameString

    if s.space.empty?
      TBD.log(TBD::ERROR,
        "Can't process '#{id}', can't find its host space - skipping")
      next
    end
    space = s.space.get

    if s.surface.empty?
      TBD.log(TBD::ERROR,
        "Can't process '#{id}', can't find its parent surface - skipping")
      next
    end
    dad = s.surface.get.nameString

    # The function will throw 2 possible (non-fatal) errors:
    #   - number of subsurfaces vertices isn't 3 or 4 (EnergyPlus limitation)
    #   - subsurface gross area is below threshold TOL (not worth the effort)
    u, gross, pts = opening(os_model, id)
    next unless pts
    next if u < TOL
    next if gross < TOL

    # Site-specific (or absolute, or true) surface normal.
    t, r = transforms(os_model, space)
    unless t && r
      TBD.log(TBD::FATAL,
        "Can't process '#{id}' transformation")
      return nil, nil
    end

    n = trueNormal(s, r)
    unless n
      TBD.log(TBD::FATAL,
        "Can't process '#{id}' true normal")
      return nil, nil
    end

    points = (t * pts).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }
    minz = ( points.map { |p| p.z } ).min

    type = :skylight
    type = :window if /window/i.match(s.subSurfaceType)
    type = :door if /door/i.match(s.subSurfaceType)

    if type == :door
      glazed = true if /glass/i.match(s.subSurfaceType)
    end

    # For every kid, there's a dad somewhere ...
    surfaces.each do |identifier, properties|
      if identifier == dad
        sub = { points: points, minz: minz, n: n, gross: gross, u: u }
        sub[:glazed] = true if glazed
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
      p[:windows] = p[:windows].sort_by { |_, pp| pp[:minz] }.to_h
    end
    if p.has_key?(:doors)
      p[:doors] = p[:doors].sort_by { |_, pp| pp[:minz] }.to_h
    end
    if p.has_key?(:skylights)
      p[:skylights] = p[:skylights].sort_by { |_, pp| pp[:minz] }.to_h
    end
  end

  # Split "surfaces" hash into "floors", "ceilings" and "walls" hashes.
  floors = surfaces.select { |i, p| p[:type] == :floor }
  floors = floors.sort_by { |i, p| [p[:minz], p[:space]] }.to_h

  ceilings = surfaces.select { |i, p| p[:type] == :ceiling }
  ceilings = ceilings.sort_by { |i, p| [p[:minz], p[:space]] }.to_h

  walls = surfaces.select { |i, p| p[:type] == :wall }
  walls = walls.sort_by { |i, p| [p[:minz], p[:space]] }.to_h

  # Remove ":type" (now redundant).
  surfaces.values.each { |p| p.delete_if { |ii, _| ii == :type } }

  # Fetch OpenStudio shading surfaces & key attributes.
  shades = {}
  os_model.getShadingSurfaces.each do |s|
    id = s.nameString

    if s.shadingSurfaceGroup.empty?
      TBD.log(TBD::ERROR,
        "Can't process '#{id}' transformation")
      next
    end
    group = s.shadingSurfaceGroup.get

    # Site-specific (or absolute, or true) surface normal. Shading surface
    # groups may also be linked to (rotated) spaces.
    t, r = transforms(os_model, group)
    unless t && r
      TBD.log(TBD::FATAL,
        "Can't process '#{id}' transformation")
      return nil, nil
    end

    shading = group.to_ShadingSurfaceGroup
    unless shading.empty?
      unless shading.get.space.empty?
        r += shading.get.space.get.directionofRelativeNorth
      end
    end

    n = trueNormal(s, r)
    unless n
      TBD.log(TBD::FATAL,
        "Can't process '#{id}' true normal")
      return nil, nil
    end

    points = (t * s.vertices).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }
    minz = ( points.map { |p| p.z } ).min

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

  # Revise opaque surface net area (maybe subsurfaces with Frame & Divider).
  surfaces.values.each do |p|
    subarea = 0
    if p.has_key?(:windows)
      p[:windows].values.each { |o| subarea += o[:gross] }
    end
    if p.has_key?(:doors)
      p[:doors].values.each { |o| subarea += o[:gross] }
    end
    if p.has_key?(:skylights)
      p[:skylights].values.each { |o| subarea += o[:gross] }
    end
    p[:net] = p[:gross] - subarea
  end

  # Loop through Topolys edges and populate TBD edge hash. Initially, there
  # should be a one-to-one correspondence between Topolys and TBD edge
  # objects. Use Topolys-generated identifiers as unique edge hash keys.
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
  kiva = generateKiva(os_model, walls, floors, edges) if g_kiva

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
    origin     = edge[:v0].point
    terminal   = edge[:v1].point
    dx         = (origin.x - terminal.x).abs
    dy         = (origin.y - terminal.y).abs
    dz         = (origin.z - terminal.z).abs
    horizontal = dz.abs < TOL
    vertical   = dx < TOL && dy < TOL
    edge_V     = terminal - origin
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
          normal     = surfaces[id][:n]         if surfaces.has_key?(id)
          normal     = holes[id].attributes[:n] if holes.has_key?(id)
          normal     = shades[id][:n]           if shades.has_key?(id)
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
            point_on_plane = edge_plane.project(point)
            origin_point_V = point_on_plane - origin
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

            if point_V_magnitude > farthest_V.magnitude
              farthest = point
              farthest_V = origin_point_V
            end
          end

          angle = reference_V.angle(farthest_V)
          adjust = false                # adjust angle [180°, 360°] if necessary
          if vertical
            adjust = true if east.dot(farthest_V) < -TOL
          else
            if north.dot(farthest_V).abs < TOL            ||
              (north.dot(farthest_V).abs - 1).abs < TOL
                adjust = true if east.dot(farthest_V) < -TOL
            else
              adjust = true if north.dot(farthest_V) < -TOL
            end
          end
          angle = 2 * Math::PI - angle if adjust
          angle -= 2 * Math::PI if (angle - 2 * Math::PI).abs < TOL
          surface[:angle] = angle
          farthest_V.normalize!
          surface[:polar] = farthest_V
          surface[:normal] = normal
        end
      end                             # end of edge-linked, surface-to-wire loop
    end                                        # end of edge-linked surface loop

    edge[:horizontal] = horizontal
    edge[:vertical] = vertical
    edge[:surfaces] = edge[:surfaces].sort_by{ |i, p| p[:angle] }.to_h
  end                                                         # end of edge loop

  # Topolys edges may constitute thermal bridges (and therefore thermally
  # derate linked OpenStudio opaque surfaces), depending on a number of factors
  # such as surface type, space conditioning and boundary conditions. Thermal
  # bridging attributes (type & PSI-value pairs) are grouped into PSI sets,
  # normally accessed through the 'set' user-argument (in the OpenStudio
  # Measure interface).

  # Process user-defined TBD JSON file inputs if file exists & valid:
  #   "io" holds valid TBD JSON hash from file
  #   "io_p" holds TBD PSI sets (built-in defaults & those on file)
  #   "io_k" holds TBD KHI points (built-in defaults & those on file)
  io, io_p, io_k = processTBDinputs(surfaces, edges, psi_set, ioP, schemaP)

  # A user-defined TBD JSON input file can hold a number of anomalies that
  # won't affect results, such as a custom PSI set that isn't referenced
  # elsewhere (similar to an OpenStudio material on file that isn't referenced
  # by any OpenStudio construction). This may trigger 'warnings' in the log
  # file, but they're in principle benign.
  #
  # A user-defined JSON input file can instead hold a number of more serious
  # anomalies that risk generating erroneous or unintended results. They're
  # logged as well, yet it remains up to the user to decide how serious a risk
  # this may be. If a custom edge is defined on file (e.g., an "expansion joint"
  # thermal bridge instead of a "mild transition") yet TBD is unable to match
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
  return nil, nil if TBD.fatal?

  p = io[:building][:psi]                                 # default building PSI
  has, val = io_p.shorthands(p)

  if has.empty? || val.empty?
    TBD.log(TBD::FATAL,
      "Can't process an invalid or incomplete building PSI set")
    return nil, nil
  end

  edges.values.each do |edge|
    next unless edge.has_key?(:surfaces)
    deratables = []
    edge[:surfaces].each do |id, surface|
      next unless surfaces.has_key?(id)
      next unless surfaces[id].has_key?(:deratable)
      deratables << id if surfaces[id][:deratable]
    end
    next if deratables.empty?
    psi = {}

    if edge.has_key?(:io_type)
      tt = io_p.safeType(p, edge[:io_type])
      edge[:sets] = {} unless edge.has_key?(:sets)
      edge[:sets][edge[:io_type]] = val[tt]       # default to :building PSI set
      psi[edge[:io_type]] = val[tt]
      edge[:psi] = psi
      if edge.has_key?(:io_set) && io_p.set.has_key?(edge[:io_set])
        ttt = io_p.safeType(edge[:io_set], edge[:io_type])
        edge[:set] = edge[:io_set] if ttt
      end
      match = true
    end

    edge[:surfaces].keys.each do |id|
      next if match
      next unless surfaces.has_key?(id)
      next unless deratables.include?(id)

      # Evaluate PSI content before processing a new linked surface.
      is = {}
      is[:head]     = psi.keys.to_s.include?("head")
      is[:sill]     = psi.keys.to_s.include?("sill")
      is[:jamb]     = psi.keys.to_s.include?("jamb")
      is[:corner]   = psi.keys.to_s.include?("corner")
      is[:parapet]  = psi.keys.to_s.include?("parapet")
      is[:party]    = psi.keys.to_s.include?("party")
      is[:grade]    = psi.keys.to_s.include?("grade")
      is[:balcony]  = psi.keys.to_s.include?("balcony")
      is[:rimjoist] = psi.keys.to_s.include?("rimjoist")

      # Label edge as :head, :sill or :jamb if linked to:
      #   1x subsurface
      unless is[:head] || is[:sill] || is[:jamb]
        edge[:surfaces].keys.each do |i|
          next if is[:head] || is[:sill] || is[:jamb]
          next if i == id
          next if deratables.include?(i)
          next unless holes.has_key?(i)

          ii = ""
          ii = id if deratables.size == 1                           # just dad
          if ii.empty?                                            # seek uncle
            jj = deratables.first unless deratables.first == id
            jj = deratables.last  unless deratables.last  == id
            id_has = {}
            id_has[:windows]   = true if surfaces[id].has_key?(:windows)
            id_has[:doors]     = true if surfaces[id].has_key?(:doors)
            id_has[:skylights] = true if surfaces[id].has_key?(:skylights)
            ido = []
            ido = ido + surfaces[id][:windows].keys   if id_has[:windows]
            ido = ido + surfaces[id][:doors].keys     if id_has[:doors]
            ido = ido + surfaces[id][:skylights].keys if id_has[:skylights]
            jj_has = {}
            jj_has[:windows]   = true if surfaces[jj].has_key?(:windows)
            jj_has[:doors]     = true if surfaces[jj].has_key?(:doors)
            jj_has[:skylights] = true if surfaces[jj].has_key?(:skylights)
            jjo = []
            jjo = jjo + surfaces[jj][:windows].keys   if jj_has[:windows]
            jjo = jjo + surfaces[jj][:doors].keys     if jj_has[:doors]
            jjo = jjo + surfaces[jj][:skylights].keys if jj_has[:skylights]
            ii = jj if ido.include?(i)
            ii = id if jjo.include?(i)
          end
          next if ii.empty?

          s1      = edge[:surfaces][ii]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          # Subsurface edges are tagged as :head, :sill or :jamb, regardless of
          # building PSI set subsurface tags. If the latter is simply
          # :fenestration, then its (single) PSI value is systematically
          # attributed to subsurface :head, :sill & :jamb edges. If absent,
          # concave or convex variants also inherit from base type.
          #
          # TBD tags a subsurface edge as :jamb if the subsurface is "flat". If
          # not flat, TBD tags a horizontal edge as either :head or :sill based
          # on the polar angle of the subsurface around the edge vs sky zenith.
          # Otherwise, all other subsurface edges are tagged as :jamb.

          if ((s2[:normal].dot(zenith)).abs - 1).abs < TOL
            psi[:jamb]        = val[:jamb]        if flat
            psi[:jambconcave] = val[:jambconcave] if concave
            psi[:jambconvex]  = val[:jambconvex]  if convex
             is[:jamb]        = true
          else
            if edge[:horizontal]
              if s2[:polar].dot(zenith) < 0
                psi[:head]        = val[:head]        if flat
                psi[:headconcave] = val[:headconcave] if concave
                psi[:headconvex]  = val[:headconvex]  if convex
                 is[:head]        = true
              else
                psi[:sill]        = val[:sill]        if flat
                psi[:sillconcave] = val[:sillconcave] if concave
                psi[:sillconvex]  = val[:sillconvex]  if convex
                 is[:sill]        = true
              end
            else
              psi[:jamb]        = val[:jamb]        if flat
              psi[:jambconcave] = val[:jambconcave] if concave
              psi[:jambconvex]  = val[:jambconvex]  if convex
               is[:jamb]        = true
            end
          end
        end
      end

      # Label edge as :cornerconcave or :cornerconvex if linked to:
      #   2x deratable walls & f(relative polar wall vectors around edge)
      unless is[:corner]
        edge[:surfaces].keys.each do |i|
          next if is[:corner]
          next if i == id
          next unless deratables.size == 2
          next unless deratables.include?(i)
          next unless walls.has_key?(id)
          next unless walls.has_key?(i)

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          psi[:cornerconcave] = val[:cornerconcave] if concave
          psi[:cornerconvex]  = val[:cornerconvex]  if convex
           is[:corner]        = true
        end
      end

      # Label edge as :parapet if linked to:
      #   1x deratable wall
      #   1x deratable ceiling
      unless is[:parapet]
        edge[:surfaces].keys.each do |i|
          next if is[:parapet]
          next if i == id
          next unless deratables.size == 2
          next unless deratables.include?(i)
          next unless ceilings.has_key?(id)
          next unless walls.has_key?(i)

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          psi[:parapet]        = val[:parapet]        if flat
          psi[:parapetconcave] = val[:parapetconcave] if concave
          psi[:parapetconvex]  = val[:parapetconvex]  if convex
           is[:parapet]        = true
        end
      end

      # Label edge as :party if linked to:
      #   1x adiabatic surface
      #   1x (only) deratable surface
      unless is[:party]
        edge[:surfaces].keys.each do |i|
          next if is[:party]
          next if i == id
          next unless deratables.size == 1
          next unless surfaces.has_key?(i)
          next if holes.has_key?(i)
          next if shades.has_key?(i)
          next unless surfaces[i][:boundary].downcase == "adiabatic"

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          psi[:party]        = val[:party]        if flat
          psi[:partyconcave] = val[:partyconcave] if concave
          psi[:partyconvex]  = val[:partyconvex]  if convex
           is[:party]        = true
        end
      end

      # Label edge as :grade if linked to:
      #   1x surface (e.g. slab or wall) facing ground
      #   1x surface (i.e. wall) facing outdoors
      unless is[:grade]
        edge[:surfaces].keys.each do |i|
          next if is[:grade]
          next if i == id
          next unless deratables.size == 1
          next unless surfaces.has_key?(i)
          next unless surfaces[i].has_key?(:ground)
          next unless surfaces[i][:ground]

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          psi[:grade]        = val[:grade]        if flat
          psi[:gradeconcave] = val[:gradeconcave] if concave
          psi[:gradeconvex]  = val[:gradeconvex]  if convex
           is[:grade]        = true
        end
      end

      # Label edge as :rimjoist (or :balcony) if linked to:
      #   1x deratable surface
      #   1x CONDITIONED floor
      #   1x shade (optional)
      unless is[:rimjoist] || is[:balcony]
        balcony = false
        edge[:surfaces].keys.each do |i|
          next if i == id
          balcony = true if shades.has_key?(i)
        end
        edge[:surfaces].keys.each do |i|
          next if is[:rimjoist] || is[:balcony]
          next if i == id
          next unless deratables.size == 2
          next if floors.has_key?(id)
          next unless floors.has_key?(i)
          next unless floors[i].has_key?(:conditioned)
          next unless floors[i][:conditioned]
          next if floors[i][:ground]

          ii = ""
          ii = i if deratables.include?(i)                     # exposed floor
          if ii.empty?
            deratables.each { |j| ii = j unless j == id }
          end
          next if ii.empty?

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][ii]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          if balcony
            psi[:balcony]        = val[:balcony]        if flat
            psi[:balconyconcave] = val[:balconyconcave] if concave
            psi[:balconyconvex]  = val[:balconyconvex]  if convex
             is[:balcony]        = true
          else
            psi[:rimjoist]        = val[:rimjoist]        if flat
            psi[:rimjoistconcave] = val[:rimjoistconcave] if concave
            psi[:rimjoistconvex]  = val[:rimjoistconvex]  if convex
             is[:rimjoist]        = true
          end
        end
      end
    end                                                    # edge's surfaces loop

    edge[:psi] = psi unless psi.empty?
    edge[:set] = p unless psi.empty?
  end                                                                # edge loop

  # Tracking (mild) transitions between deratable surfaces around edges that
  # have not been previously tagged.
  edges.values.each do |edge|
    next if edge.has_key?(:psi)
    next unless edge.has_key?(:surfaces)
    deratable = false
    edge[:surfaces].each do |id, surface|
      next if deratable
      next unless surfaces.has_key?(id)
      next unless surfaces[id].has_key?(:deratable)
      deratable = true if surfaces[id][:deratable]
    end
    next unless deratable
    count = 0
    edge[:surfaces].keys.each do |id|
      next unless surfaces.has_key?(id)
      next unless surfaces[id].has_key?(:deratable)
      next unless surfaces[id][:deratable]
      count += 1
    end
    next unless count > 0
    psi = {}
    psi[:transition] = 0.000
    edge[:psi] = psi
    edge[:set] = io[:building][:psi]
  end

  # A priori, TBD applies (default) :building PSI types and values to individual
  # edges. If a TBD JSON input file holds custom:
  #   :stories
  #   :spacetypes
  #   :surfaces
  #   :edges
  # ... PSI sets that may apply to individual edges, then the default :building
  # PSI types and/or values are overridden, as follows:
  #   custom :stories    PSI sets trump :building PSI sets
  #   custom :spacetypes PSI sets trump the aforementioned PSI sets
  #   custom :spaces     PSI sets trump the aforementioned PSI sets
  #   custom :surfaces   PSI sets trump the aforementioned PSI sets
  #   custom :edges      PSI sets trump the aforementioned PSI sets
  if io
    # First, reset subsurface U-factors (if set on file).
    if io.has_key?(:subsurfaces)
      io[:subsurfaces].each do |sub|
        next unless sub.has_key?(:id)
        next unless sub.has_key?(:usi)
        i = sub[:id]
        match = false
        surfaces.values.each do |surface|
          next if match
          if surface.has_key?(:windows)
            surface[:windows].each do |ii, window|
              next unless window.has_key?(:u)
              next if match
              if i == ii
                match = true
                window[:u] = sub[:usi]
              end
            end
          end
          if surface.has_key?(:doors)
            surface[:doors].each do |ii, door|
              next unless door.has_key?(:u)
              next if match
              if i == ii
                match = true
                door[:u] = sub[:usi]
              end
            end
          end
          if surface.has_key?(:skylights)
            surface[:skylights].each do |ii, skylight|
              next unless skylight.has_key?(:u)
              next if match
              if i == ii
                match = true
                skylight[:u] = sub[:usi]
              end
            end
          end
        end
      end
    end

    if io.has_key?(:stories)
      io[:stories].each do |story|
        next unless story.has_key?(:id)
        next unless story.has_key?(:psi)
        i = story[:id]
        p = story[:psi]
        next unless io_p.set.has_key?(p)
        holds, values = io_p.shorthands(p)
        next if holds.empty?
        next if values.empty?

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)
          next if edge.has_key?(:io_set)
          next unless edge.has_key?(:surfaces)
          edge[:surfaces].keys.each do |id|
            next unless surfaces.has_key?(id)
            next unless surfaces[id].has_key?(:story)
            st = surfaces[id][:story]
            next unless i == st.nameString
            edge[:stories] = {} unless edge.has_key?(:stories)
            edge[:stories][p] = {}
            psi = {}
            if edge.has_key?(:io_type)
              tt = io_p.safeType(p, edge[:io_type])
              psi[edge[:io_type]] = values[tt] if tt
            else
              edge[:psi].keys.each do |t|
                tt = io_p.safeType(p, t)
                psi[t] = values[tt] if tt
              end
            end
            edge[:stories][p] = psi unless psi.empty?
          end
        end
      end

      # TBD/Topolys edges will generally be linked to more than one surface and
      # hence to more than one story. It is possible for a TBD JSON file to hold
      # 2x story PSI sets that end up targetting one or more edges common to
      # both stories. In such cases, TBD retains the most conductive PSI
      # type/value from both story PSI sets.
      edges.values.each do |edge|
        next unless edge.has_key?(:psi)
        next unless edge.has_key?(:stories)
        edge[:psi].keys.each do |t|
          vals = {}
          edge[:stories].each do |p, psi|
            holds, values = io_p.shorthands(p)
            next if holds.empty?
            next if values.empty?
            tt = io_p.safeType(p, t)
            vals[p] = values[tt] if tt
          end
          next if vals.empty?
          edge[:psi][t] = vals.values.max
          edge[:sets] = {} unless edge.has_key?(:sets)
          edge[:sets][t] = vals.key(vals.values.max)
        end
      end
    end

    if io.has_key?(:spacetypes)
      io[:spacetypes].each do |stype|
        next unless stype.has_key?(:id)
        next unless stype.has_key?(:psi)
        i = stype[:id]
        p = stype[:psi]
        next unless io_p.set.has_key?(p)
        holds, values = io_p.shorthands(p)
        next if holds.empty?
        next if values.empty?

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)
          next if edge.has_key?(:io_set)
          next unless edge.has_key?(:surfaces)
          edge[:surfaces].keys.each do |id|
            next unless surfaces.has_key?(id)
            next unless surfaces[id].has_key?(:stype)
            st = surfaces[id][:stype]
            next unless i == st.nameString
            edge[:spacetypes] = {} unless edge.has_key?(:spacetypes)
            edge[:spacetypes][p] = {}
            psi = {}
            if edge.has_key?(:io_type)
              tt = io_p.safeType(p, edge[:io_type])
              psi[edge[:io_type]] = values[tt] if tt
            else
              edge[:psi].keys.each do |t|
                tt = io_p.safeType(p, t)
                psi[t] = values[tt] if tt
              end
            end
            edge[:spacetypes][p] = psi unless psi.empty?
          end
        end
      end

      # TBD/Topolys edges will generally be linked to more than one surface and
      # hence to more than one spacetype. It is possible for a TBD JSON file to
      # hold 2x spacetype PSI sets that end up targetting one or more edges
      # common to both spacetypes. In such cases, TBD retains the most
      # conductive PSI type/value from both spacetype PSI sets.
      edges.values.each do |edge|
        next unless edge.has_key?(:psi)
        next unless edge.has_key?(:spacetypes)
        edge[:psi].keys.each do |t|
          vals = {}
          edge[:spacetypes].each do |p, psi|
            holds, values = io_p.shorthands(p)
            next if holds.empty?
            next if values.empty?
            tt = io_p.safeType(p, t)
            vals[p] = values[tt] if tt
          end
          next if vals.empty?
          edge[:psi][t] = vals.values.max
          edge[:sets] = {} unless edge.has_key?(:sets)
          edge[:sets][t] = vals.key(vals.values.max)
        end
      end
    end

    if io.has_key?(:spaces)
      io[:spaces].each do |space|
        next unless space.has_key?(:id)
        next unless space.has_key?(:psi)
        i = space[:id]
        p = space[:psi]
        next unless io_p.set.has_key?(p)
        holds, values = io_p.shorthands(p)
        next if holds.empty?
        next if values.empty?

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)
          next if edge.has_key?(:io_set)
          next unless edge.has_key?(:surfaces)
          edge[:surfaces].keys.each do |id|
            next unless surfaces.has_key?(id)
            next unless surfaces[id].has_key?(:space)
            sp = surfaces[id][:space]
            next unless i == sp.nameString
            edge[:spaces] = {} unless edge.has_key?(:spaces)
            edge[:spaces][p] = {}
            psi = {}
            if edge.has_key?(:io_type)
              tt = io_p.safeType(p, edge[:io_type])
              psi[edge[:io_type]] = values[tt] if tt
            else
              edge[:psi].keys.each do |t|
                tt = io_p.safeType(p, t)
                psi[t] = values[tt] if tt
              end
            end
            edge[:spaces][p] = psi unless psi.empty?
          end
        end
      end

      # TBD/Topolys edges will generally be linked to more than one surface and
      # hence to more than one space. It is possible for a TBD JSON file to hold
      # 2x space PSI sets that end up targetting one or more edges common to
      # both spaces. In such cases, TBD retains the most conductive PSI
      # type/value from both space PSI sets.
      edges.values.each do |edge|
        next unless edge.has_key?(:psi)
        next unless edge.has_key?(:spaces)
        edge[:psi].keys.each do |t|
          vals = {}
          edge[:spaces].each do |p, psi|
            holds, values = io_p.shorthands(p)
            next if holds.empty?
            next if values.empty?
            tt = io_p.safeType(p, t)
            vals[p] = values[tt] if tt
          end
          next if vals.empty?
          edge[:psi][t] = vals.values.max
          edge[:sets] = {} unless edge.has_key?(:sets)
          edge[:sets][t] = vals.key(vals.values.max)
        end
      end
    end

    if io.has_key?(:surfaces)
      io[:surfaces].each do |surface|
        next unless surface.has_key?(:id)
        next unless surface.has_key?(:psi)
        i = surface[:id]
        p = surface[:psi]
        next unless io_p.set.has_key?(p)
        holds, values = io_p.shorthands(p)
        next if holds.empty?
        next if values.empty?

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)
          next if edge.has_key?(:io_set)
          next unless edge.has_key?(:surfaces)
          edge[:surfaces].each do |id, s|
            next unless surfaces.has_key?(id)
            next unless i == id
            psi = {}
            if edge.has_key?(:io_type)
              tt = io_p.safeType(p, edge[:io_type])
              psi[:io_type] = values[tt] if tt
            else
              edge[:psi].keys.each do |t|
                tt = io_p.safeType(p, t)
                psi[t] = values[tt] if tt
              end
            end
            s[:psi] = psi unless psi.empty?
            s[:set] = p unless psi.empty?
          end
        end
      end

      # TBD/Topolys edges will generally be linked to more than one surface. It
      # is possible for a TBD JSON file to hold 2x surface PSI sets that end up
      # targetting one or more edges shared by both surfaces. In such cases, TBD
      # retains the most conductive PSI type/value from both surface PSI sets.
      edges.values.each do |edge|
        next unless edge.has_key?(:psi)
        next unless edge.has_key?(:surfaces)
        edge[:psi].keys.each do |t|
          vals = {}
          edge[:surfaces].each do |id, s|
            next unless s.has_key?(:psi)
            next unless s.has_key?(:set)
            next if s[:set].empty?
            holds, values = io_p.shorthands(s[:set])
            next if holds.empty?
            next if values.empty?
            tt = io_p.safeType(s[:set], t)
            vals[s[:set]] = values[tt] if tt
          end
          next if vals.empty?
          edge[:psi][t] = vals.values.max
          edge[:sets] = {} unless edge.has_key?(:sets)
          edge[:sets][t] = vals.key(vals.values.max)
        end
      end
    end

    # Loop through all customized edges on file w/w/o a custom PSI set
    edges.values.each do |edge|
      next unless edge.has_key?(:psi)
      next unless edge.has_key?(:io_type)
      next unless edge.has_key?(:surfaces)
      if edge.has_key?(:io_set)
        next unless io_p.set.has_key?(edge[:io_set])
        set = edge[:io_set]
      else
        next unless edge[:sets].has_key?(edge[:io_type])
        next unless io_p.set.has_key?(edge[:sets][edge[:io_type]])
        set = edge[:sets][edge[:io_type]]
      end
      holds, values = io_p.shorthands(set)
      next if holds.empty?
      next if values.empty?
      tt = io_p.safeType(set, edge[:io_type])
      next unless tt
      if edge.has_key?(:io_set)
        edge[:psi] = {}
        edge[:set] = edge[:io_set]
      else
        edge[:sets] = {} unless edge.has_key?(:sets)
        edge[:sets][edge[:io_type]] = values[tt]
      end
      edge[:psi][edge[:io_type]] = values[tt]
    end
  end

  # Loop through each edge and assign heat loss to linked surfaces.
  edges.each do |identifier, edge|
    next unless edge.has_key?(:psi)
    psi = edge[:psi].values.max
    type = edge[:psi].key(psi)
    bridge = { psi: psi, type: type, length: edge[:length] }

    if edge.has_key?(:sets) && edge[:sets].has_key?(type)
      edge[:set] = edge[:sets][type] unless edge.has_key?(:io_set)
    end

    # Retrieve valid linked surfaces as deratables.
    deratables = {}
    edge[:surfaces].each do |id, surface|
      next unless surfaces.has_key?(id)
      next unless surfaces[id][:deratable]
      deratables[id] = surface
    end

    openings = {}
    edge[:surfaces].each do |id, surface|
      next unless holes.has_key?(id)
      openings[id] = surface
    end
    next if openings.size > 1                           # edge links 2x openings

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
    next if deratables.empty?

    # Sum RSI of targeted insulating layer from each deratable surface.
    rsi = 0
    deratables.each do |id, deratable|
      next unless surfaces[id].has_key?(:r)
      rsi += surfaces[id][:r]
    end

    # Assign heat loss from thermal bridges to surfaces, in proportion to
    # insulating layer thermal resistance
    deratables.each do |id, deratable|
      surfaces[id][:edges] = {} unless surfaces[id].has_key?(:edges)
      loss = 0
      loss = bridge[:psi] * surfaces[id][:r] / rsi if rsi > 0.001
      b = { psi: loss, type: bridge[:type], length: bridge[:length] }
      surfaces[id][:edges][identifier] = b
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
    next unless surface.has_key?(:deratable)
    next unless surface[:deratable]
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
        next unless io_k.point[k[:id]] > 0.001
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
    next unless surface.has_key?(:construction)
    next unless surface.has_key?(:index)
    next unless surface.has_key?(:ltype)
    next unless surface.has_key?(:r)
    next unless surface.has_key?(:edges)
    next unless surface.has_key?(:heatloss)
    next unless surface[:heatloss].abs > TOL

    os_model.getSurfaces.each do |s|
      next unless id == s.nameString
      index = surface[:index]
      current_c = surface[:construction]
      c = current_c.clone(os_model).to_Construction.get

      m = nil
      m = derate(os_model, id, surface, c) if index
      # m may be nilled simply because the targeted construction has already
      # been derated, i.e. holds " tbd" in its name. Names of cloned/derated
      # constructions (due to TBD) include the surface name (since derated
      # constructions are now unique to each surface) and the suffix " c tbd".
      if m
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
        # If one comments out the following loop (3 lines), tested surfaces
        # with air layers will generate discrepencies between the calculed RSi
        # value above and the inverse of the uFactor. All other surface
        # constructions pass the test.
        #
        # if ((1/current_R) - s.uFactor.to_f).abs > 0.005
        #   puts "#{s.nameString} - Usi:#{1/current_R} UFactor: #{s.uFactor}"
        # end
        s.setConstruction(c)

        # If derated surface construction separates CONDITIONED space from
        # UNCONDITIONED or UNENCLOSED space, then derate adjacent surface
        # construction as well (unless defaulted).
        if s.outsideBoundaryCondition.downcase == "surface"
          unless s.adjacentSurface.empty?
            adjacent = s.adjacentSurface.get
            i = adjacent.nameString
            if surfaces.has_key?(i) && adjacent.isConstructionDefaulted == false
              indx = surfaces[i][:index]
              current_cc = surfaces[i][:construction]
              cc = current_cc.clone(os_model).to_Construction.get

              cc.setLayer(indx, m)
              cc.setName("#{i} c tbd")
              adjacent.setConstruction(cc)
            end
          end
        end

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
        surface[:ratio] = ratio if ratio.abs > TOL

        # Storing underated USi value, as well as reference USi (if applicable)
        surface[:u] = 1/current_R
      end
    end
  end

  # Process edges & surfaces (& subsurfaces) to compute UA' summations.

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
