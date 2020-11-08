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


    # 2nd space: plenum (p) with stairwell (s) surfaces
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

    #os_model.save("os_model_test.osm", true)

    # Create the Topolys Model.
    t_model = Topolys::Model.new

    # Fetch OpenStudio (opaque) surfaces & key attributes.
    surfaces = {}
    os_model.getSurfaces.each do |s|
      next if s.space.empty?
      space = s.space.get
      id    = s.nameString

      t, r = transforms(os_model, space)
      n = trueNormal(s, r)

      type = :floor
      type = :ceiling if /ceiling/i.match(s.surfaceType)
      type = :wall if /wall/i.match(s.surfaceType)

      ground   = s.isGroundSurface
      boundary = s.outsideBoundaryCondition
      points   = (t * s.vertices).map{ |v| Topolys::Point3D.new(v.x, v.y, v.z) }
      minz     = (points.map{ |p| p.z }).min

      # Content of the hash will evolve over the next few hundred lines.
      surfaces[id] = {
        type:     type,
        ground:   ground,
        boundary: boundary,
        space:    space,
        gross:    s.grossArea,
        net:      s.netArea,
        points:   points,
        minz:     minz,
        n:        n
      }
    end # (opaque) surfaces populated

    # Fetch OpenStudio subsurfaces & key attributes.
    os_model.getSubSurfaces.each do |s|
      next if s.space.empty?
      next if s.surface.empty?
      space = s.space.get
      dad = s.surface.get.nameString
      id = s.nameString

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
    end # (opaque) surface "dads" populated with subsurface "kids"

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

    # Demo : Shared edges between an (opaque) Topolys face (outer edges) and
    # one of its kids' (holes)' edges are the same Ruby and Topolys objects
    # Good. Care should nonetheless be taken in TBD to avoid derating faces
    # with 'outer' edges shared with their kids.
    # ceilings.values.each do |properties|
    #   if properties.has_key?(:skylights)
    #     properties[:face].outer.edges.each do |e|
    #       puts e.id
    #     end
    #     properties[:face]
    #     properties[:face].holes.each do |h|
    #       h.edges.each do |e|
    #         puts e.id
    #       end
    #     end
    #   end
    # end

    # Loop through Topolys edges and populate TBD edge hash. Initially, there
    # should be a one-to-one correspondence between Topolys and TBD edge
    # objects. TBD edges shared only by non-deratble surfaces (e.g. 2x interior
    # walls, or outer edges of shadng surfaces) will either be removed from the
    # hash, or ignored (on the fence right now). Use Topolys-generated
    # identifiers as unique edge hash keys.
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

    # test edge surface polar angles ...
    # edges.values.each do |edge|
    #   if edge[:surfaces].size > 1
    #     puts "edge of (#{edge[:length]}m) is linked to #{edge[:surfaces].size}:"
    #     edge[:surfaces].each do |i, surface|
    #       puts "... #{i} : #{surface[:angle]}"
    #     end
    #   end
    # end
    expect(edges.size).to eq(89)
    expect(t_model.edges.size).to eq(89)

    # Topolys edges may constitute thermal bridges (and therefore thermally
    # derate linked OpenStudio surfaces), depending on a number of factors such
    # as surface types and boundary conditions. Thermal bridging attributes
    # (type & PSI-value pairs) are grouped into PSI sets, normally accessed
    # through the 'set' user-argument (in the OpenStudio Measure interface).
    psi = PSI.new
    psi_set = psi.set["poor (BC Hydro)"]
    # psi_set = psi.set["(without thermal bridges)"]
    # psi_set = psi.set["code (Quebec)"] # thermal bridging effect less critical

    edges.values.each do |edge|
      next unless edge.has_key?(:surfaces)
      next unless edge[:surfaces].size > 1

      # Skip unless one (at least) linked surface is deratable, i.e.
      # outside-facing floor, ceiling or wall. Ground-facing surfaces
      # are equally processed (up to a point), as the coupling of TBD
      # edges and OpenStudio/EnergyPlus ground-facing surfaces
      # isn't currently enabled, e.g. KIVA ... TO DO.
      deratable = false
      edge[:surfaces].each do |id, surface|
        deratable = true if floors.has_key?(id)
        deratable = true if ceilings.has_key?(id)
        deratable = true if walls.has_key?(id)
      end
      next unless deratable

      psi = {}
      edge[:surfaces].keys.each do |id|
        next unless surfaces.has_key?(id)
        # Skipping the :party wall label for now. Criteria determining party
        # wall edges from TBD edges is to be determined. Most likely scenario
        # seems to be an edge linking only 1x outside-facing or ground-facing
        # surface with only 1x adiabatic surface. Warrants separate tests.
        # TO DO.

        # Label edge as :grade if linked to:
        #   1x ground-facing surface (e.g. slab or wall)
        #   1x outside-facing surface (i.e. normally a wall)
        unless psi.has_key?(:grade)
          edge[:surfaces].keys.each do |i|
            next unless surfaces.has_key?(i)
            next unless surfaces[i][:boundary].downcase == "Outdoors"
            next unless surfaces[id].has_key?(:ground)
            next unless surfaces[id][:ground]
            psi[:grade] = psi_set[:grade]
          end
        end

        # Label edge as :balcony if linked to:
        #   1x floor
        #   1x shade
        unless psi.has_key?(:balcony)
          edge[:surfaces].keys.each do |i|
            next unless shades.has_key?(i)
            next unless floors.has_key?(id)
            psi[:balcony] = psi_set[:balcony]
          end
        end

        # Label edge as :parapet if linked to:
        #   1x outside-facing wall &
        #   1x outside-facing ceiling
        unless psi.has_key?(:parapet)
          edge[:surfaces].keys.each do |i|
            next unless walls.has_key?(i)
            next unless walls[i][:boundary].downcase == "outdoors"
            next unless ceilings.has_key?(id)
            next unless ceilings[id][:boundary].downcase == "outdoors"
            psi[:parapet] = psi_set[:parapet]
          end
        end

        # Repeat for exposed floors vs walls, as :parapet is currently a
        # proxy for intersections between exposed floors & walls
        unless psi.has_key?(:parapet)
          edge[:surfaces].keys.each do |i|
            next unless walls.has_key?(i)
            next unless walls[i][:boundary].downcase == "outdoors"
            next unless floors.has_key?(id)
            next unless floors[id][:boundary].downcase == "outdoors"
            psi[:parapet] = psi_set[:parapet]
          end
        end

        # Repeat for exposed floors vs roofs, as :parapet is currently a
        # proxy for intersections between exposed floors & roofs
        unless psi.has_key?(:parapet)
          edge[:surfaces].keys.each do |i|
            next unless ceilings.has_key?(i)
            next unless ceilings[i][:boundary].downcase == "outdoors"
            next unless floors.has_key?(id)
            next unless floors[id][:boundary].downcase == "outdoors"
            psi[:parapet] = psi_set[:parapet]
          end
        end

        # Label edge as :rimjoist if linked to:
        #   1x outside-facing wall &
        #   1x floor
        unless psi.has_key?(:rimjoist)
          edge[:surfaces].keys.each do |i|
            next unless floors.has_key?(i)
            next unless walls.has_key?(id)
            next unless walls[id][:boundary].downcase == "outdoors"
            psi[:rimjoist] = psi_set[:rimjoist]
          end
        end

        # Label edge as :fenestration if linked to:
        #   1x subsurface
        unless psi.has_key?(:fenestration)
          edge[:surfaces].keys.each do |i|
            next unless holes.has_key?(i)
            psi[:fenestration] = psi_set[:fenestration]
          end
        end

        # Label edge as :concave or :convex (corner) if linked to:
        #   2x outside-facing walls (& relative polar positions of walls)
        unless psi.has_key?(:concave)
          edge[:surfaces].keys.each do |i|
            next if i == id
            next unless walls.has_key?(i)
            next unless walls[i][:boundary].downcase == "outdoors"
            next unless walls.has_key?(id)
            next unless walls[id][:boundary].downcase == "outdoors"

            s1 = edge[:surfaces][id]
            s2 = edge[:surfaces][i]

            angle = s2[:angle] - s1[:angle]
            next unless angle > 0
            next unless (2 * Math::PI - angle).abs > 0
            next if angle > 3 * Math::PI / 4 && angle < 5 * Math::PI / 4

            n1_d_p2 = s1[:normal].dot(s2[:polar])
            p1_d_n2 = s1[:polar].dot(s2[:normal])
            psi[:concave] = psi_set[:concave] if n1_d_p2 > 0 && p1_d_n2 > 0
            psi[:convex]  = psi_set[:convex]  if n1_d_p2 < 0 && p1_d_n2 < 0
          end
        end
      end # edge's surfaces loop

      edge[:psi] = psi unless psi.empty?
    end # edge loop

    n_deratables = 0
    n_edges_at_grade = 0
    n_edges_as_balconies = 0
    n_edges_as_parapets = 0
    n_edges_as_rimjoists = 0
    n_edges_as_fenestrations = 0
    n_edges_as_concave_corners = 0
    n_edges_as_convex_corners = 0
    edges.values.each do |edge|
      if edge.has_key?(:psi)
        n_deratables += 1
        n_edges_at_grade            += 1 if edge[:psi].has_key?(:grade)
        n_edges_as_balconies        += 1 if edge[:psi].has_key?(:balcony)
        n_edges_as_parapets         += 1 if edge[:psi].has_key?(:parapet)
        n_edges_as_rimjoists        += 1 if edge[:psi].has_key?(:rimjoist)
        n_edges_as_fenestrations    += 1 if edge[:psi].has_key?(:fenestration)
        n_edges_as_concave_corners  += 1 if edge[:psi].has_key?(:concave)
        n_edges_as_convex_corners   += 1 if edge[:psi].has_key?(:convex)
      end
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
      next unless psi > 0.01
      bridge = { psi: psi,
                 type: edge[:psi].key(psi),
                 length: edge[:length] }

      # Retrieve valid linked surfaces as deratables.
      deratables = {}
      edge[:surfaces].each do |id, surface|
        next unless surfaces.has_key?(id)
        next unless surfaces[id][:boundary].downcase == "outdoors"
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

      next unless deratables.size > 0

      # Split thermal bridge heat loss equally amongst deratable surfaces.
      bridge[:psi] /= deratables.size

      # Assign heat loss from thermal bridges to surfaces.
      deratables.each do |id, deratable|
        surfaces[id][:edges] = {} unless surfaces[id].has_key?(:edges)
        surfaces[id][:edges][identifier] = bridge
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
    #expect(n_surfaces_to_derate).to eq(0) # if "(without thermal bridges)"
    expect(n_surfaces_to_derate).to eq(22) # if "poor (BC Hydro)"

    # if "poor (BC Hydro)"
    expect(surfaces["s_floor"   ][:heatloss]).to be_within(0.01).of( 8.800)
    expect(surfaces["s_E_wall"  ][:heatloss]).to be_within(0.01).of( 5.041)
    expect(surfaces["p_E_floor" ][:heatloss]).to be_within(0.01).of(18.650)
    expect(surfaces["s_S_wall"  ][:heatloss]).to be_within(0.01).of( 6.583)
    expect(surfaces["e_W_wall"  ][:heatloss]).to be_within(0.01).of( 6.365)
    expect(surfaces["p_N_wall"  ][:heatloss]).to be_within(0.01).of(37.250)
    expect(surfaces["p_S2_wall" ][:heatloss]).to be_within(0.01).of(27.268)
    expect(surfaces["p_S1_wall" ][:heatloss]).to be_within(0.01).of( 7.063)
    expect(surfaces["g_S_wall"  ][:heatloss]).to be_within(0.01).of(56.150)
    expect(surfaces["p_floor"   ][:heatloss]).to be_within(0.01).of(10.000)
    expect(surfaces["p_W1_floor"][:heatloss]).to be_within(0.01).of(13.775)
    expect(surfaces["e_N_wall"  ][:heatloss]).to be_within(0.01).of( 5.639)
    expect(surfaces["s_N_wall"  ][:heatloss]).to be_within(0.01).of( 6.583)
    expect(surfaces["g_E_wall"  ][:heatloss]).to be_within(0.01).of(18.195)
    expect(surfaces["e_S_wall"  ][:heatloss]).to be_within(0.01).of( 8.615)
    expect(surfaces["e_top"     ][:heatloss]).to be_within(0.01).of( 4.400)
    expect(surfaces["s_W_wall"  ][:heatloss]).to be_within(0.01).of( 5.670)
    expect(surfaces["e_E_wall"  ][:heatloss]).to be_within(0.01).of( 6.365)
    expect(surfaces["e_floor"   ][:heatloss]).to be_within(0.01).of( 5.500)
    expect(surfaces["g_W_wall"  ][:heatloss]).to be_within(0.01).of(18.195)
    expect(surfaces["g_N_wall"  ][:heatloss]).to be_within(0.01).of(54.255)
    expect(surfaces["p_W2_floor"][:heatloss]).to be_within(0.01).of(13.729)

    # if "(without thermal bridges)""
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
      next unless surface.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        next if s.space.empty?
        space = s.space.get

        # Retrieve current surface construction.
        current_c = nil
        defaulted = false
        if s.isConstructionDefaulted
          # Check for space default set.
          space_default_set = space.defaultConstructionSet
          unless space_default_set.empty?
            space_default_set = space_default_set.get
            current_c = space_default_set.getDefaultConstruction(s)
            next if current_c.empty?
            current_c = current_c.get
            defaulted = true
          end

          # Check for building default set.
          building_default_set = os_building.defaultConstructionSet
          unless building_default_set.empty? || defaulted
            building_default_set = building_default_set.get
            current_c = building_default_set.getDefaultConstruction(s)
            next if current_c.empty?
            current_c = current_c.get
            defaulted = true
          end

          # No space or building defaults - resort to first set @model level.
          model_default_sets = os_model.getDefaultConstructionSets
          unless model_default_sets.empty? || defaulted
            model_default_set = model_default_sets.first
            current_c = model_default_set.getDefaultConstruction(s)
            next if current_c.empty?
            current_c = current_c.get
            defaulted = true
          end

          next unless defaulted
          construction_name = current_c.nameString
          c = current_c.clone(os_model).to_Construction.get

        else # ... no defaults - surface-specific construction
          current_c = s.construction.get
          construction_name = current_c.nameString
          c = current_c.clone(os_model).to_Construction.get
        end

        # index - of layer/material (to derate) in cloned construction
        # type  - either massless (RSi) or standard (k + d)
        # r     - initial RSi value of the targeted layer to derate
        index, type, r = deratableLayer(c)

        index = nil unless index.is_a?(Numeric) &&
                           index >=0            &&
                           index < c.layers.size

        # m     - newly derated, cloned material
        m = nil
        m = derate(os_model, s, id, surface, c, index, type, r) unless index.nil?

        # "m" may be nilled simply because the targeted construction has already
        # been derated, i.e. holds " tbd" in its name. Names of cloned/derated
        # constructions (due to TBD) include the surface name (since derated
        # constructions are unique to each surface) and the suffix " c tbd".
        unless m.nil?
          c.setLayer(index, m)
          c.setName("#{id} c tbd")
          s.setConstruction(c)
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
end

RSpec.describe TBD do
  it "can process TB & D : DOE Prototype test_smalloffice.osm" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_smalloffice.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi = PSI.new
    psi_set = psi.set["poor (BC Hydro)"]

    # TBD "surfaces" (Hash) holds opaque surfaces (as well as their child
    # subsurfaces) for post-processing, e.g. testing, output to JSON (soon).
    surfaces = processTBD(os_model, psi_set)
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
end

# RSpec.describe TBD do
#   it "can process TB & D : DOE Prototype test_secondaryschool.osm" do
#     translator = OpenStudio::OSVersion::VersionTranslator.new
#     path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_secondaryschool_7.osm")
#     os_model = translator.loadModel(path)
#     expect(os_model.empty?).to be(false)
#     os_model = os_model.get
#
#     psi = PSI.new
#     psi_set = psi.set["efficient (BC Hydro)"]
#     #psi_set = psi.set["(without thermal bridges)"]
#
#
#     # TBD "surfaces" (Hash) holds opaque surfaces (as well as their child
#     # subsurfaces) for post-processing, e.g. testing, output to JSON (soon).
#     surfaces = processTBD(os_model, psi_set)
#     expect(surfaces.size).to eq(326)
#
#     # testing (with)
#     surfaces.each do |id, surface|
#       next unless surface.has_key?(:edges)
#       os_model.getSurfaces.each do |s|
#         next unless id == s.nameString
#         expect(s.isConstructionDefaulted).to be(false)
#         expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
#
#         u = s.uFactor
#         c = s.thermalConductance
#         unless u.empty? || c.empty?
#           u = u.get
#           c = c.get
#           #puts "with, #{id}, #{s.netArea}, #{u}, #{c}"
#         end
#       end
#     end
#
#     # testing (without)
#     surfaces.each do |id, surface|
#       next if surface.has_key?(:edges)
#       os_model.getSurfaces.each do |s|
#         next unless id == s.nameString
#         next unless s.outsideBoundaryCondition.downcase == "outdoors"
#         expect(/ tbd/i.match(s.construction.get.nameString)).to eq(nil)
#
#         u = s.uFactor
#         c = s.thermalConductance
#         unless u.empty? || c.empty?
#           u = u.get
#           c = c.get
#           #puts "without, #{id}, #{s.netArea}, #{u}, #{c}"
#         end
#       end
#     end
#   end
# end

RSpec.describe TBD do
  it "can process TB & D : DOE Prototype test_warehouse.osm" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_warehouse.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi = PSI.new
    psi_set = psi.set["poor (BC Hydro)"]

    # TBD "surfaces" (Hash) holds opaque surfaces (as well as their child
    # subsurfaces) for post-processing, e.g. testing, output to JSON (soon).
    surfaces = processTBD(os_model, psi_set)
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
end

RSpec.describe TBD do
  it "can process TB & D : test_seb.osm" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi = PSI.new
    psi_set = psi.set["poor (BC Hydro)"]

    # TBD "surfaces" (Hash) holds opaque surfaces (as well as their child
    # subsurfaces) for post-processing, e.g. testing, output to JSON (soon).
    surfaces = processTBD(os_model, psi_set)
    expect(surfaces.size).to eq(56)

    surfaces.each do |id, surface|
      if surface.has_key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        #puts "#{name} RSi derated by #{ratio}%"
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end
  end
end

RSpec.describe TBD do
  it "can process TB & D : test_seb.osm (0 W/K per m)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/files/test_seb.osm")
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    psi = PSI.new
    psi_set = psi.set["(without thermal bridges)"]

    # TBD "surfaces" (Hash) holds opaque surfaces (as well as their child
    # subsurfaces) for post-processing, e.g. testing, output to JSON (soon).
    surfaces = processTBD(os_model, psi_set)
    expect(surfaces.size).to eq(56)

    # Since all PSI values = 0, we're not expecting any derated surfaces
    surfaces.values.each do |surface|
      expect(surface.has_key?(:ratio)).to be(false)
    end
  end
end

RSpec.describe TBD do
  it "can process TB & D : JSON file read/validate" do
    tbd_schema =
    {
      "$schema": "http://json-schema.org/draft-04/schema#",
      "id": "https://github.com/rd2/tbd/blob/master/tbd.schema.json",
      "title": "TBD Schema",
      "description": "Schema for Thermal Bridging and Derating",
      "type": "object",
      "properties": {
        "description": {
          "type": "string"
        },
        "schema": {
          "type": "string"
        },
        "psis": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/PSI"
          },
          "uniqueItems": true
        },
        "khis": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/KHI"
          },
          "uniqueItems": true
        },
        "edges": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Edge"
          },
          "uniqueItems": true
        },
        "surfaces": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Surface"
          },
          "uniqueItems": true
        },
        "spaces": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Space"
          },
          "uniqueItems": true
        },
        "stories": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Story"
          },
          "uniqueItems": true
        },
        "unit": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Unit"
          },
          "uniqueItems": true
        },
        "logs": {
          "type": "array",
          "items": {
            "$ref": "#/definitions/Log"
          }
        }
      },
      "additionalProperties": false,
      "definitions": {
        "PSI": {
          "description": "Set of PSI-values (in W/K per m) for thermal bridges",
          "type": "object",
          "properties": {
            "id": {
              "title": "Unique PSI set identifier",
              "type": "string"
            },
            "rimjoist": {
              "title": "Floor/wall edge PSI",
              "type": "number",
              "minimum": 0
            },
            "parapet": {
              "title": "Roof/wall or exposed-floor/wall edge PSI",
              "type": "number",
              "minimum": 0
            },
            "fenestration": {
              "title": "Window, door, skylight perimeter PSI",
              "type": "number",
              "minimum": 0
            },
            "concave": {
              "title": "Wall corner [0°,135°) PSI",
              "type": "number",
              "minimum": 0
            },
            "convex": {
              "title": "Wall corner (225°,360°] PSI",
              "type": "number",
              "minimum": 0
            },
            "balcony": {
              "title": "Floor/balcony edge PSI ",
              "type": "number",
              "minimum": 0
            },
            "party": {
              "title": "Party wall edge PSI",
              "type": "number",
              "minimum": 0
            },
            "grade": {
              "title": "Floor/foundation edge PSI",
              "type": "number",
              "minimum": 0
            }
          },
          "additionalProperties": false,
          "required": [
            "id"
          ],
          "minProperties": 2
        },
        "KHI": {
          "description": "KHI-value (in W/K) for a point thermal bridge",
          "type": "object",
          "properties": {
            "id": {
              "title": "Unique KHI identifier",
              "type": "string"
            },
            "point": {
              "title": "Point KHI-value",
              "type": "number",
              "minimum": 0
            }
          },
          "additionalProperties": false,
          "required": [
            "id",
            "point"
          ]
        },
        "Edge": {
          "description": "Surface(s) edge as thermal bridge",
          "type": "object",
          "properties": {
            "psi": {
              "title": "PSI-set identifier",
              "type": "string"
            },
            "type": {
              "title": "PSI-set type, e.g. 'parapet'",
              "type": "string",
              "enum": [
                "rimjoist",
                "parapet",
                "fenestration",
                "concave",
                "convex",
                "balcony",
                "party",
                "grade"
              ]
            },
            "length": {
              "title": "Edge length (m), 10cm min",
              "type": "number",
              "minimum": 0,
              "exclusiveMinimum": true
            },
            "surfaces": {
              "title": "Surface(s) connected to edge",
              "type": "array",
              "items": {
                "type": "string"
              },
              "minItems": 1,
              "uniqueItems": true
            }
          },
          "additionalProperties": false,
          "required": [
            "psi",
            "type",
            "length",
            "surfaces"
          ]
        },
        "Surface": {
          "description": "Surface default PSI-set (optional)",
          "type": "object",
          "properties": {
            "id": {
              "title": "e.g. OS or E+ surface identifier",
              "type": "string"
            },
            "psi": {
              "title": "PSI-set identifier",
              "type": "string"
            },
            "khis": {
              "title": "Surface-hosted point thermal bridges",
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "id": {
                    "title": "Unique KHI-value identifier",
                    "type": "string"
                  },
                  "count": {
                    "title": "Number of KHI-matching point thermal bridges",
                    "type": "number",
                    "minimum": 1
                  }
                },
                "additionalProperties": false,
                "required": [
                  "id",
                  "count"
                ]
              },
              "uniqueItems": true
            }
          },
          "additionalProperties": false,
          "minProperties": 2,
          "required": [
            "id"
          ]
        },
        "Space": {
          "description": "Space default PSI-set (optional for OS)",
          "type": "object",
          "required": [
            "id",
            "psi"
          ],
          "properties": {
            "id": {
              "title": "e.g. OS space or E+ zone identifier",
              "type": "string"
            },
            "psi": {
              "title": "PSI-set identifier",
              "type": "string"
            }
          },
          "additionalProperties": false
        },
        "Story": {
          "title": "Story default PSI-set (optional for OS)",
          "type": "object",
          "properties": {
            "id": {
              "title": "e.g. OS story identifier",
              "type": "string"
            },
            "psi": {
              "title": "PSI-set identifier",
              "type": "string"
            }
          },
          "additionalProperties": false,
          "required": [
            "id",
            "psi"
          ]
        },
        "Unit": {
          "title": "Building unit default PSI-set (optional for OS)",
          "type": "object",
          "properties": {
            "psi": {
              "title": "PSI-set identifier",
              "type": "string"
            }
          },
          "additionalProperties": false,
          "required": [
            "psi"
          ]
        },
        "Log": {
          "title": "TBD log messages",
          "type": "string"
        }
      }
    }

    tbd_io =
    {
      "schema": "https://github.com/rd2/tbd/blob/master/tbd.schema.json",
      "description": "testing basic JSON validation",
      "psis": [
        {
          "id": "good",
          "parapet": 0.5,
          "party": 0.9
        },
        {
          "id": "compliant",
          "rimjoist": 0.3,
          "parapet": 0.325,
          "fenestration": 0.35,
          "concave": 0.45,
          "convex": 0.45,
          "balcony": 0.5,
          "party": 0.5,
          "grade": 0.45
        }
      ],
      "khis": [
        {
          "id": "column",
          "point": 0.5
        },
        {
          "id": "support",
          "point": 0.5
        }
      ],
      "edges": [
        {
          "psi": "compliant",
          "type": "party",
          "length": 2.5,
          "surfaces": [
            "front wall"
          ]
        }
      ],
      "surfaces": [
        {
          "id": "front wall",
          "khis": [
            {
              "id": "column",
              "count": 3
            },
            {
              "id": "support",
              "count": 4
            }
          ],
          "psi": "good"
        }
      ],
      "unit": [
        {
          "psi": "compliant"
        }
      ]
    }
    # JSON::Validator.validate!(tbd_schema, tbd_o)
    expect(JSON::Validator.validate(tbd_schema, tbd_io)).to be(true)

    # Load TBD JSON schema (same as above, yet on file)
    tbd_schema_f = File.dirname(__FILE__) + "/../tbd.schema.json"
    expect(File.exist?(tbd_schema_f)).to be(true)
    tbd_schema_c = File.read(tbd_schema_f)
    tbd_schema = JSON.parse(tbd_schema_c, symbolize_names: true)
    expect(JSON::Validator.validate(tbd_schema, tbd_io)).to be(true)
    expect(tbd_io.has_key?(:description)).to be(true)
    expect(tbd_io.has_key?(:schema)).to be(true)
    expect(tbd_io.has_key?(:edges)).to be(true)
    expect(tbd_io.has_key?(:surfaces)).to be(true)
    expect(tbd_io.has_key?(:spaces)).to be(false)
    expect(tbd_io.has_key?(:stories)).to be(false)
    expect(tbd_io.has_key?(:unit)).to be(true)
    expect(tbd_io.has_key?(:logs)).to be(false)
    expect(tbd_io[:edges].size).to eq(1)
    expect(tbd_io[:surfaces].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    if tbd_io.has_key?(:psis)
      tbd_io[:psis].each do |p| psi.append(p); end
    end
    expect(psi.set.size).to eq(7)
    expect(psi.set.has_key?("poor (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("regular (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("efficient (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(without thermal bridges)")).to be(true)
    expect(psi.set.has_key?("good")).to be(true)
    expect(psi.set.has_key?("compliant")).to be(true)

    # Similar treatment for khis
    khi = KHI.new
    if tbd_io.has_key?(:khis)
      tbd_io[:khis].each do |k| khi.append(k); end
    end
    expect(khi.point.size).to eq(7)
    expect(khi.point.has_key?("poor (BC Hydro)")).to be(true)
    expect(khi.point.has_key?("regular (BC Hydro)")).to be(true)
    expect(khi.point.has_key?("efficient (BC Hydro)")).to be(true)
    expect(khi.point.has_key?("code (Quebec)")).to be(true)
    expect(khi.point.has_key?("(non thermal bridging)")).to be(true)
    expect(khi.point.has_key?("column")).to be(true)
    expect(khi.point.has_key?("support")).to be(true)
    expect(khi.point["column"]).to eq(0.5)
    expect(khi.point["support"]).to eq(0.5)

    # Internal logic of TBD JSON file content, e.g.
    # referenced psis & khis need to be loaded in memory
    # either built-in TBD defaults or on file.
    if tbd_io.has_key?(:unit)
      # although structured as an array, there can only be one unit per file
      tbd_io[:unit].each do |unit|
        if unit.has_key?(:psi)
          expect(unit[:psi]).to eq("compliant")
          expect(psi.set.has_key?(unit[:psi])).to be(true)
        end
      end
    end
    if tbd_io.has_key?(:surfaces)
      tbd_io[:surfaces].each do |surface|
        expect(surface.has_key?(:id)).to be(true)
        expect(surface[:id]).to eq("front wall") # valid vs OSM ?
        if surface.has_key?(:psi)
          expect(surface[:psi]).to eq("good")
          expect(psi.set.has_key?(surface[:psi])).to be(true)
        end
        if surface.has_key?(:khis)
          expect(surface[:khis].size).to eq(2)
          surface[:khis].each do |k|
            expect(k.has_key?(:id)).to be(true)
            expect(khi.point.has_key?(k[:id])).to be(true)
            expect(k[:count]).to eq(3) if k[:id] == "column"
            expect(k[:count]).to eq(4) if k[:id] == "support"
          end
        end
      end
    end
    if tbd_io.has_key?(:edges)
      tbd_io[:edges].each do |edge|
        if edge.has_key?(:psi)
          expect(edge[:psi]).to eq("compliant")
          expect(psi.set.has_key?(edge[:psi])).to be(true)
          expect(edge.has_key?(:surfaces)).to be(true)
          edge[:surfaces].each do |surface|
            expect(surface).to eq("front wall") # valid vs OSM ?
          end
        end
      end
    end

    # # Load TBD JSON test (same as above, yet on file)
    tbd_io_f = File.dirname(__FILE__) + "/../json/tbd_json_test.json"
    expect(File.exist?(tbd_schema_f)).to be(true)
    tbd_io_c = File.read(tbd_io_f)
    tbd_io = JSON.parse(tbd_io_c, symbolize_names: true)
    expect(JSON::Validator.validate(tbd_schema, tbd_io)).to be(true)
    expect(tbd_io.has_key?(:description)).to be(true)
    expect(tbd_io.has_key?(:schema)).to be(true)
    expect(tbd_io.has_key?(:edges)).to be(true)
    expect(tbd_io.has_key?(:surfaces)).to be(true)
    expect(tbd_io.has_key?(:spaces)).to be(false)
    expect(tbd_io.has_key?(:stories)).to be(false)
    expect(tbd_io.has_key?(:unit)).to be(true)
    expect(tbd_io.has_key?(:logs)).to be(false)
    expect(tbd_io[:edges].size).to eq(1)
    expect(tbd_io[:surfaces].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    if tbd_io.has_key?(:psis)
      tbd_io[:psis].each do |p| psi.append(p); end
    end
    expect(psi.set.size).to eq(7)
    expect(psi.set.has_key?("poor (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("regular (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("efficient (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(without thermal bridges)")).to be(true)
    expect(psi.set.has_key?("good")).to be(true)
    expect(psi.set.has_key?("compliant")).to be(true)

    # Similar treatment for khis
    khi = KHI.new
    if tbd_io.has_key?(:khis)
      tbd_io[:khis].each do |k| khi.append(k); end
    end
    expect(khi.point.size).to eq(7)
    expect(khi.point.has_key?("poor (BC Hydro)")).to be(true)
    expect(khi.point.has_key?("regular (BC Hydro)")).to be(true)
    expect(khi.point.has_key?("efficient (BC Hydro)")).to be(true)
    expect(khi.point.has_key?("code (Quebec)")).to be(true)
    expect(khi.point.has_key?("(non thermal bridging)")).to be(true)
    expect(khi.point.has_key?("column")).to be(true)
    expect(khi.point.has_key?("support")).to be(true)
    expect(khi.point["column"]).to eq(0.5)
    expect(khi.point["support"]).to eq(0.5)

    # Internal logic of TBD JSON file content, e.g.
    # referenced psis & khis need to be loaded in memory
    # either built-in TBD defaults or on file.
    if tbd_io.has_key?(:unit)
      # although structured as an array, there can only be one unit per file
      tbd_io[:unit].each do |unit|
        if unit.has_key?(:psi)
          expect(unit[:psi]).to eq("compliant")
          expect(psi.set.has_key?(unit[:psi])).to be(true)
        end
      end
    end
    if tbd_io.has_key?(:surfaces)
      tbd_io[:surfaces].each do |surface|
        expect(surface.has_key?(:id)).to be(true)
        expect(surface[:id]).to eq("front wall") # valid vs OSM ?
        if surface.has_key?(:psi)
          expect(surface[:psi]).to eq("good")
          expect(psi.set.has_key?(surface[:psi])).to be(true)
        end
        if surface.has_key?(:khis)
          expect(surface[:khis].size).to eq(2)
          surface[:khis].each do |k|
            expect(k.has_key?(:id)).to be(true)
            expect(khi.point.has_key?(k[:id])).to be(true)
            expect(k[:count]).to eq(3) if k[:id] == "column"
            expect(k[:count]).to eq(4) if k[:id] == "support"
          end
        end
      end
    end
    if tbd_io.has_key?(:edges)
      tbd_io[:edges].each do |edge|
        if edge.has_key?(:psi)
          expect(edge[:psi]).to eq("compliant")
          expect(psi.set.has_key?(edge[:psi])).to be(true)
          expect(edge.has_key?(:surfaces)).to be(true)
          edge[:surfaces].each do |surface|
            expect(surface).to eq("front wall") # valid vs OSM ?
          end
        end
      end
    end

    # a reminder that built-in KHIs are not frozen ...
    khi.point["code (Quebec)"] = 2.0
    expect(khi.point["code (Quebec)"]).to eq(2.0)

    # Load PSI combo JSON example - likely the most expected or common use
    tbd_io_f = File.dirname(__FILE__) + "/../json/tbd_PSI_combo.json"
    expect(File.exist?(tbd_schema_f)).to be(true)
    tbd_io_c = File.read(tbd_io_f)
    tbd_io = JSON.parse(tbd_io_c, symbolize_names: true)
    expect(JSON::Validator.validate(tbd_schema, tbd_io)).to be(true)
    expect(tbd_io.has_key?(:description)).to be(true)
    expect(tbd_io.has_key?(:schema)).to be(true)
    expect(tbd_io.has_key?(:edges)).to be(false)
    expect(tbd_io.has_key?(:surfaces)).to be(false)
    expect(tbd_io.has_key?(:spaces)).to be(true)
    expect(tbd_io.has_key?(:stories)).to be(false)
    expect(tbd_io.has_key?(:unit)).to be(true)
    expect(tbd_io.has_key?(:logs)).to be(false)
    expect(tbd_io[:spaces].size).to eq(1)
    expect(tbd_io[:unit].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    if tbd_io.has_key?(:psis)
      tbd_io[:psis].each do |p| psi.append(p); end
    end
    expect(psi.set.size).to eq(7)
    expect(psi.set.has_key?("poor (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("regular (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("efficient (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(without thermal bridges)")).to be(true)
    expect(psi.set.has_key?("OK")).to be(true)
    expect(psi.set.has_key?("Awesome")).to be(true)
    expect(psi.set["Awesome"][:rimjoist]).to eq(0.2)

    # Similar treatment for khis
    khi = KHI.new
    if tbd_io.has_key?(:khis)
      tbd_io[:khis].each do |k| khi.append(k); end
    end
    expect(khi.point.size).to eq(5)

    # Internal logic of TBD JSON file content, e.g.
    # referenced psis & khis need to be loaded in memory
    # either built-in TBD defaults or on file.
    if tbd_io.has_key?(:unit)
      # although structured as an array, there can only be one unit per file
      tbd_io[:unit].each do |unit|
        if unit.has_key?(:psi)
          expect(unit[:psi]).to eq("Awesome")
          expect(psi.set.has_key?(unit[:psi])).to be(true)
        end
      end
    end
    if tbd_io.has_key?(:spaces)
      tbd_io[:spaces].each do |space|
        if space.has_key?(:psi)
          expect(space[:id]).to eq("ground-floor restaurant") # valid vs OSM?
          expect(space[:psi]).to eq("OK")
          expect(psi.set.has_key?(space[:psi])).to be(true)
        end
      end
    end

    # Load PSI combo2 JSON example - a more elaborate example, yet common.
    # Post-JSON validation required to handle case sensitive keys & value
    # strings (e.g. "ok" vs "OK" in the file)
    tbd_io_f = File.dirname(__FILE__) + "/../json/tbd_PSI_combo2.json"
    expect(File.exist?(tbd_schema_f)).to be(true)
    tbd_io_c = File.read(tbd_io_f)
    tbd_io = JSON.parse(tbd_io_c, symbolize_names: true)
    expect(JSON::Validator.validate(tbd_schema, tbd_io)).to be(true)
    expect(tbd_io.has_key?(:description)).to be(true)
    expect(tbd_io.has_key?(:schema)).to be(true)
    expect(tbd_io.has_key?(:edges)).to be(true)
    expect(tbd_io.has_key?(:surfaces)).to be(true)
    expect(tbd_io.has_key?(:spaces)).to be(false)
    expect(tbd_io.has_key?(:stories)).to be(false)
    expect(tbd_io.has_key?(:unit)).to be(true)
    expect(tbd_io.has_key?(:logs)).to be(false)
    expect(tbd_io[:edges].size).to eq(1)
    expect(tbd_io[:surfaces].size).to eq(1)
    expect(tbd_io[:unit].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    if tbd_io.has_key?(:psis)
      tbd_io[:psis].each do |p| psi.append(p); end
    end
    expect(psi.set.size).to eq(8)
    expect(psi.set.has_key?("poor (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("regular (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("efficient (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(without thermal bridges)")).to be(true)
    expect(psi.set.has_key?("OK")).to be(true)
    expect(psi.set.has_key?("Awesome")).to be(true)
    expect(psi.set.has_key?("Party wall edge")).to be(true)
    expect(psi.set["Party wall edge"][:party]).to eq(0.4)

    # Similar treatment for khis
    khi = KHI.new
    if tbd_io.has_key?(:khis)
      tbd_io[:khis].each do |k| khi.append(k); end
    end
    expect(khi.point.size).to eq(5)

    # Internal logic of TBD JSON file content, e.g.
    # referenced psis & khis need to be loaded in memory
    # either built-in TBD defaults or on file.
    if tbd_io.has_key?(:unit)
      # although structured as an array, there can only be one unit per file
      tbd_io[:unit].each do |unit|
        if unit.has_key?(:psi)
          expect(unit[:psi]).to eq("Awesome")
          expect(psi.set.has_key?(unit[:psi])).to be(true)
        end
      end
    end
    if tbd_io.has_key?(:surfaces)
      tbd_io[:surfaces].each do |surface|
        expect(surface.has_key?(:id)).to be(true) # valid vs OSM ?
        expect(surface[:id]).to eq("ground-floor restaurant South-wall")
        if surface.has_key?(:psi)
          expect(surface[:psi]).to eq("ok")
          expect(psi.set.has_key?(surface[:psi])).to be(false) # log mismatch
        end
      end
    end
    if tbd_io.has_key?(:edges)
      tbd_io[:edges].each do |edge|
        if edge.has_key?(:psi)
          expect(edge[:psi]).to eq("Party wall edge")
          expect(edge[:type]).to eq("party")
          expect(psi.set.has_key?(edge[:psi])).to be(true)
          expect(psi.set[edge[:psi]].has_key?(:party)).to be(true)
          expect(edge.has_key?(:surfaces)).to be(true)
          edge[:surfaces].each do |surface|
            # valid vs OSM ?
            answer = false
            answer = true if surface == "ground-floor restaurant West-wall" ||
                                        "ground-floor restaurant party wall"
            expect(answer).to be(true)
          end
        end
      end
    end

    # Load full PSI JSON example - with duplicate keys for "party"
    # "JSON Schema Lint" * will recognize the duplicate and - as with duplicate
    # Ruby hash keys - will have the second entry ("party": 0.8) override the
    # first ("party": 0.7). Another reminder of post-JSON validation.
    # * https://jsonschemalint.com/#!/version/draft-04/markup/json
    tbd_io_f = File.dirname(__FILE__) + "/../json/tbd_full_PSI.json"
    expect(File.exist?(tbd_schema_f)).to be(true)
    tbd_io_c = File.read(tbd_io_f)
    tbd_io = JSON.parse(tbd_io_c, symbolize_names: true)
    expect(JSON::Validator.validate(tbd_schema, tbd_io)).to be(true)
    expect(tbd_io.has_key?(:description)).to be(true)
    expect(tbd_io.has_key?(:schema)).to be(true)
    expect(tbd_io.has_key?(:edges)).to be(false)
    expect(tbd_io.has_key?(:surfaces)).to be(false)
    expect(tbd_io.has_key?(:spaces)).to be(false)
    expect(tbd_io.has_key?(:stories)).to be(false)
    expect(tbd_io.has_key?(:unit)).to be(false)
    expect(tbd_io.has_key?(:logs)).to be(false)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    if tbd_io.has_key?(:psis)
      tbd_io[:psis].each do |p| psi.append(p); end
    end
    expect(psi.set.size).to eq(6)
    expect(psi.set.has_key?("poor (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("regular (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("efficient (BC Hydro)")).to be(true)
    expect(psi.set.has_key?("code (Quebec)")).to be(true)
    expect(psi.set.has_key?("(without thermal bridges)")).to be(true)
    expect(psi.set.has_key?("OK")).to be(true)
    expect(psi.set["OK"][:party]).to eq(0.8)

    # Similar treatment for khis
    khi = KHI.new
    if tbd_io.has_key?(:khis)
      tbd_io[:khis].each do |k| khi.append(k); end
    end
    expect(khi.point.size).to eq(5)

    # Load minimal PSI JSON example
    tbd_io_f = File.dirname(__FILE__) + "/../json/tbd_minimal_PSI.json"
    expect(File.exist?(tbd_schema_f)).to be(true)
    tbd_io_c = File.read(tbd_io_f)
    tbd_io = JSON.parse(tbd_io_c, symbolize_names: true)
    expect(JSON::Validator.validate(tbd_schema, tbd_io)).to be(true)

    # Load minimal KHI JSON example
    tbd_io_f = File.dirname(__FILE__) + "/../json/tbd_minimal_KHI.json"
    expect(File.exist?(tbd_schema_f)).to be(true)
    tbd_io_c = File.read(tbd_io_f)
    tbd_io = JSON.parse(tbd_io_c, symbolize_names: true)
    expect(JSON::Validator.validate(tbd_schema, tbd_io)).to be(true)
    expect(JSON::Validator.validate(tbd_schema_f, tbd_io_f, uri: true)).to be(true)
  end
end
