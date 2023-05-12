# BSD 3-Clause License
#
# Copyright (c) 2022-2023, Denis Bourgeois
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require "openstudio"

module OSut
  extend OSlg            #   DEBUG for devs; WARN/ERROR for users (bad OS input)

  TOL  = 0.01
  TOL2 = TOL * TOL
  DBG  = OSut::DEBUG     # mainly to flag invalid arguments to devs (buggy code)
  INF  = OSut::INFO      #                            not currently used in OSut
  WRN  = OSut::WARN      #   WARN users of 'iffy' .osm inputs (yet not critical)
  ERR  = OSut::ERROR     #     flag invalid .osm inputs (then exit via 'return')
  FTL  = OSut::FATAL     #                            not currently used in OSut
  NS   = "nameString"    #                OpenStudio IdfObject nameString method
  HEAD = 2.032           # standard 80" door
  SILL = 0.762           # standard 30" window sill

  # This first set of utilities (~750 lines) help distinguishing spaces that
  # are directly vs indirectly CONDITIONED, vs SEMI-HEATED. The solution here
  # relies as much as possible on space conditioning categories found in
  # standards like ASHRAE 90.1 and energy codes like the Canadian NECB editions.
  # Both documents share many similarities, regardless of nomenclature. There
  # are however noticeable differences between approaches on how a space is
  # tagged as falling into one of the aforementioned categories. First, an
  # overview of 90.1 requirements, with some minor edits for brevity/emphasis:
  #
  # www.pnnl.gov/main/publications/external/technical_reports/PNNL-26917.pdf
  #
  #   3.2.1. General Information - SPACE CONDITIONING CATEGORY
  #
  #     - CONDITIONED space: an ENCLOSED space that has a heating and/or
  #       cooling system of sufficient size to maintain temperatures suitable
  #       for HUMAN COMFORT:
  #         - COOLED: cooled by a system >= 10 W/m2
  #         - HEATED: heated by a system, e.g. >= 50 W/m2 in Climate Zone CZ-7
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
  # to ASHRAE 90.1 (e.g. heating and/or cooling based, no distinction for
  # INDIRECTLY conditioned spaces like plenums).
  #
  # SEMI-HEATED spaces are also a defined NECB term, but again the distinction
  # is based on desired/intended design space setpoint temperatures - not
  # system sizing criteria. No further treatment is implemented here to
  # distinguish SEMI-HEATED from CONDITIONED spaces.
  #
  # The single NECB criterion distinguishing UNCONDITIONED ENCLOSED spaces
  # (such as vestibules) from UNENCLOSED spaces (such as attics) remains the
  # intention to ventilate - or rather to what degree. Regardless, the methods
  # here are designed to process both classifications in the same way, namely by
  # focusing on adjacent surfaces to CONDITIONED (or SEMI-HEATED) spaces as part
  # of the building envelope.

  # In light of the above, methods here are designed without a priori knowledge
  # of explicit system sizing choices or access to iterative autosizing
  # processes. As discussed in greater detail elswhere, methods are developed to
  # rely on zoning info and/or "intended" temperature setpoints.
  #
  # For an OpenStudio model in an incomplete or preliminary state, e.g. holding
  # fully-formed ENCLOSED spaces without thermal zoning information or setpoint
  # temperatures (early design stage assessments of form, porosity or envelope),
  # all OpenStudio spaces will be considered CONDITIONED, presuming setpoints of
  # ~21°C (heating) and ~24°C (cooling).
  #
  # If ANY valid space/zone-specific temperature setpoints are found in the
  # OpenStudio model, spaces/zones WITHOUT valid heating or cooling setpoints
  # are considered as UNCONDITIONED or UNENCLOSED spaces (like attics), or
  # INDIRECTLY CONDITIONED spaces (like plenums), see "plenum?" method.

  ##
  # Return min & max values of a schedule (ruleset).
  #
  # @param sched [OpenStudio::Model::ScheduleRuleset] schedule
  #
  # @return [Hash] min: (Float), max: (Float)
  # @return [Hash] min: nil, max: nil (if invalid input)
  def scheduleRulesetMinMax(sched = nil)
    # Largely inspired from David Goldwasser's
    # "schedule_ruleset_annual_min_max_value":
    #
    # github.com/NREL/openstudio-standards/blob/
    # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
    # standards/Standards.ScheduleRuleset.rb#L124
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::ScheduleRuleset
    res = { min: nil, max: nil }

    return invalid("sched", mth, 1, DBG, res)     unless sched.respond_to?(NS)

    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)

    profiles = []
    profiles << sched.defaultDaySchedule
    sched.scheduleRules.each { |rule| profiles << rule.daySchedule }

    profiles.each do |profile|
      id = profile.nameString

      profile.values.each do |val|
        ok = val.is_a?(Numeric)
        log(WRN, "Skipping non-numeric value in '#{id}' (#{mth})")     unless ok
        next                                                           unless ok

        res[:min] = val unless res[:min]
        res[:min] = val     if res[:min] > val
        res[:max] = val unless res[:max]
        res[:max] = val     if res[:max] < val
      end
    end

    valid = res[:min] && res[:max]
    log(ERR, "Invalid MIN/MAX in '#{id}' (#{mth})") unless valid

    res
  end

  ##
  # Return min & max values of a schedule (constant).
  #
  # @param sched [OpenStudio::Model::ScheduleConstant] schedule
  #
  # @return [Hash] min: (Float), max: (Float)
  # @return [Hash] min: nil, max: nil (if invalid input)
  def scheduleConstantMinMax(sched = nil)
    # Largely inspired from David Goldwasser's
    # "schedule_constant_annual_min_max_value":
    #
    # github.com/NREL/openstudio-standards/blob/
    # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
    # standards/Standards.ScheduleConstant.rb#L21
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::ScheduleConstant
    res = { min: nil, max: nil }

    return invalid("sched", mth, 1, DBG, res)     unless sched.respond_to?(NS)

    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)

    valid = sched.value.is_a?(Numeric)
    mismatch("'#{id}' value", sched.value, Numeric, mth, ERR, res) unless valid
    res[:min] = sched.value
    res[:max] = sched.value

    res
  end

  ##
  # Return min & max values of a schedule (compact).
  #
  # @param sched [OpenStudio::Model::ScheduleCompact] schedule
  #
  # @return [Hash] min: (Float), max: (Float)
  # @return [Hash] min: nil, max: nil (if invalid input)
  def scheduleCompactMinMax(sched = nil)
    # Largely inspired from Andrew Parker's
    # "schedule_compact_annual_min_max_value":
    #
    # github.com/NREL/openstudio-standards/blob/
    # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
    # standards/Standards.ScheduleCompact.rb#L8
    mth      = "OSut::#{__callee__}"
    cl       = OpenStudio::Model::ScheduleCompact
    vals     = []
    prev_str = ""
    res      = { min: nil, max: nil }

    return invalid("sched", mth, 1, DBG, res)     unless sched.respond_to?(NS)

    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)

    sched.extensibleGroups.each do |eg|
      if prev_str.include?("until")
        vals << eg.getDouble(0).get unless eg.getDouble(0).empty?
      end

      str = eg.getString(0)
      prev_str = str.get.downcase unless str.empty?
    end

    return empty("'#{id}' values", mth, ERR, res) if vals.empty?

    ok = vals.min.is_a?(Numeric) && vals.max.is_a?(Numeric)
    log(ERR, "Non-numeric values in '#{id}' (#{mth})")                 unless ok
    return res                                                         unless ok

    res[:min] = vals.min
    res[:max] = vals.max

    res
  end

  ##
  # Return min & max values for schedule (interval).
  #
  # @param sched [OpenStudio::Model::ScheduleInterval] schedule
  #
  # @return [Hash] min: (Float), max: (Float)
  # @return [Hash] min: nil, max: nil (if invalid input)
  def scheduleIntervalMinMax(sched = nil)
    mth  = "OSut::#{__callee__}"
    cl   = OpenStudio::Model::ScheduleInterval
    vals = []
    res  = { min: nil, max: nil }

    return invalid("sched", mth, 1, DBG, res)     unless sched.respond_to?(NS)

    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)

    vals = sched.timeSeries.values
    ok   = vals.min.is_a?(Numeric) && vals.max.is_a?(Numeric)
    log(ERR, "Non-numeric values in '#{id}' (#{mth})")                 unless ok
    return res                                                         unless ok

    res[:min] = vals.min
    res[:max] = vals.max

    res
  end

  ##
  # Return max zone heating temperature schedule setpoint [°C] and whether
  # zone has active dual setpoint thermostat.
  #
  # @param zone [OpenStudio::Model::ThermalZone] a thermal zone
  #
  # @return [Hash] spt: (Float), dual: (Bool)
  # @return [Hash] spt: nil, dual: false (if invalid input)
  def maxHeatScheduledSetpoint(zone = nil)
    # Largely inspired from Parker & Marrec's "thermal_zone_heated?" procedure.
    # The solution here is a tad more relaxed to encompass SEMI-HEATED zones as
    # per Canadian NECB criteria (basically any space with at least 10 W/m2 of
    # installed heating equipement, i.e. below freezing in Canada).
    #
    # github.com/NREL/openstudio-standards/blob/
    # 58964222d25783e9da4ae292e375fb0d5c902aa5/lib/openstudio-standards/
    # standards/Standards.ThermalZone.rb#L910
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::ThermalZone
    res = { spt: nil, dual: false }

    return invalid("zone", mth, 1, DBG, res)     unless zone.respond_to?(NS)

    id = zone.nameString
    return mismatch(id, zone, cl, mth, DBG, res) unless zone.is_a?(cl)

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
        sched = equip.heatingSetpointTemperatureSchedule
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
          res[:spt] = max unless res[:spt]
          res[:spt] = max     if res[:spt] < max
        end
      end

      unless sched.to_ScheduleConstant.empty?
        sched = sched.to_ScheduleConstant.get
        max = scheduleConstantMinMax(sched)[:max]

        if max
          res[:spt] = max unless res[:spt]
          res[:spt] = max     if res[:spt] < max
        end
      end

      unless sched.to_ScheduleCompact.empty?
        sched = sched.to_ScheduleCompact.get
        max = scheduleCompactMinMax(sched)[:max]

        if max
          res[:spt] = max unless res[:spt]
          res[:spt] = max     if res[:spt] < max
        end
      end
    end

    return res if zone.thermostat.empty?

    tstat       = zone.thermostat.get
    res[:spt]   = nil

    unless tstat.to_ThermostatSetpointDualSetpoint.empty? &&
           tstat.to_ZoneControlThermostatStagedDualSetpoint.empty?

      unless tstat.to_ThermostatSetpointDualSetpoint.empty?
        tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      else
        tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
      end

      unless tstat.heatingSetpointTemperatureSchedule.empty?
        res[:dual] = true
        sched      = tstat.heatingSetpointTemperatureSchedule.get

        unless sched.to_ScheduleRuleset.empty?
          sched = sched.to_ScheduleRuleset.get
          max = scheduleRulesetMinMax(sched)[:max]

          if max
            res[:spt] = max unless res[:spt]
            res[:spt] = max     if res[:spt] < max
          end

          dd = sched.winterDesignDaySchedule

          unless dd.values.empty?
            res[:spt] = dd.values.max unless res[:spt]
            res[:spt] = dd.values.max     if res[:spt] < dd.values.max
          end
        end

        unless sched.to_ScheduleConstant.empty?
          sched = sched.to_ScheduleConstant.get
          max = scheduleConstantMinMax(sched)[:max]

          if max
            res[:spt] = max unless res[:spt]
            res[:spt] = max     if res[:spt] < max
          end
        end

        unless sched.to_ScheduleCompact.empty?
          sched = sched.to_ScheduleCompact.get
          max = scheduleCompactMinMax(sched)[:max]

          if max
            res[:spt] = max unless res[:spt]
            res[:spt] = max     if res[:spt] < max
          end
        end

        unless sched.to_ScheduleYear.empty?
          sched = sched.to_ScheduleYear.get

          sched.getScheduleWeeks.each do |week|
            next if week.winterDesignDaySchedule.empty?

            dd = week.winterDesignDaySchedule.get
            next unless dd.values.empty?

            res[:spt] = dd.values.max unless res[:spt]
            res[:spt] = dd.values.max     if res[:spt] < dd.values.max
          end
        end
      end
    end

    res
  end

  ##
  # Validate if model has zones with valid heating temperature setpoints.
  #
  # @param model [OpenStudio::Model::Model] a model
  #
  # @return [Bool] true if valid heating temperature setpoints
  # @return [Bool] false if invalid input
  def heatingTemperatureSetpoints?(model = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Model

    return mismatch("model", model, cl, mth, DBG, false) unless model.is_a?(cl)

    model.getThermalZones.each do |zone|
      return true if maxHeatScheduledSetpoint(zone)[:spt]
    end

    false
  end

  ##
  # Return min zone cooling temperature schedule setpoint [°C] and whether
  # zone has active dual setpoint thermostat.
  #
  # @param zone [OpenStudio::Model::ThermalZone] a thermal zone
  #
  # @return [Hash] spt: (Float), dual: (Bool)
  # @return [Hash] spt: nil, dual: false (if invalid input)
  def minCoolScheduledSetpoint(zone = nil)
    # Largely inspired from Parker & Marrec's "thermal_zone_cooled?" procedure.
    #
    # github.com/NREL/openstudio-standards/blob/
    # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
    # standards/Standards.ThermalZone.rb#L1058
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::ThermalZone
    res = { spt: nil, dual: false }

    return invalid("zone", mth, 1, DBG, res)     unless zone.respond_to?(NS)

    id = zone.nameString
    return mismatch(id, zone, cl, mth, DBG, res) unless zone.is_a?(cl)

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
          res[:spt] = min unless res[:spt]
          res[:spt] = min     if res[:spt] > min
        end
      end

      unless sched.to_ScheduleConstant.empty?
        sched = sched.to_ScheduleConstant.get
        min = scheduleConstantMinMax(sched)[:min]

        if min
          res[:spt] = min unless res[:spt]
          res[:spt] = min     if res[:spt] > min
        end
      end

      unless sched.to_ScheduleCompact.empty?
        sched = sched.to_ScheduleCompact.get
        min = scheduleCompactMinMax(sched)[:min]

        if min
          res[:spt] = min unless res[:spt]
          res[:spt] = min     if res[:spt] > min
        end
      end
    end

    return res if zone.thermostat.empty?

    tstat       = zone.thermostat.get
    res[:spt]   = nil

    unless tstat.to_ThermostatSetpointDualSetpoint.empty? &&
           tstat.to_ZoneControlThermostatStagedDualSetpoint.empty?

      unless tstat.to_ThermostatSetpointDualSetpoint.empty?
        tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      else
        tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
      end

      unless tstat.coolingSetpointTemperatureSchedule.empty?
        res[:dual] = true
        sched      = tstat.coolingSetpointTemperatureSchedule.get

        unless sched.to_ScheduleRuleset.empty?
          sched = sched.to_ScheduleRuleset.get
          min = scheduleRulesetMinMax(sched)[:min]

          if min
            res[:spt] = min unless res[:spt]
            res[:spt] = min     if res[:spt] > min
          end

          dd = sched.summerDesignDaySchedule

          unless dd.values.empty?
            res[:spt] = dd.values.min unless res[:spt]
            res[:spt] = dd.values.min     if res[:spt] > dd.values.min
          end
        end

        unless sched.to_ScheduleConstant.empty?
          sched = sched.to_ScheduleConstant.get
          min = scheduleConstantMinMax(sched)[:min]

          if min
            res[:spt] = min unless res[:spt]
            res[:spt] = min     if res[:spt] > min
          end
        end

        unless sched.to_ScheduleCompact.empty?
          sched = sched.to_ScheduleCompact.get
          min = scheduleCompactMinMax(sched)[:min]

          if min
            res[:spt] = min unless res[:spt]
            res[:spt] = min     if res[:spt] > min
          end
        end

        unless sched.to_ScheduleYear.empty?
          sched = sched.to_ScheduleYear.get

          sched.getScheduleWeeks.each do |week|
            next if week.summerDesignDaySchedule.empty?

            dd = week.summerDesignDaySchedule.get
            next unless dd.values.empty?

            res[:spt] = dd.values.min unless res[:spt]
            res[:spt] = dd.values.min     if res[:spt] > dd.values.min
          end
        end
      end
    end

    res
  end

  ##
  # Validate if model has zones with valid cooling temperature setpoints.
  #
  # @param model [OpenStudio::Model::Model] a model
  #
  # @return [Bool] true if valid cooling temperature setpoints
  # @return [Bool] false if invalid input
  def coolingTemperatureSetpoints?(model = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Model

    return mismatch("model", model, cl, mth, DBG, false)  unless model.is_a?(cl)

    model.getThermalZones.each do |zone|
      return true if minCoolScheduledSetpoint(zone)[:spt]
    end

    false
  end

  ##
  # Validate if model has zones with HVAC air loops.
  #
  # @param model [OpenStudio::Model::Model] a model
  #
  # @return [Bool] true if model has one or more HVAC air loops
  # @return [Bool] false if invalid input
  def airLoopsHVAC?(model = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Model

    return mismatch("model", model, cl, mth, DBG, false)  unless model.is_a?(cl)

    model.getThermalZones.each do |zone|
      next                                           if zone.canBePlenum
      return true                                unless zone.airLoopHVACs.empty?
      return true                                    if zone.isPlenum
    end

    false
  end

  ##
  # Validate whether space should be processed as a plenum.
  #
  # @param space [OpenStudio::Model::Space] a space
  # @param loops [Bool] true if model has airLoopHVAC object(s)
  # @param setpoints [Bool] true if model has valid temperature setpoints
  #
  # @return [Bool] true if should be tagged as plenum
  # @return [Bool] false if invalid input
  def plenum?(space = nil, loops = nil, setpoints = nil)
    # Largely inspired from NREL's "space_plenum?" procedure:
    #
    # github.com/NREL/openstudio-standards/blob/
    # 58964222d25783e9da4ae292e375fb0d5c902aa5/lib/openstudio-standards/
    # standards/Standards.Space.rb#L1384
    #
    # A space may be tagged as a plenum if:
    #
    # CASE A: its zone's "isPlenum" == true (SDK method) for a fully-developed
    #         OpenStudio model (complete with HVAC air loops); OR
    #
    # CASE B: (IN ABSENCE OF HVAC AIRLOOPS) if it's excluded from a building's
    #         total floor area yet linked to a zone holding an 'inactive'
    #         thermostat, i.e. can't extract valid setpoints; OR
    #
    # CASE C: (IN ABSENCE OF HVAC AIRLOOPS & VALID SETPOINTS) it has "plenum"
    #         (case insensitive) as a spacetype (or as a spacetype's
    #         'standards spacetype').
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Space

    return invalid("space", mth, 1, DBG, false)     unless space.respond_to?(NS)

    id = space.nameString
    return mismatch(id, space, cl, mth, DBG, false) unless space.is_a?(cl)

    valid = loops == true || loops == false
    return invalid("loops", mth, 2, DBG, false)     unless valid

    valid = setpoints == true || setpoints == false
    return invalid("setpoints", mth, 3, DBG, false) unless valid

    unless space.thermalZone.empty?
      zone = space.thermalZone.get
      return zone.isPlenum if loops                                          # A

      if setpoints
        heat = maxHeatScheduledSetpoint(zone)
        cool = minCoolScheduledSetpoint(zone)
        return false if heat[:spt] || cool[:spt]          # directly conditioned
        return heat[:dual] || cool[:dual] unless space.partofTotalFloorArea  # B
        return false
      end
    end

    unless space.spaceType.empty?
      type = space.spaceType.get
      return type.nameString.downcase == "plenum"                            # C
    end

    unless type.standardsSpaceType.empty?
      type = type.standardsSpaceType.get
      return type.downcase == "plenum"                                       # C
    end

    false
  end

  ##
  # Generate an HVAC availability schedule.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param avl [String] seasonal availability choice (optional, default "ON")
  #
  # @return [OpenStudio::Model::Schedule] HVAC availability sched
  # @return [NilClass] if invalid input
  def availabilitySchedule(model = nil, avl = "")
    mth    = "OSut::#{__callee__}"
    cl     = OpenStudio::Model::Model
    limits = nil

    return mismatch("model", model, cl, mth)       unless model.is_a?(cl)
    return invalid("availability", avl, 2, mth)    unless avl.respond_to?(:to_s)

    # Either fetch availability ScheduleTypeLimits object, or create one.
    model.getScheduleTypeLimitss.each do |l|
      break if limits
      next if l.lowerLimitValue.empty?
      next if l.upperLimitValue.empty?
      next if l.numericType.empty?
      next unless l.lowerLimitValue.get.to_i == 0
      next unless l.upperLimitValue.get.to_i == 1
      next unless l.numericType.get.downcase == "discrete"
      next unless l.unitType.downcase == "availability"
      next unless l.nameString.downcase == "hvac operation scheduletypelimits"

      limits = l
    end

    unless limits
      limits = OpenStudio::Model::ScheduleTypeLimits.new(model)
      limits.setName("HVAC Operation ScheduleTypeLimits")
      limits.setLowerLimitValue(0)
      limits.setUpperLimitValue(1)
      limits.setNumericType("Discrete")
      limits.setUnitType("Availability")
    end

    time = OpenStudio::Time.new(0,24)
    secs = time.totalSeconds
    on   = OpenStudio::Model::ScheduleDay.new(model, 1)
    off  = OpenStudio::Model::ScheduleDay.new(model, 0)

    # Seasonal availability start/end dates.
    year  = model.yearDescription
    return  empty("yearDescription", mth, ERR) if year.empty?

    year  = year.get
    may01 = year.makeDate(OpenStudio::MonthOfYear.new("May"),  1)
    oct31 = year.makeDate(OpenStudio::MonthOfYear.new("Oct"), 31)

    case avl.to_s.downcase
    when "winter"             # available from November 1 to April 30 (6 months)
      val = 1
      sch = off
      nom = "WINTER Availability SchedRuleset"
      dft = "WINTER Availability dftDaySched"
      tag = "May-Oct WINTER Availability SchedRule"
      day = "May-Oct WINTER SchedRule Day"
    when "summer"                # available from May 1 to October 31 (6 months)
      val = 0
      sch = on
      nom = "SUMMER Availability SchedRuleset"
      dft = "SUMMER Availability dftDaySched"
      tag = "May-Oct SUMMER Availability SchedRule"
      day = "May-Oct SUMMER SchedRule Day"
    when "off"                                                 # never available
      val = 0
      sch = on
      nom = "OFF Availability SchedRuleset"
      dft = "OFF Availability dftDaySched"
      tag = ""
      day = ""
    else                                                      # always available
      val = 1
      sch = on
      nom = "ON Availability SchedRuleset"
      dft = "ON Availability dftDaySched"
      tag = ""
      day = ""
    end

    # Fetch existing schedule.
    ok = true
    schedule = model.getScheduleByName(nom)

    unless schedule.empty?
      schedule = schedule.get.to_ScheduleRuleset

      unless schedule.empty?
        schedule = schedule.get
        default = schedule.defaultDaySchedule
        ok = ok && default.nameString           == dft
        ok = ok && default.times.size           == 1
        ok = ok && default.values.size          == 1
        ok = ok && default.times.first          == time
        ok = ok && default.values.first         == val
        rules = schedule.scheduleRules
        ok = ok && (rules.size == 0 || rules.size == 1)

        if rules.size == 1
          rule = rules.first
          ok = ok && rule.nameString            == tag
          ok = ok && !rule.startDate.empty?
          ok = ok && !rule.endDate.empty?
          ok = ok && rule.startDate.get         == may01
          ok = ok && rule.endDate.get           == oct31
          ok = ok && rule.applyAllDays

          d = rule.daySchedule
          ok = ok && d.nameString               == day
          ok = ok && d.times.size               == 1
          ok = ok && d.values.size              == 1
          ok = ok && d.times.first.totalSeconds == secs
          ok = ok && d.values.first.to_i        != val
        end

        return schedule if ok
      end
    end

    schedule = OpenStudio::Model::ScheduleRuleset.new(model)
    schedule.setName(nom)
    ok = schedule.setScheduleTypeLimits(limits)
    log(ERR, "'#{nom}': Can't set schedule type limits (#{mth})")      unless ok
    return nil                                                         unless ok

    ok = schedule.defaultDaySchedule.addValue(time, val)
    log(ERR, "'#{nom}': Can't set default day schedule (#{mth})")      unless ok
    return nil                                                         unless ok

    schedule.defaultDaySchedule.setName(dft)

    unless tag.empty?
      rule = OpenStudio::Model::ScheduleRule.new(schedule, sch)
      rule.setName(tag)
      ok = rule.setStartDate(may01)
      log(ERR, "'#{tag}': Can't set start date (#{mth})")              unless ok
      return nil                                                       unless ok

      ok = rule.setEndDate(oct31)
      log(ERR, "'#{tag}': Can't set end date (#{mth})")                unless ok
      return nil                                                       unless ok

      ok = rule.setApplyAllDays(true)
      log(ERR, "'#{tag}': Can't apply to all days (#{mth})")           unless ok
      return nil                                                       unless ok

      rule.daySchedule.setName(day)
    end

    schedule
  end

  ##
  # Validate if default construction set holds a base construction.
  #
  # @param set [OpenStudio::Model::DefaultConstructionSet] a default set
  # @param bse [OpensStudio::Model::ConstructionBase] a construction base
  # @param gr [Bool] true if ground-facing surface
  # @param ex [Bool] true if exterior-facing surface
  # @param typ [String] a surface type
  #
  # @return [Bool] true if default construction set holds construction
  # @return [Bool] false if invalid input
  def holdsConstruction?(set = nil, bse = nil, gr = false, ex = false, typ = "")
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::DefaultConstructionSet
    cl2 = OpenStudio::Model::ConstructionBase

    return invalid("set", mth, 1, DBG, false)         unless set.respond_to?(NS)

    id = set.nameString
    return mismatch(id, set, cl1, mth, DBG, false)    unless set.is_a?(cl1)
    return invalid("base", mth, 2, DBG, false)        unless bse.respond_to?(NS)

    id = bse.nameString
    return mismatch(id, bse, cl2, mth, DBG, false)    unless bse.is_a?(cl2)

    valid = gr == true || gr == false
    return invalid("ground", mth, 3, DBG, false)      unless valid

    valid = ex == true || ex == false
    return invalid("exterior", mth, 4, DBG, false)    unless valid

    valid = typ.respond_to?(:to_s)
    return invalid("surface typ", mth, 4, DBG, false) unless valid

    type = typ.to_s.downcase
    valid = type == "floor" || type == "wall" || type == "roofceiling"
    return invalid("surface type", mth, 5, DBG, false) unless valid

    constructions = nil

    if gr
      unless set.defaultGroundContactSurfaceConstructions.empty?
        constructions = set.defaultGroundContactSurfaceConstructions.get
      end
    elsif ex
      unless set.defaultExteriorSurfaceConstructions.empty?
        constructions = set.defaultExteriorSurfaceConstructions.get
      end
    else
      unless set.defaultInteriorSurfaceConstructions.empty?
        constructions = set.defaultInteriorSurfaceConstructions.get
      end
    end

    return false unless constructions

    case type
    when "roofceiling"
      unless constructions.roofCeilingConstruction.empty?
        construction = constructions.roofCeilingConstruction.get
        return true if construction == bse
      end
    when "floor"
      unless constructions.floorConstruction.empty?
        construction = constructions.floorConstruction.get
        return true if construction == bse
      end
    else
      unless constructions.wallConstruction.empty?
        construction = constructions.wallConstruction.get
        return true if construction == bse
      end
    end

    false
  end

  ##
  # Return a surface's default construction set.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param s [OpenStudio::Model::Surface] a surface
  #
  # @return [OpenStudio::Model::DefaultConstructionSet] default set
  # @return [NilClass] if invalid input
  def defaultConstructionSet(model = nil, s = nil)
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::Model
    cl2 = OpenStudio::Model::Surface

    return mismatch("model", model, cl1, mth)           unless model.is_a?(cl1)
    return invalid("s", mth, 2)                         unless s.respond_to?(NS)

    id   = s.nameString
    return mismatch(id, s, cl2, mth)                    unless s.is_a?(cl2)

    ok = s.isConstructionDefaulted
    log(ERR, "'#{id}' construction not defaulted (#{mth})")            unless ok
    return nil                                                         unless ok
    return empty("'#{id}' construction", mth, ERR)      if s.construction.empty?

    base = s.construction.get
    return empty("'#{id}' space", mth, ERR)             if s.space.empty?

    space = s.space.get
    type = s.surfaceType
    ground = false
    exterior = false

    if s.isGroundSurface
      ground = true
    elsif s.outsideBoundaryCondition.downcase == "outdoors"
      exterior = true
    end

    unless space.defaultConstructionSet.empty?
      set = space.defaultConstructionSet.get
      return set        if holdsConstruction?(set, base, ground, exterior, type)
    end

    unless space.spaceType.empty?
      spacetype = space.spaceType.get

      unless spacetype.defaultConstructionSet.empty?
        set = spacetype.defaultConstructionSet.get
        return set      if holdsConstruction?(set, base, ground, exterior, type)
      end
    end

    unless space.buildingStory.empty?
      story = space.buildingStory.get

      unless story.defaultConstructionSet.empty?
        set = story.defaultConstructionSet.get
        return set      if holdsConstruction?(set, base, ground, exterior, type)
      end
    end

    building = model.getBuilding

    unless building.defaultConstructionSet.empty?
      set = building.defaultConstructionSet.get
      return set        if holdsConstruction?(set, base, ground, exterior, type)
    end

    nil
  end

  ##
  # Validate if every material in a layered construction is standard & opaque.
  #
  # @param lc [OpenStudio::LayeredConstruction] a layered construction
  #
  # @return [Bool] true if all layers are valid
  # @return [Bool] false if invalid input
  def standardOpaqueLayers?(lc = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::LayeredConstruction

    return invalid("lc", mth, 1, DBG, false) unless lc.respond_to?(NS)
    return mismatch(lc.nameString, lc, cl, mth, DBG, false) unless lc.is_a?(cl)

    lc.layers.each { |m| return false if m.to_StandardOpaqueMaterial.empty? }

    true
  end

  ##
  # Total (standard opaque) layered construction thickness (in m).
  #
  # @param lc [OpenStudio::LayeredConstruction] a layered construction
  #
  # @return [Float] total layered construction thickness
  # @return [Float] 0 if invalid input
  def thickness(lc = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::LayeredConstruction

    return invalid("lc", mth, 1, DBG, 0.0)             unless lc.respond_to?(NS)

    id = lc.nameString
    return mismatch(id, lc, cl, mth, DBG, 0.0)         unless lc.is_a?(cl)

    ok = standardOpaqueLayers?(lc)
    log(ERR, "'#{id}' holds non-StandardOpaqueMaterial(s) (#{mth})")   unless ok
    return 0.0                                                         unless ok

    thickness = 0.0
    lc.layers.each { |m| thickness += m.thickness }

    thickness
  end

  ##
  # Return total air film resistance for fenestration.
  #
  # @param usi [Float] a fenestrated construction's U-factor (W/m2•K)
  #
  # @return [Float] total air film resistance in m2•K/W (0.1216 if errors)
  def glazingAirFilmRSi(usi = 5.85)
    # The sum of thermal resistances of calculated exterior and interior film
    # coefficients under standard winter conditions are taken from:
    #
    #   https://bigladdersoftware.com/epx/docs/9-6/engineering-reference/
    #   window-calculation-module.html#simple-window-model
    #
    # These remain acceptable approximations for flat windows, yet likely
    # unsuitable for subsurfaces with curved or projecting shapes like domed
    # skylights. The solution here is considered an adequate fix for reporting,
    # awaiting eventual OpenStudio (and EnergyPlus) upgrades to report NFRC 100
    # (or ISO) air film resistances under standard winter conditions.
    #
    # For U-factors above 8.0 W/m2•K (or invalid input), the function returns
    # 0.1216 m2•K/W, which corresponds to a construction with a single glass
    # layer thickness of 2mm & k = ~0.6 W/m.K.
    #
    # The EnergyPlus Engineering calculations were designed for vertical windows
    # - not horizontal, slanted or domed surfaces - use with caution.
    mth = "OSut::#{__callee__}"
    cl  = Numeric

    return mismatch("usi", usi, cl, mth, DBG, 0.1216)  unless usi.is_a?(cl)
    return invalid("usi", mth, 1, WRN, 0.1216)             if usi > 8.0
    return negative("usi", mth, WRN, 0.1216)               if usi < 0
    return zero("usi", mth, WRN, 0.1216)                   if usi.abs < TOL

    rsi = 1 / (0.025342 * usi + 29.163853)   # exterior film, next interior film

    return rsi + 1 / (0.359073 * Math.log(usi) + 6.949915) if usi < 5.85
    return rsi + 1 / (1.788041 * usi - 2.886625)
  end

  ##
  # Return a construction's 'standard calc' thermal resistance (with air films).
  #
  # @param lc [OpenStudio::Model::LayeredConstruction] a layered construction
  # @param film [Float] thermal resistance of surface air films (m2•K/W)
  # @param t [Float] gas temperature (°C) (optional)
  #
  # @return [Float] calculated RSi at standard conditions (0 if error)
  def rsi(lc = nil, film = 0.0, t = 0.0)
    # This is adapted from BTAP's Material Module's "get_conductance" (P. Lopez)
    #
    #   https://github.com/NREL/OpenStudio-Prototype-Buildings/blob/
    #   c3d5021d8b7aef43e560544699fb5c559e6b721d/lib/btap/measures/
    #   btap_equest_converter/envelope.rb#L122
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::LayeredConstruction
    cl2 = Numeric

    return invalid("lc", mth, 1, DBG, 0.0)             unless lc.respond_to?(NS)

    id = lc.nameString

    return mismatch(id, lc, cl1, mth, DBG, 0.0)        unless lc.is_a?(cl1)
    return mismatch("film", film, cl2, mth, DBG, 0.0)  unless film.is_a?(cl2)
    return mismatch("temp K", t, cl2, mth, DBG, 0.0)   unless t.is_a?(cl2)

    t += 273.0                                             # °C to K
    return negative("temp K", mth, DBG, 0.0)               if t < 0
    return negative("film", mth, DBG, 0.0)                 if film < 0

    rsi = film

    lc.layers.each do |m|
      # Fenestration materials first (ignoring shades, screens, etc.)
      empty = m.to_SimpleGlazing.empty?
      return 1 / m.to_SimpleGlazing.get.uFactor                     unless empty

      empty = m.to_StandardGlazing.empty?
      rsi += m.to_StandardGlazing.get.thermalResistance             unless empty
      empty = m.to_RefractionExtinctionGlazing.empty?
      rsi += m.to_RefractionExtinctionGlazing.get.thermalResistance unless empty
      empty = m.to_Gas.empty?
      rsi += m.to_Gas.get.getThermalResistance(t)                   unless empty
      empty = m.to_GasMixture.empty?
      rsi += m.to_GasMixture.get.getThermalResistance(t)            unless empty

      # Opaque materials next.
      empty = m.to_StandardOpaqueMaterial.empty?
      rsi += m.to_StandardOpaqueMaterial.get.thermalResistance      unless empty
      empty = m.to_MasslessOpaqueMaterial.empty?
      rsi += m.to_MasslessOpaqueMaterial.get.thermalResistance      unless empty
      empty = m.to_RoofVegetation.empty?
      rsi += m.to_RoofVegetation.get.thermalResistance              unless empty
      empty = m.to_AirGap.empty?
      rsi += m.to_AirGap.get.thermalResistance                      unless empty
    end

    rsi
  end

  ##
  # Identify a layered construction's (opaque) insulating layer. The method
  # returns a 3-keyed hash ... :index (insulating layer index within layered
  # construction), :type (standard: or massless: material type), and
  # :r (material thermal resistance in m2•K/W).
  #
  # @param lc [OpenStudio::Model::LayeredConstruction] a layered construction
  #
  # @return [Hash] index: (Integer), type: (:standard or :massless), r: (Float)
  # @return [Hash] index: nil, type: nil, r: 0 (if invalid input)
  def insulatingLayer(lc = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::LayeredConstruction
    res = { index: nil, type: nil, r: 0.0 }
    i   = 0                                                           # iterator

    return invalid("lc", mth, 1, DBG, res)             unless lc.respond_to?(NS)

    id   = lc.nameString
    return mismatch(id, lc, cl1, mth, DBG, res)        unless lc.is_a?(cl)

    lc.layers.each do |m|
      unless m.to_MasslessOpaqueMaterial.empty?
        m             = m.to_MasslessOpaqueMaterial.get

        if m.thermalResistance < 0.001 || m.thermalResistance < res[:r]
          i += 1
          next
        else
          res[:r    ] = m.thermalResistance
          res[:index] = i
          res[:type ] = :massless
        end
      end

      unless m.to_StandardOpaqueMaterial.empty?
        m             = m.to_StandardOpaqueMaterial.get
        k             = m.thermalConductivity
        d             = m.thickness

        if d < 0.003 || k > 3.0 || d / k < res[:r]
          i += 1
          next
        else
          res[:r    ] = d / k
          res[:index] = i
          res[:type ] = :standard
        end
      end

      i += 1
    end

    res
  end

  ##
  # Return OpenStudio site/space transformation & rotation angle [0,2PI) rads.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param group [OpenStudio::Model::PlanarSurfaceGroup] a group
  #
  # @return [Hash] t: (OpenStudio::Transformation), r: Float
  # @return [Hash] t: nil, r: nil (if invalid input)
  def transforms(model = nil, group = nil)
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::Model
    cl2 = OpenStudio::Model::PlanarSurfaceGroup
    res = { t: nil, r: nil }

    return mismatch("model", model, cl1, mth, DBG, res) unless model.is_a?(cl1)
    return invalid("group", mth, 2, DBG, res) unless group.respond_to?(NS)

    id = group.nameString
    return mismatch(id, group, cl2, mth, DBG, res) unless group.is_a?(cl2)

    res[:t] = group.siteTransformation
    res[:r] = group.directionofRelativeNorth + model.getBuilding.northAxis

    res
  end

  ##
  # Return a scalar product of an OpenStudio Vector3d.
  #
  # @param v [OpenStudio::Vector3d] a vector
  # @param m [Float] a scalar
  #
  # @return [OpenStudio::Vector3d] modified vector
  # @return [OpenStudio::Vector3d] provided (or empty) vector if invalid input
  def scalar(v = OpenStudio::Vector3d.new(0,0,0), m = 0)
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Vector3d
    cl2 = Numeric

    return mismatch("vector", v, cl1, mth, DBG, v) unless v.is_a?(cl1)
    return mismatch("x",    v.x, cl2, mth, DBG, v) unless v.x.respond_to?(:to_f)
    return mismatch("y",    v.y, cl2, mth, DBG, v) unless v.y.respond_to?(:to_f)
    return mismatch("z",    v.z, cl2, mth, DBG, v) unless v.z.respond_to?(:to_f)
    return mismatch("m",      m, cl2, mth, DBG, v) unless m.respond_to?(:to_f)

    OpenStudio::Vector3d.new(m * v.x, m * v.y, m * v.z)
  end

  ##
  # Flatten OpenStudio 3D points vs Z-axis (Z=0).
  #
  # @param pts [Array] an OpenStudio Point3D array/vector
  #
  # @return [Array] flattened OpenStudio 3D points
  def flatZ(pts = nil)
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Point3dVector
    cl2 = OpenStudio::Point3d
    v   = OpenStudio::Point3dVector.new

    valid = pts.is_a?(cl1) || pts.is_a?(Array)
    return mismatch("points", pts, cl1, mth, DBG, v)      unless valid

    pts.each { |pt| mismatch("pt", pt, cl2, mth, ERR, v)  unless pt.is_a?(cl2) }
    pts.each { |pt| v << OpenStudio::Point3d.new(pt.x, pt.y, 0) }

    v
  end

  ##
  # Validate whether 1st OpenStudio convex polygon fits in 2nd convex polygon.
  #
  # @param p1 [OpenStudio::Point3dVector] or Point3D array of polygon #1
  # @param p2 [OpenStudio::Point3dVector] or Point3D array of polygon #2
  # @param id1 [String] polygon #1 identifier (optional)
  # @param id2 [String] polygon #2 identifier (optional)
  #
  # @return [Bool] true if 1st polygon fits entirely within the 2nd polygon
  # @return [Bool] false if invalid input
  def fits?(p1 = nil, p2 = nil, id1 = "", id2 = "")
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Point3dVector
    cl2 = OpenStudio::Point3d
    a   = false

    return invalid("id1", mth, 3, DBG, a) unless id1.respond_to?(:to_s)
    return invalid("id2", mth, 4, DBG, a) unless id2.respond_to?(:to_s)

    i1  = id1.to_s
    i2  = id2.to_s
    i1  = "poly1" if i1.empty?
    i2  = "poly2" if i2.empty?

    valid1 = p1.is_a?(cl1) || p1.is_a?(Array)
    valid2 = p2.is_a?(cl1) || p2.is_a?(Array)

    return mismatch(i1, p1, cl1, mth, DBG, a) unless valid1
    return mismatch(i2, p2, cl1, mth, DBG, a) unless valid2
    return empty(i1, mth, ERR, a)                 if p1.empty?
    return empty(i2, mth, ERR, a)                 if p2.empty?

    p1.each { |v| return mismatch(i1, v, cl2, mth, ERR, a) unless v.is_a?(cl2) }
    p2.each { |v| return mismatch(i2, v, cl2, mth, ERR, a) unless v.is_a?(cl2) }

    # XY-plane transformation matrix ... needs to be clockwise for boost.
    ft    = OpenStudio::Transformation.alignFace(p1)
    ft_p1 = flatZ( (ft.inverse * p1)         )
    return  false                                                if ft_p1.empty?

    cw    = OpenStudio.pointInPolygon(ft_p1.first, ft_p1, TOL)
    ft_p1 = flatZ( (ft.inverse * p1).reverse )               unless cw
    ft_p2 = flatZ( (ft.inverse * p2).reverse )               unless cw
    ft_p2 = flatZ( (ft.inverse * p2)         )                   if cw
    return  false                                                if ft_p2.empty?

    area1 = OpenStudio.getArea(ft_p1)
    area2 = OpenStudio.getArea(ft_p2)
    return  empty("#{i1} area", mth, ERR, a)                     if area1.empty?
    return  empty("#{i2} area", mth, ERR, a)                     if area2.empty?

    area1 = area1.get
    area2 = area2.get
    union = OpenStudio.join(ft_p1, ft_p2, TOL2)
    return  false                                                if union.empty?

    union = union.get
    area  = OpenStudio.getArea(union)
    return  empty("#{i1}:#{i2} union area", mth, ERR, a)         if area.empty?

    area = area.get

    return false                                     if area < TOL
    return true                                      if (area - area2).abs < TOL
    return false                                     if (area - area2).abs > TOL

    true
  end

  ##
  # Validate whether an OpenStudio polygon overlaps another.
  #
  # @param p1 [OpenStudio::Point3dVector] or Point3D array of polygon #1
  # @param p2 [OpenStudio::Point3dVector] or Point3D array of polygon #2
  # @param id1 [String] polygon #1 identifier (optional)
  # @param id2 [String] polygon #2 identifier (optional)
  #
  # @return Returns true if polygons overlaps (or either fits into the other)
  # @return [Bool] false if invalid input
  def overlaps?(p1 = nil, p2 = nil, id1 = "", id2 = "")
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Point3dVector
    cl2 = OpenStudio::Point3d
    a   = false

    return invalid("id1", mth, 3, DBG, a) unless id1.respond_to?(:to_s)
    return invalid("id2", mth, 4, DBG, a) unless id2.respond_to?(:to_s)

    i1 = id1.to_s
    i2 = id2.to_s
    i1 = "poly1" if i1.empty?
    i2 = "poly2" if i2.empty?

    valid1 = p1.is_a?(cl1) || p1.is_a?(Array)
    valid2 = p2.is_a?(cl1) || p2.is_a?(Array)

    return mismatch(i1, p1, cl1, mth, DBG, a) unless valid1
    return mismatch(i2, p2, cl1, mth, DBG, a) unless valid2
    return empty(i1, mth, ERR, a)                 if p1.empty?
    return empty(i2, mth, ERR, a)                 if p2.empty?

    p1.each { |v| return mismatch(i1, v, cl2, mth, ERR, a) unless v.is_a?(cl2) }
    p2.each { |v| return mismatch(i2, v, cl2, mth, ERR, a) unless v.is_a?(cl2) }

    # XY-plane transformation matrix ... needs to be clockwise for boost.
    ft    = OpenStudio::Transformation.alignFace(p1)
    ft_p1 = flatZ( (ft.inverse * p1)         )
    ft_p2 = flatZ( (ft.inverse * p2)         )
    return  false                                                if ft_p1.empty?
    return  false                                                if ft_p2.empty?

    cw    = OpenStudio.pointInPolygon(ft_p1.first, ft_p1, TOL)
    ft_p1 = flatZ( (ft.inverse * p1).reverse )               unless cw
    ft_p2 = flatZ( (ft.inverse * p2).reverse )               unless cw
    return  false                                                if ft_p1.empty?
    return  false                                                if ft_p2.empty?

    area1 = OpenStudio.getArea(ft_p1)
    area2 = OpenStudio.getArea(ft_p2)
    return  empty("#{i1} area", mth, ERR, a)                     if area1.empty?
    return  empty("#{i2} area", mth, ERR, a)                     if area2.empty?

    area1 = area1.get
    area2 = area2.get
    union = OpenStudio.join(ft_p1, ft_p2, TOL2)
    return  false                                                if union.empty?

    union = union.get
    area  = OpenStudio.getArea(union)
    return empty("#{i1}:#{i2} union area", mth, ERR, a)          if area.empty?

    area = area.get
    return false                                                 if area < TOL

    delta = (area - area1 - area2).abs
    return false                                                 if delta < TOL

    true
  end

  ##
  # Generate offset vertices (by width) for a 3- or 4-sided, convex polygon.
  #
  # @param p1 [OpenStudio::Point3dVector] OpenStudio Point3D vector/array
  # @param w [Float] offset width (min: 0.0254m)
  # @param v [Integer] OpenStudio SDK version, eg '321' for 'v3.2.1' (optional)
  #
  # @return [OpenStudio::Point3dVector] offset points if successful
  # @return [OpenStudio::Point3dVector] original points if invalid input
  def offset(p1 = [], w = 0, v = 0)
    mth   = "OSut::#{__callee__}"
    cl    = OpenStudio::Point3d
    vrsn  = OpenStudio.openStudioVersion.split(".").map(&:to_i).join.to_i

    valid = p1.is_a?(OpenStudio::Point3dVector) || p1.is_a?(Array)
    return  mismatch("pts", p1, cl1, mth, DBG, p1)  unless valid
    return  empty("pts", mth, ERR, p1)                  if p1.empty?

    valid = p1.size == 3 || p1.size == 4
    iv    = true if p1.size == 4
    return  invalid("pts", mth, 1, DBG, p1)         unless valid
    return  invalid("width", mth, 2, DBG, p1)       unless w.respond_to?(:to_f)

    w     = w.to_f
    return  p1                                          if w < 0.0254

    v     = v.to_i                                      if v.respond_to?(:to_i)
    v     = 0                                       unless v.respond_to?(:to_i)
    v     = vrsn                                        if v.zero?

    p1.each { |x| return mismatch("p", x, cl, mth, ERR, p1) unless x.is_a?(cl) }

    unless v < 340
      # XY-plane transformation matrix ... needs to be clockwise for boost.
      ft     = OpenStudio::Transformation::alignFace(p1)
      ft_pts = flatZ( (ft.inverse * p1) )
      return   p1                                       if ft_pts.empty?

      cw     = OpenStudio::pointInPolygon(ft_pts.first, ft_pts, TOL)
      ft_pts = flatZ( (ft.inverse * p1).reverse )   unless cw
      offset = OpenStudio.buffer(ft_pts, w, TOL)
      return   p1                                       if offset.empty?

      offset = offset.get
      offset =  ft * offset                             if cw
      offset = (ft * offset).reverse                unless cw

      pz = OpenStudio::Point3dVector.new
      offset.each { |o| pz << OpenStudio::Point3d.new(o.x, o.y, o.z ) }

      return pz
    else                                                  # brute force approach
      pz     = {}
      pz[:A] = {}
      pz[:B] = {}
      pz[:C] = {}
      pz[:D] = {}                                                          if iv

      pz[:A][:p] = OpenStudio::Point3d.new(p1[0].x, p1[0].y, p1[0].z)
      pz[:B][:p] = OpenStudio::Point3d.new(p1[1].x, p1[1].y, p1[1].z)
      pz[:C][:p] = OpenStudio::Point3d.new(p1[2].x, p1[2].y, p1[2].z)
      pz[:D][:p] = OpenStudio::Point3d.new(p1[3].x, p1[3].y, p1[3].z)      if iv

      pzAp = pz[:A][:p]
      pzBp = pz[:B][:p]
      pzCp = pz[:C][:p]
      pzDp = pz[:D][:p]                                                    if iv

      # Generate vector pairs, from next point & from previous point.
      # :f_n : "from next"
      # :f_p : "from previous"
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
      pz[:A][:f_n] = pzAp - pzBp
      pz[:A][:f_p] = pzAp - pzCp                                       unless iv
      pz[:A][:f_p] = pzAp - pzDp                                           if iv

      pz[:B][:f_n] = pzBp - pzCp
      pz[:B][:f_p] = pzBp - pzAp

      pz[:C][:f_n] = pzCp - pzAp                                       unless iv
      pz[:C][:f_n] = pzCp - pzDp                                           if iv
      pz[:C][:f_p] = pzCp - pzBp

      pz[:D][:f_n] = pzDp - pzAp                                           if iv
      pz[:D][:f_p] = pzDp - pzCp                                           if iv

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
      pz[:A][:pl_f_n] = OpenStudio::Plane.new(pzAp, pz[:A][:f_n])
      pz[:A][:pl_f_p] = OpenStudio::Plane.new(pzAp, pz[:A][:f_p])

      pz[:B][:pl_f_n] = OpenStudio::Plane.new(pzBp, pz[:B][:f_n])
      pz[:B][:pl_f_p] = OpenStudio::Plane.new(pzBp, pz[:B][:f_p])

      pz[:C][:pl_f_n] = OpenStudio::Plane.new(pzCp, pz[:C][:f_n])
      pz[:C][:pl_f_p] = OpenStudio::Plane.new(pzCp, pz[:C][:f_p])

      pz[:D][:pl_f_n] = OpenStudio::Plane.new(pzDp, pz[:D][:f_n])          if iv
      pz[:D][:pl_f_p] = OpenStudio::Plane.new(pzDp, pz[:D][:f_p])          if iv

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
      pz[:A][:p_n_pl] = pz[:A][:pl_f_n].project(pz[:A][:p] + pz[:A][:f_p])
      pz[:A][:n_p_pl] = pz[:A][:pl_f_p].project(pz[:A][:p] + pz[:A][:f_n])

      pz[:B][:p_n_pl] = pz[:B][:pl_f_n].project(pz[:B][:p] + pz[:B][:f_p])
      pz[:B][:n_p_pl] = pz[:B][:pl_f_p].project(pz[:B][:p] + pz[:B][:f_n])

      pz[:C][:p_n_pl] = pz[:C][:pl_f_n].project(pz[:C][:p] + pz[:C][:f_p])
      pz[:C][:n_p_pl] = pz[:C][:pl_f_p].project(pz[:C][:p] + pz[:C][:f_n])

      pz[:D][:p_n_pl] = pz[:D][:pl_f_n].project(pz[:D][:p] + pz[:D][:f_p]) if iv
      pz[:D][:n_p_pl] = pz[:D][:pl_f_p].project(pz[:D][:p] + pz[:D][:f_n]) if iv

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
      pz[:A][:n_p_n_pl] = pz[:A][:p_n_pl] - pzAp
      pz[:A][:n_n_p_pl] = pz[:A][:n_p_pl] - pzAp

      pz[:B][:n_p_n_pl] = pz[:B][:p_n_pl] - pzBp
      pz[:B][:n_n_p_pl] = pz[:B][:n_p_pl] - pzBp

      pz[:C][:n_p_n_pl] = pz[:C][:p_n_pl] - pzCp
      pz[:C][:n_n_p_pl] = pz[:C][:n_p_pl] - pzCp

      pz[:D][:n_p_n_pl] = pz[:D][:p_n_pl] - pzDp                           if iv
      pz[:D][:n_n_p_pl] = pz[:D][:n_p_pl] - pzDp                           if iv

      # Fetch angle between both extended vectors (A>pC & A>pB),
      # ... then normalize (Cn).
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
      a1 = OpenStudio.getAngle(pz[:A][:n_p_n_pl], pz[:A][:n_n_p_pl])
      a2 = OpenStudio.getAngle(pz[:B][:n_p_n_pl], pz[:B][:n_n_p_pl])
      a3 = OpenStudio.getAngle(pz[:C][:n_p_n_pl], pz[:C][:n_n_p_pl])
      a4 = OpenStudio.getAngle(pz[:D][:n_p_n_pl], pz[:D][:n_n_p_pl])       if iv

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
      pz[:A][:f_n].normalize
      pz[:A][:n_p_n_pl].normalize
      pzAp = pzAp + scalar(pz[:A][:n_p_n_pl], w)
      pzAp = pzAp + scalar(pz[:A][:f_n], w * Math.tan(a1/2))

      pz[:B][:f_n].normalize
      pz[:B][:n_p_n_pl].normalize
      pzBp = pzBp + scalar(pz[:B][:n_p_n_pl], w)
      pzBp = pzBp + scalar(pz[:B][:f_n], w * Math.tan(a2/2))

      pz[:C][:f_n].normalize
      pz[:C][:n_p_n_pl].normalize
      pzCp = pzCp + scalar(pz[:C][:n_p_n_pl], w)
      pzCp = pzCp + scalar(pz[:C][:f_n], w * Math.tan(a3/2))

      pz[:D][:f_n].normalize                                               if iv
      pz[:D][:n_p_n_pl].normalize                                          if iv
      pzDp = pzDp + scalar(pz[:D][:n_p_n_pl], w)                           if iv
      pzDp = pzDp + scalar(pz[:D][:f_n], w * Math.tan(a4/2))               if iv

      # Re-convert to OpenStudio 3D points.
      vec  = OpenStudio::Point3dVector.new
      vec << OpenStudio::Point3d.new(pzAp.x, pzAp.y, pzAp.z)
      vec << OpenStudio::Point3d.new(pzBp.x, pzBp.y, pzBp.z)
      vec << OpenStudio::Point3d.new(pzCp.x, pzCp.y, pzCp.z)
      vec << OpenStudio::Point3d.new(pzDp.x, pzDp.y, pzDp.z)               if iv

      return vec
    end
  end

  ##
  # Validate whether an OpenStudio planar surface is safe to process.
  #
  # @param s [OpenStudio::Model::PlanarSurface] a surface
  #
  # @return [Bool] true if valid surface
  def surface_valid?(s = nil)
    mth = "OSut::#{__callee__}"
    cl = OpenStudio::Model::PlanarSurface

    return mismatch("surface", s, cl, mth, DBG, false) unless s.is_a?(cl)

    id   = s.nameString
    size = s.vertices.size
    last = size - 1

    log(ERR, "#{id} #{size} vertices? need +3 (#{mth})")        unless size > 2
    return false                                                unless size > 2

    [0, last].each do |i|
      v1  = s.vertices[i]
      v2  = s.vertices[i + 1]                                  unless i == last
      v2  = s.vertices.first                                       if i == last
      vec = v2 - v1
      bad = vec.length < TOL

      # As is, this comparison also catches collinear vertices (< 10mm apart)
      # along an edge. Should avoid red-flagging such cases. TO DO.
      log(ERR, "#{id}: < #{TOL}m (#{mth})")                              if bad
      return false                                                       if bad
    end

    # Add as many extra tests as needed ...
    true
  end

  ##
  # Add sub surfaces (e.g. windows, doors, skylights) to surface.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param s [OpenStudio::Model::Surface] a model surface
  # @param subs [Array] requested sub surface attributes
  # @param clear [Bool] remove current sub surfaces if true
  # @param bfr [Double] safety buffer (m), when ~aligned along other edges
  #
  # @return [Bool] true if successful (check for logged messages if failures)
  def addSubs(model = nil, s = nil, subs = [], clear = false, bfr = 0.005)
    mth = "OSut::#{__callee__}"
    v   = OpenStudio.openStudioVersion.split(".").join.to_i
    cl1 = OpenStudio::Model::Model
    cl2 = OpenStudio::Model::Surface
    cl3 = Array
    cl4 = Hash
    cl5 = Numeric
    min = 0.050 # minimum ratio value ( 5%)
    max = 0.950 # maximum ratio value (95%)
    no  = false

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Exit if mismatched or invalid argument classes.
    return mismatch("model", model, cl1, mth, DBG, no) unless model.is_a?(cl1)
    return mismatch("surface",   s, cl2, mth, DBG, no) unless s.is_a?(cl2)
    return mismatch("subs",   subs, cl3, mth, DBG, no) unless subs.is_a?(cl3)
    return no                                          unless surface_valid?(s)

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Clear existing sub surfaces if requested.
    nom = s.nameString

    unless clear == true || clear == false
      log(WRN, "#{nom}: Keeping existing sub surfaces (#{mth})")
      clear = false
    end

    s.subSurfaces.map(&:remove) if clear

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Allowable sub surface types ... & Frame&Divider enabled
    #   - "FixedWindow"             | true
    #   - "OperableWindow"          | true
    #   - "Door"                    | false
    #   - "GlassDoor"               | true
    #   - "OverheadDoor"            | false
    #   - "Skylight"                | false if v < 321
    #   - "TubularDaylightDome"     | false
    #   - "TubularDaylightDiffuser" | false
    type  = "FixedWindow"
    types = OpenStudio::Model::SubSurface.validSubSurfaceTypeValues
    gross = s.grossArea
    stype = s.surfaceType # Wall, RoofCeiling or Floor

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Fetch transform, as if host surface vertices were to "align", i.e.:
    #   - rotated/tilted ... then flattened along XY plane
    #   - all Z-axis coordinates ~= 0
    #   - vertices with the lowest X-axis values are "aligned" along X-axis (0)
    #   - vertices with the lowest Z-axis values are "aligned" along Y-axis (0)
    #   - Z-axis values are represented as Y-axis values
    tr = OpenStudio::Transformation.alignFace(s.vertices)

    # Aligned vertices of host surface, and fetch attributes.
    aligned = tr.inverse * s.vertices
    max_x   = aligned.max_by(&:x).x
    max_y   = aligned.max_by(&:y).y
    mid_x   = max_x / 2
    mid_y   = max_y / 2

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Assign default values to certain sub keys (if missing), +more validation.
    subs.each_with_index do |sub, index|
      return mismatch("sub", sub, cl4, mth, DBG, no) unless sub.is_a?(cl4)

      # Required key:value pairs (either set by the user or defaulted).
      sub[:id        ] = ""     unless sub.key?(:id        ) # "Window 007"
      sub[:type      ] = type   unless sub.key?(:type      ) # "FixedWindow"
      sub[:count     ] = 1      unless sub.key?(:count     ) # for an array
      sub[:multiplier] = 1      unless sub.key?(:multiplier)
      sub[:frame     ] = nil    unless sub.key?(:frame     ) # frame/divider
      sub[:assembly  ] = nil    unless sub.key?(:assembly  ) # construction

      # Optional key:value pairs.
      # sub[:ratio     ] # e.g. %FWR
      # sub[:head      ] # e.g. std 80" door + frame/buffers
      # sub[:sill      ] # e.g. std 30" sill + frame/buffers
      # sub[:height    ] # any sub surface height below "head"
      # sub[:width     ] # e.g. 1.200 m
      # sub[:offset    ] # if array
      # sub[:centreline] # left or right of base surface centreline

      sub[:id] = "#{nom}|#{index}" if sub[:id].empty?
      id       = sub[:id]

      # If sub surface type is invalid, log/reset. Additional corrections may
      # be enabled once a sub surface is actually instantiated.
      unless types.include?(sub[:type])
        log(WRN, "Reset invalid '#{id}' type to '#{type}' (#{mth})")
        sub[:type] = type
      end

      # Log/ignore (optional) frame & divider object.
      unless sub[:frame].nil?
        if sub[:frame].respond_to?(:frameWidth)
          sub[:frame] = nil if sub[:type] == "Skylight" && v < 321
          sub[:frame] = nil if sub[:type] == "Door"
          sub[:frame] = nil if sub[:type] == "OverheadDoor"
          sub[:frame] = nil if sub[:type] == "TubularDaylightDome"
          sub[:frame] = nil if sub[:type] == "TubularDaylightDiffuser"
          log(WRN, "Skip '#{id}' FrameDivider (#{mth})") if sub[:frame].nil?
        else
          sub[:frame] = nil
          log(WRN, "Skip '#{id}' invalid FrameDivider object (#{mth})")
        end
      end

      # The (optional) "assembly" must reference a valid OpenStudio
      # construction base, to explicitly assign to each instantiated sub
      # surface. If invalid, log/reset/ignore. Additional checks are later
      # activated once a sub surface is actually instantiated.
      unless sub[:assembly].nil?
        unless sub[:assembly].respond_to?(:isFenestration)
          log(WRN, "Skip invalid '#{id}' construction (#{mth})")
          sub[:assembly] = nil
        end
      end

      # Log/reset negative numerical values. Set ~0 values to 0.
      sub.each do |key, value|
        next if key == :id
        next if key == :type
        next if key == :frame
        next if key == :assembly

        return mismatch(key, value, cl5, mth, DBG, no) unless value.is_a?(cl5)
        next if key == :centreline

        negative(key, mth, WRN) if value < 0
        value = 0.0             if value.abs < TOL
      end
    end

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Log/reset (or abandon) conflicting user-set geometry key:value pairs:
    #   - sub[:head      ] # e.g. std 80" door + frame/buffers
    #   - sub[:sill      ] # e.g. std 30" sill + frame/buffers
    #   - sub[:height    ] # any sub surface height below "head"
    #   - sub[:width     ] # e.g. 1.200 m
    #   - sub[:offset    ] # centreline-to-centreline between subs (if array)
    #   - sub[:centreline] # left/right of base surface centreline, e.g. -0.2 m
    #
    # If successful, this will generate sub surfaces and add them to the model.
    subs.each do |sub|
      # Set-up unique sub parameters:
      #   - Frame & Divider "width"
      #   - minimum "clear glazing" limits
      #   - buffers, etc.
      id         = sub[:id]
      frame      = 0
      frame      = sub[:frame].frameWidth unless sub[:frame].nil?
      frames     = 2 * frame
      buffer     = frame + bfr
      buffers    = 2 * buffer
      dim        = 0.200 unless (3 * frame) > 0.200
      dim        = 3 * frame if (3 * frame) > 0.200
      glass      = dim - frames
      min_sill   = buffer
      min_head   = buffers + glass
      max_head   = max_y - buffer
      max_sill   = max_head - (buffers + glass)
      min_ljamb  = buffer
      max_ljamb  = max_x - (buffers + glass)
      min_rjamb  = buffers + glass
      max_rjamb  = max_x - buffer
      max_height = max_y - buffers
      max_width  = max_x - buffers

      # Default sub surface "head" & "sill" height (unless user-specified).
      typ_head = HEAD # standard 80" door
      typ_sill = SILL # standard 30" window sill

      if sub.key?(:ratio)
        typ_head = mid_y * (1 + sub[:ratio])     if sub[:ratio] > 0.75
        typ_head = mid_y * (1 + sub[:ratio]) unless stype.downcase == "wall"
        typ_sill = mid_y * (1 - sub[:ratio])     if sub[:ratio] > 0.75
        typ_sill = mid_y * (1 - sub[:ratio]) unless stype.downcase == "wall"
      end

      # Log/reset "height" if beyond min/max.
      if sub.key?(:height)
        unless sub[:height].between?(glass, max_height)
          sub[:height] = glass      if sub[:height] < glass
          sub[:height] = max_height if sub[:height] > max_height
          log(WRN, "Reset '#{id}' height to #{sub[:height]} m (#{mth})")
        end
      end

      # Log/reset "head" height if beyond min/max.
      if sub.key?(:head)
        unless sub[:head].between?(min_head, max_head)
          sub[:head] = max_head if sub[:head] > max_head
          sub[:head] = min_head if sub[:head] < min_head
          log(WRN, "Reset '#{id}' head height to #{sub[:head]} m (#{mth})")
        end
      end

      # Log/reset "sill" height if beyond min/max.
      if sub.key?(:sill)
        unless sub[:sill].between?(min_sill, max_sill)
          sub[:sill] = max_sill if sub[:sill] > max_sill
          sub[:sill] = min_sill if sub[:sill] < min_sill
          log(WRN, "Reset '#{id}' sill height to #{sub[:sill]} m (#{mth})")
        end
      end

      # At this point, "head", "sill" and/or "height" have been tentatively
      # validated (and/or have been corrected) independently from one another.
      # Log/reset "head" & "sill" heights if conflicting.
      if sub.key?(:head) && sub.key?(:sill) && sub[:head] < sub[:sill] + glass
        sill = sub[:head] - glass

        if sill < min_sill
          sub[:ratio     ] = 0 if sub.key?(:ratio)
          sub[:count     ] = 0
          sub[:multiplier] = 0
          sub[:height    ] = 0 if sub.key?(:height)
          sub[:width     ] = 0 if sub.key?(:width)
          log(ERR, "Skip: invalid '#{id}' head/sill combo (#{mth})")
          next
        else
          sub[:sill] = sill
          log(WRN, "(Re)set '#{id}' sill height to #{sub[:sill]} m (#{mth})")
        end
      end

      # Attempt to reconcile "head", "sill" and/or "height". If successful,
      # all 3x parameters are set (if missing), or reset if invalid.
      if sub.key?(:head) && sub.key?(:sill)
        height = sub[:head] - sub[:sill]

        if sub.key?(:height) && (sub[:height] - height).abs > TOL
          log(WRN, "(Re)set '#{id}' height to #{height} m (#{mth})")
        end

        sub[:height] = height
      elsif sub.key?(:head) # no "sill"
        if sub.key?(:height)
          sill = sub[:head] - sub[:height]

          if sill < min_sill
            sill   = min_sill
            height = sub[:head] - sill

            if height < glass
              sub[:ratio     ] = 0 if sub.key?(:ratio)
              sub[:count     ] = 0
              sub[:multiplier] = 0
              sub[:height    ] = 0 if sub.key?(:height)
              sub[:width     ] = 0 if sub.key?(:width)
              log(ERR, "Skip: invalid '#{id}' head/height combo (#{mth})")
              next
            else
              sub[:sill  ] = sill
              sub[:height] = height
              log(WRN, "(Re)set '#{id}' height to #{sub[:height]} m (#{mth})")
            end
          else
            sub[:sill] = sill
          end
        else
          sub[:sill  ] = typ_sill
          sub[:height] = sub[:head] - sub[:sill]
        end
      elsif sub.key?(:sill) # no "head"
        if sub.key?(:height)
          head = sub[:sill] + sub[:height]

          if head > max_head
            head   = max_head
            height = head - sub[:sill]

            if height < glass
              sub[:ratio     ] = 0 if sub.key?(:ratio)
              sub[:count     ] = 0
              sub[:multiplier] = 0
              sub[:height    ] = 0 if sub.key?(:height)
              sub[:width     ] = 0 if sub.key?(:width)
              log(ERR, "Skip: invalid '#{id}' sill/height combo (#{mth})")
              next
            else
              sub[:head  ] = head
              sub[:height] = height
              log(WRN, "(Re)set '#{id}' height to #{sub[:height]} m (#{mth})")
            end
          else
            sub[:head] = head
          end
        else
          sub[:head  ] = typ_head
          sub[:height] = sub[:head] - sub[:sill]
        end
      elsif sub.key?(:height) # neither "head" nor "sill"
        head = typ_head
        sill = head - sub[:height]

        if sill < min_sill
          sill = min_sill
          head = sill + sub[:height]
        end

        sub[:head] = head
        sub[:sill] = sill
      else
        sub[:head  ] = typ_head
        sub[:sill  ] = typ_sill
        sub[:height] = sub[:head] - sub[:sill]
      end

      # Log/reset "width" if beyond min/max.
      if sub.key?(:width)
        unless sub[:width].between?(glass, max_width)
          sub[:width] = glass      if sub[:width] < glass
          sub[:width] = max_width  if sub[:width] > max_width
          log(WRN, "Reset '#{id}' width to #{sub[:width]} m (#{mth})")
        end
      end

      # Log/reset "count" if < 1.
      if sub.key?(:count)
        if sub[:count] < 1
          sub[:count] = 1
          log(WRN, "Reset '#{id}' count to #{sub[:count]} (#{mth})")
        end
      end

      sub[:count] = 1 unless sub.key?(:count)

      n       = sub[:count]
      even    = n.to_i.even?
      centre  = mid_x
      centre += sub[:centreline] if sub.key?(:centreline)
      h       = sub[:height] + frames
      w       = 0 # overall width of sub(s) bounding box (to calculate)
      x0      = 0 # left-side X-axis coordinate of sub(s) bounding box
      xf      = 0 # right-side X-axis coordinate of sub(s) bounding box

      # Log/reset "offset", if conflicting vs "width".
      if sub.key?(:ratio)
        if sub[:ratio] < TOL
          sub[:ratio     ] = 0
          sub[:count     ] = 0
          sub[:multiplier] = 0
          sub[:height    ] = 0 if sub.key?(:height)
          sub[:width     ] = 0 if sub.key?(:width)
          log(ERR, "Skip: '#{id}' ratio ~0 (#{mth})")
          next
        end

        # Log/reset if "ratio" beyond min/max?
        unless sub[:ratio].between?(min, max)
          sub[:ratio] = min if sub[:ratio] < min
          sub[:ratio] = max if sub[:ratio] > max
          log(WRN, "Reset ratio (min/max) to #{sub[:ratio]} (#{mth})")
        end

        # Log/reset "count" unless 1.
        unless sub[:count] == 1
          sub[:count] = 1
          log(WRN, "Reset count (ratio) to 1 (#{mth})")
        end

        area  = gross * sub[:ratio] # sub m2, including (optional) frames
        w     = area / h
        width = w - frames
        x0    = centre - w/2
        xf    = centre + w/2

        # Too wide?
        if x0 < min_ljamb || xf > max_rjamb
          sub[:ratio     ] = 0 if sub.key?(:ratio)
          sub[:count     ] = 0
          sub[:multiplier] = 0
          sub[:height    ] = 0 if sub.key?(:height)
          sub[:width     ] = 0 if sub.key?(:width)
          log(ERR, "Skip: invalid (ratio) width/centreline (#{mth})")
          next
        end

        if sub.key?(:width) && (sub[:width] - width).abs > TOL
          sub[:width] = width
          log(WRN, "Reset width (ratio) to #{sub[:width]} (#{mth})")
        end

        sub[:width] = width unless sub.key?(:width)
      else
        unless sub.key?(:width)
          sub[:ratio     ] = 0 if sub.key?(:ratio)
          sub[:count     ] = 0
          sub[:multiplier] = 0
          sub[:height    ] = 0 if sub.key?(:height)
          sub[:width     ] = 0 if sub.key?(:width)
          log(ERR, "Skip: missing '#{id}' width (#{mth})")
          next
        end

        width  = sub[:width] + frames
        gap    = (max_x - n * width) / (n + 1)
        gap    = sub[:offset] - width if sub.key?(:offset)
        gap    = 0                    if gap < bfr
        offset = gap + width

        if sub.key?(:offset) && (offset - sub[:offset]).abs > TOL
          sub[:offset] = offset
          log(WRN, "Reset sub offset to #{sub[:offset]} m (#{mth})")
        end

        sub[:offset] = offset unless sub.key?(:offset)

        # Overall width of bounding box around array.
        w  = n * width + (n - 1) * gap
        x0 = centre - w/2
        xf = centre + w/2

        # Too wide?
        if x0 < min_ljamb || xf > max_rjamb
          sub[:ratio     ] = 0 if sub.key?(:ratio)
          sub[:count     ] = 0
          sub[:multiplier] = 0
          sub[:height    ] = 0 if sub.key?(:height)
          sub[:width     ] = 0 if sub.key?(:width)
          log(ERR, "Skip: invalid array width/centreline (#{mth})")
          next
        end
      end

      # Initialize left-side X-axis coordinate of only/first sub.
      pos = x0

      # Generate sub(s).
      sub[:count].times do |i|
        name = "#{id}:#{i}"
        fr   = 0
        fr   = sub[:frame].frameWidth if sub[:frame]

        vec  = OpenStudio::Point3dVector.new
        vec << OpenStudio::Point3d.new(pos,               sub[:head], 0)
        vec << OpenStudio::Point3d.new(pos,               sub[:sill], 0)
        vec << OpenStudio::Point3d.new(pos + sub[:width], sub[:sill], 0)
        vec << OpenStudio::Point3d.new(pos + sub[:width], sub[:head], 0)
        vec = tr * vec

        # Log/skip if conflict between individual sub and base surface.
        vc = vec
        vc = offset(vc, fr, 300) if fr > 0
        ok = fits?(vc, s.vertices, name, nom)
        log(ERR, "Skip '#{name}': won't fit in '#{nom}' (#{mth})") unless ok
        break                                                      unless ok

        # Log/skip if conflicts with existing subs (even if same array).
        s.subSurfaces.each do |sb|
          nome = sb.nameString
          fd   = sb.windowPropertyFrameAndDivider
          fr   = 0                     if fd.empty?
          fr   = fd.get.frameWidth unless fd.empty?
          vk   = sb.vertices
          vk   = offset(vk, fr, 300) if fr > 0
          oops = overlaps?(vc, vk, name, nome)
          log(ERR, "Skip '#{name}': overlaps '#{nome}' (#{mth})") if oops
          ok = false                                              if oops
          break                                                   if oops
        end

        break unless ok

        sb = OpenStudio::Model::SubSurface.new(vec, model)
        sb.setName(name)
        sb.setSubSurfaceType(sub[:type])
        sb.setConstruction(sub[:assembly])               if sub[:assembly]
        ok = sb.allowWindowPropertyFrameAndDivider
        sb.setWindowPropertyFrameAndDivider(sub[:frame]) if sub[:frame] && ok
        sb.setMultiplier(sub[:multiplier])               if sub[:multiplier] > 1
        sb.setSurface(s)

        # Reset "pos" if array.
        pos += sub[:offset] if sub.key?(:offset)
      end
    end

    true
  end

  ##
  # Callback when other modules extend OSlg
  #
  # @param base [Object] instance or class object
  def self.extended(base)
    base.send(:include, self)
  end
end
