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

    # The following are default PSI values (* published, ** calculated). Users
    # may edit these sets, add new sets here, or read-in custom sets from a TBD
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

    @set[ "poor (BETBG)" ] =
    {
      rimjoist:     1.000, # *
      parapet:      0.800, # *
      fenestration: 0.500, # *
      concave:      0.850, # *
      convex:       0.850, # *
      balcony:      1.000, # *
      party:        0.850, # *
      grade:        0.850, # *
      joint:        0.300, # *
      transition:   0.000
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
      grade:        0.450, # *
      joint:        0.200, # *
      transition:   0.000
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
      grade:        0.200, # *
      joint:        0.100, # *
      transition:   0.000
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
      grade:        0.450, # *
      joint:        0.200, # ** "regular (BETBG)"
      transition:   0.000
    }.freeze               # based on EXTERIOR dimensions (art. 3.1.1.6)

    @set[ "(non thermal bridging)" ] = # ... would not derate surfaces:
    {
      rimjoist:     0.000,
      parapet:      0.000,
      fenestration: 0.000,
      concave:      0.000,
      convex:       0.000,
      balcony:      0.000,
      party:        0.000,
      grade:        0.000,
      joint:        0.000,
      transition:   0.000
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
        @set[id][:head]         = p[:head]         if p.has_key?(:head)
        @set[id][:sill]         = p[:sill]         if p.has_key?(:sill)
        @set[id][:jamb]         = p[:jamb]         if p.has_key?(:jamb)
        @set[id][:concave]      = p[:concave]      if p.has_key?(:concave)
        @set[id][:convex]       = p[:convex]       if p.has_key?(:convex)
        @set[id][:balcony]      = p[:balcony]      if p.has_key?(:balcony)
        @set[id][:party]        = p[:party]        if p.has_key?(:party)
        @set[id][:grade]        = p[:grade]        if p.has_key?(:grade)
        @set[id][:joint]        = p[:joint]        if p.has_key?(:joint)
        @set[id][:transition]   = p[:transition]   if p.has_key?(:transition)

        @set[id][:joint]        = 0.000 unless p.has_key?(:joint)
        @set[id][:transition]   = 0.000 unless p.has_key?(:transition)
      end
    end
    # should log if else message
  end

  ##
  # Validate whether a stored PSI set has a complete list of PSI type:values
  #
  # @param [String] s A PSI set identifier
  #
  # @return [Bool] Returns true if stored and has a complete PSI set
  def complete?(s)
    answer    = @set.has_key?(s)

    partial   = answer && @set[s].has_key?(:fenestration)
    complete  = answer &&
                @set[s].has_key?(:head) &&
                @set[s].has_key?(:sill) &&
                @set[s].has_key?(:jamb)

    answer    = answer && (partial || complete)
    answer    = answer && @set[s].has_key?(:rimjoist)
    answer    = answer && @set[s].has_key?(:parapet)
    answer    = answer && @set[s].has_key?(:concave)
    answer    = answer && @set[s].has_key?(:convex)
    answer    = answer && @set[s].has_key?(:balcony)
    answer    = answer && @set[s].has_key?(:party)
    answer    = answer && @set[s].has_key?(:grade)
    answer
  end
end

##
# Check for matching vertex pairs between edges (10mm tolerance).
# @param [Hash] e1 First edge
# @param [Hash] e2 Second edge
#
# @return [Bool] Returns true if edges share vertex pairs
def matches?(e1, e2)
  raise "Invalid edges (matches?)" unless e1 && e2
  raise "Missing :v0 for e1" unless e1.has_key?(:v0)
  raise "Missing :v1 for e1" unless e1.has_key?(:v1)
  raise "Missing :v0 for e2" unless e2.has_key?(:v0)
  raise "Missing :v1 for e2" unless e2.has_key?(:v1)
  cl = Topolys::Point3D
  raise "e1 v0: #{e1[:v0].class}? expected #{cl}" unless e1[:v0].is_a?(cl)
  raise "e1 v1: #{e1[:v1].class}? expected #{cl}" unless e1[:v1].is_a?(cl)
  raise "e2 v0: #{e1[:v0].class}? expected #{cl}" unless e2[:v0].is_a?(cl)
  raise "e2 v1: #{e1[:v1].class}? expected #{cl}" unless e2[:v1].is_a?(cl)

  answer = false
  e1_vector = e1[:v1] - e1[:v0]
  e2_vector = e2[:v1] - e2[:v0]
  raise "e1 length <= 10mm" if e1_vector.magnitude < TOL
  raise "e2 length <= 10mm" if e2_vector.magnitude < TOL

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
# :io_building = project-wide PSI set, if absent from TBD JSON file
#
# @param [Hash] surfaces Preprocessed collection of TBD surfaces
# @param [Hash] edges Preprocessed collection TBD edges
# @param [String] set Default) PSI set identifier, can be "" (empty)
# @param [String] ioP Path to a user-set TBD JSON input file (optional)
# @param [String] schemaP Path to a TBD JSON schema file (optional)
#
# @return [Hash] Returns a JSON-generated collection of user inputs
# @return [Hash] Returns a new PSI library, enriched with optional sets on file
# @return [Hash] Returns a new KHI library, enriched with optional pairs on file
def processTBDinputs(surfaces, edges, set, ioP = nil, schemaP = nil)
  # In the near future, the bulk of the "raises" in processTBDinputs will
  # be logged as mild or severe warnings, possibly halting all TBD processes
  # The OpenStudio/EnergyPlus model would remain unaltered (or un-derated).

  # JSON validation relies on case-senitive string comparisons (e.g. OpenStudio
  # space or surface names, vs corresponding TBD JSON identifiers). So "Space-1"
  # would not match "SPACE-1". A head's up ...
  tt = :fenestration
  io = {}
  psi = PSI.new                  # PSI hash, initially holding built-in defaults
  khi = KHI.new                  # KHI hash, initially holding built-in defaults

  raise "Invalid surfaces (TBD inputs)" unless surfaces
  raise "Invalid edges (TBD inputs)" unless edges
  cl = surfaces.class
  raise "#{cl}? expected surfaces Hash (TBD inputs)" unless cl == Hash
  cl = edges.class
  raise "#{cl}? expected edges Hash (TBD inputs)" unless cl == Hash

  if ioP && File.size?(ioP) # optional input file exists and is non-zero
    ioC = File.read(ioP)
    io = JSON.parse(ioC, symbolize_names: true)

    # Schema validation is not yet supported in the OpenStudio Application.
    if schemaP
      require "json-schema"

      raise "Invalid TBD schema file" unless File.exist?(schemaP)
      raise "Empty TBD schema file" if File.zero?(schemaP)
      schemaC = File.read(schemaP)
      schema = JSON.parse(schemaC, symbolize_names: true)

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

    if io.has_key?(:building)
      raise "Building PSI?" unless io[:building].first.has_key?(:psi)
    else
      # No building PSI - "set" must default to a built-in PSI set.
      io[:building] = [{ psi: set }]           # i.e. default PSI set & no KHI's
    end

    p = io[:building].first[:psi]
    raise "Incomplete PSI set #{p}" unless psi.complete?(p)

    if io.has_key?(:stories)
      io[:stories].each do |story|
        next unless story.has_key?(:id)
        next unless story.has_key?(:psi)
        i = story[:id]
        p = story[:psi]

        # Validate if story "id" is found in stories hash
        match = false
        surfaces.values.each do |properties|
          next if match
          next unless properties.has_key?(:story)
          st = properties[:story]
          match = true if i = st.nameString
        end
        raise "Mismatch OpenStudio #{i}" unless match
        raise "#{i} PSI mismatch" unless psi.set.has_key?(p)
      end
    end

    if io.has_key?(:spacetypes)
      io[:spacetypes].each do |stype|
        next unless stype.has_key?(:id)
        next unless stype.has_key?(:psi)
        i = stype[:id]
        p = stype[:psi]

        # Validate if spacetype "id" is found in spacetypes hash
        match = false
        surfaces.values.each do |properties|
          next if match
          next unless properties.has_key?(:stype)
          spt = properties[:stype]
          match = true if i = spt.nameString
        end
        raise "Mismatch OpenStudio #{i}" unless match
        raise "#{i} PSI mismatch" unless psi.set.has_key?(p)
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
                raise "Edge vertices must come in pairs"           # all or none
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
              match = matches?(e1, e2)
            end

            next unless match
            e[:io_type] = t
            n += 1
            if edge.has_key?(:psi)                                    # optional
              p = edge[:psi]
              raise "PSI mismatch (TBD inputs)" unless psi.set.has_key?(p)
              unless psi.set[p].has_key?(t)
                if t == :head || t == :sill || t == :jamb
                  raise "#{p} missing PSI #{t}" unless psi.set[p].has_key?(tt)
                else
                  raise "#{p} missing PSI #{t}" unless psi.set[p].has_key?(t)
                end
              end
              e[:io_set] = p
            end
          end
        end
        raise "Edge: missing OpenStudio match" if n == 0
      end
    end
  else
    # No (optional) user-defined TBD JSON input file.
    # In such cases, "set" must refer to a valid PSI set
    raise "Incomplete PSI set #{set}" unless psi.complete?(set)
    io[:building] = [{ psi: set }]             # i.e. default PSI set & no KHI's
  end
  return io, psi, khi
end

##
# Return min & max values for schedule (ruleset).
#
# @param [OpenStudio::Model::ScheduleRuleset] sched An OS schedule (ruleset)
#
# @return [Hash] :min & :max; nilled if invalid.
def scheduleRulesetMinMax(sched)
  # Largely inspired from David Goldwasser's
  # "schedule_ruleset_annual_min_max_value":
  #
  # github.com/NREL/openstudio-standards/blob/
  # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
  # standards/Standards.ScheduleRuleset.rb#L124
  result = { min: nil, max: nil }
  raise "Invalid sched (ruleset MinMax)" unless sched
  cl = OpenStudio::Model::ScheduleRuleset
  raise "#{sched.class}? expected #{cl} (ruleset)" unless sched.is_a?(cl)

  profiles = []
  profiles << sched.defaultDaySchedule
  rules = sched.scheduleRules
  rules.each do |rule|
    profiles << rule.daySchedule
  end

  min = nil
  max = nil
  profiles.each do |profile|
    profile.values.each do |value|
      next unless value.is_a?(Numeric)
      if min
        min = value if min > value
      else
        min = value
      end
      if max
        max = value if max < value
      else
        max = value
      end
    end
  end

  result[:min] = min
  result[:max] = max
  result
end

##
# Return min & max values for schedule (constant).
#
# @param [OpenStudio::Model::ScheduleConstant] sched An OS schedule (constant)
#
# @return [Hash] :min & :max; nilled if invalid.
def scheduleConstantMinMax(sched)
  # Largely inspired from David Goldwasser's
  # "schedule_constant_annual_min_max_value":
  #
  # github.com/NREL/openstudio-standards/blob/
  # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
  # standards/Standards.ScheduleConstant.rb#L21
  result = { min: nil, max: nil }
  raise "Invalid sched (constant MinMax)" unless sched
  cl = OpenStudio::Model::ScheduleConstant
  raise "#{sched.class}? expected #{cl} (constant)" unless sched.is_a?(cl)

  min = nil
  min = sched.value if sched.value.is_a?(Numeric)
  max = min

  result[:min] = min
  result[:max] = max
  result
end

##
# Return min & max values for schedule (compact).
#
# @param [OpenStudio::Model::ScheduleCompact] sched An OS schedule (compact)
#
# @return [Hash] :min & :max; nilled if invalid.
def scheduleCompactMinMax(sched)
  # Largely inspired from Andrew Parker's
  # "schedule_compact_annual_min_max_value":
  #
  # github.com/NREL/openstudio-standards/blob/
  # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
  # standards/Standards.ScheduleCompact.rb#L8
  result = { min: nil, max: nil }
  raise "Invalid sched (compact MinMax)" unless sched
  cl = OpenStudio::Model::ScheduleCompact
  raise "#{sched.class}? expected #{cl} (compact)" unless sched.is_a?(cl)

  min = nil
  max = nil

  vals = []
  prev_str = ""
  sch.extensibleGroups.each do |eg|
    if prev_str.include?("until")
      vals << eg.getDouble(0).get unless eg.getDouble(0).empty?
    end
    str = eg.getString(0)
    prev_str = str.get.downcase unless str.empty?
  end

  unless vals.empty?
    min = vals.min if vals.min.is_a?(Numeric)
    max = vals.max if vals.min.is_a?(Numeric)
  end

  result[:min] = min
  result[:max] = max
  result
end

##
# Return max zone heating temperature schedule setpoint [°C].
#
# @param [OpenStudio::Model::ThermalZone] zone An OS thermal zone
#
# @return [Float] Returns max setpoint (nil if invalid)
# @return [Bool] Returns true if zone has (inactive?) dual setpoint thermostat.
def maxHeatScheduledSetpoint(zone)
  # Largely inspired from Parker & Marrec's "thermal_zone_heated?" procedure.
  # The solution here is a tad more relaxed to encompass SEMI-HEATED zones as
  # per Canadian NECB criterai (basically any space with at least 10 W/m2 of
  # installed heating equipement i.e. below freezing in Canada).
  #
  # github.com/NREL/openstudio-standards/blob/
  # 58964222d25783e9da4ae292e375fb0d5c902aa5/lib/openstudio-standards/
  # standards/Standards.ThermalZone.rb#L910
  setpoint = nil
  dual = false
  raise "Invalid zone (max T)" unless zone
  cl = OpenStudio::Model::ThermalZone
  raise "#{zone.class}? expected #{cl} (max T)" unless zone.is_a?(cl)

  # Zone radiant heating? Get schedule from radiant system.
  zone.equipment.each do |equip|
    sched = nil

    unless equip.to_ZoneHVACHighTemperatureRadiant.empty?
      equip = equip.to_ZoneHVACHighTemperatureRadiant.get
      unless equip.heatingSetpointTemperatureSchedule.empty?
        sched = equip.heatingSetpointTemperatureSchedule.get
      end
    end

    unless equip.to_ZoneHVACLowTemperatureRadiantElectric.empty?
      equip = equip.to_ZoneHVACLowTemperatureRadiantElectric.get
      unless equip.heatingSetpointTemperatureSchedule.empty?
        sched = equip.heatingSetpointTemperatureSchedule.get
      end
    end

    unless equip.to_ZoneHVACLowTempRadiantConstFlow.empty?
      equip = equip.to_ZoneHVACLowTempRadiantConstFlow.get
      coil = equip.heatingCoil
      unless coil.to_CoilHeatingLowTempRadiantConstFlow.empty?
        coil = coil.to_CoilHeatingLowTempRadiantConstFlow.get
        unless coil.heatingHighControlTemperatureSchedule.empty?
          sched = c.heatingHighControlTemperatureSchedule.get
        end
      end
    end

    unless equip.to_ZoneHVACLowTempRadiantVarFlow.empty?
      equip = equip.to_ZoneHVACLowTempRadiantVarFlow.get
      coil = equip.heatingCoil
      unless coil.to_CoilHeatingLowTempRadiantVarFlow.empty?
        coil = coil.to_CoilHeatingLowTempRadiantVarFlow.get
        unless coil.heatingControlTemperatureSchedule.empty?
          sched = coil.heatingControlTemperatureSchedule.get
        end
      end
    end

    next unless sched

    unless sched.to_ScheduleRuleset.empty?
      sched = sched.to_ScheduleRuleset.get
      max = scheduleRulesetMinMax(sched)[:max]
      if max
        if setpoint
          setpoint = max if max > setpoint
        else
          setpoint = max
        end
      end
    end

    unless sched.to_ScheduleConstant.empty?
      sched = sched.to_ScheduleConstant.get
      max = scheduleConstantMinMax(sched)[:max]
      if max
        if setpoint
          setpoint = max if max > setpoint
        else
          setpoint = max
        end
      end
    end

    unless sched.to_ScheduleCompact.empty?
      sched = sched.to_ScheduleCompact.get
      max = scheduleCompactMinMax(sched)[:max]
      if max
        if setpoint
          setpoint = max if max > setpoint
        else
          setpoint = max
        end
      end
    end
  end

  return setpoint, dual if setpoint
  return setpoint, dual if zone.thermostat.empty?
  tstat = zone.thermostat.get

  unless tstat.to_ThermostatSetpointDualSetpoint.empty? &&
         tstat.to_ZoneControlThermostatStagedDualSetpoint.empty?
    dual = true
    unless tstat.to_ThermostatSetpointDualSetpoint.empty?
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
    else
      tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
    end

    unless tstat.heatingSetpointTemperatureSchedule.empty?
      sched = tstat.heatingSetpointTemperatureSchedule.get

      unless sched.to_ScheduleRuleset.empty?
        sched = sched.to_ScheduleRuleset.get
        max = scheduleRulesetMinMax(sched)[:max]
        if max
          if setpoint
            setpoint = max if max > setpoint
          else
            setpoint = max
          end
        end

        dd = sched.winterDesignDaySchedule
        unless dd.values.empty?
          if setpoint
            setpoint = dd.values.max if dd.values.max > setpoint
          else
            setpoint = dd.values.max
          end
        end
      end

      unless sched.to_ScheduleConstant.empty?
        sched = sched.to_ScheduleConstant.get
        max = scheduleConstantMinMax(sched)[:max]
        if max
          if setpoint
            setpoint = max if max > setpoint
          else
            setpoint = max
          end
        end
      end

      unless sched.to_ScheduleCompact.empty?
        sched = sched.to_ScheduleCompact.get
        max = scheduleCompactMinMax(sched)[:max]
        if max
          if setpoint
            setpoint = max if max > setpoint
          else
            setpoint = max
          end
        end
      end

      unless sched.to_ScheduleYear.empty?
        sched = sched.to_ScheduleYear.get
        sched.getScheduleWeeks.each do |week|
          next if week.winterDesignDaySchedule.empty?
          dd = week.winterDesignDaySchedule.get
          next unless dd.values.empty?
          if setpoint
            setpoint = dd.values.max if dd.values.max > setpoint
          else
            setpoint = dd.values.max
          end
        end
      end
    end
  end
  return setpoint, dual
end

##
# Validate if model has zones with valid heating temperature setpoints
#
# @param [OpenStudio::Model::Model] model An OS model
#
# @return [Bool] Returns true if valid heating temperature setpoints
def heatingTemperatureSetpoints?(model)
  answer = false
  raise "Invalid model (heat T?)" unless model
  cl = OpenStudio::Model::Model
  raise "#{model.class}? expected #{cl} (heat T?)" unless model.is_a?(cl)

  model.getThermalZones.each do |zone|
    next if answer
    max, _ = maxHeatScheduledSetpoint(zone)
    answer = true unless max
  end
  answer
end

##
# Return min zone cooling temperature schedule setpoint [°C].
#
# @param [OpenStudio::Model::ThermalZone] zone An OS thermal zone
#
# @return [Float] Returns min setpoint (nil if invalid)
# @return [Bool] Returns true if zone has (inactive?) dual setpoint thermostat.
def minCoolScheduledSetpoint(zone)
  # Largely inspired from Parker & Marrec's "thermal_zone_cooled?" procedure.
  #
  # github.com/NREL/openstudio-standards/blob/
  # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
  # standards/Standards.ThermalZone.rb#L1058
  setpoint = nil
  dual = false
  raise "Invalid zone (minT)" unless zone
  cl = OpenStudio::Model::ThermalZone
  raise "#{zone.class}? expected #{cl} (minT)" unless zone.is_a?(cl)

  # Zone radiant cooling? Get schedule from radiant system.
  zone.equipment.each do |equip|
    sched = nil

    unless equip.to_ZoneHVACLowTempRadiantConstFlow.empty?
      equip = equip.to_ZoneHVACLowTempRadiantConstFlow.get
      coil = equip.coolingCoil
      unless coil.to_CoilCoolingLowTempRadiantConstFlow.empty?
        coil = coil.to_CoilCoolingLowTempRadiantConstFlow.get
        unless coil.coolingLowControlTemperatureSchedule.empty?
          sched = coil.coolingLowControlTemperatureSchedule.get
        end
      end
    end

    unless equip.to_ZoneHVACLowTempRadiantVarFlow.empty?
      equip = equip.to_ZoneHVACLowTempRadiantVarFlow.get
      coil = equip.coolingCoil
      unless coil.to_CoilCoolingLowTempRadiantVarFlow.empty?
        coil = coil.to_CoilCoolingLowTempRadiantVarFlow.get
        unless coil.coolingControlTemperatureSchedule.empty?
          sched = coil.coolingControlTemperatureSchedule.get
        end
      end
    end

    next unless sched

    unless sched.to_ScheduleRuleset.empty?
      sched = sched.to_ScheduleRuleset.get
      min = scheduleRulesetMinMax(sched)[:min]
      if min
        if setpoint
          setpoint = min if min < setpoint
        else
          setpoint = min
        end
      end
    end

    unless sched.to_ScheduleConstant.empty?
      sched = sched.to_ScheduleConstant.get
      min = scheduleConstantMinMax(sched)[:min]
      if min
        if setpoint
          setpoint = min if min < setpoint
        else
          setpoint = min
        end
      end
    end

    unless sched.to_ScheduleCompact.empty?
      sched = sched.to_ScheduleCompact.get
      min = scheduleCompactMinMax(sched)[:min]
      if min
        if setpoint
          setpoint = min if min < setpoint
        else
          setpoint = min
        end
      end
    end
  end

  return setpoint, dual if setpoint
  return setpoint, dual if zone.thermostat.empty?
  tstat = zone.thermostat.get

  unless tstat.to_ThermostatSetpointDualSetpoint.empty? &&
         tstat.to_ZoneControlThermostatStagedDualSetpoint.empty?
    dual = true
    unless tstat.to_ThermostatSetpointDualSetpoint.empty?
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
    else
      tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
    end

    unless tstat.coolingSetpointTemperatureSchedule.empty?
      sched = tstat.coolingSetpointTemperatureSchedule.get

      unless sched.to_ScheduleRuleset.empty?
        sched = sched.to_ScheduleRuleset.get
        min = scheduleRulesetMinMax(sched)[:min]
        if min
          if setpoint
            setpoint = min if min < setpoint
          else
            setpoint = min
          end
        end

        dd = sched.summerDesignDaySchedule
        unless dd.values.empty?
          if setpoint
            setpoint = dd.values.min if dd.values.min < setpoint
          else
            setpoint = dd.values.min
          end
        end
      end

      unless sched.to_ScheduleConstant.empty?
        sched = sched.to_ScheduleConstant.get
        min = scheduleConstantMinMax(sched)[:min]
        if min
          if setpoint
            setpoint = min if min < setpoint
          else
            setpoint = min
          end
        end
      end

      unless sched.to_ScheduleCompact.empty?
        sched = sched.to_ScheduleCompact.get
        min = scheduleCompactMinMax(sched)[:min]
        if min
          if setpoint
            setpoint = min if min < setpoint
          else
            setpoint = min
          end
        end
      end

      unless sched.to_ScheduleYear.empty?
        sched = sched.to_ScheduleYear.get
        sched.getScheduleWeeks.each do |week|
          next if week.summerDesignDaySchedule.empty?
          dd = week.summerDesignDaySchedule.get
          next unless dd.values.empty?
          if setpoint
            setpoint = dd.values.min if dd.values.min < setpoint
          else
            setpoint = dd.values.min
          end
        end
      end
    end
  end
  return setpoint, dual
end

##
# Validate if model has zones with valid cooling temperature setpoints
#
# @param [OpenStudio::Model::Model] model An OS model
#
# @return [Bool] Returns true if valid cooling temperature setpoints
def coolingTemperatureSetpoints?(model)
  answer = false
  raise "Invalid model (cool T?)" unless model
  cl = OpenStudio::Model::Model
  raise "#{model.class}? expected #{cl} (cool T?)" unless model.is_a?(cl)

  model.getThermalZones.each do |zone|
    next if answer
    min, _ = minCoolScheduledSetpoint(zone)
    answer = true unless min
  end
  answer
end

##
# Validate if model has zones with HVAC air loops
#
# @param [OpenStudio::Model::Model] model An OS model
#
# @return [Bool] Returns true if HVAC air loops
def airLoopsHVAC?(model)
  answer = false
  raise "Invalid model (loops?)" unless model
  cl = OpenStudio::Model::Model
  raise "#{model.class}? expected #{cl} (loops?)" unless model.is_a?(cl)

  model.getThermalZones.each do |zone|
    next if answer
    next if zone.canBePlenum
    answer = true unless zone.airLoopHVACs.empty?
    answer = true if zone.isPlenum
  end
  answer
end

##
# Validate whether space should be processed as a plenum.
#
# @param [OpenStudio::Model::Space] space An OS space
# @param [Bool] loops True if model has airLoopHVAC objects
# @param [Bool] setpoints True if model has valid temperature setpoints
#
# @return [Bool] Returns true if should be tagged as plenum.
def plenum?(space, loops, setpoints)
  # Largely inspired from NREL's "space_plenum?" procedure.
  #
  # github.com/NREL/openstudio-standards/blob/
  # 58964222d25783e9da4ae292e375fb0d5c902aa5/lib/openstudio-standards/
  # standards/Standards.Space.rb#L1384

  # For a fully-developed OSM (complete with HVAC air loops), space tagged as
  # plenum if zone "isPlenum" (case A).
  #
  # In absence of HVAC air loops, 2x other cases trigger a plenum tag:
  #   case B. space excluded from building's total floor area, yet zone holds an
  #           "inactive" thermostat (i.e., can't extract valid setpoints); or
  #   case C. spacetype is "plenum".
  raise "Invalid space (plenum?)" unless space
  raise "Invalid loops (plenum?)" unless loops
  raise "Invalid setpoints (plenum?)" unless setpoints
  cl = OpenStudio::Model::Space
  cl2 = space.class
  raise "#{cl2}? expected #{cl} (plenum?)" unless space.is_a?(cl)
  a = loops == true || loops == false
  cl2 = loops.class
  raise "#{cl2}? expected true/false (loops in plenum?)" unless a
  a = setpoints == true || setpoints == false
  cl2 = setpoints.class
  raise "#{cl2}? expected true/false (setpoints in plenum?)" unless a

  unless space.thermalZone.empty?
    zone = space.thermalZone.get
    return zone.isPlenum if loops                                       # case A

    if setpoints
      heating, dual1 = maxHeatScheduledSetpoint(zone)
      cooling, dual2 = minCoolScheduledSetpoint(zone)
      return false if heating || cooling            # directly conditioned space

      unless space.partofTotalFloorArea
        return true if dual1 || dual2                                   # case B
      else
        return false
      end
    end
  end

  unless space.spaceType.empty?                                         # case C
    type = space.spaceType.get
    return true if type.nameString.downcase == "plenum"
    unless type.standardsSpaceType.empty?
      type = type.standardsSpaceType.get
      return true if type.downcase == "plenum"
    end
  end
  false
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
  raise "Invalid model (transforms)" unless model
  raise "invalid group (transforms)" unless group
  cl = OpenStudio::Model::Model
  raise "#{model.class}? expected #{cl} (transforms)" unless model.is_a?(cl)
  gr = group.is_a?(OpenStudio::Model::Space)
  gr = group.is_a?(OpenStudio::Model::ShadingSurfaceGroup) || gr
  raise "#{group.class}? expected OS group (transforms)" unless gr

  t = group.siteTransformation
  r = group.directionofRelativeNorth + model.getBuilding.northAxis
  return t, r
end

##
# Return site-specific (or absolute) Topolys surface normal
#
# @param [OpenStudio::Model::PlanarSurface] s An OS planar surface
# @param [Float] r A rotation angle [0,2PI) radians
#
# @return [OpenStudio::Vector3D] Returns normal vector <x,y,z> of s
def trueNormal(s, r)
  raise "Invalid surface (normals)" unless s
  raise "Invalid rotation angle (normals)" unless r
  cl = OpenStudio::Model::PlanarSurface
  raise "#{s.class}? expected #{c} (normals)" unless s.is_a?(cl)
  raise "#{r.class}? expected numeric (normals)" unless r.is_a?(Numeric)

  n = Topolys::Vector3D.new(s.outwardNormal.x * Math.cos(r) -
                            s.outwardNormal.y * Math.sin(r),                 # x
                            s.outwardNormal.x * Math.sin(r) +
                            s.outwardNormal.y * Math.cos(r),                 # y
                            s.outwardNormal.z)                               # z
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
  raise "Invalid model (Topolys obj)" unless model
  raise "Invalid points (Topolys obj)" unless points
  cl = Topolys::Model
  cl2 = model.class
  raise "#{cl2}? expected #{cl} (Topolys obj)" unless model.is_a?(cl)
  cl2 = points.class
  raise "#{cl2}? expected array (Topolys obj)" unless points.is_a?(Array)
  n = points.size
  raise "#{n}? expected +2 points (Topolys obj)" unless n > 2

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
  raise "Invalid model (TBD kids)" unless model
  raise "Invalid kids (TBD kids)" unless kids
  cl = Topolys::Model
  cl2 = model.class
  raise "#{cl2}? expected #{cl} (TBD kids)" unless model.is_a?(cl)
  cl2 = kids.class
  raise "#{cl2}? expected surface hash (TBD kids)" unless kids.is_a?(Hash)

  kids.each do |id, properties|
    vtx, hole = topolysObjects(model, properties[:points])
    hole.attributes[:id] = id
    hole.attributes[:n] = properties[:n] if properties.has_key?(:n)
    properties[:hole] = hole
    holes << hole
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
  raise "Invalid model (TBD dads)" unless model
  raise "Invalid kids (TBD dads)" unless dads
  cl = Topolys::Model
  cl2 = model.class
  raise "#{cl2}? expected #{cl} (TBD dads)" unless model.is_a?(cl)
  cl2 = dads.class
  raise "#{cl2}? expected surface hash (TBD dads)" unless dads.is_a?(Hash)

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
  tbd_holes
end

##
# Populate TBD edges with linked Topolys faces.
#
# @param [Hash] surfaces A collection of TBD surfaces
# @param [Hash] edges A collection TBD edges
def tbdSurfaceEdges(surfaces, edges)
  raise "Invalid surfaces (TBD edges)" unless surfaces
  raise "Invalid edges (TBD edges)" unless edges
  cl = Hash
  cl2 = surfaces.class
  raise "#{cl2}? expected surfaces hash (TBD edges)" unless surfaces.is_a?(cl)
  cl2 = edges.class
  raise "#{cl2}? expected edges hash (TBD edges)" unless edges.is_a?(cl)

  surfaces.each do |id, properties|
    unless properties.has_key?(:face)
      raise "Missing Topolys face for #{id} (TBD edges)"
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
# @return [Bool] Returns true if Kiva foundations are successfully generated.
def generateKiva(os_model, walls, floors, edges)
  raise "Invalid OS model (gen KIVA)" unless os_model
  raise "Invalid walls (gen KIVA)" unless walls
  raise "Invalid floors (gen KIVA)" unless floors
  raise "Invalid edges (gen KIVA)" unless edges
  cl = OpenStudio::Model::Model
  cl2 = os_model.class
  raise "#{cl2}? expected #{cl} (gen KIVA)" unless os_model.is_a?(cl)
  cl2 = walls.class
  raise "#{cl2}? expected walls hash (gen KIVA)" unless walls.is_a?(Hash)
  cl2 = floors.class
  raise "#{cl2}? expected floors hash (gen KIVA)" unless floors.is_a?(Hash)
  cl2 = edges.class
  raise "#{cl2}? expected edges hash (gen KIVA)" unless edges.is_a?(Hash)

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
  foundation_kiva_settings = os_model.getFoundationKivaSettings

  # One way to expose in-built default parameters (in the future), e.g.:
  # soil_k = foundation_kiva_settings.soilConductivity
  # foundation_kiva_settings.setSoilConductivity(soil_k)

  # Generic 1" XPS insulation (for slab-on-grade setup) - unused if basement.
  xps25mm = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
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

      floors[id][:foundation] = OpenStudio::Model::FoundationKiva.new(os_model)

      # It's assumed that generated foundation walls have insulated
      # constructions. Perimeter insulation for slabs-on-grade.
      # Typical circa-1980 slab-on-grade (perimeter) insulation setup.
      if floors[id][:kiva] == :slab
        floors[id][:foundation].setInteriorHorizontalInsulationMaterial(xps25mm)
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
  raise "Invalid construction (layer)" unless construction
  cl = OpenStudio::Model::Construction
  cl2 = construction.class
  raise "#{cl2}? expected #{cl} (layer)" unless construction.is_a?(cl)

  # Identify insulating material (and key attributes) within a construction.
  r                = 0.0         # R-value of insulating material
  index            = nil         # index of insulating material
  type             = nil         # nil, :massless; or :standard
  i                = 0           # iterator

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
# @param [OpenStudio::Model::Model] os_model An OS model
# @param [String] id Insulating material identifier
# @param [Hash] surface A TBD surface
# @param [OpenStudio::Model::Construction] c An OS construction
#
# @return [OpenStudio::Model::Material] Returns derated (cloned) material
def derate(os_model, id, surface, c)
  raise "Invalid OS model (derate)" unless os_model
  raise "Invalid ID (derate)" unless id
  raise "Invalid surface (derate)" unless surface
  raise "Invalid construction (derate)" unless c
  cl = OpenStudio::Model::Model
  cl2 = os_model.class
  raise "#{cl2}? expected #{cl} (derate)" unless os_model.is_a?(cl)
  cl = Hash
  cl2 = surface.class
  raise "#{cl2}? expected #{cl} (derate)" unless surface.is_a?(cl)
  cl = OpenStudio::Model::Construction
  raise "#{c.class}? expected #{cl} (derate)" unless c.is_a?(cl)

  m = nil
  if surface.has_key?(:heatloss)                                    &&
    surface[:heatloss].is_a?(Numeric)                               &&
    surface[:heatloss].abs > 0.01                                   &&
    surface.has_key?(:net)                                          &&
    surface[:net].is_a?(Numeric)                                    &&
    surface[:net] > 0.01                                            &&
    surface.has_key?(:construction)                                 &&
    surface.has_key?(:index)                                        &&
    surface[:index] != nil                                          &&
    surface[:index].is_a?(Integer)                                  &&
    surface[:index] >= 0                                            &&
    surface.has_key?(:ltype)                                        &&
    (surface[:ltype] == :massless || surface[:ltype] == :standard)  &&
    surface.has_key?(:r)                                            &&
    surface[:r].is_a?(Numeric)                                      &&
    surface[:r] >= 0.001                                            &&
    / tbd/i.match(c.nameString) == nil                 # skip if already derated

    index          = surface[:index]
    ltype          = surface[:ltype]
    r              = surface[:r]
    u              = surface[:heatloss] / surface[:net]
    loss           = 0.0
    de_u           = 1.0 / r + u                                     # derated U
    de_r           = 1.0 / de_u                                      # derated R

    if ltype == :massless
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

    else                                                    # ltype == :standard
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
# @param [String] ioP Path to a user-set TBD JSON input file (optional)
# @param [String] schemaP Path to a TBD JSON schema file (optional)
# @param [Bool] g_kiva Have TBD generate Kiva objects
#
# @return [Hash] Returns TBD collection of objects for JSON serialization
# @return [Hash] Returns collection of derated TBD surfaces
def processTBD(os_model, psi_set, ioP = nil, schemaP = nil, g_kiva = false)
  raise "Invalid OS model (process TBD)" unless os_model
  cl = OpenStudio::Model::Model
  raise "#{os_model.class}? expected OS model" unless os_model.is_a?(cl)
  a = g_kiva == true || g_kiva == false
  raise "#{g_kiva.class}? expected true or false (process TBD)" unless a

  os_building = os_model.getBuilding

  # Create the Topolys Model.
  t_model = Topolys::Model.new

  # TBD deals with ~insulated envelope surfaces enclosing spaces that are
  # directly or indirectly CONDITIONED, or SEMI-HEATED. TBD is designed to
  # ignore surfaces in UNCONDITIONED and UNENCLOSED spaces. TBD relies as
  # much as possible on space conditioning categories found in standards like
  # ASHRAE 90.1 and energy codes like the Canadian NECB. Both documents share
  # many similarities, regardless of nomenclature. There are however
  # noticeable differences between approaches on how a space is tagged as
  # falling into any of the aforementioned categories. First, an overview of
  # 90.1 requirements (with some minor edits for brevity + added emphasis):
  #
  # www.pnnl.gov/main/publications/external/technical_reports/PNNL-26917.pdf
  #
  #   3.2.1. General Information - SPACE CONDITIONING CATEGORY
  #
  #     - CONDITIONED space: an ENCLOSED space that has a heating and/or
  #       cooling system of sufficient size to maintain temperatures suitable
  #       for HUMAN COMFORT:
  #         - COOLED: cooled by a system >= 10 W/m2
  #         - HEATED: heated by a system e.g., >= 50 W/m2 in Climate Zone CZ-7
  #         - INDIRECTLY: heated or cooled via adjacent space(s) provided:
  #             - UA of adjacent surfaces > UA of other surfaces
  #                 or
  #             - intentional air transfer from HEATED/COOLED space > 3 ACH
  #
  #               ... includes plenums, atria, etc.
  #
  #     - SEMI-HEATED space: an ENCLOSED space that has a heating system
  #       >= 10 W/m2, yet NOT a CONDITIONED space (see above).
  #
  #     - UNCONDITIONED space: an ENCLOSED space that is NOT a conditioned
  #       space or a SEMI-HEATED space (see above).
  #
  #       NOTE: Crawlspaces, attics, and parking garages with natural or
  #       mechanical ventilation are considered UNENCLOSED spaces.
  #
  #       2.3.3 Modeling Requirements: surfaces adjacent to UNENCLOSED spaces
  #       shall be treated as exterior surfaces. All other UNENCLOSED surfaces
  #       are to be modeled as is in both proposed and baseline models. For
  #       instance, modeled fenestration in UNENCLOSED spaces would not be
  #       factored in WWR calculations.
  #
  #
  # Related NECB definitions and concepts, starting with CONDITIONED space:
  #
  # "[...] the temperature of which is controlled to limit variation in
  # response to the exterior ambient temperature by the provision, either
  # DIRECTLY or INDIRECTLY, of heating or cooling [...]". Although criteria
  # differ (e.g., not sizing-based), the general idea is sufficiently similar
  # to ASHRAE 90.1 for TBD purposes (e.g., heating and/or cooling based, no
  # distinction for INDIRECTLY conditioned spaces like plenums).
  #
  # SEMI-HEATED spaces are also a defined NECB term, but again the distinction
  # is based on desired/intended design space setpoint temperatures - not
  # system sizing criteria. However, as there is currently little-to-no
  # guidance on how to adapt thermal bridge PSI-values when dealing with
  # spaces not intended to be maintained at 21°C (ref: BETBG), by default TBD
  # will seek to process envelope surfaces in SEMI-HEATED spaces as those in
  # CONDITIONED spaces. Users can always rely of customized PSI sets to target
  # SEMI-HEATED spaces e.g., space- or spacetype-specific.
  #
  # The single NECB criterion distinguishing UNCONDITIONED ENCLOSED spaces
  # (such as vestibules) from UNENCLOSED spaces (such as attics) remains the
  # intention to ventilate - or rather to what degree. Regardless, TBD will
  # process both classifications in the same way, namely by focusing on
  # adjacent surfaces to CONDITIONED (or SEMI-HEATED) spaces as part of the
  # building envelope.

  # In light of the preceding compare/contrast analysis, TBD is designed to
  # handle envelope surfaces without a priori knowledge of explicit system
  # sizing choices or access to iterative autosizing processes. As discussed
  # in the following, TBD seeks to rely on zoning info and/or "intended"
  # temperature setpoints to determine which surfaces to process.
  #
  # For an OSM in an incomplete or preliminary state (e.g., holding fully-formed
  # ENCLOSED spaces without thermal zoning information or setpoint temperatures
  # [early design stage assessments of form/porosity/envelope]), TBD will only
  # seek to derate opaque, outdoor-facing surfaces by positing that all OSM
  # spaces are CONDITIONED, having setpoints of ~21°C (heating) and ~24°C
  # (cooling), à la BETBG.
  #
  # If any valid space/zone-specific temperature setpoints are found in the OSM,
  # TBD will instead seek to tag outdoor-facing opaque surfaces with their
  # parent space/zone's explicit heating (max) and/or cooling (min) setpoints.
  # In such cases, spaces/zones without valid heating or cooling setpoints are
  # either considered as UNCONDITIONED or UNENCLOSED spaces (like attics), or
  # INDIRECTLY CONDITIONED spaces (like plenums), see "plenum?" function.

  # "true" if any OSM space/zone holds setpoint temperatures.
  setpoints = heatingTemperatureSetpoints?(os_model)
  setpoints = coolingTemperatureSetpoints?(os_model) || setpoints

  # "true" if any OSM space/zone is part of an HVAC air loop.
  airloops = airLoopsHVAC?(os_model)

  # Fetch OpenStudio (opaque) surfaces & key attributes.
  surfaces = {}
  os_model.getSurfaces.each do |s|
    next if s.space.empty?
    space = s.space.get
    id    = s.nameString

    ground   = s.isGroundSurface
    boundary = s.outsideBoundaryCondition
    if boundary.downcase == "surface"
      raise "#{id}: adjacent surface?" if s.adjacentSurface.empty?
      adjacent = s.adjacentSurface.get.nameString
      test = os_model.getSurfaceByName(adjacent)
      raise "mismatch #{id} vs #{adjacent}" if test.empty?
      boundary = adjacent
    end

    conditioned = true
    if setpoints
      unless space.thermalZone.empty?
        zone = space.thermalZone.get
        heating, _ = maxHeatScheduledSetpoint(zone)
        cooling, _ = minCoolScheduledSetpoint(zone)
        unless heating || cooling
          conditioned = false unless plenum?(space, airloops, setpoints)
        end
      else
        conditioned = false unless plenum?(space, airloops, setpoints)
      end
    end

    # Site-specific (or absolute, or true) surface normal.
    t, r = transforms(os_model, space)
    n = trueNormal(s, r)

    type = :floor
    type = :ceiling if /ceiling/i.match(s.surfaceType)
    type = :wall    if /wall/i.match(s.surfaceType)

    points   = (t * s.vertices).map{ |v| Topolys::Point3D.new(v.x, v.y, v.z) }
    minz     = (points.map{ |p| p.z }).min

    # Content of the hash will evolve over the next few hundred lines.
    surfaces[id] = {
      type:         type,
      conditioned:  conditioned,
      ground:       ground,
      boundary:     boundary,
      space:        space,
      gross:        s.grossArea,
      net:          s.netArea,
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
      unless index.nil?
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
      surface[:deratable] = true
    else
      next unless surfaces.has_key?(b)
      next unless surfaces[b].has_key?(:conditioned)
      next if surfaces[b][:conditioned]
      surface[:deratable] = true
    end
  end

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

          # Store angle.
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
  # derate linked OpenStudio surfaces), depending on a number of factors such
  # as surface types, space conditioning and boundary conditions. Thermal
  # bridging attributes (type & PSI-value pairs) are grouped into PSI sets,
  # normally accessed through the 'set' user-argument (in the OpenStudio
  # Measure interface).

  # Process user-defined TBD JSON file inputs if file exists & valid:
  #   "io" holds valid TBD JSON hash from file
  #   "io_p" holds TBD PSI sets (built-in defaults & those on file)
  #   "io_k" holds TBD KHI points (built-in defaults & those on file)
  io, io_p, io_k = processTBDinputs(surfaces, edges, psi_set, ioP, schemaP)

  edges.values.each do |edge|
    next unless edge.has_key?(:surfaces)

    # Skip unless one (at least) linked surface is deratable.
    deratable = false
    edge[:surfaces].each do |id, surface|
      next if deratable
      next unless surfaces.has_key?(id)
      next unless surfaces[id].has_key?(:deratable)
      deratable = true if surfaces[id][:deratable]
    end
    next unless deratable

    psi = {}                                           # edge-specific PSI types
    p = io[:building].first[:psi]                         # default building PSI

    match = false
    if edge.has_key?(:io_type)                # customized edge in TBD JSON file
      p = edge[:io_set]       if edge.has_key?(:io_set)
      edge[:set] = p          if io_p.set.has_key?(p)

      unless edge[:io_type] == :fenestration ||
             edge[:io_type] == :head         ||
             edge[:io_type] == :sill         ||
             edge[:io_type] == :jamb
        match = true
        t = edge[:io_type]
        psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
      end
    end

    edge[:surfaces].keys.each do |id|
      next if match                                         # skip if customized
      next unless surfaces.has_key?(id)
      next unless surfaces[id].has_key?(:conditioned)
      next unless surfaces[id][:conditioned]

      # Label edge as :party if linked to:
      #   1x adiabatic surface
      #   1x (only) deratable surface
      unless psi.has_key?(:party)
        count = 0
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:party)
          next if i == id
          next unless surfaces.has_key?(i)
          next unless surfaces[i].has_key?(:deratable)
          next unless surfaces[i][:deratable]
          count += 1
        end
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:party)
          next if count == 1
          next unless surfaces[id].has_key?(:deratable)
          next unless surfaces[id][:deratable]
          next unless surfaces.has_key?(i)
          next unless surfaces[i].has_key?(:deratable)
          next if surfaces[i][:deratable]
          next unless surfaces[i][:boundary].downcase == "adiabatic"
          psi[:party] = io_p.set[p][:party]
        end
      end

      # Label edge as :grade if linked to:
      #   1x surface (e.g. slab or wall) facing ground
      #   1x surface (i.e. wall) facing outdoors
      unless psi.has_key?(:grade)
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:grade)
          next unless surfaces[id].has_key?(:ground)
          next unless surfaces[id][:ground]
          next unless surfaces.has_key?(i)
          next unless surfaces[i].has_key?(:conditioned)
          next unless surfaces[i][:conditioned]
          next unless surfaces[i][:boundary].downcase == "outdoors"
          psi[:grade] = io_p.set[p][:grade]
        end
      end

      # Label edge as :balcony if linked to:
      #   1x floor
      #   1x shade
      unless psi.has_key?(:balcony)
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:balcony)
          next unless shades.has_key?(i)
          next unless floors.has_key?(id)
          psi[:balcony] = io_p.set[p][:balcony]
        end
      end

      # Label edge as :parapet if linked to:
      #   1x deratable wall
      #   1x deratable ceiling
      unless psi.has_key?(:parapet)
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:parapet)
          next unless ceilings.has_key?(id)
          next unless ceilings[id].has_key?(:deratable)
          next unless ceilings[id][:deratable]
          next unless walls.has_key?(i)
          next unless walls[i].has_key?(:deratable)
          next unless walls[i][:deratable]
          psi[:parapet] = io_p.set[p][:parapet]
        end
      end

      # Repeat for exposed floors vs walls, as :parapet is currently a
      # proxy for intersections between exposed floors & walls. Optional
      # :bandjoist could be favoured for such cases.
      unless psi.has_key?(:parapet)
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:parapet)
          next unless floors.has_key?(id)
          next unless floors[id].has_key?(:deratable)
          next unless floors[id][:deratable]
          next unless walls.has_key?(i)
          next unless walls[i].has_key?(:deratable)
          next unless walls[i][:deratable]
          psi[:parapet] = io_p.set[p][:parapet]
        end
      end

      # Repeat for exposed floors vs roofs, as :parapet is currently a
      # proxy for intersections between exposed floors & roofs. Optional
      # :bandjoist could be favoured for such cases.
      unless psi.has_key?(:parapet)
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:parapet)
          next unless floors.has_key?(id)
          next unless floors[id].has_key?(:deratable)
          next unless floors[id][:deratable]
          next unless ceilings.has_key?(i)
          next unless ceilings[i].has_key?(:deratable)
          next unless ceilings[i][:deratable]
          psi[:parapet] = io_p.set[p][:parapet]
        end
      end

      # Label edge as :rimjoist if linked to:
      #   1x deratable wall
      #   1x CONDITIONED floor
      unless psi.has_key?(:rimjoist)
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:rimjoist)
          next unless floors.has_key?(i)
          next unless floors[i].has_key?(:conditioned)
          next unless floors[i][:conditioned]
          next if floors[i][:ground]
          next unless walls.has_key?(id)
          next unless walls[id].has_key?(:deratable)
          next unless walls[id][:deratable]
          psi[:rimjoist] = io_p.set[p][:rimjoist]
        end
      end

      # Label edge as :head, :sill or :jamb if linked to:
      #   1x subsurface
      unless psi.has_key?(:head) || psi.has_key?(:sill) || psi.has_key?(:jamb)
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:head) ||
                  psi.has_key?(:sill) ||
                  psi.has_key?(:jamb)
          answer   = holes.has_key?(i)
          overall  = answer && io_p.set[p].has_key?(:fenestration)
          complete = answer &&
                     io_p.set[p].has_key?(:head) &&
                     io_p.set[p].has_key?(:sill) &&
                     io_p.set[p].has_key?(:jamb)
          answer   = answer && (overall || complete)
          next unless answer
          s = edge[:surfaces][i]

          # Subsurface edges are tagged as :head, :sill or :jamb, regardless
          # of building PSI set subsurface tags. If the latter is simply
          # :fenestration, then its (single) PSI value is systematically
          # attributed to subsurface :head, :sill & :jamb edges.
          #
          # TBD tags a subsurface edge as :jamb if the subsurface is "flat". If
          # not flat, TBD tags a horizontal edge as either :head or :sill based
          # on the polar angle of the subsurface around the edge vs sky zenith.
          # Otherwise, all other subsurface edges are tagged as :jamb.
          if ((s[:normal].dot(zenith)).abs - 1).abs < 0.01                # flat
            psi[:jamb] = io_p.set[p][:jamb]             if complete
            psi[:jamb] = io_p.set[p][:fenestration]     if overall
          else
            if edge[:horizontal]                                # :head or :sill
              if s[:polar].dot(zenith) < 0
                psi[:head] = io_p.set[p][:head]         if complete
                psi[:head] = io_p.set[p][:fenestration] if overall
              else
                psi[:sill] = io_p.set[p][:sill]         if complete
                psi[:sill] = io_p.set[p][:fenestration] if overall
              end
            else
              psi[:jamb] = io_p.set[p][:jamb]           if complete
              psi[:jamb] = io_p.set[p][:fenestration]   if overall
            end
          end
          edge[:complete] = complete
          edge[:overall]  = overall
        end
      end

      # Label edge as :concave or :convex (corner) if linked to:
      #   2x deratable walls & f(relative polar positions of walls)
      unless psi.has_key?(:concave) || psi.has_key?(:convex)
        edge[:surfaces].keys.each do |i|
          next if psi.has_key?(:concave) || psi.has_key?(:convex)
          next if i == id
          next unless walls.has_key?(id)
          next unless walls[id].has_key?(:deratable)
          next unless walls[id][:deratable]
          next unless walls.has_key?(i)
          next unless walls[i].has_key?(:deratable)
          next unless walls[i][:deratable]

          s1 = edge[:surfaces][id]
          s2 = edge[:surfaces][i]

          angle = (s2[:angle] - s1[:angle]).abs
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

  # Tracking (mild) transitions between deratable surfaces around edges that
  # have not been previously tagged.
  edges.each do |tag, edge|
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

    psi = {}
    p = io[:building].first[:psi]

    match = false
    if edge.has_key?(:io_type)                # customized edge in TBD JSON file
      p = edge[:io_set]       if edge.has_key?(:io_set)
      edge[:set] = p          if io_p.set.has_key?(p)

      unless edge[:io_type] == :fenestration ||
             edge[:io_type] == :head         ||
             edge[:io_type] == :sill         ||
             edge[:io_type] == :jamb
        match = true
        t = edge[:io_type]
        psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
      end
    end

    count = 0
    edge[:surfaces].keys.each do |id|
      next if match
      next unless surfaces.has_key?(id)
      next unless surfaces[id].has_key?(:deratable)
      next unless surfaces[id][:deratable]
      count += 1
    end
    next unless count > 0
    psi[:transition] = 0.000
    edge[:psi] = psi
    edge[:set] = p
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
    tt = :fenestration

    if io.has_key?(:stories)
      io[:stories].each do |story|
        next unless story.has_key?(:id)
        next unless story.has_key?(:psi)
        i = story[:id]
        p = story[:psi]
        next unless io_p.set.has_key?(p)               # raise warning in future

        complet = false
        complet = true if io_p.set[p].has_key?(:head) &&
                          io_p.set[p].has_key?(:sill) &&
                          io_p.set[p].has_key?(:jamb)

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)
          next if edge.has_key?(:io_set)       # customized edge WITH custom PSI
          next unless edge.has_key?(:surfaces)
          edge[:surfaces].keys.each do |id|
            next unless surfaces.has_key?(id)
            next unless surfaces[id].has_key?(:story)
            st = surfaces[id][:story]
            next unless i == st.nameString
            edge[:stories] = {} unless edge.has_key?(:stories)
            edge[:stories][p] = {}

            psi = {}
            if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
              t = edge[:io_type]
              psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
            else
              edge[:psi].keys.each do |t|
                if t == :head || t == :sill || t == :jamb
                  if complet
                    psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                  else
                    psi[t] = io_p.set[p][tt] if io_p.set[p].has_key?(tt)
                  end
                else                                          # not fenestration
                  psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                end
              end
            end
            edge[:stories][p] = psi
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
        edge[:psi].keys.each do |type|
          vals = {}
          edge[:stories].each do |p, psi|
            vals[p] = psi[type] if psi.has_key?(type)
          end
          next if vals.empty?
          edge[:psi][type] = vals.values.max
          edge[:sets] = {} unless edge.has_key?(:sets)
          edge[:sets][type] = vals.key(vals.values.max)
        end
      end
    end

    if io.has_key?(:spacetypes)
      io[:spacetypes].each do |stype|
        next unless stype.has_key?(:id)
        next unless stype.has_key?(:psi)
        i = stype[:id]
        p = stype[:psi]
        next unless io_p.set.has_key?(p)               # raise warning in future

        complet = false
        complet = true if io_p.set[p].has_key?(:head) &&
                          io_p.set[p].has_key?(:sill) &&
                          io_p.set[p].has_key?(:jamb)

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)
          next if edge.has_key?(:io_set)       # customized edge WITH custom PSI
          next unless edge.has_key?(:surfaces)
          edge[:surfaces].keys.each do |id|
            next unless surfaces.has_key?(id)
            next unless surfaces[id].has_key?(:stype)
            st = surfaces[id][:stype]
            next unless i == st.nameString
            edge[:spacetypes] = {} unless edge.has_key?(:spacetypes)
            edge[:spacetypes][p] = {}

            psi = {}
            if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
              t = edge[:io_type]
              psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
            else
              edge[:psi].keys.each do |t|
                if t == :head || t == :sill || t == :jamb
                  if complet
                    psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                  else
                    psi[t] = io_p.set[p][tt] if io_p.set[p].has_key?(tt)
                  end
                else                                          # not fenestration
                  psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                end
              end
            end
            edge[:spacetypes][p] = psi
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
        edge[:psi].keys.each do |type|
          vals = {}
          edge[:spacetypes].each do |p, psi|
            vals[p] = psi[type] if psi.has_key?(type)
          end
          next if vals.empty?
          edge[:psi][type] = vals.values.max
          edge[:sets] = {} unless edge.has_key?(:sets)
          edge[:sets][type] = vals.key(vals.values.max)
        end
      end
    end

    if io.has_key?(:spaces)
      io[:spaces].each do |space|
        next unless space.has_key?(:id)
        next unless space.has_key?(:psi)
        i = space[:id]
        p = space[:psi]
        next unless io_p.set.has_key?(p)               # raise warning in future

        complet = false
        complet = true if io_p.set[p].has_key?(:head) &&
                          io_p.set[p].has_key?(:sill) &&
                          io_p.set[p].has_key?(:jamb)

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)
          next if edge.has_key?(:io_set)       # customized edge WITH custom PSI
          next unless edge.has_key?(:surfaces)
          edge[:surfaces].keys.each do |id|
            next unless surfaces.has_key?(id)
            next unless surfaces[id].has_key?(:space)
            sp = surfaces[id][:space]
            next unless i == sp.nameString
            edge[:spaces] = {} unless edge.has_key?(:spaces)
            edge[:spaces][p] = {}

            psi = {}
            if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
              t = edge[:io_type]
              psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
            else
              edge[:psi].keys.each do |t|
                if t == :head || t == :sill || t == :jamb
                  if complet
                    psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                  else
                    psi[t] = io_p.set[p][tt] if io_p.set[p].has_key?(tt)
                  end
                else                                          # not fenestration
                  psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                end
              end
            end
            edge[:spaces][p] = psi
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
        edge[:psi].keys.each do |type|
          vals = {}
          edge[:spaces].each do |p, psi|
            vals[p] = psi[type] if psi.has_key?(type)
          end
          next if vals.empty?
          edge[:psi][type] = vals.values.max
          edge[:sets] = {} unless edge.has_key?(:sets)
          edge[:sets][type] = vals.key(vals.values.max)
        end
      end
    end

    if io.has_key?(:surfaces)
      io[:surfaces].each do |surface|
        next unless surface.has_key?(:id)
        next unless surface.has_key?(:psi)
        i = surface[:id]
        p = surface[:psi]
        next unless io_p.set.has_key?(p)               # raise warning in future

        complet = false
        complet = true if io_p.set[p].has_key?(:head) &&
                          io_p.set[p].has_key?(:sill) &&
                          io_p.set[p].has_key?(:jamb)

        edges.values.each do |edge|
          next unless edge.has_key?(:psi)
          next if edge.has_key?(:io_set)       # customized edge WITH custom PSI
          next unless edge.has_key?(:surfaces)
          edge[:surfaces].each do |id, s|
            next unless surfaces.has_key?(id)
            next unless i == id

            psi = {}
            if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
              if edge[:io_type] == tt
                t = :head if edge.has_key?(:head)
                t = :sill if edge.has_key?(:sill)
                t = :jamb if edge.has_key?(:jamb)
              else
                t = edge[:io_type]
              end
              psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
            else
              edge[:psi].keys.each do |t|
                if t == :head || t == :sill || t == :jamb
                  if complet
                    psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                  else
                    psi[t] = io_p.set[p][tt] if io_p.set[p].has_key?(tt)
                  end
                else                                          # not fenestration
                  psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                end
              end
            end
            s[:psi] = psi
            s[:set] = p
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
        edge[:psi].keys.each do |type|
          vals = {}
          edge[:surfaces].each do |id, s|
            next unless s.has_key?(:psi)
            next unless s.has_key?(:set)
            psi = s[:psi]
            next if psi.empty?
            p = s[:set]
            vals[p] = psi[type] if psi.has_key?(type)
          end
          next if vals.empty?
          edge[:psi][type] = vals.values.max
          edge[:sets] = {} unless edge.has_key?(:sets)
          edge[:sets][type] = vals.key(vals.values.max)
        end
      end
    end

    # Loop through all customized edges on file WITH a custom PSI set
    edges.values.each do |edge|
      next unless edge.has_key?(:psi)
      next unless edge.has_key?(:io_set)
      next unless edge.has_key?(:io_type)
      next unless edge.has_key?(:surfaces)

      p = edge[:io_set]
      next unless io_p.set.has_key?(p)
      psi = {}

      if edge[:io_type] == tt
        t = :head if edge[:psi].has_key?(:head)
        t = :sill if edge[:psi].has_key?(:sill)
        t = :jamb if edge[:psi].has_key?(:jamb)
        psi[t] = io_p.set[p][tt]
      else
        t = edge[:io_type]
        if io_p.set[p].has_key?(t)
          psi[t] = io_p.set[p][t]
        elsif t == :head || t == :sill || t == :jamb
          psi[t] = io_p.set[p][tt] if io_p.set[p].has_key?(tt)
        else
          # Test to ensure this never happens ...
        end
      end
      next if psi.empty?

      edge[:psi] = psi
      edge[:set] = p
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

    # Retrieve linked openings.
    openings = {}
    if edge[:psi].has_key?(:head) ||
       edge[:psi].has_key?(:sill) ||
       edge[:psi].has_key?(:jamb)
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
  surfaces.values.each do |surface|
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
    next unless surface[:heatloss].abs > 0.01
    os_model.getSurfaces.each do |s|
      next unless id == s.nameString
      index = surface[:index]
      current_c = surface[:construction]
      c = current_c.clone(os_model).to_Construction.get

      m = nil
      m = derate(os_model, id, surface, c) unless index.nil?

      # m may be nilled simply because the targeted construction has already
      # been derated, i.e. holds " tbd" in its name. Names of cloned/derated
      # constructions (due to TBD) include the surface name (since derated
      # constructions are now unique to each surface) and the suffix " c tbd".
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
        surface[:ratio] = ratio if ratio.abs > 0.01
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
