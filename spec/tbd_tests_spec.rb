require "psi"

  RSpec.describe TBD do
  it "can process thermal bridging and derating : LoScrigno" do
    # The following populates both OpenStudio and Topolys models of "Lo scrigno"
    # (or Jewel Box), by Renzo Piano (Lingotto Factory, Turin); a cantilevered,
    # single space art gallery (space #1), above a slanted plenum (space #2),
    # and resting on four main pillars. For the purposes of the spec, vertical
    # access (elevator and stairs, fully glazed) are modelled as extensions
    # of either space.

    # Apart from populating the OpenStudio model, the bulk of the next few
    # hundred is copy of the processTBD method. It is repeated step-by-step
    # here for detailed testing purposes.

    os_model = OpenStudio::Model::Model.new
    os_g = OpenStudio::Model::Space.new(os_model) # gallery "g" & elevator "e"
    os_g.setName("scrigno_gallery")
    os_p = OpenStudio::Model::Space.new(os_model) # plenum "p" & stairwell "s"
    os_p.setName("scrigno_plenum")
    os_s = OpenStudio::Model::ShadingSurfaceGroup.new(os_model)

    os_building = os_model.getBuilding

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

    # if one comments out the following, then one can no longer rely on a
    # building-specific, default construction set. If missing, fall back to
    # to model default construction set @index 0.
    os_building.setDefaultConstructionSet(set)

    # 8" XPS massless variant, specific for elevator floor (not defaulted)
    xps8x25mm = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    expect(xps8x25mm.handle.to_s.empty?).to be(false)
    expect(xps8x25mm.nameString.empty?).to be(false)
    expect(xps8x25mm.nameString).to eq("Material No Mass 1")
    xps8x25mm.setName("xps8x25mm")
    expect(xps8x25mm.nameString).to eq("xps8x25mm")
    xps8x25mm.setRoughness("Rough")
    xps8x25mm.setThermalResistance(8 * 0.88)
    xps8x25mm.setThermalAbsorptance(0.9)
    xps8x25mm.setSolarAbsorptance(0.7)
    xps8x25mm.setVisibleAbsorptance(0.7)
    expect(xps8x25mm.roughness).to eq("Rough")
    expect(xps8x25mm.thermalResistance).to be_within(0.0001).of(7.0400)
    expect(xps8x25mm.thermalAbsorptance.empty?).to be(false)
    expect(xps8x25mm.thermalAbsorptance.get).to be_within(0.0001).of(0.9)
    expect(xps8x25mm.solarAbsorptance.empty?).to be(false)
    expect(xps8x25mm.solarAbsorptance.get).to be_within(0.0001).of(0.7)
    expect(xps8x25mm.visibleAbsorptance.empty?).to be(false)
    expect(xps8x25mm.visibleAbsorptance.get).to be_within(0.0001).of(0.7)

    elevator_floor_c = OpenStudio::Model::Construction.new(os_model)
    expect(elevator_floor_c.handle.to_s.empty?).to be(false)
    expect(elevator_floor_c.nameString.empty?).to be(false)
    expect(elevator_floor_c.nameString).to eq("Construction 1")
    elevator_floor_c.setName("elevator_floor_c")
    expect(elevator_floor_c.nameString).to eq("elevator_floor_c")
    expect(elevator_floor_c.layers.size).to eq(0)

    mats = OpenStudio::Model::MaterialVector.new
    mats << exterior
    mats << xps8x25mm
    mats << interior
    expect(elevator_floor_c.setLayers(mats)).to be(true)
    expect(elevator_floor_c.layers.size).to eq(3)
    expect(elevator_floor_c.layers[0].handle.to_s).to eq(exterior.handle.to_s)
    expect(elevator_floor_c.layers[1].handle.to_s).to eq(xps8x25mm.handle.to_s)
    expect(elevator_floor_c.layers[2].handle.to_s).to eq(interior.handle.to_s)

    # Set building shading surfaces:
    # (4x above gallery roof + 2x North/South balconies)
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 12.4, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new( 12.4, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 45.0, 50.0)
    os_r1_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r1_shade.setName("r1_shade")
    os_r1_shade.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 22.7, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 37.5, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 37.5, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 45.0, 50.0)
    os_r2_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r2_shade.setName("r2_shade")
    os_r2_shade.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 22.7, 32.5, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 32.5, 50.0)
    os_r3_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r3_shade.setName("r3_shade")
    os_r3_shade.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 48.7, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 59.0, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 59.0, 45.0, 50.0)
    os_r4_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r4_shade.setName("r4_shade")
    os_r4_shade.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 41.7, 44.0)
    os_v << OpenStudio::Point3d.new( 45.7, 41.7, 44.0)
    os_v << OpenStudio::Point3d.new( 45.7, 40.2, 44.0)
    os_N_balcony = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_N_balcony.setName("N_balcony") # 1.70m as thermal bridge
    os_N_balcony.setShadingSurfaceGroup(os_s)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.1, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 28.1, 28.3, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 28.3, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 44.0)
    os_S_balcony = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_S_balcony.setName("S_balcony") # 19.3m as thermal bridge
    os_S_balcony.setShadingSurfaceGroup(os_s)


    # 1st space: gallery (g) with elevator (e) surfaces
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5) # 10.4m
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
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 36.6m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5) # 36.6m
    os_g_N_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_N_wall.setName("g_N_wall")
    os_g_N_wall.setSpace(os_g)                        # 201.3m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 46.0) #   2.0m
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 44.0) #   1.0m
    os_v << OpenStudio::Point3d.new( 46.4, 40.2, 44.0) #   2.0m
    os_v << OpenStudio::Point3d.new( 46.4, 40.2, 46.0) #   1.0m
    os_g_N_door = OpenStudio::Model::SubSurface.new(os_v, os_model)
    os_g_N_door.setName("g_N_door")
    os_g_N_door.setSubSurfaceType("Door")
    os_g_N_door.setSurface(os_g_N_wall)                #   2.0m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5) # 10.4m
    os_g_E_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_E_wall.setName("g_E_wall")
    os_g_E_wall.setSpace(os_g)                        # 57.2m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) #  6.6m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0) #  2.7m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 46.7) #  4.0m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 46.7) #  2.7m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0) # 26.0m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5) # 36.6m
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

    # initially, elevator floor is defaulted ...
    expect(os_e_floor.surfaceType.downcase).to eq("floor")
    expect(os_e_floor.isConstructionDefaulted).to be(true)
    c = set.getDefaultConstruction(os_e_floor).get.to_Construction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be(true)
    expect(c.nameString).to eq("scrigno_construction")

    # ... now overriding default construction
    os_e_floor.setConstruction(elevator_floor_c)
    expect(os_e_floor.isConstructionDefaulted).to be(false)
    c = os_e_floor.construction.get.to_Construction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be(true)
    expect(c.nameString).to eq("elevator_floor_c")

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
    os_e_p_wall.setOutsideBoundaryCondition("Surface")

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 36.6m
    os_g_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_floor.setName("g_floor")
    os_g_floor.setSpace(os_g)                         # 380.64m2
    os_g_floor.setOutsideBoundaryCondition("Surface")


    # 2nd space: plenum (p) with stairwell (s) surfaces
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 36.6m
    os_p_top = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_top.setName("p_top")
    os_p_top.setSpace(os_p)                            # 380.64m2
    os_p_top.setOutsideBoundaryCondition("Surface")

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
    os_p_e_wall.setOutsideBoundaryCondition("Surface")

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

    #os_model.save("os_model_test.osm", true)

    # Create the Topolys Model.
    t_model = Topolys::Model.new

    # "true" if any OSM space/zone holds DD setpoint temperatures.
    # ... is heating/winter or cooling/summer "northern hemisphere" biased?
    setpoints = winterDesignDayTemperatureSetpoints?(os_model)
    setpoints = summerDesignDayTemperatureSetpoints?(os_model) unless setpoints

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
          heating = winterDesignDayTemperatureSetpoint(zone)
          cooling = summerDesignDayTemperatureSetpoint(zone)

          conditioned = false if airloops && zone.canBePlenum
        else
          conditioned = false
        end
      end

      t, r = transforms(os_model, space)
      n = trueNormal(s, r)

      type = :floor
      type = :ceiling if /ceiling/i.match(s.surfaceType)
      type = :wall if /wall/i.match(s.surfaceType)

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
      surfaces[id][:heating] = heating if heating  # if valid winter DD setpoint
      surfaces[id][:cooling] = cooling if cooling  # if valid summer DD setpoint
      surfaces[id][:stype] = space.spaceType.get unless space.spaceType.empty?
      surfaces[id][:story] = space.buildingStory.get unless space.buildingStory.empty?

      unless s.construction.empty?
        construction = s.construction.get.to_Construction.get
        # index  - of layer/material (to derate) in construction
        # ltype  - either massless (RSi) or standard (k + d)
        # r      - initial RSi value of the indexed layer to derate
        index, ltype, r = deratableLayer(construction)
        index = nil unless index.is_a?(Numeric)
        index = nil unless index >= 0
        index = nil unless index < c.layers.size
        unless index.nil?
          surfaces[id][:construction] = construction
          surfaces[id][:index]        = index
          surfaces[id][:ltype]        = ltype
          surfaces[id][:r]            = r
        end
      end
    end                                            # (opaque) surfaces populated

    surfaces.each do |id, surface|
      expect(surface[:conditioned]).to be(true)
      expect(surface.has_key?(:heating)).to be(false)
      expect(surface.has_key?(:cooling)).to be(false)
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
    end               # (opaque) surface "dads" populated with subsurface "kids"

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

    expect(surfaces["g_top"   ].has_key?(:windows  )).to be(false)
    expect(surfaces["g_top"   ].has_key?(:doors    )).to be(false)
    expect(surfaces["g_top"   ].has_key?(:skylights)).to be(true)

    expect(surfaces["g_top"   ][:skylights].size).to eq(1)
    expect(surfaces["g_S_wall"][:doors    ].size).to eq(1)
    expect(surfaces["g_N_wall"][:doors    ].size).to eq(1)

    expect(surfaces["g_top"   ][:skylights].has_key?("g_sky"   )).to be(true)
    expect(surfaces["g_S_wall"][:doors    ].has_key?("g_S_door")).to be(true)
    expect(surfaces["g_N_wall"][:doors    ].has_key?("g_N_door")).to be(true)

    expect(surfaces["g_top"   ].has_key?(:type)).to be(true)

    # Split "surfaces" hash into "floors", "ceilings" and "walls" hashes.
    floors = surfaces.select{ |i, p| p[:type] == :floor }
    floors = floors.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h
    expect(floors.size).to eq(7)

    ceilings = surfaces.select{ |i, p| p[:type] == :ceiling }
    ceilings = ceilings.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h
    expect(ceilings.size).to eq(3)

    walls = surfaces.select{|i, p| p[:type] == :wall }
    walls = walls.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h
    expect(walls.size).to eq(17)

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
    end # shading surfaces populated
    expect(shades.size).to eq(6)

    # Mutually populate TBD & Topolys surfaces. Keep track of created "holes".
    holes = {}
    floor_holes = populateTBDdads(t_model, floors)
    ceiling_holes = populateTBDdads(t_model, ceilings)
    wall_holes = populateTBDdads(t_model, walls)

    holes.merge!(floor_holes)
    holes.merge!(ceiling_holes)
    holes.merge!(wall_holes)

    expect(floor_holes.size).to eq(0)
    expect(ceiling_holes.size).to eq(1)
    expect(wall_holes.size).to eq(2)
    expect(holes.size).to eq(3)

    # Testing normals
    floors.values.each do |properties|
      t_x = properties[:face].outer.plane.normal.x
      t_y = properties[:face].outer.plane.normal.y
      t_z = properties[:face].outer.plane.normal.z

      expect(properties[:n].x).to be_within(0.001).of(t_x)
      expect(properties[:n].y).to be_within(0.001).of(t_y)
      expect(properties[:n].z).to be_within(0.001).of(t_z)
    end

    # OpenStudio (opaque) surfaces VS number of Topolys (opaque) faces
    expect(surfaces.size).to eq(27)
    expect(t_model.faces.size).to eq(27)

    populateTBDdads(t_model, shades)
    expect(t_model.faces.size).to eq(33)

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
    expect(edges.size).to eq(12)

    # Next, floors, ceilings & walls; then shades.
    tbdSurfaceEdges(floors, edges)
    expect(edges.size).to eq(47)

    tbdSurfaceEdges(ceilings, edges)
    expect(edges.size).to eq(51)

    tbdSurfaceEdges(walls, edges)
    expect(edges.size).to eq(67)

    tbdSurfaceEdges(shades, edges)
    expect(edges.size).to eq(89)
    expect(t_model.edges.size).to eq(89)

    # the following surfaces should all share an edge
    p_S2_wall_face = walls["p_S2_wall"][:face]
    e_p_wall_face  = walls["e_p_wall"][:face]
    p_e_wall_face  = walls["p_e_wall"][:face]
    e_E_wall_face  = walls["e_E_wall"][:face]

    p_S2_wall_edge_ids = Set.new(p_S2_wall_face.outer.edges.map{|oe| oe.id})
    e_p_wall_edges_ids = Set.new(e_p_wall_face.outer.edges.map{|oe| oe.id})
    p_e_wall_edges_ids = Set.new(p_e_wall_face.outer.edges.map{|oe| oe.id})
    e_E_wall_edges_ids = Set.new(e_E_wall_face.outer.edges.map{|oe| oe.id})

    intersection = p_S2_wall_edge_ids & e_p_wall_edges_ids & p_e_wall_edges_ids
    expect(intersection.size).to eq 1

    intersection = p_S2_wall_edge_ids & e_p_wall_edges_ids & p_e_wall_edges_ids & e_E_wall_edges_ids
    expect(intersection.size).to eq 1

    shared_edges = p_S2_wall_face.shared_outer_edges(e_p_wall_face)
    expect(shared_edges.size).to eq 1
    expect(shared_edges.first.id).to eq intersection.to_a.first

    shared_edges = p_S2_wall_face.shared_outer_edges(p_e_wall_face)
    expect(shared_edges.size).to eq 1
    expect(shared_edges.first.id).to eq intersection.to_a.first

    shared_edges = p_S2_wall_face.shared_outer_edges(e_E_wall_face)
    expect(shared_edges.size).to eq 1
    expect(shared_edges.first.id).to eq intersection.to_a.first

    # g_floor and p_top should be connected with all edges shared
    g_floor_face = floors["g_floor"][:face]
    g_floor_wire = g_floor_face.outer
    g_floor_edges = g_floor_wire.edges
    p_top_face = ceilings["p_top"][:face]
    p_top_wire = p_top_face.outer
    p_top_edges = p_top_wire.edges
    shared_edges = p_top_face.shared_outer_edges(g_floor_face)

    expect(g_floor_edges.size).to be > 4
    expect(g_floor_edges.size).to eq(p_top_edges.size)
    expect(shared_edges.size).to eq(p_top_edges.size)
    g_floor_edges.each do |g_floor_edge|
      p_top_edge = p_top_edges.find{|e| e.id == g_floor_edge.id}
      expect(p_top_edge).to be_truthy
    end

    expect(floors.size).to eq(7)
    expect(ceilings.size).to eq(3)
    expect(walls.size).to eq(17)
    expect(shades.size).to eq(6)

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
    zenith      = Topolys::Vector3D.new(0, 0, 1).freeze
    north       = Topolys::Vector3D.new(0, 1, 0).freeze
    east        = Topolys::Vector3D.new(1, 0, 0).freeze

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
      else # project zenith vector unto edge plane
        reference = edge_plane.project(origin + zenith)
        reference_V = reference - origin
      end

      edge[:surfaces].each do |id, surface|
        # loop through each linked wire and determine farthest point from
        # edge while ensuring candidate point is not aligned with edge
        t_model.wires.each do |wire|
          if surface[:wire] == wire.id # there should be a unique match
            normal = surfaces[id][:n]         if surfaces.has_key?(id)
            normal = holes[id].attributes[:n] if holes.has_key?(id)
            normal = shades[id][:n]           if shades.has_key?(id)

            farthest = Topolys::Point3D.new(origin.x, origin.y, origin.z)
            farthest_V = farthest - origin # zero magnitude, initially

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

            angle = edge_V.angle(farthest_V)
            expect(angle).to be_within(0.01).of(Math::PI / 2) # for testing

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

            # store angle
            surface[:angle] = angle
            farthest_V.normalize!
            surface[:polar] = farthest_V
            surface[:normal] = normal
          end # not sure if it's worth checking matching id's ...
        end # end of edge-linked, surface-to-wire loop
      end # end of edge-linked surface loop

      # sort angles
      edge[:surfaces] = edge[:surfaces].sort_by{ |i, p| p[:angle] }.to_h
    end # end of edge loop

    expect(edges.size).to eq(89)
    expect(t_model.edges.size).to eq(89)

    # Topolys edges may constitute thermal bridges (and therefore thermally
    # derate linked OpenStudio surfaces), depending on a number of factors such
    # as surface types, space conditioning and boundary conditions. Thermal
    # bridging attributes (type & PSI-value pairs) are grouped into PSI sets,
    # normally accessed through the 'set' user-argument (in the OpenStudio
    # Measure interface).

    psi_set = "poor (BETBG)"
    # psi_set = "(non thermal bridging)"
    # psi_set = "code (Quebec)" # thermal bridging effect less critical

    # Process user-defined TBD JSON file inputs if file exists & valid:
    #   "io" holds valid TBD JSON hash from file
    #   "io_p" holds TBD PSI sets (built-in defaults & those on file)
    #   "io_k" holds TBD KHI points (built-in defaults & those on file)
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    io, io_p, io_k = processTBDinputs(surfaces, edges, psi_set, io_path, schema_path)

    # psi = PSI.new

    edges.values.each do |edge|
      next unless edge.has_key?(:surfaces)
      next unless edge[:surfaces].size > 1        # no longer required if :party

      # Skip unless one (at least) linked surface is deratable i.e.,
      # floor, ceiling or wall facing outdoors or UNCONDITIONED space.
      deratable = false
      edge[:surfaces].keys.each do |id|
        next if deratable
        deratable = true if floors.has_key?(id)
        deratable = true if ceilings.has_key?(id)
        deratable = true if walls.has_key?(id)
      end
      next unless deratable

      psi = {}                                         # edge-specific PSI types
      p = io[:building].first[:psi]                       # default building PSI

      match = false
      if edge.has_key?(:io_type)              # customized edge in TBD JSON file
        match = true
        t = edge[:io_type]
        p = edge[:io_set]       if edge.has_key?(:io_set)
        edge[:set] = p          if io_p.set.has_key?(p)
        psi[t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
      end

      edge[:surfaces].keys.each do |id|
        next if match                                       # skip if customized
        next unless surfaces.has_key?(id)
        next unless surfaces[id].has_key?(:conditioned)
        next unless surfaces[id][:conditioned]

        # Skipping the :party wall label for now. Criteria determining party
        # wall edges from TBD edges is to be determined. Most likely scenario
        # seems to be an edge linking only 1x surface facings outdoors (or
        # unconditioned space) with only 1x adiabatic surface. Warrants separate
        # tests. TO DO.

        # Label edge as :grade if linked to:
        #   1x surface (e.g. slab or wall) facing ground
        #   1x surface (i.e. wall) facing outdoors OR facing UNCONDITIONED space
        unless psi.has_key?(:grade)
          edge[:surfaces].keys.each do |i|
            next unless surfaces[id].has_key?(:ground)
            next unless surfaces[id][:ground]
            next unless surfaces.has_key?(i)
            next unless surfaces[i].has_key?(:conditioned)
            next unless surfaces[i][:conditioned]

            if surfaces.has_key?(surfaces[i][:boundary])      # adjacent surface
              adjacent = surfaces[i][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless surfaces[i][:boundary].downcase == "outdoors"
            end

            if surfaces.has_key?(surfaces[id][:boundary])     # adjacent surface
              adjacent = surfaces[id][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless surfaces[id][:boundary].downcase == "outdoors"
            end

            psi[:grade] = io_p.set[p][:grade]
          end
        end

        # Label edge as :balcony if linked to:
        #   1x floor
        #   1x shade
        unless psi.has_key?(:balcony)
          edge[:surfaces].keys.each do |i|
            next unless shades.has_key?(i)
            next unless floors.has_key?(id)
            psi[:balcony] = io_p.set[p][:balcony]
          end
        end

        # Label edge as :parapet if linked to:
        #   1x wall facing outdoors OR facing UNCONDITIONED space &
        #   1x ceiling facing outdoors OR facing UNCONDITIONED space
        unless psi.has_key?(:parapet)
          edge[:surfaces].keys.each do |i|
            next unless ceilings.has_key?(id)
            next unless walls.has_key?(i)
            next unless walls[i].has_key?(:conditioned)
            next unless walls[i][:conditioned]

            if surfaces.has_key?(walls[i][:boundary])         # adjacent surface
              adjacent = walls[i][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless walls[i][:boundary].downcase == "outdoors"
            end

            if surfaces.has_key?(ceilings[id][:boundary])     # adjacent surface
              adjacent = ceilings[id][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless ceilings[id][:boundary].downcase == "outdoors"
            end

            psi[:parapet] = io_p.set[p][:parapet]
          end
        end

        # Repeat for exposed floors vs walls, as :parapet is currently a
        # proxy for intersections between exposed floors & walls
        unless psi.has_key?(:parapet)
          edge[:surfaces].keys.each do |i|
            next unless floors.has_key?(id)
            next unless walls.has_key?(i)
            next unless walls[i].has_key?(:conditioned)
            next unless walls[i][:conditioned]

            if surfaces.has_key?(walls[i][:boundary])         # adjacent surface
              adjacent = walls[i][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless walls[i][:boundary].downcase == "outdoors"
            end

            if surfaces.has_key?(floors[id][:boundary])       # adjacent surface
              adjacent = floors[id][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless floors[id][:boundary].downcase == "outdoors"
            end

            psi[:parapet] = io_p.set[p][:parapet]
          end
        end

        # Repeat for exposed floors vs roofs, as :parapet is currently a
        # proxy for intersections between exposed floors & roofs
        unless psi.has_key?(:parapet)
          edge[:surfaces].keys.each do |i|
            next unless floors.has_key?(id)
            next unless ceilings.has_key?(i)
            next unless ceilings[i].has_key?(:conditioned)
            next unless ceilings[i][:conditioned]

            if surfaces.has_key?(ceilings[i][:boundary])      # adjacent surface
              adjacent = ceilings[i][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless ceilings[i][:boundary].downcase == "outdoors"
            end

            if surfaces.has_key?(floors[id][:boundary])       # adjacent surface
              adjacent = floors[id][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless floors[id][:boundary].downcase == "outdoors"
            end

            psi[:parapet] = io_p.set[p][:parapet]
          end
        end

        # Label edge as :rimjoist if linked to:
        #   1x wall facing outdoors OR facing UNCONDITIONED space &
        #   1x floor
        unless psi.has_key?(:rimjoist)
          edge[:surfaces].keys.each do |i|
            next unless floors.has_key?(i)
            next unless walls.has_key?(id)

            if surfaces.has_key?(walls[id][:boundary])        # adjacent surface
              adjacent = walls[id][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless walls[id][:boundary].downcase == "outdoors"
            end

            psi[:rimjoist] = io_p.set[p][:rimjoist]
          end
        end

        # Label edge as :fenestration if linked to:
        #   1x subsurface
        unless psi.has_key?(:fenestration)
          edge[:surfaces].keys.each do |i|
            next unless holes.has_key?(i)
            psi[:fenestration] = io_p.set[p][:fenestration]
          end
        end

        # Label edge as :concave or :convex (corner) if linked to:
        #   2x walls facing outdoors OR facing UNCONDITIONED space &
        #            f(relative polar positions of walls)
        unless psi.has_key?(:concave) || psi.has_key?(:convex)
          edge[:surfaces].keys.each do |i|
            next if i == id
            next unless walls.has_key?(id)
            next unless walls.has_key?(i)
            next unless walls[i].has_key?(:conditioned)
            next unless walls[i][:conditioned]

            if surfaces.has_key?(walls[i][:boundary])         # adjacent surface
              adjacent = walls[i][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless walls[i][:boundary].downcase == "outdoors"
            end

            if surfaces.has_key?(walls[id][:boundary])         # adjacent surface
              adjacent = walls[id][:boundary]
              next unless surfaces[adjacent].has_key?(:conditioned)
              next if surfaces[adjacent][:conditioned]
            else
              next unless walls[id][:boundary].downcase == "outdoors"
            end

            s1 = edge[:surfaces][id]
            s2 = edge[:surfaces][i]

            angle = s2[:angle] - s1[:angle]
            next unless angle > 0
            next unless (2 * Math::PI - angle).abs > 0
            next if angle > 3 * Math::PI / 4 && angle < 5 * Math::PI / 4

            n1_d_p2 = s1[:normal].dot(s2[:polar])
            p1_d_n2 = s1[:polar].dot(s2[:normal])
            psi[:concave] = io_p.set[p][:concave] if n1_d_p2 > 0 && p1_d_n2 > 0
            psi[:convex]  = io_p.set[p][:convex]  if n1_d_p2 < 0 && p1_d_n2 < 0
          end
        end
      end                                                 # edge's surfaces loop

      edge[:psi] = psi unless psi.empty?
      edge[:set] = p unless psi.empty?
    end                                                              # edge loop

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
      if io.has_key?(:stories)
        io[:stories].each do |story|
          next unless story.has_key?(:id)
          next unless story.has_key?(:psi)
          i = story[:id]
          p = story[:psi]
          next unless io_p.set.has_key?(p)

          edges.values.each do |edge|
            next unless edge.has_key?(:psi)
            next if edge.has_key?(:io_set)       # customized edge WITH custom PSI
            next unless edge.has_key?(:surfaces)

            # TBD/Topolys edges will generally be linked to more than one surface
            # and hence to more than one space. It is possible for a TBD JSON file
            # to hold 2x space PSI sets that affect one or more edges common to
            # both spaces. As with Ruby and JSON hashes, the last processed TBD
            # JSON space PSI set will supersede preceding ones. Caution ...
            # Future revisons to TBD JSON I/O validation, e.g. log warning?
            # Maybe revise e.g., retain most stringent PSI value?
            edge[:surfaces].keys.each do |id|
              next unless surfaces.has_key?(id)
              next unless surfaces[id].has_key?(:story)
              st = surfaces[id][:story]
              next unless i == st.nameString

              if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
                t = edge[:io_type]
                next unless io_p.set[p].has_key?(t)
                psi = {}
                psi[t] = io_p.set[p][t]
                edge[:psi] = psi
              else
                edge[:psi].keys.each do |t|
                  edge[:psi][t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                end
              end
              edge[:set] = p
            end
          end
        end
      end

      if io.has_key?(:spacetypes)
        io[:spacetypes].each do |stype|
          next unless stype.has_key?(:id)
          next unless stype.has_key?(:psi)
          i = stype[:id]
          p = stype[:psi]
          next unless io_p.set.has_key?(p)

          edges.values.each do |edge|
            next unless edge.has_key?(:psi)
            next if edge.has_key?(:io_set)       # customized edge WITH custom PSI
            next unless edge.has_key?(:surfaces)

            # TBD/Topolys edges will generally be linked to more than one surface
            # and hence to more than one space. It is possible for a TBD JSON file
            # to hold 2x space PSI sets that affect one or more edges common to
            # both spaces. As with Ruby and JSON hashes, the last processed TBD
            # JSON space PSI set will supersede preceding ones. Caution ...
            # Future revisons to TBD JSON I/O validation, e.g. log warning?
            # Maybe revise e.g., retain most stringent PSI value?
            edge[:surfaces].keys.each do |id|
              next unless surfaces.has_key?(id)
              next unless surfaces[id].has_key?(:stype)
              st = surfaces[id][:stype]
              next unless i == st.nameString

              if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
                t = edge[:io_type]
                next unless io_p.set[p].has_key?(t)
                psi = {}
                psi[t] = io_p.set[p][t]
                edge[:psi] = psi
              else
                edge[:psi].keys.each do |t|
                  edge[:psi][t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                end
              end
              edge[:set] = p
            end
          end
        end
      end

      if io.has_key?(:spaces)
        io[:spaces].each do |space|
          next unless space.has_key?(:id)
          next unless space.has_key?(:psi)
          i = space[:id]
          p = space[:psi]
          next unless io_p.set.has_key?(p)

          edges.values.each do |edge|
            next unless edge.has_key?(:psi)
            next if edge.has_key?(:io_set)       # customized edge WITH custom PSI
            next unless edge.has_key?(:surfaces)

            # TBD/Topolys edges will generally be linked to more than one surface
            # and hence to more than one space. It is possible for a TBD JSON file
            # to hold 2x space PSI sets that affect one or more edges common to
            # both spaces. As with Ruby and JSON hashes, the last processed TBD
            # JSON space PSI set will supersede preceding ones. Caution ...
            # Future revisons to TBD JSON I/O validation, e.g. log warning?
            # Maybe revise e.g., retain most stringent PSI value?
            edge[:surfaces].keys.each do |id|
              next unless surfaces.has_key?(id)
              next unless surfaces[id].has_key?(:space)
              sp = surfaces[id][:space]
              next unless i == sp.nameString

              if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
                t = edge[:io_type]
                next unless io_p.set[p].has_key?(t)
                psi = {}
                psi[t] = io_p.set[p][t]
                edge[:psi] = psi
              else
                edge[:psi].keys.each do |t|
                  edge[:psi][t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                end
              end
              edge[:set] = p
            end
          end
        end
      end

      if io.has_key?(:surfaces)
        io[:surfaces].each do |surface|
          next unless surface.has_key?(:id)
          next unless surface.has_key?(:psi)
          i = surface[:id]
          p = surface[:psi]
          next unless io_p.set.has_key?(p)

          edges.values.each do |edge|
            next unless edge.has_key?(:psi)
            next if edge.has_key?(:io_set)       # customized edge WITH custom PSI
            next unless edge.has_key?(:surfaces)

            # TBD/Topolys edges will generally be linked to more than one
            # surface. It is possible for a TBD JSON file to hold 2x surface PSI
            # sets that affect one or more edges common to both surfaces. As
            # with Ruby and JSON hashes, the last processed TBD JSON surface PSI
            # set will supersede preceding ones. Caution ...
            # Future revisons to TBD JSON I/O validation, e.g. log warning?
            # Maybe revise e.g., retain most stringent PSI value?
            edge[:surfaces].keys.each do |s|
              next unless surfaces.has_key?(s)
              next unless i == s
              if edge.has_key?(:io_type)          # custom edge w/o custom PSI set
                t = edge[:io_type]
                next unless io_p.set[p].has_key?(t)
                psi = {}
                psi[t] = io_p.set[p][t]
                edge[:psi] = psi
              else
                edge[:psi] = {} unless edge.has_key?(:psi)
                edge[:psi].keys.each do |t|
                  edge[:psi][t] = io_p.set[p][t] if io_p.set[p].has_key?(t)
                end
              end
              edge[:set] = p
            end
          end
        end
      end

      # Loop through all customized edges on file WITH a custom PSI set
      edges.values.each do |edge|
        next unless edge.has_key?(:psi)
        next unless edge.has_key?(:io_set)
        next unless edge.has_key?(:io_type)
        next unless edge.has_key?(:surfaces)

        t = edge[:io_type]
        p = edge[:io_set]
        next unless io_p.set.has_key?(p)
        next unless io_p.set[p].has_key?(t)
        psi = {}
        psi[t] = io_p.set[p][t]
        edge[:psi] = psi
        edge[:set] = p
      end
    end

    n_deratables = 0
    n_edges_at_grade = 0
    n_edges_as_balconies = 0
    n_edges_as_parapets = 0
    n_edges_as_rimjoists = 0
    n_edges_as_fenestrations = 0
    n_edges_as_concave_corners = 0
    n_edges_as_convex_corners = 0

    edges.values.each do |edge|
      next unless edge.has_key?(:psi)
      n_deratables += 1
      n_edges_at_grade            += 1 if edge[:psi].has_key?(:grade)
      n_edges_as_balconies        += 1 if edge[:psi].has_key?(:balcony)
      n_edges_as_parapets         += 1 if edge[:psi].has_key?(:parapet)
      n_edges_as_rimjoists        += 1 if edge[:psi].has_key?(:rimjoist)
      n_edges_as_fenestrations    += 1 if edge[:psi].has_key?(:fenestration)
      n_edges_as_concave_corners  += 1 if edge[:psi].has_key?(:concave)
      n_edges_as_convex_corners   += 1 if edge[:psi].has_key?(:convex)
    end
    expect(n_deratables).to eq(62)
    expect(n_edges_at_grade).to eq(0)
    expect(n_edges_as_balconies).to eq(4)
    expect(n_edges_as_parapets).to eq(31)
    expect(n_edges_as_rimjoists).to eq(32)
    expect(n_edges_as_fenestrations).to eq(12)
    expect(n_edges_as_concave_corners).to eq(4)
    expect(n_edges_as_convex_corners).to eq(12)

    # loop through each edge and assign heat loss to linked surfaces.
    edges.each do |identifier, edge|
      next unless edge.has_key?(:psi)
      psi = edge[:psi].values.max

      bridge = { psi: psi,
                 type: edge[:psi].key(psi),
                 length: edge[:length] }

      # Retrieve valid linked surfaces as deratables.
      deratables = {}
      edge[:surfaces].each do |id, surface|
        next unless surfaces.has_key?(id)
        deratable = false
        if surfaces[id][:boundary].downcase == "outdoors"
          deratable = true if surfaces[id][:conditioned] == true
        elsif surfaces[id][:boundary].downcase == "space"
          expect(surfaces[id].adjacentSurface.empty?).to be(false)
          adjacent = surfaces[id].adjacentSurface.get
          i = adjacent.nameString
          expect(surfaces.has_key?(i)).to be(true)
          deratable = true if surfaces[i][:conditioned] == false
        end
        next unless deratable
        deratables[id] = surface
      end

      # Retrieve linked openings.
      openings = {}
      if edge[:psi].has_key?(:fenestration)
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
        expect(surfaces[id].has_key?(:r)).to be(true)
        rsi += surfaces[id][:r]
      end

      # Assign heat loss from thermal bridges to surfaces, in proportion to
      # insulating layer thermal resistance
      deratables.each do |id, deratable|
        surfaces[id][:edges] = {} unless surfaces[id].has_key?(:edges)
        loss = bridge[:psi] * surfaces[id][:r] / rsi

        b = { psi: loss, type: bridge[:type], length: bridge[:length] }

        surfaces[id][:edges][identifier] = b
      end
    end

    # Assign thermal bridging heat loss [in W/K] to each deratable surface.
    n_surfaces_to_derate = 0
    surfaces.values.each do |surface|
      next unless surface.has_key?(:edges)
      surface[:heatloss] = 0
      surface[:edges].values.each do |edge|
        surface[:heatloss] += edge[:psi] * edge[:length]
      end
      n_surfaces_to_derate += 1
    end
    #expect(n_surfaces_to_derate).to eq(0) # if "(non thermal bridging)"
    expect(n_surfaces_to_derate).to eq(22) # if "poor (BETBG)"

    # if "poor (BETBG)"
    expect(surfaces["s_floor"   ][:heatloss]).to be_within(0.01).of( 8.800)
    expect(surfaces["s_E_wall"  ][:heatloss]).to be_within(0.01).of( 5.041)
    expect(surfaces["p_E_floor" ][:heatloss]).to be_within(0.01).of(18.650)
    expect(surfaces["s_S_wall"  ][:heatloss]).to be_within(0.01).of( 6.583)
    expect(surfaces["e_W_wall"  ][:heatloss]).to be_within(0.01).of( 6.023) # 6.365
    expect(surfaces["p_N_wall"  ][:heatloss]).to be_within(0.01).of(37.250)
    expect(surfaces["p_S2_wall" ][:heatloss]).to be_within(0.01).of(27.268)
    expect(surfaces["p_S1_wall" ][:heatloss]).to be_within(0.01).of( 7.063)
    expect(surfaces["g_S_wall"  ][:heatloss]).to be_within(0.01).of(56.150)
    expect(surfaces["p_floor"   ][:heatloss]).to be_within(0.01).of(10.000)
    expect(surfaces["p_W1_floor"][:heatloss]).to be_within(0.01).of(13.775)
    expect(surfaces["e_N_wall"  ][:heatloss]).to be_within(0.01).of( 4.727) # 5.639
    expect(surfaces["s_N_wall"  ][:heatloss]).to be_within(0.01).of( 6.583)
    expect(surfaces["g_E_wall"  ][:heatloss]).to be_within(0.01).of(18.195)
    expect(surfaces["e_S_wall"  ][:heatloss]).to be_within(0.01).of( 7.703) # 8.615
    expect(surfaces["e_top"     ][:heatloss]).to be_within(0.01).of( 4.400)
    expect(surfaces["s_W_wall"  ][:heatloss]).to be_within(0.01).of( 5.670)
    expect(surfaces["e_E_wall"  ][:heatloss]).to be_within(0.01).of( 6.023) # 6.365
    expect(surfaces["e_floor"   ][:heatloss]).to be_within(0.01).of( 8.007) # 5.500
    expect(surfaces["g_W_wall"  ][:heatloss]).to be_within(0.01).of(18.195)
    expect(surfaces["g_N_wall"  ][:heatloss]).to be_within(0.01).of(54.255)
    expect(surfaces["p_W2_floor"][:heatloss]).to be_within(0.01).of(13.729)

    # if "(non thermal bridging)""
    # expect(surfaces["s_floor"   ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["s_E_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["p_E_floor" ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["s_S_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["e_W_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["p_N_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["p_S2_wall" ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["p_S1_wall" ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["g_S_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["p_floor"   ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["p_W1_floor"].has_key?(:heatloss)).to be(false)
    # expect(surfaces["e_N_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["s_N_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["g_E_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["e_S_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["e_top"     ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["s_W_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["e_E_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["e_floor"   ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["g_W_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["g_N_wall"  ].has_key?(:heatloss)).to be(false)
    # expect(surfaces["p_W2_floor"].has_key?(:heatloss)).to be(false)

    #ceiling_c   = defaults.roofCeilingConstruction.get.to_Construction.get
    #wall_c      = defaults.wallConstruction.get.to_Construction.get
    #floor_c     = defaults.floorConstruction.get.to_Construction.get


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
        # constructions are unique to each surface) and the suffix " c tbd".
        unless m.nil?
          c.setLayer(index, m)
          c.setName("#{id} c tbd")
          s.setConstruction(c)

          # If derated surface construction separates 2x spaces, then derate
          # adjacent surface construction as well.
          if s.outsideBoundaryCondition.downcase == "space"
            expect(s.adjacentSurface.empty?).to be(false)
            adjacent = s.adjacentSurface.get
            i = adjacent.nameString
            if surfaces.has_key?(i)
              indx = surfaces[i][:index]
              c_c = surface[:construction]
              cc = c_c.clone(os_model).to_Construction.get
              cc.setLayer(indx, m)
              cc.setName("#{i} c tbd")
              adjacent.setConstruction(cc)
            end
          end
        end
      end
    end

    # testing
    floors.each do |id, floor|
      next unless floor.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    # testing
    ceilings.each do |id, ceiling|
      next unless ceiling.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    # testing
    walls.each do |id, wall|
      next unless wall.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

  end # can process thermal bridging and derating : LoScrigno

  it "can process TB & D : DOE Prototype test_smalloffice.osm" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_smalloffice.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "poor (BETBG)"
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, gen_kiva)
    expect(surfaces.size).to eq(43)

    # testing
    surfaces.each do |id, surface|
      next unless surface.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end
  end

  it "can process TB & D : DOE Prototype test_warehouse.osm" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_warehouse.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "poor (BETBG)"
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(23)

    # testing
    surfaces.each do |id, surface|
      next unless surface.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end
  end

  it "can process TB & D : DOE Prototype test_warehouse.osm + JSON I/O" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_warehouse.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # 1. run the measure with a basic TBD JSON input file, e.g. :
    #    - a custom PSI set, e.g. "compliant" set
    #    - (4x) custom edges, e.g. "bad" :fenestration perimeters between
    #      - "Office Left Wall Window1" & "Office Left Wall"

    # The TBD JSON input file should hold the following:
    # "edges": [
    #  {
    #    "psi": "bad",
    #    "type": "fenestration",
    #    "surfaces": [
    #      "Office Left Wall Window1",
    #      "Office Left Wall"
    #    ]
    #  }
    # ],

    # Despite defining the psi_set as having no thermal bridges, the "compliant"
    # PSI set on file will be considered as the building-wide default set.
    psi_set = "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_warehouse.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(23)

    surfaces.each do |id, surface|
      next unless surface.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")

        next unless name == "Office Left Wall"
        expect(surface[:ratio]).to be_within(0.2).of(-40.5) # -44.1
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end

    # Now mimic the export functionality of the measure
    out = JSON.pretty_generate(io)
    out_path = File.dirname(__FILE__) + "/../json/tbd_warehouse.out.json"
    File.open(out_path, "w") do |out_path|
      out_path.puts out
    end

    # 2. Re-use the exported file as input for another warehouse
    os_model2 = translator.loadModel(path)
    expect(os_model2.empty?).to be(false)
    os_model2 = os_model2.get

    io_path2 = File.dirname(__FILE__) + "/../json/tbd_warehouse.out.json"
    gen_kiva = false
    io2, surfaces = processTBD(os_model2, psi_set, io_path2, schema_path, gen_kiva)
    expect(surfaces.size).to eq(23)

    surfaces.each do |id, surface|
      next unless surface.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")

        next unless name == "Office Left Wall"
        expect(surface[:ratio]).to be_within(0.2).of(-40.4) # -44.1
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end

    # Now mimic (again) the export functionality of the measure
    out2 = JSON.pretty_generate(io2)
    out_path2 = File.dirname(__FILE__) + "/../json/tbd_warehouse2.out.json"
    File.open(out_path2, "w") do |out_path2|
      out_path2.puts out2
    end

    # Both output files should be the same ...
    # cmd = "diff #{out_path} #{out_path2}"
    # expect(system( cmd )).to be(true)
    # expect(FileUtils).to be_identical(out_path, out_path2)
    expect(FileUtils.identical?(out_path, out_path2)).to be(true)
  end

  it "can process TB & D : DOE Prototype test_warehouse.osm + JSON I/O (2)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_warehouse.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # 1. run the measure with a basic TBD JSON input file, e.g. :
    #    - a custom PSI set, e.g. "compliant" set
    #    - (1x) custom edges, e.g. "bad" :fenestration perimeters between
    #      - "Office Left Wall Window1" & "Office Left Wall"
    #      - 1x? this time, with explicit 3D coordinates for shared edge.

    # The TBD JSON input file should hold the following:
    # "edges": [
    #  {
    #    "psi": "bad",
    #    "type": "fenestration",
    #    "surfaces": [
    #      "Office Left Wall Window1",
    #      "Office Left Wall"
    #    ],
    #    "v0x": 0.0,
    #    "v0y": 7.51904930207155,
    #    "v0z": 0.914355407629293,
    #    "v1x": 0.0,
    #    "v1y": 5.38555335093654,
    #    "v1z": 0.914355407629293
    #   }
    # ],

    # Despite defining the psi_set as having no thermal bridges, the "compliant"
    # PSI set on file will be considered as the building-wide default set.
    psi_set = "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_warehouse1.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(23)

    surfaces.each do |id, surface|
      next unless surface.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")

        next unless name == "Office Left Wall"
        expect(surface[:ratio]).to be_within(0.2).of(-35.3) # -39.8
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end

    # Now mimic the export functionality of the measure
    out = JSON.pretty_generate(io)
    out_path = File.dirname(__FILE__) + "/../json/tbd_warehouse1.out.json"
    File.open(out_path, "w") do |out_path|
      out_path.puts out
    end

    # 2. Re-use the exported file as input for another warehouse
    os_model2 = translator.loadModel(path)
    expect(os_model2.empty?).to be(false)
    os_model2 = os_model2.get

    io_path2 = File.dirname(__FILE__) + "/../json/tbd_warehouse1.out.json"
    gen_kiva = false
    io2, surfaces = processTBD(os_model2, psi_set, io_path2, schema_path, gen_kiva)
    expect(surfaces.size).to eq(23)

    surfaces.each do |id, surface|
      next unless surface.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        next unless name == "Office Left Wall"
        expect(surface[:ratio]).to be_within(0.2).of(-35.3) # -39.8

      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end

    # Now mimic (again) the export functionality of the measure
    out2 = JSON.pretty_generate(io2)
    out_path2 = File.dirname(__FILE__) + "/../json/tbd_warehouse3.out.json"
    File.open(out_path2, "w") do |out_path2|
      out_path2.puts out2
    end

    # Both output files should be the same ...
    # cmd = "diff #{out_path} #{out_path2}"
    # expect(system( cmd )).to be(true)
    # expect(FileUtils).to be_identical(out_path, out_path2)
    expect(FileUtils.identical?(out_path, out_path2)).to be(true)
  end

  it "can process TB & D : test_seb.osm" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "poor (BETBG)"
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        #puts "#{name} RSi derated by #{ratio}%"
      else
        if surface[:boundary].downcase == "outdoors"
          expect(surface[:conditioned]).to be(false)
        end
      end
    end
  end

  it "can process TB & D : test_seb.osm (0 W/K per m)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "(non thermal bridging)"
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    # Since all PSI values = 0, we're not expecting any derated surfaces
    surfaces.values.each do |surface|
      expect(surface.has_key?(:ratio)).to be(false)
    end
  end

  it "can process TB & D : test_seb.osm (0 W/K per m) with JSON" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    # As the :building PSI set on file remains "(non thermal bridging)", one should
    # not expect differences in results, i.e. derating shouldn't occur.
    surfaces.values.each do |surface|
      expect(surface.has_key?(:ratio)).to be(false)
    end
  end

  it "can process TB & D : test_seb.osm (0 W/K per m) with JSON (non-0)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n0.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    # The :building PSI set on file "compliant" supersedes the psi_set
    # "(non thermal bridging)", so one should expect differences in results,
    # i.e. derating should occur. The next 2 tests:
    #   1. setting both psi_set & file :building to "compliant"
    #   2. setting psi_set to "compliant" while removing the :building from file
    # ... all 3x cases should yield the same results.
    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        #puts "#{name} RSi derated by #{ratio}%"
        if id == "Level0 Utility 1 Ceiling Plenum AbvClgPlnmWall 5"
          expect(surface[:ratio]).to be_within(0.1).of(-18.1)
        end
        if id == "Utility1 Wall 5"
          expect(surface[:ratio]).to be_within(0.1).of(-23.2) # -26.1
        end
        if id == "Openarea 1 Wall 7"
          expect(surface[:ratio]).to be_within(0.1).of(-13.8) # -17.7
        end
        if id == "Level 0 Entry way  Ceiling Plenum RoofCeiling"
          expect(surface[:ratio]).to be_within(0.1).of(-28.5)
        end
        if id == "Level0 Entry way  Ceiling Plenum AbvClgPlnmWall 4"
          expect(surface[:ratio]).to be_within(0.1).of(-20.7)
        end
        if id == "Level 0 Open area 1 Ceiling Plenum RoofCeiling"
          expect(surface[:ratio]).to be_within(0.1).of(-20.4)
        end
      else
        if surface[:boundary].downcase == "outdoors"
          expect(surface[:conditioned]).to be(false)
        end
      end
    end
  end

  it "can process TB & D : test_seb.osm (0 W/K per m) with JSON (non-0) 2" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    #   1. setting both psi_set & file :building to "compliant"
    psi_set = "compliant" # instead of "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n0.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        #ratio  = format "%3.1f", surface[:ratio]
        #name   = id.rjust(15, " ")
        #puts "#{name} RSi derated by #{ratio}%"
        if id == "Level0 Utility 1 Ceiling Plenum AbvClgPlnmWall 5"
          expect(surface[:ratio]).to be_within(0.1).of(-18.1)
        end
        if id == "Utility1 Wall 5"
          expect(surface[:ratio]).to be_within(0.1).of(-23.2) # -26.1
        end
        if id == "Openarea 1 Wall 7"
          expect(surface[:ratio]).to be_within(0.1).of(-13.8) # -17.7
        end
        if id == "Level 0 Entry way  Ceiling Plenum RoofCeiling"
          expect(surface[:ratio]).to be_within(0.1).of(-28.5)
        end
        if id == "Level0 Entry way  Ceiling Plenum AbvClgPlnmWall 4"
          expect(surface[:ratio]).to be_within(0.1).of(-20.7)
        end
        if id == "Level 0 Open area 1 Ceiling Plenum RoofCeiling"
          expect(surface[:ratio]).to be_within(0.1).of(-20.4)
        end
      else
        if surface[:boundary].downcase == "outdoors"
          expect(surface[:conditioned]).to be(false)
        end
      end
    end
  end

  it "can process TB & D : test_seb.osm (0 W/K per m) with JSON (non-0) 3" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    #   2. setting psi_set to "compliant" while removing the :building from file
    psi_set = "compliant" # instead of "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n1.json" # no :building
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        #ratio  = format "%3.1f", surface[:ratio]
        #name   = id.rjust(15, " ")
        #puts "#{name} RSi derated by #{ratio}%"
        if id == "Level0 Utility 1 Ceiling Plenum AbvClgPlnmWall 5"
          expect(surface[:ratio]).to be_within(0.1).of(-18.1)
        end
        if id == "Utility1 Wall 5"
          expect(surface[:ratio]).to be_within(0.1).of(-23.2) # -26.1
        end
        if id == "Openarea 1 Wall 7"
          expect(surface[:ratio]).to be_within(0.1).of(-13.8) # -17.7
        end
        if id == "Level 0 Entry way  Ceiling Plenum RoofCeiling"
          expect(surface[:ratio]).to be_within(0.1).of(-28.5)
        end
        if id == "Level0 Entry way  Ceiling Plenum AbvClgPlnmWall 4"
          expect(surface[:ratio]).to be_within(0.1).of(-20.7)
        end
        if id == "Level 0 Open area 1 Ceiling Plenum RoofCeiling"
          expect(surface[:ratio]).to be_within(0.1).of(-20.4)
        end
      else
        if surface[:boundary].downcase == "outdoors"
          expect(surface[:conditioned]).to be(false)
        end
      end
    end
  end

  it "can process TB & D : testing JSON surface KHI entries" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n2.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    # As the :building PSI set on file remains "(non thermal bridging)", one should
    # not expect differences in results, i.e. derating shouldn't occur. However,
    # the JSON file holds KHI entries for "Entryway  Wall 2" :
    # 3x "columns" @0.5 W/K + 4x supports @0.5W/K = 3.5 W/K
    surfaces.values.each do |surface|
      next unless surface.has_key?(:ratio)
      expect(surface[:heatloss]).to be_within(0.01).of(3.5)
    end
  end

  it "can process TB & D : testing JSON surface KHI & PSI entries" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "(non thermal bridging)" # no :building PSI set on file
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n3.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)
    expect(io.has_key?(:building)).to be(true) # despite no being on file - good
    expect(io[:building].first.has_key?(:psi)).to be(true)
    expect(io[:building].first[:psi]).to eq("(non thermal bridging)")

    # As the :building PSI set on file remains "(non thermal bridging)", one should
    # not expect differences in results, i.e. derating shouldn't occur for most
    # surfaces. However, the JSON file holds KHI entries for "Entryway  Wall 5":
    # 3x "columns" @0.5 W/K + 4x supports @0.5W/K = 3.5 W/K (as in case above),
    # and a "good" PSI set (:parapet, of 0.5 W/K per m).
    surfaces.each do |id, surface|
      next unless surface.has_key?(:ratio)
      expect(id).to eq("Entryway  Wall 5")
      expect(surface[:heatloss]).to be_within(0.01).of(5.3) # 3.5 + (3.6m x 0.5)
    end

    expect(io.has_key?(:edges)).to be(true)
    expect(io[:edges].size).to eq(1)
    io[:edges].each do |edge|
      expect(edge.has_key?(:psi)).to be(true)
      expect(edge.has_key?(:type)).to be(true)
      expect(edge.has_key?(:length)).to be(true)
      expect(edge.has_key?(:surfaces)).to be(true)

      p = edge[:psi]
      t = edge[:type]
      s = {}
      io[:psis].each do |set| s = set if set[:id] == p; end
      expect(s[t]).to be_within(0.01).of(0.5)
      expect(t).to eq(:parapet)
      expect(edge[:length]).to be_within(0.01).of(3.6)
      expect(edge[:surfaces].class).to eq(Array)
    end

    out = JSON.pretty_generate(io)
    out_path = File.dirname(__FILE__) + "/../json/tbd_seb_n3.out.json"
    File.open(out_path, "w") do |out_path|
      out_path.puts out
    end
  end

  it "can process TB & D : JSON surface KHI & PSI entries + building & edge" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n4.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    # As the :building PSI set on file == "(non thermal bridgin)", derating
    # shouldn't occur at large. However, the JSON file holds a custom edge
    # entry for "Entryway  Wall 5" : "bad" fenestration permieters, which
    # only derates the host wall itself
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      expect(surface.has_key?(:ratio)).to be(false) unless id == "Entryway  Wall 5"
      next unless id == "Entryway  Wall 5"
      expect(surface[:heatloss]).to be_within(0.01).of(8.89)
    end
  end

  it "can process TB & D : JSON surface KHI & PSI entries + building & edge (2)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n5.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    # As above, yet the KHI points are now set @0.5 W/K per m (instead of 0)
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      expect(surface.has_key?(:ratio)).to be(false) unless id == "Entryway  Wall 5"
      next unless id == "Entryway  Wall 5"
      expect(surface[:heatloss]).to be_within(0.01).of(12.39)
    end
  end

  it "can process TB & D : JSON surface KHI & PSI entries + building & edge (3)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "(non thermal bridging)"
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n6.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    # As above, with a "good" surface PSI set
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      expect(surface.has_key?(:ratio)).to be(false) unless id == "Entryway  Wall 5"
      next unless id == "Entryway  Wall 5"
      expect(surface[:heatloss]).to be_within(0.01).of(14.18)  # 12.39 + 5.04
    end
  end

  it "can process TB & D : JSON surface KHI & PSI entries + building & edge (4)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "compliant" # ignored - superseded by :building PSI set on file
    io_path = File.dirname(__FILE__) + "/../json/tbd_seb_n7.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    # In the JSON file, the "Entry way 1" space "compliant" PSI set supersedes
    # the default :building PSI set "(non thermal bridging)". And hence the 3x
    # walls below (4, 5 & 6) - opaque envelope surfaces part of "Entry way 1" -
    # will be derated. Exceptionally, Wall 5 has (in addition to a handful of
    # point conductances) derating edges based on the "good" PSI set. Finally,
    # any edges between Wall 5 and its "Sub Surface 8" have their types
    # overwritten (from :fenestration to :balcony), i.e. 0.8 W/K per m instead
    # of 0.35. The latter is a weird one, but illustrates the basic
    # functionality. A more realistic override: a switch between :corner to
    # :fenestration (or vice versa) for corner windows, for instance.
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      if id == "Entryway  Wall 5" ||
         id == "Entryway  Wall 6" ||
         id == "Entryway  Wall 4"
        expect(surface.has_key?(:ratio)).to be(true)
      else
        expect(surface.has_key?(:ratio)).to be(false)
      end
      next unless id == "Entryway  Wall 5"
      expect(surface[:heatloss]).to be_within(0.01).of(12.51) # 13.6
    end

    out = JSON.pretty_generate(io)
    out_path = File.dirname(__FILE__) + "/../json/tbd_seb_n7.out.json"
    File.open(out_path, "w") do |out_path|
      out_path.puts out
    end
  end

  it "can factor in negative PSI values (JSON input)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_warehouse.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "compliant" # ignored - superseded by :building PSI set on file
    io_path = File.dirname(__FILE__) + "/../json/tbd_warehouse4.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(23)

    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      next unless surface.has_key?(:ratio)
      expect surface.has_key?(:heatloss)

      # Ratios are typically negative e.g., a steel corner column decreasing
      # linked surface RSi values. In some cases, a corner PSI can be negative
      # (and thus increasing linked surface RSi values). This happens when
      # estimating PSI values for convex corners while relying on an interior
      # dimensioning convention e.g., BETBG Detail 7.6.2, ISO 14683.
      expect(surface[:ratio]).to be_within(0.01).of(0.15) if id == "Fine Storage Office Front Wall"
      expect(surface[:ratio]).to be_within(0.01).of(0.55) if id == "Office Left Wall"
      expect(surface[:ratio]).to be_within(0.01).of(0.43) if id == "Fine Storage Office Left Wall"
      expect(surface[:ratio]).to be_within(0.01).of(0.18) if id == "Office Front Wall"
      expect(surface[:ratio]).to be_within(0.01).of(0.13) if id == "Fine Storage Right Wall"
      expect(surface[:ratio]).to be_within(0.01).of(0.04) if id == "Bulk Storage Right Wall"
      expect(surface[:ratio]).to be_within(0.01).of(0.12) if id == "Bulk Storage Rear Wall"
      expect(surface[:ratio]).to be_within(0.01).of(0.20) if id == "Fine Storage Front Wall"
      expect(surface[:ratio]).to be_within(0.01).of(0.04) if id == "Bulk Storage Left Wall"

      # In such cases, negative heatloss means heat gained.
      expect(surface[:heatloss]).to be_within(0.01).of(-0.10) if id == "Fine Storage Office Front Wall"
      expect(surface[:heatloss]).to be_within(0.01).of(-0.10) if id == "Office Left Wall"
      expect(surface[:heatloss]).to be_within(0.01).of(-0.10) if id == "Fine Storage Office Left Wall"
      expect(surface[:heatloss]).to be_within(0.01).of(-0.10) if id == "Office Front Wall"
      expect(surface[:heatloss]).to be_within(0.01).of(-0.20) if id == "Fine Storage Right Wall"
      expect(surface[:heatloss]).to be_within(0.01).of(-0.20) if id == "Bulk Storage Right Wall"
      expect(surface[:heatloss]).to be_within(0.01).of(-0.40) if id == "Bulk Storage Rear Wall"
      expect(surface[:heatloss]).to be_within(0.01).of(-0.20) if id == "Fine Storage Front Wall"
      expect(surface[:heatloss]).to be_within(0.01).of(-0.20) if id == "Bulk Storage Left Wall"

      # The results above have been validated.
    end

    out = JSON.pretty_generate(io)
    out_path = File.dirname(__FILE__) + "/../json/tbd_warehouse4.out.json"
    File.open(out_path, "w") do |out_path|
      out_path.puts out
    end
  end

  it "can process TB & D : JSON file read/validate" do
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    expect(File.exist?(schema_path)).to be(true)
    schema_c = File.read(schema_path)
    schema = JSON.parse(schema_c, symbolize_names: true)

    io_path = File.dirname(__FILE__) + "/../json/tbd_json_test.json"
    io_c = File.read(io_path)
    io = JSON.parse(io_c, symbolize_names: true)

    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(io.has_key?(:description)).to be(true)
    expect(io.has_key?(:schema)).to be(true)
    expect(io.has_key?(:edges)).to be(true)
    expect(io.has_key?(:surfaces)).to be(true)
    expect(io.has_key?(:spaces)).to be(false)
    expect(io.has_key?(:spacetypes)).to be(false)
    expect(io.has_key?(:stories)).to be(false)
    expect(io.has_key?(:building)).to be(true)
    expect(io.has_key?(:logs)).to be(false)
    expect(io[:edges].size).to eq(1)
    expect(io[:surfaces].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    expect(io.has_key?(:psis)).to be(true)
    io[:psis].each do |p| psi.append(p); end
    expect(psi.set.size).to eq(7)
    expect(psi.set.has_key?("poor (BETBG)")).to be(true)
    expect(psi.set.has_key?("regular (BETBG)")).to be(true)
    expect(psi.set.has_key?("efficient (BETBG)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(non thermal bridging)")).to be(true)
    expect(psi.set.has_key?("good")).to be(true)
    expect(psi.set.has_key?("compliant")).to be(true)

    # Similar treatment for khis
    khi = KHI.new
    expect(io.has_key?(:khis)).to be(true)
    io[:khis].each do |k| khi.append(k); end
    expect(khi.point.size).to eq(7)
    expect(khi.point.has_key?("poor (BETBG)")).to be(true)
    expect(khi.point.has_key?("regular (BETBG)")).to be(true)
    expect(khi.point.has_key?("efficient (BETBG)")).to be(true)
    expect(khi.point.has_key?("code (Quebec)")).to be(true)
    expect(khi.point.has_key?("(non thermal bridging)")).to be(true)
    expect(khi.point.has_key?("column")).to be(true)
    expect(khi.point.has_key?("support")).to be(true)
    expect(khi.point["column"]).to eq(0.5)
    expect(khi.point["support"]).to eq(0.5)

    expect(io.has_key?(:building)).to be(true)
    expect(io[:building].first.has_key?(:psi)).to be(true)
    expect(io[:building].first[:psi]).to eq("compliant")
    expect(psi.set.has_key?(io[:building].first[:psi])).to be(true)

    expect(io.has_key?(:surfaces)).to be(true)
    io[:surfaces].each do |surface|
      expect(surface.has_key?(:id)).to be(true)
      expect(surface[:id]).to eq("front wall")
      expect(surface.has_key?(:psi)).to be(true)
      expect(surface[:psi]).to eq("good")
      expect(psi.set.has_key?(surface[:psi])).to be(true)

      expect(surface.has_key?(:khis)).to be(true)
      expect(surface[:khis].size).to eq(2)
      surface[:khis].each do |k|
        expect(k.has_key?(:id)).to be(true)
        expect(khi.point.has_key?(k[:id])).to be(true)
        expect(k[:count]).to eq(3) if k[:id] == "column"
        expect(k[:count]).to eq(4) if k[:id] == "support"
      end
    end

    expect(io.has_key?(:edges)).to be(true)
    io[:edges].each do |edge|
      expect(edge.has_key?(:psi)).to be(true)
      expect(edge[:psi]).to eq("compliant")
      expect(psi.set.has_key?(edge[:psi])).to be(true)
      expect(edge.has_key?(:surfaces)).to be(true)
      edge[:surfaces].each do |surface|
        expect(surface).to eq("front wall")
      end
    end

    # a reminder that built-in KHIs are not frozen ...
    khi.point["code (Quebec)"] = 2.0
    expect(khi.point["code (Quebec)"]).to eq(2.0)

    # Load PSI combo JSON example - likely the most expected or common use
    io_path = File.dirname(__FILE__) + "/../json/tbd_PSI_combo.json"
    io_c = File.read(io_path)
    io = JSON.parse(io_c, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(io.has_key?(:description)).to be(true)
    expect(io.has_key?(:schema)).to be(true)
    expect(io.has_key?(:edges)).to be(false)
    expect(io.has_key?(:surfaces)).to be(false)
    expect(io.has_key?(:spaces)).to be(true)
    expect(io.has_key?(:spacetypes)).to be(false)
    expect(io.has_key?(:stories)).to be(false)
    expect(io.has_key?(:building)).to be(true)
    expect(io.has_key?(:logs)).to be(false)
    expect(io[:spaces].size).to eq(1)
    expect(io[:building].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    expect(io.has_key?(:psis)).to be(true)
    io[:psis].each do |p| psi.append(p); end
    expect(psi.set.size).to eq(7)
    expect(psi.set.has_key?("poor (BETBG)")).to be(true)
    expect(psi.set.has_key?("regular (BETBG)")).to be(true)
    expect(psi.set.has_key?("efficient (BETBG)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(non thermal bridging)")).to be(true)
    expect(psi.set.has_key?("OK")).to be(true)
    expect(psi.set.has_key?("Awesome")).to be(true)
    expect(psi.set["Awesome"][:rimjoist]).to eq(0.2)

    expect(io.has_key?(:building)).to be (true)
    expect(io[:building].first.has_key?(:psi)).to be(true)
    expect(io[:building].first[:psi]).to eq("Awesome")
    expect(psi.set.has_key?(io[:building].first[:psi])).to be(true)

    expect(io.has_key?(:spaces)).to be(true)
    io[:spaces].each do |space|
      expect(space.has_key?(:psi)).to be(true)
      expect(space[:id]).to eq("ground-floor restaurant")
      expect(space[:psi]).to eq("OK")
      expect(psi.set.has_key?(space[:psi])).to be(true)
    end

    # Load PSI combo2 JSON example - a more elaborate example, yet common.
    # Post-JSON validation required to handle case sensitive keys & value
    # strings (e.g. "ok" vs "OK" in the file)
    io_path = File.dirname(__FILE__) + "/../json/tbd_PSI_combo2.json"
    io_c = File.read(io_path)
    io = JSON.parse(io_c, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(io.has_key?(:description)).to be(true)
    expect(io.has_key?(:schema)).to be(true)
    expect(io.has_key?(:edges)).to be(true)
    expect(io.has_key?(:surfaces)).to be(true)
    expect(io.has_key?(:spaces)).to be(false)
    expect(io.has_key?(:spacetypes)).to be(false)
    expect(io.has_key?(:stories)).to be(false)
    expect(io.has_key?(:building)).to be(true)
    expect(io.has_key?(:logs)).to be(false)
    expect(io[:edges].size).to eq(1)
    expect(io[:surfaces].size).to eq(1)
    expect(io[:building].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    expect(io.has_key?(:psis)).to be(true)
    io[:psis].each do |p| psi.append(p); end
    expect(psi.set.size).to eq(8)
    expect(psi.set.has_key?("poor (BETBG)")).to be(true)
    expect(psi.set.has_key?("regular (BETBG)")).to be(true)
    expect(psi.set.has_key?("efficient (BETBG)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(non thermal bridging)")).to be(true)
    expect(psi.set.has_key?("OK")).to be(true)
    expect(psi.set.has_key?("Awesome")).to be(true)
    expect(psi.set.has_key?("Party wall edge")).to be(true)
    expect(psi.set["Party wall edge"][:party]).to eq(0.4)

    expect(io.has_key?(:building)).to be(true)
    expect(io[:building].first.has_key?(:psi)).to be(true)
    expect(io[:building].first[:psi]).to eq("Awesome")
    expect(psi.set.has_key?(io[:building].first[:psi])).to be(true)

    expect(io.has_key?(:surfaces)).to be(true)
    io[:surfaces].each do |surface|
      expect(surface.has_key?(:id)).to be(true)
      expect(surface[:id]).to eq("ground-floor restaurant South-wall")
      expect(surface.has_key?(:psi)).to be(true)
      expect(surface[:psi]).to eq("ok")
      expect(psi.set.has_key?(surface[:psi])).to be(false)
    end

    expect(io.has_key?(:edges)).to be(true)
    io[:edges].each do |edge|
      expect(edge.has_key?(:psi)).to be(true)
      expect(edge[:psi]).to eq("Party wall edge")
      expect(edge.has_key?(:type)).to be(true)
      expect(edge[:type]).to eq("party")
      expect(psi.set.has_key?(edge[:psi])).to be(true)
      expect(psi.set[edge[:psi]].has_key?(:party)).to be(true)
      expect(edge.has_key?(:surfaces)).to be(true)
      edge[:surfaces].each do |surface|
        answer = false
        answer = true if surface == "ground-floor restaurant West-wall" ||
                                    "ground-floor restaurant party wall"
        expect(answer).to be(true)
      end
    end

    # Load full PSI JSON example - with duplicate keys for "party"
    # "JSON Schema Lint" * will recognize the duplicate and - as with duplicate
    # Ruby hash keys - will have the second entry ("party": 0.8) override the
    # first ("party": 0.7). Another reminder of post-JSON validation.
    # * https://jsonschemalint.com/#!/version/draft-04/markup/json
    io_path = File.dirname(__FILE__) + "/../json/tbd_full_PSI.json"
    io_c = File.read(io_path)
    io = JSON.parse(io_c, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(io.has_key?(:description)).to be(true)
    expect(io.has_key?(:schema)).to be(true)
    expect(io.has_key?(:edges)).to be(false)
    expect(io.has_key?(:surfaces)).to be(false)
    expect(io.has_key?(:spaces)).to be(false)
    expect(io.has_key?(:spacetypes)).to be(false)
    expect(io.has_key?(:stories)).to be(false)
    expect(io.has_key?(:building)).to be(false)
    expect(io.has_key?(:logs)).to be(false)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    expect(io.has_key?(:psis)).to be(true)
    io[:psis].each do |p| psi.append(p); end
    expect(psi.set.size).to eq(6)
    expect(psi.set.has_key?("poor (BETBG)")).to be(true)
    expect(psi.set.has_key?("regular (BETBG)")).to be(true)
    expect(psi.set.has_key?("efficient (BETBG)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(non thermal bridging)")).to be(true)
    expect(psi.set.has_key?("OK")).to be(true)
    expect(psi.set["OK"][:party]).to eq(0.8)

    # Load minimal PSI JSON example
    io_path = File.dirname(__FILE__) + "/../json/tbd_minimal_PSI.json"
    io_c = File.read(io_path)
    io = JSON.parse(io_c, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)

    # Load minimal KHI JSON example
    io_path = File.dirname(__FILE__) + "/../json/tbd_minimal_KHI.json"
    io_c = File.read(io_path)
    io = JSON.parse(io_c, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(JSON::Validator.validate(schema_path, io_path, uri: true)).to be(true)
  end

  it "can factor in spacetype-specific PSI sets (JSON input)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_warehouse.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "compliant" # ignored - superseded by :building PSI set on file
    io_path = File.dirname(__FILE__) + "/../json/tbd_warehouse5.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(23)

    expect(io.has_key?(:spacetypes)).to be(true)
    io[:spacetypes].each do |spacetype|
      expect(spacetype.has_key?(:id)).to be(true)
      expect(spacetype[:id]).to eq("Warehouse Office")
      expect(spacetype.has_key?(:psi)).to be(true)
    end

    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      next unless surface.has_key?(:ratio)
      expect(surface.has_key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
      expect(surface.has_key?(:space)).to be(true)
      next unless surface[:space].nameString == "Zone1 Office"

      expect(heatloss).to be_within(0.01).of(8.23) if id == "Office Left Wall" # 10.7
      expect(heatloss).to be_within(0.01).of(13.12) if id == "Office Front Wall" # 20.35
    end
  end

  it "can factor in story-specific PSI sets (JSON input)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_smalloffice.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "compliant" # ignored - superseded by :building PSI set on file
    io_path = File.dirname(__FILE__) + "/../json/tbd_smalloffice.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false

    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(43)

    expect(io.has_key?(:stories)).to be(true)
    io[:stories].each do |story|
      expect(story.has_key?(:id)).to be(true)
      expect(story[:id]).to eq("Building Story 1")
      expect(story.has_key?(:psi)).to be(true)
    end

    surfaces.each do |id, surface|
      next unless surface.has_key?(:ratio)
      expect(surface.has_key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
      next unless surface.has_key?(:story)
      expect(surface[:story].nameString).to eq("Building Story 1")

      #expect(heatloss).to be_within(0.01).of(31.41) if id == "Perimeter_ZN_1_wall_south"
      #expect(heatloss).to be_within(0.01).of(20.05) if id == "Perimeter_ZN_2_wall_east"
      #expect(heatloss).to be_within(0.01).of(29.61) if id == "Perimeter_ZN_3_wall_north"
      #expect(heatloss).to be_within(0.01).of(20.05) if id == "Perimeter_ZN_4_wall_west"
    end
  end

  it "can factor in unenclosed space such as attics" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_smalloffice.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    expect(airLoopsHVAC?(os_model)).to be(true)
    expect(winterDesignDayTemperatureSetpoints?(os_model)).to be(true)
    expect(summerDesignDayTemperatureSetpoints?(os_model)).to be(true)

    psi_set = "compliant" # ignored - superseded by :building PSI set on file
    io_path = File.dirname(__FILE__) + "/../json/tbd_smalloffice.json"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = false

    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(43)

    # Check derating of attic floor (5x surfaces)
    os_model.getSpaces.each do |space|
      next unless space.nameString == "Attic"
      expect(space.thermalZone.empty?).to be(false)
      zone = space.thermalZone.get
      expect(zone.isPlenum).to be(false)
      expect(zone.canBePlenum).to be(true)
      space.surfaces.each do |s|
        id = s.nameString
        expect(surfaces.has_key?(id)).to be(true)
        expect(surfaces[id].has_key?(:space)).to be(true)
        next unless surfaces[id][:space].nameString == "Attic"
        expect(surfaces[id][:conditioned]).to be(false)
        next if surfaces[id][:boundary] == "Outdoors"
        expect(s.adjacentSurface.empty?).to be(false)
        adjacent = s.adjacentSurface.get.nameString
        expect(surfaces.has_key?(adjacent)).to be(true)
        expect(surfaces[id][:boundary]).to eq(adjacent)
        expect(surfaces[adjacent][:conditioned]).to be(true)
        #puts surfaces[adjacent].keys if adjacent == "Perimeter_ZN_2_ceiling"
        # expect(surfaces[adjacent].has_key?(:heatloss)).to be(true)
        #if surfaces[id][:boundary].include?("Core")
        #  puts "core #{id} : adjacent = #{adjacent}"
        #else
        #  puts "not core #{id} : adjacent = #{adjacent}"
          #expect(surfaces[id].has_key?(:heatloss)).to be(true)
        #end
      end
    end

    # CHeck derating of outdoor-facing walls
    surfaces.each do |id, surface|
      next unless surface.has_key?(:ratio)
      next if surface[:boundary].downcase == "outdoors"
      puts id if surface.has_key?(:heatloss)
      #heatloss = surface[:heatloss]
      #expect(heatloss.abs).to be > 0
    end

    # CHeck derating of outdoor-facing walls
    surfaces.each do |id, surface|
      next unless surface.has_key?(:ratio)
      next unless surface[:boundary].downcase == "outdoors"
      #puts id if surface.has_key?(:heatloss)
      expect(surface.has_key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
    end
  end

  it "can factor in temperature setpoints" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_smalloffice.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "regular (BETBG)"
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    io, surfaces = processTBD(os_model, psi_set, "", schema_path, false)
    expect(surfaces.size).to eq(43)

    expect(winterDesignDayTemperatureSetpoints?(os_model)).to be(true)
    expect(summerDesignDayTemperatureSetpoints?(os_model)).to be(true)
  end

  it "has a PSI class" do
    psi = PSI.new
    expect(psi.set.has_key?("poor (BETBG)")).to be(true)
    expect(psi.complete?("poor (BETBG)")).to be(true)

    expect(psi.set.has_key?("new set")).to be(false)
    expect(psi.complete?("new set")).to be(false)
    new_set =
    {
      id:           "new set",
      rimjoist:     0.000, #
      parapet:      0.000, #
      fenestration: 0.000, #
      concave:      0.000, #
      convex:       0.000, #
      balcony:      0.000, #
      party:        0.000, #
      grade:        0.000  #
    }
    psi.append(new_set)
    expect(psi.set.has_key?("new set")).to be(true)
    expect(psi.complete?("new set")).to be(true)

    expect(psi.set["new set"][:grade]).to eq(0)
    new_set[:grade] = 1.0
    psi.append(new_set) # does not override existing value
    expect(psi.set["new set"][:grade]).to eq(0)

    expect(psi.set.has_key?("incomplete set")).to be(false)
    expect(psi.complete?("incomplete set")).to be(false)
    incomplete_set =
    {
      id:           "incomplete set",
      grade:        0.000  #
    }
    psi.append(incomplete_set)
    expect(psi.set.has_key?("incomplete set")).to be(true)
    expect(psi.complete?("incomplete set")).to be(false)
  end

  it "can generate and access KIVA inputs (seb)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Set one of the ground-facing surfaces to (Kiva) "Foundation".
    os_model.getSurfaces.each do |s|
      next unless s.nameString == "Entry way  Floor"
      construction = s.construction.get
      s.setOutsideBoundaryCondition("Foundation")
      s.setConstruction(construction)
    end

    # The following materials and foundation objects are provided here as
    # placeholders for future tests.

    # For continuous insulation and/or finishings, OpenStudio/EnergyPlus/Kiva
    # offer 2x solutions : (i) adapt surface construction by adding required
    # insulation and/or finishing layers *, or (ii) add layers as Kiva custom
    # blocks. The former is preferred here. TO DO: sensitivity analysis.

    # * ... only "standard" OS Materials can be used - not "massless" ones.

    # Generic 1-1/2" XPS insulation.
    xps_38mm = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
    xps_38mm.setName("XPS_38mm")
    xps_38mm.setRoughness("Rough")
    xps_38mm.setThickness(0.0381)
    xps_38mm.setConductivity(0.029)
    xps_38mm.setDensity(28)
    xps_38mm.setSpecificHeat(1450)
    xps_38mm.setThermalAbsorptance(0.9)
    xps_38mm.setSolarAbsorptance(0.7)

    # 1. Current code-compliant slab-on-grade (perimeter) solution.
    kiva_slab_2020s = OpenStudio::Model::FoundationKiva.new(os_model)
    kiva_slab_2020s.setName("Kiva slab 2020s")
    kiva_slab_2020s.setInteriorHorizontalInsulationMaterial(xps_38mm)
    kiva_slab_2020s.setInteriorHorizontalInsulationWidth(1.2)
    kiva_slab_2020s.setInteriorVerticalInsulationMaterial(xps_38mm)
    kiva_slab_2020s.setInteriorVerticalInsulationDepth(0.138)

    # 2. Beyond-code slab-on-grade (continuous) insulation setup. Add 1-1/2"
    #    XPS insulation layer (under slab) to surface construction.
    kiva_slab_HP = OpenStudio::Model::FoundationKiva.new(os_model)
    kiva_slab_HP.setName("Kiva slab HP")

    # 3. Do the same for (full height) basements - no insulation under slab for
    #    vintages 1980s & 2020s. Add (full-height) layered insulation and/or
    #    finishing to basement wall construction.
    kiva_basement = OpenStudio::Model::FoundationKiva.new(os_model)
    kiva_basement.setName("Kiva basement")

    # 4. Beyond-code basement slab (perimeter) insulation setup. Add
    #    (full-height)layered insulation and/or finishing to basement wall
    #    construction.
    kiva_basement_HP = OpenStudio::Model::FoundationKiva.new(os_model)
    kiva_basement_HP.setName("Kiva basement HP")
    kiva_basement_HP.setInteriorHorizontalInsulationMaterial(xps_38mm)
    kiva_basement_HP.setInteriorHorizontalInsulationWidth(1.2)
    kiva_basement_HP.setInteriorVerticalInsulationMaterial(xps_38mm)
    kiva_basement_HP.setInteriorVerticalInsulationDepth(0.138)

    # Attach (1) slab-on-grade Kiva foundation object to floor surface.
    os_model.getSurfaces.each do |s|
      next unless s.nameString == "Entry way  Floor"
      s.setAdjacentFoundation(kiva_slab_2020s)
      arg = "TotalExposedPerimeter"
      s.createSurfacePropertyExposedFoundationPerimeter(arg, 6.95)
    end

    os_model.save("os_model_KIVA.osm", true)

    # Now re-open for testing.
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/../os_model_KIVA.osm")
    os_model2 = translator.loadModel(path)
    expect(os_model2.empty?).to be(false)
    os_model2 = os_model2.get

    os_model2.getSurfaces.each do |s|
      next unless s.isGroundSurface
      next unless s.nameString == "Entry way  Floor"
      construction = s.construction.get
      s.setOutsideBoundaryCondition("Foundation")
      s.setConstruction(construction)
    end

    # Set one of the linked outside-facing walls to (Kiva) "Foundation"
    os_model2.getSurfaces.each do |s|
      next unless s.nameString == "Entryway  Wall 4"
      construction = s.construction.get
      s.setOutsideBoundaryCondition("Foundation")
      s.setConstruction(construction)
    end

    kfs = os_model2.getFoundationKivas
    expect(kfs.empty?).to be(false)
    expect(kfs.size).to eq(4)
    # puts os_model2.public_methods.grep(/Kiva/)

    settings = os_model2.getFoundationKivaSettings
    expect(settings.soilConductivity).to be_within(0.01).of(1.73)

    psi_set = "poor (BETBG)"
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = true
    io, surfaces = processTBD(os_model2, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(56)

    surfaces.each do |id, surface|
      next unless surface.has_key?(:foundation) # ... only floors
      next unless surface.has_key?(:kiva) # ... only one here.
      expect(surface[:kiva]).to eq(:basement)
      expect(surface.has_key?(:exposed)).to be (true)
      expect(surface[:exposed]).to be_within(0.01).of(6.95)
    end
  end

  it "can generate and access KIVA inputs (midrise apts - variant)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/midrise_KIVA.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi_set = "poor (BETBG)"
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = true
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(180)

    # Validate.
    surfaces.each do |id, surface|
      next unless surface.has_key?(:foundation) # ... only floors
      next unless surface.has_key?(:kiva)
      expect(surface[:kiva]).to eq(:slab)
      expect(surface.has_key?(:exposed)).to be(true)
      exp = surface[:exposed]

      found = false
      os_model.getSurfaces.each do |s|
        next unless s.nameString == id
        next unless s.outsideBoundaryCondition.downcase == "foundation"
        found = true

        expect(exp).to be_within(0.01).of(3.36) if id == "g Floor C"
      end
      expect(found).to be(true)
    end
  end

  it "can generate multiple KIVA exposed perimeters (midrise apts - variant)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/midrise_KIVA.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Reset all ground-facing floor surfaces as "foundations".
    os_model.getSurfaces.each do |s|
      next unless s.outsideBoundaryCondition.downcase == "ground"
      construction = s.construction.get
      s.setOutsideBoundaryCondition("Foundation")
      s.setConstruction(construction)
    end

    psi_set = "poor (BETBG)"
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = true
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(180)

    # Validate.
    surfaces.each do |id, surface|
      next unless surface.has_key?(:foundation) # only floors
      next unless surface.has_key?(:kiva)
      expect(surface[:kiva]).to eq(:slab)
      expect(surface.has_key?(:exposed)).to be(true)
      exp = surface[:exposed]

      found = false
      os_model.getSurfaces.each do |s|
        next unless s.nameString == id
        next unless s.outsideBoundaryCondition.downcase == "foundation"
        found = true

        expect(exp).to be_within(0.01).of(19.20) if id == "g GFloor NWA"
        expect(exp).to be_within(0.01).of(19.20) if id == "g GFloor NEA"
        expect(exp).to be_within(0.01).of(19.20) if id == "g GFloor SWA"
        expect(exp).to be_within(0.01).of(19.20) if id == "g GFloor SEA"
        expect(exp).to be_within(0.01).of(11.58) if id == "g GFloor S1A"
        expect(exp).to be_within(0.01).of(11.58) if id == "g GFloor S2A"
        expect(exp).to be_within(0.01).of(11.58) if id == "g GFloor N1A"
        expect(exp).to be_within(0.01).of(11.58) if id == "g GFloor N2A"
        expect(exp).to be_within(0.01).of(3.36) if id == "g Floor C"
      end
      expect(found).to be(true)
    end
  end

  it "can generate KIVA exposed perimeters (warehouse)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_warehouse.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Reset all ground-facing floor surfaces as "foundations".
    os_model.getSurfaces.each do |s|
      next unless s.outsideBoundaryCondition.downcase == "ground"
      construction = s.construction.get
      s.setOutsideBoundaryCondition("Foundation")
      s.setConstruction(construction)
    end

    #psi_set = "poor (BETBG)"
    psi_set = "(non thermal bridging)"
    io_path = ""
    schema_path = File.dirname(__FILE__) + "/../tbd.schema.json"
    gen_kiva = true
    io, surfaces = processTBD(os_model, psi_set, io_path, schema_path, gen_kiva)
    expect(surfaces.size).to eq(23)

    # Validate.
    surfaces.each do |id, surface|
      next unless surface.has_key?(:foundation) # only floors
      next unless surface.has_key?(:kiva)
      expect(surface[:kiva]).to eq(:slab)
      expect(surface.has_key?(:exposed)).to be(true)
      exp = surface[:exposed]

      found = false
      os_model.getSurfaces.each do |s|
        next unless s.nameString == id
        next unless s.outsideBoundaryCondition.downcase == "foundation"
        found = true

        expect(exp).to be_within(0.01).of(71.62) if id == "Fine Storage"
        expect(exp).to be_within(0.01).of(35.05) if id == "Office Floor"
        expect(exp).to be_within(0.01).of(185.92) if id == "Bulk Storage"
      end
      expect(found).to be(true)
    end

    os_model.save("warehouse_KIVA.osm", true)

    # Now re-open for testing.
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/../warehouse_KIVA.osm")
    os_model2 = translator.loadModel(path)
    expect(os_model2.empty?).to be(false)
    os_model2 = os_model2.get

    os_model2.getSurfaces.each do |s|
      next unless s.isGroundSurface
      next unless s.nameString == "Fine Storage" ||
                  s.nameString == "Office Storage" ||
                  s.nameString == "Bulk Storage"
      expect(s.outsideBoundaryCondition).to eq("Foundation")
    end

    kfs = os_model2.getFoundationKivas
    expect(kfs.empty?).to be(false)
    expect(kfs.size).to eq(3)
  end
end
