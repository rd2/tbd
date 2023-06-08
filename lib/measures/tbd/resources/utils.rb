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

  # Default (higher-level) construction parameters.
  @@mass = [:none, :light, :medium, :heavy].freeze
  @@film = {} # standard air films, m2.K/W
  @@uo   = {} # default (~1980s) envelope Uo (W/m2.K), based on surface type
  @@mats = {} # StandardOpaqueMaterials

  @@film[:shading  ] = 0.000
  @@film[:partition] = 0.000
  @@film[:wall     ] = 0.150
  @@film[:roof     ] = 0.140
  @@film[:floor    ] = 0.190
  @@film[:basement ] = 0.120
  @@film[:slab     ] = 0.160
  @@film[:door     ] = @@film[:wall]
  @@film[:window   ] = @@film[:wall] # irrelevant if SimpleGlazingMaterial
  @@film[:skylight ] = @@film[:roof] # irrelevant if SimpleGlazingMaterial

  @@uo[:shading    ] = 0.000 # N/A
  @@uo[:partition  ] = 0.000 # N/A
  @@uo[:wall       ] = 0.384 # rated Ro ~14.8
  @@uo[:roof       ] = 0.327 # rated Ro ~17.6
  @@uo[:floor      ] = 0.317 # rated Ro ~17.9 (exposed floor)
  @@uo[:basement   ] = 0.000 # uninsulated
  @@uo[:slab       ] = 0.000 # uninsulated
  @@uo[:door       ] = 1.800 # insulated, unglazed steel door (single layer)
  @@uo[:window     ] = 2.800 # e.g. patio doors (simple glazing)
  @@uo[:skylight   ] = 3.500 # all skylight technologies

  # Default OpenStudio "StandardOpaqueMaterial" object parameters:
  #   - roughness            (rgh) : "Smooth"
  #   - thickness                  :    0.1 m
  #   - thermal conductivity (k  ) :    0.1 W/m.K
  #   - density              (rho) :    0.1 kg/m3
  #   - specific heat        (cp ) : 1400.0 J/kg.K
  #
  #   https://s3.amazonaws.com/openstudio-sdk-documentation/cpp/
  #   OpenStudio-3.6.1-doc/model/html/
  #   classopenstudio_1_1model_1_1_standard_opaque_material.html
  #
  # Apart from surface roughness, rarely would these defaulted material
  # properties be suitable - and are therefore explicitely set below. FYI:
  #   - "Very Rough"    : stucco
  #   - "Rough"	        : brick
  #   - "Medium Rough"  : concrete
  #   - "Medium Smooth" : clear pine
  #   - "Smooth"        : smooth plaster
  #   - "Very Smooth"   : glass
  #
  # Standard opaque materials, taken from a variety of sources (e.g. energy
  # codes, NREL's BCL). Material identifiers are symbols, e.g.:
  #   - :brick
  #   - :sand
  #   - :concrete
  #
  # Material properties remain largely constant between projects. What does
  # tend to vary between projects are thicknesses. Actual OpenStudio opaque
  # material objects can be (re)set in more than one way by class methods.
  # OpenStudio object names are then suffixed with actual material thicknesses,
  # in mm, e.g.:
  #   - "concrete200" : 200mm concrete slab
  #   - "drywall13"    : 1/2" gypsum board
  #   - "drywall16"    : 5/8" gypsum board
  #
  # Surface absorptances are also defaulted in OpenStudio:
  #   - thermal, long-wave   (thm) : 90%
  #   - solar                (sol) : 70%
  #   - visible              (vis) : 70%
  #
  # These can also be explicitly set, here (e.g. a redundant example):
  @@mats[:sand     ]         = {}
  @@mats[:sand     ][:rgh] = "Rough"
  @@mats[:sand     ][:k  ] =    1.290
  @@mats[:sand     ][:rho] = 2240.000
  @@mats[:sand     ][:cp ] =  830.000
  @@mats[:sand     ][:thm] =    0.900
  @@mats[:sand     ][:sol] =    0.700
  @@mats[:sand     ][:vis] =    0.700

  @@mats[:concrete ]       = {}
  @@mats[:concrete ][:rgh] = "MediumRough"
  @@mats[:concrete ][:k  ] =    1.730
  @@mats[:concrete ][:rho] = 2240.000
  @@mats[:concrete ][:cp ] =  830.000

  @@mats[:brick    ]       = {}
  @@mats[:brick    ][:rgh] = "Rough"
  @@mats[:brick    ][:k  ] =    0.675
  @@mats[:brick    ][:rho] = 1600.000
  @@mats[:brick    ][:cp ] =  790.000

  @@mats[:cladding ]       = {} # e.g. lightweight cladding over furring
  @@mats[:cladding ][:rgh] = "MediumSmooth"
  @@mats[:cladding ][:k  ] =    0.115
  @@mats[:cladding ][:rho] =  540.000
  @@mats[:cladding ][:cp ] = 1200.000

  @@mats[:sheathing]       = {} # e.g. plywood
  @@mats[:sheathing][:k  ] =    0.160
  @@mats[:sheathing][:rho] =  545.000
  @@mats[:sheathing][:cp ] = 1210.000

  @@mats[:polyiso  ]       = {}
  @@mats[:polyiso  ][:k  ] =    0.025
  @@mats[:polyiso  ][:rho] =   25.000
  @@mats[:polyiso  ][:cp ] = 1590.000

  @@mats[:cellulose]       = {}
  @@mats[:cellulose][:rgh] = "VeryRough"
  @@mats[:cellulose][:k  ] =    0.050
  @@mats[:cellulose][:rho] =   80.000
  @@mats[:cellulose][:cp ] =  835.000

  @@mats[:mineral  ]       = {}
  @@mats[:mineral  ][:k  ] =    0.050
  @@mats[:mineral  ][:rho] =   19.000
  @@mats[:mineral  ][:cp ] =  960.000

  @@mats[:drywall  ]       = {}
  @@mats[:drywall  ][:k  ] =    0.160
  @@mats[:drywall  ][:rho] =  785.000
  @@mats[:drywall  ][:cp ] = 1090.000

  @@mats[:door     ]        = {}
  @@mats[:door     ][:rgh] = "MediumSmooth"
  @@mats[:door     ][:k  ] =    0.080 # = 1.8 * 0.045m
  @@mats[:door     ][:rho] =  600.000
  @@mats[:door     ][:cp ] = 1000.000

  ##
  # Generate a multilayered construction, based on specs. Also generates
  # required OpenStudio materials as needed.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param specs [Hash] a specification hash
  #
  # @return [OpenStudio::Model::Construction] a construction (nil if failure)
  def genConstruction(model = nil, specs = {})
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::Model
    cl2 = Hash

    # Log/exit if invalid arguments.
    return mismatch("model", model, cl1, mth)        unless model.is_a?(cl1)
    return mismatch("specs", specs, cl2, mth)        unless specs.is_a?(cl2)

    specs[:type]   = :wall                           unless specs.key?(:type)
    ok             = @@uo.keys.include?(specs[:type])
    return invalid("surface type", mth, 0)           unless ok

    specs[:id  ]   = ""                              unless specs.key?(:id  )
    id             = specs[:id]
    ok             = id.respond_to?(:to_s)
    id             = "Construction:#{specs[:type]}"  unless ok
    id             = "Construction:#{specs[:type]}"      if id.empty?
    specs[:uo  ]   = @@uo[ specs[:type] ]            unless specs.key?(:uo  )
    u              = specs[:uo]
    return mismatch("#{id} Uo", u, Numeric, mth)     unless u.is_a?(Numeric)
    return invalid("#{id} Uo (> 5.678)", mth, 0)         if u > 5.678

    # Optional specs. Log/reset if invalid.
    specs[:clad  ] = :light             unless specs.key?(:clad  ) # exterior
    specs[:frame ] = :light             unless specs.key?(:frame )
    specs[:finish] = :light             unless specs.key?(:finish) # interior
    specs[:clad  ] = :light             unless @@mass.include?(specs[:clad  ])
    specs[:frame ] = :light             unless @@mass.include?(specs[:frame ])
    specs[:finish] = :light             unless @@mass.include?(specs[:finish])
    log(WRN, "Reset to light cladding") unless @@mass.include?(specs[:clad  ])
    log(WRN, "Reset to light framing" ) unless @@mass.include?(specs[:frame ])
    log(WRN, "Reset to light finish"  ) unless @@mass.include?(specs[:finish])
    film           = @@film[ specs[:type] ]

    # Layered assembly (max 4 layers):
    #   - cladding
    #   - intermediate sheathing
    #   - composite insulating/framing
    #   - interior finish
    a = {clad: {}, sheath: {}, compo: {}, finish: {}, glazing: {}}

    case specs[:type]
    when :shading
      mt = :sheathing
      d  = 0.015
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
    when :partition
      d  = 0.015
      mt = :drywall
      a[:clad][:mat] = @@mats[mt]
      a[:clad][:d  ] = d
      a[:clad][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

      mt = :sheathing
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

      mt = :drywall
      a[:finish][:mat] = @@mats[mt]
      a[:finish][:d  ] = d
      a[:finish][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
    when :wall
      unless specs[:clad] == :none
        mt = :cladding
        mt = :brick    if specs[:clad] == :medium
        mt = :concrete if specs[:clad] == :heavy
        d  = 0.100
        d  = 0.015     if specs[:clad] == :light
        a[:clad][:mat] = @@mats[mt]
        a[:clad][:d  ] = d
        a[:clad][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      end

      mt = :drywall
      mt = :polyiso   if specs[:frame] == :medium
      mt = :mineral   if specs[:frame] == :heavy
      d  = 0.100
      d  = 0.015      if specs[:frame] == :light
      a[:sheath][:mat] = @@mats[mt]
      a[:sheath][:d  ] = d
      a[:sheath][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

      mt = :concrete
      mt = :mineral   if specs[:frame] == :light
      d  = 0.100
      d  = 0.200      if specs[:frame] == :heavy
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:finish] == :none
        mt = :concrete
        mt = :drywall   if specs[:finish] == :light
        d  = 0.015
        d  = 0.100      if specs[:finish] == :medium
        d  = 0.200      if specs[:finish] == :heavy
        a[:finish][:mat] = @@mats[mt]
        a[:finish][:d  ] = d
        a[:finish][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      end
    when :roof
      unless specs[:clad] == :none
        mt = :concrete
        mt = :cladding if specs[:clad] == :light
        d  = 0.015
        d  = 0.100     if specs[:clad] == :medium # e.g. terrace
        d  = 0.200     if specs[:clad] == :heavy  # e.g. parking garage
        a[:clad][:mat] = @@mats[mt]
        a[:clad][:d  ] = d
        a[:clad][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

        mt = :sheathing
        d  = 0.015
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      end

      mt = :cellulose
      mt = :polyiso   if specs[:frame] == :medium
      mt = :mineral   if specs[:frame] == :heavy
      d  = 0.100
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:finish] == :none
        mt = :concrete
        mt = :drywall   if specs[:finish] == :light
        d  = 0.015
        d  = 0.100      if specs[:finish] == :medium # proxy for steel decking
        d  = 0.200      if specs[:finish] == :heavy
        a[:finish][:mat] = @@mats[mt]
        a[:finish][:d  ] = d
        a[:finish][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      end
    when :floor # exposed
      unless specs[:clad] == :none
        mt = :cladding
        d  = 0.015
        a[:clad][:mat] = @@mats[mt]
        a[:clad][:d  ] = d
        a[:clad][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

        mt = :sheathing
        d  = 0.015
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      end

      mt = :cellulose
      mt = :polyiso   if specs[:frame] == :medium
      mt = :mineral   if specs[:frame] == :heavy
      d  = 0.100 # possibly an insulating layer to reset
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:finish] == :none
        mt = :concrete
        mt = :sheathing if specs[:finish] == :light
        d  = 0.015
        d  = 0.100      if specs[:finish] == :medium
        d  = 0.200      if specs[:finish] == :heavy
        a[:finish][:mat] = @@mats[mt]
        a[:finish][:d  ] = d
        a[:finish][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      end
    when :slab # basement slab or slab-on-grade
      mt = :sand
      d  = 0.100
      a[:clad][:mat] = @@mats[mt]
      a[:clad][:d  ] = d
      a[:clad][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:frame] == :none
        mt = :polyiso
        d  = 0.025
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      end

      mt = :concrete
      d  = 0.100
      d  = 0.200      if specs[:frame] == :heavy
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:finish] == :none
        mt = :sheathing
        d  = 0.015
        a[:finish][:mat] = @@mats[mt]
        a[:finish][:d  ] = d
        a[:finish][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      end
    when :basement # wall
      unless specs[:clad] == :none
        mt = :concrete
        mt = :sheathing if specs[:clad] == :light
        d  = 0.100
        d  = 0.015      if specs[:clad] == :light
        a[:clad][:mat] = @@mats[mt]
        a[:clad][:d  ] = d
        a[:clad][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

        mt = :polyiso
        d  = 0.025
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

        mt = :concrete
        d  = 0.200
        a[:compo][:mat] = @@mats[mt]
        a[:compo][:d  ] = d
        a[:compo][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
      else
        mt = :concrete
        d  = 0.200
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

        unless specs[:finish] == :none
          mt = :mineral
          d  = 0.075
          a[:compo][:mat] = @@mats[mt]
          a[:compo][:d  ] = d
          a[:compo][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"

          mt = :drywall
          d  = 0.015
          a[:finish][:mat] = @@mats[mt]
          a[:finish][:d  ] = d
          a[:finish][:id ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
        end
      end
    when :door # opaque
      # 45mm insulated (composite) steel door.
      mt = :door
      d  = 0.045

      a[:compo  ][:mat ] = @@mats[mt]
      a[:compo  ][:d   ] = d
      a[:compo  ][:id  ] = "#{mt}#{format('%03d', d*1000)[-3..-1]}"
    when :window # e.g. patio doors (simple glazing)
      # SimpleGlazingMaterial.
      a[:glazing][:u   ]  = specs[:uo  ]
      a[:glazing][:shgc]  = 0.450
      a[:glazing][:shgc]  = specs[:shgc] if specs.key?(:shgc)
      a[:glazing][:id  ]  = "window"
      a[:glazing][:id  ] += ":U#{format('%.1f', a[:glazing][:u])}"
      a[:glazing][:id  ] += ":SHGC#{format('%d', a[:glazing][:shgc]*100)}"
    when :skylight
      # SimpleGlazingMaterial.
      a[:glazing][:u   ] = specs[:uo  ]
      a[:glazing][:shgc] = 0.450
      a[:glazing][:shgc] = specs[:shgc] if specs.key?(:shgc)
      a[:glazing][:id  ]  = "skylight"
      a[:glazing][:id  ] += ":U#{format('%.1f', a[:glazing][:u])}"
      a[:glazing][:id  ] += ":SHGC#{format('%d', a[:glazing][:shgc]*100)}"
    end

    # Initiate layers.
    glazed = true
    glazed = false if a[:glazing].empty?
    layers = OpenStudio::Model::OpaqueMaterialVector.new   unless glazed
    layers = OpenStudio::Model::FenestrationMaterialVector.new if glazed

    if glazed
      u    = a[:glazing][:u   ]
      shgc = a[:glazing][:shgc]
      lyr  = model.getSimpleGlazingByName(a[:glazing][:id])

      if lyr.empty?
        lyr = OpenStudio::Model::SimpleGlazing.new(model, u, shgc)
        lyr.setName(a[:glazing][:id])
      else
        lyr = lyr.get
      end

      layers << lyr
    else
      # Loop through each layer spec, and generate construction.
      a.each do |i, l|
        next if l.empty?

        lyr = model.getStandardOpaqueMaterialByName(l[:id])

        if lyr.empty?
          lyr = OpenStudio::Model::StandardOpaqueMaterial.new(model)
          lyr.setName(l[:id])
          lyr.setThickness(l[:d])
          lyr.setRoughness(         l[:mat][:rgh]) if l[:mat].key?(:rgh)
          lyr.setConductivity(      l[:mat][:k  ]) if l[:mat].key?(:k  )
          lyr.setDensity(           l[:mat][:rho]) if l[:mat].key?(:rho)
          lyr.setSpecificHeat(      l[:mat][:cp ]) if l[:mat].key?(:cp )
          lyr.setThermalAbsorptance(l[:mat][:thm]) if l[:mat].key?(:thm)
          lyr.setSolarAbsorptance(  l[:mat][:sol]) if l[:mat].key?(:sol)
          lyr.setVisibleAbsorptance(l[:mat][:vis]) if l[:mat].key?(:vis)
        else
          lyr = lyr.get
        end

        layers << lyr
      end
    end

    c  = OpenStudio::Model::Construction.new(layers)
    c.setName(id)

    # Adjust insulating layer thickness or conductivity to match requested Uo.
    unless glazed
      ro = 0
      ro = 1 / specs[:uo] - @@film[ specs[:type] ] if specs[:uo] > 0

      if specs[:type] == :door # 1x layer, adjust conductivity
        layer = c.getLayer(0).to_StandardOpaqueMaterial
        return invalid("#{id} standard material?", mth, 0) if layer.empty?

        layer = layer.get
        k     = layer.thickness / ro
        layer.setConductivity(k)
      elsif ro > 0 # multiple layers, adjust insulating layer thickness
        lyr = insulatingLayer(c)
        return invalid("#{id} construction", mth, 0) if lyr[:index].nil?
        return invalid("#{id} construction", mth, 0) if lyr[:type ].nil?
        return invalid("#{id} construction", mth, 0) if lyr[:r    ].zero?

        layer = c.getLayer(lyr[:index]).to_StandardOpaqueMaterial
        return invalid("#{id} standard material", mth, 0) if layer.empty?

        layer = layer.get
        d     = layer.thickness
        k     = layer.conductivity
        d     = (ro - rsi(c) + lyr[:r]) * k
        nom   = layer.nameString.gsub(/[^a-z]/i, "")
        nom  += format("%03d", d*1000)[-3..-1]
        layer.setName(nom)
        layer.setThickness(d)
      end
    end

    c
  end

  ##
  # Generate a solar shade (e.g. roller, textile) for glazed sub surfaces,
  # controlled to minimize overheating in cooling months (Northern Hemisphere,
  # i.e. May to October), when outdoor dry bulb temperature is above 18°C and
  # impinging solar radiation is above 100 W/m2). For SDK v3.2.1 and up.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param subs [OpenStudio::Model::SubSurfaceVector] list of sub surfaces
  #
  # @return [Bool] true if successful
  def genShade(model = nil, subs = OpenStudio::Model::SubSurfaceVector.new)
    mth = "OSut::#{__callee__}"
    v   = OpenStudio.openStudioVersion.split(".").join.to_i
    cl1 = OpenStudio::Model::Model
    cl2 = OpenStudio::Model::SubSurfaceVector
    no  = false

    # Log/exit if invalid arguments.
    return mismatch("model", model, cl1, mth, ERR, no) unless model.is_a?(cl1)
    return mismatch("subs ", subs,  cl2, mth, ERR, no) unless subs.is_a?(cl2)
    return empty(   "subs",              mth, WRN, no)     if subs.empty?
    return no if v < 321

    # Shading availability period.
    onoff = model.getScheduleTypeLimitsByName("onoff")

    if onoff.empty?
      onoff = OpenStudio::Model::ScheduleTypeLimits.new(model)
      onoff.setName("onoff")
      onoff.setLowerLimitValue(0)
      onoff.setUpperLimitValue(1)
      onoff.setNumericType("Discrete")
      onoff.setUnitType("Availability")
    else
      onoff = onoff.get
    end

    # Shading schedule.
    may     = OpenStudio::MonthOfYear.new("May")
    october = OpenStudio::MonthOfYear.new("Oct")
    start   = OpenStudio::Date.new(may, 1)
    finish  = OpenStudio::Date.new(october, 31)

    shade_sch = OpenStudio::Model::ScheduleRuleset.new(model, 0)
    shade_sch.setName("shade_sch")
    shade_sch.setScheduleTypeLimits(onoff)
    shade_sch.defaultDaySchedule.setName("shade_sch_dft")

    shade_cooling_rule = OpenStudio::Model::ScheduleRule.new(shade_sch)
    shade_cooling_rule.setName("shade_cooling_rule")
    shade_cooling_rule.setStartDate(start)
    shade_cooling_rule.setEndDate(finish)
    shade_cooling_rule.setApplyAllDays(true)
    shade_cooling_rule.daySchedule.setName("shade_sch_cooling")
    shade_cooling_rule.daySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 1)

    shd = OpenStudio::Model::Shade.new(model)
    shd.setName("shade")

    ctl = OpenStudio::Model::ShadingControl.new(shd)
    ctl.setName("shade_control")
    ctl.setSchedule(shade_sch)
    ctl.setShadingControlType("OnIfHighOutdoorAirTempAndHighSolarOnWindow")
    ctl.setSetpoint(18)   # °C
    ctl.setSetpoint2(100) # W/m2
    ctl.setMultipleSurfaceControlType("Group")

    # Setting setpoint (#1) triggers the following (apparently benign) warning:
    #
    #   [openstudio.model.ShadingControl] <0> Object of type 'OS:ShadingControl'
    #   and named 'shade_control' has a Shading Control Type
    #   'OnIfHighOutdoorAirTempAndHighSolarOnWindow' which does require a
    #   Setpoint, not resetting it
    #
    #   github.com/NREL/OpenStudio/blob/872300de73e3223f0d541269def844b6250a3ed0
    #   /src/model/ShadingControl.cpp#L334
    #
    # This appears to be the calling point:
    #
    #   github.com/NREL/OpenStudio/blob/872300de73e3223f0d541269def844b6250a3ed0
    #   /src/model/ShadingControl.cpp#L274
    #
    # Hopefully, SDK devs could comment out the stdout warning everytime
    # resetSetpoint() is called.

    ctl.setSubSurfaces(subs)
  end

  ##
  # Generate an internal mass definition and internal mass instances for
  # selected spaces.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param spaces [Array] OpenStudio spaces
  # @param ratio [Double] internal mass surface area / floor area
  #
  # @return [Bool] true if successful
  def genMass(model = nil, spaces = [], ratio = 2.0)
    # This is largely adapted from OpenStudio-Standards
    #
    # https://github.com/NREL/openstudio-standards/blob/
    # d332605c2f7a35039bf658bf55cad40a7bcac317/lib/openstudio-standards/
    # prototypes/common/objects/Prototype.Model.rb#L786

    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::Model
    cl2 = Array
    cl3 = Numeric
    cl4 = OpenStudio::Model::Space
    no  = false

    # Log/exit if invalid arguments.
    return mismatch("model", model, cl1, mth, ERR, no) unless model.is_a?(cl1)
    return mismatch("spaces", spaces, cl2, mth, ERR, no) unless spaces.is_a?(cl2)
    return mismatch("ratio", ratio, cl3, mth, ERR, no) unless ratio.is_a?(cl3)
    return empty(   "spaces", mth, WRN, no) if spaces.empty?
    return negative("ratio", mth, ERR, no) if ratio < 0

    spaces.each do |space|
      return mismatch("space", space, cl4, mth, ERR, no) unless space.is_a?(cl4)
    end

    # A single material.
    mat = "m:mass"
    m_mass = model.getOpaqueMaterialByName(mat)

    if m_mass.empty?
      m_mass = OpenStudio::Model::StandardOpaqueMaterial.new(model)
      m_mass.setName(mat)
      m_mass.setRoughness("MediumRough")
      m_mass.setThickness(0.15)
      m_mass.setConductivity(1.12)
      m_mass.setDensity(540)
      m_mass.setSpecificHeat(1210)
      m_mass.setThermalAbsorptance(0.9)
      m_mass.setSolarAbsorptance(0.7)
      m_mass.setVisibleAbsorptance(0.17)
    else
      m_mass = m_mass.get
    end

    # A single, 1x layered construction.
    construction = "c:mass"
    c_mass = model.getConstructionByName(construction)

    if c_mass.empty?
      c_mass = OpenStudio::Model::Construction.new(model)
      c_mass.setName(construction)
      layers = OpenStudio::Model::MaterialVector.new
      layers << m_mass
      c_mass.setLayers(layers)
    else
      c_mass = c_mass.get
    end

    id = "mass definition:" + (format "%.2f", ratio)
    definition = model.getInternalMassDefinitionByName(id)

    if definition.empty?
      definition = OpenStudio::Model::InternalMassDefinition.new(model)
      definition.setName(id)
      definition.setConstruction(c_mass)
      definition.setSurfaceAreaperSpaceFloorArea(ratio)
    else
      definition = definition.get
    end

    spaces.each do |space|
      mass = OpenStudio::Model::InternalMass.new(definition)
      mass.setName("mass:#{space.nameString}")
      mass.setSpace(space)
    end

    true
  end

  # This next set of utilities (~750 lines) help distinguishing spaces that
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
  # Return 'width' of a planar surface.
  #
  # @param s [OpenStudio::Model::PlanarSurface] a planar surface
  #
  # @return [Double] planar surface (left-to-right) width; 0 if invalid inputs
  def width(s = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::PlanarSurface

    return mismatch("surface", s, cl, mth, DBG, 0) unless s.is_a?(cl)
    return zero("surface area", mth, DBG, 0)           if s.grossArea < TOL

    tr = OpenStudio::Transformation.alignFace(s.vertices)

    (tr.inverse * s.vertices).max_by(&:x).x
  end

  ##
  # Return 'height' of a planar surface, viewed perpendicularly (vs space or
  # building XYZ coordinates).
  #
  # @param s [OpenStudio::Model::PlanarSurface] a planar surface
  #
  # @return [Double] planar surface (top-to-bottom) height; 0 if invalid inputs
  def height(s = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::PlanarSurface

    return mismatch("surface", s, cl, mth, DBG, 0) unless s.is_a?(cl)
    return zero("surface area", mth, DBG, 0)           if s.grossArea < TOL

    tr = OpenStudio::Transformation.alignFace(s.vertices)

    (tr.inverse * s.vertices).max_by(&:y).y
  end

  ##
  # Return array of space-specific OpenStudio::Model::Surface's that match
  # criteria (e.g. exterior, north-east facing walls in hotel "lobby"). Note
  # 'sides' rely on space coordinates (not absolute model coordinates). And
  # 'sides' are exclusive, not inclusive (e.g. walls that are strictly
  # north-facing or strictly east-facing would not be returned if 'sides' holds
  # [:north, :east]).
  #
  # @param spaces [Array] targeted OpenStudio::Model::Space's
  # @param boundary [String] OpenStudio outside boundary condition
  # @param type [String] OpenStudio surface type
  # @param sides [Arrayl] surface direction keys, e.g. [:north, :top, :bottom]
  #
  # @return [Array] matching OpenStudio::Model::Surface's (empty if fail)
  def facets(spaces = [], boundary = "Outdoors", type = "Wall", sides = [])
    faces    = []
    list     = [:bottom, :top, :north, :east, :south, :west].freeze
    boundary = boundary.downcase
    type     = type.downcase
    return [] unless spaces.respond_to?(:&)
    return [] unless boundary.respond_to?(:to_s)
    return [] unless type.respond_to?(:to_s)
    return [] unless sides.respond_to?(:&)

    spaces.each { |s| return [] unless s.respond_to?(:setSpaceType) }

    # Skip empty sides.
    return [] if sides.empty?

    # Keep valid sides.
    orientations = sides.select {|o| list.include?(o)}
    return [] if orientations.empty?

    spaces.each do |space|
      space.surfaces.each do |s|
        next unless s.outsideBoundaryCondition.downcase == boundary
        next unless s.surfaceType.downcase == type

        sidez = []
        sidez << :top    if s.outwardNormal.z >  TOL
        sidez << :bottom if s.outwardNormal.z < -TOL
        sidez << :north  if s.outwardNormal.y >  TOL
        sidez << :east   if s.outwardNormal.x >  TOL
        sidez << :south  if s.outwardNormal.y < -TOL
        sidez << :west   if s.outwardNormal.x < -TOL
        ok = true
        orientations.each { |o| ok = false unless sidez.include?(o) }
        faces << s if ok
      end
    end

    faces
  end

  ##
  # Generates an OpenStudio 3D point vector of a composite floor "slab", a
  # 'union' of multiple rectangular, horizontal floor "plates". Each "plate" is
  # a Hash holding 4x keys: :x & :y coordinates of the origin (i.e. bottom-left
  # corner of each plate), and :dx & :dy (plate width and depth). Each plate
  # must also either encompass or overlap (or share an adge with) any of the
  # preceding plates in the array. The resulting vector (or "slab") is empty
  # if input is invalid.
  #
  # @param pltz [Array] individual plate Hashes
  # @param z [Double] Z-axis coordinate
  #
  # @return [OpenStudio::Point3dVector] new floor vertices; empty if fail
  def genSlab(pltz = [], z = 0)
    mth = "OSut::#{__callee__}"
    slb = OpenStudio::Point3dVector.new
    bkp = OpenStudio::Point3dVector.new
    cl1 = Array
    cl2 = Hash
    cl3 = Numeric

    # Input validation.
    return mismatch("plates", pltz, cl1, mth, DBG, slb) unless pltz.is_a?(cl1)

    pltz.each_with_index do |plt, i|
      id = "plate # #{i+1} (index #{i})"

      return mismatch(id, plt, cl1, mth, DBG, slb) unless plt.is_a?(cl2)
      return hashkey( id, plt,  :x, mth, DBG, slb) unless plt.key?(:x )
      return hashkey( id, plt,  :y, mth, DBG, slb) unless plt.key?(:y )
      return hashkey( id, plt, :dx, mth, DBG, slb) unless plt.key?(:dx)
      return hashkey( id, plt, :dy, mth, DBG, slb) unless plt.key?(:dy)

      x  = plt[:x ]
      y  = plt[:y ]
      dx = plt[:dx]
      dy = plt[:dy]

      return mismatch("#{id} X",   x, cl3, mth, DBG, slb) unless  x.is_a?(cl3)
      return mismatch("#{id} Y",   y, cl3, mth, DBG, slb) unless  y.is_a?(cl3)
      return mismatch("#{id} dX", dx, cl3, mth, DBG, slb) unless dx.is_a?(cl3)
      return mismatch("#{id} dY", dy, cl3, mth, DBG, slb) unless dy.is_a?(cl3)
      return zero(    "#{id} dX",          mth, ERR, slb)     if dx.abs < TOL
      return zero(    "#{id} dY",          mth, ERR, slb)     if dy.abs < TOL
    end

    # Join plates.
    pltz.each_with_index do |plt, i|
      id = "plate # #{i+1} (index #{i})"
      x  = plt[:x ]
      y  = plt[:y ]
      dx = plt[:dx]
      dy = plt[:dy]

      # Adjust X if dX < 0.
      x -= -dx if dx < 0
      dx = -dx if dx < 0

      # Adjust Y if dY < 0.
      y -= -dy if dy < 0
      dy = -dy if dy < 0

      vtx  = []
      vtx << OpenStudio::Point3d.new(x + dx, y + dy, 0)
      vtx << OpenStudio::Point3d.new(x + dx, y,      0)
      vtx << OpenStudio::Point3d.new(x,      y,      0)
      vtx << OpenStudio::Point3d.new(x,      y + dy, 0)

      if slb.empty?
        slb = vtx
      else
        slab = OpenStudio.join(slb, vtx, TOL2)
        slb  = slab.get                  unless slab.empty?
        return invalid(id, mth, 0, ERR, bkp) if slab.empty?
      end
    end

    # Once joined, re-adjust Z-axis coordinates.
    unless z.zero?
      vtx = OpenStudio::Point3dVector.new
      slb.each { |pt| vtx << OpenStudio::Point3d.new(pt.x, pt.y, z) }
      slb = vtx
    end

    slb
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
    max_x   = aligned.max_by(&:x).x # same as OSut.width(s)
    max_y   = aligned.max_by(&:y).y # same as OSut.height(s)
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
      # sub[:head      ] # e.g. std 80" door + frame/buffers (+ m)
      # sub[:sill      ] # e.g. std 30" sill + frame/buffers (+ m)
      # sub[:height    ] # any sub surface height, below "head" (+ m)
      # sub[:width     ] # e.g. 1.200 m
      # sub[:offset    ] # if array (+ m)
      # sub[:centreline] # left or right of base surface centreline (+/- m)
      # sub[:r_buffer  ] # buffer between sub/array and right-side corner (+ m)
      # sub[:l_buffer  ] # buffer between sub/array and left-side corner (+ m)

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
    #   :head       e.g. std 80" door + frame/buffers (+ m)
    #   :sill       e.g. std 30" sill + frame/buffers (+ m)
    #   :height     any sub surface height, below "head" (+ m)
    #   :width      e.g. 1.200 m
    #   :offset     if array (+ m)
    #   :centreline left or right of base surface centreline (+/- m)
    #   :r_buffer   buffer between sub/array and right-side corner (+ m)
    #   :l_buffer   buffer between sub/array and left-side corner (+ m)
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

      # Log/reset if left-sided buffer under min jamb position.
      if sub.key?(:l_buffer)
        if sub[:l_buffer] < min_ljamb
          sub[:l_buffer] = min_ljamb
          log(WRN, "Reset '#{id}' left buffer to #{sub[:l_buffer]} m (#{mth})")
        end
      end

      # Log/reset if right-sided buffer beyond max jamb position.
      if sub.key?(:r_buffer)
        if sub[:r_buffer] > max_rjamb
          sub[:r_buffer] = min_rjamb
          log(WRN, "Reset '#{id}' right buffer to #{sub[:r_buffer]} m (#{mth})")
        end
      end

      centre  = mid_x
      centre += sub[:centreline] if sub.key?(:centreline)
      n       = sub[:count     ]
      h       = sub[:height    ] + frames
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

        area  = s.grossArea * sub[:ratio] # sub m2, including (optional) frames
        w     = area / h
        width = w - frames
        x0    = centre - w/2
        xf    = centre + w/2

        if sub.key?(:l_buffer)
          if sub.key?(:centreline)
            log(WRN, "Skip #{id} left buffer (vs centreline) (#{mth})")
          else
            x0     = sub[:l_buffer] - frame
            xf     = x0 + w
            centre = x0 + w/2
          end
        elsif sub.key?(:r_buffer)
          if sub.key?(:centreline)
            log(WRN, "Skip #{id} right buffer (vs centreline) (#{mth})")
          else
            xf     = max_x - sub[:r_buffer] + frame
            x0     = xf - w
            centre = x0 + w/2
          end
        end

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

        # Overall width (including frames) of bounding box around array.
        w  = n * width + (n - 1) * gap
        x0 = centre - w/2
        xf = centre + w/2

        if sub.key?(:l_buffer)
          if sub.key?(:centreline)
            log(WRN, "Skip #{id} left buffer (vs centreline) (#{mth})")
          else
            x0     = sub[:l_buffer] - frame
            xf     = x0 + w
            centre = x0 + w/2
          end
        elsif sub.key?(:r_buffer)
          if sub.key?(:centreline)
            log(WRN, "Skip #{id} right buffer (vs centreline) (#{mth})")
          else
            xf     = max_x - sub[:r_buffer] + frame
            x0     = xf - w
            centre = x0 + w/2
          end
        end

        # Too wide?
        if x0 < bfr || xf > max_x - bfr
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
      pos = x0 + frame

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
