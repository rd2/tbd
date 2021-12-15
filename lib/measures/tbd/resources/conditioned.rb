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
  unless sched && sched.is_a?(OpenStudio::Model::ScheduleRuleset)
    TBD.log(TBD::DEBUG,
      "Invalid ruleset MinMax schedule (argument) - skipping")
    return result
  end

  profiles = []
  profiles << sched.defaultDaySchedule
  rules = sched.scheduleRules
  rules.each { |rule| profiles << rule.daySchedule }

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
  unless sched && sched.is_a?(OpenStudio::Model::ScheduleConstant)
    TBD.log(TBD::DEBUG,
      "Invalid constant MinMax schedule (argument) - skipping")
    return result
  end

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
  unless sched && sched.is_a?(OpenStudio::Model::ScheduleCompact)
    TBD.log(TBD::DEBUG,
      "Invalid compact MinMax schedule (argument) - skipping")
    return result
  end

  min = nil
  max = nil

  vals = []
  prev_str = ""
  sched.extensibleGroups.each do |eg|
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
  unless zone && zone.is_a?(OpenStudio::Model::ThermalZone)
    TBD.log(TBD::DEBUG,
      "Invalid max heat setpoint thermal zone (argument) - skipping")
    return setpoint, dual
  end

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
# Validate if model has zones with valid heating temperature setpoints.
#
# @param [OpenStudio::Model::Model] model An OS model
#
# @return [Bool] Returns true if valid heating temperature setpoints
def heatingTemperatureSetpoints?(model)
  answer = false
  unless model && model.is_a?(OpenStudio::Model::Model)
    TBD.log(TBD::DEBUG,
      "Can't find or validate OSM (argument) for heating setpoints - skipping")
    return answer
  end

  model.getThermalZones.each do |zone|
    next if answer
    max, _ = maxHeatScheduledSetpoint(zone)
    return true if max
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
  unless zone && zone.is_a?(OpenStudio::Model::ThermalZone)
    TBD.log(TBD::DEBUG,
      "Invalid min cool setpoint thermal zone (argument) - skipping")
    return setpoint, dual
  end

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
# Validate if model has zones with valid cooling temperature setpoints.
#
# @param [OpenStudio::Model::Model] model An OS model
#
# @return [Bool] Returns true if valid cooling temperature setpoints
def coolingTemperatureSetpoints?(model)
  answer = false
  unless model && model.is_a?(OpenStudio::Model::Model)
    TBD.log(TBD::DEBUG,
      "Can't find or validate OSM (argument) for cooling setpoints - skipping")
    return answer
  end

  model.getThermalZones.each do |zone|
    next if answer
    min, _ = minCoolScheduledSetpoint(zone)
    answer = true if min
  end
  answer
end

##
# Validate if model has zones with HVAC air loops.
#
# @param [OpenStudio::Model::Model] model An OS model
#
# @return [Bool] Returns true if HVAC air loops
def airLoopsHVAC?(model)
  answer = false
  unless model && model.is_a?(OpenStudio::Model::Model)
    TBD.log(TBD::DEBUG,
      "Can't find or validate OSM (argument) for HVAC air loops - skipping")
    return answer
  end

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
  cl = OpenStudio::Model::Space
  unless space && space.is_a?(cl)
    TBD.log(TBD::DEBUG,
      "Invalid plenum space (argument) - skipping")
    return false
  end
  unless loops == true || loops == false
    TBD.log(TBD::DEBUG,
      "Invalid plenum loops (argument) - skipping")
    return false
  end
  unless setpoints == true || setpoints == false
    TBD.log(TBD::DEBUG,
      "Invalid plenum setpoints (argument) - skipping")
    return false
  end

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
