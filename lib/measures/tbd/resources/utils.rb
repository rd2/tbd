# BSD 3-Clause License
#
# Copyright (c) 2022-2024, Denis Bourgeois
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

  # General surface orientations (see facets method)
  SIDZ = [:bottom, # e.g. ground-facing, exposed floros
             :top, # e.g. roof/ceiling
           :north, # NORTH
            :east, # EAST
           :south, # SOUTH
            :west  # WEST
         ].freeze

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
  # Identifies a layered construction's (opaque) insulating layer. The method
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

  ##
  # Validates whether opaque surface can be considered as a curtain wall (or
  # similar technology) spandrel, regardless of construction layers, by looking
  # up AdditionalProperties or its identifier.
  #
  # @param s [OpenStudio::Model::Surface] an opaque surface
  #
  # @return [Bool] whether surface can be considered 'spandrel'
  # @return [false] if invalid input (see logs)
  def spandrel?(s = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Surface
    return invalid("surface", mth, 1, DBG, false) unless s.respond_to?(NS)

    id = s.nameString
    m1  = "#{id}:spandrel"
    m2  = "#{id}:spandrel:boolean"
    return mismatch(id, s, cl, mth) unless s.is_a?(cl)

    if s.additionalProperties.hasFeature("spandrel")
      val = s.additionalProperties.getFeatureAsBoolean("spandrel")
      return invalid(m1, mth, 1, ERR, false) if val.empty?

      val = val.get
      return invalid(m2, mth, 1, ERR, false) unless [true, false].include?(val)
      return val
    end

    id.downcase.include?("spandrel")
  end

  ##
  # Validates whether a sub surface is fenestrated.
  #
  # @param s [OpenStudio::Model::SubSurface] a sub surface
  #
  # @return [Bool] whether subsurface can be considered 'fenestrated'
  # @return [false] if invalid input (see logs)
  def fenestration?(s = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::SubSurface
    return invalid("subsurface", mth, 1, DBG, false) unless s.respond_to?(NS)

    id = s.nameString
    return mismatch(id, s, cl, mth, false) unless s.is_a?(cl)

    # OpenStudio::Model::SubSurface.validSubSurfaceTypeValues
    # "FixedWindow"              : fenestration
    # "OperableWindow"           : fenestration
    # "Door"
    # "GlassDoor"                : fenestration
    # "OverheadDoor"
    # "Skylight"                 : fenestration
    # "TubularDaylightDome"      : fenestration
    # "TubularDaylightDiffuser"  : fenestration
    return false if s.subSurfaceType.downcase == "door"
    return false if s.subSurfaceType.downcase == "overheaddoor"

    true
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
  # @return [Bool] whether model holds valid heating temperature setpoints
  # @return [false] if invalid input (see logs)
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
    m2  = "#{id}:vestibule:boolean"

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
    # By initially relying on the SDK's "partofTotalFloorArea", "space_plenum?"
    # ends up catching a MUCH WIDER range of spaces, which aren't caught by
    # "isPlenum". This includes attics, crawlspaces, non-plenum air spaces above
    # ceiling tiles, and any other UNOCCUPIED space in a model. The term
    # "plenum" in this context is more of a catch-all shorthand - to be used
    # with caution. For instance, "space_plenum?" shouldn't be used (in
    # isolation) to determine whether an UNOCCUPIED space should have its
    # envelope insulated ("plenum") or not ("attic").
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
  # Returns the site/true outward normal vector of a surface.
  #
  # @param s [OpenStudio::Model::PlanarSurface] a surface
  # @param r [#to_f] a group/site rotation angle [0,2PI) radians
  #
  # @return [OpenStudio::Vector3d] true normal vector
  # @return [nil] if invalid input (see logs)
  def trueNormal(s = nil, r = 0)
    mth = "TBD::#{__callee__}"
    cl  = OpenStudio::Model::PlanarSurface
    return mismatch("surface", s, cl, mth)   unless s.is_a?(cl)
    return invalid("rotation angle", mth, 2) unless r.respond_to?(:to_f)

    r = -r.to_f * Math::PI / 180.0
    vx = s.outwardNormal.x * Math.cos(r) - s.outwardNormal.y * Math.sin(r)
    vy = s.outwardNormal.x * Math.sin(r) + s.outwardNormal.y * Math.cos(r)
    vz = s.outwardNormal.z

    OpenStudio::Point3d.new(vx, vy, vz) - OpenStudio::Point3d.new(0, 0, 0)
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
    cl1 = OpenStudio::Point3d
    cl2 = OpenStudio::Point3dVector
    cl3 = OpenStudio::Model::PlanarSurface
    cl4 = Array
    v   = OpenStudio::Point3dVector.new

    if pts.is_a?(cl1)
      v << pts
      return v
    end

    return pts if pts.is_a?(cl2)
    return pts.vertices if pts.is_a?(cl3)

    return mismatch("points", pts, cl1, mth, DBG, v) unless pts.is_a?(cl4)

    pts.each do |pt|
      return mismatch("point", pt, cl4, mth, DBG, v) unless pt.is_a?(cl1)
    end

    pts.each { |pt| v << OpenStudio::Point3d.new(pt.x, pt.y, pt.z) }

    v
  end

  ##
  # Returns true if 2 sets of OpenStudio 3D points are nearly equal.
  #
  # @param s1 [Set<OpenStudio::Point3d>] 1st set of 3D point(s)
  # @param s2 [Set<OpenStudio::Point3d>] 2nd set of 3D point(s)
  # @param indexed [Bool] whether to attempt to harmonize vertex sequence
  #
  # @return [Bool] whether sets are nearly equal (within TOL)
  # @return [false] if invalid input (see logs)
  def same?(s1 = nil, s2 = nil, indexed = true)
    mth = "OSut::#{__callee__}"
    s1  = to_p3Dv(s1).to_a
    s2  = to_p3Dv(s2).to_a
    return false if s1.empty?
    return false if s2.empty?
    return false unless s1.size == s2.size

    indexed = true unless [true, false].include?(indexed)

    if indexed
      xOK = (s1[0].x - s2[0].x).abs < TOL
      yOK = (s1[0].y - s2[0].y).abs < TOL
      zOK = (s1[0].z - s2[0].z).abs < TOL

      if xOK && yOK && zOK && s1.size == 1
        return true
      else
        indx = nil

        s2.each_with_index do |pt, i|
          break if indx

          xOK = (s1[0].x - s2[i].x).abs < TOL
          yOK = (s1[0].y - s2[i].y).abs < TOL
          zOK = (s1[0].z - s2[i].z).abs < TOL

          indx = i if xOK && yOK && zOK
        end

        return false unless indx

        s2 = to_p3Dv(s2).to_a
        s2.rotate!(indx)
      end
    end

    # OpenStudio.isAlmostEqual3dPt(p1, p2, TOL) # ... from v350 onwards.
    s1.size.times.each do |i|
      xOK = (s1[i].x - s2[i].x).abs < TOL
      yOK = (s1[i].y - s2[i].y).abs < TOL
      zOK = (s1[i].z - s2[i].z).abs < TOL
      return false unless xOK && yOK && zOK
    end

    true
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
  # Returns OpenStudio 3D point (in a set) nearest to a point of reference, e.g.
  # grid origin. If left unspecified, the method systematically returns the
  # bottom-left corner (BLC) of any horizontal set. If more than one point fits
  # the initial criteria, the method relies on deterministic sorting through
  # triangulation.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  # @param p01 [OpenStudio::Point3d] point of reference
  #
  # @return [Integer] set index of nearest point to point of reference
  # @return [nil] if invalid input (see logs)
  def nearest(pts = nil, p01 = nil)
    mth = "OSut::#{__callee__}"
    l   = 100
    d01 = 10000
    d02 = 0
    d03 = 0
    idx = nil
    pts = to_p3Dv(pts)
    return idx if pts.empty?

    p03 = OpenStudio::Point3d.new( l,-l,-l)
    p02 = OpenStudio::Point3d.new( l, l, l)
    p01 = OpenStudio::Point3d.new(-l,-l,-l) unless p01
    return mismatch("point", p01, cl, mth) unless p01.is_a?(OpenStudio::Point3d)

    pts.each_with_index { |pt, i| return i if same?(pt, p01) }

    pts.each_with_index do |pt, i|
      length01 = (pt - p01).length
      length02 = (pt - p02).length
      length03 = (pt - p03).length

      if length01.round(2) == d01.round(2)
        if length02.round(2) == d02.round(2)
          if length03.round(2) > d03.round(2)
            idx = i
            d03 = length03
          end
        elsif length02.round(2) > d02.round(2)
          idx = i
          d03 = length03
          d02 = length02
        end
      elsif length01.round(2) < d01.round(2)
        idx = i
        d01 = length01
        d02 = length02
        d03 = length03
      end
    end

    idx
  end

  ##
  # Returns OpenStudio 3D point (in a set) farthest from a point of reference,
  # e.g. grid origin. If left unspecified, the method systematically returns the
  # top-right corner (TRC) of any horizontal set. If more than one point fits
  # the initial criteria, the method relies on deterministic sorting through
  # triangulation.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  # @param p01 [OpenStudio::Point3d] point of reference
  #
  # @return [Integer] set index of farthest point from point of reference
  # @return [nil] if invalid input (see logs)
  def farthest(pts = nil, p01 = nil)
    mth = "OSut::#{__callee__}"
    l   = 100
    d01 = 0
    d02 = 10000
    d03 = 10000
    idx = nil
    pts = to_p3Dv(pts)
    return idx if pts.empty?

    p03 = OpenStudio::Point3d.new( l,-l,-l)
    p02 = OpenStudio::Point3d.new( l, l, l)
    p01 = OpenStudio::Point3d.new(-l,-l,-l) unless p01
    return mismatch("point", p01, cl, mth) unless p01.is_a?(OpenStudio::Point3d)

    pts.each_with_index do |pt, i|
      next if same?(pt, p01)

      length01 = (pt - p01).length
      length02 = (pt - p02).length
      length03 = (pt - p03).length

      if length01.round(2) == d01.round(2)
        if length02.round(2) == d02.round(2)
          if length03.round(2) < d03.round(2)
            idx = i
            d03 = length03
          end
        elsif length02.round(2) < d02.round(2)
          idx = i
          d03 = length03
          d02 = length02
        end
      elsif length01.round(2) > d01.round(2)
        idx = i
        d01 = length01
        d02 = length02
        d03 = length03
      end
    end

    idx
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
  # Validates whether 3D points share X, Y or Z coordinates.
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
    return invalid("axis",               mth, 2, DBG, false) unless ok2

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
  def nextUp(pts = nil, pt = nil)
    mth = "OSut::#{__callee__}"
    pts = to_p3Dv(pts)
    cl  = OpenStudio::Point3d
    return mismatch("point", pt, cl, mth)  unless pt.is_a?(cl)
    return invalid("points (2+)", mth, 1, WRN) if pts.size < 2

    pair = pts.each_cons(2).find { |p1, _| same?(p1, pt) }

    pair.nil? ? pts.first : pair.last
  end

  ##
  # Returns 'width' of a set of OpenStudio 3D points.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [Float] width along X-axis, once re/aligned
  # @return [0.0] if invalid inputs
  def width(pts = nil)
    pts = to_p3Dv(pts)
    return 0 if pts.size < 2

    pts.max_by(&:x).x - pts.min_by(&:x).x
  end

  ##
  # Returns 'height' of a set of OpenStudio 3D points.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [Float] height along Z-axis, or Y-axis if flat
  # @return [0.0] if invalid inputs
  def height(pts = nil)
    pts = to_p3Dv(pts)
    return 0 if pts.size < 2

    min = pts.min_by(&:z).z
    max = pts.max_by(&:z).z
    return max - min if (max - min).abs > TOL

    pts.max_by(&:y).y - pts.min_by(&:y).y
  end

  ##
  # Returns midpoint coordinates of line segment.
  #
  # @param p1 [OpenStudio::Point3d] 1st 3D point of a line segment
  # @param p2 [OpenStudio::Point3d] 2nd 3D point of a line segment
  #
  # @return [OpenStudio::Point3d] midpoint
  # @return [nil] if invalid input (see logs)
  def midpoint(p1 = nil, p2 = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Point3d
    return mismatch("point 1", p1, cl, mth) unless p1.is_a?(cl)
    return mismatch("point 2", p2, cl, mth) unless p2.is_a?(cl)
    return invalid("same points", mth, 0)       if same?(p1, p2)

    midX = p1.x + (p2.x - p1.x)/2
    midY = p1.y + (p2.y - p1.y)/2
    midZ = p1.z + (p2.z - p1.z)/2

    OpenStudio::Point3d.new(midX, midY, midZ)
  end

  ##
  # Returns a vertical 3D plane from 2x 3D points, right-hand rule. Input points
  # are considered last 2 (of 3) points forming the plane; the first point is
  # assumed zenithal. Input points cannot align vertically.
  #
  # @param p1 [OpenStudio::Point3d] 1st 3D point of a line segment
  # @param p2 [OpenStudio::Point3d] 2nd 3D point of a line segment
  #
  # @return [OpenStudio::Plane] 3D plane
  # @return [nil] if invalid input (see logs)
  def verticalPlane(p1 = nil, p2 = nil)
    mth = "OSut::#{__callee__}"
    return mismatch("point 1", p1, cl, mth) unless p1.is_a?(OpenStudio::Point3d)
    return mismatch("point 2", p2, cl, mth) unless p2.is_a?(OpenStudio::Point3d)

    if (p1.x - p2.x).abs < TOL && (p1.y - p2.y).abs < TOL
      return invalid("vertically aligned points", mth)
    end

    zenith = OpenStudio::Point3d.new(p1.x, p1.y, (p2 - p1).length)
    points = OpenStudio::Point3dVector.new
    points << zenith
    points << p1
    points << p2

    OpenStudio::Plane.new(points)
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
  # Returns paired sequential points as (non-zero length) line segments. If the
  # set strictly holds 2x unique points, a single segment is returned.
  # Otherwise, the returned number of segments equals the number of unique
  # points.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [OpenStudio::Point3dVectorVector] line segments (see logs if empty)
  def getSegments(pts = nil)
    mth = "OSut::#{__callee__}"
    vv  = OpenStudio::Point3dVectorVector.new
    pts = getUniques(pts)
    return vv if pts.size < 2

    pts.each_with_index do |p1, i1|
      i2 = i1 + 1
      i2 = 0 if i2 == pts.size
      p2 = pts[i2]

      line = OpenStudio::Point3dVector.new
      line << p1
      line << p2
      vv   << line
      break if pts.size == 2
    end

    vv
  end

  ##
  # Determines if a set of 3D points if a valid segment.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [Bool] whether set is a valid segment
  # @return [false] if invalid input (see logs)
  def segment?(pts = nil)
    pts = to_p3Dv(pts)
    return false     if pts.empty?
    return false unless pts.size == 2
    return false     if same?(pts[0], pts[1])

    true
  end

  ##
  # Returns points as (non-zero length) 'triads', i.e. 3x sequential points.
  # If the set holds less than 3x unique points, an empty triad is
  # returned. Otherwise, the returned number of triads equals the number of
  # unique points. If non-collinearity is requested, then the number of
  # returned triads equals the number of non-collinear points.
  #
  # @param pts [OpenStudio::Point3dVector] 3D points
  #
  # @return [OpenStudio::Point3dVectorVector] triads (see logs if empty)
  def getTriads(pts = nil, co = false)
    mth = "OSut::#{__callee__}"
    vv  = OpenStudio::Point3dVectorVector.new
    pts = getUniques(pts)
    return vv if pts.size < 2

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
      vv  << tri
    end

    vv
  end

  ##
  # Determines if a set of 3D points if a valid triad.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [Bool] whether set is a valid triad (i.e. a trio of 3D points)
  # @return [false] if invalid input (see logs)
  def triad?(pts = nil)
    pts = to_p3Dv(pts)
    return false     if pts.empty?
    return false unless pts.size == 3
    return false     if same?(pts[0], pts[1])
    return false     if same?(pts[0], pts[2])
    return false     if same?(pts[1], pts[2])

    true
  end

  ##
  # Validates whether a 3D point lies ~along a 3D point segment, i.e. less than
  # 10mm from any segment.
  #
  # @param p0 [OpenStudio::Point3d] a 3D point
  # @param sg [Set<OpenStudio::Point3d] a 3D point segment
  #
  # @return [Bool] whether a 3D point lies ~along a 3D point segment
  # @return [false] if invalid input (see logs)
  def pointAlongSegment?(p0 = nil, sg = [])
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Point3d
    cl2 = OpenStudio::Point3dVector
    return mismatch(  "point", p0, cl1, mth, DBG, false) unless p0.is_a?(cl1)
    return mismatch("segment", sg, cl2, mth, DBG, false) unless segment?(sg)

    return true if holds?(sg, p0)

    a   = sg.first
    b   = sg.last
    ab  = b - a
    abn = b - a
    abn.normalize
    ap  = p0 - a
    sp = ap.dot(abn)
    return false if sp < 0

    apd = scalar(abn, sp)
    return false if apd.length > ab.length + TOL

    ap0 = a + apd
    return true if (p0 - ap0).length.round(2) <= TOL

    false
  end

  ##
  # Validates whether a 3D point lies anywhere ~along a set of 3D point
  # segments, i.e. less than 10mm from any segment.
  #
  # @param p0 [OpenStudio::Point3d] a 3D point
  # @param sgs [Set<OpenStudio::Point3d] 3D point segments
  #
  # @return [Bool] whether a 3D point lies ~along a set of 3D point segments
  # @return [false] if invalid input (see logs)
  def pointAlongSegments?(p0 = nil, sgs = [])
    mth = "OSut::#{__callee__}"
    cl1 = OpenStudio::Point3d
    cl2 = OpenStudio::Point3dVectorVector
    sgs = sgs.is_a?(cl2) ? sgs : getSegments(sgs)
    return empty("segments",         mth, DBG, false)     if sgs.empty?
    return mismatch("point", p0, cl, mth, DBG, false) unless p0.is_a?(cl1)

    sgs.each { |sg| return true if pointAlongSegment?(p0, sg) }

    false
  end

  ##
  # Returns point of intersection of 2x 3D line segments.
  #
  # @param s1 [Set<OpenStudio::Point3d] 1st 3D line segment
  # @param s2 [Set<OpenStudio::Point3d] 2nd 3D line segment
  #
  # @return [OpenStudio::Point3d] point of intersection of both lines
  # @return [nil] if no intersection, equal, or invalid input (see logs)
  def getLineIntersection(s1 = [], s2 = [])
    s1  = getSegments(s1)
    s2  = getSegments(s2)
    return nil if s1.empty?
    return nil if s2.empty?

    s1 = s1.first
    s2 = s2.first

    # Matching segments?
    return nil if same?(s1, s2)
    return nil if same?(s1, s2.to_a.reverse)

    a1 = s1[0]
    a2 = s1[1]
    b1 = s2[0]
    b2 = s2[1]

    # Matching segment endpoints?
    return a1 if same?(a1, b1)
    return a2 if same?(a2, b1)
    return a1 if same?(a1, b2)
    return a2 if same?(a2, b2)

    # Segment endpoint along opposite segment?
    return a1 if pointAlongSegments?(a1, s2)
    return a2 if pointAlongSegments?(a2, s2)
    return b1 if pointAlongSegments?(b1, s1)
    return b2 if pointAlongSegments?(b2, s1)

    # Line segments as vectors. Skip if colinear.
    a   = a2 - a1
    b   = b2 - b1
    xab = a.cross(b)
    return nil if xab.length.round(4) < TOL2

    # Link 1st point to other segment endpoints as vectors. Must be coplanar.
    a1b1  = b1 - a1
    a1b2  = b2 - a1
    xa1b1 = a.cross(a1b1)
    xa1b2 = a.cross(a1b2)
    return nil unless xab.cross(xa1b1).length.round(4) < TOL2
    return nil unless xab.cross(xa1b2).length.round(4) < TOL2

    # Both segment endpoints can't be 'behind' point.
    return nil if a.dot(a1b1) < 0 && a.dot(a1b2) < 0

    # Both in 'front' of point? Pick farthest from 'a'.
    if a.dot(a1b1) > 0 && a.dot(a1b2) > 0
      lxa1b1 = xa1b1.length
      lxa1b2 = xa1b2.length

      c1 = lxa1b1.round(4) < lxa1b2.round(4) ? b1 : b2
    else
      c1 = a.dot(a1b1) > 0 ? b1 : b2
    end

    c1a1  = a1 - c1
    xc1a1 = a.cross(c1a1)
    d1    = a1 + xc1a1
    n     = a.cross(xc1a1)
    dot   = b.dot(n)
    n     = n.reverseVector if dot < 0
    f     = c1a1.dot(n) / b.dot(n)
    p0    = c1 + scalar(b, f)

    # Intersection can't be 'behind' point.
    return nil if a.dot(p0 - a1) < 0

    # Ensure intersection is sandwiched between endpoints.
    return nil unless pointAlongSegments?(p0, s2) && pointAlongSegments?(p0, s1)

    p0
  end

  ##
  # Validates whether 3D line segment intersects 3D segments (e.g. polygon).
  #
  # @param l [Set<OpenStudio::Point3d] 3D line segment
  # @param s [Set<OpenStudio::Point3d] 3D segments
  #
  # @return [Bool] whether 3D line intersects 3D segments
  # @return [false] if invalid input (see logs)
  def lineIntersects?(l = [], s = [])
    l   = getSegments(l)
    s   = getSegments(s)
    return nil if l.empty?
    return nil if s.empty?

    l = l.first

    s.each { |segment| return true if getLineIntersection(l, segment) }

    false
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
    return invalid("3+ points"  , mth, 1, DBG, n)     if pts.size < 3
    return invalid("flat points", mth, 1, DBG, n) unless xyz?(pts, :z)

    OpenStudio.pointInPolygon(pts.first, pts, TOL)
  end

  ##
  # Returns OpenStudio 3D points (min 3x) conforming to an UpperLeftCorner (ULC)
  # convention. Points Z-axis values must be ~= 0. Points are returned
  # counterclockwise.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [OpenStudio::Point3dVector] ULC points (see logs if empty)
  def ulc(pts = nil)
    mth = "OSut::#{__callee__}"
    v   = OpenStudio::Point3dVector.new
    pts = to_p3Dv(pts).to_a
    return invalid("points (3+)",      mth, 1, DBG, v)     if pts.size < 3
    return invalid("points (aligned)", mth, 1, DBG, v) unless xyz?(pts, :z)

    # Ensure counterclockwise sequence.
    pts  = pts.reverse if clockwise?(pts)
    minX = pts.min_by(&:x).x
    i0   = nearest(pts)
    p0   = pts[i0]

    pts_x = pts.select { |pt| pt.x.round(2) == minX.round(2) }.reverse

    p1 = pts_x.max_by { |pt| (pt - p0).length }
    i1 = pts.index(p1)

    to_p3Dv(pts.rotate(i1))
  end

  ##
  # Returns OpenStudio 3D points (min 3x) conforming to an BottomLeftCorner
  # (BLC) convention. Points Z-axis values must be ~= 0. Points are returned
  # counterclockwise.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [OpenStudio::Point3dVector] BLC points (see logs if empty)
  def blc(pts = nil)
    mth = "OSut::#{__callee__}"
    v   = OpenStudio::Point3dVector.new
    pts = to_p3Dv(pts).to_a
    return invalid("points (3+)",      mth, 1, DBG, v)     if pts.size < 3
    return invalid("points (aligned)", mth, 1, DBG, v) unless xyz?(pts, :z)

    # Ensure counterclockwise sequence.
    pts  = pts.reverse if clockwise?(pts)
    minX = pts.min_by(&:x).x
    i0   = nearest(pts)
    p0   = pts[i0]

    pts_x = pts.select { |pt| pt.x.round(2) == minX.round(2) }.reverse

    return to_p3Dv(pts.rotate(i0)) if pts_x.include?(p0)

    p1 = pts_x.min_by { |pt| (pt - p0).length }
    i1 = pts.index(p1)

    to_p3Dv(pts.rotate(i1))
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
    return pts if pts.size < 3
    return mismatch("n non-collinears", n, Integer, mth, DBG, v) unless ok

    # Evaluate cross product of vectors of 3x sequential points.
    pts.each_with_index do |p2, i2|
      i1  = i2 - 1
      i3  = i2 + 1
      i3  = 0 if i3 == pts.size
      p1  = pts[i1]
      p3  = pts[i3]
      v13 = p3 - p1
      v12 = p2 - p1
      next if v12.cross(v13).length < TOL2

      a << p2
    end

    if holds?(a, pts[0])
      a = a.rotate(-1) unless same?(a[0], pts[0])
    end

    n = n.to_i
    a = a[0..n-1]  if n > 0
    a = a[n-1..-1] if n < 0

    to_p3Dv(a)
  end

  ##
  # Returns sequential collinear points in an OpenStudio 3D point vector.
  #
  # @param pts [Set<OpenStudio::Point3d] 3D points
  # @param n [#to_i] requested number of collinears (0 returns all)
  #
  # @return [OpenStudio::Point3dVector] collinears (see logs if empty)
  def getCollinears(pts = nil, n = 0)
    mth = "OSut::#{__callee__}"
    pts = getUniques(pts)
    ok  = n.respond_to?(:to_i)
    v   = OpenStudio::Point3dVector.new
    return pts if pts.size < 3
    return mismatch("n collinears", n, Integer, mth, DBG, v) unless ok

    ncolls = getNonCollinears(pts)
    return pts if ncolls.empty?

    to_p3Dv( pts.delete_if { |pt| holds?(ncolls, pt) } )
  end

  ##
  # Returns an OpenStudio 3D point vector as basis for a valid OpenStudio 3D
  # polygon. In addition to basic OpenStudio polygon tests (e.g. all points
  # sharing the same 3D plane, non-self-intersecting), the method can
  # optionally check for convexity, or ensure uniqueness and/or non-collinearity.
  # Returned vector can also be 'aligned', as well as in UpperLeftCorner (ULC)
  # counterclockwise sequence, or in clockwise sequence.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  # @param vx [Bool] whether to check for convexity
  # @param uq [Bool] whether to ensure uniqueness
  # @param co [Bool] whether to ensure non-collinearity
  # @param tt [Bool, OpenStudio::Transformation] whether to 'align'
  # @param sq [:no, :ulc, :blc, :cw] unaltered, ULC, BLC or clockwise sequence
  #
  # @return [OpenStudio::Point3dVector] 3D points (see logs if empty)
  def poly(pts = nil, vx = false, uq = false, co = false, tt = false, sq = :no)
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
    ok2 = sq == :no  || sq == :ulc  || sq == :blc || sq == :cw
    return invalid("transformation", mth, 5, DBG, v) unless ok1
    return invalid("sequence",       mth, 6, DBG, v) unless ok2

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Minimum 3 points?
    p3 = getNonCollinears(pts, 3)
    return empty("polygon", mth, ERR, v) if p3.size < 3

    # Coplanar?
    pln = OpenStudio::Plane.new(p3)

    pts.each do |pt|
      return empty("plane", mth, ERR, v) unless pln.pointOnPlane(pt)
    end

    t  = OpenStudio::Transformation.alignFace(pts)
    at = (t.inverse * pts).reverse

    if tt.is_a?(cl)
      att = (tt.inverse * pts).reverse

      if same?(at, att)
        a = att
        a = ulc(a).to_a if clockwise?(a)
        t = nil
      else
        t = xyz?(att, :z) ? nil : OpenStudio::Transformation.alignFace(att)
        a = t ? (t.inverse * att).reverse : att
      end
    else
      a = at
    end

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Ensure uniqueness and/or non-collinearity. Preserve original sequence.
    p0 = a.first
    a  = getUniques(a).to_a       if uq
    a  = getNonCollinears(a).to_a if co
    i0 = a.index { |pt| same?(pt, p0) }
    a  = a.rotate(i0)             unless i0.nil?

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Check for convexity (optional).
    if vx && a.size > 3
      zen = OpenStudio::Point3d.new(0, 0, 1000)

      getTriads(a).each do |trio|
        p1  = trio[0]
        p2  = trio[1]
        p3  = trio[2]
        v12 = p2 - p1
        v13 = p3 - p1
        x   = (zen - p1).cross(v12)
        return v if x.dot(v13).round(4) > 0
      end
    end

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Alter sequence (optional).
    if tt.is_a?(cl)
      case sq
      when :ulc
        a = t ? to_p3Dv(t * ulc(a.reverse)) : to_p3Dv(ulc(a.reverse))
      when :blc
        a = t ? to_p3Dv(t * blc(a.reverse)) : to_p3Dv(blc(a.reverse))
      when :cw
        a = t ? to_p3Dv(t * a) : to_p3Dv(a)
      else
        a = t ? to_p3Dv(t * a.reverse) : to_p3Dv(a.reverse)
      end
    else
      case sq
      when :ulc
        a = tt ? to_p3Dv(ulc(a.reverse)) : to_p3Dv(t * ulc(a.reverse))
      when :blc
        a = tt ? to_p3Dv(blc(a.reverse)) : to_p3Dv(t * blc(a.reverse))
      when :cw
        a = tt ? to_p3Dv(a) : to_p3Dv(t * a)
      else
        a = tt ? to_p3Dv(a.reverse) : to_p3Dv(t * a.reverse)
      end
    end

    a
  end

  ##
  # Validates whether 3D point is within a 3D polygon. If option 'entirely' is
  # set to true, then the method returns false if point lies along any of the
  # polygon edges, or is very near any of its vertices.
  #
  # @param p0 [OpenStudio::Point3d] a 3D point
  # @param s [Set<OpenStudio::Point3d] a 3D polygon
  # @param entirely [Bool] whether point should be neatly within polygon limits
  #
  # @return [Bool] whether a 3D point lies within a 3D polygon
  # @return [false] if invalid input (see logs)
  def pointWithinPolygon?(p0 = nil, s = [], entirely = false)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Point3d
    s   = poly(s, false, true, true)
    return empty("polygon",          mth, DBG, false)     if s.empty?
    return mismatch("point", p0, cl, mth, DBG, false) unless p0.is_a?(cl)

    n = OpenStudio.getOutwardNormal(s)
    return false if n.empty?

    n  = n.get
    pl = OpenStudio::Plane.new(s.first, n)
    return false unless pl.pointOnPlane(p0)

    entirely = false unless [true, false].include?(entirely)
    segments = getSegments(s)

    # Along polygon edges, or near vertices?
    if pointAlongSegments?(p0, segments)
      return false    if entirely
      return true unless entirely
    end

    segments.each do |segment|
      #   - draw vector from segment midpoint to point
      #   - scale 1000x (assuming no building surface would be 1km wide)
      #   - convert vector to an independent line segment
      #   - loop through polygon segments, tally the number of intersections
      #   - avoid double-counting polygon vertices as intersections
      #   - return false if number of intersections is even
      mid = midpoint(segment.first, segment.last)
      mpV = scalar(mid - p0, 1000)
      p1  = p0 + mpV
      ctr = 0
      pts = []

      # Skip if ~collinear.
      next if (mpV.cross(segment.last - segment.first).length).round(4) < TOL2

      segments.each do |sg|
        intersect = getLineIntersection([p0, p1], sg)
        next unless intersect

        # One of the polygon vertices?
        if holds?(s, intersect)
          next if holds?(pts, intersect)

          pts << intersect
        end

        ctr += 1
      end

      next         if ctr.zero?
      return false if ctr.even?
    end

    true
  end

  ##
  # Validates whether 2 polygons are parallel, regardless of their direction.
  #
  # @param p1 [Set<OpenStudio::Point3d>] 1st set of 3D points
  # @param p2 [Set<OpenStudio::Point3d>] 2nd set of 3D points
  #
  # @return [Bool] whether 2 polygons are parallel
  # @return [false] if invalid input (see logs)
  def parallel?(p1 = nil, p2 = nil)
    p1  = poly(p1, false, true, false)
    p2  = poly(p2, false, true, false)
    return false if p1.empty?
    return false if p2.empty?

    p1 = getNonCollinears(p1, 3)
    p2 = getNonCollinears(p2, 3)
    return false if p1.empty?
    return false if p2.empty?

    pl1 = OpenStudio::Plane.new(p1)
    pl2 = OpenStudio::Plane.new(p2)

    pl1.outwardNormal.dot(pl2.outwardNormal).abs > 0.99
  end

  ##
  # Validates whether a polygon faces upwards.
  #
  # @param pts [Set<OpenStudio::Point3d>] OpenStudio 3D points
  #
  # @return [Bool] if facing upwards
  # @return [false] if invalid input (see logs)
  def facingUp?(pts = nil)
    up  = OpenStudio::Point3d.new(0,0,1) - OpenStudio::Point3d.new(0,0,0)
    pts = poly(pts, false, true, false)
    return false if pts.empty?

    pts = getNonCollinears(pts, 3)
    return false if pts.empty?

    OpenStudio::Plane.new(pts).outwardNormal.dot(up) > 0.99
  end

  ##
  # Validates whether a polygon faces downwards.
  #
  # @param pts [Set<OpenStudio::Point3d>] OpenStudio 3D points
  #
  # @return [Bool] if facing downwards
  # @return [false] if invalid input (see logs)
  def facingDown?(pts = nil)
    lo  = OpenStudio::Point3d.new(0,0,-1) - OpenStudio::Point3d.new(0,0,0)
    pts = poly(pts, false, true, false)
    return false if pts.empty?

    pts = getNonCollinears(pts, 3)
    return false if pts.empty?

    OpenStudio::Plane.new(pts).outwardNormal.dot(lo) > 0.99
  end

  ##
  # Validates whether an OpenStudio polygon is a rectangle (4x sides + 2x
  # diagonals of equal length, meeting at midpoints).
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [Bool] whether polygon is rectangular
  # @return [false] if invalid input (see logs)
  def rectangular?(pts = nil)
    pts = poly(pts, false, false, false)
    return false     if pts.empty?
    return false unless pts.size == 4

    m1 = midpoint(pts[0], pts[2])
    m2 = midpoint(pts[1], pts[3])
    return false unless same?(m1, m2)

    diag1 = pts[2] - pts[0]
    diag2 = pts[3] - pts[1]
    return true if (diag1.length - diag2.length).abs < TOL

    false
  end

  ##
  # Validates whether an OpenStudio polygon is a square (rectangular, 4x ~equal
  # sides).
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points
  #
  # @return [Bool] whether polygon is a square
  # @return [false] if invalid input (see logs)
  def square?(pts = nil)
    d   = nil
    pts = poly(pts, false, false, false)
    return false if pts.empty?
    return false unless rectangular?(pts)

    getSegments(pts).each do |pt|
      l = (pt[1] - pt[0]).length
      d = l unless d
      return false unless l.round(2) == d.round(2)
    end

    true
  end

  ##
  # Determines whether a 1st OpenStudio polygon fits in a 2nd polygon. Vertex
  # sequencing of both polygons must be counterclockwise. If option 'entirely'
  # is set to true, then the method returns false if point lies along any of the
  # polygon edges, or is very near any of its vertices.
  #
  # @param p1 [Set<OpenStudio::Point3d>] 1st set of 3D points
  # @param p2 [Set<OpenStudio::Point3d>] 2nd set of 3D points
  # @param entirely [Bool] whether point should be neatly within polygon limits
  #
  # @return [Bool] whether 1st polygon fits within the 2nd polygon
  # @return [false] if invalid input (see logs)
  def fits?(p1 = nil, p2 = nil, entirely = false)
    pts = []
    p1  = poly(p1)
    p2  = poly(p2)
    return false if p1.empty?
    return false if p2.empty?

    p1.each { |p0| return false unless pointWithinPolygon?(p0, p2) }

    entirely = false unless [true, false].include?(entirely)
    return true unless entirely

    p1.each { |p0| return false unless pointWithinPolygon?(p0, p2, entirely) }

    true
  end

  ##
  # Returns intersection of overlapping polygons, empty if non intersecting. If
  # the optional 3rd argument is left as false, the 2nd polygon may only overlap
  # if it shares the 3D plane equation of the 1st one. If the 3rd argument is
  # instead set to true, then the 2nd polygon is first cast onto the 3D plane of
  # the 1st one; the method therefore returns (as overlap) the intersection of a
  # projection of the 2nd polygon onto the 1st one. The method returns the
  # smallest of the 2 polygons if either fits within the larger one.
  #
  # @param p1 [Set<OpenStudio::Point3d>] 1st set of 3D points
  # @param p2 [Set<OpenStudio::Point3d>] 2nd set of 3D points
  # @param flat [Bool] whether to first align the 2nd set onto the 1st set plane
  #
  # @return [OpenStudio::Point3dVector] largest intersection (see logs if empty)
  def overlap(p1 = nil, p2 = nil, flat = false)
    mth  = "OSut::#{__callee__}"
    flat = false unless [true, false].include?(flat)
    face = OpenStudio::Point3dVector.new
    p01  = poly(p1)
    p02  = poly(p2)
    return empty("points 1", mth, DBG, face) if p01.empty?
    return empty("points 2", mth, DBG, face) if p02.empty?
    return p01 if fits?(p01, p02)
    return p02 if fits?(p02, p01)

    if xyz?(p01, :z)
      t   = nil
      cw1 = clockwise?(p01)
      a1  = cw1 ? p01.to_a.reverse : p01.to_a
      a2  = p02.to_a
      a2  = flatten(a2).to_a if flat
      return invalid("points 2", mth, 2, DBG, face) unless xyz?(a2, :z)

      cw2 = clockwise?(a2)
      a2  = a2.reverse if cw2
    else
      t   = OpenStudio::Transformation.alignFace(p01)
      a1  = t.inverse * p01
      a2  = t.inverse * p02
      a2  = flatten(a2).to_a if flat
      return invalid("points 2", mth, 2, DBG, face) unless xyz?(a2, :z)

      cw2 = clockwise?(a2)
      a2  = a2.reverse if cw2
    end

    # Return either (transformed) polygon if one fits into the other.
    p1t = p01

    if t
      p2t = to_p3Dv(cw2 ? t * a2 : t * a2.reverse)
    else
      if cw1
        p2t = to_p3Dv(cw2 ? a2.reverse : a2)
      else
        p2t = to_p3Dv(cw2 ? a2 : a2.reverse)
      end
    end

    return p1t if fits?(a1, a2)
    return p2t if fits?(a2, a1)

    area1 = OpenStudio.getArea(a1)
    area2 = OpenStudio.getArea(a2)
    return empty("points 1 area", mth, ERR, face) if area1.empty?
    return empty("points 2 area", mth, ERR, face) if area2.empty?

    area1 = area1.get
    area2 = area2.get
    union = OpenStudio.join(a1.reverse, a2.reverse, TOL2)
    return face if union.empty?

    union = union.get
    area  = OpenStudio.getArea(union)
    return face if area.empty?

    area  = area.get
    delta = area1 + area2 - area

    if area > TOL
      return face if  area.round(2) == area1.round(2)
      return face if  area.round(2) == area2.round(2)
      return face if delta.round(2) == 0
    end

    res = OpenStudio.intersect(a1.reverse, a2.reverse, TOL)
    return face if res.empty?

    res  = res.get
    res1 = res.polygon1
    return face if res1.empty?

    to_p3Dv(t ? t * res1.reverse : res1.reverse)
  end

  ##
  # Determines whether OpenStudio polygons overlap.
  #
  # @param p1 [Set<OpenStudio::Point3d>] 1st set of 3D points
  # @param p2 [Set<OpenStudio::Point3d>] 2nd set of 3D points
  # @param flat [Bool] whether points are to be pre-flattened (Z=0)
  #
  # @return [Bool] whether polygons overlap (or fit)
  # @return [false] if invalid input (see logs)
  def overlaps?(p1 = nil, p2 = nil, flat = false)
    overlap(p1, p2, flat).empty? ? false : true
  end

  ##
  # Casts an OpenStudio polygon onto the 3D plane of a 2nd polygon, relying on
  # an independent 3D ray vector.
  #
  # @param p1 [Set<OpenStudio::Point3d>] 1st set of 3D points
  # @param p2 [Set<OpenStudio::Point3d>] 2nd set of 3D points
  # @param ray [OpenStudio::Vector3d] a vector
  #
  # @return [OpenStudio::Point3dVector] cast of p1 onto p2 (see logs if empty)
  def cast(p1 = nil, p2 = nil, ray = nil)
    mth  = "OSut::#{__callee__}"
    cl   = OpenStudio::Vector3d
    face = OpenStudio::Point3dVector.new
    p1   = poly(p1)
    p2   = poly(p2)
    return face if p1.empty?
    return face if p2.empty?
    return mismatch("ray", ray, cl, mth) unless ray.is_a?(cl)

    # From OpenStudio SDK v3.7.0 onwards, one could/should rely on:
    #
    # s3.amazonaws.com/openstudio-sdk-documentation/cpp/OpenStudio-3.7.0-doc/
    # utilities/html/classopenstudio_1_1_plane.html
    # #abc4747b1b041a7f09a6887bc0e5abce1
    #
    #   e.g. p1.each { |pt| face << pl.rayIntersection(pt, ray) }
    #
    # The following +/- replicates the same solution, based on:
    #   https://stackoverflow.com/a/65832417
    p0 = p2.first
    pl = OpenStudio::Plane.new(getNonCollinears(p2, 3))
    n  = pl.outwardNormal
    return face if n.dot(ray).abs < TOL

    p1.each do |pt|
      length = n.dot(pt - p0) / n.dot(ray.reverseVector)
      face << pt + scalar(ray, length)
    end

    face
  end

  ##
  # Generates offset vertices (by width) for a 3- or 4-sided, convex polygon. If
  # width is negative, the vertices are contracted inwards.
  #
  # @param p1 [Set<OpenStudio::Point3d>] OpenStudio 3D points
  # @param w [#to_f] offset width (absolute min: 0.0254m)
  # @param v [#to_i] OpenStudio SDK version, eg '321' for "v3.2.1" (optional)
  #
  # @return [OpenStudio::Point3dVector] offset points (see logs if unaltered)
  def offset(p1 = nil, w = 0, v = 0)
    mth = "OSut::#{__callee__}"
    pts = poly(p1, true, true, false, true, :cw)
    return invalid("points", mth, 1, DBG, p1) unless [3, 4].include?(pts.size)

    mismatch("width",   w, Numeric, mth) unless w.respond_to?(:to_f)
    mismatch("version", v, Integer, mth) unless v.respond_to?(:to_i)

    iv = pts.size == 4 ? true : false
    vs = OpenStudio.openStudioVersion.split(".").join.to_i
    v  = v.respond_to?(:to_i) ? v.to_i : vs
    w  = w.respond_to?(:to_f) ? w.to_f : 0
    return p1 if w.abs < 0.0254

    unless v < 340
      t      = OpenStudio::Transformation.alignFace(p1)
      offset = OpenStudio.buffer(pts, w, TOL)
      return p1 if offset.empty?

      return to_p3Dv(t * offset.get.reverse)
    else # brute force approach
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
    return out if vtx.empty?

    t = OpenStudio::Transformation.alignFace(vtx)

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
  # Generates a BLC box from a triad (3D points). Points must be unique and
  # non-collinear.
  #
  # @param [Set<OpenStudio::Point3d>] a triad (3D points)
  #
  # @return [Set<OpenStudio::Point3D>] a rectangular ULC box (see logs if empty)
  def triadBox(pts = nil)
    mth = "OSut::#{__callee__}"
    bkp = OpenStudio::Point3dVector.new
    box = []
    pts = getNonCollinears(pts)
    return bkp if pts.empty?

    t   = xyz?(pts, :z) ? nil : OpenStudio::Transformation.alignFace(pts)
    pts = poly(pts, false, true, true, t) if t
    return bkp if pts.empty?
    return invalid("triad", mth, 1, ERR, bkp) unless pts.size == 3

    pts = to_p3Dv(pts.to_a.reverse) if clockwise?(pts)
    p0  = pts[0]
    p1  = pts[1]
    p2  = pts[2]

    # Cast p0 unto vertical plane defined by p1/p2.
    pp0 = verticalPlane(p1, p2).project(p0)
    v00 = p0  - pp0
    v11 = pp0 - p1
    v10 = p0  - p1
    v12 = p2  - p1

    # Reset p0 and/or p1 if obtuse or acute.
    if v12.dot(v10) < 0
      p0 = p1 + v00
    elsif v12.dot(v10) > 0
      if v11.length < v12.length
        p1 = pp0
      else
        p0 = p1 + v00
      end
    end

    p3 = p2 + v00

    box << OpenStudio::Point3d.new(p0.x, p0.y, p0.z)
    box << OpenStudio::Point3d.new(p1.x, p1.y, p1.z)
    box << OpenStudio::Point3d.new(p2.x, p2.y, p2.z)
    box << OpenStudio::Point3d.new(p3.x, p3.y, p3.z)

    box = blc(box)
    return bkp unless rectangular?(box)

    box = to_p3Dv(t * box) if t

    box
  end

  ##
  # Generates a BLC box bounded within a triangle (midpoint theorem).
  #
  # pts [Set<OpenStudio::Point3d>] triangular polygon
  #
  # @return [OpenStudio::Point3dVector] medial bounded box (see logs if empty)
  def medialBox(pts = nil)
    mth = "OSut::#{__callee__}"
    bkp = OpenStudio::Point3dVector.new
    box = []
    pts = poly(pts, true, true, true)
    return bkp if pts.empty?
    return invalid("triangle", mth, 1, ERR, bkp) unless pts.size == 3

    t   = xyz?(pts, :z) ? nil : OpenStudio::Transformation.alignFace(pts)
    pts = poly(pts, false, false, false, t) if t
    return bkp if pts.empty?

    pts = to_p3Dv(pts.to_a.reverse) if clockwise?(pts)

    # Generate vertical plane along longest segment.
    mpoints = []
    sgs     = getSegments(pts)
    longest = sgs.max_by { |s| OpenStudio.getDistanceSquared(s.first, s.last) }
    plane   = verticalPlane(longest.first, longest.last)

    # Fetch midpoints of other 2 segments.
    sgs.each { |s| mpoints << midpoint(s.first, s.last) unless s == longest }

    return bkp unless mpoints.size == 2

    # Generate medial bounded box.
    box << plane.project(mpoints.first)
    box << mpoints.first
    box << mpoints.last
    box << plane.project(mpoints.last)
    box = clockwise?(box) ? blc(box.reverse) : blc(box)
    return bkp unless rectangular?(box)
    return bkp unless fits?(box, pts)

    box = to_p3Dv(t * box) if t

    box
  end

  ##
  # Generates a BLC bounded box within a polygon.
  #
  # @param pts [Set<OpenStudio::Point3d>] OpenStudio 3D points
  #
  # @return [OpenStudio::Point3dVector] bounded box (see logs if empty)
  def boundedBox(pts = nil)
    str = ".*(?<!utilities.geometry.join)$"
    OpenStudio::Logger.instance.standardOutLogger.setChannelRegex(str)

    mth = "OSut::#{__callee__}"
    bkp = OpenStudio::Point3dVector.new
    box = []
    pts = poly(pts, false, true, true)
    return bkp if pts.empty?

    t   = xyz?(pts, :z) ? nil : OpenStudio::Transformation.alignFace(pts)
    pts = t.inverse * pts if t
    return bkp if pts.empty?

    pts = to_p3Dv(pts.to_a.reverse) if clockwise?(pts)

    # PATH A : Return medial bounded box if polygon is a triangle.
    if pts.size == 3
      box = medialBox(pts)

      unless box.empty?
        box = to_p3Dv(t * box) if t
        return box
      end
    end

    # PATH B : Return polygon itself if already rectangular.
    if rectangular?(pts)
      box = t ? to_p3Dv(t * pts) : pts
      return box
    end

    aire = 0

    # PATH C : Right-angle, midpoint triad approach.
    getSegments(pts).each do |sg|
      m0 = midpoint(sg.first, sg.last)

      getSegments(pts).each do |seg|
        p1 = seg.first
        p2 = seg.last
        next if same?(p1, sg.first)
        next if same?(p1, sg.last)
        next if same?(p2, sg.first)
        next if same?(p2, sg.first)

        out = triadBox(OpenStudio::Point3dVector.new([m0, p1, p2]))
        next if out.empty?
        next unless fits?(out, pts)

        area = OpenStudio.getArea(out)
        next if area.empty?

        area = area.get
        next if area < TOL
        next if area < aire

        aire = area
        box  = out
      end
    end

    # PATH D : Right-angle triad approach, may override PATH C boxes.
    getSegments(pts).each do |sg|
      p0 = sg.first
      p1 = sg.last

      pts.each do |p2|
        next if same?(p2, p0)
        next if same?(p2, p1)

        out = triadBox(OpenStudio::Point3dVector.new([p0, p1, p2]))
        next if out.empty?
        next unless fits?(out, pts)

        area = OpenStudio.getArea(out)
        next if area.empty?

        area = area.get
        next if area < TOL
        next if area < aire

        aire = area
        box  = out
      end
    end

    unless aire < TOL
      box = to_p3Dv(t * box) if t
      return box
    end

    # PATH E : Medial box, segment approach.
    aire = 0

    getSegments(pts).each do |sg|
      p0 = sg.first
      p1 = sg.last

      pts.each do |p2|
        next if same?(p2, p0)
        next if same?(p2, p1)

        out = medialBox(OpenStudio::Point3dVector.new([p0, p1, p2]))
        next if out.empty?
        next unless fits?(out, pts)

        area = OpenStudio.getArea(box)
        next if area.empty?

        area = area.get
        next if area < TOL
        next if area < aire

        aire = area
        box  = out
      end
    end

    unless aire < TOL
      box = to_p3Dv(t * box) if t
      return box
    end

    # PATH F : Medial box, triad approach.
    aire = 0

    getTriads(pts).each do |sg|
      p0 = sg[0]
      p1 = sg[1]
      p2 = sg[2]

      out = medialBox(OpenStudio::Point3dVector.new([p0, p1, p2]))
      next if out.empty?
      next unless fits?(out, pts)

      area = OpenStudio.getArea(box)
      next if area.empty?

      area = area.get
      next if area < TOL
      next if area < aire

      aire = area
      box  = out
    end

    unless aire < TOL
      box = to_p3Dv(t * box) if t
      return box
    end

    # PATH G : Medial box, triangulated approach.
    aire  = 0
    outer = to_p3Dv(pts.to_a.reverse)
    holes = OpenStudio::Point3dVectorVector.new

    OpenStudio.computeTriangulation(outer, holes).each do |triangle|
      getSegments(triangle).each do |sg|
        p0 = sg.first
        p1 = sg.last

        pts.each do |p2|
          next if same?(p2, p0)
          next if same?(p2, p1)

          out = medialBox(OpenStudio::Point3dVector.new([p0, p1, p2]))
          next if out.empty?
          next unless fits?(out, pts)

          area = OpenStudio.getArea(out)
          next if area.empty?

          area = area.get
          next if area < TOL
          next if area < aire

          aire = area
          box  = out
        end
      end
    end

    return bkp if aire < TOL

    box = to_p3Dv(t * box) if t

    box
  end

  ##
  # Generates re-'aligned' polygon vertices wrt main axis of symmetry of its
  # largest bounded box. A Hash is returned with 6x key:value pairs ...
  # set: realigned (cloned) polygon vertices, box: its bounded box (wrt to :set),
  # bbox: its bounding box, t: its translation transformation, r: its rotation
  # transformation, and o: the origin coordinates of its axis of rotation. First,
  # cloned polygon vertices are rotated so the longest axis of symmetry of its
  # bounded box lies parallel to the X-axis; :o being the midpoint of the narrow
  # side (of the bounded box) nearest to grid origin (0,0,0). Once rotated,
  # polygon vertices are then translated as to ensure one or more vertices are
  # aligned along the X-axis and one or more vertices are aligned along the
  # Y-axis (no vertices with negative X or Y coordinate values). To unalign the
  # returned set of vertices (or its bounded box, or its bounding box), first
  # inverse the translation transformation, then inverse the rotation
  # transformation.
  #
  # @param pts [Set<OpenStudio::Point3d>] OpenStudio 3D points
  #
  # @return [Hash] :set, :box, :bbox, :t, :r & :o
  # @return [Hash] :set, :box, :bbox, :t, :r & :o (nil) if invalid (see logs)
  def getRealignedFace(pts = nil)
    mth = "OSut::#{__callee__}"
    out = { set: nil, box: nil, bbox: nil, t: nil, r: nil, o: nil }
    pts = poly(pts, false, true)
    return out if pts.empty?
    return invalid("aligned plane", mth, 1, DBG, out) unless xyz?(pts, :z)
    return invalid("clockwise pts", mth, 1, DBG, out)     if clockwise?(pts)

    o   = OpenStudio::Point3d.new(0, 0, 0)
    w   = width(pts)
    h   = height(pts)
    d   = h > w ? h : w
    sgs = {}
    box = boundedBox(pts)
    return invalid("bounded box", mth, 0, DBG, out) if box.empty?

    segments = getSegments(box)
    return invalid("bounded box segments", mth, 0, DBG, out) if segments.empty?

    # Deterministic ID of box rotation/translation 'origin'.
    segments.each_with_index do |sg, idx|
      sgs[sg]       = {}
      sgs[sg][:idx] = idx
      sgs[sg][:mid] = midpoint(sg[0], sg[1])
      sgs[sg][:l  ] = (sg[1] - sg[0]).length
      sgs[sg][:mo ] = (sgs[sg][:mid] - o).length
    end

    sgs = sgs.sort_by { |sg, s| s[:mo] }.first(2).to_h     if square?(box)
    sgs = sgs.sort_by { |sg, s| s[:l ] }.first(2).to_h unless square?(box)
    sgs = sgs.sort_by { |sg, s| s[:mo] }.first(2).to_h unless square?(box)

    sg0 = sgs.values[0]
    sg1 = sgs.values[1]

    if (sg0[:mo]).round(2) == (sg1[:mo]).round(2)
      i = sg1[:mid].y.round(2) < sg0[:mid].y.round(2) ? sg1[:idx] : sg0[:idx]
    else
      i = sg0[:idx]
    end

    k = i + 2 < segments.size ? i + 2 : i - 2

    origin   = midpoint(segments[i][0], segments[i][1])
    terminal = midpoint(segments[k][0], segments[k][1])
    seg      = terminal - origin
    right    = OpenStudio::Point3d.new(origin.x + d, origin.y    , 0) - origin
    north    = OpenStudio::Point3d.new(origin.x,     origin.y + d, 0) - origin
    axis     = OpenStudio::Point3d.new(origin.x,     origin.y    , d) - origin
    angle    = OpenStudio::getAngle(right, seg)
    angle    = -angle if north.dot(seg) < 0
    r        = OpenStudio.createRotation(origin, axis, angle)
    pts      = to_p3Dv(r.inverse * pts)
    box      = to_p3Dv(r.inverse * box)
    dX       = pts.min_by(&:x).x
    dY       = pts.min_by(&:y).y
    xy       = OpenStudio::Point3d.new(origin.x + dX, origin.y + dY, 0)
    origin2  = xy - origin
    t        = OpenStudio.createTranslation(origin2)
    set      = t.inverse * pts
    box      = t.inverse * box
    bbox     = outline([set])

    out[:set ] = set
    out[:box ] = box
    out[:bbox] = bbox
    out[:t   ] = t
    out[:r   ] = r
    out[:o   ] = origin

    out
  end

  ##
  # Returns 'width' of a set of OpenStudio 3D points, once re/aligned.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points, once re/aligned
  #
  # @return [Float] width along X-axis, once re/aligned
  # @return [0.0] if invalid inputs
  def alignedWidth(pts = nil)
    pts = poly(pts, false, true, true, true)
    return 0 if pts.size < 2

    pts = getRealignedFace(pts)[:set]
    return 0 if pts.size < 2

    pts.max_by(&:x).x - pts.min_by(&:x).x
  end

  ##
  # Returns 'height' of a set of OpenStudio 3D points, once re/aligned.
  #
  # @param pts [Set<OpenStudio::Point3d>] 3D points, once re/aligned
  #
  # @return [Float] height along Y-axis, once re/aligned
  # @return [0.0] if invalid inputs
  def alignedHeight(pts = nil)
    pts   = pts = poly(pts, false, true, true, true)
    return 0 if pts.size < 2

    pts = getRealignedFace(pts)[:set]
    return 0 if pts.size < 2

    pts.max_by(&:y).y - pts.min_by(&:y).y
  end

  ##
  # Generates leader line anchors, linking polygon vertices to one or more sets
  # (Hashes) of sequenced vertices. By default, the method seeks to link set
  # :vtx (key) vertices (users can select another collection of vertices, e.g.
  # tag == :box). The method minimally validates individual sets of vertices
  # (e.g. coplanarity, non-self-intersecting, no inter-set conflicts). Potential
  # leader lines cannot intersect each other, other 'tagged' set vertices or
  # original polygon edges. For highly-articulated cases (e.g. a narrow polygon
  # with multiple concavities, holding multiple sets), such leader line
  # conflicts will surely occur. The method relies on a 'first-come-first-served'
  # approach: sets without leader lines are ignored (check for set :void keys,
  # see error logs). It is recommended to sort sets prior to calling the method.
  #
  # @param s [Set<OpenStudio::Point3d>] a larger (parent) set of points
  # @param [Array<Hash>] set a collection of sequenced vertices
  # @option [Symbol] tag sequence of set vertices to target
  #
  # @return [Integer] number of successfully-generated anchors (check logs)
  def genAnchors(s = nil, set = [], tag = :vtx)
    mth = "OSut::#{__callee__}"
    dZ  = nil
    t   = nil
    id  = s.respond_to?(:nameString) ? "#{s.nameString}: " : ""
    pts = poly(s)
    n   = 0
    return n if pts.empty?
    return mismatch("set", set, Array, mth, DBG, n) unless set.respond_to?(:to_a)

    set = set.to_a

    # Validate individual sets. Purge surface-specific leader line anchors.
    set.each_with_index do |st, i|
      str1 = id + "set ##{i+1}"
      str2 = str1 + " #{tag.to_s}"
      return mismatch(str1, st, Hash,  mth, DBG, n) unless st.respond_to?(:key?)
      return hashkey( str1, st,  tag,  mth, DBG, n) unless st.key?(tag)
      return empty("#{str2} vertices", mth, DBG, n) if st[tag].empty?

      stt = poly(st[tag])
      return invalid("#{str2} polygon", mth, 0, DBG, n) if stt.empty?
      return invalid("#{str2} gap", mth, 0, DBG, n) unless fits?(stt, pts, true)

      if st.key?(:ld)
        ld = st[:ld]
        return invalid("#{str1} leaders", mth, 0, DBG, n) unless ld.is_a?(Hash)

        ld.reject! { |k, _| k == s }
      else
        st[:ld] = {}
      end
    end

    if facingUp?(pts)
      if xyz?(pts, :z)
        dZ = 0
      else
        dZ = pts.first.z
        pts = flatten(pts).to_a
      end
    else
      t  = OpenStudio::Transformation.alignFace(pts)
      pts = t.inverse * pts
    end

    # Set leader lines anchors. Gather candidate leader line anchors; select
    # anchor with shortest distance to first vertex of 'tagged' set.
    set.each_with_index do |st, i|
      candidates = []
      break if st[:ld].key?(s)

      stt = dZ ? flatten(st[tag]).to_a : t.inverse * st[tag]
      p1  = stt.first

      pts.each_with_index do |pt, k|
        ld  = [pt, p1]
        nb  = 0

        # Check for intersections between leader line and polygon edges.
        getSegments(pts).each do |sg|
          break unless nb.zero?
          next if holds?(sg, pt)

          nb += 1 if lineIntersects?(sg, ld)
        end

        next unless nb.zero?

        # Check for intersections between candidate leader line and other sets.
        set.each_with_index do |other, j|
          break unless nb.zero?
          next if i == j

          ost = dZ ? flatten(other[tag]).to_a : t.inverse * other[tag]
          sgj = getSegments(ost)

          sgj.each { |sg| nb += 1 if lineIntersects?(ld, sg) }
        end

        next unless nb.zero?

        # ... and previous leader lines (first come, first serve basis).
        set.each_with_index do |other, j|
          break unless nb.zero?
          next if i == j
          next unless other[:ld].key?(s)

          ost = other[tag]
          pj  = ost.first
          old = other[:ld][s]
          ldj = dZ ? flatten([ old, pj ]) : t.inverse * [ old, pj ]

          unless same?(old, pt)
            nb += 1 if lineIntersects?(ld, ldj)
          end
        end

        next unless nb.zero?

        # Finally, check for self-intersections.
        getSegments(stt).each do |sg|
          break unless nb.zero?
          next if holds?(sg, p1)

          nb += 1 if lineIntersects?(sg, ld)
          nb += 1 if (sg.first - sg.last).cross(ld.first - ld.last).length < TOL
        end

        candidates << pt if nb.zero?
      end

      if candidates.empty?
        str = id + "set ##{i+1}"
        log(ERR, "#{str}: unable to anchor #{tag} leader line (#{mth})")
        st[:void] = true
      else
        p0 = candidates.sort_by! { |pt| (pt - p1).length }.first

        if dZ
          st[:ld][s] = OpenStudio::Point3d.new(p0.x, p0.y, p0.z + dZ)
        else
          st[:ld][s] = t * p0
        end

        n += 1
      end
    end

    n
  end

  ##
  # Generates extended polygon vertices to circumscribe one or more sets
  # (Hashes) of sequenced vertices. The method minimally validates individual
  # sets of vertices (e.g. coplanarity, non-self-intersecting, no inter-set
  # conflicts). Valid leader line anchors (set key :ld) need to be generated
  # prior to calling the method (see genAnchors). By default, the method seeks
  # to link leader line anchors to set :vtx (key) vertices (users can select
  # another collection of vertices, e.g. tag == :box).
  #
  # @param s [Set<OpenStudio::Point3d>] a larger (parent) set of points
  # @param [Array<Hash>] set a collection of sequenced vertices
  # @option set [Hash] :ld a collection of polygon-specific leader line anchors
  # @option [Symbol] tag sequence of set vertices to target
  #
  # @return [OpenStudio::Point3dVector] extended vertices (see logs if empty)
  def genExtendedVertices(s = nil, set = [], tag = :vtx)
    mth = "OSut::#{__callee__}"
    id  = s.respond_to?(:nameString) ? "#{s.nameString}: " : ""
    f   = false
    pts = poly(s)
    cl  = OpenStudio::Point3d
    a   = OpenStudio::Point3dVector.new
    v   = []
    return a if pts.empty?
    return mismatch("set", set, Array, mth, DBG, a) unless set.respond_to?(:to_a)

    set = set.to_a

    # Validate individual sets.
    set.each_with_index do |st, i|
      str1 = id + "set ##{i+1}"
      str2 = str1 + " #{tag.to_s}"
      return mismatch(str1, st,  Hash, mth, DBG, a) unless st.respond_to?(:key?)
      return hashkey( str1, st,   tag, mth, DBG, a) unless st.key?(tag)
      return empty("#{str2} vertices", mth, DBG, a) if st[tag].empty?
      return hashkey( str1, st,   :ld, mth, DBG, a) unless st.key?(:ld)

      stt = poly(st[tag])
      return invalid("#{str2} polygon", mth, 0, DBG, a) if stt.empty?

      ld = st[:ld]
      return mismatch(str, ld,  Hash, mth, DBG, a) unless ld.is_a?(Hash)
      return hashkey( str, ld,     s, mth, DBG, a) unless ld.key?(s)
      return mismatch(str, ld[s], cl, mth, DBG, a) unless ld[s].is_a?(cl)
    end

    # Re-sequence polygon vertices.
    pts.each do |pt|
      v << pt

      # Loop through each valid set; concatenate circumscribing vertices.
      set.each_with_index do |st, i|
        next unless same?(st[:ld][s], pt)
        next unless st.key?(tag)

        v += st[tag].to_a
        v << pt
      end
    end

    to_p3Dv(v)
  end

  ##
  # Generates arrays of rectangular polygon inserts within a larger polygon. If
  # successful, each set inherits additional key:value pairs: namely :vtx
  # (subset of polygon circumscribing vertices), and :vts (collection of
  # indivudual polygon insert vertices). Valid leader line anchors (set key :ld)
  # need to be generated prior to calling the method (see genAnchors, and
  # genExtendedvertices).
  #
  # @param s [Set<OpenStudio::Point3d>] a larger polygon
  # @param [Array<Hash>] set a collection of polygon insert instructions
  # @option set [Set<OpenStudio::Point3d>] :box bounding box of each collection
  # @option set [Hash] :ld a collection of polygon-specific leader line anchors
  # @option set [Integer] :rows (1) number of rows of inserts
  # @option set [Integer] :cols (1) number of columns of inserts
  # @option set [Numeric] :w0 (1.4) width of individual inserts (wrt cols) min 0.4
  # @option set [Numeric] :d0 (1.4) depth of individual inserts (wrt rows) min 0.4
  # @option set [Numeric] :dX (0) optional left/right X-axis buffer
  # @option set [Numeric] :dY (0) optional top/bottom Y-axis buffer
  #
  # @return [OpenStudio::Point3dVector] new polygon vertices (see logs if empty)
  def genInserts(s = nil, set = [])
    mth = "OSut::#{__callee__}"
    id  = s.respond_to?(:nameString) ? "#{s.nameString}:" : ""
    pts = poly(s)
    cl  = OpenStudio::Point3d
    a   = OpenStudio::Point3dVector.new
    return a if pts.empty?
    return mismatch("set", set, Array, mth, DBG, a) unless set.respond_to?(:to_a)

    set  = set.to_a
    gap  = 0.1
    gap4 = 0.4 # minimum insert width/depth

    # Validate/reset individual set collections.
    set.each_with_index do |st, i|
      str1 = id + "set ##{i+1}"
      return mismatch(str1, st, Hash, mth, DBG, a) unless st.respond_to?(:key?)
      return hashkey( str1, st, :box, mth, DBG, a) unless st.key?(:box)
      return hashkey( str1, st,  :ld, mth, DBG, a) unless st.key?(:ld)

      str2 = str1 + " anchor"
      ld = st[:ld]
      return mismatch(str2, ld,  Hash, mth, DBG, a) unless ld.respond_to?(:key?)
      return hashkey( str2, ld,     s, mth, DBG, a) unless ld.key?(s)
      return mismatch(str2, ld[s], cl, mth, DBG, a) unless ld[s].is_a?(cl)

      # Ensure each set bounding box is safely within larger polygon boundaries.
      # TO DO: In line with related addSkylights "TO DO", expand method to
      #        safely handle 'side' cutouts (i.e. no need for leader lines). In
      #        so doing, boxes could eventually align along surface edges.
      str3 = str1 + " box"
      bx = poly(st[:box])
      return invalid(str3, mth, 0, DBG, a) if bx.empty?
      return invalid("#{str3} rectangle", mth, 0, DBG, a) unless rectangular?(bx)
      return invalid("#{str3} box", mth, 0, DBG, a) unless fits?(bx, pts, true)

      if st.key?(:rows)
        rws = st[:rows]
        return invalid("#{id} rows", mth, 0, DBG, a) unless rws.is_a?(Integer)
        return zero(   "#{id} rows", mth,    DBG, a)     if rws < 1
      else
        st[:rows] = 1
      end

      if st.key?(:cols)
        cls = st[:cols]
        return invalid("#{id} cols", mth, 0, DBG, a) unless cls.is_a?(Integer)
        return zero(   "#{id} cols", mth,    DBG, a)     if cls < 1
      else
        st[:cols] = 1
      end

      if st.key?(:w0)
        w0 = st[:w0]
        return invalid("#{id} width", mth, 0, DBG, a) unless w0.is_a?(Numeric)

        w0 = w0.to_f
        return zero("#{id} width", mth, DBG, a) if w0.round(2) < gap4
      else
        st[:w0] = 1.4
      end

      if st.key?(:d0)
        d0 = st[:d0]
        return invalid("#{id} depth", mth, 0, DBG, a) unless d0.is_a?(Numeric)

        d0 = d0.to_f
        return zero("#{id} depth", mth, DBG, a) if d0.round(2) < gap4
      else
        st[:d0] = 1.4
      end

      if st.key?(:dX)
        dX = st[:dX]
        return invalid( "#{id} dX", mth, 0, DBG, a) unless dX.is_a?(Numeric)
      else
        st[:dX] = nil
      end

      if st.key?(:dY)
        dY = st[:dY]
        return invalid( "#{id} dY", mth, 0, DBG, a) unless dY.is_a?(Numeric)
      else
        st[:dY] = nil
      end
    end

    # Flag conflicts between set bounding boxes. TO DO: ease up for ridges.
    set.each_with_index do |st, i|
      bx = st[:box]

      set.each_with_index do |other, j|
        next if i == j

        bx2  = other[:box]
        str4 = id + "set boxes ##{i+1}:##{j+1}"
        next unless overlaps?(bx, bx2)
        return invalid("#{str4} (overlapping)", mth, 0, DBG, a)
      end
    end

    # Loop through each 'valid' set (i.e. linking a valid leader line anchor),
    # generate set vertex array based on user-provided specs. Reset BLC vertex
    # coordinates once completed.
    set.each_with_index do |st, i|
      str = id + "set ##{i+1}"
      dZ  = nil
      t   = nil
      bx  = st[:box]

      if facingUp?(bx)
        if xyz?(bx, :z)
          dZ = 0
        else
          dZ = bx.first.z
          bx = flatten(bx).to_a
        end
      else
        t  = OpenStudio::Transformation.alignFace(bx)
        bx = t.inverse * bx
      end

      o = getRealignedFace(bx)
      next unless o[:set]

      st[:out] = o
      st[:bx ] = blc(o[:r] * (o[:t] * o[:set]))


      vts  = {} # collection of individual (named) polygon insert vertices
      vtx  = [] # sequence of circumscribing polygon vertices

      bx   = o[:set]
      w    = width(bx)  # overall sandbox width
      d    = height(bx) # overall sandbox depth
      dX   = st[:dX  ]  # left/right buffer (array vs bx)
      dY   = st[:dY  ]  # top/bottom buffer (array vs bx)
      cols = st[:cols]  # number of array columns
      rows = st[:rows]  # number of array rows
      x    = st[:w0  ]  # width of individual insert
      y    = st[:d0  ]  # depth of indivual insert
      gX   = 0          # gap between insert columns
      gY   = 0          # gap between insert rows

      # Gap between insert columns.
      if cols > 1
        dX = ( (w - cols * x) / cols) / 2 unless dX
        gX = (w - 2 * dX - cols * x) / (cols - 1)
        gX = gap if gX.round(2) < gap
        dX = (w - cols * x - (cols - 1) * gX) / 2
      else
        dX = (w - x) / 2
      end

      if dX.round(2) < 0
        log(ERR, "Skipping #{str}: Negative dX {#{mth}}")
        next
      end

      # Gap between insert rows.
      if rows > 1
        dY = ( (d - rows * y) / rows) / 2 unless dY
        gY = (d - 2 * dY - rows * y) / (rows - 1)
        gY = gap if gY.round(2) < gap
        dY = (d - rows * y - (rows - 1) * gY) / 2
      else
        dY = (d - y) / 2
      end

      if dY.round(2) < 0
        log(ERR, "Skipping #{str}: Negative dY {#{mth}}")
        next
      end

      st[:dX] = dX
      st[:gX] = gX
      st[:dY] = dY
      st[:gY] = gY

      x0 = bx.min_by(&:x).x + dX # X-axis starting point
      y0 = bx.min_by(&:y).y + dY # X-axis starting point
      xC = x0                    # current X-axis position
      yC = y0                    # current Y-axis position

      # BLC of array.
      vtx << OpenStudio::Point3d.new(xC, yC, 0)

      # Move up incrementally along left side of sandbox.
      rows.times.each do |iY|
        unless iY.zero?
          yC += gY
          vtx << OpenStudio::Point3d.new(xC, yC, 0)
        end

        yC += y
        vtx << OpenStudio::Point3d.new(xC, yC, 0)
      end

      # Loop through each row: left-to-right, then right-to-left.
      rows.times.each do |iY|
        (cols - 1).times.each do |iX|
          xC += x
          vtx << OpenStudio::Point3d.new(xC, yC, 0)

          xC += gX
          vtx << OpenStudio::Point3d.new(xC, yC, 0)
        end

        # Generate individual polygon inserts, left-to-right.
        cols.times.each do |iX|
          nom  = "#{i}:#{iX}:#{iY}"
          vec  = []
          vec << OpenStudio::Point3d.new(xC    , yC    , 0)
          vec << OpenStudio::Point3d.new(xC    , yC - y, 0)
          vec << OpenStudio::Point3d.new(xC + x, yC - y, 0)
          vec << OpenStudio::Point3d.new(xC + x, yC    , 0)

          # Store.
          vtz = ulc(o[:r] * (o[:t] * vec))

          if dZ
            vz = OpenStudio::Point3dVector.new
            vtz.each { |v| vz << OpenStudio::Point3d.new(v.x, v.y, v.z + dZ) }
            vts[nom] = vz
          else
            vts[nom] = to_p3Dv(t * vtz)
          end

          # Add reverse vertices, circumscribing each insert.
          vec.reverse!
          vec.pop if iX == cols - 1
          vtx += vec

          xC -= gX + x unless iX == cols - 1
        end

        unless iY == rows - 1
          yC -= gY + y
          vtx << OpenStudio::Point3d.new(xC, yC, 0)
        end
      end

      vtx = o[:r] * (o[:t] * vtx)

      if dZ
        vz = OpenStudio::Point3dVector.new
        vtx.each { |v| vz << OpenStudio::Point3d.new(v.x, v.y, v.z + dZ) }
        vtx = vz
      else
        vtx = to_p3Dv(t * vtx)
      end

      st[:vts] = vts
      st[:vtx] = vtx
    end

    # Extended vertex sequence of the larger polygon.
    genExtendedVertices(s, set)
  end

  ##
  # Returns an array of OpenStudio space surfaces or subsurfaces that match
  # criteria, e.g. exterior, north-east facing walls in hotel "lobby". Note that
  # 'sides' rely on space coordinates (not absolute model coordinates). Also,
  # 'sides' are exclusive (not inclusive), e.g. walls strictly north-facing or
  # strictly east-facing would not be returned if 'sides' holds [:north, :east].
  #
  # @param spaces [Set<OpenStudio::Model::Space>] target spaces
  # @param boundary [#to_s] OpenStudio outside boundary condition
  # @param type [#to_s] OpenStudio surface (or subsurface) type
  # @param sides [Set<Symbols>] direction keys, e.g. :north (see OSut::SIDZ)
  #
  # @return [Array<OpenStudio::Model::Surface>] surfaces (may be empty, no logs)
  def facets(spaces = [], boundary = "Outdoors", type = "Wall", sides = [])
    spaces = spaces.is_a?(OpenStudio::Model::Space) ? [spaces] : spaces
    spaces = spaces.respond_to?(:to_a) ? spaces.to_a : []
    return [] if spaces.empty?

    sides = sides.respond_to?(:to_sym) ? [sides] : sides
    sides = sides.respond_to?(:to_a) ? sides.to_a : []

    faces    = []
    boundary = trim(boundary).downcase
    type     = trim(type).downcase
    return [] if boundary.empty?
    return [] if type.empty?

    # Filter sides. If sides is initially empty, return all surfaces of matching
    # type and outside boundary condition.
    unless sides.empty?
      sides = sides.select { |side| SIDZ.include?(side) }
      return [] if sides.empty?
    end

    spaces.each do |space|
      return [] unless space.respond_to?(:setSpaceType)

      space.surfaces.each do |s|
        next unless s.outsideBoundaryCondition.downcase == boundary
        next unless s.surfaceType.downcase == type

        if sides.empty?
          faces << s
        else
          orientations = []
          orientations << :top    if s.outwardNormal.z >  TOL
          orientations << :bottom if s.outwardNormal.z < -TOL
          orientations << :north  if s.outwardNormal.y >  TOL
          orientations << :east   if s.outwardNormal.x >  TOL
          orientations << :south  if s.outwardNormal.y < -TOL
          orientations << :west   if s.outwardNormal.x < -TOL

          faces << s if sides.all? { |o| orientations.include?(o) }
        end
      end
    end

    # SubSurfaces?
    spaces.each do |space|
      break unless faces.empty?

      space.surfaces.each do |s|
        next unless s.outsideBoundaryCondition.downcase == boundary

        s.subSurfaces.each do |sub|
          next unless sub.subSurfaceType.downcase == type

          if sides.empty?
            faces << sub
          else
            orientations = []
            orientations << :top    if sub.outwardNormal.z >  TOL
            orientations << :bottom if sub.outwardNormal.z < -TOL
            orientations << :north  if sub.outwardNormal.y >  TOL
            orientations << :east   if sub.outwardNormal.x >  TOL
            orientations << :south  if sub.outwardNormal.y < -TOL
            orientations << :west   if sub.outwardNormal.x < -TOL

            faces << sub if sides.all? { |o| orientations.include?(o) }
          end
        end
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
  # Returns outdoor-facing, space-related roof surfaces. These include
  # outdoor-facing roofs of each space per se, as well as any outdoor-facing
  # roof surface of unoccupied spaces immediately above (e.g. plenums, attics)
  # overlapping any of the ceiling surfaces of each space.
  #
  # @param spaces [Set<OpenStudio::Model::Space>] target spaces
  #
  # @return [Array<OpenStudio::Model::Surface>] roofs (may be empty)
  def getRoofs(spaces = [])
    mth    = "OSut::#{__callee__}"
    up     = OpenStudio::Point3d.new(0,0,1) - OpenStudio::Point3d.new(0,0,0)
    roofs  = []
    spaces = spaces.is_a?(OpenStudio::Model::Space) ? [spaces] : spaces
    spaces = spaces.respond_to?(:to_a) ? spaces.to_a : []

    spaces = spaces.select { |space| space.is_a?(OpenStudio::Model::Space) }

    # Space-specific outdoor-facing roof surfaces.
    roofs = facets(spaces, "Outdoors", "RoofCeiling")

    # Outdoor-facing roof surfaces of unoccupied plenums or attics above?
    spaces.each do |space|
      # When multiple spaces are involved (e.g. plenums, attics), the target
      # space may not share the same local transformation as the space(s) above.
      # Fetching local transformation.
      t0 = transforms(space)
      next unless t0[:t]

      t0 = t0[:t]

      facets(space, "Surface", "RoofCeiling").each do |ceiling|
        cv0 = t0 * ceiling.vertices

        floor = ceiling.adjacentSurface
        next if floor.empty?

        other = floor.get.space
        next if other.empty?

        other = other.get
        next if other.partofTotalFloorArea

        ti = transforms(other)
        next unless ti[:t]

        ti = ti[:t]

        # TO DO: recursive call for stacked spaces as atria (via AirBoundaries).
        facets(other, "Outdoors", "RoofCeiling").each do |ruf|
          rvi = ti * ruf.vertices
          cst = cast(cv0, rvi, up)
          next unless overlaps?(cst, rvi, false)

          roofs << ruf unless roofs.include?(ruf)
        end
      end
    end

    roofs
  end

  ##
  # Validates whether space has outdoor-facing surfaces with fenestration.
  #
  # @param space [OpenStudio::Model::Space] a space
  # @param sidelit [Bool] whether to check for sidelighting, e.g. windows
  # @param toplit [Bool] whether to check for toplighting, e.g. skylights
  # @param baselit [Bool] whether to check for baselighting, e.g. glazed floors
  #
  # @return [Bool] whether space is daylit
  # @return [false] if invalid input (see logs)
  def daylit?(space = nil, sidelit = true, toplit = true, baselit = true)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Space
    ck1 = space.is_a?(cl)
    ck2 = [true, false].include?(sidelit)
    ck3 = [true, false].include?(toplit)
    ck4 = [true, false].include?(baselit)
    return mismatch("space", space, cl, mth,    DBG, false) unless ck1
    return invalid("sidelit"          , mth, 2, DBG, false) unless ck2
    return invalid("toplit"           , mth, 3, DBG, false) unless ck3
    return invalid("baselit"          , mth, 4, DBG, false) unless ck4

    walls  = sidelit ? facets(space, "Outdoors", "Wall")        : []
    roofs  =  toplit ? facets(space, "Outdoors", "RoofCeiling") : []
    floors = baselit ? facets(space, "Outdoors", "Floor")       : []

    (walls + roofs + floors).each do |surface|
      surface.subSurfaces.each do |sub|
        # All fenestrated subsurface types are considered, as user can set these
        # explicitely (e.g. skylight in a wall) in OpenStudio.
        return true if fenestration?(sub)
      end
    end

    false
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
      return negative("safety buffer", mth, ERR, no) if bfr.round(2) < 0

      msg = "Safety buffer < 5mm may generate invalid geometry (#{mth})"
      log(WRN, msg) if bfr.round(2) < 0.005
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
    t   = OpenStudio::Transformation.alignFace(s.vertices)
    s0  = poly(s, false, false, false, t, :ulc)
    s00 = nil

    if facingUp?(s) || facingDown?(s) # TODO: redundant check?
      s00 = getRealignedFace(s0)
      return false unless s00[:set]

      s0 = s00[:set]
    end

    max_x = width(s0)
    max_y = height(s0)
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
      frame      = sub[:frame] ? sub[:frame].frameWidth : 0
      frames     = 2 * frame
      buffer     = frame + bfr
      buffers    = 2 * buffer
      dim        = 3 * frame > 0.200 ? 3 * frame : 0.200
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
        unless sub[:height].between?(glass - TOL2, max_height + TOL2)
          sub[:height] = glass      if sub[:height] < glass
          sub[:height] = max_height if sub[:height] > max_height
          log(WRN, "Reset '#{id}' height to #{sub[:height]} m (#{mth})")
        end
      end

      # Log/reset "head" height if beyond min/max.
      if sub.key?(:head)
        unless sub[:head].between?(min_head - TOL2, max_head + TOL2)
          sub[:head] = max_head if sub[:head] > max_head
          sub[:head] = min_head if sub[:head] < min_head
          log(WRN, "Reset '#{id}' head height to #{sub[:head]} m (#{mth})")
        end
      end

      # Log/reset "sill" height if beyond min/max.
      if sub.key?(:sill)
        unless sub[:sill].between?(min_sill - TOL2, max_sill + TOL2)
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

        if sill < min_sill - TOL2
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

        if sub.key?(:height) && (sub[:height] - height).abs > TOL2
          log(WRN, "(Re)set '#{id}' height to #{height} m (#{mth})")
        end

        sub[:height] = height
      elsif sub.key?(:head) # no "sill"
        if sub.key?(:height)
          sill = sub[:head] - sub[:height]

          if sill < min_sill - TOL2
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

          if head > max_head - TOL2
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
        head = s00 ? mid_y + sub[:height]/2 : typ_head
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
        unless sub[:width].between?(glass - TOL2, max_width + TOL2)
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
        if sub[:l_buffer] < min_ljamb - TOL
          sub[:l_buffer] = min_ljamb
          log(WRN, "Reset '#{id}' left buffer to #{sub[:l_buffer]} m (#{mth})")
        end
      end

      # Log/reset if right-sided buffer beyond max jamb position.
      if sub.key?(:r_buffer)
        if sub[:r_buffer] > max_rjamb - TOL
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
        if x0 < min_ljamb - TOL2 || xf > max_rjamb - TOL2
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
        if x0 < bfr - TOL2 || xf > max_x - bfr - TOL2
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
        vec = s00 ? t * (s00[:r] * (s00[:t] * vec)) : t * vec

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
  # Validates whether surface is considered a sloped roof (outdoor-facing,
  # 10% < tilt < 90%).
  #
  # @param s [OpenStudio::Model::Surface] a model surface
  #
  # @return [Bool] whether surface is a sloped roof
  # @return [false] if invalid input (see logs)
  def slopedRoof?(s = nil)
    mth = "OSut::#{__callee__}"
    cl  = OpenStudio::Model::Surface
    return mismatch("surface", s, cl, mth, DBG, false) unless s.is_a?(cl)

    return false if facingUp?(s)
    return false if facingDown?(s)

    true
  end

  ##
  # Returns the "gross roof area" above selected conditioned, occupied spaces.
  # This includes all roof surfaces of indirectly-conditioned, unoccupied spaces
  # like plenums (if located above any of the selected spaces). This also
  # includes roof surfaces of unconditioned or unenclosed spaces like attics, if
  # vertically-overlapping any ceiling of occupied spaces below; attic roof
  # sections above uninsulated soffits are excluded, for instance.
  def grossRoofArea(spaces = [])
    mth = "OSut::#{__callee__}"
    up  = OpenStudio::Point3d.new(0,0,1) - OpenStudio::Point3d.new(0,0,0)
    rm2 = 0
    rfs = {}

    spaces = spaces.is_a?(OpenStudio::Model::Space) ? [spaces] : spaces
    spaces = spaces.respond_to?(:to_a) ? spaces.to_a : []
    spaces = spaces.select { |space| space.is_a?(OpenStudio::Model::Space) }
    spaces = spaces.select { |space| space.partofTotalFloorArea }
    return invalid("spaces", mth, 1, DBG, 0) if spaces.empty?

    # The method is very similar to OpenStudio-Standards' :
    #   find_exposed_conditioned_roof_surfaces(model)
    #
    # github.com/NREL/openstudio-standards/blob/
    # be81bd88dc55a44d8cce3ee6daf29c768032df6a/lib/openstudio-standards/
    # standards/Standards.Surface.rb#L99
    #
    # ... yet differs with regards to attics with overhangs/soffits.

    # Start with roof surfaces of occupied spaces.
    spaces.each do |space|
      facets(space, "Outdoors", "RoofCeiling").each do |roof|
        next if rfs.key?(roof)

        rfs[roof] = {m2: roof.grossArea, m: space.multiplier}
      end
    end

    # Roof surfaces of unoccupied, conditioned spaces above (e.g. plenums)?
    # TO DO: recursive call for stacked spaces as atria (via AirBoundaries).
    spaces.each do |space|
      facets(space, "Surface", "RoofCeiling").each do |ceiling|
        floor = ceiling.adjacentSurface
        next if floor.empty?

        other = floor.get.space
        next if other.empty?

        other = other.get
        next if other.partofTotalFloorArea
        next if unconditioned?(other)

        facets(other, "Outdoors", "RoofCeiling").each do |roof|
          next if rfs.key?(roof)

          rfs[roof] = {m2: roof.grossArea, m: other.multiplier}
        end
      end
    end

    # Roof surfaces of unoccupied, unconditioned spaces above (e.g. attics)?
    # TO DO: recursive call for stacked spaces as atria (via AirBoundaries).
    spaces.each do |space|
      # When taking overlaps into account, the target space may not share the
      # same local transformation as the space(s) above.
      t0 = transforms(space)
      next unless t0[:t]

      t0 = t0[:t]

      facets(space, "Surface", "RoofCeiling").each do |ceiling|
        cv0 = t0 * ceiling.vertices

        floor = ceiling.adjacentSurface
        next if floor.empty?

        other = floor.get.space
        next if other.empty?

        other = other.get
        next if other.partofTotalFloorArea
        next unless unconditioned?(other)

        ti = transforms(other)
        next unless ti[:t]

        ti = ti[:t]

        facets(other, "Outdoors", "RoofCeiling").each do |roof|
          rvi  = ti * roof.vertices
          cst  = cast(cv0, rvi, up)
          next if cst.empty?

          # The overlap calculation fails for roof and ceiling surfaces with
          # previously-added leader lines.
          #
          # TODO: revise approach for attics ONCE skylight wells have been added.
          olap = nil
          olap = overlap(cst, rvi, false)
          next if olap.empty?

          m2 = OpenStudio.getArea(olap)
          next if m2.empty?

          m2 = m2.get
          next unless m2.round(2) > 0

          rfs[roof] = {m2: 0, m: other.multiplier} unless rfs.key?(roof)

          rfs[roof][:m2] += m2
        end
      end
    end

    rfs.values.each { |rf| rm2 += rf[:m2] * rf[:m] }

    rm2
  end

  ##
  # Identifies horizontal ridges between 2x sloped roof surfaces (same space).
  # If successful, the returned Array holds 'ridge' Hashes. Each Hash holds: an
  # :edge (OpenStudio::Point3dVector), the edge :length (Numeric), and :roofs
  # (Array of 2x linked roof surfaces). Each roof surface may be linked to more
  # than one horizontal ridge.
  #
  # @param roofs [Array<OpenStudio::Model::Surface>] target roof surfaces
  #
  # @return [Array] horizontal ridges (see logs if empty)
  def getHorizontalRidges(roofs = [])
    mth    = "OSut::#{__callee__}"
    ridges = []
    return ridges unless roofs.is_a?(Array)

    roofs = roofs.select { |s| s.is_a?(OpenStudio::Model::Surface) }
    roofs = roofs.select { |s| slopedRoof?(s) }

    roofs.each do |roof|
      maxZ = roof.vertices.max_by(&:z).z
      next if roof.space.empty?

      space = roof.space.get

      getSegments(roof).each do |edge|
        next unless xyz?(edge, :z, maxZ)

        # Skip if already tracked.
        match = false

        ridges.each do |ridge|
          break if match

          edg   = ridge[:edge]
          match = same?(edge, edg) || same?(edge, edg.reverse)
        end

        next if match

        ridge = { edge: edge, length: (edge[1] - edge[0]).length, roofs: [roof] }

        # Links another roof (same space)?
        match = false

        roofs.each do |ruf|
          break if match
          next  if ruf == roof
          next  if ruf.space.empty?
          next  unless ruf.space.get == space

          getSegments(ruf).each do |edg|
            break if match
            next unless same?(edge, edg) || same?(edge, edg.reverse)

            ridge[:roofs] << ruf
            ridges << ridge
            match = true
          end
        end
      end
    end

    ridges
  end

  ##
  # Adds skylights to toplight selected OpenStudio (occupied, conditioned)
  # spaces, based on requested skylight-to-roof (SRR%) options (max 10%). If the
  # user selects 0% (0.0) as the :srr while keeping :clear as true, the method
  # simply purges all pre-existing roof subsurfaces (whether glazed or not) of
  # selected spaces, and exits while returning 0 (without logging an error or
  # warning). Pre-toplit spaces are otherwise ignored. Boolean options :attic,
  # :plenum, :sloped and :sidelit, further restrict candidate roof surfaces. If
  # applicable, options :attic and :plenum add skylight wells. Option :patterns
  # restricts preset skylight allocation strategies in order of preference; if
  # left empty, all preset patterns are considered, also in order of preference
  # (see examples).
  #
  # @param spaces [Array<OpenStudio::Model::Space>] space(s) to toplight
  # @param [Hash] opts requested skylight attributes
  # @option opts [#to_f] :srr skylight-to-roof ratio (0.00, 0.10]
  # @option opts [#to_f] :size (1.22) template skylight width/depth (min 0.4m)
  # @option opts [#frameWidth] :frame (nil) OpenStudio Frame & Divider (optional)
  # @option opts [Bool] :clear (true) whether to first purge existing skylights
  # @option opts [Bool] :sidelit (true) whether to consider sidelit spaces
  # @option opts [Bool] :sloped (true) whether to consider sloped roof surfaces
  # @option opts [Bool] :plenum (true) whether to consider plenum wells
  # @option opts [Bool] :attic (true) whether to consider attic wells
  # @option opts [Array<#to_s>] :patterns requested skylight allocation (3x)
  # @example (a) consider 2D array of individual skylights, e.g. n(1.2m x 1.2m)
  #   opts[:patterns] = ["array"]
  # @example (b) consider 'a', then array of 1x(size) x n(size) skylight strips
  #   opts[:patterns] = ["array", "strips"]
  #
  # @return [Float] returns gross roof area if successful (see logs if 0 m2)
  def addSkyLights(spaces = [], opts = {})
    mth   = "OSut::#{__callee__}"
    clear = true
    srr   = 0.0
    frame = nil   # FrameAndDivider object
    f     = 0.0   # FrameAndDivider frame width
    gap   = 0.1   # min 2" around well (2x), as well as max frame width
    gap2  = 0.2   # 2x gap
    gap4  = 0.4   # minimum skylight 16" width/depth (excluding frame width)
    bfr   = 0.005 # minimum array perimeter buffer (no wells)
    w     = 1.22  # default 48" x 48" skylight base
    w2    = w * w # m2


    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Excerpts of ASHRAE 90.1 2022 definitions:
    #
    # "ROOF":
    #
    #   "the upper portion of the building envelope, including opaque areas and
    #   fenestration, that is horizontal or tilted at an angle of less than 60
    #   degrees from horizontal. For the purposes of determining building
    #   envelope requirements, the classifications are defined as follows
    #   (inter alia):
    #
    #     - attic and other roofs: all other roofs, including roofs with
    #       insulation ENTIRELY BELOW (inside of) the roof structure (i.e.,
    #       attics, cathedral ceilings, and single-rafter ceilings), roofs with
    #       insulation both above and BELOW the roof structure, and roofs
    #       without insulation but excluding metal building roofs. [...]"
    #
    # "ROOF AREA, GROSS":
    #
    #   "the area of the roof measured from the EXTERIOR faces of walls or from
    #   the centerline of party walls."
    #
    #
    # For the simple case below (steep 4-sided hip roof, UNENCLOSED ventilated
    # attic), 90.1 users typically choose between either:
    #   1. modelling the ventilated attic explicitely, or
    #   2. ignoring the ventilated attic altogether.
    #
    # If skylights were added to the model, option (1) would require one or more
    # skylight wells (light shafts leading to occupied spaces below), with
    # insulated well walls separating CONDITIONED spaces from an UNENCLOSED,
    # UNCONDITIONED space (i.e. attic).
    #
    # Determining which roof surfaces (or which portion of roof surfaces) need
    # to be considered when calculating "GROSS ROOF AREA" may be subject to some
    # interpretation. From the above definitions:
    #
    #   - the uninsulated, tilted hip-roof attic surfaces are considered "ROOF"
    #     surfaces, provided they 'shelter' insulation below (i.e. insulated
    #     attic floor).
    #   - however, only the 'projected' portion of such "ROOF" surfaces, i.e.
    #     areas between axes AA` and BB` (along exterior walls)) would be
    #     considered.
    #   - the portions above uninsulated soffits (illustrated on the right)
    #     would be excluded from the "GROSS ROOF AREA" as they are beyond the
    #     exterior wall projections.
    #
    #     A         B
    #     |         |
    #      _________
    #     /          \                  /|        |\
    #    /            \                / |        | \
    #   /_  ________  _\    = >       /_ |        | _\   ... excluded portions
    #     |          |
    #     |__________|
    #     .          .
    #     A`         B`
    #
    # If the unoccupied space (directly under the hip roof) were instead an
    # INDIRECTLY-CONDITIONED plenum (not an attic), then there would be no need
    # to exclude portions of any roof surface: all plenum roof surfaces (in
    # addition to soffit surfaces) would need to be insulated). The method takes
    # such circumstances into account, which requires vertically casting of
    # surfaces ontoothers, as well as overlap calculations. If successful, the
    # method returns the "GROSS ROOF AREA" (in m2), based on the above rationale.
    #
    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Excerpts of similar NECB requirements (unchanged from 2011 through 2020):
    #
    #   3.2.1.4. 2). "The total skylight area shall be less than 2% of the GROSS
    #   ROOF AREA as determined in Article 3.1.1.6." (5% in earlier versions)
    #
    #   3.1.1.6. 5). "In the calculation of allowable skylight area, the GROSS
    #   ROOF AREA shall be calculated as the sum of the areas of insulated
    #   roof including skylights."
    #
    # There are NO additional details or NECB appendix notes on the matter. It
    # is unclear if the NECB's looser definition of GROSS ROOF AREA includes
    # (uninsulated) sloped roof surfaces above (insulated) flat ceilings (e.g.
    # attics), as with 90.1. It would be definitely odd if it didn't. For
    # instance, if the GROSS ROOF AREA were based on insulated ceiling surfaces,
    # there would be a topological disconnect between flat ceiling and sloped
    # skylights above. Should NECB users first 'project' (sloped) skylight rough
    # openings onto flat ceilings when calculating %SRR? Without much needed
    # clarification, the (clearer) 90.1 rules equally apply here to NECB cases.

    # If skylight wells are indeed required, well wall edges are always vertical
    # (i.e. never splayed), requiring a vertical ray.
    origin = OpenStudio::Point3d.new(0,0,0)
    zenith = OpenStudio::Point3d.new(0,0,1)
    ray    = zenith - origin

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Accept a single 'OpenStudio::Model::Space' (vs an array of spaces).
    if spaces.respond_to?(:spaceType) || spaces.respond_to?(:to_a)
      spaces = spaces.respond_to?(:to_a) ? spaces.to_a : [spaces]
      spaces = spaces.select { |space| space.respond_to?(:spaceType) }
      spaces = spaces.select { |space| space.partofTotalFloorArea }
      spaces = spaces.reject { |space| unconditioned?(space) }
      return empty("spaces", mth, DBG, 0) if spaces.empty?
    else
      return mismatch("spaces", spaces, Array, mth, DBG, 0)
    end

    mdl = spaces.first.model

    # Exit if mismatched or invalid argument classes/keys.
    return mismatch("opts", opts, Hash, mth, DBG, 0) unless opts.is_a?(Hash)
    return  hashkey( "srr", opts, :srr, mth, ERR, 0) unless opts.key?(:srr)

    # Validate requested skylight-to-roof ratio.
    if opts[:srr].respond_to?(:to_f)
      srr = opts[:srr].to_f
      log(WRN, "Resetting srr to 0% (#{mth})")  if srr < 0
      log(WRN, "Resetting srr to 10% (#{mth})") if srr > 0.10
      srr = srr.clamp(0.00, 0.10)
    else
      return mismatch("srr", opts[:srr], Numeric, mth, DBG, 0)
    end

    # Validate Frame & Divider object, if provided.
    if opts.key?(:frame)
      frame = opts[:frame]

      if frame.respond_to?(:frameWidth)
        frame = nil if v < 321
        frame = nil if f.frameWidth.round(2) < 0
        frame = nil if f.frameWidth.round(2) > gap

        f = f.frameWidth                            if frame
        log(WRN, "Skip Frame&Divider (#{mth})") unless frame
      else
        frame = nil
        log(ERR, "Skip invalid Frame&Divider object (#{mth})")
      end
    end

    # Validate skylight size, if provided.
    if opts.key?(:size)
      if opts[:size].respond_to?(:to_f)
        w  = opts[:size].to_f
        w2 = w * w
        return invalid(size, mth, 0, ERR, 0) if w.round(2) < gap4
      else
        return mismatch("size", opts[:size], Numeric, mth, DBG, 0)
      end
    end

    f2  = 2 * f
    w0  = w + f2
    w02 = w0 * w0
    wl  = w0 + gap
    wl2 = wl * wl

    # Validate purge request, if provided.
    if opts.key?(:clear)
      clear = opts[:clear]

      unless [true, false].include?(clear)
        log(WRN, "Purging existing skylights by default (#{mth})")
        clear = true
      end
    end

    getRoofs(spaces).each { |s| s.subSurfaces.map(&:remove) } if clear

    # Safely exit, e.g. if strictly called to purge existing roof subsurfaces.
    return 0 if srr < TOL

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # The method seeks to insert a skylight array within the largest rectangular
    # 'bounded box' that neatly 'fits' within a given roof surface. This equally
    # applies to any vertically-cast overlap between roof and plenum (or attic)
    # floor, which in turn generates skylight wells. Skylight arrays are
    # inserted from left/right + top/bottom (as illustrated below), once a roof
    # (or cast 3D overlap) is 'aligned' in 2D (possibly also 'realigned').
    #
    # Depending on geometric complexity (e.g. building/roof concavity,
    # triangulation), the total area of bounded boxes may be significantly less
    # than the calculated "GROSS ROOF AREA", which can make it challenging to
    # attain the desired %SRR. If :patterns are left unaltered, the method will
    # select patterns that maximize the likelihood of attaining the requested
    # %SRR, to the detriment of spatial distribution of daylighting.
    #
    # The default skylight module size is 1.2m x 1.2m (4' x 4'), which be
    # overridden by the user, e.g. 2.4m x 2.4m (8' x 8').
    #
    # Preset skylight allocation patterns (in order of precedence):
    #    1. "array"
    #   _____________________
    #  |   _      _      _   |  - ?x columns ("cols") >= ?x rows (min 2x2)
    #  |  |_|    |_|    |_|  |  - SRR ~5% (1.2m x 1.2m), as illustrated
    #  |                     |  - SRR ~19% (2.4m x 2.4m)
    #  |   _      _      _   |  - +suitable for wide spaces (storage, retail)
    #  |  |_|    |_|    |_|  |  - ~1.4x height + skylight width 'ideal' rule
    #  |_____________________|  - better daylight distribution, many wells
    #
    #    2. "strips"
    #   _____________________
    #  |   _      _      _   |  - ?x columns (min 2), 1x row
    #  |  | |    | |    | |  |  - ~doubles %SRR ...
    #  |  | |    | |    | |  |  - SRR ~10% (1.2m x ?1.2m), as illustrated
    #  |  | |    | |    | |  |  - SRR ~19% (2.4m x ?1.2m)
    #  |  |_|    |_|    |_|  |  - ~roof monitor layout
    #  |_____________________|  - fewer wells
    #
    #    3. "strip"
    #    ____________________
    #   |                    |  - 1x column, 1x row (min 1x)
    #   |   ______________   |  - SRR ~11% (1.2m x ?1.2m)
    #   |  | ............ |  |  - SRR ~22% (2.4m x ?1.2m), as illustrated
    #   |  |______________|  |  - +suitable for elongated bounded boxes
    #   |                    |  - 1x well
    #   |____________________|
    #
    #   TO-DO: Support strips/strip patterns along ridge of paired roof surfaces.
    layouts  = ["array", "strips", "strip"]
    patterns = []

    # Validate skylight placement patterns, if provided.
    if opts.key?(:patterns)
      if opts[:patterns].is_a?(Array)
        opts[:patterns].each_with_index do |pattern, i|
          pattern = trim(pattern).downcase

          if pattern.empty?
            invalid("pattern #{i+1}", mth, 0, ERR)
            next
          end

          patterns << pattern if layouts.include?(pattern)
        end
      else
        mismatch("patterns", opts[:patterns], Array, mth, DBG)
      end
    end

    patterns = layouts if patterns.empty?

    # The method first attempts to add skylights in ideal candidate spaces:
    #   - large roof surface areas (e.g. retail, classrooms ... not corridors)
    #   - not sidelit (favours core spaces)
    #   - having flat roofs (avoids sloped roofs)
    #   - not under plenums, nor attics (avoids wells)
    #
    # This ideal (albeit stringent) set of conditions is "combo a".
    #
    # If required %SRR has not yet been achieved, the method decrementally drops
    # selection criteria and starts over, e.g.:
    #   - then considers sidelit spaces
    #   - then considers sloped roofs
    #   - then considers skylight wells
    #
    # A maximum number of skylights are allocated to roof surfaces matching a
    # given combo. Priority is always given to larger roof areas. If
    # unsuccessful in meeting the required %SRR target, a single criterion is
    # then dropped (e.g. b, then c, etc.), and the allocation process is
    # relaunched. An error message is logged if the %SRR isn't ultimately met.
    #
    # Through filters, users may restrict candidate roof surfaces:
    #   b. above occupied sidelit spaces ('false' restricts to core spaces)
    #   c. that are sloped ('false' restricts to flat roofs)
    #   d. above indirectly conditioned spaces (e.g. plenums, uninsulated wells)
    #   e. above unconditioned spaces (e.g. attics, insulated wells)
    filters = ["a", "b", "bc", "bcd", "bcde"]

    # Prune filters, based on user-selected options.
    [:sidelit, :sloped, :plenum, :attic].each do |opt|
      next unless opts.key?(opt)
      next unless opts[opt] == false

      case opt
      when :sidelit then filters.map! { |f| f.include?("b") ? f.delete("b") : f }
      when :sloped  then filters.map! { |f| f.include?("c") ? f.delete("c") : f }
      when :plenum  then filters.map! { |f| f.include?("d") ? f.delete("d") : f }
      when :attic   then filters.map! { |f| f.include?("e") ? f.delete("e") : f }
      end
    end

    filters.reject! { |f| f.empty? }
    filters.uniq!

    # Remaining filters may be further reduced (after space/roof processing),
    # depending on geometry, e.g.:
    #  - if there are no sidelit spaces: filter "b" will be pruned away
    #  - if there are no sloped roofs  : filter "c" will be pruned away
    #  - if no plenums are identified  : filter "d" will be pruned away
    #  - if no attics are identified   : filter "e" will be pruned away

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Break down spaces (and connected spaces) into groups.
    sets     = [] # collection of skylight arrays to deploy
    rooms    = {} # occupied CONDITIONED spaces to toplight
    plenums  = {} # unoccupied (INDIRECTLY-) CONDITIONED spaces above rooms
    attics   = {} # unoccupied UNCONDITIONED spaces above rooms
    ceilings = {} # of occupied CONDITIONED space (if plenums/attics)

    # Select candidate 'rooms' to toplit - excludes plenums/attics.
    spaces.each do |space|
      next if unconditioned?(space)          # e.g. attic
      next unless space.partofTotalFloorArea # occupied (not plenum)

      # Already toplit?
      if daylit?(space, false, true, false)
        log(WRN, "#{id} is already toplit, skipping (#{mth})")
        next
      end

      # When unoccupied spaces are involved (e.g. plenums, attics), the occupied
      # space (to toplight) may not share the same local transformation as its
      # unoccupied space(s) above. Fetching local transformation.
      h  = 0
      t0 = transforms(space)
      next unless t0[:t]

      toitures = facets(space, "Outdoors", "RoofCeiling")
      plafonds = facets(space, "Surface", "RoofCeiling")

      toitures.each { |surf| h = [h, surf.vertices.max_by(&:z).z].max }
      plafonds.each { |surf| h = [h, surf.vertices.max_by(&:z).z].max }

      rooms[space]           = {}
      rooms[space][:t      ] = t0[:t]
      rooms[space][:m      ] = space.multiplier
      rooms[space][:h      ] = h
      rooms[space][:roofs  ] = toitures
      rooms[space][:sidelit] = daylit?(space, true, false, false)

      # Fetch and process room-specific outdoor-facing roof surfaces, the most
      # basic 'set' to track:
      #   - no skylight wells
      #   - 1x skylight array per roof surface
      #   - no need to preprocess space transformation
      rooms[space][:roofs].each do |roof|
        box = boundedBox(roof)
        next if box.empty?

        bm2 = OpenStudio.getArea(box)
        next if bm2.empty?

        bm2 = bm2.get
        next if bm2.round(2) < w02.round(2)

        # Track if bounded box is significantly smaller than roof.
        tight = bm2 < roof.grossArea / 2 ? true : false

        set           = {}
        set[:box    ] = box
        set[:bm2    ] = bm2
        set[:tight  ] = tight
        set[:roof   ] = roof
        set[:space  ] = space
        set[:sidelit] = rooms[space][:sidelit]
        set[:t      ] = rooms[space][:t      ]
        set[:sloped ] = slopedRoof?(roof)
        sets << set
      end
    end

    # Process outdoor-facing roof surfaces of plenums and attics above.
    rooms.each do |space, room|
      t0    = room[:t]
      toits = getRoofs(space)
      rufs  = room.key?(:roofs) ? toits - room[:roofs] : toits
      next if rufs.empty?

      # Process room ceilings, as 1x or more are overlapping roofs above. Fetch
      # vertically-cast overlaps.
      rufs.each do |ruf|
        espace = ruf.space
        next if espace.empty?

        espace = espace.get
        next if espace.partofTotalFloorArea

        m  = espace.multiplier
        ti = transforms(espace)
        next unless ti[:t]

        ti  = ti[:t]
        vtx = ruf.vertices

        # Ensure BLC vertex sequence.
        if facingUp?(vtx)
          vtx = ti * vtx

          if xyz?(vtx, :z)
            vtx = blc(vtx)
          else
            dZ  = vtx.first.z
            vtz = blc(flatten(vtx)).to_a
            vtx = []

            vtz.each { |v| vtx << OpenStudio::Point3d.new(v.x, v.y, v.z + dZ) }
          end

          ruf.setVertices(ti.inverse * vtx)
        else
          tr  = OpenStudio::Transformation.alignFace(vtx)
          vtx = blc(tr.inverse * vtx)
          ruf.setVertices(tr * vtx)
        end

        ri = ti * ruf.vertices

        facets(space, "Surface", "RoofCeiling").each do |tile|
          vtx = tile.vertices

          # Ensure BLC vertex sequence.
          if facingUp?(vtx)
            vtx = t0 * vtx

            if xyz?(vtx, :z)
              vtx = blc(vtx)
            else
              dZ  = vtx.first.z
              vtz = blc(flatten(vtx)).to_a
              vtx = []

              vtz.each { |v| vtx << OpenStudio::Point3d.new(v.x, v.y, v.z + dZ) }
            end

            vtx = t0.inverse * vtx
          else
            tr  = OpenStudio::Transformation.alignFace(vtx)
            vtx = blc(tr.inverse * vtx)
            vtx = tr * vtx
          end

          tile.setVertices(vtx)

          ci0 = cast(t0 * tile.vertices, ri, ray)
          next if ci0.empty?

          olap = overlap(ri, ci0, false)
          next if olap.empty?

          box = boundedBox(olap)
          next if box.empty?

          # Adding skylight wells (plenums/attics) is contingent to safely
          # linking new base roof 'inserts' through leader lines. Currently,
          # this requires an offset from main roof surface edges.
          #
          # TO DO: expand the method to factor in cases where simple 'side'
          #        cutouts can be supported (no need for leader lines), e.g.
          #        skylight strips along roof ridges.
          box = offset(box, -gap, 300)
          box = poly(box, false, false, false, false, :blc)
          next if box.empty?

          bm2 = OpenStudio.getArea(box)
          next if bm2.empty?

          bm2 = bm2.get
          next if bm2.round(2) < w02.round(2)

          # Vertically-cast box onto ceiling below.
          cbox = cast(box, t0 * tile.vertices, ray)
          next if cbox.empty?

          cm2 = OpenStudio.getArea(cbox)
          next if cm2.empty?

          cm2 = cm2.get

          # Track if bounded boxes are significantly smaller than either roof
          # or ceiling.
          tight = bm2 < ruf.grossArea  / 2 ? true : false
          tight = cm2 < tile.grossArea / 2 ? true : tight

          unless ceilings.key?(tile)
            floor = tile.adjacentSurface

            if floor.empty?
              log(ERR, "#{tile.nameString} adjacent floor? (#{mth})")
              next
            end

            floor = floor.get

            # Ensure BLC vertex sequence.
            vtx = t0 * vtx
            floor.setVertices(ti.inverse * vtx.reverse)

            if floor.space.empty?
              log(ERR, "#{floor.nameString} space? (#{mth})")
              next
            end

            espce = floor.space.get

            unless espce == espace
              log(ERR, "#{espce.nameString} != #{espace.nameString}? (#{mth})")
              next
            end

            ceilings[tile]         = {}
            ceilings[tile][:roofs] = []
            ceilings[tile][:space] = space
            ceilings[tile][:floor] = floor
          end

          ceilings[tile][:roofs] << ruf

          # More detailed skylight set entries with suspended ceilings.
          set           = {}
          set[:olap   ] = olap
          set[:box    ] = box
          set[:cbox   ] = cbox
          set[:bm2    ] = bm2
          set[:cm2    ] = cm2
          set[:tight  ] = tight
          set[:roof   ] = ruf
          set[:space  ] = space
          set[:clng   ] = tile
          set[:t      ] = t0
          set[:sidelit] = room[:sidelit]
          set[:sloped ] = slopedRoof?(ruf)

          if unconditioned?(espace) # e.g. attic
            unless attics.key?(espace)
              attics[espace] = {t: ti, m: m, bm2: 0, roofs: []}
            end

            attics[espace][:bm2  ] += bm2
            attics[espace][:roofs] << ruf

            set[:attic] = espace

            ceilings[tile][:attic] = espace
          else # e.g. plenum
            unless plenums.key?(espace)
              plenums[espace] = {t: ti, m: m, bm2: 0, roofs: []}
            end

            plenums[espace][:bm2  ] += bm2
            plenums[espace][:roofs] << ruf

            set[:plenum] = espace

            ceilings[tile][:plenum] = espace
          end

          sets << set
          break # only 1x unique ruf/ceiling pair.
        end
      end
    end

    # Ensure uniqueness of plenum roofs, and set GROSS ROOF AREA.
    attics.values.each do |attic|
      attic[:roofs ].uniq!
      attic[:ridges] = getHorizontalRidges(attic[:roofs]) # TO-DO
    end

    plenums.values.each do |plenum|
      plenum[:roofs ].uniq!
      # plenum[:m2    ] = plenum[:roofs].sum(&:grossArea)
      plenum[:ridges] = getHorizontalRidges(plenum[:roofs]) # TO-DO
    end

    # Regardless of the selected skylight arrangement pattern, the current
    # solution may only consider attic/plenum sets that can be successfully
    # linked to leader line anchors, for both roof and ceiling surfaces.
    [attics, plenums].each do |greniers|
      k = greniers == attics ? :attic : :plenum

      greniers.each do |spce, grenier|
        grenier[:roofs].each do |roof|
          sts = sets

          sts = sts.select { |st| st.key?(k) }
          sts = sts.select { |st| st.key?(:box) }
          sts = sts.select { |st| st.key?(:bm2) }
          sts = sts.select { |st| st.key?(:roof) }
          sts = sts.select { |st| st.key?(:space) }
          sts = sts.select { |st| st[k    ] == spce }
          sts = sts.select { |st| st[:roof] == roof }
          next if sts.empty?

          sts = sts.sort_by { |st| st[:bm2] }
          genAnchors(roof, sts, :box)
        end
      end
    end

    # Delete voided sets.
    sets.reject! { |set| set.key?(:void) }

    # Repeat leader line loop for ceilings.
    ceilings.each do |tile, ceiling|
      k = ceiling.key?(:attic) ? :attic : :plenum
      next unless ceiling.key?(k)

      space = ceiling[:space]
      spce  = ceiling[k     ]
      next unless ceiling.key?(:roofs)
      next unless rooms.key?(space)

      stz = []

      ceiling[:roofs].each do |roof|
        sts = sets

        sts = sts.select { |st| st.key?(k) }
        sts = sts.select { |st| st.key?(:cbox) }
        stz = stz.select { |st| st.key?(:cm2) }
        sts = sts.select { |st| st.key?(:roof) }
        sts = sts.select { |st| st.key?(:clng) }
        sts = sts.select { |st| st.key?(:space) }
        sts = sts.select { |st| st[k     ] == spce }
        sts = sts.select { |st| st[:roof ] == roof }
        sts = sts.select { |st| st[:clng ] == tile }
        sts = sts.select { |st| st[:space] == space }
        next unless sts.size == 1

        stz << sts.first
      end

      next if stz.empty?

      genAnchors(tile, stz, :cbox)
    end

    # Delete voided sets.
    sets.reject! { |set| set.key?(:void) }

    m2  = 0 # existing skylight rough opening area
    rm2 = grossRoofArea(spaces)

    # Tally existing skylight rough opening areas (%SRR calculations).
    rooms.values.each do |room|
      m = room[:m]

      room[:roofs].each do |roof|
        roof.subSurfaces.each do |sub|
          next unless fenestration?(sub)

          id  = sub.nameString
          xm2 = sub.grossArea

          if sub.allowWindowPropertyFrameAndDivider
            unless sub.windowPropertyFrameAndDivider.empty?
              fw   = sub.windowPropertyFrameAndDivider.get.frameWidth
              vec  = offset(sub.vertices, fw, 300)
              aire = OpenStudio.getArea(vec)

              if aire.empty?
                log(ERR, "Skipping '#{id}': invalid Frame&Divider (#{mth})")
              else
                xm2 = aire.get
              end
            end
          end

          m2 += xm2 * sub.multiplier * m
        end
      end
    end

    # Required skylight area to add.
    sm2 = rm2 * srr - m2

    # Skip if existing skylights exceed or ~roughly match requested %SRR.
    if sm2.round(2) < w02.round(2)
      log(INF, "Skipping: existing srr > requested srr (#{mth})")
      return 0
    end

    # Any sidelit/sloped roofs being targeted?
    #
    # TODO: enable double-ridged, sloped roofs have double-sloped
    #       skylights/wells (patterns "strip"/"strips").
    sidelit = sets.any? { |set| set[:sidelit] }
    sloped  = sets.any? { |set| set[:sloped ] }

    # Precalculate skylight rows + cols, for each selected pattern. In the case
    # of 'cols x rows' arrays of skylights, the method initially overshoots
    # with regards to ideal skylight placement, e.g.:
    #
    #   aceee.org/files/proceedings/2004/data/papers/SS04_Panel3_Paper18.pdf
    #
    # ... yet skylight areas are subsequently contracted to strictly meet SRR%.
    sets.each_with_index do |set, i|
      id     = "set #{i+1}"
      well   = set.key?(:clng)
      space  = set[:space]
      tight  = set[:tight]
      factor = tight ? 1.75 : 1.25
      room   = rooms[space]
      h      = room[:h]
      t      = OpenStudio::Transformation.alignFace(set[:box])
      abox   = poly(set[:box], false, false, false, t, :ulc)
      obox   = getRealignedFace(abox)
      next unless obox[:set]

      width = width(obox[:set])
      depth = height(obox[:set])
      area  = width * depth
      skym2 = srr * area

      # Flag sets if too narrow/shallow to hold a single skylight.
      if well
        if width.round(2) < wl.round(2)
          log(ERR, "#{id}: Too narrow")
          set[:void] = true
          next
        end

        if depth.round(2) < wl.round(2)
          log(ERR, "#{id}: Too shallow")
          set[:void] = true
          next
        end
      else
        if width.round(2) < w0.round(2)
          log(ERR, "#{id}: Too narrow")
          set[:void] = true
          next
        end

        if depth.round(2) < w0.round(2)
          log(ERR, "#{id}: Too shallow")
          set[:void] = true
          next
        end
      end

      # Estimate number of skylight modules per 'pattern'. Default spacing
      # varies based on bounded box size (i.e. larger vs smaller rooms).
      patterns.each do |pattern|
        cols = 1
        rows = 1
        wx   = w0
        wy   = w0
        wxl  = wl
        wyl  = wl
        dX   = nil
        dY   = nil

        case pattern
        when "array" # min 2x cols x min 2x rows
          cols = 2
          rows = 2

          if tight
            sp = 1.4 * h / 2
            lx = well ? width - cols * wxl : width - cols * wx
            ly = well ? depth - rows * wyl : depth - rows * wy
            next if lx.round(2) < sp.round(2)
            next if ly.round(2) < sp.round(2)

            if well
              cols = ((width - wxl) / (wxl + sp)).round(2).to_i + 1
              rows = ((depth - wyl) / (wyl + sp)).round(2).to_i + 1
            else
              cols = ((width - wx) / (wx + sp)).round(2).to_i + 1
              rows = ((depth - wy) / (wy + sp)).round(2).to_i + 1
            end

            next if cols < 2
            next if rows < 2

            dX = well ? 0.0 : bfr + f
            dY = well ? 0.0 : bfr + f
          else
            sp = 1.4 * h
            lx = well ? (width - cols * wxl) / cols : (width - cols * wx) / cols
            ly = well ? (depth - rows * wyl) / rows : (depth - rows * wy) / cols
            next if lx.round(2) < sp.round(2)
            next if ly.round(2) < sp.round(2)

            if well
              cols = (width / (wxl + sp)).round(2).to_i
              rows = (depth / (wyl + sp)).round(2).to_i
            else
              cols = (width / (wx + sp)).round(2).to_i
              rows = (depth / (wy + sp)).round(2).to_i
            end

            next if cols < 2
            next if rows < 2

            ly = well ? (depth - rows * wyl) / rows : (depth - rows * wy) / cols
            dY = ly / 2
          end

          # Current skylight area. If undershooting, adjust skylight width/depth
          # as well as reduce spacing. For geometrical constrained cases,
          # undershooting means not reaching 1.75x the required SRR%. Otherwise,
          # undershooting means not reaching 1.25x the required SRR%. Any
          # consequent overshooting is later corrected.
          tm2       = wx * cols * wy * rows
          undershot = tm2.round(2) < factor * skym2.round(2) ? true : false

          # Inflate skylight width/depth (and reduce spacing) to reach SRR%.
          if undershot
            ratio2 = 1 + (factor * skym2 - tm2) / tm2
            ratio  = Math.sqrt(ratio2)

            sp  = w
            wx *= ratio
            wy *= ratio
            wxl = wx + gap
            wyl = wy + gap

            if tight
              if well
                lx = (width - cols * wxl) / (cols - 1)
                ly = (depth - rows * wyl) / (rows - 1)
              else
                lx = (width - cols * wx) / (cols - 1)
                ly = (depth - rows * wy) / (rows - 1)
              end

              lx = lx.round(2) < sp.round(2) ? sp : lx
              ly = ly.round(2) < sp.round(2) ? sp : ly

              if well
                wxl = (width - (cols - 1) * lx) / cols
                wyl = (depth - (rows - 1) * ly) / rows
                wx  = wxl - gap
                wy  = wyl - gap
              else
                wx  = (width - (cols - 1) * lx) / cols
                wy  = (depth - (rows - 1) * ly) / rows
                wxl = wx + gap
                wyl = wy + gap
              end
            else
              if well
                lx = (width - cols * wxl) / cols
                ly = (depth - rows * wyl) / rows
              else
                lx = (width - cols * wx) / cols
                ly = (depth - rows * wy) / rows
              end

              lx = lx.round(2) < sp.round(2) ? sp : lx
              ly = ly.round(2) < sp.round(2) ? sp : ly

              if well
                wxl = (width - cols * lx) / cols
                wyl = (depth - rows * ly) / rows
                wx  = wxl - gap
                wy  = wyl - gap
                lx  = (width - cols * wxl) / cols
                ly  = (depth - rows * wyl) / rows
              else
                wx  = (width - cols * lx) / cols
                wy  = (depth - rows * ly) / rows
                wxl = wx + gap
                wyl = wy + gap
                lx  = (width - cols * wx) / cols
                ly  = (depth - rows * wy) / rows
              end
            end

            dY = ly / 2
          end
        when "strips" # min 2x cols x 1x row
          cols = 2

          if tight
            sp = h / 2
            lx = well ? width - cols * wxl : width - cols * wx
            ly = well ? depth - wyl : depth - wy
            next if lx.round(2) < sp.round(2)
            next if ly.round(2) < sp.round(2)

            if well
              cols = ((width - wxl) / (wxl + sp)).round(2).to_i + 1
            else
              cols = ((width - wx) / (wx + sp)).round(2).to_i + 1
            end

            next if cols < 2

            if well
              wyl = depth - ly
              wy  = wyl - gap
            else
              wy  = depth - ly
              wyl = wy + gap
            end

            dX = well ? 0 : bfr + f
            dY = ly / 2
          else
            sp = h
            lx = well ? (width - cols * wxl) / cols : (width - cols * wx) / cols
            ly = well ? depth - wyl : depth - wy
            next if lx.round(2) < sp.round(2)
            next if ly.round(2) < w.round(2)

            if well
              cols = (width / (wxl + sp)).round(2).to_i
            else
              cols = (width / (wx + sp)).round(2).to_i
            end

            next if cols < 2

            if well
              wyl = depth - ly
              wy  = wyl - gap
            else
              wy  = depth - ly
              wyl = wy + gap
            end

            dY = ly / 2
          end

          tm2       = wx * cols * wy
          undershot = tm2.round(2) < factor * skym2.round(2) ? true : false

          # Inflate skylight width (and reduce spacing) to reach SRR%.
          if undershot
            ratio2 = 1 + (factor * skym2 - tm2) / tm2

            sp  = w
            wx *= ratio2
            wxl = wx + gap

            if tight
              if well
                lx = (width - cols * wxl) / (cols - 1)
              else
                lx = (width - cols * wx) / (cols - 1)
              end

              lx = lx.round(2) < sp.round(2) ? sp : lx

              if well
                wxl = (width - (cols - 1) * lx) / cols
                wx  = wxl - gap
              else
                wx  = (width - (cols - 1) * lx) / cols
                wxl = wx + gap
              end
            else
              if well
                lx = (width - cols * wxl) / cols
              else
                lx = (width - cols * wx) / cols
              end

              lx  = lx.round(2) < sp.round(2) ? sp : lx

              if well
                wxl = (width - cols * lx) / cols
                wx  = wxl - gap
                lx  = (width - cols * wxl) / cols
              else
                wx  = (width - cols * lx) / cols
                wxl = wx + gap
                lx  = (width - cols * wx) / cols
              end
            end
          end
        else # "strip" 1 (long?) row x 1 column
          sp = w
          lx = well ? width - wxl : width - wx
          ly = well ? depth - wyl : depth - wy

          if tight
            next if lx.round(2) < sp.round(2)
            next if ly.round(2) < sp.round(2)

            if well
              wxl = width - lx
              wyl = depth - ly
              wx  = wxl - gap
              wy  = wyl - gap
            else
              wx  = width - lx
              wy  = depth - ly
              wxl = wx + gap
              wyl = wy + gap
            end

            dX = well ? 0.0 : bfr + f
            dY = ly / 2
          else
            next if lx.round(2) < sp.round(2)
            next if ly.round(2) < sp.round(2)

            if well
              wxl = width - lx
              wyl = depth - ly
              wx  = wxl - gap
              wy  = wyl - gap
            else
              wx  = width - lx
              wy  = depth - ly
              wxl = wx + gap
              wyl = wy + gap
            end

            dY = ly / 2
          end

          tm2       = wx * wy
          undershot = tm2.round(2) < factor * skym2.round(2) ? true : false

          # Inflate skylight depth to reach SRR%.
          if undershot
            ratio2 = 1 + (factor * skym2 - tm2) / tm2

            sp  = w
            wy *= ratio2
            wyl = wy + gap

            ly  = well ? depth - wy : depth - wyl
            ly  = ly.round(2) < sp.round(2) ? sp : lx

            if well
              wyl = depth - ly
              wy  = wyl - gap
            else
              wy  = depth - ly
              wyl = wy + gap
            end
          end
        end

        st         = {}
        st[:tight] = tight
        st[:cols ] = cols
        st[:rows ] = rows
        st[:wx   ] = wx
        st[:wy   ] = wy
        st[:wxl  ] = wxl
        st[:wyl  ] = wyl
        st[:dX   ] = dX if dX
        st[:dY   ] = dY if dY

        set[pattern] = st
      end
    end

    # Delete voided sets.
    sets.reject! { |set| set.key?(:void) }

    # Final reset of filters.
    filters.map! { |f| f.include?("b") ? f.delete("b") : f } unless sidelit
    filters.map! { |f| f.include?("c") ? f.delete("c") : f } unless sloped
    filters.map! { |f| f.include?("d") ? f.delete("d") : f } if plenums.empty?
    filters.map! { |f| f.include?("e") ? f.delete("e") : f } if attics.empty?

    filters.reject! { |f| f.empty? }
    filters.uniq!

    # Initialize skylight area tally.
    skm2 = 0

    # Assign skylight pattern.
    filters.each_with_index do |filter, i|
      next if skm2.round(2) >= sm2.round(2)

      sts = sets
      sts = sts.sort_by { |st| st[:bm2] }.reverse!
      sts = sts.reject  { |st| st.key?(:pattern) }

      if filter.include?("a")
        # Start with the default (ideal) allocation selection:
          # - large roof surface areas (e.g. retail, classrooms not corridors)
          # - not sidelit (favours core spaces)
          # - having flat roofs (avoids sloped roofs)
          # - not under plenums, nor attics (avoids wells)
        sts = sts.reject { |st| st[:sidelit]   }
        sts = sts.reject { |st| st[:sloped ]   }
        sts = sts.reject { |st| st.key?(:clng) }
      else
        sts = sts.reject { |st| st[:sidelit]     } unless filter.include?("b")
        sts = sts.reject { |st| st[:sloped]      } unless filter.include?("c")
        sts = sts.reject { |st| st.key?(:plenum) } unless filter.include?("d")
        sts = sts.reject { |st| st.key?(:attic)  } unless filter.include?("e")
      end

      next if sts.empty?

      # Tally precalculated skylights per pattern (once filtered).
      fpm2 = {}

      patterns.each do |pattern|
        sts.each do |st|
          next unless st.key?(pattern)

          cols = st[pattern][:cols]
          rows = st[pattern][:rows]
          wx   = st[pattern][:wx  ]
          wy   = st[pattern][:wy  ]

          fpm2[pattern] = {m2: 0, tight: false} unless fpm2.key?(pattern)

          fpm2[pattern][:m2   ] += wx * wy * cols * rows
          fpm2[pattern][:tight] = st[:tight] ? true : false
        end
      end

      pattern = nil
      next if fpm2.empty?

      fpm2 = fpm2.sort_by { |_, fm2| fm2[:m2] }.to_h

      # Select suitable pattern, often overshooting. Favour array unless
      # geometrically constrainted.
      if fpm2.keys.include?("array")
        if (fpm2["array"][:m2]).round(2) >= sm2.round(2)
          pattern = "array" unless fpm2[:tight]
        end
      end

      unless pattern
        if fpm2.values.first[:m2].round(2) >= sm2.round(2)
          pattern = fpm2.keys.first
        elsif fpm2.values.last[:m2].round(2) <= sm2.round(2)
          pattern = fpm2.keys.last
        else
          fpm2.keep_if { |_, fm2| fm2[:m2].round(2) >= sm2.round(2) }

          pattern = fpm2.keys.first
        end
      end

      skm2 += fpm2[pattern][:m2]

      # Update matching sets.
      sts.each do |st|
        sets.each do |set|
          next unless set.key?(pattern)
          next unless st[:roof] == set[:roof]
          next unless same?(st[:box], set[:box])

          if st.key?(:clng)
            next unless set.key?(:clng)
            next unless st[:clng] == set[:clng]
          end

          set[:pattern] = pattern
          set[:cols   ] = set[pattern][:cols]
          set[:rows   ] = set[pattern][:rows]
          set[:w      ] = set[pattern][:wx  ]
          set[:d      ] = set[pattern][:wy  ]
          set[:w0     ] = set[pattern][:wxl ]
          set[:d0     ] = set[pattern][:wyl ]
          set[:dX     ] = set[pattern][:dX  ]
          set[:dY     ] = set[pattern][:dY  ]
        end
      end
    end

    # Skylight size contraction if overshot (e.g. -13.2% if overshot by +13.2%).
    # This is applied on a surface/pattern basis; individual skylight sizes may
    # vary from one surface to the next, depending on respective patterns.
    if skm2.round(2) > sm2.round(2)
      ratio2 = 1 - (skm2 - sm2) / skm2
      ratio  = Math.sqrt(ratio2)
      skm2  *= ratio2

      sets.each do |set|
        next if set.key?(:void)
        next unless set.key?(:pattern)

        pattern = set[:pattern]
        next unless set.key?(pattern)

        case pattern
        when "array" # equally adjust both width and depth
          xr  = set[:w] * ratio
          yr  = set[:d] * ratio
          dyr = set[:d] - yr

          set[:w ]  = xr
          set[:d ]  = yr
          set[:w0]  = set[:w] + gap
          set[:d0]  = set[:d] + gap
          set[:dY] += dyr / 2
        when "strips" # adjust depth
          xr2 = set[:w] * ratio2

          set[:w ]  = xr2
          set[:w0]  = set[:w] + gap
        else # "strip", adjust width
          yr2 = set[:d] * ratio2
          dyr = set[:d] - yr2

          set[:d ]  = yr2
          set[:d0]  = set[:w] + gap
          set[:dY] += dyr / 2
        end
      end
    end

    # Generate skylight well roofs for attics & plenums.
    [attics, plenums].each do |greniers|
      k = greniers == attics ? :attic : :plenum

      greniers.each do |spce, grenier|
        ti = grenier[:t]

        grenier[:roofs].each do |roof|
          sts = sets
          sts = sts.select { |st| st.key?(k) }
          sts = sts.select { |st| st.key?(:pattern) }
          sts = sts.select { |st| st.key?(:clng) }
          sts = sts.select { |st| st.key?(:roof) }
          sts = sts.select { |st| st.key?(:space) }
          sts = sts.select { |st| st[:roof] == roof }
          sts = sts.select { |st| st[k    ] == spce }
          sts = sts.select { |st| st.key?(st[:pattern]) }
          sts = sts.select { |st| rooms.key?(st[:space]) }
          sts = sts.select { |st| st.key?(:ld) }
          sts = sts.select { |st| st[:ld].key?(roof) }
          next if sts.empty?

          # If successful, 'genInserts' returns extended roof surface vertices,
          # including leader lines to support cutouts. The final selection is
          # contingent to successfully inserting corresponding room ceiling
          # inserts (vis-à-vis attic/plenum floor below). The method also
          # generates new roof inserts. See key:value pair :vts.
          vz = genInserts(roof, sts)
          next if vz.empty? # TODO log error if empty

          roof.setVertices(ti.inverse * vz)
        end
      end
    end

    # Repeat for ceilings below attic/plenum floors.
    ceilings.each do |tile, ceiling|
      k = ceiling.key?(:attic) ? :attic : :plenum
      next unless ceiling.key?(k)
      next unless ceiling.key?(:roofs)

      greniers = ceiling.key?(:attic) ? attics : plenums
      space    = ceiling[:space]
      spce     = ceiling[k     ]
      floor    = ceiling[:floor]
      next unless rooms.key?(space)
      next unless greniers.key?(spce)

      room    = rooms[space]
      grenier = greniers[spce]
      ti      = grenier[:t]
      t0      = room[:t]
      stz     = []

      ceiling[:roofs].each do |roof|
        sts = sets

        sts = sts.select { |st| st.key?(k) }
        sts = sts.select { |st| st.key?(:clng) }
        sts = sts.select { |st| st.key?(:cm2) }
        sts = sts.select { |st| st.key?(:roof) }
        sts = sts.select { |st| st.key?(:space) }
        sts = sts.select { |st| st[:clng] == tile }
        sts = sts.select { |st| st[:roof] == roof }
        sts = sts.select { |st| st[k    ] == spce }
        sts = sts.select { |st| rooms.key?(st[:space]) }
        sts = sts.select { |st| st.key?(:ld) }
        sts = sts.select { |st| st.key?(:vtx) }
        sts = sts.select { |st| st.key?(:vts) }
        sts = sts.select { |st| st[:ld].key?(roof) }
        sts = sts.select { |st| st[:ld].key?(tile) }
        next unless sts.size == 1

        stz << sts.first
      end

      next if stz.empty?

      # Vertically-cast set roof :vtx onto ceiling.
      stz.each do |st|
        cvtx = cast(ti * st[:vtx], t0 * tile.vertices, ray)
        st[:cvtx] = t0.inverse * cvtx
      end

      # Extended ceiling vertices.
      vertices = genExtendedVertices(tile, stz, :cvtx)
      next if vertices.empty?

      # Reset ceiling and adjacent floor vertices.
      tile.setVertices(t0.inverse * vertices)
      floor.setVertices(ti.inverse * vertices.to_a.reverse)

      # Add new roof inserts & skylights for the (now) toplit space.
      stz.each_with_index do |st, i|
        sub          = {}
        sub[:type  ] = "Skylight"
        sub[:width ] = st[:w] - f2
        sub[:height] = st[:d] - f2
        sub[:sill  ] = gap / 2
        sub[:frame ] = frame if frame

        st[:vts].each do |id, vt|
          roof = OpenStudio::Model::Surface.new(t0.inverse * vt, mdl)
          roof.setSpace(space)
          roof.setName("#{i}:#{id}:#{space.nameString}")

          # Generate well walls.
          v0 = roof.vertices
          vX = cast(roof, tile, ray)
          s0 = getSegments(v0)
          sX = getSegments(vX)

          s0.each_with_index do |sg, j|
            sg0 = sg.to_a
            sgX = sX[j].to_a
            vec  = OpenStudio::Point3dVector.new
            vec << sg0.first
            vec << sg0.last
            vec << sgX.last
            vec << sgX.first

            grenier_wall = OpenStudio::Model::Surface.new(vec, mdl)
            grenier_wall.setSpace(spce)
            grenier_wall.setName("#{id}:#{j}:#{spce.nameString}")

            room_wall = OpenStudio::Model::Surface.new(vec.to_a.reverse, mdl)
            room_wall.setSpace(space)
            room_wall.setName("#{id}:#{j}:#{space.nameString}")

            grenier_wall.setAdjacentSurface(room_wall)
            room_wall.setAdjacentSurface(grenier_wall)
          end

          # Add individual skylights.
          addSubs(roof, [sub])
        end
      end
    end

    # New direct roof loop. No overlaps, so no need for relative space
    # coordinate adjustments.
    rooms.each do |space, room|
      room[:roofs].each do |roof|
        sets.each_with_index do |set, i|
          next     if set.key?(:clng)
          next unless set.key?(:box)
          next unless set.key?(:roof)
          next unless set.key?(:cols)
          next unless set.key?(:rows)
          next unless set.key?(:d)
          next unless set.key?(:w)
          next unless set.key?(:dX)
          next unless set.key?(:dY)
          next unless set.key?(:tight)
          next unless set[:roof] == roof

          tight = set[:tight]

          d1 = set[:d] - f2
          w1 = set[:w] - f2

          # Y-axis 'height' of the roof, once re/aligned.
          # TODO: retrieve st[:out], +efficient
          y  = alignedHeight(set[:box])
          dY = set[:dY] if set[:dY]

          set[:rows].times.each do |j|
            sub            = {}
            sub[:type    ] = "Skylight"
            sub[:count   ] = set[:cols]
            sub[:width   ] = w1
            sub[:height  ] = d1
            sub[:frame   ] = frame if frame
            sub[:id      ] = "set #{i+1}:#{j+1}"
            sub[:sill    ] = dY + j * (2 * dY + d1)
            sub[:r_buffer] = set[:dX] if set[:dX]
            sub[:l_buffer] = set[:dX] if set[:dX]
            addSubs(roof, [sub])
          end
        end
      end
    end

    rm2
  end

  ##
  # Callback when other modules extend OSlg
  #
  # @param base [Object] instance or class object
  def self.extended(base)
    base.send(:include, self)
  end
end
