require "openstudio"
require "topolys"
require "psi"

RSpec.describe TBD do
  it "can process thermal bridging and derating of complex architecture" do
    # The following populates both OpenStudio and Topolys models of "Lo scrigno"
    # (or Jewel Box), by Renzo Piano (Lingetto Factory, Turin); a cantilevered,
    # single space art gallery (space #1), above a slanted plenum (space #2),
    # and resting on four main pillars. For the purposes of the spec, vertical
    # access (elevator and stairs, fully glazed) are modelled as extensions
    # of either space.
    os_model = OpenStudio::Model::Model.new
    os_g = OpenStudio::Model::Space.new(os_model) # gallery "g" & elevator "e"
    os_p = OpenStudio::Model::Space.new(os_model) # plenum "p" & stairwell "s"
    os_s = OpenStudio::Model::ShadingSurfaceGroup.new(os_model)
    os_scrigno = os_model.getBuilding

    # For the purposes of the spec, all opaque envelope assemblies will be
    # built up from a single, 3-layered construction
    construction = OpenStudio::Model::Construction.new(os_model)
    expect(construction.handle.to_s.empty?).to be(false)
    expect(construction.nameString.empty?).to be(false)
    expect(construction.nameString).to eq("Construction 1")
    construction.setName("scrigno_construction")
    expect(construction.nameString).to eq("scrigno_construction")
    expect(construction.layers.size).to eq(0)

    exterior = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    expect(exterior.handle.to_s.empty?).to be(false)
    expect(exterior.nameString.empty?).to be(false)
    expect(exterior.nameString).to eq("Material No Mass 1")
    exterior.setName("scrigno_exterior")
    expect(exterior.nameString).to eq("scrigno_exterior")
    exterior.setRoughness("Rough")
    exterior.setThermalResistance(0.3626)
    exterior.setThermalAbsorptance(0.9)
    exterior.setSolarAbsorptance(0.7)
    exterior.setVisibleAbsorptance(0.7)
    expect(exterior.roughness).to eq("Rough")
    expect(exterior.thermalResistance).to be_within(0.0001).of(0.3626)
    expect(exterior.thermalAbsorptance.empty?).to be(false)
    expect(exterior.thermalAbsorptance.get).to be_within(0.0001).of(0.9)
    expect(exterior.solarAbsorptance.empty?).to be(false)
    expect(exterior.solarAbsorptance.get).to be_within(0.0001).of(0.7)
    expect(exterior.visibleAbsorptance.empty?).to be(false)
    expect(exterior.visibleAbsorptance.get).to be_within(0.0001).of(0.7)

    insulation = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
    expect(insulation.handle.to_s.empty?).to be(false)
    expect(insulation.nameString.empty?).to be(false)
    expect(insulation.nameString).to eq("Material 1")
    insulation.setName("scrigno_insulation")
    expect(insulation.nameString).to eq("scrigno_insulation")
    insulation.setRoughness("MediumRough")
    insulation.setThickness(0.1184)
    insulation.setConductivity(0.045)
    insulation.setDensity(265)
    insulation.setSpecificHeat(836.8)
    insulation.setThermalAbsorptance(0.9)
    insulation.setSolarAbsorptance(0.7)
    insulation.setVisibleAbsorptance(0.7)
    expect(insulation.roughness.empty?).to be(false)
    expect(insulation.roughness).to eq("MediumRough")
    expect(insulation.thickness).to be_within(0.0001).of(0.1184)
    expect(insulation.conductivity).to be_within(0.0001).of(0.045)
    expect(insulation.density).to be_within(0.0001 ).of(265)
    expect(insulation.specificHeat).to be_within(0.0001).of(836.8)
    expect(insulation.thermalAbsorptance).to be_within(0.0001).of(0.9)
    expect(insulation.solarAbsorptance).to be_within(0.0001).of(0.7)
    expect(insulation.visibleAbsorptance).to be_within(0.0001).of(0.7)

    interior = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
    expect(interior.handle.to_s.empty?).to be(false)
    expect(interior.nameString.empty?).to be(false)
    expect(interior.nameString.downcase).to eq("material 1")
    interior.setName("scrigno_interior")
    expect(interior.nameString).to eq("scrigno_interior")
    interior.setRoughness("MediumRough")
    interior.setThickness(0.0126)
    interior.setConductivity(0.16)
    interior.setDensity(784.9)
    interior.setSpecificHeat(830)
    interior.setThermalAbsorptance(0.9)
    interior.setSolarAbsorptance(0.9)
    interior.setVisibleAbsorptance(0.9)
    expect(interior.roughness.downcase).to eq("mediumrough")
    expect(interior.thickness).to be_within(0.0001).of(0.0126)
    expect(interior.conductivity).to be_within(0.0001).of( 0.16)
    expect(interior.density).to be_within(0.0001).of(784.9)
    expect(interior.specificHeat).to be_within(0.0001).of(830)
    expect(interior.thermalAbsorptance).to be_within(0.0001).of( 0.9)
    expect(interior.solarAbsorptance).to be_within(0.0001).of( 0.9)
    expect(interior.visibleAbsorptance).to be_within(0.0001).of( 0.9)

    layers = OpenStudio::Model::MaterialVector.new
    layers << exterior
    layers << insulation
    layers << interior
    expect(construction.setLayers(layers)).to be(true)
    expect(construction.layers.size).to eq(3)
    expect(construction.layers[0].handle.to_s).to eq(exterior.handle.to_s)
    expect(construction.layers[1].handle.to_s).to eq(insulation.handle.to_s)
    expect(construction.layers[2].handle.to_s).to eq(interior.handle.to_s)

    defaults = OpenStudio::Model::DefaultSurfaceConstructions.new(os_model)
    expect(defaults.setWallConstruction(construction)).to be(true)
    expect(defaults.setRoofCeilingConstruction(construction)).to be(true)
    expect(defaults.setFloorConstruction(construction)).to be(true)

    set = OpenStudio::Model::DefaultConstructionSet.new(os_model)
    expect(set.setDefaultExteriorSurfaceConstructions(defaults)).to be(true)

    # Set building shading surfaces:
    # (4x above gallery roof + 2x North/South balconies)
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(12.4, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new(12.4, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new(22.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new(22.7, 45.0, 50.0)
    os_r1_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r1_shade.setName("r1_shade")
    os_r1_shade.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(22.7, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new(22.7, 37.5, 50.0)
    os_v << OpenStudio::Point3d.new(48.7, 37.5, 50.0)
    os_v << OpenStudio::Point3d.new(48.7, 45.0, 50.0)
    os_r2_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r2_shade.setName("r2_shade")
    os_r2_shade.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(22.7, 32.5, 50.0)
    os_v << OpenStudio::Point3d.new(22.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new(48.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new(48.7, 32.5, 50.0)
    os_r3_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r3_shade.setName("r3_shade")
    os_r3_shade.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(48.7, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new(48.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new(59.0, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new(59.0, 45.0, 50.0)
    os_r4_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r4_shade.setName("r4_shade")
    os_r4_shade.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(47.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new(47.4, 41.7, 44.0)
    os_v << OpenStudio::Point3d.new(45.7, 41.7, 44.0)
    os_v << OpenStudio::Point3d.new(45.7, 40.2, 44.0)
    os_N_balcony = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_N_balcony.setName("N_balcony") # 1.70m as thermal bridge
    os_N_balcony.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(28.1, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new(28.1, 28.3, 44.0)
    os_v << OpenStudio::Point3d.new(47.4, 28.3, 44.0)
    os_v << OpenStudio::Point3d.new(47.4, 29.8, 44.0)
    os_S_balcony = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_S_balcony.setName("S_balcony") # 19.3m as thermal bridge
    os_S_balcony.setShadingSurfaceGroup(os_s)


    # 1st space: gallery (g) with elevator (e) surfaces
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(17.4, 40.2, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new(17.4, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new(17.4, 29.8, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new(17.4, 29.8, 49.5) # 10.4m
    os_g_W_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_W_wall.setName("g_W_wall")
    os_g_W_wall.setSpace(os_g)                        #  57.2m2

    expect(os_g_W_wall.surfaceType.downcase).to eq("wall")
    expect(os_g_W_wall.isConstructionDefaulted).to be(true)
    c = set.getDefaultConstruction(os_g_W_wall).get.to_Construction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be(true)
    expect(c.nameString).to eq("scrigno_construction")

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(54.0, 40.2, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new(54.0, 40.2, 44.0) # 36.6m
    os_v << OpenStudio::Point3d.new(17.4, 40.2, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new(17.4, 40.2, 49.5) # 36.6m
    os_g_N_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_N_wall.setName("g_N_wall")
    os_g_N_wall.setSpace(os_g)                        # 201.3m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 46.0) #   2.0m
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 44.0) #   1.0m
    os_v << OpenStudio::Point3d.new( 46.4, 29.8, 44.0) #   2.0m
    os_v << OpenStudio::Point3d.new( 46.4, 29.8, 46.0) #   1.0m
    os_g_N_door = OpenStudio::Model::SubSurface.new(os_v, os_model)
    os_g_N_door.setName("g_N_door")
    os_g_N_door.setSubSurfaceType("Door")
    os_g_N_door.setSurface(os_g_N_wall)                #   2.0m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(54.0, 29.8, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new(54.0, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new(54.0, 40.2, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new(54.0, 40.2, 49.5) # 10.4m
    os_g_E_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_E_wall.setName("g_E_wall")
    os_g_E_wall.setSpace(os_g)                        # 57.2m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new(17.4, 29.8, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new(17.4, 29.8, 44.0) #  6.6m
    os_v << OpenStudio::Point3d.new(24.0, 29.8, 44.0) #  2.7m
    os_v << OpenStudio::Point3d.new(24.0, 29.8, 46.7) #  4.0m
    os_v << OpenStudio::Point3d.new(28.0, 29.8, 46.7) #  2.7m
    os_v << OpenStudio::Point3d.new(28.0, 29.8, 44.0) # 26.0m
    os_v << OpenStudio::Point3d.new(54.0, 29.8, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new(54.0, 29.8, 49.5) # 36.6m
    os_g_S_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_S_wall.setName("g_S_wall")
    os_g_S_wall.setSpace(os_g)                        # 190.48m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 46.4, 29.8, 46.0) #  2.0m
    os_v << OpenStudio::Point3d.new( 46.4, 29.8, 44.0) #  1.0m
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 44.0) #  2.0m
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 46.0) #  1.0m
    os_g_S_door = OpenStudio::Model::SubSurface.new(os_v, os_model)
    os_g_S_door.setName("g_S_door")
    os_g_S_door.setSubSurfaceType("Door")
    os_g_S_door.setSurface(os_g_S_wall)                #   2.0m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5) # 36.6m
    os_g_top = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_top.setName("g_top")
    os_g_top.setSpace(os_g)                            # 380.64m2

    expect(os_g_top.surfaceType.downcase).to eq("roofceiling")
    expect(os_g_top.isConstructionDefaulted).to be(true)
    c = set.getDefaultConstruction(os_g_top).get.to_Construction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be(true)
    expect(c.nameString).to eq("scrigno_construction")

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5) # 36.6m
    os_g_sky = OpenStudio::Model::SubSurface.new(os_v, os_model)
    os_g_sky.setName("g_sky")
    os_g_sky.setSurface(os_g_top)                      # 380.64m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 46.7) #  1.5m
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 46.7) #  4.0m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7) #  1.5m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 46.7) #  4.0m
    os_e_top = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_top.setName("e_top")
    os_e_top.setSpace(os_g)                            #   6.0m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 40.8) #  1.5m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 40.8) #  4.0m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8) #  1.5m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8) #  4.0m
    os_e_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_floor.setName("e_floor")
    os_e_floor.setSpace(os_g)                          #   6.0m2
    os_e_floor.setOutsideBoundaryCondition("Outdoors")

    expect(os_e_floor.surfaceType.downcase).to eq("floor")
    expect(os_e_floor.isConstructionDefaulted).to be(true)
    c = set.getDefaultConstruction(os_e_floor).get.to_Construction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be(true)
    expect(c.nameString).to eq("scrigno_construction")

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 46.7) #  5.9m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 40.8) #  1.5m
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 40.8) #  5.9m
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 46.7) #  1.5m
    os_e_W_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_W_wall.setName("e_W_wall")
    os_e_W_wall.setSpace(os_g)                         #   8.85m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 46.7) #  5.9m
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 40.8) #  4.0m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8) #  5.5m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7) #  4.0m
    os_e_S_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_S_wall.setName("e_S_wall")
    os_e_S_wall.setSpace(os_g)                         #  23.6m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7) #  5.9m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8) #  1.5m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8) #  5.9m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 46.7) #  1.5m
    os_e_E_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_E_wall.setName("e_E_wall")
    os_e_E_wall.setSpace(os_g)                         #   8.85m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4) #  1.60m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8) #  4.00m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 40.8) #  2.20m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) #  4.04m
    os_e_N_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_N_wall.setName("e_N_wall")
    os_e_N_wall.setSpace(os_g)                         #  ~7.63m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0) #  1.60m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4) #  4.04m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) #  1.00m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0) #  4.00m
    os_e_p_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_p_wall.setName("e_p_wall")
    os_e_p_wall.setSpace(os_g)                         #   ~5.2m2
    os_e_p_wall.setOutsideBoundaryCondition("Space")

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 36.6m
    os_g_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_floor.setName("g_floor")
    os_g_floor.setSpace(os_g)                         # 380.64m2
    os_g_floor.setOutsideBoundaryCondition("Space")


    # 2nd space: plenum (p) with stariwell (s) surfaces
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 36.6m
    os_p_top = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_top.setName("p_top")
    os_p_top.setSpace(os_p)                            # 380.64m2
    os_p_top.setOutsideBoundaryCondition("Space")

    os_p_top.setAdjacentSurface(os_g_floor)
    os_g_floor.setAdjacentSurface(os_p_top)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0) #  1.00m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) #  4.04m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4) #  1.60m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0) #  4.00m
    os_p_e_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_e_wall.setName("p_e_wall")
    os_p_e_wall.setSpace(os_p)                         #  ~5.2m2
    os_p_e_wall.setOutsideBoundaryCondition("Space")

    os_e_p_wall.setAdjacentSurface(os_p_e_wall)
    os_p_e_wall.setAdjacentSurface(os_e_p_wall)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) #   6.67m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) #   1.00m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0) #   6.60m
    os_p_S1_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_S1_wall.setName("p_S1_wall")
    os_p_S1_wall.setSpace(os_p)                        #  ~3.3m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0) #   1.60m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4) #   2.73m
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.0) #  10.00m
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0) #  13.45m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) #  25.00m
    os_p_S2_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_S2_wall.setName("p_S2_wall")
    os_p_S2_wall.setSpace(os_p)                        #  38.15m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) #  13.45m
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0) #  10.00m
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.0) #  13.45m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) #  36.60m
    os_p_N_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_N_wall.setName("p_N_wall")
    os_p_N_wall.setSpace(os_p)                         #  46.61m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.0) # 10.0m
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0) # 10.0m
    os_p_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_floor.setName("p_floor")
    os_p_floor.setSpace(os_p)                         # 104.00m2
    os_p_floor.setOutsideBoundaryCondition("Outdoors")

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0) # 10.40m
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0) # 13.45m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 10.40m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 13.45m
    os_p_E_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_E_floor.setName("p_E_floor")
    os_p_E_floor.setSpace(os_p)                        # 139.88m2
    os_p_E_floor.setSurfaceType("Floor") # slanted floors are walls (default)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) # 10.40m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # ~6.68m
    os_v << OpenStudio::Point3d.new( 24.0, 40.2, 43.0) # 10.40m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) # ~6.68m
    os_p_W1_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_W1_floor.setName("p_W1_floor")
    os_p_W1_floor.setSpace(os_p)                       #  69.44m2
    os_p_W1_floor.setSurfaceType("Floor") # slanted floors are walls (default)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.00) #  3.30m
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.00) #  5.06m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.26) #  3.80m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.26) #  5.06m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.00) #  3.30m
    os_v << OpenStudio::Point3d.new( 24.0, 40.2, 43.00) #  6.77m
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.00) # 10.40m
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.00) #  6.77m
    os_p_W2_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_W2_floor.setName("p_W2_floor")
    os_p_W2_floor.setSpace(os_p)                        #  51.23m2
    os_p_W2_floor.setSurfaceType("Floor") # slanted floors are walls (default)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.0) #  2.2m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.8) #  3.8m
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.8) #  2.2m
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.0) #  3.8m
    os_s_W_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_W_wall.setName("s_W_wall")
    os_s_W_wall.setSpace(os_p)                         #   8.39m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.26) #  1.46m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.80) #  5.00m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.80) #  2.20m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.00) #  5.06m
    os_s_N_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_N_wall.setName("s_N_wall")
    os_s_N_wall.setSpace(os_p)                          #   9.15m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.26) #  1.46m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.80) #  3.80m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.80) #  1.46m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.26) #  3.80m
    os_s_E_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_E_wall.setName("s_E_wall")
    os_s_E_wall.setSpace(os_p)                          #   5.55m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.00) #  2.20m
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.80) #  5.00m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.80) #  1.46m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.26) #  5.06m
    os_s_S_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_S_wall.setName("s_S_wall")
    os_s_S_wall.setSpace(os_p)                          #   9.15m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.8) #  3.8m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.8) #  5.0m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.8) #  3.8m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.8) #  5.0m
    os_s_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_floor.setName("s_floor")
    os_s_floor.setSpace(os_p)                          #  19.0m2
    os_s_floor.setSurfaceType("Floor")
    os_s_floor.setOutsideBoundaryCondition("Outdoors")

    # Topolys edges may constitute thermal bridges (and therefore thermally
    # derate linked OpenStudio surfaces), depending on a number of factors such
    # as surface types and boundary conditions. Thermal bridging attributes
    # (type & PSI-value pairs) are grouped into PSI sets, normally accessed
    # through the 'set' user-argument (in the OpenStudio Measure interface).
    psi = PSI.new
    set = psi.set["poor (BC Hydro)"]

    # create the Topolys Model
    t_model = Topolys::Model.new

    # Fetch OpenStudio planar surfaces & key attributes
    surfaces = {}
    os_model.getPlanarSurfaces.each do |planar|
      next if planar.planarSurfaceGroup.empty?
      group = planar.planarSurfaceGroup.get
      id = planar.nameString

      # site transformation & rotation
      t = group.siteTransformation
      r = group.directionofRelativeNorth + os_model.getBuilding.northAxis

      # shading surface groups may also be linked to (rotated) spaces
      shading = group.to_ShadingSurfaceGroup
      unless shading.empty?
        unless shading.get.space.empty?
          r += shading.get.space.get.directionofRelativeNorth
        end
      end

      # site-specific (or absolute, or true) surface normal
      # this is here only for temporary testing of Topolys equivalence
      # (Topolys is in absolute coordinates only)
      n = OpenStudio::Vector3d.new(planar.outwardNormal.x * Math.cos( r ) -
                                   planar.outwardNormal.y * Math.sin( r ), # x
                                   planar.outwardNormal.x * Math.sin( r ) +
                                   planar.outwardNormal.y * Math.cos( r ), # y
                                   planar.outwardNormal.z )                # z

      points = (t*planar.vertices).map{|v| Topolys::Point3D.new(v.x, v.y, v.z)}
      minz = (points.map{|p| p.z}).min

      # Default values (some for short-term testing)
      #
      # type: initially e.g. "OS_Surface", "OS_SubSurface", "OS_ShadingSurface"
      # interior partition surfaces (e.g. daylight shelves) are ignored
      type = planar.iddObjectType.valueName
      ground = false
      boundary = nil
      dad = nil
      shade = false
      space = nil

      # reset some values ...
      surface = planar.to_Surface
      unless surface.empty?
        surface = surface.get
        type = surface.surfaceType
        ground = surface.isGroundSurface
        boundary = surface.outsideBoundaryCondition
      end
      sub = planar.to_SubSurface
      unless sub.empty?
        sub = sub.get
        type = sub.subSurfaceType
        boundary = sub.outsideBoundaryCondition
        dad = sub.surface.get.nameString unless sub.surface.empty?
      end
      shading = planar.to_ShadingSurface
      shade = true unless shading.empty?

      # this content of the hash will evolve over the next few iterations
      surfaces[id] = {
        type: type,
        boundary: boundary,
        gross: planar.grossArea,
        net: planar.netArea,
        points: points,
        minz: minz
      }
    end # surfaces{} are populated

    # add a Topolys Face for each OpenStudio Surface
    surfaces.each do |id, properties|
      #puts id
      vertices = t_model.get_vertices(properties[:points])
      #wire = t_model.get_wire(vertices)
      #face = t_model.get_face(wire, [])
    end
  end

end
