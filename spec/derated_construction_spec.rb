require "tbd"

RSpec.describe TBD do

  it "can compute uFactor for ceilings, walls, and floors" do

    os_model = OpenStudio::Model::Model.new
    space = OpenStudio::Model::Space.new(os_model)

    material = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    material.setRoughness("Smooth")
    material.setThermalResistance(4.0)
    material.setThermalAbsorptance(0.9)
    material.setSolarAbsorptance(0.7)
    material.setVisibleAbsorptance(0.7)

    layers = OpenStudio::Model::MaterialVector.new
    layers << material
    construction = OpenStudio::Model::Construction.new(os_model)
    construction.setLayers(layers)
    expect(construction.thermalConductance.empty?).to be(false)
    expect(construction.thermalConductance.get).to be_within(0.001).of(0.25)
    expect(construction.uFactor(0).empty?).to be(false)
    expect(construction.uFactor(0).get).to be_within(0.001).of(0.25)

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new( 10, 10, 5)
    vertices << OpenStudio::Point3d.new( 0, 10, 5)
    vertices << OpenStudio::Point3d.new( 0, 0, 5)
    vertices << OpenStudio::Point3d.new( 10, 0, 5)
    ceiling = OpenStudio::Model::Surface.new(vertices, os_model)
    ceiling.setSpace(space)
    ceiling.setConstruction(construction)
    expect(ceiling.surfaceType.downcase).to eq("roofceiling")
    expect(ceiling.outsideBoundaryCondition.downcase).to eq("outdoors")
    expect(ceiling.filmResistance).to be_within(0.001).of(0.136)
    expect(ceiling.uFactor.empty?).to be(false)
    expect(ceiling.uFactor.get).to be_within(0.001).of(0.242)

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new( 0, 10, 5)
    vertices << OpenStudio::Point3d.new( 0, 10, 0)
    vertices << OpenStudio::Point3d.new( 0, 0, 0)
    vertices << OpenStudio::Point3d.new( 0, 0, 5)
    wall = OpenStudio::Model::Surface.new(vertices, os_model)
    wall.setSpace(space)
    wall.setConstruction(construction)
    expect(wall.surfaceType.downcase).to eq("wall")
    expect(wall.outsideBoundaryCondition.downcase).to eq("outdoors")
    expect(wall.tilt).to be_within(0.001).of(Math::PI/2.0)
    expect(wall.filmResistance).to be_within(0.001).of(0.150)
    expect(wall.uFactor.empty?).to be(false)
    expect(wall.uFactor.get).to be_within(0.001).of(0.241)

    vertices = OpenStudio::Point3dVector.new
    vertices << OpenStudio::Point3d.new( 0, 10, 0)
    vertices << OpenStudio::Point3d.new( 10, 10, 0)
    vertices << OpenStudio::Point3d.new( 10, 0, 0)
    vertices << OpenStudio::Point3d.new( 0, 0, 0)
    floor = OpenStudio::Model::Surface.new(vertices, os_model)
    floor.setSpace(space)
    floor.setConstruction(construction)
    expect(floor.surfaceType.downcase).to eq("floor")
    expect(floor.outsideBoundaryCondition.downcase).to eq("ground")
    expect(floor.tilt).to be_within(0.001).of(Math::PI)
    expect(floor.filmResistance).to be_within(0.001).of(0.160)
    expect(floor.uFactor.empty?).to be(false)
    expect(floor.uFactor.get).to be_within(0.001).of(0.241)

    # make outdoors (like a soffit)
    expect(floor.setOutsideBoundaryCondition("Outdoors")).to be(true)
    expect(floor.filmResistance).to be_within(0.001).of(0.190)
    expect(floor.uFactor.empty?).to be(false)
    expect(floor.uFactor.get).to be_within(0.001).of(0.239)

    # now make these surfaces not outdoors
    expect(ceiling.setOutsideBoundaryCondition("Adiabatic")).to be(true)
    expect(ceiling.filmResistance).to be_within(0.001).of(0.212)
    expect(ceiling.uFactor.empty?).to be(false)
    expect(ceiling.uFactor.get).to be_within(0.001).of(0.237)

    expect(wall.setOutsideBoundaryCondition("Adiabatic")).to be(true)
    expect(wall.filmResistance).to be_within(0.001).of(0.239)
    expect(wall.uFactor.empty?).to be(false)
    expect(wall.uFactor.get).to be_within(0.001).of(0.236)

    expect(floor.setOutsideBoundaryCondition("Adiabatic")).to be(true)
    expect(floor.filmResistance).to be_within(0.001).of(0.321)
    expect(floor.uFactor.empty?).to be(false)
    expect(floor.uFactor.get).to be_within(0.001).of(0.231)

    # doubling number of layers. Good.
    layers = OpenStudio::Model::MaterialVector.new
    layers << material
    layers << material
    construction = OpenStudio::Model::Construction.new(os_model)
    construction.setLayers(layers)
    expect(construction.thermalConductance.empty?).to be(false)
    expect(construction.thermalConductance.get).to be_within(0.001).of(0.125)
    expect(construction.uFactor(0).empty?).to be(false)
    expect(construction.uFactor(0).get).to be_within(0.001).of(0.125)

    # All good.
    floor.setConstruction(construction)
    expect(floor.setOutsideBoundaryCondition("Outdoors")).to be(true)
    expect(floor.filmResistance).to be_within(0.001).of(0.190)
    expect(floor.thermalConductance.empty?).to be(false)
    expect(floor.thermalConductance.get).to be_within(0.001).of(0.125)
    expect(floor.uFactor.empty?).to be(false)
    expect(floor.uFactor.get).to be_within(0.001).of(0.122)


    # Constructions/materials generated from DOE Prototype (Small Office), i.e. in.osm or in.idf

    #Material,
    #5/8 in. Gypsum Board,                   !- Name
    #MediumSmooth,                           !- Roughness
    #0.0159,                                 !- Thickness {m}
    #0.159999999999999,                      !- Conductivity {W/m-K}
    #799.999999999999,                       !- Density {kg/m3}
    #1090,                                   !- Specific Heat {J/kg-K}
    #0.9,                                    !- Thermal Absorptance
    #0.7,                                    !- Solar Absorptance
    #0.7;                                    !- Visible Absorptance

    #OS:Material,
    #{7462f6dd-da46-4439-8dbe-ca9fd849f87b}, !- Handle
    #5/8 in. Gypsum Board,                   !- Name
    #MediumSmooth,                           !- Roughness
    #0.0159,                                 !- Thickness {m}
    #0.159999999999999,                      !- Conductivity {W/m-K}
    #799.999999999999,                       !- Density {kg/m3}
    #1090,                                   !- Specific Heat {J/kg-K}
    #0.9,                                    !- Thermal Absorptance
    #0.7,                                    !- Solar Absorptance
    #0.7;                                    !- Visible Absorptance
    gypsum = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    gypsum.setRoughness("MediumSmooth")
    gypsum.setThermalConductivity(0.16)
    gypsum.setThickness(0.0159)
    gypsum.setThermalAbsorptance(0.9)
    gypsum.setSolarAbsorptance(0.7)
    gypsum.setVisibleAbsorptance(0.7)
    gypsum.setName("5/8 in. Gypsum Board") # RSi = 0.099375

    #Material:NoMass,
    #Typical Insulation R-35.4 1,            !- Name
    #Smooth,                                 !- Roughness
    #6.23478649910089,                       !- Thermal Resistance {m2-K/W}
    #0.9,                                    !- Thermal Absorptance
    #0.7,                                    !- Solar Absorptance
    #0.7;                                    !- Visible Absorptance

    #Material:NoMass, (once derated)
    #Attic_roof_east Typical Insulation R-35.4 2 tbd, !- Name
    #Smooth,                                 !- Roughness
    #4.20893587096259,                       !- Thermal Resistance {m2-K/W}
    #0.9,                                    !- Thermal Absorptance
    #0.7,                                    !- Solar Absorptance
    #0.7;                                    !- Visible Absorptance

    #OS:Material:NoMass,
    #{730da72e-2cdb-42f1-91aa-44ebaf6b683b}, !- Handle
    #Attic_roof_east Typical Insulation R-35.4 2 tbd, !- Name
    #Smooth,                                 !- Roughness
    #4.20893587096259,                       !- Thermal Resistance {m2-K/W} << derated, initially ~6.24?
    #0.9,                                    !- Thermal Absorptance
    #0.7,                                    !- Solar Absorptance
    #0.7;                                    !- Visible Absorptance
    ratedR35 = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    ratedR35.setRoughness("Smooth")
    ratedR35.setThermalResistance(6.24)
    ratedR35.setThermalAbsorptance(0.9)
    ratedR35.setSolarAbsorptance(0.7)
    ratedR35.setVisibleAbsorptance(0.7)
    ratedR35.setName("Attic_roof_east Typical Insulation R-35.4")

    deratedR35 = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    deratedR35.setRoughness("Smooth")
    deratedR35.setThermalResistance(4.21)
    deratedR35.setThermalAbsorptance(0.9)
    deratedR35.setSolarAbsorptance(0.7)
    deratedR35.setVisibleAbsorptance(0.7)
    deratedR35.setName("Attic_roof_east Typical Insulation R-35.4 2 tbd")

    #OS:Material,
    #{cce5c80d-e6fa-4569-9c4f-7b66f0700c6d}, !- Handle
    #25mm Stucco,                            !- Name
    #Smooth,                                 !- Roughness
    #0.0254,                                 !- Thickness {m}
    #0.719999999999999,                      !- Conductivity {W/m-K}
    #1855.99999999999,                       !- Density {kg/m3}
    #839.999999999997,                       !- Specific Heat {J/kg-K}
    #0.9,                                    !- Thermal Absorptance
    #0.7,                                    !- Solar Absorptance
    #0.7;                                    !- Visible Absorptance
    stucco = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
    stucco.setRoughness("Smooth")
    stucco.setThermalConductivity(0.72)
    stucco.setThickness(0.0254)
    stucco.setDensity(1856.0)
    stucco.setSpecificHeat(840.0)
    stucco.setThermalAbsorptance(0.9)
    stucco.setSolarAbsorptance(0.7)
    stucco.setVisibleAbsorptance(0.7)
    stucco.setName("25mm Stucco") # RSi = 0.0353

    #Material:NoMass,
    #Typical Insulation R-9.06,              !- Name
    #Smooth,                                 !- Roughness
    #1.59504467488221,                       !- Thermal Resistance {m2-K/W}
    #0.9,                                    !- Thermal Absorptance
    #0.7,                                    !- Solar Absorptance
    #0.7;                                    !- Visible Absorptance

    #OS:Material:NoMass,
    #{5621c538-653b-4356-b037-e3d3feff7ac1}, !- Handle
    #Perimeter_ZN_1_wall_south Typical Insulation R-9.06 1 tbd, !- Name
    #Smooth,                                 !- Roughness
    #0.594690149255382,                      !- Thermal Resistance {m2-K/W} << derated, initially ~1.60?
    #0.9,                                    !- Thermal Absorptance
    #0.7,                                    !- Solar Absorptance
    #0.7;                                    !- Visible Absorptance
    ratedR9 = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    ratedR9.setRoughness("Smooth")
    ratedR9.setThermalResistance(1.60)
    ratedR9.setThermalAbsorptance(0.9)
    ratedR9.setSolarAbsorptance(0.7)
    ratedR9.setVisibleAbsorptance(0.7)
    ratedR9.setName("Perimeter_ZN_1_wall_south Typical Insulation R-9.06 1")

    deratedR9 = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    deratedR9.setRoughness("Smooth")
    deratedR9.setThermalResistance(0.59)
    deratedR9.setThermalAbsorptance(0.9)
    deratedR9.setSolarAbsorptance(0.7)
    deratedR9.setVisibleAbsorptance(0.7)
    deratedR9.setName("Perimeter_ZN_1_wall_south Typical Insulation R-9.06 1 tbd")

    #FLOOR        air film resistance = 0.190 (USi = 5.4)
    #WALL         air film resistance = 0.150 (USi = 6.7)
    #ROOFCEILING  air film resistance = 0.136 (USi = 7.4)

    #Construction,
    #Typical Wood Joist Attic Floor R-37.04 1, !- Name
    #5/8 in. Gypsum Board,                   !- Layer 1
    #Typical Insulation R-35.4 1;            !- Layer 2

    #OS:Construction,
    #{909c4492-fe3b-4850-9468-150aa692b15b}, !- Handle
    #Attic_roof_east Typical Wood Joist Attic Floor R-37.04 tbd, !- Name
    #,                                       !- Surface Rendering Name
    #{7462f6dd-da46-4439-8dbe-ca9fd849f87b}, !- Layer 1 (Gypsum)
    #{730da72e-2cdb-42f1-91aa-44ebaf6b683b}; !- Layer 2 (R35 insulation)
    layers = OpenStudio::Model::MaterialVector.new
    layers << gypsum                          # RSi = 0.099375
    layers << ratedR35                        # Rsi = 6.24
                                              #     = 6.34    TOTAL (without air films) , USi = 0.158
                                              #     = 6.54    TOTAL if floor            , USi = 0.153
                                              #     = 6.50    TOTAL if wall             , USi = 0.154
                                              #     = 6.44    TOTAL if roof             , USi = 0.156
    rated_attic = OpenStudio::Model::Construction.new(os_model)
    rated_attic.setLayers(layers)
    rated_attic.setName("Attic_roof_east Typical Wood Joist Attic Floor R-37.04")
    expect(rated_attic.thermalConductance.get).to be_within(0.01).of(0.158)

    layers = OpenStudio::Model::MaterialVector.new
    layers << gypsum                          # RSi = 0.099375
    layers << deratedR35                      # Rsi = 4.21
                                              #     = 4.31    TOTAL (without air films) , USi = 0.232
                                              #     = 4.55    TOTAL if floor            , USi = 0.220
                                              #     = 4.46    TOTAL if wall             , USi = 0.224
                                              #     = 4.45    TOTAL if roof             , USi = 0.225
    derated_attic = OpenStudio::Model::Construction.new(os_model)
    derated_attic.setLayers(layers)
    derated_attic.setName("Attic_roof_east Typical Wood Joist Attic Floor R-37.04 tbd")
    expect(derated_attic.thermalConductance.get).to be_within(0.01).of(0.232)

    #OS:Construction,
    #{f234620a-99ac-491d-9979-2b49bdb02f43}, !- Handle
    #Perimeter_ZN_1_wall_south Typical Insulated Wood Framed Exterior Wall R-11.24 tbd, !- Name
    #,                                       !- Surface Rendering Name
    #{cce5c80d-e6fa-4569-9c4f-7b66f0700c6d}, !- Layer 1 (Stucco)
    #{7462f6dd-da46-4439-8dbe-ca9fd849f87b}, !- Layer 2 (Gypsum)
    #{5621c538-653b-4356-b037-e3d3feff7ac1}, !- Layer 3 (R9 insulation)
    #{7462f6dd-da46-4439-8dbe-ca9fd849f87b}; !- Layer 4 (Gypsum)
    layers = OpenStudio::Model::MaterialVector.new
    layers << stucco                          # RSi = 0.0353
    layers << gypsum                          # RSi = 0.099375
    layers << ratedR9                         # Rsi = 1.6
    layers << gypsum                          # RSi = 0.099375
                                              #     = 1.83    TOTAL (without air films) , USi = 0.546
                                              #     = 2.065   TOTAL if floor            , USi = 0.484
                                              #     = 1.98    TOTAL if wall             , USi = 0.505
                                              #     = 1.43    TOTAL if roof             , USi = 0.699
    rated_perimeter = OpenStudio::Model::Construction.new(os_model)
    rated_perimeter.setLayers(layers)
    rated_perimeter.setName("Perimeter_ZN_1_wall_south Typical Insulated Wood Framed Exterior Wall R-11.24")
    expect(rated_perimeter.thermalConductance.get).to be_within(0.01).of(0.546)

    layers = OpenStudio::Model::MaterialVector.new
    layers << stucco                          # RSi = 0.0353
    layers << gypsum                          # RSi = 0.099375
    layers << deratedR9                       # RSi = 0.59
    layers << gypsum                          # RSi = 0.099375
                                              #     = 0.824    TOTAL (without air films) , USi = 1.214
                                              #     = 1.059    TOTAL if floor            , USi = 0.944
                                              #     = 0.974    TOTAL if wall             , USi = 1.027
                                              #     = 0.960    TOTAL if roof             , USi = 1.042
    derated_perimeter = OpenStudio::Model::Construction.new(os_model)
    derated_perimeter.setLayers(layers)
    derated_perimeter.setName("Perimeter_ZN_1_wall_south Typical Insulated Wood Framed Exterior Wall R-11.24 tbd")
    expect(derated_perimeter.thermalConductance.get).to be_within(0.01).of(1.214)

    floor.setOutsideBoundaryCondition("Outdoors")
    floor.setConstruction(rated_attic)
    rated_attic_RSi = 1.0 / floor.uFactor.to_f
    expect(rated_attic_RSi).to be_within(0.01).of(6.53)
    #puts "... rated attic thermal conductance:#{floor.thermalConductance}"        # USi = 0.15773, RSi = 6.34
    #puts "... rated attic uFactor:#{floor.uFactor}"                               # USi = 0.15313, RSi = 6.53
    #     = 6.34    TOTAL (without air films) , USi = 0.158
    #     = 6.54    TOTAL if floor            , USi = 0.153
    #     = 6.50    TOTAL if wall             , USi = 0.154
    #     = 6.44    TOTAL if roof             , USi = 0.156

    floor.setConstruction(derated_attic)
    derated_attic_RSi = 1.0 / floor.uFactor.to_f
    expect(derated_attic_RSi).to be_within(0.01).of(4.50)
    #puts "... derated attic thermal conductance:#{floor.thermalConductance}"      # USi = 0.23202, RSi = 4.31
    #puts "... derated attic uFactor:#{floor.uFactor}"                             # USi = 0.22220, RSi = 4.50
    #     = 4.31    TOTAL (without air films) , USi = 0.232
    #     = 4.55    TOTAL if floor            , USi = 0.220
    #     = 4.46    TOTAL if wall             , USi = 0.224
    #     = 4.45    TOTAL if roof             , USi = 0.225

    floor.setConstruction(rated_perimeter)
    rated_perimeter_RSi = 1.0 / floor.uFactor.to_f
    expect(rated_perimeter_RSi).to be_within(0.01).of(2.03)
    #puts "... rated perimeter thermal conductance:#{floor.thermalConductance}"    # USi = 0.544877, RSi = 1.84
    #puts "... rated Perimeter uFactor:#{floor.uFactor}"                           # USi = 0.493664, RSi = 2.03
    #     = 1.83    TOTAL (without air films) , USi = 0.546
    #     = 2.065   TOTAL if floor            , USi = 0.484
    #     = 1.98    TOTAL if wall             , USi = 0.505
    #     = 1.43    TOTAL if roof             , USi = 0.699

    floor.setConstruction(derated_perimeter)
    derated_perimeter_RSi = 1.0 / floor.uFactor.to_f
    expect(derated_perimeter_RSi).to be_within(0.01).of(1.016)
    #puts "... derated perimeter thermal conductance:#{floor.thermalConductance}"  # USi = 1.211710, RSi = 0.825
    #puts "... derated perimeter uFactor:#{floor.uFactor}"                         # USi = 0.984571, RSi = 1.016
    #     = 0.824    TOTAL (without air films) , USi = 1.214
    #     = 1.059    TOTAL if floor            , USi = 0.944
    #     = 0.974    TOTAL if wall             , USi = 1.027
    #     = 0.960    TOTAL if roof             , USi = 1.042
  end
end
