require "openstudio"

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
