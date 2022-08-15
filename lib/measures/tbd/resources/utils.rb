# BSD 3-Clause License
#
# Copyright (c) 2022, Denis Bourgeois
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
  # to ASHRAE 90.1 (e.g., heating and/or cooling based, no distinction for
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
  # For an OpenStudio model (OSM) in an incomplete or preliminary state, e.g.
  # holding fully-formed ENCLOSED spaces without thermal zoning information or
  # setpoint temperatures (early design stage assessments of form, porosity or
  # envelope), all OSM spaces will be considered CONDITIONED, presuming
  # setpoints of ~21°C (heating) and ~24°C (cooling).
  #
  # If ANY valid space/zone-specific temperature setpoints are found in the OSM,
  # spaces/zones WITHOUT valid heating or cooling setpoints are considered as
  # UNCONDITIONED or UNENCLOSED spaces (like attics), or INDIRECTLY CONDITIONED
  # spaces (like plenums), see "plenum?" method.

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
    mth      = "OSut::#{__callee__}"
    cl       = OpenStudio::Model::ScheduleInterval
    vals     = []
    prev_str = ""
    res      = { min: nil, max: nil }

    return invalid("sched", mth, 1, DBG, res)     unless sched.respond_to?(NS)
    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)
    vals = sched.timeSeries.values
    ok = vals.min.is_a?(Numeric) && vals.max.is_a?(Numeric)
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

      # unless equip.to_ZoneHVACLowTemperatureRadiantElectric.empty?
      #   equip = equip.to_ZoneHVACLowTemperatureRadiantElectric.get
      #
      #   unless equip.heatingSetpointTemperatureSchedule.empty?
      #     sched = equip.heatingSetpointTemperatureSchedule.get
      #   end
      # end

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

    return mismatch("model", model, cl, mth, DBG, false) unless model.is_a?(cl)

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

    return mismatch("model", model, cl, mth, DBG, false) unless model.is_a?(cl)

    model.getThermalZones.each do |zone|
      next if zone.canBePlenum
      return true unless zone.airLoopHVACs.empty?
      return true if zone.isPlenum
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
    #         OpenStudio model (complete with HVAC air loops);
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

      unless type.standardsSpaceType.empty?
        type = type.standardsSpaceType.get
        return type.downcase == "plenum"                                     # C
      end
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

    return mismatch("model", model, cl, mth)    unless model.is_a?(cl)
    return invalid("availability", avl, 2, mth) unless avl.respond_to?(:to_s)

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
    year = model.yearDescription
    return empty("yearDescription", mth, ERR) if year.empty?
    year = year.get
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
  # Validate if default construction set holds a base ground construction.
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

    return mismatch("model", model, cl1, mth) unless model.is_a?(cl1)
    return invalid("s", mth, 2)               unless s.respond_to?(NS)
    id = s.nameString
    return mismatch(id, s, cl2, mth)          unless s.is_a?(cl2)

    ok = s.isConstructionDefaulted
    log(ERR, "'#{id}' construction not defaulted (#{mth})")            unless ok
    return nil                                                         unless ok
    return empty("'#{id}' construction", mth, ERR) if s.construction.empty?
    base = s.construction.get
    return empty("'#{id}' space", mth, ERR) if s.space.empty?
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
      return set if holdsConstruction?(set, base, ground, exterior, type)
    end

    unless space.spaceType.empty?
      spacetype = space.spaceType.get

      unless spacetype.defaultConstructionSet.empty?
        set = spacetype.defaultConstructionSet.get
        return set if holdsConstruction?(set, base, ground, exterior, type)
      end
    end

    unless space.buildingStory.empty?
      story = space.buildingStory.get

      unless story.defaultConstructionSet.empty?
        set = story.defaultConstructionSet.get
        return set if holdsConstruction?(set, base, ground, exterior, type)
      end
    end

    building = model.getBuilding

    unless building.defaultConstructionSet.empty?
      set = building.defaultConstructionSet.get
      return set if holdsConstruction?(set, base, ground, exterior, type)
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
  # @return [Double] total layered construction thickness
  # @return [Double] 0 if invalid input
  def thickness(lc = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::LayeredConstruction

    return invalid("lc", mth, 1, DBG, 0.0)     unless lc.respond_to?(NS)
    id = lc.nameString
    return mismatch(id, lc, cl, mth, DBG, 0.0) unless lc.is_a?(cl)

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
    t += 273.0                                                         # °C to K
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

    return invalid("lc", mth, 1, DBG, res)      unless lc.respond_to?(NS)
    id = lc.nameString
    return mismatch(id, lc, cl1, mth, DBG, res) unless lc.is_a?(cl)

    lc.layers.each do |m|
      unless m.to_MasslessOpaqueMaterial.empty?
        m             = m.to_MasslessOpaqueMaterial.get

        if m.thermalResistance < 0.001 || m.thermalResistance < res[:r]
          i += 1
          next
        else
          res[:r]     = m.thermalResistance
          res[:index] = i
          res[:type]  = :massless
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
          res[:r]     = d / k
          res[:index] = i
          res[:type]  = :standard
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
    return mismatch("points", pts, cl1, mth, DBG, v)     unless valid
    pts.each { |pt| mismatch("pt", pt, cl2, mth, ERR, v) unless pt.is_a?(cl2) }
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
    return empty(i1, mth, ERR, a) if p1.empty?
    return empty(i2, mth, ERR, a) if p2.empty?
    p1.each { |v| return mismatch(i1, v, cl2, mth, ERR, a) unless v.is_a?(cl2) }
    p2.each { |v| return mismatch(i2, v, cl2, mth, ERR, a) unless v.is_a?(cl2) }

    ft = OpenStudio::Transformation::alignFace(p1).inverse
    ft_p1 = flatZ( (ft * p1).reverse )
    return false if ft_p1.empty?
    area1 = OpenStudio::getArea(ft_p1)
    return empty("#{i1} area", mth, ERR, a) if area1.empty?
    area1 = area1.get
    ft_p2 = flatZ( (ft * p2).reverse )
    return false if ft_p2.empty?
    area2 = OpenStudio::getArea(ft_p2)
    return empty("#{i2} area", mth, ERR, a) if area2.empty?
    area2 = area2.get
    union = OpenStudio::join(ft_p1, ft_p2, TOL2)
    return false if union.empty?
    union = union.get
    area = OpenStudio::getArea(union)
    return empty("#{i1}:#{i2} union area", mth, ERR, a) if area.empty?
    area = area.get

    return false if area < TOL
    return true if (area - area2).abs < TOL
    return false if (area - area2).abs > TOL

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
    return empty(i1, mth, ERR, a) if p1.empty?
    return empty(i2, mth, ERR, a) if p2.empty?
    p1.each { |v| return mismatch(i1, v, cl2, mth, ERR, a) unless v.is_a?(cl2) }
    p2.each { |v| return mismatch(i2, v, cl2, mth, ERR, a) unless v.is_a?(cl2) }

    ft = OpenStudio::Transformation::alignFace(p1).inverse
    ft_p1 = flatZ( (ft * p1).reverse )
    return false if ft_p1.empty?
    area1 = OpenStudio::getArea(ft_p1)
    return empty("#{i1} area", mth, ERR, a) if area1.empty?
    area1 = area1.get
    ft_p2 = flatZ( (ft * p2).reverse )
    return false if ft_p2.empty?
    area2 = OpenStudio::getArea(ft_p2)
    return empty("#{i2} area", mth, ERR, a) if area2.empty?
    area2 = area2.get
    union = OpenStudio::join(ft_p1, ft_p2, TOL2)
    return false if union.empty?
    union = union.get
    area = OpenStudio::getArea(union)
    return empty("#{i1}:#{i2} union area", mth, ERR, a) if area.empty?
    area = area.get

    return false if area < TOL

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
