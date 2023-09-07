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
  # DEBUG for devs; WARN/ERROR for users (bad OS input), see OSlg
  extend OSlg

  TOL  = 0.01         # default distance tolerance (m)
  TOL2 = TOL * TOL    # default area tolerance (m2)
  DBG  = OSlg::DEBUG  # see github.com/rd2/oslg
  INF  = OSlg::INFO   # see github.com/rd2/oslg
  WRN  = OSlg::WARN   # see github.com/rd2/oslg
  ERR  = OSlg::ERROR  # see github.com/rd2/oslg
  FTL  = OSlg::FATAL  # see github.com/rd2/oslg
  NS   = "nameString" # OpenStudio object identifier method

  HEAD = 2.032 # standard 80" door
  SILL = 0.762 # standard 30" window sill

  # This first set of utilities support OpenStudio materials, constructions,
  # construction sets, etc. If relying on default StandardOpaqueMaterial:
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
  # ... apart from surface roughness, rarely would these material properties be
  # suitable - and are therefore explicitely set below. On roughness:
  #   - "Very Rough"    : stucco
  #   - "Rough"	        : brick
  #   - "Medium Rough"  : concrete
  #   - "Medium Smooth" : clear pine
  #   - "Smooth"        : smooth plaster
  #   - "Very Smooth"   : glass

  # thermal mass categories (e.g. exterior cladding, interior finish, framing)
  @@mass = [
      :none, # token for 'no user selection', resort to defaults
     :light, # e.g. 16mm drywall interior
    :medium, # e.g. 100mm brick cladding
     :heavy  # e.g. 200mm poured concrete
  ].freeze

  # basic materials (StandardOpaqueMaterials only)
  @@mats = {
        sand: {},
    concrete: {},
       brick: {},
    cladding: {}, # e.g. lightweight cladding over furring
   sheathing: {}, # e.g. plywood
     polyiso: {}, # e.g. polyisocyanurate panel (or similar)
   cellulose: {}, # e.g. blown, dry/stabilized fiber
     mineral: {}, # e.g. semi-rigid rock wool insulation
     drywall: {},
        door: {}  # single composite material (45mm insulated steel door)
  }.freeze

  # default inside+outside air film resistances (m2.K/W)
  @@film = {
      shading: 0.000, # NA
    partition: 0.000,
         wall: 0.150,
         roof: 0.140,
        floor: 0.190,
     basement: 0.120,
         slab: 0.160,
         door: 0.150,
       window: 0.150, # ignored if SimpleGlazingMaterial
     skylight: 0.140  # ignored if SimpleGlazingMaterial
  }.freeze

  # default (~1980s) envelope Uo (W/m2•K), based on surface type
  @@uo = {
      shading: 0.000, # N/A
    partition: 0.000, # N/A
         wall: 0.384, # rated Ro ~14.8 hr•ft2F/Btu
         roof: 0.327, # rated Ro ~17.6 hr•ft2F/Btu
        floor: 0.317, # rated Ro ~17.9 hr•ft2F/Btu (exposed floor)
     basement: 0.000, # uninsulated
         slab: 0.000, # uninsulated
         door: 1.800, # insulated, unglazed steel door (single layer)
       window: 2.800, # e.g. patio doors (simple glazing)
     skylight: 3.500  # all skylight technologies
  }.freeze

  # Standard opaque materials, taken from a variety of sources (e.g. energy
  # codes, NREL's BCL). Material identifiers are symbols, e.g.:
  #   - :brick
  #   - :sand
  #   - :concrete
  #
  # Material properties remain largely constant between projects. What does
  # tend to vary (between projects) are thicknesses. Actual OpenStudio opaque
  # material objects can be (re)set in more than one way by class methods.
  # In genConstruction, OpenStudio object identifiers are later suffixed with
  # actual material thicknesses, in mm, e.g.:
  #   - "concrete200" : 200mm concrete slab
  #   - "drywall13"   : 1/2" gypsum board
  #   - "drywall16"   : 5/8" gypsum board
  #
  # Surface absorptances are also defaulted in OpenStudio:
  #   - thermal, long-wave   (thm) : 90%
  #   - solar                (sol) : 70%
  #   - visible              (vis) : 70%
  #
  # These can also be explicitly set, here (e.g. a redundant 'sand' example):
  @@mats[:sand     ][:rgh] = "Rough"
  @@mats[:sand     ][:k  ] =    1.290
  @@mats[:sand     ][:rho] = 2240.000
  @@mats[:sand     ][:cp ] =  830.000
  @@mats[:sand     ][:thm] =    0.900
  @@mats[:sand     ][:sol] =    0.700
  @@mats[:sand     ][:vis] =    0.700

  @@mats[:concrete ][:rgh] = "MediumRough"
  @@mats[:concrete ][:k  ] =    1.730
  @@mats[:concrete ][:rho] = 2240.000
  @@mats[:concrete ][:cp ] =  830.000

  @@mats[:brick    ][:rgh] = "Rough"
  @@mats[:brick    ][:k  ] =    0.675
  @@mats[:brick    ][:rho] = 1600.000
  @@mats[:brick    ][:cp ] =  790.000

  @@mats[:cladding ][:rgh] = "MediumSmooth"
  @@mats[:cladding ][:k  ] =    0.115
  @@mats[:cladding ][:rho] =  540.000
  @@mats[:cladding ][:cp ] = 1200.000

  @@mats[:sheathing][:k  ] =    0.160
  @@mats[:sheathing][:rho] =  545.000
  @@mats[:sheathing][:cp ] = 1210.000

  @@mats[:polyiso  ][:k  ] =    0.025
  @@mats[:polyiso  ][:rho] =   25.000
  @@mats[:polyiso  ][:cp ] = 1590.000

  @@mats[:cellulose][:rgh] = "VeryRough"
  @@mats[:cellulose][:k  ] =    0.050
  @@mats[:cellulose][:rho] =   80.000
  @@mats[:cellulose][:cp ] =  835.000

  @@mats[:mineral  ][:k  ] =    0.050
  @@mats[:mineral  ][:rho] =   19.000
  @@mats[:mineral  ][:cp ] =  960.000

  @@mats[:drywall  ][:k  ] =    0.160
  @@mats[:drywall  ][:rho] =  785.000
  @@mats[:drywall  ][:cp ] = 1090.000

  @@mats[:door     ][:rgh] = "MediumSmooth"
  @@mats[:door     ][:k  ] =    0.080
  @@mats[:door     ][:rho] =  600.000
  @@mats[:door     ][:cp ] = 1000.000

  ##
  # Generates an OpenStudio multilayered construction; materials if needed.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param [Hash] specs OpenStudio construction specifications
  # @option specs [#to_s] :id ("") construction identifier
  # @option specs [Symbol] :type (:wall), see @@uo
  # @option specs [Numeric] :uo clear-field Uo, in W/m2.K, see @@uo
  # @option specs [Symbol] :clad (:light) exterior cladding, see @@mass
  # @option specs [Symbol] :frame (:light) assembly framing, see @@mass
  # @option specs [Symbol] :finish (:light) interior finishing, see @@mass
  #
  # @return [OpenStudio::Model::Construction] generated construction
  # @return [nil] if invalid inputs (see logs)
  def genConstruction(model = nil, specs = {})
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::Model
    cl2 = Hash
    return mismatch("model", model, cl1, mth) unless model.is_a?(cl1)
    return mismatch("specs", specs, cl2, mth) unless specs.is_a?(cl2)

    specs[:id  ] = ""    unless specs.key?(:id  )
    specs[:type] = :wall unless specs.key?(:type)
    chk = @@uo.keys.include?(specs[:type])
    return invalid("surface type", mth, 2, ERR) unless chk

    id = trim(specs[:id])
    id = "OSut|CON|#{specs[:type]}"       if id.empty?
    specs[:uo] = @@uo[ specs[:type] ] unless specs.key?(:uo)
    u = specs[:uo]
    return mismatch("#{id} Uo", u, Numeric, mth)  unless u.is_a?(Numeric)
    return invalid("#{id} Uo (> 5.678)", mth, 2, ERR) if u > 5.678
    return negative("#{id} Uo"         , mth,    ERR) if u < 0

    # Optional specs. Log/reset if invalid.
    specs[:clad  ] = :light             unless specs.key?(:clad  ) # exterior
    specs[:frame ] = :light             unless specs.key?(:frame )
    specs[:finish] = :light             unless specs.key?(:finish) # interior
    log(WRN, "Reset to light cladding") unless @@mass.include?(specs[:clad  ])
    log(WRN, "Reset to light framing" ) unless @@mass.include?(specs[:frame ])
    log(WRN, "Reset to light finish"  ) unless @@mass.include?(specs[:finish])
    specs[:clad  ] = :light             unless @@mass.include?(specs[:clad  ])
    specs[:frame ] = :light             unless @@mass.include?(specs[:frame ])
    specs[:finish] = :light             unless @@mass.include?(specs[:finish])

    film = @@film[ specs[:type] ]

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
      a[:compo][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
    when :partition
      d  = 0.015
      mt = :drywall
      a[:clad][:mat] = @@mats[mt]
      a[:clad][:d  ] = d
      a[:clad][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

      mt = :sheathing
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

      mt = :drywall
      a[:finish][:mat] = @@mats[mt]
      a[:finish][:d  ] = d
      a[:finish][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
    when :wall
      unless specs[:clad] == :none
        mt = :cladding
        mt = :brick    if specs[:clad] == :medium
        mt = :concrete if specs[:clad] == :heavy
        d  = 0.100
        d  = 0.015     if specs[:clad] == :light
        a[:clad][:mat] = @@mats[mt]
        a[:clad][:d  ] = d
        a[:clad][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
      end

      mt = :drywall
      mt = :polyiso   if specs[:frame] == :medium
      mt = :mineral   if specs[:frame] == :heavy
      d  = 0.100
      d  = 0.015      if specs[:frame] == :light
      a[:sheath][:mat] = @@mats[mt]
      a[:sheath][:d  ] = d
      a[:sheath][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

      mt = :concrete
      mt = :mineral   if specs[:frame] == :light
      d  = 0.100
      d  = 0.200      if specs[:frame] == :heavy
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:finish] == :none
        mt = :concrete
        mt = :drywall   if specs[:finish] == :light
        d  = 0.015
        d  = 0.100      if specs[:finish] == :medium
        d  = 0.200      if specs[:finish] == :heavy
        a[:finish][:mat] = @@mats[mt]
        a[:finish][:d  ] = d
        a[:finish][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
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
        a[:clad][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

        mt = :sheathing
        d  = 0.015
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
      end

      mt = :cellulose
      mt = :polyiso   if specs[:frame] == :medium
      mt = :mineral   if specs[:frame] == :heavy
      d  = 0.100
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:finish] == :none
        mt = :concrete
        mt = :drywall   if specs[:finish] == :light
        d  = 0.015
        d  = 0.100      if specs[:finish] == :medium # proxy for steel decking
        d  = 0.200      if specs[:finish] == :heavy
        a[:finish][:mat] = @@mats[mt]
        a[:finish][:d  ] = d
        a[:finish][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
      end
    when :floor # exposed
      unless specs[:clad] == :none
        mt = :cladding
        d  = 0.015
        a[:clad][:mat] = @@mats[mt]
        a[:clad][:d  ] = d
        a[:clad][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

        mt = :sheathing
        d  = 0.015
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
      end

      mt = :cellulose
      mt = :polyiso   if specs[:frame] == :medium
      mt = :mineral   if specs[:frame] == :heavy
      d  = 0.100 # possibly an insulating layer to reset
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:finish] == :none
        mt = :concrete
        mt = :sheathing if specs[:finish] == :light
        d  = 0.015
        d  = 0.100      if specs[:finish] == :medium
        d  = 0.200      if specs[:finish] == :heavy
        a[:finish][:mat] = @@mats[mt]
        a[:finish][:d  ] = d
        a[:finish][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
      end
    when :slab # basement slab or slab-on-grade
      mt = :sand
      d  = 0.100
      a[:clad][:mat] = @@mats[mt]
      a[:clad][:d  ] = d
      a[:clad][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:frame] == :none
        mt = :polyiso
        d  = 0.025
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
      end

      mt = :concrete
      d  = 0.100
      d  = 0.200      if specs[:frame] == :heavy
      a[:compo][:mat] = @@mats[mt]
      a[:compo][:d  ] = d
      a[:compo][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

      unless specs[:finish] == :none
        mt = :sheathing
        d  = 0.015
        a[:finish][:mat] = @@mats[mt]
        a[:finish][:d  ] = d
        a[:finish][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
      end
    when :basement # wall
      unless specs[:clad] == :none
        mt = :concrete
        mt = :sheathing if specs[:clad] == :light
        d  = 0.100
        d  = 0.015      if specs[:clad] == :light
        a[:clad][:mat] = @@mats[mt]
        a[:clad][:d  ] = d
        a[:clad][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

        mt = :polyiso
        d  = 0.025
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

        mt = :concrete
        d  = 0.200
        a[:compo][:mat] = @@mats[mt]
        a[:compo][:d  ] = d
        a[:compo][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
      else
        mt = :concrete
        d  = 0.200
        a[:sheath][:mat] = @@mats[mt]
        a[:sheath][:d  ] = d
        a[:sheath][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

        unless specs[:finish] == :none
          mt = :mineral
          d  = 0.075
          a[:compo][:mat] = @@mats[mt]
          a[:compo][:d  ] = d
          a[:compo][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"

          mt = :drywall
          d  = 0.015
          a[:finish][:mat] = @@mats[mt]
          a[:finish][:d  ] = d
          a[:finish][:id ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
        end
      end
    when :door # opaque
      # 45mm insulated (composite) steel door.
      mt = :door
      d  = 0.045

      a[:compo  ][:mat ] = @@mats[mt]
      a[:compo  ][:d   ] = d
      a[:compo  ][:id  ] = "OSut|#{mt}|#{format('%03d', d*1000)[-3..-1]}"
    when :window # e.g. patio doors (simple glazing)
      # SimpleGlazingMaterial.
      a[:glazing][:u   ]  = specs[:uo  ]
      a[:glazing][:shgc]  = 0.450
      a[:glazing][:shgc]  = specs[:shgc] if specs.key?(:shgc)
      a[:glazing][:id  ]  = "OSut|window"
      a[:glazing][:id  ] += "|U#{format('%.1f', a[:glazing][:u])}"
      a[:glazing][:id  ] += "|SHGC#{format('%d', a[:glazing][:shgc]*100)}"
    when :skylight
      # SimpleGlazingMaterial.
      a[:glazing][:u   ] = specs[:uo  ]
      a[:glazing][:shgc] = 0.450
      a[:glazing][:shgc] = specs[:shgc] if specs.key?(:shgc)
      a[:glazing][:id  ]  = "OSut|skylight"
      a[:glazing][:id  ] += "|U#{format('%.1f', a[:glazing][:u])}"
      a[:glazing][:id  ] += "|SHGC#{format('%d', a[:glazing][:shgc]*100)}"
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

        index = lyr[:index]
        layer = c.getLayer(index).to_StandardOpaqueMaterial
        return invalid("#{id} material @#{index}", mth, 0) if layer.empty?

        layer = layer.get
        k     = layer.conductivity
        d     = (ro - rsi(c) + lyr[:r]) * k
        return invalid("#{id} adjusted m", mth, 0) if d < 0.03

        nom   = "OSut|"
        nom  += layer.nameString.gsub(/[^a-z]/i, "").gsub("OSut", "")
        nom  += "|"
        nom  += format("%03d", d*1000)[-3..-1]
        layer.setName(nom) if model.getStandardOpaqueMaterialByName(nom).empty?
        layer.setThickness(d)
      end
    end

    c
  end

  ##
  # Generates a solar shade (e.g. roller, textile) for glazed OpenStudio
  # SubSurfaces (v351+), controlled to minimize overheating in cooling months
  # (May to October in Northern Hemisphere), when outdoor dry bulb temperature
  # is above 18°C and impinging solar radiation is above 100 W/m2.
  #
  # @param subs [OpenStudio::Model::SubSurfaceVector] sub surfaces
  #
  # @return [Bool] whether successfully generated
  # @return [false] if invalid input (see logs)
  def genShade(subs = OpenStudio::Model::SubSurfaceVector.new)
    # Filter OpenStudio warnings for ShadingControl:
    #   ref: https://github.com/NREL/OpenStudio/issues/4911
    str = ".*(?<!ShadingControl)$"
    OpenStudio::Logger.instance.standardOutLogger.setChannelRegex(str)

    mth = "OSut::#{__callee__}"
    v   = OpenStudio.openStudioVersion.split(".").join.to_i
    cl  = OpenStudio::Model::SubSurfaceVector
    return mismatch("subs ", subs,  cl2, mth, DBG, false) unless subs.is_a?(cl)
    return empty(   "subs",              mth, WRN, false)     if subs.empty?
    return false                                              if v < 321

    # Shading availability period.
    mdl   = subs.first.model
    id    = "onoff"
    onoff = mdl.getScheduleTypeLimitsByName(id)

    if onoff.empty?
      onoff = OpenStudio::Model::ScheduleTypeLimits.new(mdl)
      onoff.setName(id)
      onoff.setLowerLimitValue(0)
      onoff.setUpperLimitValue(1)
      onoff.setNumericType("Discrete")
      onoff.setUnitType("Availability")
    else
      onoff = onoff.get
    end

    # Shading schedule.
    id  = "OSut|SHADE|Ruleset"
    sch = mdl.getScheduleRulesetByName(id)

    if sch.empty?
      sch = OpenStudio::Model::ScheduleRuleset.new(mdl, 0)
      sch.setName(id)
      sch.setScheduleTypeLimits(onoff)
      sch.defaultDaySchedule.setName("OSut|Shade|Ruleset|Default")
    else
      sch = sch.get
    end

    # Summer cooling rule.
    id   = "OSut|SHADE|ScheduleRule"
    rule = mdl.getScheduleRuleByName(id)

    if rule.empty?
      may     = OpenStudio::MonthOfYear.new("May")
      october = OpenStudio::MonthOfYear.new("Oct")
      start   = OpenStudio::Date.new(may, 1)
      finish  = OpenStudio::Date.new(october, 31)

      rule = OpenStudio::Model::ScheduleRule.new(sch)
      rule.setName(id)
      rule.setStartDate(start)
      rule.setEndDate(finish)
      rule.setApplyAllDays(true)
      rule.daySchedule.setName("OSut|Shade|Rule|Default")
      rule.daySchedule.addValue(OpenStudio::Time.new(0,24,0,0), 1)
    else
      rule = rule.get
    end

    # Shade object.
    id  = "OSut|Shade"
    shd = mdl.getShadeByName(id)

    if shd.empty?
      shd = OpenStudio::Model::Shade.new(mdl)
      shd.setName(id)
    else
      shd = shd.get
    end

    # Shading control (unique to each call).
    id  = "OSut|ShadingControl"
    ctl = OpenStudio::Model::ShadingControl.new(shd)
    ctl.setName(id)
    ctl.setSchedule(sch)
    ctl.setShadingControlType("OnIfHighOutdoorAirTempAndHighSolarOnWindow")
    ctl.setSetpoint(18)   # °C
    ctl.setSetpoint2(100) # W/m2
    ctl.setMultipleSurfaceControlType("Group")
    ctl.setSubSurfaces(subs)
  end

  ##
  # Generates an internal mass definition and instances for target spaces.
  #
  # @param sps [OpenStudio::Model::SpaceVector] target spaces
  # @param ratio [Numeric] internal mass surface / floor areas
  #
  # @return [Bool] whether successfully generated
  # @return [false] if invalid input (see logs)
  def genMass(sps = OpenStudio::Model::SpaceVector.new, ratio = 2.0)
    # This is largely adapted from OpenStudio-Standards:
    #
    #   https://github.com/NREL/openstudio-standards/blob/
    #   d332605c2f7a35039bf658bf55cad40a7bcac317/lib/openstudio-standards/
    #   prototypes/common/objects/Prototype.Model.rb#L786
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::SpaceVector
    cl2 = Numeric
    no  = false
    return mismatch("spaces",   sps, cl1, mth, DBG, no) unless sps.is_a?(cl1)
    return mismatch( "ratio", ratio, cl2, mth, DBG, no) unless ratio.is_a?(cl2)
    return empty(   "spaces",             mth, WRN, no)     if sps.empty?
    return negative( "ratio",             mth, ERR, no)     if ratio < 0

    # A single material.
    mdl = sps.first.model
    id  = "OSut|MASS|Material"
    mat = mdl.getOpaqueMaterialByName(id)

    if mat.empty?
      mat = OpenStudio::Model::StandardOpaqueMaterial.new(mdl)
      mat.setName(id)
      mat.setRoughness("MediumRough")
      mat.setThickness(0.15)
      mat.setConductivity(1.12)
      mat.setDensity(540)
      mat.setSpecificHeat(1210)
      mat.setThermalAbsorptance(0.9)
      mat.setSolarAbsorptance(0.7)
      mat.setVisibleAbsorptance(0.17)
    else
      mat = mat.get
    end

    # A single, 1x layered construction.
    id  = "OSut|MASS|Construction"
    con = mdl.getConstructionByName(id)

    if con.empty?
      con = OpenStudio::Model::Construction.new(mdl)
      con.setName(id)
      layers = OpenStudio::Model::MaterialVector.new
      layers << mat
      con.setLayers(layers)
    else
      con = con.get
    end

    id = "OSut|InternalMassDefinition|" + (format "%.2f", ratio)
    df = mdl.getInternalMassDefinitionByName(id)

    if df.empty?
      df = OpenStudio::Model::InternalMassDefinition.new(mdl)
      df.setName(id)
      df.setConstruction(con)
      df.setSurfaceAreaperSpaceFloorArea(ratio)
    else
      df = df.get
    end

    sps.each do |sp|
      mass = OpenStudio::Model::InternalMass.new(df)
      mass.setName("OSut|InternalMass|#{sp.nameString}")
      mass.setSpace(sp)
    end

    true
  end

  ##
  # Validates if a default construction set holds a base construction.
  #
  # @param set [OpenStudio::Model::DefaultConstructionSet] a default set
  # @param bse [OpensStudio::Model::ConstructionBase] a construction base
  # @param gr [Bool] if ground-facing surface
  # @param ex [Bool] if exterior-facing surface
  # @param tp [#to_s] a surface type
  #
  # @return [Bool] whether default set holds construction
  # @return [false] if invalid input (see logs)
  def holdsConstruction?(set = nil, bse = nil, gr = false, ex = false, tp = "")
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::DefaultConstructionSet
    cl2 = OpenStudio::Model::ConstructionBase
    ck1 = set.respond_to?(NS)
    ck2 = bse.respond_to?(NS)
    return invalid("set" , mth, 1, DBG, false) unless ck1
    return invalid("base", mth, 2, DBG, false) unless ck2

    id1 = set.nameString
    id2 = bse.nameString
    ck1 = set.is_a?(cl1)
    ck2 = bse.is_a?(cl2)
    ck3 = [true, false].include?(gr)
    ck4 = [true, false].include?(ex)
    ck5 = tp.respond_to?(:to_s)
    return mismatch(id1, set, cl1, mth,    DBG, false) unless ck1
    return mismatch(id2, bse, cl2, mth,    DBG, false) unless ck2
    return invalid("ground"      , mth, 3, DBG, false) unless ck3
    return invalid("exterior"    , mth, 4, DBG, false) unless ck4
    return invalid("surface type", mth, 5, DBG, false) unless ck5

    type = trim(tp).downcase
    ck1  = ["floor", "wall", "roofceiling"].include?(type)
    return invalid("surface type", mth, 5, DBG, false) unless ck1

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
  # Returns a surface's default construction set.
  #
  # @param s [OpenStudio::Model::Surface] a surface
  #
  # @return [OpenStudio::Model::DefaultConstructionSet] default set
  # @return [nil] if invalid input (see logs)
  def defaultConstructionSet(s = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Surface
    return invalid("surface", mth, 1) unless s.respond_to?(NS)

    id = s.nameString
    ok = s.isConstructionDefaulted
    m1 = "#{id} construction not defaulted (#{mth})"
    m2 = "#{id} construction"
    m3 = "#{id} space"
    return mismatch(id, s, cl, mth) unless s.is_a?(cl)

    log(ERR, m1)           unless ok
    return nil             unless ok
    return empty(m2, mth, ERR) if s.construction.empty?
    return empty(m3, mth, ERR) if s.space.empty?

    mdl      = s.model
    base     = s.construction.get
    space    = s.space.get
    type     = s.surfaceType
    ground   = false
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

    building = mdl.getBuilding

    unless building.defaultConstructionSet.empty?
      set = building.defaultConstructionSet.get
      return set if holdsConstruction?(set, base, ground, exterior, type)
    end

    nil
  end

  ##
  # Validates if every material in a layered construction is standard & opaque.
  #
  # @param lc [OpenStudio::LayeredConstruction] a layered construction
  #
  # @return [Bool] whether all layers are valid
  # @return [false] if invalid input (see logs)
  def standardOpaqueLayers?(lc = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::LayeredConstruction
    return invalid("lc", mth, 1, DBG, false) unless lc.respond_to?(NS)
    return mismatch(lc.nameString, lc, cl, mth, DBG, false) unless lc.is_a?(cl)

    lc.layers.each { |m| return false if m.to_StandardOpaqueMaterial.empty? }

    true
  end

  ##
  # Returns total (standard opaque) layered construction thickness (m).
  #
  # @param lc [OpenStudio::LayeredConstruction] a layered construction
  #
  # @return [Float] construction thickness
  # @return [0.0] if invalid input (see logs)
  def thickness(lc = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::LayeredConstruction
    return invalid("lc", mth, 1, DBG, 0.0) unless lc.respond_to?(NS)

    id = lc.nameString
    return mismatch(id, lc, cl, mth, DBG, 0.0) unless lc.is_a?(cl)

    ok = standardOpaqueLayers?(lc)
    log(ERR, "'#{id}' holds non-StandardOpaqueMaterial(s) (#{mth})")  unless ok
    return 0.0                                                        unless ok

    thickness = 0.0
    lc.layers.each { |m| thickness += m.thickness }

    thickness
  end

  ##
  # Returns total air film resistance of a fenestrated construction (m2•K/W)
  #
  # @param usi [Numeric] a fenestrated construction's U-factor (W/m2•K)
  #
  # @return [Float] total air film resistances
  # @return [0.1216] if invalid input (see logs)
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
    # The EnergyPlus Engineering calculations were designed for vertical
    # windows - not horizontal, slanted or domed surfaces - use with caution.
    mth = "OSut::#{__callee__}"
    cl  = Numeric
    return mismatch("usi", usi, cl, mth,    DBG, 0.1216)  unless usi.is_a?(cl)
    return invalid("usi",           mth, 1, WRN, 0.1216)      if usi > 8.0
    return negative("usi",          mth,    WRN, 0.1216)      if usi < 0
    return zero("usi",              mth,    WRN, 0.1216)      if usi.abs < TOL

    rsi = 1 / (0.025342 * usi + 29.163853) # exterior film, next interior film
    return rsi + 1 / (0.359073 * Math.log(usi) + 6.949915) if usi < 5.85
    return rsi + 1 / (1.788041 * usi - 2.886625)
  end

  ##
  # Returns a construction's 'standard calc' thermal resistance (m2•K/W), which
  # includes air film resistances. It excludes insulating effects of shades,
  # screens, etc. in the case of fenestrated constructions.
  #
  # @param lc [OpenStudio::Model::LayeredConstruction] a layered construction
  # @param film [Numeric] thermal resistance of surface air films (m2•K/W)
  # @param t [Numeric] gas temperature (°C) (optional)
  #
  # @return [Float] layered construction's thermal resistance
  # @return [0.0] if invalid input (see logs)
  def rsi(lc = nil, film = 0.0, t = 0.0)
    # This is adapted from BTAP's Material Module "get_conductance" (P. Lopez)
    #
    #   https://github.com/NREL/OpenStudio-Prototype-Buildings/blob/
    #   c3d5021d8b7aef43e560544699fb5c559e6b721d/lib/btap/measures/
    #   btap_equest_converter/envelope.rb#L122
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::LayeredConstruction
    cl2 = Numeric
    return invalid("lc", mth, 1, DBG, 0.0) unless lc.respond_to?(NS)

    id = lc.nameString
    return mismatch(id,       lc, cl1, mth, DBG, 0.0) unless lc.is_a?(cl1)
    return mismatch("film", film, cl2, mth, DBG, 0.0) unless film.is_a?(cl2)
    return mismatch("temp K",  t, cl2, mth, DBG, 0.0) unless t.is_a?(cl2)

    t += 273.0 # °C to K
    return negative("temp K", mth, ERR, 0.0) if t < 0
    return negative("film",   mth, ERR, 0.0) if film < 0

    rsi = film

    lc.layers.each do |m|
      # Fenestration materials first.
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
  # returns a 3-keyed hash :index, the insulating layer index [0, n layers)
  # within the layered construction; :type, either :standard or :massless; and
  # :r, material thermal resistance in m2•K/W.
  #
  # @param lc [OpenStudio::Model::LayeredConstruction] a layered construction
  #
  # @return [Hash] index: (Integer), type: (Symbol), r: (Float)
  # @return [Hash] index: nil, type: nil, r: 0 if invalid input (see logs)
  def insulatingLayer(lc = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::LayeredConstruction
    res = { index: nil, type: nil, r: 0.0 }
    i   = 0  # iterator
    return invalid("lc", mth, 1, DBG, res) unless lc.respond_to?(NS)

    id   = lc.nameString
    return mismatch(id, lc, cl1, mth, DBG, res) unless lc.is_a?(cl)

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

  # ---- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---- #
  # ---- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---- #
  # This next set of utilities (~850 lines) help distinguish spaces that are
  # directly vs indirectly CONDITIONED, vs SEMIHEATED. The solution here
  # relies as much as possible on space conditioning categories found in
  # standards like ASHRAE 90.1 and energy codes like the Canadian NECBs.
  #
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
  #     - SEMIHEATED space: an ENCLOSED space that has a heating system
  #       >= 10 W/m2, yet NOT a CONDITIONED space (see above).
  #
  #     - UNCONDITIONED space: an ENCLOSED space that is NOT a conditioned
  #       space or a SEMIHEATED space (see above).
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
  # SEMIHEATED spaces are described in the NECB (yet not a defined term). The
  # distinction is also based on desired/intended design space setpoint
  # temperatures (here 15°C) - not system sizing criteria. No further treatment
  # is implemented here to distinguish SEMIHEATED from CONDITIONED spaces;
  # notwithstanding the AdditionalProperties tag (described further in this
  # section), it is up to users to determine if a CONDITIONED space is
  # indeed SEMIHEATED or not (e.g. based on MIN/MAX setpoints).
  #
  # The single NECB criterion distinguishing UNCONDITIONED ENCLOSED spaces
  # (such as vestibules) from UNENCLOSED spaces (such as attics) remains the
  # intention to ventilate - or rather to what degree. Regardless, the methods
  # here are designed to process both classifications in the same way, namely
  # by focusing on adjacent surfaces to CONDITIONED (or SEMIHEATED) spaces as
  # part of the building envelope.

  # In light of the above, OSut methods here are designed without a priori
  # knowledge of explicit system sizing choices or access to iterative
  # autosizing processes. As discussed in greater detail below, methods here
  # are developed to rely on zoning and/or "intended" temperature setpoints.
  # In addition, OSut methods here cannot distinguish between UNCONDITIONED vs
  # UNENCLOSED spaces from OpenStudio geometry alone. They are henceforth
  # considered synonymous.
  #
  # For an OpenStudio model in an incomplete or preliminary state, e.g. holding
  # fully-formed ENCLOSED spaces WITHOUT thermal zoning information or setpoint
  # temperatures (early design stage assessments of form, porosity or
  # envelope), OpenStudio spaces are considered CONDITIONED by default. This
  # default behaviour may be reset based on the (Space) AdditionalProperties
  # "space_conditioning_category" key (4x possible values), which is relied
  # upon by OpenStudio-Standards:
  #
  #   github.com/NREL/openstudio-standards/blob/
  #   d2b5e28928e712cb3f137ab5c1ad6d8889ca02b7/lib/openstudio-standards/
  #   standards/Standards.Space.rb#L1604C5-L1605C1
  #
  # OpenStudio-Standards recognizes 4x possible value strings:
  #   - "NonResConditioned"
  #   - "ResConditioned"
  #   - "Semiheated"
  #   - "Unconditioned"
  #
  # OSut maintains existing "space_conditioning_category" key/value pairs
  # intact. Based on these, OSut methods may return related outputs:
  #
  #   "space_conditioning_category" | OSut status   | heating °C | cooling °C
  # -------------------------------   -------------   ----------   ----------
  #   - "NonResConditioned"           CONDITIONED     21.0         24.0
  #   - "ResConditioned"              CONDITIONED     21.0         24.0
  #   - "Semiheated"                  SEMIHEATED      15.0         NA
  #   - "Unconditioned"               UNCONDITIONED   NA           NA
  #
  # OSut also looks up another (Space) AdditionalProperties 'key',
  # "indirectlyconditioned" to flag plenum or occupied spaces indirectly
  # conditioned with transfer air only. The only accepted 'value' for an
  # "indirectlyconditioned" 'key' is the name (string) of another (linked)
  # space, e.g.:
  #
  #   "indirectlyconditioned" space | linked space, e.g. "core_space"
  # -------------------------------   ---------------------------------------
  #   return air plenum               occupied space below
  #   supply air plenum               occupied space above
  #   dead air space (not a plenum)   nearby occupied space
  #
  # OSut doesn't validate whether the "indirectlyconditioned" space is actually
  # adjacent to its linked space. It nonetheless relies on the latter's
  # conditioning category (e.g. CONDITIONED, SEMIHEATED) to determine
  # anticipated ambient temperatures in the former. For instance, an
  # "indirectlyconditioned"-tagged return air plenum linked to a SEMIHEATED
  # space is considered as free-floating in terms of cooling, and unlikely to
  # have ambient conditions below 15°C under heating (winter) design
  # conditions. OSut will associate this plenum to a 15°C heating setpoint
  # temperature. If the SEMIHEATED space instead has a heating setpoint
  # temperature of 7°C, then OSut will associate a 7°C heating setpoint to this
  # plenum.
  #
  # Even when a (more developed) OpenStudio model holds valid space/zone
  # temperature setpoints, OSut gives priority to these AdditionalProperties.
  # For instance, a CONDITIONED space can be considered INDIRECTLYCONDITIONED,
  # even if its zone thermostat has a valid heating and/or cooling setpoint.
  # This is in sync with OpenStudio-Standards' method
  # "space_conditioning_category()".

  ##
  # Validates if model has zones with HVAC air loops.
  #
  # @param model [OpenStudio::Model::Model] a model
  #
  # @return [Bool] whether model has HVAC air loops
  # @return [false] if invalid input (see logs)
  def airLoopsHVAC?(model = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Model
    return mismatch("model", model, cl, mth, DBG, false) unless model.is_a?(cl)

    model.getThermalZones.each do |zone|
      next            if zone.canBePlenum
      return true unless zone.airLoopHVACs.empty?
      return true     if zone.isPlenum
    end

    false
  end

  ##
  # Returns MIN/MAX values of a schedule (ruleset).
  #
  # @param sched [OpenStudio::Model::ScheduleRuleset] a schedule
  #
  # @return [Hash] min: (Float), max: (Float)
  # @return [Hash] min: nil, max: nil if invalid inputs (see logs)
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
    return invalid("sched", mth, 1, DBG, res) unless sched.respond_to?(NS)

    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)

    values = sched.defaultDaySchedule.values.to_a

    sched.scheduleRules.each { |rule| values += rule.daySchedule.values }

    res[:min] = values.min.is_a?(Numeric) ? values.min : nil
    res[:max] = values.max.is_a?(Numeric) ? values.max : nil

    res
  end

  ##
  # Returns MIN/MAX values of a schedule (constant).
  #
  # @param sched [OpenStudio::Model::ScheduleConstant] a schedule
  #
  # @return [Hash] min: (Float), max: (Float)
  # @return [Hash] min: nil, max: nil if invalid inputs (see logs)
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
    return invalid("sched", mth, 1, DBG, res) unless sched.respond_to?(NS)

    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)

    ok = sched.value.is_a?(Numeric)
    mismatch("#{id} value", sched.value, Numeric, mth, ERR, res) unless ok
    res[:min] = sched.value
    res[:max] = sched.value

    res
  end

  ##
  # Returns MIN/MAX values of a schedule (compact).
  #
  # @param sched [OpenStudio::Model::ScheduleCompact] schedule
  #
  # @return [Hash] min: (Float), max: (Float)
  # @return [Hash] min: nil, max: nil if invalid input (see logs)
  def scheduleCompactMinMax(sched = nil)
    # Largely inspired from Andrew Parker's
    # "schedule_compact_annual_min_max_value":
    #
    # github.com/NREL/openstudio-standards/blob/
    # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
    # standards/Standards.ScheduleCompact.rb#L8
    mth  = "OSut::#{__callee__}"
    cl   = OpenStudio::Model::ScheduleCompact
    vals = []
    prev = ""
    res  = { min: nil, max: nil }
    return invalid("sched", mth, 1, DBG, res) unless sched.respond_to?(NS)

    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)

    sched.extensibleGroups.each do |eg|
      if prev.include?("until")
        vals << eg.getDouble(0).get unless eg.getDouble(0).empty?
      end

      str  = eg.getString(0)
      prev = str.get.downcase unless str.empty?
    end

    return empty("#{id} values", mth, ERR, res) if vals.empty?

    res[:min] = vals.min.is_a?(Numeric) ? vals.min : nil
    res[:max] = vals.min.is_a?(Numeric) ? vals.max : nil

    res
  end

  ##
  # Returns MIN/MAX values for schedule (interval).
  #
  # @param sched [OpenStudio::Model::ScheduleInterval] schedule
  #
  # @return [Hash] min: (Float), max: (Float)
  # @return [Hash] min: nil, max: nil if invalid input (see logs)
  def scheduleIntervalMinMax(sched = nil)
    mth  = "OSut::#{__callee__}"
    cl   = OpenStudio::Model::ScheduleInterval
    vals = []
    res  = { min: nil, max: nil }
    return invalid("sched", mth, 1, DBG, res) unless sched.respond_to?(NS)

    id = sched.nameString
    return mismatch(id, sched, cl, mth, DBG, res) unless sched.is_a?(cl)

    vals = sched.timeSeries.values

    res[:min] = vals.min.is_a?(Numeric) ? vals.min : nil
    res[:max] = vals.max.is_a?(Numeric) ? vals.min : nil

    res
  end

  ##
  # Returns MAX zone heating temperature schedule setpoint [°C] and whether
  # zone has an active dual setpoint thermostat.
  #
  # @param zone [OpenStudio::Model::ThermalZone] a thermal zone
  #
  # @return [Hash] spt: (Float), dual: (Bool)
  # @return [Hash] spt: nil, dual: false if invalid input (see logs)
  def maxHeatScheduledSetpoint(zone = nil)
    # Largely inspired from Parker & Marrec's "thermal_zone_heated?" procedure.
    # The solution here is a tad more relaxed to encompass SEMIHEATED zones as
    # per Canadian NECB criteria (basically any space with at least 10 W/m2 of
    # installed heating equipement, i.e. below freezing in Canada).
    #
    # github.com/NREL/openstudio-standards/blob/
    # 58964222d25783e9da4ae292e375fb0d5c902aa5/lib/openstudio-standards/
    # standards/Standards.ThermalZone.rb#L910
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::ThermalZone
    res = { spt: nil, dual: false }
    return invalid("zone", mth, 1, DBG, res) unless zone.respond_to?(NS)

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

    tstat = zone.thermostat.get
    res[:spt] = nil

    unless tstat.to_ThermostatSetpointDualSetpoint.empty? &&
           tstat.to_ZoneControlThermostatStagedDualSetpoint.empty?

      unless tstat.to_ThermostatSetpointDualSetpoint.empty?
        tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      else
        tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
      end

      unless tstat.heatingSetpointTemperatureSchedule.empty?
        res[:dual] = true
        sched = tstat.heatingSetpointTemperatureSchedule.get

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
  # Validates if model has zones with valid heating temperature setpoints.
  #
  # @param model [OpenStudio::Model::Model] a model
  #
  # @return [Bool] wether model holds valid heating temperature setpoints
  # @return [false] false if invalid input (see logs)
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
  # Returns MIN zone cooling temperature schedule setpoint [°C] and whether
  # zone has an active dual setpoint thermostat.
  #
  # @param zone [OpenStudio::Model::ThermalZone] a thermal zone
  #
  # @return [Hash] spt: (Float), dual: (Bool)
  # @return [Hash] spt: nil, dual: false if invalid input (see logs)
  def minCoolScheduledSetpoint(zone = nil)
    # Largely inspired from Parker & Marrec's "thermal_zone_cooled?" procedure.
    #
    # github.com/NREL/openstudio-standards/blob/
    # 99cf713750661fe7d2082739f251269c2dfd9140/lib/openstudio-standards/
    # standards/Standards.ThermalZone.rb#L1058
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::ThermalZone
    res = { spt: nil, dual: false }
    return invalid("zone", mth, 1, DBG, res) unless zone.respond_to?(NS)

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

    tstat     = zone.thermostat.get
    res[:spt] = nil

    unless tstat.to_ThermostatSetpointDualSetpoint.empty? &&
           tstat.to_ZoneControlThermostatStagedDualSetpoint.empty?

      unless tstat.to_ThermostatSetpointDualSetpoint.empty?
        tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      else
        tstat = tstat.to_ZoneControlThermostatStagedDualSetpoint.get
      end

      unless tstat.coolingSetpointTemperatureSchedule.empty?
        res[:dual] = true
        sched = tstat.coolingSetpointTemperatureSchedule.get

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
  # Validates if model has zones with valid cooling temperature setpoints.
  #
  # @param model [OpenStudio::Model::Model] a model
  #
  # @return [Bool] whether model holds valid cooling temperature setpoints
  # @return [false] if invalid input (see logs)
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
  # Validates whether space is a vestibule.
  #
  # @param space [OpenStudio::Model::Space] a space
  #
  # @return [Bool] whether space is considered a vestibule
  # @return [false] if invalid input (see logs)
  def vestibule?(space = nil)
    # INFO: OpenStudio-Standards' "thermal_zone_vestibule" criteria:
    #   - zones less than 200ft2; AND
    #   - having infiltration using Design Flow Rate
    #
    #   github.com/NREL/openstudio-standards/blob/
    #   86bcd026a20001d903cc613bed6d63e94b14b142/lib/openstudio-standards/
    #   standards/Standards.ThermalZone.rb#L1264
    #
    # This (unused) OpenStudio-Standards method likely needs revision; it would
    # return "false" if the thermal zone area were less than 200ft2. Not sure
    # which edition of 90.1 relies on a 200ft2 threshold (2010?); 90.1 2016
    # doesn't. Yet even fixed, the method would nonetheless misidentify as
    # "vestibule" a small space along an exterior wall, such as a semiheated
    # storage space.
    #
    # The code below is intended as a simple short-term solution, basically
    # relying on AdditionalProperties, or (if missing) a "vestibule" substring
    # within a space's spaceType name (or the latter's standardsSpaceType).
    #
    # Alternatively, some future method could infer its status as a vestibule
    # based on a few basic features (common to all vintages):
    #   - 1x+ outdoor-facing wall(s) holding 1x+ door(s)
    #   - adjacent to 1x+ 'occupied' conditioned space(s)
    #   - ideally, 1x+ door(s) between vestibule and 1x+ such adjacent space(s)
    #
    # An additional method parameter (i.e. std = :necb) could be added to
    # ensure supplementary Standard-specific checks, e.g. maximum floor area,
    # minimum distance between doors.
    #
    # Finally, an entirely separate method could be developed to first identify
    # whether "building entrances" (a defined term in 90.1) actually require
    # vestibules as per specific code requirements. Food for thought.
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Space
    return mismatch("space", space, cl, mth, DBG, false) unless space.is_a?(cl)

    id  = space.nameString
    m1  = "#{id}:vestibule"
    m1  = "#{id}:vestibule boolean"

    if space.additionalProperties.hasFeature("vestibule")
      val = space.additionalProperties.getFeatureAsBoolean("vestibule")
      return invalid(m1, mth, 1, ERR, false) if val.empty?

      val = val.get
      return invalid(m2, mth, 1, ERR, false) unless [true, false].include?(val)
      return val
    end

    unless space.spaceType.empty?
      type = space.spaceType.get
      return false if type.nameString.downcase.include?("plenum")
      return true  if type.nameString.downcase.include?("vestibule")

      unless type.standardsSpaceType.empty?
        type = type.standardsSpaceType.get.downcase
        return false if type.include?("plenum")
        return true  if type.include?("vestibule")
      end
    end

    false
  end

  ##
  # Validates whether a space is an indirectly-conditioned plenum.
  #
  # @param space [OpenStudio::Model::Space] a space
  #
  # @return [Bool] whether space is considered a plenum
  # @return [false] if invalid input (see logs)
  def plenum?(space = nil)
    # Largely inspired from NREL's "space_plenum?":
    #
    #   github.com/NREL/openstudio-standards/blob/
    #   58964222d25783e9da4ae292e375fb0d5c902aa5/lib/openstudio-standards/
    #   standards/Standards.Space.rb#L1384
    #
    # Ideally, "plenum?" should be in sync with OpenStudio SDK's "isPlenum"
    # method, which solely looks for either HVAC air mixer objects:
    #  - AirLoopHVACReturnPlenum
    #  - AirLoopHVACSupplyPlenum
    #
    # Of the OpenStudio-Standards Prototype models, only the LargeOffice
    # holds AirLoopHVACReturnPlenum objects. OpenStudio-Standards' method
    # "space_plenum?" indeed catches them by checking if the space is
    # "partofTotalFloorArea" (which internally has an "isPlenum" check). So
    # "isPlenum" closely follows ASHRAE 90.1 2016's definition of "plenum":
    #
    #   "plenum": a compartment or chamber ...
    #             - to which one or more ducts are connected
    #             - that forms a part of the air distribution system, and
    #             - that is NOT USED for occupancy or storage.
    #
    # Canadian NECB 2020 has the following (not as well) defined term:
    #   "plenum": a chamber forming part of an air duct system.
    #             ... we'll assume that a space shall also be considered
    #             UNOCCUPIED if it's "part of an air duct system".
    #
    # As intended, "isPlenum" would NOT identify as a "plenum" any vented
    # UNCONDITIONED or UNENCLOSED attic or crawlspace - good. Yet "isPlenum"
    # would also ignore dead air spaces integrating ducted return air. The
    # SDK's "partofTotalFloorArea" would be more suitable in such cases, as
    # long as modellers have, a priori, set this parameter to FALSE.
    #
    # OpenStudio-Standards' "space_plenum?" catches a MUCH WIDER range of
    # spaces, which aren't caught by "isPlenum". This includes attics,
    # crawlspaces, non-plenum air spaces above ceiling tiles, and any other
    # UNOCCUPIED space in a model. The term "plenum" in this context is more
    # of a catch-all shorthand - to be used with caution. For instance,
    # "space_plenum?" shouldn't be used (in isolation) to determine whether an
    # UNOCCUPIED space should have its envelope insulated ("plenum") or not
    # ("attic").
    #
    # In contrast to OpenStudio-Standards' "space_plenum?", this method
    # strictly returns FALSE if a space is indeed "partofTotalFloorArea". It
    # also returns FALSE if the space is a vestibule. Otherwise, it needs more
    # information to determine if such an UNOCCUPIED space is indeed a
    # plenum. Beyond these 2x criteria, a space is considered a plenum if:
    #
    # CASE A: it includes the substring "plenum" (case insensitive) in its
    #         spaceType's name, or in the latter's standardsSpaceType string;
    #
    # CASE B: "isPlenum" == TRUE in an OpenStudio model WITH HVAC airloops: OR
    #
    # CASE C: its zone holds an 'inactive' thermostat (i.e. can't extract valid
    #         setpoints) in an OpenStudio model with setpoint temperatures.
    #
    # If a modeller is instead simply interested in identifying UNOCCUPIED
    # spaces that are INDIRECTLYCONDITIONED (not necessarily plenums), then the
    # following combination is likely more reliable and less confusing:
    #   - SDK's partofTotalFloorArea == FALSE
    #   - OSut's unconditioned? == FALSE
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Space
    return mismatch("space", space, cl, mth, DBG, false) unless space.is_a?(cl)
    return false if space.partofTotalFloorArea
    return false if vestibule?(space)

    id = space.nameString
    m1 = "#{id}:plenum"
    m1 = "#{id}:plenum boolean"

    # CASE A: "plenum" spaceType.
    unless space.spaceType.empty?
      type = space.spaceType.get
      return true if type.nameString.downcase.include?("plenum")

      unless type.standardsSpaceType.empty?
        type = type.standardsSpaceType.get.downcase
        return true if type.include?("plenum")
      end
    end

    # CASE B: "isPlenum" == TRUE if airloops.
    return space.isPlenum if airLoopsHVAC?(space.model)

    # CASE C: zone holds an 'inactive' thermostat.
    zone   = space.thermalZone
    heated = heatingTemperatureSetpoints?(space.model)
    cooled = coolingTemperatureSetpoints?(space.model)

    if heated || cooled
      return false if zone.empty?

      zone = zone.get
      heat = maxHeatScheduledSetpoint(zone)
      cool = minCoolScheduledSetpoint(zone)
      return false if heat[:spt] || cool[:spt] # directly CONDITIONED
      return heat[:dual] || cool[:dual]        # FALSE if both are nilled
    end

    false
  end

  ##
  # Retrieves a space's (implicit or explicit) heating/cooling setpoints.
  #
  # @param space [OpenStudio::Model::Space] a space
  #
  # @return [Hash] heating: (Float), cooling: (Float)
  # @return [Hash] heating: nil, cooling: nil if invalid input (see logs)
  def setpoints(space = nil)
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Model::Space
    cl2 = String
    res = {heating: nil, cooling: nil}
    tg1 = "space_conditioning_category"
    tg2 = "indirectlyconditioned"
    cts = ["nonresconditioned", "resconditioned", "semiheated", "unconditioned"]
    cnd = nil
    return mismatch("space", space, cl1, mth, DBG, res) unless space.is_a?(cl1)

    # 1. Check for OpenStudio-Standards' space conditioning categories.
    if space.additionalProperties.hasFeature(tg1)
      cnd = space.additionalProperties.getFeatureAsString(tg1)

      if cnd.empty?
        cnd = nil
      else
        cnd = cnd.get

        if cts.include?(cnd.downcase)
          return res if cnd.downcase == "unconditioned"
        else
          invalid("#{tg1}:#{cnd}", mth, 0, ERR)
          cnd = nil
        end
      end
    end

    # 2. Check instead OSut's INDIRECTLYCONDITIONED (parent space) link.
    if cnd.nil?
      id = space.additionalProperties.getFeatureAsString(tg2)

      unless id.empty?
        id  = id.get
        dad = space.model.getSpaceByName(id)

        if dad.empty?
          log(ERR, "Unknown space #{id} (#{mth})")
        else
          # Now focus on 'parent' space linked to INDIRECTLYCONDITIONED space.
          space = dad.get
          cnd   = tg2
        end
      end
    end

    # 3. Fetch space setpoints (if model indeed holds valid setpoints).
    heated = heatingTemperatureSetpoints?(space.model)
    cooled = coolingTemperatureSetpoints?(space.model)
    zone   = space.thermalZone

    if heated || cooled
      return res if zone.empty? # UNCONDITIONED

      zone = zone.get
      res[:heating] = maxHeatScheduledSetpoint(zone)[:spt]
      res[:cooling] = minCoolScheduledSetpoint(zone)[:spt]
    end

    # 4. Reset if AdditionalProperties were found & valid.
    unless cnd.nil?
      if cnd.downcase == "unconditioned"
        res[:heating] = nil
        res[:cooling] = nil
      elsif cnd.downcase == "semiheated"
        res[:heating] = 15.0 if res[:heating].nil?
        res[:cooling] = nil
      elsif cnd.downcase.include?("conditioned")
        # "nonresconditioned", "resconditioned" or "indirectlyconditioned"
        res[:heating] = 21.0 if res[:heating].nil? # default
        res[:cooling] = 24.0 if res[:cooling].nil? # default
      end
    end

    # 5. Reset if plenum?
    if plenum?(space)
      res[:heating] = 21.0 if res[:heating].nil? # default
      res[:cooling] = 24.0 if res[:cooling].nil? # default
    end

    res
  end

  ##
  # Validates if a space is UNCONDITIONED.
  #
  # @param space [OpenStudio::Model::Space] a space
  #
  # @return [Bool] whether space is considered UNCONDITIONED
  # @return [false] if invalid input (see logs)
  def unconditioned?(space = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Space
    return mismatch("space", space, cl, mth, DBG, false) unless space.is_a?(cl)

    ok = false
    ok = setpoints(space)[:heating].nil? && setpoints(space)[:cooling].nil?

    ok
  end

  ##
  # Generates an HVAC availability schedule.
  #
  # @param model [OpenStudio::Model::Model] a model
  # @param avl [String] seasonal availability choice (optional, default "ON")
  #
  # @return [OpenStudio::Model::Schedule] HVAC availability sched
  # @return [nil] if invalid input (see logs)
  def availabilitySchedule(model = nil, avl = "")
    mth    = "OSut::#{__callee__}"
    cl     = OpenStudio::Model::Model
    limits = nil
    return mismatch("model",     model, cl, mth) unless model.is_a?(cl)
    return invalid("availability", avl,  2, mth) unless avl.respond_to?(:to_s)

    # Either fetch availability ScheduleTypeLimits object, or create one.
    model.getScheduleTypeLimitss.each do |l|
      break    if limits
      next     if l.lowerLimitValue.empty?
      next     if l.upperLimitValue.empty?
      next     if l.numericType.empty?
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
    return empty("yearDescription", mth, ERR) if year.empty?

    year  = year.get
    may01 = year.makeDate(OpenStudio::MonthOfYear.new("May"),  1)
    oct31 = year.makeDate(OpenStudio::MonthOfYear.new("Oct"), 31)

    case trim(avl).downcase
    when "winter" # available from November 1 to April 30 (6 months)
      val = 1
      sch = off
      nom = "WINTER Availability SchedRuleset"
      dft = "WINTER Availability dftDaySched"
      tag = "May-Oct WINTER Availability SchedRule"
      day = "May-Oct WINTER SchedRule Day"
    when "summer" # available from May 1 to October 31 (6 months)
      val = 0
      sch = on
      nom = "SUMMER Availability SchedRuleset"
      dft = "SUMMER Availability dftDaySched"
      tag = "May-Oct SUMMER Availability SchedRule"
      day = "May-Oct SUMMER SchedRule Day"
    when "off" # never available
      val = 0
      sch = on
      nom = "OFF Availability SchedRuleset"
      dft = "OFF Availability dftDaySched"
      tag = ""
      day = ""
    else # always available
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
        default  = schedule.defaultDaySchedule
        ok = ok && default.nameString           == dft
        ok = ok && default.times.size           == 1
        ok = ok && default.values.size          == 1
        ok = ok && default.times.first          == time
        ok = ok && default.values.first         == val
        rules = schedule.scheduleRules
        ok = ok && rules.size < 2

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

    unless schedule.setScheduleTypeLimits(limits)
      log(ERR, "'#{nom}': Can't set schedule type limits (#{mth})")
      return nil
    end

    unless schedule.defaultDaySchedule.addValue(time, val)
      log(ERR, "'#{nom}': Can't set default day schedule (#{mth})")
      return nil
    end

    schedule.defaultDaySchedule.setName(dft)

    unless tag.empty?
      rule = OpenStudio::Model::ScheduleRule.new(schedule, sch)
      rule.setName(tag)

      unless rule.setStartDate(may01)
        log(ERR, "'#{tag}': Can't set start date (#{mth})")
        return nil
      end

      unless rule.setEndDate(oct31)
        log(ERR, "'#{tag}': Can't set end date (#{mth})")
        return nil
      end

      unless rule.setApplyAllDays(true)
        log(ERR, "'#{tag}': Can't apply to all days (#{mth})")
        return nil
      end

      rule.daySchedule.setName(day)
    end

    schedule
  end

  # ---- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---- #
  # ---- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- ---- #
  # This final set of utilities targets OpenStudio geometry. Many of the
  # following geometry methods rely on Boost as an OpenStudio dependency.
  # As per Boost requirements, points (e.g. polygons) must first be 'aligned':
  #   - first rotated/tilted as to lay flat along XY plane (Z-axis ~= 0)
  #   - initial Z-axis values are represented as Y-axis values
  #   - points with the lowest X-axis values are 'aligned' along X-axis (0)
  #   - points with the lowest Z-axis values are 'aligned' along Y-axis (0)
  #   - for several Boost methods, points must be clockwise in sequence
  #
  # Check OSut's poly() method, which offers such Boost-related options.

  ##
  # Returns OpenStudio site/space transformation & rotation angle [0,2PI) rads.
  #
  # @param group [OpenStudio::Model::PlanarSurfaceGroup] a site or space object
  #
  # @return [Hash] t: (OpenStudio::Transformation), r: (Float)
  # @return [Hash] t: nil, r: nil if invalid input (see logs)
  def transforms(group = nil)
    mth = "OSut::#{__callee__}"
    cl2 = OpenStudio::Model::PlanarSurfaceGroup
    res = { t: nil, r: nil }
    return invalid("group", mth, 2, DBG, res) unless group.respond_to?(NS)

    id  = group.nameString
    mdl = group.model
    return mismatch(id, group, cl2, mth, DBG, res) unless group.is_a?(cl2)

    res[:t] = group.siteTransformation
    res[:r] = group.directionofRelativeNorth + mdl.getBuilding.northAxis

    res
  end

  ##
  # Returns true if 2 OpenStudio 3D points are nearly equal
  #
  # @param p1 [OpenStudio::Point3d] 1st 3D point
  # @param p2 [OpenStudio::Point3d] 2nd 3D point
  #
  # @return [Bool] whether equal points (within TOL)
  # @return [false] if invalid input (see logs)
  def same?(p1 = nil, p2 = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Point3d
    return mismatch("point 1", p1, cl, mth, DBG, false) unless p1.is_a?(cl)
    return mismatch("point 2", p2, cl, mth, DBG, false) unless p2.is_a?(cl)

    # OpenStudio.isAlmostEqual3dPt(p1, p2, TOL) # ... from v350 onwards.
    (p1.x-p2.x).abs < TOL && (p1.y-p2.y).abs < TOL && (p1.z-p2.z).abs < TOL
  end

  ##
  # Returns true if a line segment is along the X-axis.
  #
  # @param p1 [OpenStudio::Point3d] 1st 3D point of a line segment
  # @param p2 [OpenStudio::Point3d] 2nd 3D point of a line segment
  # @param strict [Bool] whether segment shouldn't hold Y- or Z-axis components
  #
  # @return [Bool] whether along the X-axis
  # @return [false] if invalid input (see logs)
  def xx?(p1 = nil, p2 = nil, strict = true)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Point3d
    strict = true unless [true, false].include?(strict)
    return mismatch("point 1", p1, cl, mth, DBG, false) unless p1.is_a?(cl)
    return mismatch("point 2", p2, cl, mth, DBG, false) unless p2.is_a?(cl)
    return false if (p1.y - p2.y).abs > TOL && strict
    return false if (p1.z - p2.z).abs > TOL && strict

    (p1.x - p2.x).abs > TOL
  end

  ##
  # Returns true if a line segment is along the Y-axis.
  #
  # @param p1 [OpenStudio::Point3d] 1st 3D point of a line segment
  # @param p2 [OpenStudio::Point3d] 2nd 3D point of a line segment
  # @param strict [Bool] whether segment shouldn't hold X- or Z-axis components
  #
  # @return [Bool] whether along the Y-axis
  # @return [false] if invalid input (see logs)
  def yy?(p1 = nil, p2 = nil, strict = true)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Point3d
    strict = true unless [true, false].include?(strict)
    return mismatch("point 1", p1, cl, mth, DBG, false) unless p1.is_a?(cl)
    return mismatch("point 2", p2, cl, mth, DBG, false) unless p2.is_a?(cl)
    return false if (p1.x - p2.x).abs > TOL && strict
    return false if (p1.z - p2.z).abs > TOL && strict

    (p1.y - p2.y).abs > TOL
  end

  ##
  # Returns true if a line segment is along the Z-axis.
  #
  # @param p1 [OpenStudio::Point3d] 1st 3D point of a line segment
  # @param p2 [OpenStudio::Point3d] 2nd 3D point of a line segment
  # @param strict [Bool] whether segment shouldn't hold X- or Y-axis components
  #
  # @return [Bool] whether along the Z-axis
  # @return [false] if invalid input (see logs)
  def zz?(p1 = nil, p2 = nil, strict = true)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Point3d
    strict = true unless [true, false].include?(strict)
    return mismatch("point 1", p1, cl, mth, DBG, false) unless p1.is_a?(cl)
    return mismatch("point 2", p2, cl, mth, DBG, false) unless p2.is_a?(cl)
    return false if (p1.x - p2.x).abs > TOL && strict
    return false if (p1.y - p2.y).abs > TOL && strict

    (p1.z - p2.z).abs > TOL
  end

  ##
  # Returns a scalar product of an OpenStudio Vector3d.
  #
  # @param v [OpenStudio::Vector3d] a vector
  # @param m [#to_f] a scalar
  #
  # @return [OpenStudio::Vector3d] scaled points (see logs if empty)
  def scalar(v = OpenStudio::Vector3d.new, m = 0)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Vector3d
    ok  = m.respond_to?(:to_f)
    return mismatch("vector", v, cl,      mth, DBG, v) unless v.is_a?(cl)
    return mismatch("m",      m, Numeric, mth, DBG, v) unless ok

    m = m.to_f
    OpenStudio::Vector3d.new(m * v.x, m * v.y, m * v.z)
  end

  ##
  # Returns OpenStudio 3D points as an OpenStudio point vector, validating
  # points in the process (if Array).
  #
  # @param pts [Set<OpenStudio::Point3d>] OpenStudio 3D points
  #
  # @return [OpenStudio::Point3dVector] 3D vector (see logs if empty)
  def to_p3Dv(pts = nil)
    mth = "OSut::#{__callee__}"
    cl1 = Array
    cl2 = OpenStudio::Point3dVector
    cl3 = OpenStudio::Model::PlanarSurface
    cl4 = OpenStudio::Point3d
    v   = OpenStudio::Point3dVector.new
    return pts                                           if pts.is_a?(cl2)
    return pts.vertices                                  if pts.is_a?(cl3)
    return mismatch("points", pts, cl1, mth, DBG, v) unless pts.is_a?(cl1)

    pts.each do |pt|
      return mismatch("point", pt, cl4, mth, DBG, v) unless pt.is_a?(cl4)
    end

    pts.each { |pt| v << OpenStudio::Point3d.new(pt.x, pt.y, pt.z) }

    v
  end

  ##
  # Returns true if an OpenStudio 3D point is part of a set of 3D points.
  #
  # @param pts [Set<OpenStudio::Point3dVector>] 3d points
  # @param p1 [OpenStudio::Point3d] a 3D point
  #
  # @return [Bool] whether part of a set of 3D points
  # @return [false] if invalid input (see logs)
  def holds?(pts = nil, p1 = nil)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    cl  = OpenStudio::Point3d
    return mismatch("point", p1, cl, mth, DBG, false) unless p1.is_a?(cl)

    pts.each { |pt| return true if same?(p1, pt) }

    false
  end

  ##
  # Flattens OpenStudio 3D points vs X, Y or Z axes.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  # @param axs [Symbol] :x, :y or :z axis
  # @param val [#to_f] axis value
  #
  # @return [OpenStudio::Point3dVector] flattened points (see logs if empty)
  def flatten(pts = nil, axs = :z, val = 0)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    v   = OpenStudio::Point3dVector.new
    ok1 = val.respond_to?(:to_f)
    ok2 = [:x, :y, :z].include?(axs)
    return mismatch("val", val, Numeric, mth,    DBG, v) unless ok1
    return invalid("axis (XYZ?)",        mth, 2, DBG, v) unless ok2

    val = val.to_f

    case axs
    when :x
      pts.each { |pt| v << OpenStudio::Point3d.new(val, pt.y, pt.z) }
    when :y
      pts.each { |pt| v << OpenStudio::Point3d.new(pt.x, val, pt.z) }
    else
      pts.each { |pt| v << OpenStudio::Point3d.new(pt.x, pt.y, val) }
    end

    v
  end

  ##
  # Returns true if OpenStudio 3D points share X, Y or Z coordinates.
  #
  # @param pts [Set<OpenStudio::Point3d>] OpenStudio 3D points
  # @param axs [Symbol] if potentially along :x, :y or :z axis
  # @param val [Numeric] axis value
  #
  # @return [Bool] if points share X, Y or Z coordinates
  # @return [false] if invalid input (see logs)
  def xyz?(pts = nil, axs = :z, val = 0)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    ok1 = val.respond_to?(:to_f)
    ok2 = [:x, :y, :z].include?(axs)
    return false if pts.empty?
    return mismatch("val", val, Numeric, mth,    DBG, false) unless ok1
    return invalid("axis (XYZ?)",        mth, 2, DBG, false) unless ok2

    val = val.to_f

    case axs
    when :x
      pts.each { |pt| return false if (pt.x - val).abs > TOL }
    when :y
      pts.each { |pt| return false if (pt.y - val).abs > TOL }
    else
      pts.each { |pt| return false if (pt.z - val).abs > TOL }
    end

    true
  end

  ##
  # Returns next sequential point in an OpenStudio 3D point vector.
  #
  # @param pts [OpenStudio::Point3dVector] 3D points
  # @param pt [OpenStudio::Point3d] a given 3D point
  #
  # @return [OpenStudio::Point3d] the next sequential point
  # @return [nil] if invalid input (see logs)
  def next(pts = nil, pt = nil)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    cl  = OpenStudio::Point3d
    return mismatch("point", pt, cl, mth)  unless pt.is_a?(cl)
    return invalid("points (2+)", mth, 1, WRN) if pts.size < 2

    pair = pts.each_cons(2).find { |p1, _| same?(p1, pt) }

    pair.nil? ? pts.first : pair.last
  end

  ##
  # Returns unique OpenStudio 3D points from an OpenStudio 3D point vector.
  #
  # @param pts [Set<OpenStudio::Point3d] 3D points
  # @param n [#to_i] requested number of unique points (0 returns all)
  #
  # @return [OpenStudio::Point3dVector] unique points (see logs if empty)
  def getUniques(pts = nil, n = 0)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    ok  = n.respond_to?(:to_i)
    v   = OpenStudio::Point3dVector.new
    return v if pts.empty?
    return mismatch("n unique points", n, Integer, mth, DBG, v) unless ok

    pts.each { |pt| v << pt unless holds?(v, pt) }

    n = n.to_i
    n = 0    unless n.abs < v.size
    v = v[0..n]  if n > 0
    v = v[n..-1] if n < 0

    v
  end

  ##
  # Returns sequential non-collinear points in an OpenStudio 3D point vector.
  #
  # @param pts [Set<OpenStudio::Point3d] 3D points
  # @param n [#to_i] requested number of non-collinears (0 returns all)
  #
  # @return [OpenStudio::Point3dVector] non-collinears (see logs if empty)
  def getNonCollinears(pts = nil, n = 0)
    mth = "OSut::#{__callee__}"
    pts = getUniques(pts)
    ok  = n.respond_to?(:to_i)
    v   = OpenStudio::Point3dVector.new
    a   = []
    return pts if pts.size < 2
    return mismatch("n non-collinears", n, Integer, mth, DBG, v) unless ok

    # Alternative: evaluate cross product of vectors of 3x sequential points.
    pts.each_with_index do |p2, i2|
      i1  = i2 - 1
      i3  = i2 + 1
      i3  = 0 if i3 == pts.size
      p1  = pts[i1]
      p3  = pts[i3]
      v13 = p3 - p1
      v12 = p2 - p1
      next if v12.cross(v13).length < TOL
      # next if OpenStudio.isPointOnLineBetweenPoints(p1, p3, p2, TOL) # v351

      a << p2
    end

    if holds?(a, pts[0])
      a = a.rotate(-1) unless same?(a[0], pts[0])
    end

    n = n.to_i
    n = 0    unless n.abs < pts.size
    a = a[0..n]  if n > 0
    a = a[n..-1] if n < 0

    to_p3Dv(a)
  end

  ##
  # Returns paired sequential points as (non-zero length) line segments. If the
  # set strictly holds 2x unique points, a single segment is returned.
  # Otherwise, the returned number of segments equals the number of unique
  # points. If non-collinearity is requested, then the number of returned
  # segments equals the number of non-colliear points.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  # @param co [Bool] whether to keep collinear points
  #
  # @return [OpenStudio::Point3dVectorVector] line segments (see logs if empty)
  def getSegments(pts = nil, co = false)
    mth = "OSut::#{__callee__}"
    vv  = OpenStudio::Point3dVectorVector.new
    co  = false                 unless [true, false].include?(co)
    pts = getNonCollinears(pts) unless co
    pts = getUniques(pts)           if co
    return vv                       if pts.size < 2

    pts.each_with_index do |p1, i1|
      i2 = i1 + 1
      i2 = 0 if i2 == pts.size
      p2 = pts[i2]

      line = OpenStudio::Point3dVector.new
      line << p1
      line << p2
      vv << line
      break if pts.size == 2
    end

    vv
  end

  ##
  # Returns points as (non-zero length) 'triads', i.e. 3x sequential points.
  # If the set holds less than 3x unique points, an empty triad is
  # returned. Otherwise, the returned number of triads equals the number of
  # unique points. If non-collinearity is requested, then the number of
  # returned triads equals the number of non-collinear points.
  #
  # @param pts [OpenStudio::Point3dVector] 3D points
  # @param co [Bool] whether to keep collinear points
  #
  # @return [OpenStudio::Point3dVectorVector] triads (see logs if empty)
  def getTriads(pts = nil, co = false)
    mth = "OSut::#{__callee__}"
    vv  = OpenStudio::Point3dVectorVector.new
    co  = false                 unless [true, false].include?(co)
    pts = getNonCollinears(pts) unless co
    pts = getUniques(pts)           if co
    return vv                       if pts.size < 2

    pts.each_with_index do |p1, i1|
      i2 = i1 + 1
      i2 = 0 if i2 == pts.size
      i3 = i2 + 1
      i3 = 0 if i3 == pts.size
      p2 = pts[i2]
      p3 = pts[i3]

      tri = OpenStudio::Point3dVector.new
      tri << p1
      tri << p2
      tri << p3
      vv << tri
    end

    vv
  end

  ##
  # Determines if pre-'aligned' OpenStudio 3D points are listed clockwise.
  #
  # @param pts [OpenStudio::Point3dVector] 3D points
  #
  # @return [Bool] whether sequence is clockwise
  # @return [false] if invalid input (see logs)
  def clockwise?(pts = nil)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    n   = false
    return invalid("points (3+)",      mth, 1, DBG, n)     if pts.size < 3
    return invalid("points (aligned)", mth, 1, DBG, n) unless xyz?(pts, :z, 0)

    OpenStudio.pointInPolygon(pts.first, pts, TOL)
  end

  ##
  # Returns 'aligned' OpenStudio 3D points conforming to Openstudio's
  # counterclockwise UpperLeftCorner (ULC) convention.
  #
  # @param pts [Set<OpenStudio::Point3d>] aligned 3D points
  #
  # @return [OpenStudio::Point3dVector] ULC points (see logs if empty)
  def ulc(pts = nil)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    v   = OpenStudio::Point3dVector.new
    p0  = OpenStudio::Point3d.new(0,0,0)
    i0  = nil

    return invalid("points (3+)",      mth, 1, DBG, v)     if pts.size < 3
    return invalid("points (aligned)", mth, 1, DBG, v) unless xyz?(pts, :z, 0)

    # Ensure counterclockwise sequence.
    pts = pts.to_a
    pts = pts.reverse if clockwise?(pts)

    # Fetch index of candidate (0,0,0) point (i == 1, in most cases). Resort
    # to last X == 0 point. Leave as is if failed attempts.
    i0 = pts.index  { |pt| same?(pt, p0) }
    i0 = pts.rindex { |pt| pt.x.abs < TOL } if i0.nil?

    unless i0.nil?
      i   = pts.size - 1
      i   = i0 - 1 unless i0 == 0
      pts = pts.rotate(i)
    end

    to_p3Dv(pts)
  end

  ##
  # Returns an OpenStudio 3D point vector as basis for a valid OpenStudio 3D
  # polygon. In addition to basic OpenStudio polygon tests (e.g. all points
  # sharing the same 3D plane, non-self-intersecting), the method can
  # optionally check for convexity, or ensure uniqueness and/or collinearity.
  # Returned vector can also be 'aligned', as well as in UpperLeftCorner (ULC)
  # counterclockwise sequence, or in clockwise sequence.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  # @param vx [Bool] whether to check for convexity
  # @param uq [Bool] whether to ensure uniqueness
  # @param co [Bool] whether to ensure non-collinearity
  # @param tt [Bool, OpenStudio::Transformation] whether to 'align'
  # @param sq [:no, :ulc, :cw] unaltered, ULC or clockwise sequence
  #
  # @return [OpenStudio::Point3dVector] 3D points (see logs if empty)
  def poly(pts = nil, vx = false, uq = false, co = true, tt = false, sq = :no)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    cl  = OpenStudio::Transformation
    v   = OpenStudio::Point3dVector.new
    vx  = false unless [true, false].include?(vx)
    uq  = false unless [true, false].include?(uq)
    co  = true  unless [true, false].include?(co)

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Exit if mismatched/invalid arguments.
    ok1 = tt == true || tt == false || tt.is_a?(cl)
    ok2 = sq == :no  || sq == :ulc  || sq == :cw
    return invalid("transformation", mth, 5, DBG, v) unless ok1
    return invalid("sequence",       mth, 6, DBG, v) unless ok2

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Basic tests:
    p3 = getNonCollinears(pts, 3)
    return empty("polygon", mth, ERR, v) if p3.size < 3

    pln = OpenStudio::Plane.new(p3)

    pts.each do |pt|
      return empty("plane", mth, ERR, v) unless pln.pointOnPlane(pt)
    end

    t = tt
    t = OpenStudio::Transformation.alignFace(pts) unless tt.is_a?(cl)
    a = (t.inverse * pts).reverse

    if tt.is_a?(cl)
      # Using a transformation that is most likely not specific to pts. The
      # most probable reason to retain this option is when testing for polygon
      # intersections, unions, etc., operations that typically require that
      # points remain nonetheless 'aligned'. This logs a warning if aligned
      # points aren't @Z =0, before 'flattening'.
      invalid("points (non-aligned)", mth, 1, WRN) unless xyz?(a, :z, 0)
      a = flatten(a).to_a                          unless xyz?(a, :z, 0)
    end

    # The following 2x lines are commented out. This is a very commnon and very
    # useful test, yet tested cases are first caught by the 'pointOnPlane'
    # test above. Keeping it for possible further testing.
    # bad = OpenStudio.selfIntersects(a, TOL)
    # return invalid("points (intersecting)", mth, 1, ERR, v) if bad

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Ensure uniqueness and/or non-collinearity. Preserve original sequence.
    p0 = a.first
    a  = OpenStudio.simplify(a, false, TOL)     if uq
    a  = OpenStudio.simplify(a, true,  TOL) unless co
    i0 = a.index { |pt| same?(pt, p0) }
    a  = a.rotate(i0)                       unless i0.nil?

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Check for convexity (optional).
    if vx
      a1 = OpenStudio.simplify(a, true, TOL).reverse
      dX = a1.max_by(&:x).x.abs
      dY = a1.max_by(&:y).y.abs
      d  = [dX, dY].max
      return false if d < TOL

      u = OpenStudio::Vector3d.new(0, 0, d)

      a1.each_with_index do |p1, i1|
        i2 = i1 + 1
        i2 = 0 if i2 == a1.size
        p2 = a1[i2]
        pi = p1 + u
        vi = OpenStudio::Point3dVector.new
        vi << pi
        vi << p1
        vi << p2
        plane  = OpenStudio::Plane.new(vi)
        normal = plane.outwardNormal

        a1.each do |p3|
          next if same?(p1, p3)
          next if same?(p2, p3)
          next if plane.pointOnPlane(p3)
          next if normal.dot(p3 - p1) < 0

          return invalid("points (non-convex)", mth, 1, ERR, v)
        end
      end
    end

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Alter sequence (optional).
    unless tt
      case sq
      when :ulc
        a = to_p3Dv(t * ulc(a.reverse))
      when :cw
        a = to_p3Dv(t * a)
        a = OpenStudio.reverse(a) unless clockwise?(a)
      else
        a = to_p3Dv(t * a.reverse)
      end
    else
      case sq
      when :ulc
        a = ulc(a.reverse)
      when :cw
        a = to_p3Dv(a)
        a = OpenStudio.reverse(a) unless clockwise?(a)
      else
        a = to_p3Dv(a.reverse)
      end
    end

    a
  end

  ##
  # Returns 'width' of a set of OpenStudio 3D points (perpendicular view).
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [Float] left-to-right width
  # @return [0.0] if invalid inputs (see logs)
  def width(pts = nil)
    mth = "OSut::#{__callee__}"

    poly(pts, false, true, false, true).max_by(&:x).x
  end

  ##
  # Returns 'height' of a set of OpenStudio 3D points (perpendicular view).
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [Float] top-to-bottom height
  # @return [0.0] if invalid inputs (see logs)
  def height(pts = nil)
    mth = "OSut::#{__callee__}"

    poly(pts, false, true, false, true).max_by(&:y).y
  end

  ##
  # Determines whether a 1st OpenStudio polygon fits in a 2nd polygon.
  #
  # @param p1 [Set<OpenStudio::Point3d>] 1st set of 3D points
  # @param p2 [Set<OpenStudio::Point3d>] 2nd set of 3D points
  # @param flat [Bool] whether points are to be pre-flattened (Z=0)
  #
  # @return [Bool] whether 1st polygon fits within the 2nd polygon
  # @return [false] false if invalid input (see logs)
  def fits?(p1 = nil, p2 = nil, flat = true)
    mth  = "OSut::#{__callee__}"
    p1   = poly(p1, false, true, false)
    p2   = poly(p2, false, true, false)
    flat = true  unless [true, false].include?(flat)
    return false     if p1.empty?
    return false     if p2.empty?

    # Aligned, clockwise points using transformation from 2nd polygon.
    t  = OpenStudio::Transformation.alignFace(p2)
    p1 = poly(p1, false, false, true, t, :cw)
    p2 = poly(p2, false, false, true, t, :cw)
    p1 = flatten(p1) if flat
    p2 = flatten(p2) if flat
    return false     if p1.empty?
    return false     if p2.empty?

    area1 = OpenStudio.getArea(p1)
    area2 = OpenStudio.getArea(p2)
    return empty("points 1 area", mth, ERR, false) if area1.empty?
    return empty("points 2 area", mth, ERR, false) if area2.empty?

    area1 = area1.get
    area2 = area2.get
    union = OpenStudio.join(p1, p2, TOL2)
    return false if union.empty?

    union = union.get
    area  = OpenStudio.getArea(union)
    return false if area.empty?

    area = area.get
    return false if area < TOL
    return true  if (area - area2).abs < TOL
    return false if (area - area2).abs > TOL

    true
  end

  ##
  # Determines whether OpenStudio polygons overlap.
  #
  # @param p1 [Set<OpenStudio::Point3d>] 1st set of 3D points
  # @param p2 [Set<OpenStudio::Point3d>] 2nd set of 3D points
  # @param flat [Bool] whether points are to be pre-flattened (Z=0)
  #
  # @return [Bool] whether olygons overlap (or either fit into one another)
  # @return [false] if invalid input (see logs)
  def overlaps?(p1 = nil, p2 = nil, flat = true)
    mth  = "OSut::#{__callee__}"
    p1   = poly(p1, false, true, false)
    p2   = poly(p2, false, true, false)
    flat = true unless [true, false].include?(flat)
    return false    if p1.empty?
    return false    if p2.empty?

    # Aligned, clockwise & convex points using transformation from 1st polygon.
    t  = OpenStudio::Transformation.alignFace(p1)
    p1 = poly(p1, false, false, true, t, :cw)
    p2 = poly(p2, false, false, true, t, :cw)
    p1 = flatten(p1) if flat
    p2 = flatten(p2) if flat
    return false     if p1.empty?
    return false     if p2.empty?

    area1 = OpenStudio.getArea(p1)
    area2 = OpenStudio.getArea(p2)
    return empty("points 1 area", mth, ERR, false) if area1.empty?
    return empty("points 2 area", mth, ERR, false) if area2.empty?

    area1 = area1.get
    area2 = area2.get
    union = OpenStudio.join(p1, p2, TOL2)
    return false if union.empty?

    union = union.get
    area  = OpenStudio.getArea(union)
    return false if area.empty?

    area = area.get
    delta = (area - area1 - area2).abs
    return false if area  < TOL
    return false if delta < TOL

    true
  end

  ##
  # Generates offset vertices (by width) for a 3- or 4-sided, convex polygon.
  #
  # @param p1 [Set<OpenStudio::Point3d>] OpenStudio 3D points
  # @param w [#to_f] offset width (min: 0.0254m)
  # @param v [#to_i] OpenStudio SDK version, eg '321' for "v3.2.1" (optional)
  #
  # @return [OpenStudio::Point3dVector] offset points (see logs if unaltered)
  def offset(p1 = nil, w = 0, v = 0)
    mth = "OSut::#{__callee__}"
    pts = poly(p1, true, true, false, true, :cw)
    return invalid("points", mth, 1, DBG, p1) unless [3, 4].include?(pts.size)

    mismatch("width",   w, Numeric, mth) unless w.respond_to?(:to_f)
    mismatch("version", v, Integer, mth) unless v.respond_to?(:to_i)

    vs = OpenStudio.openStudioVersion.split(".").join.to_i
    iv = true   if pts.size == 4
    v  = v.to_i if v.respond_to?(:to_i)
    v  = -1 unless v.respond_to?(:to_i)
    v  = vs     if v < 0
    w  = w.to_f if w.respond_to?(:to_f)
    w  = 0  unless w.respond_to?(:to_f)
    w  = 0      if w < 0.0254

    unless v < 340
      t      = OpenStudio::Transformation.alignFace(p1)
      offset = OpenStudio.buffer(pts, w, TOL)
      return p1 if offset.empty?

      return to_p3Dv(t * offset.get.reverse)
    else                                                 # brute force approach
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
  # Generates a ULC OpenStudio 3D point vector (a bounding box) that surrounds
  # multiple (smaller) OpenStudio 3D point vectors. The generated, 4-point
  # outline is optionally buffered (or offset). Frame and Divider frame widths
  # are taken into account.
  #
  # @param a [Array] sets of OpenStudio 3D points
  # @param bfr [Numeric] an optional buffer size (min: 0.0254m)
  # @param flat [Bool] if points are to be pre-flattened (Z=0)
  #
  # @return [OpenStudio::Point3dVector] ULC outline (see logs if empty)
  def outline(a = [], bfr = 0, flat = true)
    mth  = "OSut::#{__callee__}"
    flat = true unless [true, false].include?(flat)
    xMIN = nil
    xMAX = nil
    yMIN = nil
    yMAX = nil
    a2   = []
    out  = OpenStudio::Point3dVector.new
    cl   = Array
    return mismatch("array", a, cl, mth, DBG, out) unless a.is_a?(cl)
    return empty("array",           mth, DBG, out)     if a.empty?

    mismatch("buffer", bfr, Numeric, mth) unless bfr.respond_to?(:to_f)

    bfr = bfr.to_f if bfr.respond_to?(:to_f)
    bfr = 0    unless bfr.respond_to?(:to_f)
    bfr = 0        if bfr < 0.0254
    vtx = poly(a.first)
    t   = OpenStudio::Transformation.alignFace(vtx) unless vtx.empty?
    return out                                          if vtx.empty?

    a.each do |pts|
      points = poly(pts, false, true, false, t)
      points = flatten(points) if flat
      next if points.empty?

      a2 << points
    end

    a2.each do |pts|
      minX = pts.min_by(&:x).x
      maxX = pts.max_by(&:x).x
      minY = pts.min_by(&:y).y
      maxY = pts.max_by(&:y).y

      # Consider frame width, if frame-and-divider-enabled sub surface.
      if pts.respond_to?(:allowWindowPropertyFrameAndDivider)
        fd = pts.windowPropertyFrameAndDivider
        w  = 0
        w  = fd.get.frameWidth unless fd.empty?

        if w > TOL
          minX -= w
          maxX += w
          minY -= w
          maxY += w
        end
      end

      xMIN = minX if xMIN.nil?
      xMAX = maxX if xMAX.nil?
      yMIN = minY if yMIN.nil?
      yMAX = maxY if yMAX.nil?

      xMIN = [xMIN, minX].min
      xMAX = [xMAX, maxX].max
      yMIN = [yMIN, minY].min
      yMAX = [yMAX, maxY].max
    end

    return negative("outline width",  mth, DBG, out) if xMAX < xMIN
    return negative("outline height", mth, DBG, out) if yMAX < yMIN
    return zero("outline width",      mth, DBG, out) if (xMIN - xMAX).abs < TOL
    return zero("outline height",     mth, DBG, out) if (yMIN - yMAX).abs < TOL

    # Generate ULC point 3D vector.
    out << OpenStudio::Point3d.new(xMIN, yMAX, 0)
    out << OpenStudio::Point3d.new(xMIN, yMIN, 0)
    out << OpenStudio::Point3d.new(xMAX, yMIN, 0)
    out << OpenStudio::Point3d.new(xMAX, yMAX, 0)

    # Apply buffer, apply ULC (options).
    out = offset(out, bfr, 300) if bfr > 0.0254

    to_p3Dv(t * out)
  end

  ##
  # Returns an array of OpenStudio space-specific surfaces that match criteria,
  # e.g. exterior, north-east facing walls in hotel "lobby". Note 'sides' rely
  # on space coordinates (not absolute model coordinates). And 'sides' are
  # exclusive, not inclusive (e.g. walls strictly north-facing or strictly
  # east-facing would not be returned if 'sides' holds [:north, :east]).
  #
  # @param spaces [Array<OpenStudio::Model::Space>] target spaces
  # @param boundary [#to_s] OpenStudio outside boundary condition
  # @param type [#to_s] OpenStudio surface type
  # @param sides [Arrayl<Symbols>] direction keys, e.g. :north, :top, :bottom
  #
  # @return [Array<OpenStudio::Model::Surface>] surfaces (may be empty)
  def facets(spaces = [], boundary = "Outdoors", type = "Wall", sides = [])
    return [] unless spaces.respond_to?(:&)
    return [] unless sides.respond_to?(:&)
    return []     if sides.empty?

    faces    = []
    list     = [:bottom, :top, :north, :east, :south, :west].freeze
    boundary = trim(boundary).downcase
    type     = trim(type).downcase
    return [] if boundary.empty?
    return [] if type.empty?

    # Keep valid sides.
    orientations = sides.select { |o| list.include?(o) }
    return [] if orientations.empty?

    spaces.each do |space|
      return [] unless space.respond_to?(:setSpaceType)

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
  # 'union' of multiple rectangular, horizontal floor "plates". Each plate
  # must either share an edge with (or encompass or overlap) any of the
  # preceding plates in the array. The generated slab may not be convex.
  #
  # @param [Array<Hash>] pltz individual floor plates, each holding:
  # @option pltz [Numeric] :x left corner of plate origin (bird's eye view)
  # @option pltz [Numeric] :y bottom corner of plate origin (bird's eye view)
  # @option pltz [Numeric] :dx plate width (bird's eye view)
  # @option pltz [Numeric] :dy plate depth (bird's eye view)
  # @param z [Numeric] Z-axis coordinate
  #
  # @return [OpenStudio::Point3dVector] slab vertices (see logs if empty)
  def genSlab(pltz = [], z = 0)
    mth = "OSut::#{__callee__}"
    slb = OpenStudio::Point3dVector.new
    bkp = OpenStudio::Point3dVector.new
    cl1 = Array
    cl2 = Hash
    cl3 = Numeric

    # Input validation.
    return mismatch("plates", pltz, cl1, mth, DBG, slb) unless pltz.is_a?(cl1)
    return mismatch(     "Z",    z, cl3, mth, DBG, slb) unless z.is_a?(cl3)

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
  # Adds sub surfaces (e.g. windows, doors, skylights) to surface.
  #
  # @param s [OpenStudio::Model::Surface] a model surface
  # @param [Array<Hash>] subs requested attributes
  # @option subs [#to_s] :id identifier e.g. "Window 007"
  # @option subs [#to_s] :type ("FixedWindow") OpenStudio subsurface type
  # @option subs [#to_i] :count (1) number of individual subs per array
  # @option subs [#to_i] :multiplier (1) OpenStudio subsurface multiplier
  # @option subs [#frameWidth] :frame (nil) OpenStudio frame & divider object
  # @option subs [#isFenestration] :assembly (nil) OpenStudio construction
  # @option subs [#to_f] :ratio e.g. %FWR [0.0, 1.0]
  # @option subs [#to_f] :head (OSut::HEAD) e.g. door height (incl frame)
  # @option subs [#to_f] :sill (OSut::SILL) e.g. window sill (incl frame)
  # @option subs [#to_f] :height sill-to-head height
  # @option subs [#to_f] :width e.g. door width
  # @option subs [#to_f] :offset left-right centreline dX e.g. between doors
  # @option subs [#to_f] :centreline left-right dX (sub/array vs base)
  # @option subs [#to_f] :r_buffer gap between sub/array and right corner
  # @option subs [#to_f] :l_buffer gap between sub/array and left corner
  # @param clear [Bool] whether to remove current sub surfaces
  # @param bfr [#to_f] safety buffer, to maintain near other edges
  #
  # @return [Bool] whether addition is successful
  # @return [false] if invalid input (see logs)
  def addSubs(s = nil, subs = [], clear = false, bfr = 0.005)
    mth = "OSut::#{__callee__}"
    v   = OpenStudio.openStudioVersion.split(".").join.to_i
    cl1 = OpenStudio::Model::Surface
    cl2 = Array
    cl3 = Hash
    min = 0.050 # minimum ratio value ( 5%)
    max = 0.950 # maximum ratio value (95%)
    no  = false

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Exit if mismatched or invalid argument classes.
    return mismatch("surface",  s, cl2, mth, DBG, no) unless s.is_a?(cl1)
    return mismatch("subs",  subs, cl3, mth, DBG, no) unless subs.is_a?(cl2)
    return empty("surface points",      mth, DBG, no)     if poly(s).empty?

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Clear existing sub surfaces if requested.
    nom = s.nameString
    mdl = s.model

    unless [true, false].include?(clear)
      log(WRN, "#{nom}: Keeping existing sub surfaces (#{mth})")
      clear = false
    end

    s.subSurfaces.map(&:remove) if clear

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Ensure minimum safety buffer.
    if bfr.respond_to?(:to_f)
      bfr = bfr.to_f
      return negative("safety buffer", mth, ERR, no) if bfr < 0

      msg = "Safety buffer < 5mm may generate invalid geometry (#{mth})"
      log(WRN, msg) if bfr < 0.005
    else
      log(ERR, "Setting safety buffer to 5mm (#{mth})")
      bfr = 0.005
    end

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
    t     = OpenStudio::Transformation.alignFace(s.vertices)
    max_x = width(s)
    max_y = height(s)
    mid_x = max_x / 2
    mid_y = max_y / 2

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Assign default values to certain sub keys (if missing), +more validation.
    subs.each_with_index do |sub, index|
      return mismatch("sub", sub, cl4, mth, DBG, no) unless sub.is_a?(cl3)

      # Required key:value pairs (either set by the user or defaulted).
      sub[:frame     ] = nil  unless sub.key?(:frame     )
      sub[:assembly  ] = nil  unless sub.key?(:assembly  )
      sub[:count     ] = 1    unless sub.key?(:count     )
      sub[:multiplier] = 1    unless sub.key?(:multiplier)
      sub[:id        ] = ""   unless sub.key?(:id        )
      sub[:type      ] = type unless sub.key?(:type      )
      sub[:type      ] = trim(sub[:type])
      sub[:id        ] = trim(sub[:id])
      sub[:type      ] = type                   if sub[:type].empty?
      sub[:id        ] = "OSut|#{nom}|#{index}" if sub[:id  ].empty?
      sub[:count     ] = 1 unless sub[:count     ].respond_to?(:to_i)
      sub[:multiplier] = 1 unless sub[:multiplier].respond_to?(:to_i)
      sub[:count     ] = sub[:count     ].to_i
      sub[:multiplier] = sub[:multiplier].to_i
      sub[:count     ] = 1 if sub[:count     ] < 1
      sub[:multiplier] = 1 if sub[:multiplier] < 1

      id = sub[:id]

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

      # Log/reset negative float values. Set ~0.0 values to 0.0.
      sub.each do |key, value|
        next if key == :count
        next if key == :multiplier
        next if key == :type
        next if key == :id
        next if key == :frame
        next if key == :assembly

        ok = value.respond_to?(:to_f)
        return mismatch(key, value, Float, mth, DBG, no) unless ok
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

      # Default sub surface "head" & "sill" height, unless user-specified.
      typ_head = HEAD
      typ_sill = SILL

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
          sub[:width] = glass     if sub[:width] < glass
          sub[:width] = max_width if sub[:width] > max_width
          log(WRN, "Reset '#{id}' width to #{sub[:width]} m (#{mth})")
        end
      end

      # Log/reset "count" if < 1 (or not an Integer)
      if sub[:count].respond_to?(:to_i)
        sub[:count] = sub[:count].to_i

        if sub[:count] < 1
          sub[:count] = 1
          log(WRN, "Reset '#{id}' count to #{sub[:count]} (#{mth})")
        end
      else
        sub[:count] = 1
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
        name = "#{id}|#{i}"
        fr   = 0
        fr   = sub[:frame].frameWidth if sub[:frame]

        vec  = OpenStudio::Point3dVector.new
        vec << OpenStudio::Point3d.new(pos,               sub[:head], 0)
        vec << OpenStudio::Point3d.new(pos,               sub[:sill], 0)
        vec << OpenStudio::Point3d.new(pos + sub[:width], sub[:sill], 0)
        vec << OpenStudio::Point3d.new(pos + sub[:width], sub[:head], 0)
        vec = t * vec

        # Log/skip if conflict between individual sub and base surface.
        vc = vec
        vc = offset(vc, fr, 300) if fr > 0
        ok = fits?(vc, s)
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
          oops = overlaps?(vc, vk)
          log(ERR, "Skip '#{name}': overlaps '#{nome}' (#{mth})") if oops
          ok = false                                              if oops
          break                                                   if oops
        end

        break unless ok

        sb = OpenStudio::Model::SubSurface.new(vec, mdl)
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
