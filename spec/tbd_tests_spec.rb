require "tbd"

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

    argh = {}
    os_model = OpenStudio::Model::Model.new
    os_g = OpenStudio::Model::Space.new(os_model) # gallery "g" & elevator "e"
    expect(os_g.setName("scrigno_gallery").to_s).to eq("scrigno_gallery")
    os_p = OpenStudio::Model::Space.new(os_model) # plenum "p" & stairwell "s"
    expect(os_p.setName("scrigno_plenum").to_s).to eq("scrigno_plenum")
    os_s = OpenStudio::Model::ShadingSurfaceGroup.new(os_model)

    os_building = os_model.getBuilding

    # For the purposes of the spec, all opaque envelope assemblies are built up
    # from a single, 3-layered construction.
    construction = OpenStudio::Model::Construction.new(os_model)
    expect(construction.handle.to_s.empty?).to be(false)
    expect(construction.nameString.empty?).to be(false)
    expect(construction.nameString).to eq("Construction 1")
    construction.setName("scrigno_construction")
    expect(construction.nameString).to eq("scrigno_construction")
    expect(construction.layers.size).to eq(0)

    # All subsurfaces are Simple Glazing constructions.
    fenestration = OpenStudio::Model::Construction.new(os_model)
    expect(fenestration.handle.to_s.empty?).to be(false)
    expect(fenestration.nameString.empty?).to be(false)
    expect(fenestration.nameString).to eq("Construction 1")
    fenestration.setName("scrigno_fenestration")
    expect(fenestration.nameString).to eq("scrigno_fenestration")
    expect(fenestration.layers.size).to eq(0)

    glazing = OpenStudio::Model::SimpleGlazing.new(os_model)
    expect(glazing.handle.to_s.empty?).to be(false)
    expect(glazing.nameString.empty?).to be(false)
    expect(glazing.nameString).to eq("Window Material Simple Glazing System 1")
    glazing.setName("scrigno_glazing")
    expect(glazing.nameString).to eq("scrigno_glazing")
    expect(glazing.setUFactor(2.0)).to be(true)
    expect(glazing.setSolarHeatGainCoefficient(0.50)).to be(true)
    expect(glazing.setVisibleTransmittance(0.70)).to be(true)

    layers = OpenStudio::Model::MaterialVector.new
    layers << glazing
    expect(fenestration.setLayers(layers)).to be(true)
    expect(fenestration.layers.size).to eq(1)
    expect(fenestration.layers[0].handle.to_s).to eq(glazing.handle.to_s)
    expect(fenestration.uFactor.empty?).to be(false)
    expect(fenestration.uFactor.get).to be_within(0.1).of(2.0)

    exterior = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    expect(exterior.handle.to_s.empty?).to be(false)
    expect(exterior.nameString.empty?).to be(false)
    expect(exterior.nameString).to eq("Material No Mass 1")
    exterior.setName("scrigno_exterior")
    expect(exterior.nameString).to eq("scrigno_exterior")
    expect(exterior.setRoughness("Rough")).to be(true)
    expect(exterior.setThermalResistance(0.3626)).to be(true)
    expect(exterior.setThermalAbsorptance(0.9)).to be(true)
    expect(exterior.setSolarAbsorptance(0.7)).to be(true)
    expect(exterior.setVisibleAbsorptance(0.7)).to be(true)
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
    expect(insulation.setRoughness("MediumRough")).to be(true)
    expect(insulation.setThickness(0.1184)).to be(true)
    expect(insulation.setConductivity(0.045)).to be(true)
    expect(insulation.setDensity(265)).to be(true)
    expect(insulation.setSpecificHeat(836.8)).to be(true)
    expect(insulation.setThermalAbsorptance(0.9)).to be(true)
    expect(insulation.setSolarAbsorptance(0.7)).to be(true)
    expect(insulation.setVisibleAbsorptance(0.7)).to be(true)
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
    expect(interior.setRoughness("MediumRough")).to be(true)
    expect(interior.setThickness(0.0126)).to be(true)
    expect(interior.setConductivity(0.16)).to be(true)
    expect(interior.setDensity(784.9)).to be(true)
    expect(interior.setSpecificHeat(830)).to be(true)
    expect(interior.setThermalAbsorptance(0.9)).to be(true)
    expect(interior.setSolarAbsorptance(0.9)).to be(true)
    expect(interior.setVisibleAbsorptance(0.9)).to be(true)
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

    subs = OpenStudio::Model::DefaultSubSurfaceConstructions.new(os_model)
    expect(subs.setFixedWindowConstruction(fenestration)).to be(true)
    expect(subs.setOperableWindowConstruction(fenestration)).to be(true)
    expect(subs.setDoorConstruction(fenestration)).to be(true)
    expect(subs.setGlassDoorConstruction(fenestration)).to be(true)
    expect(subs.setOverheadDoorConstruction(fenestration)).to be(true)
    expect(subs.setSkylightConstruction(fenestration)).to be(true)
    expect(subs.setTubularDaylightDomeConstruction(fenestration)).to be(true)
    expect(subs.setTubularDaylightDiffuserConstruction(fenestration)).to be(true)

    set = OpenStudio::Model::DefaultConstructionSet.new(os_model)
    expect(set.setDefaultExteriorSurfaceConstructions(defaults)).to be(true)
    expect(set.setDefaultExteriorSubSurfaceConstructions(subs)).to be(true)

    # if one comments out the following, then one can no longer rely on a
    # building-specific, default construction set. If missing, fall back to
    # to model default construction set @index 0.
    expect(os_building.setDefaultConstructionSet(set)).to be(true)

    # 8" XPS massless variant, specific for elevator floor (not defaulted)
    xps8x25mm = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    expect(xps8x25mm.handle.to_s.empty?).to be(false)
    expect(xps8x25mm.nameString.empty?).to be(false)
    expect(xps8x25mm.nameString).to eq("Material No Mass 1")
    xps8x25mm.setName("xps8x25mm")
    expect(xps8x25mm.nameString).to eq("xps8x25mm")
    expect(xps8x25mm.setRoughness("Rough")).to be(true)
    expect(xps8x25mm.setThermalResistance(8 * 0.88)).to be(true)
    expect(xps8x25mm.setThermalAbsorptance(0.9)).to be(true)
    expect(xps8x25mm.setSolarAbsorptance(0.7)).to be(true)
    expect(xps8x25mm.setVisibleAbsorptance(0.7)).to be(true)
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
    expect(os_r1_shade.setShadingSurfaceGroup(os_s)).to be(true)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 22.7, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 37.5, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 37.5, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 45.0, 50.0)
    os_r2_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r2_shade.setName("r2_shade")
    expect(os_r2_shade.setShadingSurfaceGroup(os_s)).to be(true)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 22.7, 32.5, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 32.5, 50.0)
    os_r3_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r3_shade.setName("r3_shade")
    expect(os_r3_shade.setShadingSurfaceGroup(os_s)).to be(true)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 48.7, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 59.0, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 59.0, 45.0, 50.0)
    os_r4_shade = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_r4_shade.setName("r4_shade")
    expect(os_r4_shade.setShadingSurfaceGroup(os_s)).to be(true)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 41.7, 44.0)
    os_v << OpenStudio::Point3d.new( 45.7, 41.7, 44.0)
    os_v << OpenStudio::Point3d.new( 45.7, 40.2, 44.0)
    os_N_balcony = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_N_balcony.setName("N_balcony") # 1.70m as thermal bridge
    expect(os_N_balcony.setShadingSurfaceGroup(os_s)).to be(true)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.1, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 28.1, 28.3, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 28.3, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 44.0)
    os_S_balcony = OpenStudio::Model::ShadingSurface.new(os_v, os_model)
    os_S_balcony.setName("S_balcony") # 19.3m as thermal bridge
    expect(os_S_balcony.setShadingSurfaceGroup(os_s)).to be(true)

    # 1st space: gallery (g) with elevator (e) surfaces
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5) # 10.4m
    os_g_W_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_W_wall.setName("g_W_wall")
    expect(os_g_W_wall.setSpace(os_g)).to be(true)                     #  57.2m2

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
    expect(os_g_N_wall.setSpace(os_g)).to be(true)                     # 201.3m2
    expect(os_g_N_wall.uFactor.empty?).to be(false)
    expect(os_g_N_wall.uFactor.get).to be_within(0.001).of(0.310)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 46.0) #   2.0m
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 44.0) #   1.0m
    os_v << OpenStudio::Point3d.new( 46.4, 40.2, 44.0) #   2.0m
    os_v << OpenStudio::Point3d.new( 46.4, 40.2, 46.0) #   1.0m
    os_g_N_door = OpenStudio::Model::SubSurface.new(os_v, os_model)
    os_g_N_door.setName("g_N_door")
    expect(os_g_N_door.setSubSurfaceType("GlassDoor")).to be(true)
    expect(os_g_N_door.setSurface(os_g_N_wall)).to be(true)            #   2.0m2
    expect(os_g_N_door.uFactor.empty?).to be(false)
    expect(os_g_N_door.uFactor.get).to be_within(0.1).of(2.0)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5) #  5.5m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) #  5.5m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5) # 10.4m
    os_g_E_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_E_wall.setName("g_E_wall")
    expect(os_g_E_wall.setSpace(os_g)).to be(true)                      # 57.2m2

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
    expect(os_g_S_wall.setSpace(os_g)).to be(true)                    # 190.48m2
    expect(os_g_S_wall.uFactor.empty?).to be(false)
    expect(os_g_S_wall.uFactor.get).to be_within(0.001).of(0.310)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 46.4, 29.8, 46.0) #  2.0m
    os_v << OpenStudio::Point3d.new( 46.4, 29.8, 44.0) #  1.0m
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 44.0) #  2.0m
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 46.0) #  1.0m
    os_g_S_door = OpenStudio::Model::SubSurface.new(os_v, os_model)
    os_g_S_door.setName("g_S_door")
    expect(os_g_S_door.setSubSurfaceType("GlassDoor")).to be(true)
    expect(os_g_S_door.setSurface(os_g_S_wall)).to be(true)            #   2.0m2
    expect(os_g_S_door.uFactor.empty?).to be(false)
    expect(os_g_S_door.uFactor.get).to be_within(0.1).of(2.0)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5) # 36.6m
    os_g_top = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_top.setName("g_top")
    expect(os_g_top.setSpace(os_g)).to be(true)                       # 380.64m2
    expect(os_g_S_wall.uFactor.empty?).to be(false)
    expect(os_g_S_wall.uFactor.get).to be_within(0.001).of(0.310)

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
    expect(os_g_sky.setSurface(os_g_top)).to be(true)                 # 380.64m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 46.7) #  1.5m
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 46.7) #  4.0m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7) #  1.5m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 46.7) #  4.0m
    os_e_top = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_top.setName("e_top")
    expect(os_e_top.setSpace(os_g)).to be(true)                        #   6.0m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 40.8) #  1.5m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 40.8) #  4.0m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8) #  1.5m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8) #  4.0m
    os_e_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_floor.setName("e_floor")
    expect(os_e_floor.setSpace(os_g)).to be(true)                      #   6.0m2
    expect(os_e_floor.setOutsideBoundaryCondition("Outdoors")).to be(true)

    # initially, elevator floor is defaulted ...
    expect(os_e_floor.surfaceType.downcase).to eq("floor")
    expect(os_e_floor.isConstructionDefaulted).to be(true)
    c = set.getDefaultConstruction(os_e_floor).get.to_Construction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be(true)
    expect(c.nameString).to eq("scrigno_construction")

    # ... now overriding default construction
    expect(os_e_floor.setConstruction(elevator_floor_c)).to be(true)
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
    expect(os_e_W_wall.setSpace(os_g)).to be(true)                    #   8.85m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 46.7) #  5.9m
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 40.8) #  4.0m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8) #  5.5m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7) #  4.0m
    os_e_S_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_S_wall.setName("e_S_wall")
    expect(os_e_S_wall.setSpace(os_g)).to be(true)                     #  23.6m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7) #  5.9m
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8) #  1.5m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8) #  5.9m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 46.7) #  1.5m
    os_e_E_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_E_wall.setName("e_E_wall")
    expect(os_e_E_wall.setSpace(os_g)).to be(true)                    #   8.85m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4) #  1.60m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8) #  4.00m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 40.8) #  2.20m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) #  4.04m
    os_e_N_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_N_wall.setName("e_N_wall")
    expect(os_e_N_wall.setSpace(os_g)).to be(true)                    #  ~7.63m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0) #  1.60m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4) #  4.04m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) #  1.00m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0) #  4.00m
    os_e_p_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_e_p_wall.setName("e_p_wall")
    expect(os_e_p_wall.setSpace(os_g)).to be(true)                    #   ~5.2m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 36.6m
    os_g_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_g_floor.setName("g_floor")
    expect(os_g_floor.setSpace(os_g) ).to be(true)                    # 380.64m2

    # 2nd space: plenum (p) with stairwell (s) surfaces
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) # 36.6m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 36.6m
    os_p_top = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_top.setName("p_top")
    expect(os_p_top.setSpace(os_p)).to be(true)                       # 380.64m2

    expect(os_p_top.setAdjacentSurface(os_g_floor)).to be(true)
    expect(os_g_floor.setAdjacentSurface(os_p_top)).to be(true)
    expect(os_p_top.setOutsideBoundaryCondition("Surface")).to be(true)
    expect(os_g_floor.setOutsideBoundaryCondition("Surface")).to be(true)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0) #  1.00m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) #  4.04m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4) #  1.60m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0) #  4.00m
    os_p_e_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_e_wall.setName("p_e_wall")
    expect(os_p_e_wall.setSpace(os_p)).to be(true)                     #  ~5.2m2

    expect(os_e_p_wall.setAdjacentSurface(os_p_e_wall)).to be(true)
    expect(os_p_e_wall.setAdjacentSurface(os_e_p_wall)).to be(true)
    expect(os_p_e_wall.setOutsideBoundaryCondition("Surface")).to be(true)
    expect(os_e_p_wall.setOutsideBoundaryCondition("Surface")).to be(true)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) #   6.67m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) #   1.00m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0) #   6.60m
    os_p_S1_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_S1_wall.setName("p_S1_wall")
    expect(os_p_S1_wall.setSpace(os_p)).to be(true)                    #  ~3.3m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0) #   1.60m
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4) #   2.73m
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.0) #  10.00m
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0) #  13.45m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) #  25.00m
    os_p_S2_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_S2_wall.setName("p_S2_wall")
    expect(os_p_S2_wall.setSpace(os_p)).to be(true)                   #  38.15m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) #  13.45m
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0) #  10.00m
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.0) #  13.45m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) #  36.60m
    os_p_N_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_N_wall.setName("p_N_wall")
    expect(os_p_N_wall.setSpace(os_p)).to be(true)                    #  46.61m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.0) # 10.0m
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0) # 10.4m
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0) # 10.0m
    os_p_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_floor.setName("p_floor")
    expect(os_p_floor.setSpace(os_p)).to be(true)                     # 104.00m2
    expect(os_p_floor.setOutsideBoundaryCondition("Outdoors")).to be(true)

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0) # 10.40m
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0) # 13.45m
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0) # 10.40m
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0) # 13.45m
    os_p_E_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_E_floor.setName("p_E_floor")
    expect(os_p_E_floor.setSpace(os_p)).to be(true)                   # 139.88m2
    expect(os_p_E_floor.setSurfaceType("Floor")).to be(true)  # walls by default

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0) # 10.40m
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0) # ~6.68m
    os_v << OpenStudio::Point3d.new( 24.0, 40.2, 43.0) # 10.40m
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0) # ~6.68m
    os_p_W1_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_W1_floor.setName("p_W1_floor")
    expect(os_p_W1_floor.setSpace(os_p)).to be(true)                  #  69.44m2
    expect(os_p_W1_floor.setSurfaceType("Floor")).to be(true) # walls by default

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.00) #  3.30m D
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.00) #  5.06m C
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.26) #  3.80m I
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.26) #  5.06m H
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.00) #  3.30m B
    os_v << OpenStudio::Point3d.new( 24.0, 40.2, 43.00) #  6.77m A
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.00) # 10.40m E
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.00) #  6.77m F
    os_p_W2_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_p_W2_floor.setName("p_W2_floor")
    expect(os_p_W2_floor.setSpace(os_p)).to be(true)                  #  51.23m2
    expect(os_p_W2_floor.setSurfaceType("Floor")).to be(true) # walls by default

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.0) #  2.2m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.8) #  3.8m
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.8) #  2.2m
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.0) #  3.8m
    os_s_W_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_W_wall.setName("s_W_wall")
    expect(os_s_W_wall.setSpace(os_p)).to be(true)                    #   8.39m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.26) #  1.46m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.80) #  5.00m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.80) #  2.20m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.00) #  5.06m
    os_s_N_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_N_wall.setName("s_N_wall")
    expect(os_s_N_wall.setSpace(os_p)).to be(true)                    #   9.15m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.26) #  1.46m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.80) #  3.80m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.80) #  1.46m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.26) #  3.80m
    os_s_E_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_E_wall.setName("s_E_wall")
    expect(os_s_E_wall.setSpace(os_p)).to be(true)                    #   5.55m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.00) #  2.20m
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.80) #  5.00m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.80) #  1.46m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.26) #  5.06m
    os_s_S_wall = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_S_wall.setName("s_S_wall")
    expect(os_s_S_wall.setSpace(os_p)).to be(true)                    #   9.15m2

    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.8) #  3.8m
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.8) #  5.0m
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.8) #  3.8m
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.8) #  5.0m
    os_s_floor = OpenStudio::Model::Surface.new(os_v, os_model)
    os_s_floor.setName("s_floor")
    expect(os_s_floor.setSpace(os_p)).to be(true)                      #  19.0m2
    expect(os_s_floor.setSurfaceType("Floor")).to be(true)
    expect(os_s_floor.setOutsideBoundaryCondition("Outdoors")).to be(true)

    pth = File.join(__dir__, "files/osms/out/os_model_test.osm")
    os_model.save(pth, true)

    # Create the Topolys Model.
    t_model = Topolys::Model.new

    # "true" if any OSM space/zone holds DD setpoint temperatures.
    setpoints = heatingTemperatureSetpoints?(os_model)
    setpoints = coolingTemperatureSetpoints?(os_model) unless setpoints

    # "true" if any OSM space/zone is part of an HVAC air loop.
    airloops = airLoopsHVAC?(os_model)

    # Fetch OpenStudio (opaque) surfaces & key attributes.
    surfaces = {}
    os_model.getSurfaces.each do |s|

      id = s.nameString
      surface = openings(os_model, s)
      next if surface.nil?
      expect(surface.is_a?(Hash)).to be(true)
      expect(surface.key?(:space)).to be(true)

      boundary = s.outsideBoundaryCondition
      if boundary.downcase == "surface"
        expect(s.adjacentSurface.empty?).to be(false)
        adjacent = s.adjacentSurface.get.nameString
        expect(os_model.getSurfaceByName(adjacent).empty?).to be(false)
        boundary = adjacent
      end
      surface[:boundary] = boundary
      surface[:ground] = s.isGroundSurface
      surface[:conditioned] = true

      typ = s.surfaceType.downcase
      surface[:type] = :floor
      surface[:type] = :ceiling if typ.include?("ceiling")
      surface[:type] = :wall if typ.include?("wall")

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
          surface[:construction] = construction
          surface[:index]        = index
          surface[:ltype]        = ltype
          surface[:r]            = r
        end
      end
      surfaces[id] = surface
    end                                            # (opaque) surfaces populated

    expect(surfaces.empty?).to be(false)

    surfaces.each do |id, surface|
      expect(surface[:conditioned]).to be(true)
      expect(surface.key?(:heating)).to be(false)
      expect(surface.key?(:cooling)).to be(false)
    end

    surfaces.each do |id, surface|
      surface[:deratable] = false
      next unless surface.key?(:conditioned)
      next unless surface[:conditioned]
      next if surface[:ground]
      b = surface[:boundary]
      if b.downcase == "outdoors"
        surface[:deratable] = true
      else
        next unless surfaces.key?(b)
        next unless surfaces[b].key?(:conditioned)
        next if surfaces[b][:conditioned]
        surface[:deratable] = true
      end
    end

    # Sort kids.
    surfaces.values.each do |p|
      if p.key?(:windows)
        p[:windows] = p[:windows].sort_by{ |_, pp| pp[:minz] }.to_h
      end
      if p.key?(:doors)
        p[:doors] = p[:doors].sort_by{ |_, pp| pp[:minz] }.to_h
      end
      if p.key?(:skylights)
        p[:skylights] = p[:skylights].sort_by{ |_, pp| pp[:minz] }.to_h
      end
    end

    expect(surfaces["g_top"   ].key?(:windows  )).to be(false)
    expect(surfaces["g_top"   ].key?(:doors    )).to be(false)
    expect(surfaces["g_top"   ].key?(:skylights)).to be(true)

    expect(surfaces["g_top"   ][:skylights].size).to eq(1)
    expect(surfaces["g_S_wall"][:doors    ].size).to eq(1)
    expect(surfaces["g_N_wall"][:doors    ].size).to eq(1)

    expect(surfaces["g_top"   ][:skylights].key?("g_sky"   )).to be(true)
    expect(surfaces["g_S_wall"][:doors    ].key?("g_S_door")).to be(true)
    expect(surfaces["g_N_wall"][:doors    ].key?("g_N_door")).to be(true)

    expect(surfaces["g_top"   ].key?(:type)).to be(true)

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

    # Fetch OpenStudio shading surfaces & key attributes.
    shades = {}
    os_model.getShadingSurfaces.each do |s|
      next if s.shadingSurfaceGroup.empty?
      group = s.shadingSurfaceGroup.get
      id = s.nameString

      # Site-specific (or absolute, or true) surface normal. Shading surface
      # groups may also be linked to (rotated) spaces.
      t, r = transforms(os_model, group)
      expect(t.nil?).to be(false)
      expect(r.nil?).to be(false)
      shading = group.to_ShadingSurfaceGroup
      unless shading.empty?
        unless shading.get.space.empty?
          r += shading.get.space.get.directionofRelativeNorth
        end
      end
      n = trueNormal(s, r)
      expect(n.nil?).to be(false)

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
        unless edges.key?(e.id)
          edges[e.id] = { length: e.length,
                          v0: e.v0,
                          v1: e.v1,
                          surfaces: {}}
        end
        unless edges[e.id][:surfaces].key?(wire.attributes[:id])
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
    expect(intersection.size).to eq(1)

    intersection = p_S2_wall_edge_ids & e_p_wall_edges_ids &
                   p_e_wall_edges_ids & e_E_wall_edges_ids
    expect(intersection.size).to eq(1)

    shared_edges = p_S2_wall_face.shared_outer_edges(e_p_wall_face)
    expect(shared_edges.size).to eq(1)
    expect(shared_edges.first.id).to eq(intersection.to_a.first)

    shared_edges = p_S2_wall_face.shared_outer_edges(p_e_wall_face)
    expect(shared_edges.size).to eq(1)
    expect(shared_edges.first.id).to eq(intersection.to_a.first)

    shared_edges = p_S2_wall_face.shared_outer_edges(e_E_wall_face)
    expect(shared_edges.size).to eq(1)
    expect(shared_edges.first.id).to eq(intersection.to_a.first)

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

    zenith      = Topolys::Vector3D.new(0, 0, 1).freeze
    north       = Topolys::Vector3D.new(0, 1, 0).freeze
    east        = Topolys::Vector3D.new(1, 0, 0).freeze

    edges.values.each do |edge|
      origin      = edge[:v0].point
      terminal    = edge[:v1].point
      dx          = (origin.x - terminal.x).abs
      dy          = (origin.y - terminal.y).abs
      dz          = (origin.z - terminal.z).abs
      horizontal  = dz.abs < TOL
      vertical    = dx < TOL && dy < TOL
      edge_V      = terminal - origin
      edge_plane  = Topolys::Plane3D.new(origin, edge_V)

      if vertical
        reference_V = north.dup
      elsif horizontal
        reference_V = zenith.dup
      else
        reference = edge_plane.project(origin + zenith)
        reference_V = reference - origin
      end

      edge[:surfaces].each do |id, surface|
        t_model.wires.each do |wire|
          if surface[:wire] == wire.id
            normal     = surfaces[id][:n]         if surfaces.key?(id)
            normal     = holes[id].attributes[:n] if holes.key?(id)
            normal     = shades[id][:n]           if shades.key?(id)
            farthest   = Topolys::Point3D.new(origin.x, origin.y, origin.z)
            farthest_V = farthest - origin
            inverted   = false
            i_origin   = wire.points.index(origin)
            i_terminal = wire.points.index(terminal)
            i_last     = wire.points.size - 1

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
            expect(angle).to be_within(0.01).of(Math::PI / 2)

            angle = reference_V.angle(farthest_V)
            adjust = false
            if vertical
              adjust = true if east.dot(farthest_V) < -TOL
            else
              if north.dot(farthest_V).abs < TOL            ||
                (north.dot(farthest_V).abs - 1).abs < TOL
                  adjust = true if east.dot(farthest_V) < -TOL
              else
                adjust = true if north.dot(farthest_V) < -TOL
              end
            end
            angle = 2 * Math::PI - angle if adjust
            angle -= 2 * Math::PI if (angle - 2 * Math::PI).abs < TOL
            surface[:angle] = angle
            farthest_V.normalize!
            surface[:polar] = farthest_V
            surface[:normal] = normal
          end
        end                           # end of edge-linked, surface-to-wire loop
      end                                      # end of edge-linked surface loop

      edge[:horizontal] = horizontal
      edge[:vertical] = vertical
      edge[:surfaces] = edge[:surfaces].sort_by{ |i, p| p[:angle] }.to_h
    end                                                       # end of edge loop

    expect(edges.size).to eq(89)
    expect(t_model.edges.size).to eq(89)

    argh[:option] = "poor (BETBG)"
    io, io_p, io_k = processTBDinputs(surfaces, edges, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.empty?).to be(false)
    expect(io.key?(:building)).to be(true)
    expect(io[:building].key?(:psi)).to be(true)
    p = io[:building][:psi]
    has, val = io_p.shorthands(p)
    expect(has.empty?).to be(false)
    expect(val.empty?).to be(false)

    edges.values.each do |edge|
      next unless edge.key?(:surfaces)
      deratables = []
      edge[:surfaces].each do |id, surface|
        next unless surfaces.key?(id)
        next unless surfaces[id].key?(:deratable)
        deratables << id if surfaces[id][:deratable]
      end
      next if deratables.empty?
      psi = {}

      edge[:surfaces].keys.each do |id|
        next unless surfaces.key?(id)
        next unless deratables.include?(id)

        # Evaluate PSI content before processing a new linked surface.
        is = {}
        is[:head]     = psi.keys.to_s.include?("head")
        is[:sill]     = psi.keys.to_s.include?("sill")
        is[:jamb]     = psi.keys.to_s.include?("jamb")
        is[:corner]   = psi.keys.to_s.include?("corner")
        is[:parapet]  = psi.keys.to_s.include?("parapet")
        is[:party]    = psi.keys.to_s.include?("party")
        is[:grade]    = psi.keys.to_s.include?("grade")
        is[:balcony]  = psi.keys.to_s.include?("balcony")
        is[:rimjoist] = psi.keys.to_s.include?("rimjoist")

        # Label edge as :head, :sill or :jamb if linked to:
        #   1x subsurface
        unless is[:head] || is[:sill] || is[:jamb]
          edge[:surfaces].keys.each do |i|
            next if is[:head] || is[:sill] || is[:jamb]
            next if i == id
            next if deratables.include?(i)
            next unless holes.key?(i)

            ii = ""
            ii = id if deratables.size == 1                           # just dad
            if ii.empty?                                            # seek uncle
              jj = deratables.first unless deratables.first == id
              jj = deratables.last  unless deratables.last  == id
              id_has = {}
              id_has[:windows]   = true if surfaces[id].key?(:windows)
              id_has[:doors]     = true if surfaces[id].key?(:doors)
              id_has[:skylights] = true if surfaces[id].key?(:skylights)
              ido = []
              ido = ido + surfaces[id][:windows].keys   if id_has[:windows]
              ido = ido + surfaces[id][:doors].keys     if id_has[:doors]
              ido = ido + surfaces[id][:skylights].keys if id_has[:skylights]
              jj_has = {}
              jj_has[:windows]   = true if surfaces[jj].key?(:windows)
              jj_has[:doors]     = true if surfaces[jj].key?(:doors)
              jj_has[:skylights] = true if surfaces[jj].key?(:skylights)
              jjo = []
              jjo = jjo + surfaces[jj][:windows].keys   if jj_has[:windows]
              jjo = jjo + surfaces[jj][:doors].keys     if jj_has[:doors]
              jjo = jjo + surfaces[jj][:skylights].keys if jj_has[:skylights]
              ii = jj if ido.include?(i)
              ii = id if jjo.include?(i)
            end
            next if ii.empty?

            s1      = edge[:surfaces][ii]
            s2      = edge[:surfaces][i]
            concave = concave?(s1, s2)
            convex  = convex?(s1, s2)
            flat    = !concave && !convex

            if ((s2[:normal].dot(zenith)).abs - 1).abs < TOL
              psi[:jamb]        = val[:jamb]        if flat
              psi[:jambconcave] = val[:jambconcave] if concave
              psi[:jambconvex]  = val[:jambconvex]  if convex
               is[:jamb]        = true
            else
              if edge[:horizontal]
                if s2[:polar].dot(zenith) < 0
                  psi[:head]        = val[:head]        if flat
                  psi[:headconcave] = val[:headconcave] if concave
                  psi[:headconvex]  = val[:headconvex]  if convex
                   is[:head]        = true
                else
                  psi[:sill]        = val[:sill]        if flat
                  psi[:sillconcave] = val[:sillconcave] if concave
                  psi[:sillconvex]  = val[:sillconvex]  if convex
                   is[:sill]        = true
                end
              else
                psi[:jamb]        = val[:jamb]        if flat
                psi[:jambconcave] = val[:jambconcave] if concave
                psi[:jambconvex]  = val[:jambconvex]  if convex
                 is[:jamb]        = true
              end
            end
          end
        end

        # Label edge as :cornerconcave or :cornerconvex if linked to:
        #   2x deratable walls & f(relative polar wall vectors around edge)
        unless is[:cornerconcave] || is[:cornerconvex]
          edge[:surfaces].keys.each do |i|
            next if is[:cornerconcave] || is[:cornerconvex]
            next if i == id
            next unless deratables.size == 2
            next unless deratables.include?(i)
            next unless walls.key?(id)
            next unless walls.key?(i)

            s1      = edge[:surfaces][id]
            s2      = edge[:surfaces][i]
            concave = concave?(s1, s2)
            convex  = convex?(s1, s2)
            flat    = !concave && !convex

            psi[:cornerconcave] = val[:cornerconcave] if concave
            psi[:cornerconvex]  = val[:cornerconvex]  if convex
             is[:corner]        = true
          end
        end

        # Label edge as :parapet if linked to:
        #   1x deratable wall
        #   1x deratable ceiling
        unless is[:parapet]
          edge[:surfaces].keys.each do |i|
            next if is[:parapet]
            next if i == id
            next unless deratables.size == 2
            next unless deratables.include?(i)
            next unless ceilings.key?(id)
            next unless walls.key?(i)

            s1      = edge[:surfaces][id]
            s2      = edge[:surfaces][i]
            concave = concave?(s1, s2)
            convex  = convex?(s1, s2)
            flat    = !concave && !convex

            psi[:parapet]        = val[:parapet]        if flat
            psi[:parapetconcave] = val[:parapetconcave] if concave
            psi[:parapetconvex]  = val[:parapetconvex]  if convex
             is[:parapet]        = true
          end
        end

        # Label edge as :party if linked to:
        #   1x adiabatic surface
        #   1x (only) deratable surface
        unless is[:party]
          edge[:surfaces].keys.each do |i|
            next if is[:party]
            next if i == id
            next unless deratables.size == 1
            next unless surfaces.key?(i)
            next if holes.key?(i)
            next if shades.key?(i)
            next unless surfaces[i][:boundary].downcase == "adiabatic"

            s1      = edge[:surfaces][id]
            s2      = edge[:surfaces][i]
            concave = concave?(s1, s2)
            convex  = convex?(s1, s2)
            flat    = !concave && !convex

            psi[:party]        = val[:party]        if flat
            psi[:partyconcave] = val[:partyconcave] if concave
            psi[:partyconvex]  = val[:partyconvex]  if convex
             is[:party]        = true
          end
        end

        # Label edge as :grade if linked to:
        #   1x surface (e.g. slab or wall) facing ground
        #   1x surface (i.e. wall) facing outdoors
        unless is[:grade]
          edge[:surfaces].keys.each do |i|
            next if is[:grade]
            next if i == id
            next unless deratables.size == 1
            next unless surfaces.key?(i)
            next unless surfaces[i].key?(:ground)
            next unless surfaces[i][:ground]

            s1      = edge[:surfaces][id]
            s2      = edge[:surfaces][i]
            concave = concave?(s1, s2)
            convex  = convex?(s1, s2)
            flat    = !concave && !convex

            psi[:grade]        = val[:grade]        if flat
            psi[:gradeconcave] = val[:gradeconcave] if concave
            psi[:gradeconvex]  = val[:gradeconvex]  if convex
             is[:grade]        = true
          end
        end

        # Label edge as :rimjoist (or :balcony) if linked to:
        #   1x deratable surface
        #   1x CONDITIONED floor
        #   1x shade (optional)
        unless is[:rimjoist] || is[:balcony]
          balcony = false
          edge[:surfaces].keys.each do |i|
            next if i == id
            balcony = true if shades.key?(i)
          end
          edge[:surfaces].keys.each do |i|
            next if is[:rimjoist] || is[:balcony]
            next if i == id
            next unless deratables.size == 2
            next if floors.key?(id)
            next unless floors.key?(i)
            next unless floors[i].key?(:conditioned)
            next unless floors[i][:conditioned]
            next if floors[i][:ground]

            ii = ""
            ii = i if deratables.include?(i)                     # exposed floor
            if ii.empty?
              deratables.each do |j|
                ii = j unless j == id
              end
            end
            next if ii.empty?

            s1      = edge[:surfaces][id]
            s2      = edge[:surfaces][ii]
            concave = concave?(s1, s2)
            convex  = convex?(s1, s2)
            flat    = !concave && !convex

            if balcony
              psi[:balcony]        = val[:balcony]        if flat
              psi[:balconyconcave] = val[:balconyconcave] if concave
              psi[:balconyconvex]  = val[:balconyconvex]  if convex
               is[:balcony]        = true
            else
              psi[:rimjoist]        = val[:rimjoist]        if flat
              psi[:rimjoistconcave] = val[:rimjoistconcave] if concave
              psi[:rimjoistconvex]  = val[:rimjoistconvex]  if convex
               is[:rimjoist]        = true
            end
          end
        end
      end                                                 # edge's surfaces loop

      edge[:psi] = psi unless psi.empty?
      edge[:set] = p unless psi.empty?
    end                                                              # edge loop

    # Tracking (mild) transitions.
    transitions = {}
    edges.each do |tag, edge|
      next if edge.key?(:psi)
      next unless edge.key?(:surfaces)
      deratable = false
      edge[:surfaces].each do |id, surface|
        next if deratable
        next unless surfaces.key?(id)
        next unless surfaces[id].key?(:deratable)
        deratable = true if surfaces[id][:deratable]
      end
      next unless deratable
      count = 0
      edge[:surfaces].keys.each do |id|
        next unless surfaces.key?(id)
        next unless surfaces[id].key?(:deratable)
        next unless surfaces[id][:deratable]
        count += 1
      end
      next unless count > 0
      psi = {}
      psi[:transition] = 0.000
      edge[:psi] = psi
      edge[:set] = io[:building][:psi]

      tr = []
      edge[:surfaces].keys.each do |id|
        next unless surfaces.key?(id)
        next unless surfaces[id].key?(:deratable)
        next unless surfaces[id][:deratable]
        tr << id
      end
      transitions[tag] = tr unless tr.empty?
    end

    # Lo Scrigno: such transitions occur between plenum floor plates.
    expect(transitions.empty?).to be(false)
    expect(transitions.size).to eq(4)
    w1_count = 0
    transitions.each do |tag, tr|
      expect(tr.size).to eq(2)
      if tr.include?("p_W1_floor")
        w1_count += 1
        expect(tr.include?("p_W2_floor")).to be(true)
      else
        expect(tr.include?("p_floor")).to be(true)
        valid1 = tr.include?("p_W2_floor")
        valid2 = tr.include?("p_E_floor")
        valid = valid1 || valid2
        expect(valid).to be(true)
      end
    end
    expect(w1_count).to eq(2)

    n_deratables                 = 0
    n_edges_at_grade             = 0
    n_edges_as_balconies         = 0
    n_edges_as_parapets          = 0
    n_edges_as_rimjoists         = 0
    n_edges_as_concave_rimjoists = 0
    n_edges_as_convex_rimjoists  = 0
    n_edges_as_fenestrations     = 0
    n_edges_as_heads             = 0
    n_edges_as_sills             = 0
    n_edges_as_jambs             = 0
    n_edges_as_concave_jambs     = 0
    n_edges_as_convex_jambs      = 0
    n_edges_as_corners           = 0
    n_edges_as_concave_corners   = 0
    n_edges_as_convex_corners    = 0
    n_edges_as_transitions       = 0

    edges.values.each do |edge|
      next unless edge.key?(:psi)
      n_deratables += 1
      n_edges_at_grade             += 1 if edge[:psi].key?(:grade)
      n_edges_at_grade             += 1 if edge[:psi].key?(:gradeconcave)
      n_edges_at_grade             += 1 if edge[:psi].key?(:gradeconvex)
      n_edges_as_balconies         += 1 if edge[:psi].key?(:balcony)
      n_edges_as_parapets          += 1 if edge[:psi].key?(:parapetconcave)
      n_edges_as_parapets          += 1 if edge[:psi].key?(:parapetconvex)
      n_edges_as_rimjoists         += 1 if edge[:psi].key?(:rimjoist)
      n_edges_as_concave_rimjoists += 1 if edge[:psi].key?(:rimjoistconcave)
      n_edges_as_convex_rimjoists  += 1 if edge[:psi].key?(:rimjoistconvex)
      n_edges_as_fenestrations     += 1 if edge[:psi].key?(:fenestration)
      n_edges_as_heads             += 1 if edge[:psi].key?(:head)
      n_edges_as_sills             += 1 if edge[:psi].key?(:sill)
      n_edges_as_jambs             += 1 if edge[:psi].key?(:jamb)
      n_edges_as_concave_jambs     += 1 if edge[:psi].key?(:jambconcave)
      n_edges_as_convex_jambs      += 1 if edge[:psi].key?(:jambconvex)
      n_edges_as_corners           += 1 if edge[:psi].key?(:corner)
      n_edges_as_concave_corners   += 1 if edge[:psi].key?(:cornerconcave)
      n_edges_as_convex_corners    += 1 if edge[:psi].key?(:cornerconvex)
      n_edges_as_transitions       += 1 if edge[:psi].key?(:transition)
    end
    expect(n_deratables).to                 eq(66)
    expect(n_edges_at_grade).to             eq( 0)
    expect(n_edges_as_balconies).to         eq( 4)
    expect(n_edges_as_parapets).to          eq( 8)
    expect(n_edges_as_rimjoists).to         eq( 5)
    expect(n_edges_as_concave_rimjoists).to eq( 5)
    expect(n_edges_as_convex_rimjoists).to  eq(18)
    expect(n_edges_as_fenestrations).to     eq( 0)
    expect(n_edges_as_heads).to             eq( 2)
    expect(n_edges_as_sills).to             eq( 2)
    expect(n_edges_as_jambs).to             eq( 4)
    expect(n_edges_as_concave_jambs).to     eq( 0)
    expect(n_edges_as_convex_jambs).to      eq( 4)
    expect(n_edges_as_corners).to           eq( 0)
    expect(n_edges_as_concave_corners).to   eq( 4)
    expect(n_edges_as_convex_corners).to    eq(12)
    expect(n_edges_as_transitions).to       eq( 4)

    # Loop through each edge and assign heat loss to linked surfaces.
    edges.each do |identifier, edge|
      next unless edge.key?(:psi)
      psi = edge[:psi].values.max
      type = edge[:psi].key(psi)
      length = edge[:length]
      bridge = { psi: psi, type: type, length: length }

      if edge.key?(:sets) && edge[:sets].key?(type)
        edge[:set] = edge[:sets][type]
      end

      # Retrieve valid linked surfaces as deratables.
      deratables = {}
      edge[:surfaces].each do |id, surface|
        next unless surfaces.key?(id)
        next unless surfaces[id][:deratable]
        deratables[id] = surface
      end

      openings = {}
      edge[:surfaces].each do |id, surface|
        next unless holes.key?(id)
        openings[id] = surface
      end
      next if openings.size > 1                         # edge links 2x openings

      # Prune if edge links an opening and its parent, as well as 1x other
      # opaque surface (i.e. corner window derates neighbour - not parent).
      if deratables.size > 1 && openings.size > 0
        deratables.each do |id, deratable|
          if surfaces[id].key?(:windows)
            surfaces[id][:windows].keys.each do |i|
              deratables.delete(id) if openings.key?(i)
            end
          end
          if surfaces[id].key?(:doors)
            surfaces[id][:doors].keys.each do |i|
              deratables.delete(id) if openings.key?(i)
            end
          end
          if surfaces[id].key?(:skylights)
            surfaces[id][:skylights].keys.each do |i|
              deratables.delete(id) if openings.key?(i)
            end
          end
        end
      end
      next if deratables.empty?

      # Sum RSI of targeted insulating layer from each deratable surface.
      rsi = 0
      deratables.each do |id, deratable|
        expect(surfaces[id].key?(:r)).to be(true)
        rsi += surfaces[id][:r]
      end

      # Assign heat loss from thermal bridges to surfaces, in proportion to
      # insulating layer thermal resistance
      deratables.each do |id, deratable|
        surfaces[id][:edges] = {} unless surfaces[id].key?(:edges)
        loss = 0
        loss = bridge[:psi] * surfaces[id][:r] / rsi if rsi > 0.001
        b = { psi: loss, type: bridge[:type], length: bridge[:length] }
        surfaces[id][:edges][identifier] = b
      end
    end

    # Assign thermal bridging heat loss [in W/K] to each deratable surface.
    n_surfaces_to_derate = 0
    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
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
    expect(surfaces["e_W_wall"  ][:heatloss]).to be_within(0.01).of( 6.023)
    expect(surfaces["p_N_wall"  ][:heatloss]).to be_within(0.01).of(37.250)
    expect(surfaces["p_S2_wall" ][:heatloss]).to be_within(0.01).of(27.268)
    expect(surfaces["p_S1_wall" ][:heatloss]).to be_within(0.01).of( 7.063)
    expect(surfaces["g_S_wall"  ][:heatloss]).to be_within(0.01).of(56.150)
    expect(surfaces["p_floor"   ][:heatloss]).to be_within(0.01).of(10.000)
    expect(surfaces["p_W1_floor"][:heatloss]).to be_within(0.01).of(13.775)
    expect(surfaces["e_N_wall"  ][:heatloss]).to be_within(0.01).of( 4.727)
    expect(surfaces["s_N_wall"  ][:heatloss]).to be_within(0.01).of( 6.583)
    expect(surfaces["g_E_wall"  ][:heatloss]).to be_within(0.01).of(18.195)
    expect(surfaces["e_S_wall"  ][:heatloss]).to be_within(0.01).of( 7.703)
    expect(surfaces["e_top"     ][:heatloss]).to be_within(0.01).of( 4.400)
    expect(surfaces["s_W_wall"  ][:heatloss]).to be_within(0.01).of( 5.670)
    expect(surfaces["e_E_wall"  ][:heatloss]).to be_within(0.01).of( 6.023)
    expect(surfaces["e_floor"   ][:heatloss]).to be_within(0.01).of( 8.007)
    expect(surfaces["g_W_wall"  ][:heatloss]).to be_within(0.01).of(18.195)
    expect(surfaces["g_N_wall"  ][:heatloss]).to be_within(0.01).of(54.255)
    expect(surfaces["p_W2_floor"][:heatloss]).to be_within(0.01).of(13.729)

    surfaces.each do |id, surface|
      next unless surface.key?(:construction)
      next unless surface.key?(:index)
      next unless surface.key?(:ltype)
      next unless surface.key?(:r)
      next unless surface.key?(:edges)
      next unless surface.key?(:heatloss)
      next unless surface[:heatloss].abs > 0.01
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        index = surface[:index]
        current_c = surface[:construction]
        c = current_c.clone(os_model).to_Construction.get

        m = nil
        m = derate(os_model, id, surface, c) unless index.nil?

        if m
          c.setLayer(index, m)
          c.setName("#{id} c tbd")
          s.setConstruction(c)

          if s.outsideBoundaryCondition.downcase == "surface"
            unless s.adjacentSurface.empty?
              adjacent = s.adjacentSurface.get
              i = adjacent.nameString
              if surfaces.key?(i) && adjacent.isConstructionDefaulted == false
                indx = surfaces[i][:index]
                current_cc = surfaces[i][:construction]
                cc = current_cc.clone(os_model).to_Construction.get

                cc.setLayer(indx, m)
                cc.setName("#{i} c tbd")
                adjacent.setConstruction(cc)
              end
            end
          end
        end
      end
    end

    # testing
    floors.each do |id, floor|
      next unless floor.key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    # testing
    ceilings.each do |id, ceiling|
      next unless ceiling.key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    # testing
    walls.each do |id, wall|
      next unless wall.key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end
  end # can process thermal bridging and derating : LoScrigno

  it "can process DOE Prototype test_smalloffice.osm" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_smalloffice.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Testing min/max cooling/heating setpoints
    setpoints = heatingTemperatureSetpoints?(os_model)
    setpoints = coolingTemperatureSetpoints?(os_model) || setpoints
    expect(setpoints).to be(true)
    airloops = airLoopsHVAC?(os_model)
    expect(airloops).to be(true)

    os_model.getSpaces.each do |space|
      expect(space.thermalZone.empty?).to be(false)
      zone = space.thermalZone.get
      heating, _ = maxHeatScheduledSetpoint(zone)
      cooling, _ = minCoolScheduledSetpoint(zone)
      if zone.nameString == "Attic ZN"
        expect(plenum?(space, airloops, setpoints)).to be(false)
        expect(heating.nil?).to be(true)
        expect(cooling.nil?).to be(true)
        next
      end
      expect(plenum?(space, airloops, setpoints)).to be(false)
      expect(heating).to be_within(0.1).of(21.1)
      expect(cooling).to be_within(0.1).of(23.9)
    end

    # Tracking insulated ceiling surfaces below attic.
    os_model.getSurfaces.each do |s|
      next unless s.surfaceType == "RoofCeiling"
      next unless s.isConstructionDefaulted
      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      id = c.nameString
      expect(id).to eq("Typical Wood Joist Attic Floor R-37.04 1")
      expect(c.layers.size).to eq(2)
      expect(c.layers[0].nameString).to eq("5/8 in. Gypsum Board")
      expect(c.layers[1].nameString).to eq("Typical Insulation R-35.4 1")
      # "5/8 in. Gypsum Board"        : RSi = 0,0994 m2.K/W
      # "Typical Insulation R-35.4 1" : RSi = 6,2348 m2.K/W
    end

    # Tracking outdoor-facing office walls.
    os_model.getSurfaces.each do |s|
      next unless s.surfaceType == "Wall"
      next unless s.outsideBoundaryCondition == "Outdoors"
      id = s.construction.get.nameString
      str = "Typical Insulated Wood Framed Exterior Wall R-11.24"
      expect(id.include?(str)).to be(true)
      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.layers.size).to eq(4)
      expect(c.layers[0].nameString).to eq("25mm Stucco")
      expect(c.layers[1].nameString).to eq("5/8 in. Gypsum Board")
      str2 = "Typical Insulation R-9.06 1"
      expect(c.layers[2].nameString.include?(str2)).to be(true)
      expect(c.layers[3].nameString).to eq("5/8 in. Gypsum Board")
      # "25mm Stucco"                 : RSi = 0,0353 m2.K/W
      # "5/8 in. Gypsum Board"        : RSi = 0,0994 m2.K/W
      # "Perimeter_ZN_1_wall_south Typical Insulation R-9.06 1"
      #                               : RSi = 0,5947 m2.K/W
      # "Perimeter_ZN_2_wall_east Typical Insulation R-9.06 1"
      #                               : RSi = 0,6270 m2.K/W
      # "Perimeter_ZN_3_wall_north Typical Insulation R-9.06 1"
      #                               : RSi = 0,6346 m2.K/W
      # "Perimeter_ZN_4_wall_west Typical Insulation R-9.06 1"
      #                               : RSi = 0,6270 m2.K/W
    end

    argh[:option] = "poor (BETBG)"
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(43)
    expect(io[:edges].size).to eq(105)

    surfaces.each do |id, surface|
      expect(surface.key?(:conditioned)).to be(true)
      next unless surface[:conditioned]
      expect(surface.key?(:heating)).to be(true)
      expect(surface.key?(:cooling)).to be(true)

      # Testing glass door detection
      if surface.key?(:doors)
        surface[:doors].each do |i, door|
          expect(door.key?(:glazed)).to be(true)
          expect(door[:glazed]).to be(true)
          expect(door.key?(:u)).to be(true)
          expect(door[:u]).to be_a(Numeric)
          expect(door[:u]).to be_within(0.01).of(6.40)
        end
      end
    end

    # Testing attic surfaces.
    surfaces.each do |id, surface|
      expect(surface.key?(:space)).to be(true)
      next unless surface[:space].nameString == "Attic"

      # Attic is an UNENCLOSED zone - outdoor-facing surfaces are not derated.
      expect(surface.key?(:conditioned)).to be(true)
      expect(surface[:conditioned]).to be(false)
      expect(surface.key?(:heatloss)).to be(false)
      expect(surface.key?(:ratio)).to be(false)

      # Attic floor surfaces adjacent to ceiling surfaces below (CONDITIONED
      # office spaces) share derated constructions (although inverted).
      expect(surface.key?(:boundary)).to be(true)
      b = surface[:boundary]
      next if b == "Outdoors"

      # TBD/Topolys should be tracking the adjacent CONDITIONED surface.
      expect(surfaces.key?(b)).to be(true)
      expect(surfaces[b].key?(:conditioned)).to be(true)
      expect(surfaces[b][:conditioned]).to be(true)

      if id == "Attic_floor_core"
        expect(surfaces[b].key?(:heatloss)).to be(true)
        expect(surfaces[b][:heatloss]).to be_within(0.01).of(0.00)
        expect(surfaces[b].key?(:ratio)).to be(false)
      end

      next if id == "Attic_floor_core"
      expect(surfaces[b].key?(:heatloss)).to be(true)
      expect(surfaces[b].key?(:ratio)).to be(true)
      h = surfaces[b][:heatloss]
      expect(h).to be_within(0.01).of(20.11) if id.include?("north")
      expect(h).to be_within(0.01).of(20.22) if id.include?("south")
      expect(h).to be_within(0.01).of(13.42) if id.include?("west")
      expect(h).to be_within(0.01).of(13.42) if id.include?("east")

      # Derated constructions?
      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.surfaceType).to eq("Floor")

      # In the small office OSM, attic floor constructions are not set by
      # the attic default construction set. They are instead set for the
      # adjacent ceilings below (building default construction set). So
      # attic floor surfaces automatically inherit derated constructions.
      expect(s.isConstructionDefaulted).to be(true)
      c = s.construction.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.nameString.include?("c tbd")).to be(true)
      expect(c.layers.size).to eq(2)
      expect(c.layers[0].nameString).to eq("5/8 in. Gypsum Board")
      expect(c.layers[1].nameString.include?("m tbd")).to be(true)

      # Comparing derating ratios of constructions.
      expect(c.layers[1].to_MasslessOpaqueMaterial.empty?).to be(false)
      m = c.layers[1].to_MasslessOpaqueMaterial.get

      # Before derating.
      initial_R = s.filmResistance
      initial_R += 0.0994
      initial_R += 6.2348

      # After derating.
      derated_R = s.filmResistance
      derated_R += 0.0994
      derated_R += m.thermalResistance

      ratio = -(initial_R - derated_R) * 100 / initial_R
      expect(ratio).to be_within(1).of(surfaces[b][:ratio])
      # "5/8 in. Gypsum Board"        : RSi = 0,0994 m2.K/W
      # "Typical Insulation R-35.4 1" : RSi = 6,2348 m2.K/W
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(surface.key?(:heatloss)).to be(true)
      if id == "Core_ZN_ceiling"
        expect(surface[:heatloss]).to be_within(0.001).of(0)
        expect(surface.key?(:ratio)).to be(false)
        expect(surface.key?(:u)).to be(true)
        expect(surface[:u]).to be_within(0.001).of(0.153)
        next
      end
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)

      # Testing outdoor-facing walls.
      next unless s.surfaceType == "Wall"
      expect(h).to be_within(0.01).of(51.17) if id.include?("_1_") # South
      expect(h).to be_within(0.01).of(33.08) if id.include?("_2_") # East
      expect(h).to be_within(0.01).of(48.32) if id.include?("_3_") # North
      expect(h).to be_within(0.01).of(33.08) if id.include?("_4_") # West

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.layers.size).to eq(4)
      expect(c.layers[2].nameString.include?("m tbd")).to be(true)

      next unless id.include?("_1_") # South
      l_fenestration = 0
      l_head         = 0
      l_sill         = 0
      l_jamb         = 0
      l_grade        = 0
      l_parapet      = 0
      l_corner       = 0
      surface[:edges].values.each do |edge|
        l_fenestration += edge[:length] if edge[:type] == :fenestration
        l_head         += edge[:length] if edge[:type] == :head
        l_sill         += edge[:length] if edge[:type] == :sill
        l_jamb         += edge[:length] if edge[:type] == :jamb
        l_grade        += edge[:length] if edge[:type] == :grade
        l_grade        += edge[:length] if edge[:type] == :gradeconcave
        l_grade        += edge[:length] if edge[:type] == :gradeconvex
        l_parapet      += edge[:length] if edge[:type] == :parapet
        l_parapet      += edge[:length] if edge[:type] == :parapetconcave
        l_parapet      += edge[:length] if edge[:type] == :parapetconvex
        l_corner       += edge[:length] if edge[:type] == :cornerconcave
        l_corner       += edge[:length] if edge[:type] == :cornerconvex
      end
      expect(l_fenestration).to be_within(0.01).of(0)
      expect(l_head).to         be_within(0.01).of(12.81)
      expect(l_sill).to         be_within(0.01).of(10.98)
      expect(l_jamb).to         be_within(0.01).of(22.56)
      expect(l_grade).to        be_within(0.01).of(27.69)
      expect(l_parapet).to      be_within(0.01).of(27.69)
      expect(l_corner).to       be_within(0.01).of(6.1)
    end
  end

  it "can process DOE prototype test_smalloffice.osm (hardset)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_smalloffice.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # In the preceding test, attic floor surfaces inherit constructions from
    # adjacent office ceiling surfaces below. In this variant, attic floors
    # adjacent to NSEW perimeter office ceilings have hardset constructions
    # assigned to them (inverted). Results should remain the same as above.
    os_model.getSurfaces.each do |s|
      expect(s.space.empty?).to be(false)
      next unless s.space.get.nameString == "Attic"
      next unless s.nameString.include?("_perimeter")
      expect(s.surfaceType).to eq("Floor")
      expect(s.isConstructionDefaulted).to be(true)
      c = s.construction.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.layers.size).to eq(2)
      # layer[0]: "5/8 in. Gypsum Board"
      # layer[1]: "Typical Insulation R-35.4 1"

      construction = c.clone(os_model).to_Construction.get
      expect(construction.handle.to_s.empty?).to be(false)
      expect(construction.nameString.empty?).to be(false)
      str = "Typical Wood Joist Attic Floor R-37.04 2"
      expect(construction.nameString).to eq(str)
      construction.setName("#{s.nameString} floor")
      expect(construction.layers.size).to eq(2)
      expect(s.setConstruction(construction)).to be(true)
      expect(s.isConstructionDefaulted).to be(false)
    end

    argh[:option] = "poor (BETBG)"
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(43)
    expect(io[:edges].size).to eq(105)

    # Testing attic surfaces.
    surfaces.each do |id, surface|
      expect(surface.key?(:space)).to be(true)
      next unless surface[:space].nameString == "Attic"

      # Attic is an UNENCLOSED zone - outdoor-facing surfaces are not derated.
      expect(surface.key?(:conditioned)).to be(true)
      expect(surface[:conditioned]).to be(false)
      expect(surface.key?(:heatloss)).to be(false)
      expect(surface.key?(:ratio)).to be(false)

      expect(surface.key?(:boundary)).to be(true)
      b = surface[:boundary]
      next if b == "Outdoors"
      expect(surfaces.key?(b)).to be(true)
      expect(surfaces[b].key?(:conditioned)).to be(true)
      expect(surfaces[b][:conditioned]).to be(true)

      next if id == "Attic_floor_core"
      expect(surfaces[b].key?(:heatloss)).to be(true)
      expect(surfaces[b].key?(:ratio)).to be(true)
      h = surfaces[b][:heatloss]

      # Derated constructions?
      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.surfaceType).to eq("Floor")
      expect(s.isConstructionDefaulted).to be(false)
      c = s.construction.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      next unless c.nameString == "Attic_floor_perimeter_south floor"
      expect(c.nameString.include?("c tbd")).to be(true)
      expect(c.layers.size).to eq(2)
      expect(c.layers[0].nameString).to eq("5/8 in. Gypsum Board")
      expect(c.layers[1].nameString.include?("m tbd")).to be(true)

      expect(c.layers[1].to_MasslessOpaqueMaterial.empty?).to be(false)
      m = c.layers[1].to_MasslessOpaqueMaterial.get

      # Before derating.
      initial_R = s.filmResistance
      initial_R += 0.0994
      initial_R += 6.2348

      # After derating.
      derated_R = s.filmResistance
      derated_R += 0.0994
      derated_R += m.thermalResistance

      ratio = -(initial_R - derated_R) * 100 / initial_R
      expect(ratio).to be_within(1).of(surfaces[b][:ratio])
      # "5/8 in. Gypsum Board"        : RSi = 0,0994 m2.K/W
      # "Typical Insulation R-35.4 1" : RSi = 6,2348 m2.K/W

      surfaces.each do |id, surface|
        next unless surface.key?(:edges)
        expect(surface.key?(:heatloss)).to be(true)
        expect(surface.key?(:ratio)).to be(true)
        h = surface[:heatloss]

        s = os_model.getSurfaceByName(id)
        expect(s.empty?).to be(false)
        s = s.get
        expect(s.nameString).to eq(id)
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)

        # Testing outdoor-facing walls.
        next unless s.surfaceType == "Wall"
        expect(h).to be_within(0.01).of(51.17) if id.include?("_1_") # South
        expect(h).to be_within(0.01).of(33.08) if id.include?("_2_") # East
        expect(h).to be_within(0.01).of(48.32) if id.include?("_3_") # North
        expect(h).to be_within(0.01).of(33.08) if id.include?("_4_") # West

        c = s.construction
        expect(c.empty?).to be(false)
        c = c.get.to_Construction
        expect(c.empty?).to be(false)
        c = c.get
        expect(c.layers.size).to eq(4)
        expect(c.layers[2].nameString.include?("m tbd")).to be(true)

        next unless id.include?("_1_") # South
        l_fenestration = 0
        l_head         = 0
        l_sill         = 0
        l_jamb         = 0
        l_grade        = 0
        l_parapet      = 0
        l_corner       = 0
        surface[:edges].values.each do |edge|
          l_fenestration += edge[:length] if edge[:type] == :fenestration
          l_head         += edge[:length] if edge[:type] == :head
          l_sill         += edge[:length] if edge[:type] == :sill
          l_jamb         += edge[:length] if edge[:type] == :jamb
          l_grade        += edge[:length] if edge[:type] == :grade
          l_grade        += edge[:length] if edge[:type] == :gradeconcave
          l_grade        += edge[:length] if edge[:type] == :gradeconvex
          l_parapet      += edge[:length] if edge[:type] == :parapet
          l_parapet      += edge[:length] if edge[:type] == :parapetconcave
          l_parapet      += edge[:length] if edge[:type] == :parapetconvex
          l_corner       += edge[:length] if edge[:type] == :cornerconcave
          l_corner       += edge[:length] if edge[:type] == :cornerconvex
        end
        expect(l_fenestration).to be_within(0.01).of(0)
        expect(l_head).to         be_within(0.01).of(46.35)
        expect(l_sill).to         be_within(0.01).of(46.35)
        expect(l_jamb).to         be_within(0.01).of(46.35)
        expect(l_grade).to        be_within(0.01).of(27.69)
        expect(l_parapet).to      be_within(0.01).of(27.69)
        expect(l_corner).to       be_within(0.01).of(6.1)
      end
    end
  end

  it "can process DOE Prototype test_warehouse.osm" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    os_model.getSurfaces.each do |s|
      next unless s.outsideBoundaryCondition == "Outdoors"
      expect(s.space.empty?).to be(false)
      expect(s.isConstructionDefaulted).to be(true)
      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      id = c.nameString
      name = s.nameString
      expect(c.layers[1].to_MasslessOpaqueMaterial.empty?).to be(false)
      m = c.layers[1].to_MasslessOpaqueMaterial.get
      r = m.thermalResistance
      if name.include?("Bulk")
        expect(r).to be_within(0.01).of(1.33) if id.include?("Wall")
        expect(r).to be_within(0.01).of(1.68) if id.include?("Roof")
      else
        expect(r).to be_within(0.01).of(1.87) if id.include?("Wall")
        expect(r).to be_within(0.01).of(3.06) if id.include?("Roof")
      end
    end

    argh[:option] = "poor (BETBG)"
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)
    expect(io.key?(:edges))
    expect(io[:edges].size).to eq(300)

    ids = { a: "Office Front Wall",
            b: "Office Left Wall",
            c: "Fine Storage Roof",
            d: "Fine Storage Office Front Wall",
            e: "Fine Storage Office Left Wall",
            f: "Fine Storage Front Wall",
            g: "Fine Storage Left Wall",
            h: "Fine Storage Right Wall",
            i: "Bulk Storage Roof",
            j: "Bulk Storage Rear Wall",
            k: "Bulk Storage Left Wall",
            l: "Bulk Storage Right Wall" }.freeze

    # Testing.
    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 50.20) if id == ids[:a]
      expect(h).to be_within(0.01).of( 24.06) if id == ids[:b]
      expect(h).to be_within(0.01).of( 87.16) if id == ids[:c]
      expect(h).to be_within(0.01).of( 22.61) if id == ids[:d]
      expect(h).to be_within(0.01).of(  9.15) if id == ids[:e]
      expect(h).to be_within(0.01).of( 26.47) if id == ids[:f]
      expect(h).to be_within(0.01).of( 27.19) if id == ids[:g]
      expect(h).to be_within(0.01).of( 41.36) if id == ids[:h]
      expect(h).to be_within(0.01).of(161.02) if id == ids[:i]
      expect(h).to be_within(0.01).of( 62.28) if id == ids[:j]
      expect(h).to be_within(0.01).of(117.87) if id == ids[:k]
      expect(h).to be_within(0.01).of( 95.77) if id == ids[:l]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.layers[1].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.2).of(-53.0) if id == ids[:b]
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end
  end

  it "can process DOE Prototype test_warehouse.osm + JSON I/O" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
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

    # Despite defining the PSI set as having no thermal bridges, the "compliant"
    # PSI set on file will be considered as the building-wide default set.
    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    ids = { a: "Office Front Wall",
            b: "Office Left Wall",
            c: "Fine Storage Roof",
            d: "Fine Storage Office Front Wall",
            e: "Fine Storage Office Left Wall",
            f: "Fine Storage Front Wall",
            g: "Fine Storage Left Wall",
            h: "Fine Storage Right Wall",
            i: "Bulk Storage Roof",
            j: "Bulk Storage Rear Wall",
            k: "Bulk Storage Left Wall",
            l: "Bulk Storage Right Wall" }.freeze

    # Testing.
    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 25.90) if id == ids[:a]
      expect(h).to be_within(0.01).of( 17.41) if id == ids[:b] # 13.38 compliant
      expect(h).to be_within(0.01).of( 45.44) if id == ids[:c]
      expect(h).to be_within(0.01).of(  8.04) if id == ids[:d]
      expect(h).to be_within(0.01).of(  3.46) if id == ids[:e]
      expect(h).to be_within(0.01).of( 13.27) if id == ids[:f]
      expect(h).to be_within(0.01).of( 14.04) if id == ids[:g]
      expect(h).to be_within(0.01).of( 21.20) if id == ids[:h]
      expect(h).to be_within(0.01).of( 88.34) if id == ids[:i]
      expect(h).to be_within(0.01).of( 30.98) if id == ids[:j]
      expect(h).to be_within(0.01).of( 64.44) if id == ids[:k]
      expect(h).to be_within(0.01).of( 48.97) if id == ids[:l]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.layers[1].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.2).of(-46.0) if id == ids[:b]
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end

    # Now mimic the export functionality of the measure.
    out = JSON.pretty_generate(io)
    outP = File.join(__dir__, "../json/tbd_warehouse.out.json")
    File.open(outP, "w") { |outP| outP.puts out }

    # 2. Re-use the exported file as input for another warehouse.
    os_model2 = translator.loadModel(path)
    expect(os_model2.empty?).to be(false)
    os_model2 = os_model2.get

    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse.out.json")
    io2, surfaces = processTBD(os_model2, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    # Testing (again).
    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 25.90) if id == ids[:a]
      expect(h).to be_within(0.01).of( 17.41) if id == ids[:b]
      expect(h).to be_within(0.01).of( 45.44) if id == ids[:c]
      expect(h).to be_within(0.01).of(  8.04) if id == ids[:d]
      expect(h).to be_within(0.01).of(  3.46) if id == ids[:e]
      expect(h).to be_within(0.01).of( 13.27) if id == ids[:f]
      expect(h).to be_within(0.01).of( 14.04) if id == ids[:g]
      expect(h).to be_within(0.01).of( 21.20) if id == ids[:h]
      expect(h).to be_within(0.01).of( 88.34) if id == ids[:i]
      expect(h).to be_within(0.01).of( 30.98) if id == ids[:j]
      expect(h).to be_within(0.01).of( 64.44) if id == ids[:k]
      expect(h).to be_within(0.01).of( 48.97) if id == ids[:l]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.layers[1].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.2).of(-46.0) if id == ids[:b]
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end

    # Now mimic (again) the export functionality of the measure
    out2 = JSON.pretty_generate(io2)
    outP2 = File.join(__dir__, "../json/tbd_warehouse2.out.json")
    File.open(outP2, "w") { |outP2| outP2.puts out2 }

    # Both output files should be the same ...
    # cmd = "diff #{outP} #{outP2}"
    # expect(system( cmd )).to be(true)
    # expect(FileUtils).to be_identical(outP, outP2)
    expect(FileUtils.identical?(outP, outP2)).to be(true)
  end

  it "can process DOE Prototype test_warehouse.osm + JSON I/O (2)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
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

    # Despite defining the PSI set as having no thermal bridges, the "compliant"
    # PSI set on file will be considered as the building-wide default set.
    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse1.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    ids = { a: "Office Front Wall",
            b: "Office Left Wall",
            c: "Fine Storage Roof",
            d: "Fine Storage Office Front Wall",
            e: "Fine Storage Office Left Wall",
            f: "Fine Storage Front Wall",
            g: "Fine Storage Left Wall",
            h: "Fine Storage Right Wall",
            i: "Bulk Storage Roof",
            j: "Bulk Storage Rear Wall",
            k: "Bulk Storage Left Wall",
            l: "Bulk Storage Right Wall" }.freeze

    # Testing.
    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 25.90) if id == ids[:a]
      expect(h).to be_within(0.01).of( 14.55) if id == ids[:b] # 13.38 compliant
      expect(h).to be_within(0.01).of( 45.44) if id == ids[:c]
      expect(h).to be_within(0.01).of(  8.04) if id == ids[:d]
      expect(h).to be_within(0.01).of(  3.46) if id == ids[:e]
      expect(h).to be_within(0.01).of( 13.27) if id == ids[:f]
      expect(h).to be_within(0.01).of( 14.04) if id == ids[:g]
      expect(h).to be_within(0.01).of( 21.20) if id == ids[:h]
      expect(h).to be_within(0.01).of( 88.34) if id == ids[:i]
      expect(h).to be_within(0.01).of( 30.98) if id == ids[:j]
      expect(h).to be_within(0.01).of( 64.44) if id == ids[:k]
      expect(h).to be_within(0.01).of( 48.97) if id == ids[:l]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.layers[1].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.2).of(-41.9) if id == ids[:b]
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end

    # Now mimic the export functionality of the measure
    out = JSON.pretty_generate(io)
    outP = File.join(__dir__, "../json/tbd_warehouse1.out.json")
    File.open(outP, "w") { |outP| outP.puts out }

    # 2. Re-use the exported file as input for another warehouse
    os_model2 = translator.loadModel(path)
    expect(os_model2.empty?).to be(false)
    os_model2 = os_model2.get

    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse1.out.json")
    io2, surfaces = processTBD(os_model2, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.2).of(-41.9) if id == ids[:b]
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end

    # Now mimic (again) the export functionality of the measure
    out2 = JSON.pretty_generate(io2)
    outP2 = File.join(__dir__, "../json/tbd_warehouse3.out.json")
    File.open(outP2, "w") { |outP2| outP2.puts out2 }

    # Both output files should be the same ...
    # cmd = "diff #{outP} #{outP2}"
    # expect(system( cmd )).to be(true)
    # expect(FileUtils).to be_identical(outP, outP2)
    expect(FileUtils.identical?(outP, outP2)).to be(true)
  end

  it "can process test_seb.osm" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Testing min/max cooling/heating setpoints (a tad redundant).
    setpoints = heatingTemperatureSetpoints?(os_model)
    setpoints = coolingTemperatureSetpoints?(os_model) || setpoints
    expect(setpoints).to be(true)
    airloops = airLoopsHVAC?(os_model)
    expect(airloops).to be(true)

    os_model.getSpaces.each do |space|
      expect(space.thermalZone.empty?).to be(false)
      zone = space.thermalZone.get
      heating, _ = maxHeatScheduledSetpoint(zone)
      cooling, _ = minCoolScheduledSetpoint(zone)
      if zone.nameString == "Level 0 Ceiling Plenum Zone"
        expect(plenum?(space, airloops, setpoints)).to be(false)
        expect(heating.nil?).to be(true)
        expect(cooling.nil?).to be(true)
        next
      end
      expect(plenum?(space, airloops, setpoints)).to be(false)
      expect(heating).to be_within(0.1).of(22.1)
      expect(cooling).to be_within(0.1).of(22.8)
    end

    os_model.getSurfaces.each do |s|
      expect(s.space.empty?).to be(false)
      expect(s.isConstructionDefaulted).to be(false)
      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      id = c.nameString
      name = s.nameString
      if s.outsideBoundaryCondition == "Outdoors"
        expect(c.layers.size).to be(4)
        expect(c.layers[2].to_StandardOpaqueMaterial.empty?).to be(false)
        m = c.layers[2].to_StandardOpaqueMaterial.get
        r = m.thickness / m.thermalConductivity
        expect(r).to be_within(0.01).of(1.47) if s.surfaceType == "Wall"
        expect(r).to be_within(0.01).of(5.08) if s.surfaceType == "RoofCeiling"
      elsif s.outsideBoundaryCondition == "Surface"
        next unless s.surfaceType == "RoofCeiling"
        expect(c.layers.size).to be(1)
        expect(c.layers[0].to_StandardOpaqueMaterial.empty?).to be(false)
        m = c.layers[0].to_StandardOpaqueMaterial.get
        r = m.thickness / m.thermalConductivity
        expect(r).to be_within(0.01).of(0.12)
      end

      expect(s.space.empty?).to be(false)
      space = s.space.get
      nom = space.nameString
      expect(space.thermalZone.empty?).to be(false)
      zone = space.thermalZone.get
      t, dual = maxHeatScheduledSetpoint(zone)
      expect(t).to be_within(0.1).of(22.1) unless nom.include?("Plenum")
      next unless nom.include?("Plenum")
      expect(t).to be(nil)
      expect(zone.isPlenum).to be(false)
      expect(zone.canBePlenum).to be(true)
      expect(s.surfaceType).to_not eq("Floor")                     # no floors !
      expect(s.surfaceType).to eq("Wall").or eq("RoofCeiling")
    end

    argh[:option] = "poor (BETBG)"
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    surfaces.each do |id, surface|
      expect(surface.key?(:conditioned)).to be(true)
      next unless surface[:conditioned]
      expect(surface.key?(:heating)).to be(true)
      expect(surface.key?(:cooling)).to be(true)
    end

    ids = { a: "Entryway  Wall 4",
            b: "Entryway  Wall 5",
            c: "Entryway  Wall 6",
            d: "Entry way  DroppedCeiling",
            e: "Utility1 Wall 1",
            f: "Utility1 Wall 5",
            g: "Utility 1 DroppedCeiling",
            h: "Smalloffice 1 Wall 1",
            i: "Smalloffice 1 Wall 2",
            j: "Smalloffice 1 Wall 6",
            k: "Small office 1 DroppedCeiling",
            l: "Openarea 1 Wall 3",
            m: "Openarea 1 Wall 4",
            n: "Openarea 1 Wall 5",
            o: "Openarea 1 Wall 6",
            p: "Openarea 1 Wall 7",
            q: "Open area 1 DroppedCeiling" }.freeze

    # If one simulates the test_seb.osm, EnergyPlus reports the plenum as an
    # UNCONDITIONED zone, so it's more akin (at least initially) to an attic:
    # it's vented (infiltration) and there's necessarily heat conduction with
    # the outdoors and with the zone below. But otherwise, it's a dead zone
    # (no heating/cooling, no setpoints, not detailed in the eplusout.bnd
    # file), etc. The zone is linked to a "Plenum" zonelist (in the IDF), relied
    # on only to set infiltration. What leads to some confusion is that the
    # outdoor-facing surfaces (roof & walls) of the "plenum" are insulated,
    # while the dropped ceiling separating the occupied zone below is simply
    # that, lightweight uninsulated ceiling tiles (a situation more evocative
    # of a true plenum). It may be indeed OK to model the plenum this way -
    # there will be plenty of heat transfer between the plenum and the zone
    # below due to the poor thermal resistance of the ceiling tiles. And if the
    # infiltration rates are low enough (unlike an attic), then simulation
    # results may end up being quite consistent with a true plenum. TBD will
    # nonethless end up tagging the SEB plenum as an UNCONDITIONED space, and
    # as a consequence will (partially) derate the uninsulated ceiling tiles.
    # Fortunately, TBD relies on a proportionate derating solution whereby the
    # insulated wall will be the main focus of the derating step.
    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 6.43) if id == ids[:a]
      expect(h).to be_within(0.01).of(11.18) if id == ids[:b]
      expect(h).to be_within(0.01).of( 4.56) if id == ids[:c]
      expect(h).to be_within(0.01).of( 0.42) if id == ids[:d]
      expect(h).to be_within(0.01).of(12.66) if id == ids[:e]
      expect(h).to be_within(0.01).of(12.59) if id == ids[:f]
      expect(h).to be_within(0.01).of( 0.50) if id == ids[:g]
      expect(h).to be_within(0.01).of(14.06) if id == ids[:h]
      expect(h).to be_within(0.01).of( 9.04) if id == ids[:i]
      expect(h).to be_within(0.01).of( 8.75) if id == ids[:j]
      expect(h).to be_within(0.01).of( 0.53) if id == ids[:k]
      expect(h).to be_within(0.01).of( 5.06) if id == ids[:l]
      expect(h).to be_within(0.01).of( 6.25) if id == ids[:m]
      expect(h).to be_within(0.01).of( 9.04) if id == ids[:n]
      expect(h).to be_within(0.01).of( 6.74) if id == ids[:o]
      expect(h).to be_within(0.01).of( 4.32) if id == ids[:p]
      expect(h).to be_within(0.01).of( 0.76) if id == ids[:q]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      i = 0
      i = 2 if s.outsideBoundaryCondition == "Outdoors"
      expect(c.layers[i].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.1).of(-36.74) if id == ids[:a]
        expect(surface[:ratio]).to be_within(0.1).of(-34.61) if id == ids[:b]
        expect(surface[:ratio]).to be_within(0.1).of(-33.57) if id == ids[:c]
        expect(surface[:ratio]).to be_within(0.1).of( -0.14) if id == ids[:d]
        expect(surface[:ratio]).to be_within(0.1).of(-35.09) if id == ids[:e]
        expect(surface[:ratio]).to be_within(0.1).of(-35.12) if id == ids[:f]
        expect(surface[:ratio]).to be_within(0.1).of( -0.13) if id == ids[:g]
        expect(surface[:ratio]).to be_within(0.1).of(-39.75) if id == ids[:h]
        expect(surface[:ratio]).to be_within(0.1).of(-39.74) if id == ids[:i]
        expect(surface[:ratio]).to be_within(0.1).of(-39.90) if id == ids[:j]
        expect(surface[:ratio]).to be_within(0.1).of( -0.13) if id == ids[:k]
        expect(surface[:ratio]).to be_within(0.1).of(-27.78) if id == ids[:l]
        expect(surface[:ratio]).to be_within(0.1).of(-31.66) if id == ids[:m]
        expect(surface[:ratio]).to be_within(0.1).of(-28.44) if id == ids[:n]
        expect(surface[:ratio]).to be_within(0.1).of(-30.85) if id == ids[:o]
        expect(surface[:ratio]).to be_within(0.1).of(-28.78) if id == ids[:p]
        expect(surface[:ratio]).to be_within(0.1).of( -0.09) if id == ids[:q]

        next unless id == ids[:a]
        s = os_model.getSurfaceByName(id)
        expect(s.empty?).to be(false)
        s = s.get
        expect(s.nameString).to eq(id)
        expect(s.surfaceType).to eq("Wall")
        expect(s.isConstructionDefaulted).to be(false)
        c = s.construction.get.to_Construction
        expect(c.empty?).to be(false)
        c = c.get
        expect(c.nameString.include?("c tbd")).to be(true)
        expect(c.layers.size).to eq(4)
        expect(c.layers[2].nameString.include?("m tbd")).to be(true)
        expect(c.layers[2].to_StandardOpaqueMaterial.empty?).to be(false)
        m = c.layers[2].to_StandardOpaqueMaterial.get

        initial_R = s.filmResistance + 2.4674
        derated_R = s.filmResistance + 0.9931
        derated_R += m.thickness / m.thermalConductivity

        ratio = -(initial_R - derated_R) * 100 / initial_R
        expect(ratio).to be_within(1).of(surfaces[id][:ratio])
      else
        if surface[:boundary].downcase == "outdoors"
          expect(surface[:conditioned]).to be(false)
        end
      end
    end
  end

  it "can take in custom (expansion) joints as thermal bridges" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # TBD will automatically tag as a (mild) "transition" any shared edge
    # between 2x linked walls that more or less share the same 3D plane. An
    # edge shared between 2x roof surfaces will equally be tagged as a
    # "transition" edge. By default, transition edges are set @0 W/K.m i.e., no
    # derating occurs. Although structural expansion joints or roof curbs are
    # not as commonly encountered as mild transitions, they do constitute
    # significant thermal bridges (to consider). As such "joints" remain
    # undistinguishable from transition edges when parsing OSM geometry, the
    # solution tested here illustrates how users can override default
    # "transition" tags via JSON input files.
    #
    # The "tbd_warehouse6.json" file identifies 2x edges in the US DOE
    # warehouse prototype building that TBD tags as (mild) transitions by
    # default. Both edges concern the "Fine Storage" space (likely as a means
    # to ensure surface convexity in the EnergyPlus model). The "ok" PSI set
    # holds a single "joint" PSI value of 0.9 W/K per meter (let's assume both
    # edges are significant expansion joints, rather than modelling artifacts).
    # Each "expansion joint" here represents 4.27 m x 0.9 W/K per m = 3.84 W/K.
    # As wall constructions are the same for all 4x walls concerned, each wall
    # inherits 1/2 of the extra heat loss from each joint i.e., 1.92 W/K.
    #
    #   "psis": [
    #     {
    #       "id": "ok",
    #       "joint": 0.9
    #     }
    #   ],
    #   "edges": [
    #     {
    #       "psi": "ok",
    #       "type": "joint",
    #       "surfaces": [
    #         "Fine Storage Front Wall",
    #         "Fine Storage Office Front Wall"
    #       ]
    #     },
    #     {
    #       "psi": "ok",
    #       "type": "joint",
    #       "surfaces": [
    #         "Fine Storage Left Wall",
    #         "Fine Storage Office Left Wall"
    #       ]
    #     }
    #   ]
    # }

    argh[:option] = "poor (BETBG)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse6.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    ids = { a: "Office Front Wall",
            b: "Office Left Wall",
            c: "Fine Storage Roof",
            d: "Fine Storage Office Front Wall",
            e: "Fine Storage Office Left Wall",
            f: "Fine Storage Front Wall",
            g: "Fine Storage Left Wall",
            h: "Fine Storage Right Wall",
            i: "Bulk Storage Roof",
            j: "Bulk Storage Rear Wall",
            k: "Bulk Storage Left Wall",
            l: "Bulk Storage Right Wall" }.freeze

    # Testing.
    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 50.20) if id == ids[:a]
      expect(h).to be_within(0.01).of( 24.06) if id == ids[:b]
      expect(h).to be_within(0.01).of( 87.16) if id == ids[:c]
      expect(h).to be_within(0.01).of( 24.53) if id == ids[:d] # 22.61 + 1.92
      expect(h).to be_within(0.01).of( 11.07) if id == ids[:e] #  9.15 + 1.92
      expect(h).to be_within(0.01).of( 28.39) if id == ids[:f] # 26.47 + 1.92
      expect(h).to be_within(0.01).of( 29.11) if id == ids[:g] # 27.19 + 1.92
      expect(h).to be_within(0.01).of( 41.36) if id == ids[:h]
      expect(h).to be_within(0.01).of(161.02) if id == ids[:i]
      expect(h).to be_within(0.01).of( 62.28) if id == ids[:j]
      expect(h).to be_within(0.01).of(117.87) if id == ids[:k]
      expect(h).to be_within(0.01).of( 95.77) if id == ids[:l]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      expect(c.layers[1].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.2).of(-44.13) if id == ids[:a]
        expect(surface[:ratio]).to be_within(0.2).of(-53.02) if id == ids[:b]
        expect(surface[:ratio]).to be_within(0.2).of(-15.60) if id == ids[:c]
        expect(surface[:ratio]).to be_within(0.2).of(-26.10) if id == ids[:d]
        expect(surface[:ratio]).to be_within(0.2).of(-30.86) if id == ids[:e]
        expect(surface[:ratio]).to be_within(0.2).of(-21.26) if id == ids[:f]
        expect(surface[:ratio]).to be_within(0.2).of(-20.65) if id == ids[:g]
        expect(surface[:ratio]).to be_within(0.2).of(-20.51) if id == ids[:h]
        expect(surface[:ratio]).to be_within(0.2).of( -7.29) if id == ids[:i]
        expect(surface[:ratio]).to be_within(0.2).of(-14.93) if id == ids[:j]
        expect(surface[:ratio]).to be_within(0.2).of(-19.02) if id == ids[:k]
        expect(surface[:ratio]).to be_within(0.2).of(-15.09) if id == ids[:l]
      else
        expect(surface[:boundary].downcase).to_not eq("outdoors")
      end
    end
  end

  it "can process test_seb.osm (0 W/K per m)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "(non thermal bridging)"
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    surfaces.each do |id, surface|
      expect(surface.key?(:conditioned)).to be(true)
      next unless surface[:conditioned]
      expect(surface.key?(:heating)).to be(true)
      expect(surface.key?(:cooling)).to be(true)
    end

    # Since all PSI values = 0, we're not expecting any derated surfaces
    surfaces.values.each do |surface|
      expect(surface.key?(:ratio)).to be(false)
    end
  end

  it "can process test_seb.osm (0 W/K per m) with JSON" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    # As the :building PSI set on file remains "(non thermal bridging)", one
    # should not expect differences in results, i.e. derating shouldn't occur.
    surfaces.values.each do |surface|
      expect(surface.key?(:ratio)).to be(false)
    end
  end

  it "can process test_seb.osm (0 W/K per m) with JSON (non-0)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n0.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    ids = { a: "Entryway  Wall 4",
            b: "Entryway  Wall 5",
            c: "Entryway  Wall 6",
            d: "Entry way  DroppedCeiling",
            e: "Utility1 Wall 1",
            f: "Utility1 Wall 5",
            g: "Utility 1 DroppedCeiling",
            h: "Smalloffice 1 Wall 1",
            i: "Smalloffice 1 Wall 2",
            j: "Smalloffice 1 Wall 6",
            k: "Small office 1 DroppedCeiling",
            l: "Openarea 1 Wall 3",
            m: "Openarea 1 Wall 4",
            n: "Openarea 1 Wall 5",
            o: "Openarea 1 Wall 6",
            p: "Openarea 1 Wall 7",
            q: "Open area 1 DroppedCeiling" }.freeze

    # The :building PSI set on file "compliant" supersedes the argh[:option]
    # "(non thermal bridging)", so one should expect differences in results,
    # i.e. derating should occur. The next 2 tests:
    #   1. setting both argh[:option] & file :building to "compliant"
    #   2. setting argh[:option] to "compliant" + removing :building from file
    # ... all 3x cases should yield the same results.
    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 3.62) if id == ids[:a]
      expect(h).to be_within(0.01).of( 6.28) if id == ids[:b]
      expect(h).to be_within(0.01).of( 2.62) if id == ids[:c]
      expect(h).to be_within(0.01).of( 0.17) if id == ids[:d]
      expect(h).to be_within(0.01).of( 7.13) if id == ids[:e]
      expect(h).to be_within(0.01).of( 7.09) if id == ids[:f]
      expect(h).to be_within(0.01).of( 0.20) if id == ids[:g]
      expect(h).to be_within(0.01).of( 7.94) if id == ids[:h]
      expect(h).to be_within(0.01).of( 5.17) if id == ids[:i]
      expect(h).to be_within(0.01).of( 5.01) if id == ids[:j]
      expect(h).to be_within(0.01).of( 0.22) if id == ids[:k]
      expect(h).to be_within(0.01).of( 2.47) if id == ids[:l]
      expect(h).to be_within(0.01).of( 3.11) if id == ids[:m]
      expect(h).to be_within(0.01).of( 4.43) if id == ids[:n]
      expect(h).to be_within(0.01).of( 3.35) if id == ids[:o]
      expect(h).to be_within(0.01).of( 2.12) if id == ids[:p]
      expect(h).to be_within(0.01).of( 0.31) if id == ids[:q]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      i = 0
      i = 2 if s.outsideBoundaryCondition == "Outdoors"
      expect(c.layers[i].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.1).of(-28.93) if id == ids[:a]
        expect(surface[:ratio]).to be_within(0.1).of(-26.61) if id == ids[:b]
        expect(surface[:ratio]).to be_within(0.1).of(-25.82) if id == ids[:c]
        expect(surface[:ratio]).to be_within(0.1).of( -0.06) if id == ids[:d]
        expect(surface[:ratio]).to be_within(0.1).of(-27.14) if id == ids[:e]
        expect(surface[:ratio]).to be_within(0.1).of(-27.18) if id == ids[:f]
        expect(surface[:ratio]).to be_within(0.1).of( -0.05) if id == ids[:g]
        expect(surface[:ratio]).to be_within(0.1).of(-32.40) if id == ids[:h]
        expect(surface[:ratio]).to be_within(0.1).of(-32.58) if id == ids[:i]
        expect(surface[:ratio]).to be_within(0.1).of(-32.77) if id == ids[:j]
        expect(surface[:ratio]).to be_within(0.1).of( -0.05) if id == ids[:k]
        expect(surface[:ratio]).to be_within(0.1).of(-18.14) if id == ids[:l]
        expect(surface[:ratio]).to be_within(0.1).of(-21.97) if id == ids[:m]
        expect(surface[:ratio]).to be_within(0.1).of(-18.77) if id == ids[:n]
        expect(surface[:ratio]).to be_within(0.1).of(-21.14) if id == ids[:o]
        expect(surface[:ratio]).to be_within(0.1).of(-19.10) if id == ids[:p]
        expect(surface[:ratio]).to be_within(0.1).of( -0.04) if id == ids[:q]

        next unless id == ids[:a]
        s = os_model.getSurfaceByName(id)
        expect(s.empty?).to be(false)
        s = s.get
        expect(s.nameString).to eq(id)
        expect(s.surfaceType).to eq("Wall")
        expect(s.isConstructionDefaulted).to be(false)
        c = s.construction.get.to_Construction
        expect(c.empty?).to be(false)
        c = c.get
        expect(c.nameString.include?("c tbd")).to be(true)
        expect(c.layers.size).to eq(4)
        expect(c.layers[2].nameString.include?("m tbd")).to be(true)
        expect(c.layers[2].to_StandardOpaqueMaterial.empty?).to be(false)
        m = c.layers[2].to_StandardOpaqueMaterial.get

        initial_R = s.filmResistance + 2.4674
        derated_R = s.filmResistance + 0.9931
        derated_R += m.thickness / m.thermalConductivity

        ratio = -(initial_R - derated_R) * 100 / initial_R
        expect(ratio).to be_within(1).of(surfaces[id][:ratio])
      else
        if surface[:boundary].downcase == "outdoors"
          expect(surface[:conditioned]).to be(false)
        end
      end
    end
  end

  it "can process test_seb.osm (0 W/K per m) with JSON (non-0) 2" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # 1. setting both PSI option & file :building to "compliant"
    argh[:option] = "compliant" # instead of "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n0.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    ids = { a: "Entryway  Wall 4",
            b: "Entryway  Wall 5",
            c: "Entryway  Wall 6",
            d: "Entry way  DroppedCeiling",
            e: "Utility1 Wall 1",
            f: "Utility1 Wall 5",
            g: "Utility 1 DroppedCeiling",
            h: "Smalloffice 1 Wall 1",
            i: "Smalloffice 1 Wall 2",
            j: "Smalloffice 1 Wall 6",
            k: "Small office 1 DroppedCeiling",
            l: "Openarea 1 Wall 3",
            m: "Openarea 1 Wall 4",
            n: "Openarea 1 Wall 5",
            o: "Openarea 1 Wall 6",
            p: "Openarea 1 Wall 7",
            q: "Open area 1 DroppedCeiling" }.freeze

    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 3.62) if id == ids[:a]
      expect(h).to be_within(0.01).of( 6.28) if id == ids[:b]
      expect(h).to be_within(0.01).of( 2.62) if id == ids[:c]
      expect(h).to be_within(0.01).of( 0.17) if id == ids[:d]
      expect(h).to be_within(0.01).of( 7.13) if id == ids[:e]
      expect(h).to be_within(0.01).of( 7.09) if id == ids[:f]
      expect(h).to be_within(0.01).of( 0.20) if id == ids[:g]
      expect(h).to be_within(0.01).of( 7.94) if id == ids[:h]
      expect(h).to be_within(0.01).of( 5.17) if id == ids[:i]
      expect(h).to be_within(0.01).of( 5.01) if id == ids[:j]
      expect(h).to be_within(0.01).of( 0.22) if id == ids[:k]
      expect(h).to be_within(0.01).of( 2.47) if id == ids[:l]
      expect(h).to be_within(0.01).of( 3.11) if id == ids[:m]
      expect(h).to be_within(0.01).of( 4.43) if id == ids[:n]
      expect(h).to be_within(0.01).of( 3.35) if id == ids[:o]
      expect(h).to be_within(0.01).of( 2.12) if id == ids[:p]
      expect(h).to be_within(0.01).of( 0.31) if id == ids[:q]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      i = 0
      i = 2 if s.outsideBoundaryCondition == "Outdoors"
      expect(c.layers[i].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.1).of(-28.93) if id == ids[:a]
        expect(surface[:ratio]).to be_within(0.1).of(-26.61) if id == ids[:b]
        expect(surface[:ratio]).to be_within(0.1).of(-25.82) if id == ids[:c]
        expect(surface[:ratio]).to be_within(0.1).of( -0.06) if id == ids[:d]
        expect(surface[:ratio]).to be_within(0.1).of(-27.14) if id == ids[:e]
        expect(surface[:ratio]).to be_within(0.1).of(-27.18) if id == ids[:f]
        expect(surface[:ratio]).to be_within(0.1).of( -0.05) if id == ids[:g]
        expect(surface[:ratio]).to be_within(0.1).of(-32.40) if id == ids[:h]
        expect(surface[:ratio]).to be_within(0.1).of(-32.58) if id == ids[:i]
        expect(surface[:ratio]).to be_within(0.1).of(-32.77) if id == ids[:j]
        expect(surface[:ratio]).to be_within(0.1).of( -0.05) if id == ids[:k]
        expect(surface[:ratio]).to be_within(0.1).of(-18.14) if id == ids[:l]
        expect(surface[:ratio]).to be_within(0.1).of(-21.97) if id == ids[:m]
        expect(surface[:ratio]).to be_within(0.1).of(-18.77) if id == ids[:n]
        expect(surface[:ratio]).to be_within(0.1).of(-21.14) if id == ids[:o]
        expect(surface[:ratio]).to be_within(0.1).of(-19.10) if id == ids[:p]
        expect(surface[:ratio]).to be_within(0.1).of( -0.04) if id == ids[:q]

        next unless id == ids[:a]
        s = os_model.getSurfaceByName(id)
        expect(s.empty?).to be(false)
        s = s.get
        expect(s.nameString).to eq(id)
        expect(s.surfaceType).to eq("Wall")
        expect(s.isConstructionDefaulted).to be(false)
        c = s.construction.get.to_Construction
        expect(c.empty?).to be(false)
        c = c.get
        expect(c.nameString.include?("c tbd")).to be(true)
        expect(c.layers.size).to eq(4)
        expect(c.layers[2].nameString.include?("m tbd")).to be(true)
        expect(c.layers[2].to_StandardOpaqueMaterial.empty?).to be(false)
        m = c.layers[2].to_StandardOpaqueMaterial.get

        initial_R = s.filmResistance + 2.4674
        derated_R = s.filmResistance + 0.9931
        derated_R += m.thickness / m.thermalConductivity

        ratio = -(initial_R - derated_R) * 100 / initial_R
        expect(ratio).to be_within(1).of(surfaces[id][:ratio])
      else
        if surface[:boundary].downcase == "outdoors"
          expect(surface[:conditioned]).to be(false)
        end
      end
    end
  end

  it "can process test_seb.osm (0 W/K per m) with JSON (non-0) 3" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # 2. setting PSI set to "compliant" while removing the :building from file
    argh[:option] = "compliant" # instead of "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n1.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    ids = { a: "Entryway  Wall 4",
            b: "Entryway  Wall 5",
            c: "Entryway  Wall 6",
            d: "Entry way  DroppedCeiling",
            e: "Utility1 Wall 1",
            f: "Utility1 Wall 5",
            g: "Utility 1 DroppedCeiling",
            h: "Smalloffice 1 Wall 1",
            i: "Smalloffice 1 Wall 2",
            j: "Smalloffice 1 Wall 6",
            k: "Small office 1 DroppedCeiling",
            l: "Openarea 1 Wall 3",
            m: "Openarea 1 Wall 4",
            n: "Openarea 1 Wall 5",
            o: "Openarea 1 Wall 6",
            p: "Openarea 1 Wall 7",
            q: "Open area 1 DroppedCeiling" }.freeze

    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 3.62) if id == ids[:a]
      expect(h).to be_within(0.01).of( 6.28) if id == ids[:b]
      expect(h).to be_within(0.01).of( 2.62) if id == ids[:c]
      expect(h).to be_within(0.01).of( 0.17) if id == ids[:d]
      expect(h).to be_within(0.01).of( 7.13) if id == ids[:e]
      expect(h).to be_within(0.01).of( 7.09) if id == ids[:f]
      expect(h).to be_within(0.01).of( 0.20) if id == ids[:g]
      expect(h).to be_within(0.01).of( 7.94) if id == ids[:h]
      expect(h).to be_within(0.01).of( 5.17) if id == ids[:i]
      expect(h).to be_within(0.01).of( 5.01) if id == ids[:j]
      expect(h).to be_within(0.01).of( 0.22) if id == ids[:k]
      expect(h).to be_within(0.01).of( 2.47) if id == ids[:l]
      expect(h).to be_within(0.01).of( 3.11) if id == ids[:m]
      expect(h).to be_within(0.01).of( 4.43) if id == ids[:n]
      expect(h).to be_within(0.01).of( 3.35) if id == ids[:o]
      expect(h).to be_within(0.01).of( 2.12) if id == ids[:p]
      expect(h).to be_within(0.01).of( 0.31) if id == ids[:q]

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      i = 0
      i = 2 if s.outsideBoundaryCondition == "Outdoors"
      expect(c.layers[i].nameString.include?("m tbd")).to be(true)
    end

    surfaces.each do |id, surface|
      if surface.key?(:ratio)
        # ratio  = format "%3.1f", surface[:ratio]
        # name   = id.rjust(15, " ")
        # puts "#{name} RSi derated by #{ratio}%"
        expect(surface[:ratio]).to be_within(0.1).of(-28.93) if id == ids[:a]
        expect(surface[:ratio]).to be_within(0.1).of(-26.61) if id == ids[:b]
        expect(surface[:ratio]).to be_within(0.1).of(-25.82) if id == ids[:c]
        expect(surface[:ratio]).to be_within(0.1).of( -0.06) if id == ids[:d]
        expect(surface[:ratio]).to be_within(0.1).of(-27.14) if id == ids[:e]
        expect(surface[:ratio]).to be_within(0.1).of(-27.18) if id == ids[:f]
        expect(surface[:ratio]).to be_within(0.1).of( -0.05) if id == ids[:g]
        expect(surface[:ratio]).to be_within(0.1).of(-32.40) if id == ids[:h]
        expect(surface[:ratio]).to be_within(0.1).of(-32.58) if id == ids[:i]
        expect(surface[:ratio]).to be_within(0.1).of(-32.77) if id == ids[:j]
        expect(surface[:ratio]).to be_within(0.1).of( -0.05) if id == ids[:k]
        expect(surface[:ratio]).to be_within(0.1).of(-18.14) if id == ids[:l]
        expect(surface[:ratio]).to be_within(0.1).of(-21.97) if id == ids[:m]
        expect(surface[:ratio]).to be_within(0.1).of(-18.77) if id == ids[:n]
        expect(surface[:ratio]).to be_within(0.1).of(-21.14) if id == ids[:o]
        expect(surface[:ratio]).to be_within(0.1).of(-19.10) if id == ids[:p]
        expect(surface[:ratio]).to be_within(0.1).of( -0.04) if id == ids[:q]

        next unless id == ids[:a]
        s = os_model.getSurfaceByName(id)
        expect(s.empty?).to be(false)
        s = s.get
        expect(s.nameString).to eq(id)
        expect(s.surfaceType).to eq("Wall")
        expect(s.isConstructionDefaulted).to be(false)
        c = s.construction.get.to_Construction
        expect(c.empty?).to be(false)
        c = c.get
        expect(c.nameString.include?("c tbd")).to be(true)
        expect(c.layers.size).to eq(4)
        expect(c.layers[2].nameString.include?("m tbd")).to be(true)
        expect(c.layers[2].to_StandardOpaqueMaterial.empty?).to be(false)
        m = c.layers[2].to_StandardOpaqueMaterial.get

        initial_R = s.filmResistance + 2.4674
        derated_R = s.filmResistance + 0.9931
        derated_R += m.thickness / m.thermalConductivity

        ratio = -(initial_R - derated_R) * 100 / initial_R
        expect(ratio).to be_within(1).of(surfaces[id][:ratio])
      else
        if surface[:boundary].downcase == "outdoors"
          expect(surface[:conditioned]).to be(false)
        end
      end
    end
  end

  it "can process testing JSON surface KHI entries" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n2.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    # As the :building PSI set on file remains "(non thermal bridging)", one
    # should not expect differences in results, i.e. derating shouldn't occur.
    # However, the JSON file holds KHI entries for "Entryway  Wall 2" :
    # 3x "columns" @0.5 W/K + 4x supports @0.5W/K = 3.5 W/K
    surfaces.values.each do |surface|
      next unless surface.key?(:ratio)
      expect(surface[:heatloss]).to be_within(0.01).of(3.5)
    end
  end

  it "can process JSON surface KHI & PSI entries" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "(non thermal bridging)"      # no :building PSI set on file
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n3.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)
    expect(io.key?(:building)).to be(true) # despite no being on file - good
    expect(io[:building].key?(:psi)).to be(true)
    expect(io[:building][:psi]).to eq("(non thermal bridging)")

    # As the :building PSI set on file remains "(non thermal bridging)", one
    # should not expect differences in results, i.e. derating shouldn't occur
    # for most surfaces. However, the JSON file holds KHI entries for
    # "Entryway  Wall 5":
    # 3x "columns" @0.5 W/K + 4x supports @0.5W/K = 3.5 W/K (as in case above),
    # and a "good" PSI set (:parapet, of 0.5 W/K per m).
    nom1 = "Entryway  Wall 5"
    nom2 = "Entry way  DroppedCeiling"
    surfaces.each do |id, surface|
      next unless surface.key?(:ratio)
      expect(id).to eq(nom1).or eq(nom2)
      expect(surface[:heatloss]).to be_within(0.01).of(5.17) if id == nom1
      expect(surface[:heatloss]).to be_within(0.01).of(0.13) if id == nom2
      expect(surface.key?(:edges)).to be(true)
      expect(surface[:edges].size).to eq(10) if id == nom1
      expect(surface[:edges].size).to eq(6) if id == nom2
    end
    expect(io.key?(:edges)).to be(true)
    expect(io[:edges].size).to eq(80)

    # The JSON input file (tbd_seb_n3.json) holds 2x PSI sets:
    #   - "good" for "Entryway  Wall 5"
    #   - "compliant" (ignored)
    #
    # The PSI set "good" only holds non-zero PSI values for:
    #   - :rimjoist (there are none for "Entryway  Wall 5")
    #   - :parapet (a single edge shared with "Entry way  DroppedCeiling")
    #
    # Only those 2x surfaces will be derated. The following counters track the
    # total number of edges delineating either derated surfaces that contribute
    # in derating their insulation materials i.e. found in the "good" PSI set.
    nb_rimjoist_edges     = 0
    nb_parapet_edges      = 0
    nb_fenestration_edges = 0
    nb_head_edges         = 0
    nb_sill_edges         = 0
    nb_jamb_edges         = 0
    nb_corners            = 0
    nb_concave_edges      = 0
    nb_convex_edges       = 0
    nb_balcony_edges      = 0
    nb_party_edges        = 0
    nb_grade_edges        = 0
    nb_transition_edges   = 0

    io[:edges].each do |edge|
      expect(edge.key?(:psi)).to be(true)
      expect(edge.key?(:type)).to be(true)
      expect(edge.key?(:length)).to be(true)
      expect(edge.key?(:surfaces)).to be(true)
      valid = edge[:surfaces].include?(nom1) || edge[:surfaces].include?(nom2)
      next unless valid
      s = {}
      io[:psis].each { |set| s = set if set[:id] == edge[:psi] }
      next if s.empty?

      expect(s.is_a?(Hash)).to be(true)

      t = edge[:type]
      nb_rimjoist_edges     += 1 if t == :rimjoist
      nb_rimjoist_edges     += 1 if t == :rimjoistconcave
      nb_rimjoist_edges     += 1 if t == :rimjoistconvex
      nb_parapet_edges      += 1 if t == :parapet
      nb_parapet_edges      += 1 if t == :parapetconcave
      nb_parapet_edges      += 1 if t == :parapetconvex
      nb_fenestration_edges += 1 if t == :fenestration
      nb_head_edges         += 1 if t == :head
      nb_sill_edges         += 1 if t == :sill
      nb_jamb_edges         += 1 if t == :jamb
      nb_corners            += 1 if t == :corner
      nb_concave_edges      += 1 if t == :cornerconcave
      nb_convex_edges       += 1 if t == :cornerconvex
      nb_balcony_edges      += 1 if t == :balcony
      nb_party_edges        += 1 if t == :party
      nb_grade_edges        += 1 if t == :grade
      nb_grade_edges        += 1 if t == :gradeconcave
      nb_grade_edges        += 1 if t == :gradeconvex
      nb_transition_edges   += 1 if t == :transition
      expect(t).to eq(:parapetconvex).or eq(:transition)
      next unless t == :parapetconvex
      expect(edge[:length]).to be_within(0.01).of(3.6)
    end
    expect(nb_rimjoist_edges).to     eq(0)
    expect(nb_parapet_edges).to      eq(1)    # parapet linked to "good" PSI set
    expect(nb_fenestration_edges).to eq(0)
    expect(nb_head_edges).to         eq(0)
    expect(nb_sill_edges).to         eq(0)
    expect(nb_jamb_edges).to         eq(0)
    expect(nb_corners).to            eq(0)
    expect(nb_concave_edges).to      eq(0)
    expect(nb_convex_edges).to       eq(0)
    expect(nb_balcony_edges).to      eq(0)
    expect(nb_party_edges).to        eq(0)
    expect(nb_grade_edges).to        eq(0)
    expect(nb_transition_edges).to   eq(2)  # all PSI sets inherit :transitions

    # Reset counters to track the total number of edges delineating either
    # derated surfaces that DO NOT contribute in derating their insulation
    # materials i.e. not found in the "good" PSI set.
    nb_rimjoist_edges     = 0
    nb_parapet_edges      = 0
    nb_fenestration_edges = 0
    nb_head_edges         = 0
    nb_sill_edges         = 0
    nb_jamb_edges         = 0
    nb_corners            = 0
    nb_concave_edges      = 0
    nb_convex_edges       = 0
    nb_balcony_edges      = 0
    nb_party_edges        = 0
    nb_grade_edges        = 0
    nb_transition_edges   = 0

    io[:edges].each do |edge|
      valid = edge[:surfaces].include?(nom1) || edge[:surfaces].include?(nom2)
      next unless valid
      s = {}
      io[:psis].each { |set| s = set if set[:id] == edge[:psi] }
      next unless s.empty?
      expect(edge[:psi] == argh[:option]).to be(true)

      t = edge[:type]
      nb_rimjoist_edges     += 1 if t == :rimjoist
      nb_rimjoist_edges     += 1 if t == :rimjoistconcave
      nb_rimjoist_edges     += 1 if t == :rimjoistconvex
      nb_parapet_edges      += 1 if t == :parapet
      nb_parapet_edges      += 1 if t == :parapetconcave
      nb_parapet_edges      += 1 if t == :parapetconvex
      nb_fenestration_edges += 1 if t == :fenestration
      nb_head_edges         += 1 if t == :head
      nb_sill_edges         += 1 if t == :sill
      nb_jamb_edges         += 1 if t == :jamb
      nb_corners            += 1 if t == :corner
      nb_concave_edges      += 1 if t == :cornerconcave
      nb_convex_edges       += 1 if t == :cornerconvex
      nb_balcony_edges      += 1 if t == :balcony
      nb_party_edges        += 1 if t == :party
      nb_grade_edges        += 1 if t == :grade
      nb_grade_edges        += 1 if t == :gradeconcave
      nb_grade_edges        += 1 if t == :gradeconvex
      nb_transition_edges   += 1 if t == :transition
    end

    expect(nb_rimjoist_edges).to     eq(0)
    expect(nb_parapet_edges).to      eq(2)        # not linked to "good" PSI set
    expect(nb_fenestration_edges).to eq(0)
    expect(nb_head_edges).to         eq(1)
    expect(nb_sill_edges).to         eq(1)
    expect(nb_jamb_edges).to         eq(2)
    expect(nb_corners).to            eq(0)
    expect(nb_concave_edges).to      eq(0)
    expect(nb_convex_edges).to       eq(2)           # edges between walls 5 & 4
    expect(nb_balcony_edges).to      eq(0)
    expect(nb_party_edges).to        eq(0)
    expect(nb_grade_edges).to        eq(1)
    expect(nb_transition_edges).to   eq(3)                   # shared roof edges

    # Reset counters again to track the total number of edges delineating either
    # derated surfaces that DO NOT contribute in derating their insulation
    # materials i.e., automatically set as :transitions in "good" PSI set.
    nb_rimjoist_edges     = 0
    nb_parapet_edges      = 0
    nb_fenestration_edges = 0
    nb_head_edges         = 0
    nb_sill_edges         = 0
    nb_jamb_edges         = 0
    nb_corners            = 0
    nb_concave_edges      = 0
    nb_convex_edges       = 0
    nb_balcony_edges      = 0
    nb_party_edges        = 0
    nb_grade_edges        = 0
    nb_transition_edges   = 0

    io[:edges].each do |edge|
      valid = edge[:surfaces].include?(nom1) || edge[:surfaces].include?(nom2)
      next unless valid
      s = {}
      io[:psis].each { |set| s = set if set[:id] == edge[:psi] }
      next if s.empty?
      expect(s.is_a?(Hash)).to be(true)

      t = edge[:type]
      next if t.to_s.include?("parapet")
      nb_rimjoist_edges     += 1 if t == :rimjoist
      nb_rimjoist_edges     += 1 if t == :rimjoistconcave
      nb_rimjoist_edges     += 1 if t == :rimjoistconvex
      nb_parapet_edges      += 1 if t == :parapet
      nb_parapet_edges      += 1 if t == :parapetconcave
      nb_parapet_edges      += 1 if t == :parapetconvex
      nb_fenestration_edges += 1 if t == :fenestration
      nb_head_edges         += 1 if t == :head
      nb_sill_edges         += 1 if t == :sill
      nb_jamb_edges         += 1 if t == :jamb
      nb_corners            += 1 if t == :corner
      nb_concave_edges      += 1 if t == :cornerconcave
      nb_convex_edges       += 1 if t == :cornerconvex
      nb_balcony_edges      += 1 if t == :balcony
      nb_party_edges        += 1 if t == :party
      nb_grade_edges        += 1 if t == :grade
      nb_grade_edges        += 1 if t == :gradeconcave
      nb_grade_edges        += 1 if t == :gradeconvex
      nb_transition_edges   += 1 if t == :transition
    end

    expect(nb_rimjoist_edges).to     eq(0)
    expect(nb_parapet_edges).to      eq(0)
    expect(nb_fenestration_edges).to eq(0)
    expect(nb_head_edges).to         eq(0)
    expect(nb_jamb_edges).to         eq(0)
    expect(nb_sill_edges).to         eq(0)
    expect(nb_corners).to            eq(0)
    expect(nb_concave_edges).to      eq(0)
    expect(nb_convex_edges).to       eq(0)
    expect(nb_balcony_edges).to      eq(0)
    expect(nb_party_edges).to        eq(0)
    expect(nb_grade_edges).to        eq(0)
    expect(nb_transition_edges).to   eq(2)           # edges between walls 5 & 6
  end

  it "can process JSON surface KHI & PSI entries + building & edge" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n4.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    # As the :building PSI set on file == "(non thermal bridgin)", derating
    # shouldn't occur at large. However, the JSON file holds a custom edge
    # entry for "Entryway  Wall 5" : "bad" fenestration permieters, which
    # only derates the host wall itself
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      name = "Entryway  Wall 5"
      expect(surface.key?(:ratio)).to be(false) unless id == name
      next unless id == "Entryway  Wall 5"
      expect(surface[:heatloss]).to be_within(0.01).of(8.89)
    end
  end

  it "can process JSON surface KHI & PSI + building & edge (2)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n5.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    # As above, yet the KHI points are now set @0.5 W/K per m (instead of 0)
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      name = "Entryway  Wall 5"
      expect(surface.key?(:ratio)).to be(false) unless id == name
      next unless id == "Entryway  Wall 5"
      expect(surface[:heatloss]).to be_within(0.01).of(12.39)
    end
  end

  it "can process JSON surface KHI & PSI + building & edge (3)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n6.json")
    argh[:schama_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    # As above, with a "good" surface PSI set
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      name = "Entryway  Wall 5"
      expect(surface.key?(:ratio)).to be(false) unless id == name
      next unless id == "Entryway  Wall 5"
      expect(surface[:heatloss]).to be_within(0.01).of(14.05)
    end
  end

  it "can process JSON surface KHI & PSI + building & edge (4)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "compliant"        # superseded by :building PSI set on file
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n7.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
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
        expect(surface.key?(:ratio)).to be(true)
      else
        expect(surface.key?(:ratio)).to be(false)
      end
      next unless id == "Entryway  Wall 5"
      expect(surface[:heatloss]).to be_within(0.01).of(15.62)
    end
  end

  it "can factor in negative PSI values (JSON input)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "compliant"        # superseded by :building PSI set on file
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse4.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    ids = { a: "Office Front Wall",
            b: "Office Left Wall",
            c: "Fine Storage Roof",
            d: "Fine Storage Office Front Wall",
            e: "Fine Storage Office Left Wall",
            f: "Fine Storage Front Wall",
            g: "Fine Storage Left Wall",
            h: "Fine Storage Right Wall",
            i: "Bulk Storage Roof",
            j: "Bulk Storage Rear Wall",
            k: "Bulk Storage Left Wall",
            l: "Bulk Storage Right Wall" }.freeze

    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      next unless surface.key?(:ratio)
      expect(ids.has_value?(id)).to be(true)
      expect surface.key?(:heatloss)

      # Ratios are typically negative e.g., a steel corner column decreasing
      # linked surface RSi values. In some cases, a corner PSI can be positive
      # (and thus increasing linked surface RSi values). This happens when
      # estimating PSI values for convex corners while relying on an interior
      # dimensioning convention e.g., BETBG Detail 7.6.2, ISO 14683.
      expect(surface[:ratio]).to be_within(0.01).of(0.18) if id == ids[:a]
      expect(surface[:ratio]).to be_within(0.01).of(0.55) if id == ids[:b]
      expect(surface[:ratio]).to be_within(0.01).of(0.15) if id == ids[:d]
      expect(surface[:ratio]).to be_within(0.01).of(0.43) if id == ids[:e]
      expect(surface[:ratio]).to be_within(0.01).of(0.20) if id == ids[:f]
      expect(surface[:ratio]).to be_within(0.01).of(0.13) if id == ids[:h]
      expect(surface[:ratio]).to be_within(0.01).of(0.12) if id == ids[:j]
      expect(surface[:ratio]).to be_within(0.01).of(0.04) if id == ids[:k]
      expect(surface[:ratio]).to be_within(0.01).of(0.04) if id == ids[:l]

      # In such cases, negative heatloss means heat gained.
      expect(surface[:heatloss]).to be_within(0.01).of(-0.10) if id == ids[:a]
      expect(surface[:heatloss]).to be_within(0.01).of(-0.10) if id == ids[:b]
      expect(surface[:heatloss]).to be_within(0.01).of(-0.10) if id == ids[:d]
      expect(surface[:heatloss]).to be_within(0.01).of(-0.10) if id == ids[:e]
      expect(surface[:heatloss]).to be_within(0.01).of(-0.20) if id == ids[:f]
      expect(surface[:heatloss]).to be_within(0.01).of(-0.20) if id == ids[:h]
      expect(surface[:heatloss]).to be_within(0.01).of(-0.40) if id == ids[:j]
      expect(surface[:heatloss]).to be_within(0.01).of(-0.20) if id == ids[:k]
      expect(surface[:heatloss]).to be_within(0.01).of(-0.20) if id == ids[:l]
    end
  end

  it "can process JSON file read/validate" do
    TBD.clean!
    argh = {}

    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    expect(File.exist?(argh[:schema_path])).to be(true)
    schema = File.read(argh[:schema_path])
    schema = JSON.parse(schema, symbolize_names: true)

    argh[:io_path] = File.join(__dir__, "../json/tbd_json_test.json")
    io = File.read(argh[:io_path])
    io = JSON.parse(io, symbolize_names: true)

    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(io.key?(:description)).to be(true)
    expect(io.key?(:schema)).to be(true)
    expect(io.key?(:edges)).to be(true)
    expect(io.key?(:surfaces)).to be(true)
    expect(io.key?(:spaces)).to be(false)
    expect(io.key?(:spacetypes)).to be(false)
    expect(io.key?(:stories)).to be(false)
    expect(io.key?(:building)).to be(true)
    expect(io.key?(:logs)).to be(false)
    expect(io[:edges].size).to eq(1)
    expect(io[:surfaces].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    expect(io.key?(:psis)).to be(true)
    io[:psis].each { |p| expect(psi.append(p)).to be(true) }
    expect(psi.set.size).to eq(10)
    expect(psi.set.key?("poor (BETBG)")).to be(true)
    expect(psi.set.key?("regular (BETBG)")).to be(true)
    expect(psi.set.key?("efficient (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel HP (BETBG)")).to be(true)
    expect(psi.set.key?("code (Quebec)")).to be(true)
    expect(psi.set.key?("uncompliant (Quebec)")).to be(true)
    expect(psi.set.key?("(non thermal bridging)")).to be(true)
    expect(psi.set.key?("good")).to be(true)
    expect(psi.set.key?("compliant")).to be(true)

    # Similar treatment for khis
    khi = KHI.new
    expect(io.key?(:khis)).to be(true)
    io[:khis].each { |k| expect(khi.append(k)).to be(true) }
    expect(khi.point.size).to eq(8)
    expect(khi.point.key?("poor (BETBG)")).to be(true)
    expect(khi.point.key?("regular (BETBG)")).to be(true)
    expect(khi.point.key?("efficient (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel HP (BETBG)")).to be(true)
    expect(khi.point.key?("code (Quebec)")).to be(true)
    expect(khi.point.key?("uncompliant (Quebec)")).to be(true)
    expect(khi.point.key?("(non thermal bridging)")).to be(true)
    expect(khi.point.key?("column")).to be(true)
    expect(khi.point.key?("support")).to be(true)
    expect(khi.point["column"]).to eq(0.5)
    expect(khi.point["support"]).to eq(0.5)

    expect(io.key?(:building)).to be(true)
    expect(io[:building].key?(:psi)).to be(true)
    expect(io[:building][:psi]).to eq("compliant")
    expect(psi.set.key?(io[:building][:psi])).to be(true)

    expect(io.key?(:surfaces)).to be(true)
    io[:surfaces].each do |surface|
      expect(surface.key?(:id)).to be(true)
      expect(surface[:id]).to eq("front wall")
      expect(surface.key?(:psi)).to be(true)
      expect(surface[:psi]).to eq("good")
      expect(psi.set.key?(surface[:psi])).to be(true)

      expect(surface.key?(:khis)).to be(true)
      expect(surface[:khis].size).to eq(2)
      surface[:khis].each do |k|
        expect(k.key?(:id)).to be(true)
        expect(khi.point.key?(k[:id])).to be(true)
        expect(k[:count]).to eq(3) if k[:id] == "column"
        expect(k[:count]).to eq(4) if k[:id] == "support"
      end
    end

    expect(io.key?(:edges)).to be(true)
    io[:edges].each do |edge|
      expect(edge.key?(:psi)).to be(true)
      expect(edge[:psi]).to eq("compliant")
      expect(psi.set.key?(edge[:psi])).to be(true)
      expect(edge.key?(:surfaces)).to be(true)
      edge[:surfaces].each do |surface|
        expect(surface).to eq("front wall")
      end
    end

    # A reminder that built-in KHIs are not frozen ...
    khi.point["code (Quebec)"] = 2.0
    expect(khi.point["code (Quebec)"]).to eq(2.0)

    # Load PSI combo JSON example - likely the most expected or common use.
    argh[:io_path] = File.join(__dir__, "../json/tbd_PSI_combo.json")
    io = File.read(argh[:io_path])
    io = JSON.parse(io, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(io.key?(:description)).to be(true)
    expect(io.key?(:schema)).to be(true)
    expect(io.key?(:edges)).to be(false)
    expect(io.key?(:surfaces)).to be(false)
    expect(io.key?(:spaces)).to be(true)
    expect(io.key?(:spacetypes)).to be(false)
    expect(io.key?(:stories)).to be(false)
    expect(io.key?(:building)).to be(true)
    expect(io.key?(:logs)).to be(false)
    expect(io[:spaces].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults.
    psi = PSI.new
    expect(io.key?(:psis)).to be(true)
    io[:psis].each { |p| expect(psi.append(p)).to be(true) }
    expect(psi.set.size).to eq(10)
    expect(psi.set.key?("poor (BETBG)")).to be(true)
    expect(psi.set.key?("regular (BETBG)")).to be(true)
    expect(psi.set.key?("efficient (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel HP (BETBG)")).to be(true)
    expect(psi.set.key?("code (Quebec)")).to be(true)
    expect(psi.set.key?("uncompliant (Quebec)")).to be(true)
    expect(psi.set.key?("(non thermal bridging)")).to be(true)
    expect(psi.set.key?("OK")).to be(true)
    expect(psi.set.key?("Awesome")).to be(true)
    expect(psi.set["Awesome"][:rimjoist]).to eq(0.2)

    expect(io.key?(:building)).to be (true)
    expect(io[:building].key?(:psi)).to be(true)
    expect(io[:building][:psi]).to eq("Awesome")
    expect(psi.set.key?(io[:building][:psi])).to be(true)

    expect(io.key?(:spaces)).to be(true)
    io[:spaces].each do |space|
      expect(space.key?(:psi)).to be(true)
      expect(space[:id]).to eq("ground-floor restaurant")
      expect(space[:psi]).to eq("OK")
      expect(psi.set.key?(space[:psi])).to be(true)
    end

    # Load PSI combo2 JSON example - a more elaborate example, yet common.
    # Post-JSON validation required to handle case sensitive keys & value
    # strings (e.g. "ok" vs "OK" in the file).
    argh[:io_path] = File.join(__dir__, "../json/tbd_PSI_combo2.json")
    io = File.read(argh[:io_path])
    io = JSON.parse(io, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(io.key?(:description)).to be(true)
    expect(io.key?(:schema)).to be(true)
    expect(io.key?(:edges)).to be(true)
    expect(io.key?(:surfaces)).to be(true)
    expect(io.key?(:spaces)).to be(false)
    expect(io.key?(:spacetypes)).to be(false)
    expect(io.key?(:stories)).to be(false)
    expect(io.key?(:building)).to be(true)
    expect(io.key?(:logs)).to be(false)
    expect(io[:edges].size).to eq(1)
    expect(io[:surfaces].size).to eq(1)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    expect(io.key?(:psis)).to be(true)
    io[:psis].each { |p| expect(psi.append(p)).to be(true) }
    expect(psi.set.size).to eq(11)
    expect(psi.set.key?("poor (BETBG)")).to be(true)
    expect(psi.set.key?("regular (BETBG)")).to be(true)
    expect(psi.set.key?("efficient (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel HP (BETBG)")).to be(true)
    expect(psi.set.key?("code (Quebec)")).to be(true)
    expect(psi.set.key?("uncompliant (Quebec)")).to be(true)
    expect(psi.set.key?("(non thermal bridging)")).to be(true)
    expect(psi.set.key?("OK")).to be(true)
    expect(psi.set.key?("Awesome")).to be(true)
    expect(psi.set.key?("Party wall edge")).to be(true)
    expect(psi.set["Party wall edge"][:party]).to eq(0.4)

    expect(io.key?(:building)).to be(true)
    expect(io[:building].key?(:psi)).to be(true)
    expect(io[:building][:psi]).to eq("Awesome")
    expect(psi.set.key?(io[:building][:psi])).to be(true)

    expect(io.key?(:surfaces)).to be(true)
    io[:surfaces].each do |surface|
      expect(surface.key?(:id)).to be(true)
      expect(surface[:id]).to eq("ground-floor restaurant South-wall")
      expect(surface.key?(:psi)).to be(true)
      expect(surface[:psi]).to eq("ok")
      expect(psi.set.key?(surface[:psi])).to be(false)
    end

    expect(io.key?(:edges)).to be(true)
    io[:edges].each do |edge|
      expect(edge.key?(:psi)).to be(true)
      expect(edge[:psi]).to eq("Party wall edge")
      expect(edge.key?(:type)).to be(true)
      expect(edge[:type].to_s.include?("party")).to be(true)
      expect(psi.set.key?(edge[:psi])).to be(true)
      expect(psi.set[edge[:psi]].key?(:party)).to be(true)
      expect(edge.key?(:surfaces)).to be(true)
      edge[:surfaces].each do |surface|
        answer = false
        answer = true if surface == "ground-floor restaurant West-wall" ||
                         surface == "ground-floor restaurant party wall"
        expect(answer).to be(true)
      end
    end

    # Load full PSI JSON example - with duplicate keys for "party"
    # "JSON Schema Lint" * will recognize the duplicate and - as with duplicate
    # Ruby hash keys - will have the second entry ("party": 0.8) override the
    # first ("party": 0.7). Another reminder of post-JSON validation.
    # * https://jsonschemalint.com/#!/version/draft-04/markup/json
    argh[:io_path] = File.join(__dir__, "../json/tbd_full_PSI.json")
    io = File.read(argh[:io_path])
    io = JSON.parse(io, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    expect(io.key?(:description)).to be(true)
    expect(io.key?(:schema)).to be(true)
    expect(io.key?(:edges)).to be(false)
    expect(io.key?(:surfaces)).to be(false)
    expect(io.key?(:spaces)).to be(false)
    expect(io.key?(:spacetypes)).to be(false)
    expect(io.key?(:stories)).to be(false)
    expect(io.key?(:building)).to be(false)
    expect(io.key?(:logs)).to be(false)

    # Loop through input psis to ensure uniqueness vs PSI defaults
    psi = PSI.new
    expect(io.key?(:psis)).to be(true)
    io[:psis].each { |p| expect(psi.append(p)).to be(true) }
    expect(psi.set.size).to eq(9)
    expect(psi.set.key?("poor (BETBG)")).to be(true)
    expect(psi.set.key?("regular (BETBG)")).to be(true)
    expect(psi.set.key?("efficient (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel (BETBG)")).to be(true)
    expect(psi.set.key?("spandrel HP (BETBG)")).to be(true)
    expect(psi.set.key?("code (Quebec)")).to be(true)
    expect(psi.set.key?("uncompliant (Quebec)")).to be(true)
    expect(psi.set.key?("(non thermal bridging)")).to be(true)
    expect(psi.set.key?("OK")).to be(true)
    expect(psi.set["OK"][:party]).to eq(0.8)

    # Load minimal PSI JSON example
    argh[:io_path] = File.join(__dir__, "../json/tbd_minimal_PSI.json")
    io = File.read(argh[:io_path])
    io = JSON.parse(io, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)

    # Load minimal KHI JSON example
    argh[:io_path] = File.join(__dir__, "../json/tbd_minimal_KHI.json")
    io = File.read(argh[:io_path])
    io = JSON.parse(io, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    v = JSON::Validator.validate(argh[:schema_path], argh[:io_path], uri: true)
    expect(v).to be(true)

    # Load complete results (ex. UA') example
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse11.json")
    io = File.read(argh[:io_path])
    io = JSON.parse(io, symbolize_names: true)
    expect(JSON::Validator.validate(schema, io)).to be(true)
    v = JSON::Validator.validate(argh[:schema_path], argh[:io_path], uri: true)
    expect(v).to be(true)
  end

  it "can factor in spacetype-specific PSI sets (JSON input)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "compliant"        # superseded by :building PSI set on file
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse5.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    sTyp1 = "Warehouse Office"
    sTyp2 = "Warehouse Fine"

    expect(io.key?(:spacetypes)).to be(true)
    io[:spacetypes].each do |spacetype|
      expect(spacetype.key?(:id)).to be(true)
      expect(spacetype[:id]).to eq(sTyp1).or eq(sTyp2)
      expect(spacetype.key?(:psi)).to be(true)
    end

    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      next unless surface.key?(:ratio)
      expect(surface.key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
      expect(surface.key?(:space)).to be(true)
      next unless surface[:space].nameString == "Zone1 Office"

      # All applicable thermal bridges/edges derating the office walls inherit
      # the "Warehouse Office" spacetype PSI values (JSON file), except for the
      # shared :rimjoist with the Fine Storage space above. The "Warehouse Fine"
      # spacetype set has a higher :rimjoist PSI value of 0.5 W/K per meter,
      # which overrides the "Warehouse Office" value of 0.3 W/K per meter.
      name = "Office Left Wall"
      expect(heatloss).to be_within(0.01).of(11.61) if id == name
      name = "Office Front Wall"
      expect(heatloss).to be_within(0.01).of(22.94) if id == name
    end
  end

  it "can factor in story-specific PSI sets (JSON input)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_smalloffice.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "compliant"        # superseded by :building PSI set on file
    argh[:io_path] = File.join(__dir__, "../json/tbd_smalloffice.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(43)
    expect(io[:edges].size).to eq(105)

    expect(io.key?(:stories)).to be(true)
    io[:stories].each do |story|
      expect(story.key?(:id)).to be(true)
      expect(story[:id]).to eq("Building Story 1")
      expect(story.key?(:psi)).to be(true)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:ratio)
      expect(surface.key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
      next unless surface.key?(:story)
      expect(surface[:story].nameString).to eq("Building Story 1")
    end
  end

  it "can sort multiple story-specific PSI sets (JSON input)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/midrise_KIVA.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Testing min/max cooling/heating setpoints
    setpoints = heatingTemperatureSetpoints?(os_model)
    setpoints = coolingTemperatureSetpoints?(os_model) || setpoints
    expect(setpoints).to be(true)
    airloops = airLoopsHVAC?(os_model)
    expect(airloops).to be(true)

    os_model.getSpaces.each do |space|
      expect(space.thermalZone.empty?).to be(false)
      zone = space.thermalZone.get
      heating, _ = maxHeatScheduledSetpoint(zone)
      cooling, _ = minCoolScheduledSetpoint(zone)
      expect(plenum?(space, airloops, setpoints)).to be(false)
      if zone.nameString == "Office ZN"
        expect(heating).to be_within(0.1).of(21.1)
        expect(cooling).to be_within(0.1).of(23.9)
      else
        expect(heating).to be_within(0.1).of(21.7)
        expect(cooling).to be_within(0.1).of(24.4)
      end
    end

    argh[:option] = "(non thermal bridging)"                        # overridden
    argh[:io_path] = File.join(__dir__, "../json/midrise.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(180)

    surfaces.each do |id, surface|
      expect(surface.key?(:conditioned)).to be(true)
      next unless surface[:conditioned]
      expect(surface.key?(:heating)).to be(true)
      expect(surface.key?(:cooling)).to be(true)
    end

    st1 = "Building Story 1"
    st2 = "Building Story 2"
    st3 = "Building Story 3"

    expect(io.key?(:stories)).to be(true)
    expect(io[:stories].size).to eq(3)
    io[:stories].each do |story|
      expect(story.key?(:id)).to be(true)
      expect(story[:id]).to eq(st1).or eq(st2).or eq(st3)
      expect(story.key?(:psi)).to be(true)
    end

    counter = 0
    surfaces.each do |id, surface|
      next unless surface.key?(:ratio)
      expect(surface.key?(:boundary)).to be(true)
      expect(surface[:boundary]).to eq("Outdoors")
      expect(surface.key?(:story)).to be(true)
      nom = surface[:story].nameString
      expect(nom).to eq(st1).or eq(st2).or eq(st3)
      expect(nom).to eq(st1) if id.include?("g ")
      expect(nom).to eq(st2) if id.include?("m ")
      expect(nom).to eq(st3) if id.include?("t ")
      expect(surface.key?(:edges)).to be(true)
      counter += 1

      # Illustrating that story-specific PSI set is used when only 1x story.
      surface[:edges].values.each do |edge|
        expect(edge.key?(:type)).to be(true)
        expect(edge.key?(:psi)).to be(true)
        next unless id.include?("Roof")
        expect(edge[:type]).to eq(:parapetconvex).or eq(:transition)
        next unless edge[:type] == :parapetconvex
        next if id == "t Roof C"
        expect(edge[:psi]).to be_within(0.01).of(0.178) # 57.3% of 0.311
      end

      # Illustrating that story-specific PSI set is used when only 1x story.
      surface[:edges].values.each do |edge|
        next unless id.include?("t ")
        next unless id.include?("Wall ")
        next unless edge[:type] == :parapetconvex
        next if id.include?(" C")
        expect(edge[:psi]).to be_within(0.01).of(0.133) # 42.7% of 0.311
      end

      # The shared :rimjoist between middle story and ground floor units could
      # either inherit the "Building Story 1" or "Building Story 2" :rimjoist
      # PSI values. TBD retains the most conductive PSI values in such cases.
      surface[:edges].values.each do |edge|
        next unless id.include?("m ")
        next unless id.include?("Wall ")
        next if id.include?(" C")
        next unless edge[:type] == :rimjoist

        # Inheriting "Building Story 1" :rimjoist PSI of 0.501 W/K per meter.
        # The SEA unit is above an office space below, which has curtain wall.
        # RSi of insulation layers (to derate):
        #   - office walls   : 0.740 m2.K/W (26.1%)
        #   - SEA walls      : 2.100 m2.K/W (73.9%)
        #
        #   - SEA walls      : 26.1% of 0.501 = 0.3702 W/K per meter
        #   - other walls    : 50.0% of 0.501 = 0.2505 W/K per meter
        if id == "m SWall SEA" || id == "m EWall SEA"
          expect(edge[:psi]).to be_within(0.002).of(0.3702)
        else
          expect(edge[:psi]).to be_within(0.002).of(0.2505)
        end
      end
    end
    expect(counter).to eq(51)
  end

  it "can handle parties" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Reset boundary conditions for open area wall 5 (and plenum wall above).
    id1 = "Openarea 1 Wall 5"
    s1 = os_model.getSurfaceByName(id1)
    expect(s1.empty?).to be(false)
    s1 = s1.get
    s1.setOutsideBoundaryCondition("Adiabatic")
    expect(s1.nameString).to eq(id1)
    expect(s1.outsideBoundaryCondition).to eq("Adiabatic")

    id2 = "Level0 Open area 1 Ceiling Plenum AbvClgPlnmWall 5"
    s2 = os_model.getSurfaceByName(id2)
    expect(s2.empty?).to be(false)
    s2 = s2.get
    s2.setOutsideBoundaryCondition("Adiabatic")
    expect(s2.nameString).to eq(id2)
    expect(s2.outsideBoundaryCondition).to eq("Adiabatic")

    argh[:option] = "compliant"
    argh[:io_path] = File.join(__dir__, "../json/tbd_seb_n8.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    ids = { a: "Entryway  Wall 4",
            b: "Entryway  Wall 5",
            c: "Entryway  Wall 6",
            d: "Entry way  DroppedCeiling",
            e: "Utility1 Wall 1",
            f: "Utility1 Wall 5",
            g: "Utility 1 DroppedCeiling",
            h: "Smalloffice 1 Wall 1",
            i: "Smalloffice 1 Wall 2",
            j: "Smalloffice 1 Wall 6",
            k: "Small office 1 DroppedCeiling",
            l: "Openarea 1 Wall 3",
            m: "Openarea 1 Wall 4",             # removed n: "Openarea 1 Wall 5"
            o: "Openarea 1 Wall 6",
            p: "Openarea 1 Wall 7",
            q: "Open area 1 DroppedCeiling" }.freeze

    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of( 3.62) if id == ids[:a]
      expect(h).to be_within(0.01).of( 6.28) if id == ids[:b]
      expect(h).to be_within(0.01).of( 2.62) if id == ids[:c]
      expect(h).to be_within(0.01).of( 0.17) if id == ids[:d]
      expect(h).to be_within(0.01).of( 7.13) if id == ids[:e]
      expect(h).to be_within(0.01).of( 7.09) if id == ids[:f]
      expect(h).to be_within(0.01).of( 0.20) if id == ids[:g]
      expect(h).to be_within(0.01).of( 7.94) if id == ids[:h]
      expect(h).to be_within(0.01).of( 5.17) if id == ids[:i]
      expect(h).to be_within(0.01).of( 5.01) if id == ids[:j]
      expect(h).to be_within(0.01).of( 0.22) if id == ids[:k]
      expect(h).to be_within(0.01).of( 2.47) if id == ids[:l]
      expect(h).to be_within(0.01).of( 4.03) if id == ids[:m] # 3.11
      expect(h).to be_within(0.01).of( 4.43) if id == ids[:n]
      expect(h).to be_within(0.01).of( 4.27) if id == ids[:o] # 3.35
      expect(h).to be_within(0.01).of( 2.12) if id == ids[:p]
      expect(h).to be_within(0.01).of( 2.16) if id == ids[:q] # 0.31

      # The 2x side walls linked to the new party wall "Openarea 1 Wall 5":
      #   - "Openarea 1 Wall 4"
      #   - "Openarea 1 Wall 6"
      # ... have 1x half-corner replaced by 100% of a party wall edge, hence
      # the increase in extra heat loss.
      #
      # The "Open area 1 DroppedCeiling" has almost a 7x increase in extra heat
      # loss. It used to take ~7.6% of the parapet PSI it shared with "Wall 5".
      # As the latter is no longer a deratable surface (i.e., a party wall), the
      # dropped ceiling hence takes on 100% of the party wall edge it still
      # shares with "Wall 5".

      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      i = 0
      i = 2 if s.outsideBoundaryCondition == "Outdoors"
      expect(c.layers[i].nameString.include?("m tbd")).to be(true)
    end
  end

  it "can factor in unenclosed space such as attics" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_smalloffice.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    expect(airLoopsHVAC?(os_model)).to be(true)
    expect(heatingTemperatureSetpoints?(os_model)).to be(true)
    expect(coolingTemperatureSetpoints?(os_model)).to be(true)

    argh[:option] = "compliant"        # superseded by :building PSI set on file
    argh[:io_path] = File.join(__dir__, "../json/tbd_smalloffice.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(43)
    expect(io[:edges].size).to eq(105)

    # Check derating of attic floor (5x surfaces)
    os_model.getSpaces.each do |space|
      next unless space.nameString == "Attic"
      expect(space.thermalZone.empty?).to be(false)
      zone = space.thermalZone.get
      expect(zone.isPlenum).to be(false)
      expect(zone.canBePlenum).to be(true)
      space.surfaces.each do |s|
        id = s.nameString
        expect(surfaces.key?(id)).to be(true)
        expect(surfaces[id].key?(:space)).to be(true)
        next unless surfaces[id][:space].nameString == "Attic"
        expect(surfaces[id][:conditioned]).to be(false)
        next if surfaces[id][:boundary] == "Outdoors"
        expect(s.adjacentSurface.empty?).to be(false)
        adjacent = s.adjacentSurface.get.nameString
        expect(surfaces.key?(adjacent)).to be(true)
        expect(surfaces[id][:boundary]).to eq(adjacent)
        expect(surfaces[adjacent][:conditioned]).to be(true)
      end
    end

    # Check derating of ceilings (below attic).
    surfaces.each do |id, surface|
      next unless surface.key?(:ratio)
      next if surface[:boundary].downcase == "outdoors"
      expect(surface.key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
      expect(id.include?("Perimeter_ZN_")).to be(true)
      expect(id.include?("_ceiling")).to be(true)
    end

    # Check derating of outdoor-facing walls
    surfaces.each do |id, surface|
      next unless surface.key?(:ratio)
      next unless surface[:boundary].downcase == "outdoors"
      expect(surface.key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
    end
  end

  it "can factor in heads, sills and jambs" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "compliant"        # superseded by :building PSI set on file
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse7.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    nom = "Bulk Storage Roof"
    n_transitions  = 0
    n_parapets     = 0
    n_fen_edges    = 0
    n_heads        = 0
    n_sills        = 0
    n_jambs        = 0

    t1 = :transition
    t2 = :parapetconvex
    t3 = :fenestration
    t4 = :head
    t5 = :sill
    t6 = :jamb

    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      next unless surface.key?(:ratio)
      expect(surface.key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
      next unless id == nom
      expect(surfaces[id].key?(:edges)).to be(true)
      expect(surfaces[id][:edges].size).to eq(132)
      surfaces[id][:edges].values.each do |edge|
        expect(edge.key?(:type)).to be(true)
        t = edge[:type]
        expect(t).to eq(t1).or eq(t2).or eq(t3).or eq(t4).or eq(t5).or eq(t6)
        n_transitions += 1 if edge[:type] == t1
        n_parapets    += 1 if edge[:type] == t2
        n_fen_edges   += 1 if edge[:type] == t3
        n_heads       += 1 if edge[:type] == t4
        n_sills       += 1 if edge[:type] == t5
        n_jambs       += 1 if edge[:type] == t6
      end
    end
    expect(n_transitions).to eq(1)
    expect(n_parapets).to eq(3)
    expect(n_fen_edges).to eq(0)
    expect(n_heads).to eq(0)
    expect(n_sills).to eq(0)
    expect(n_jambs).to eq(128)
  end

  it "has a PSI class" do
    TBD.clean!
    argh = {}

    psi = PSI.new
    expect(psi.set.key?("poor (BETBG)")).to be(true)
    expect(psi.complete?("poor (BETBG)")).to be(true)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.size).to eq(0)

    expect(psi.set.key?("new set")).to be(false)
    expect(psi.complete?("new set")).to be(false)
    expect(TBD.status).to eq(TBD::ERROR)
    expect(TBD.logs.size).to eq(1)
    TBD.clean!
    new_set =
    {
      id:            "new set",
      rimjoist:      0.000,
      parapet:       0.000,
      fenestration:  0.000,
      cornerconcave: 0.000,
      cornerconvex:  0.000,
      balcony:       0.000,
      party:         0.000,
      grade:         0.000
    }
    expect(psi.append(new_set)).to be(true)
    expect(psi.set.key?("new set")).to be(true)
    expect(psi.complete?("new set")).to be(true)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.size).to eq(0)

    expect(psi.set["new set"][:grade]).to eq(0)
    new_set[:grade] = 1.0
    expect(psi.append(new_set)).to be(false)  # does not override existing value
    expect(TBD.status).to eq(TBD::ERROR)
    expect(TBD.logs.size).to eq(1)
    expect(psi.set["new set"][:grade]).to eq(0)

    expect(psi.set.key?("incomplete set")).to be(false)
    expect(psi.complete?("incomplete set")).to be(false)
    incomplete_set =
    {
      id:           "incomplete set",
      grade:        0.000  #
    }
    expect(psi.append(incomplete_set)).to be(true)
    expect(psi.set.key?("incomplete set")).to be(true)
    expect(psi.complete?("incomplete set")).to be(false)

    # Fenestration edge variant - complete, partial, empty
    expect(psi.set.key?("all sills")).to be(false)
    all_sills =
    {
      id:            "all sills",
      fenestration:  0.391,
      head:          0.381,
      headconcave:   0.382,
      headconvex:    0.383,
      sill:          0.371,
      sillconcave:   0.372,
      sillconvex:    0.373,
      jamb:          0.361,
      jambconcave:   0.362,
      jambconvex:    0.363,
      rimjoist:      0.001,
      parapet:       0.002,
      corner:        0.003,
      balcony:       0.004,
      party:         0.005,
      grade:         0.006
    }
    expect(psi.append(all_sills)).to be(true)
    expect(psi.set.key?("all sills")).to be(true)
    expect(psi.complete?("all sills")).to be(true)
    holds, vals = psi.shorthands("all sills")
    expect(holds.empty?).to be(false)
    expect(vals.empty?).to be(false)
    expect(holds[:fenestration]).to be(true)
    expect(vals[:sill]).to be_within(0.001).of(0.371)
    expect(vals[:sillconcave]).to be_within(0.001).of(0.372)
    expect(vals[:sillconvex]).to be_within(0.001).of(0.373)

    expect(psi.set.key?("partial sills")).to be(false)
    partial_sills =
    {
      id:            "partial sills",
      fenestration:  0.391,
      head:          0.381,
      headconcave:   0.382,
      headconvex:    0.383,
      sill:          0.371,
      sillconcave:   0.372,
      # sillconvex:    0.373,                      # dropping the convex variant
      jamb:          0.361,
      jambconcave:   0.362,
      jambconvex:    0.363,
      rimjoist:      0.001,
      parapet:       0.002,
      corner:        0.003,
      balcony:       0.004,
      party:         0.005,
      grade:         0.006
    }
    expect(psi.append(partial_sills)).to be(true)
    expect(psi.set.key?("partial sills")).to be(true)
    expect(psi.complete?("partial sills")).to be(true)   # can be a building set
    holds, vals = psi.shorthands("partial sills")
    expect(holds.empty?).to be(false)
    expect(vals.empty?).to be(false)
    expect(holds[:sillconvex]).to be(false)                # absent from PSI set
    expect(vals[:sill]).to        be_within(0.001).of(0.371)
    expect(vals[:sillconcave]).to be_within(0.001).of(0.372)
    expect(vals[:sillconvex]).to  be_within(0.001).of(0.371)    # inherits :sill

    expect(psi.set.key?("no sills")).to be(false)
    no_sills =
    {
      id:            "no sills",
      fenestration:  0.391,
      head:          0.381,
      headconcave:   0.382,
      headconvex:    0.383,
      # sill:          0.371,                     # dropping the concave variant
      # sillconcave:   0.372,                     # dropping the concave variant
      # sillconvex:    0.373,                      # dropping the convex variant
      jamb:          0.361,
      jambconcave:   0.362,
      jambconvex:    0.363,
      rimjoist:      0.001,
      parapet:       0.002,
      corner:        0.003,
      balcony:       0.004,
      party:         0.005,
      grade:         0.006
    }
    expect(psi.append(no_sills)).to be(true)
    expect(psi.set.key?("no sills")).to be(true)
    expect(psi.complete?("no sills")).to be(true)        # can be a building set
    holds, vals = psi.shorthands("no sills")
    expect(holds.empty?).to be(false)
    expect(vals.empty?).to be(false)
    expect(holds[:sill]).to be(false)                      # absent from PSI set
    expect(holds[:sillconcave]).to be(false)               # absent from PSI set
    expect(holds[:sillconvex]).to be(false)                # absent from PSI set
    expect(vals[:sill]).to        be_within(0.001).of(0.391)
    expect(vals[:sillconcave]).to be_within(0.001).of(0.391)
    expect(vals[:sillconvex]).to  be_within(0.001).of(0.391)     # :fenestration
  end

  it "can flag polygon 'fits?' & 'overlaps?' (frame & dividers)" do
    model = OpenStudio::Model::Model.new

    # 10m x 10m parent vertical (wall) surface.
    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  0,  0, 10)
    vec << OpenStudio::Point3d.new(  0,  0,  0)
    vec << OpenStudio::Point3d.new( 10,  0,  0)
    vec << OpenStudio::Point3d.new( 10,  0, 10)
    wall = OpenStudio::Model::Surface.new(vec, model)
    ft = OpenStudio::Transformation::alignFace(wall.vertices).inverse
    ft_wall  = flatZ( (ft * wall.vertices).reverse )

    # 1m x 2m corner door (with 2x edges along wall edges)
    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  0,  0,  2)
    vec << OpenStudio::Point3d.new(  0,  0,  0)
    vec << OpenStudio::Point3d.new(  1,  0,  0)
    vec << OpenStudio::Point3d.new(  1,  0,  2)
    door1 = OpenStudio::Model::SubSurface.new(vec, model)
    ft_door1 = flatZ( (ft * door1.vertices).reverse )

    union = OpenStudio::join(ft_wall, ft_door1, TOL2)
    expect(union.empty?).to be(false)
    union = union.get
    area = OpenStudio::getArea(union)
    expect(area.empty?).to be(false)
    area = area.get
    expect(area).to be_within(0.01).of(wall.grossArea)

    # Door1 fits?, overlaps?
    TBD.clean!
    expect(fits?(door1.vertices, wall.vertices)).to be(true)
    expect(overlaps?(door1.vertices, wall.vertices)).to be(true)
    expect(TBD.status).to eq(0)

    # Order of arguments matter.
    expect(fits?(wall.vertices, door1.vertices)).to be(false)
    expect(overlaps?(wall.vertices, door1.vertices)).to be(true)
    expect(TBD.status).to eq(0)

    # Another 1m x 2m corner door, yet entirely beyond the wall surface.
    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( 16,  0,  2)
    vec << OpenStudio::Point3d.new( 16,  0,  0)
    vec << OpenStudio::Point3d.new( 17,  0,  0)
    vec << OpenStudio::Point3d.new( 17,  0,  2)
    door2 = OpenStudio::Model::SubSurface.new(vec, model)
    ft_door2 = flatZ( (ft * door2.vertices).reverse )
    union = OpenStudio::join(ft_wall, ft_door2, TOL2)
    expect(union.empty?).to be(true)

    # Door2 fits?, overlaps?
    expect(fits?(door2.vertices, wall.vertices)).to be(false)
    expect(overlaps?(door2.vertices, wall.vertices)).to be(false)
    expect(TBD.status).to eq(0)

    # # Order of arguments doesn't matter.
    expect(fits?(wall.vertices, door2.vertices)).to be(false)
    expect(overlaps?(wall.vertices, door2.vertices)).to be(false)
    expect(TBD.status).to eq(0)

    # Top-right corner 2m x 2m window, overlapping top-right corner of wall.
    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  9,  0, 11)
    vec << OpenStudio::Point3d.new(  9,  0,  9)
    vec << OpenStudio::Point3d.new( 11,  0,  9)
    vec << OpenStudio::Point3d.new( 11,  0, 11)
    window = OpenStudio::Model::SubSurface.new(vec, model)
    ft_window = flatZ( (ft * window.vertices).reverse )
    union = OpenStudio::join(ft_wall, ft_window, TOL2)
    expect(union.empty?).to be(false)
    union = union.get
    area = OpenStudio::getArea(union)
    expect(area.empty?).to be(false)
    area = area.get
    expect(area).to be_within(0.01).of(103)

    # Window fits?, overlaps?
    expect(fits?(window.vertices, wall.vertices)).to be(false)
    expect(overlaps?(window.vertices, wall.vertices)).to be(true)
    expect(TBD.status).to eq(0)

    expect(fits?(wall.vertices, window.vertices)).to be(false)
    expect(overlaps?(wall.vertices, window.vertices)).to be(true)
    expect(TBD.status).to eq(0)

    # A glazed surface, entirely encompassing the wall.
    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  0,  0, 10)
    vec << OpenStudio::Point3d.new(  0,  0,  0)
    vec << OpenStudio::Point3d.new( 10,  0,  0)
    vec << OpenStudio::Point3d.new( 10,  0, 10)
    glazing = OpenStudio::Model::SubSurface.new(vec, model)

    # Glazing fits?, overlaps?
    expect(fits?(glazing.vertices, wall.vertices)).to be(true)
    expect(overlaps?(glazing.vertices, wall.vertices)).to be(true)
    expect(TBD.status).to eq(0)

    expect(fits?(wall.vertices, glazing.vertices)).to be(true)
    expect(overlaps?(wall.vertices, glazing.vertices)).to be(true)
    expect(TBD.status).to eq(0)
  end

  it "can factor-in Frame & Divider (F&D) objects" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    nom = "Office Front Wall"
    name = "Office Front Wall Window 1"

    argh[:option] = "poor (BETBG)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse8.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    n_transitions  = 0
    n_fen_edges    = 0
    n_heads        = 0
    n_sills        = 0
    n_jambs        = 0
    n_grades       = 0
    n_corners      = 0
    n_rimjoists    = 0
    fen_length     = 0

    t1 = :transition
    t2 = :fenestration
    t3 = :head
    t4 = :sill
    t5 = :jamb
    t6 = :gradeconvex
    t7 = :cornerconvex
    t8 = :rimjoist

    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      next unless surface.key?(:ratio)
      expect(surface.key?(:heatloss)).to be(true)
      heatloss = surface[:heatloss]
      expect(heatloss.abs).to be > 0
      next unless id == nom
      expect(heatloss).to be_within(0.1).of(50.2)
      expect(surface.key?(:edges)).to be(true)
      expect(surface[:edges].size).to eq(17)
      surface[:edges].values.each do |edge|
        expect(edge.key?(:type)).to be(true)
        t = edge[:type]
        n_transitions += 1 if edge[:type] == t1
        n_fen_edges   += 1 if edge[:type] == t2
        n_heads       += 1 if edge[:type] == t3
        n_sills       += 1 if edge[:type] == t4
        n_jambs       += 1 if edge[:type] == t5
        n_grades      += 1 if edge[:type] == t6
        n_corners     += 1 if edge[:type] == t7
        n_rimjoists   += 1 if edge[:type] == t8
        fen_length    += edge[:length] if edge[:type] == t2
      end
    end
    expect(n_transitions).to eq(1)
    expect(n_fen_edges).to   eq(4)                  # Office Front Wall Window 1
    expect(n_heads).to       eq(2)                             # Window 2 & door
    expect(n_sills).to       eq(1)                                    # Window 2
    expect(n_jambs).to       eq(4)                             # Window 2 & door
    expect(n_grades).to      eq(3)                         # including door sill
    expect(n_corners).to     eq(1)
    expect(n_rimjoists).to   eq(1)

    expect(fen_length).to be_within(0.01).of(10.36)         # Window 1 perimeter
    front = os_model.getSurfaceByName(nom)
    expect(front.empty?).to be(false)
    front = front.get
    expect(front.netArea).to be_within(0.01).of(95.49)
    expect(front.grossArea).to be_within(0.01).of(110.54)
    # The above net & gross areas reflect cases without frame & divider objects
    # This is also what would be reported by SketchUp.

    # Open another warehouse model and add/assign a Frame & Divider object.
    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model_FD = translator.loadModel(path)
    expect(os_model_FD.empty?).to be(false)
    os_model_FD = os_model_FD.get

    # Adding/validating Frame & Divider object.
    fd = OpenStudio::Model::WindowPropertyFrameAndDivider.new(os_model_FD)
    width = 0.03
    expect(fd.setFrameWidth(width)).to be(true)   # 30mm (narrow) around glazing
    expect(fd.setFrameConductance(2.500)).to be(true)
    window_FD = os_model_FD.getSubSurfaceByName(name)
    expect(window_FD.empty?).to be(false)
    window_FD = window_FD.get
    expect(window_FD.allowWindowPropertyFrameAndDivider).to be(true)
    expect(window_FD.setWindowPropertyFrameAndDivider(fd)).to be(true)
    width2 = window_FD.windowPropertyFrameAndDivider.get.frameWidth
    expect(width2).to be_within(0.001).of(width)               # good so far ...

    expect(window_FD.netArea).to be_within(0.01).of(5.58)
    expect(window_FD.grossArea).to be_within(0.01).of(5.58)              # 5.89?
    front_FD = os_model_FD.getSurfaceByName(nom)
    expect(front_FD.empty?).to be(false)
    front_FD = front_FD.get
    expect(front_FD.grossArea).to be_within(0.01).of(110.54)        # this is OK
    expect(front_FD.netArea).to be_within(0.01).of(95.49)              # 95.17 ?
    expect(front_FD.windowToWallRatio()).to be_within(0.01).of(0.101)  # 0.104 ?

    # If one runs a simulation with the exported file below ("os_model_FD.osm"),
    # EnergyPlus (HTML) will correctly report that the building WWR (gross
    # window-wall ratio) will have slightly increased from 71% to 72%, due to
    # the slight increase in area of the "Office Front Wall Window 1" (from
    # 5.58 m2 to 5.89 m2). The report clearly distinguishes between the revised
    # glazing area of 5.58 m2 vs a new framing area of 0.31 m2 for this window.
    # Finally, the parent surface "Office Front Wall" area will also be
    # correctly reported as 95.17 m2 (vs 95.49 m2). So OpenStudio is correctly
    # forward translating the subsurface and linked Frame & Divider objects to
    # EnergyPlus (triangular subsurfaces not tested).
    #
    # There seems to be an obvious discrepency between the net area of the
    # "Office Front Wall" reported by the OpenStudio API vs EnergyPlus. This
    # may seem minor when looking at the numbers above, but keep in mind a
    # single glazed subsurface is modified for this comparison. This difference
    # could easily reach 5% to 10% for models with many windows, especially
    # those with narrow aspect ratios (lots of framing).
    #
    # ... subsurface.netArea calculation here could be reconsidered :
    # https://github.com/NREL/OpenStudio/blob/
    # 70a5549c439eda69d6c514a7275254f71f7e3d2b/src/model/Surface.cpp#L1446
    #
    pth = File.join(__dir__, "files/osms/out/os_model_FD.osm")
    os_model_FD.save(pth, true)

    argh[:option] = "poor (BETBG)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse8.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model_FD, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    # TBD calling on framedivider.rb workarounds.
    net_area = surfaces[nom][:net]
    gross_area = surfaces[nom][:gross]
    expect(net_area).to be_within(0.01).of(95.17)                  # ! API 95.49
    expect(gross_area).to be_within(0.01).of(110.54)                      # same

    expect(surfaces[nom].key?(:windows)).to be(true)
    expect(surfaces[nom][:windows].size).to eq(2)
    surfaces[nom][:windows].each do |i, window|
      expect(window.key?(:points)).to be(true)
      expect(window[:points].size).to eq(4)
      if i == name
        expect(window.key?(:gross)).to be(true)
        expect(window[:gross]).to be_within(0.01).of(5.89)          # ! API 5.58
      end
    end

    # Adding a clerestory window, slightly above "Office Front Wall Window 1",
    # to test/validate overlapping cases. Starting with a safe case.
    cl_v = OpenStudio::Point3dVector.new
    cl_v << OpenStudio::Point3d.new( 3.66, 0.00, 4.00)
    cl_v << OpenStudio::Point3d.new( 3.66, 0.00, 2.47)
    cl_v << OpenStudio::Point3d.new( 7.31, 0.00, 2.47)
    cl_v << OpenStudio::Point3d.new( 7.31, 0.00, 4.00)
    clerestory = OpenStudio::Model::SubSurface.new(cl_v, os_model_FD)
    clerestory.setName("clerestory")
    expect(clerestory.setSurface(front_FD)).to be(true)
    expect(clerestory.setSubSurfaceType("FixedWindow")).to be(true)
    # ... reminder: set subsurface type AFTER setting its parent surface.

    argh[:option] = "poor (BETBG)"
    io, surfaces = processTBD(os_model_FD, argh)
    expect(TBD.status).to eq(TBD::WARN)    # surfaces have already been derated.
    expect(TBD.logs.size).to eq(12)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)
    expect(surfaces.key?(nom)).to be(true)
    expect(surfaces[nom].key?(:windows)).to be(true)
    wins = surfaces[nom][:windows]
    expect(wins.size).to eq(3)
    expect(wins.key?("clerestory")).to be(true)
    expect(wins.key?(name)).to be(true)
    expect(wins["clerestory"].key?(:points)).to be(true)
    expect(wins[name].key?(:points)).to be(true)

    v1 = window_FD.vertices                   # original OSM vertices for window
    p1 = wins[name][:points]       # TBD window vertices offset by frame width
    expect((p1[0].x - v1[0].x).abs).to be_within(0.01).of(width)
    expect((p1[1].x - v1[1].x).abs).to be_within(0.01).of(width)
    expect((p1[2].x - v1[2].x).abs).to be_within(0.01).of(width)
    expect((p1[3].x - v1[3].x).abs).to be_within(0.01).of(width)
    expect((p1[0].y - v1[0].y).abs).to be_within(0.01).of(0)
    expect((p1[1].y - v1[1].y).abs).to be_within(0.01).of(0)
    expect((p1[2].y - v1[2].y).abs).to be_within(0.01).of(0)
    expect((p1[3].y - v1[3].y).abs).to be_within(0.01).of(0)
    expect((p1[0].z - v1[0].z).abs).to be_within(0.01).of(width)
    expect((p1[1].z - v1[1].z).abs).to be_within(0.01).of(width)
    expect((p1[2].z - v1[2].z).abs).to be_within(0.01).of(width)
    expect((p1[3].z - v1[3].z).abs).to be_within(0.01).of(width)

    v2 = clerestory.vertices
    p2 = wins["clerestory"][:points]             # same as original OSM vertices
    expect((p2[0].x - v2[0].x).abs).to be_within(0.01).of(0)
    expect((p2[1].x - v2[1].x).abs).to be_within(0.01).of(0)
    expect((p2[2].x - v2[2].x).abs).to be_within(0.01).of(0)
    expect((p2[3].x - v2[3].x).abs).to be_within(0.01).of(0)
    expect((p2[0].y - v2[0].y).abs).to be_within(0.01).of(0)
    expect((p2[1].y - v2[1].y).abs).to be_within(0.01).of(0)
    expect((p2[2].y - v2[2].y).abs).to be_within(0.01).of(0)
    expect((p2[3].y - v2[3].y).abs).to be_within(0.01).of(0)
    expect((p2[0].z - v2[0].z).abs).to be_within(0.01).of(0)
    expect((p2[1].z - v2[1].z).abs).to be_within(0.01).of(0)
    expect((p2[2].z - v2[2].z).abs).to be_within(0.01).of(0)
    expect((p2[3].z - v2[3].z).abs).to be_within(0.01).of(0)

    # In addition, the top of the "Office Front Wall Window 1" is aligned with
    # the bottom of the clerestory, i.e. no conflicts between siblings.
    expect((p1[0].z - p2[1].z).abs).to be_within(0.01).of(0)
    expect((p1[3].z - p2[2].z).abs).to be_within(0.01).of(0)
    expect(TBD.status).to eq(TBD::WARN)

    # Testing both 'fits?' & 'overlaps?' functions.
    TBD.clean!
    vec1 = OpenStudio::Point3dVector.new
    vec2 = OpenStudio::Point3dVector.new
    p1.each { |p| vec1 << OpenStudio::Point3d.new(p.x, p.y, p.z) }
    p2.each { |p| vec2 << OpenStudio::Point3d.new(p.x, p.y, p.z) }
    expect(fits?(vec1, vec2)).to be(false)
    expect(overlaps?(vec1, vec2)).to be(false)
    # puts TBD.logs
    expect(TBD.status).to eq(0)

    # Same exercise, yet provide clerestory with Frame & Divider.
    fd2 = OpenStudio::Model::WindowPropertyFrameAndDivider.new(os_model_FD)
    width2 = 0.03
    expect(fd2.setFrameWidth(width2)).to be(true)
    expect(fd2.setFrameConductance(2.500)).to be(true)
    expect(clerestory.allowWindowPropertyFrameAndDivider).to be(true)
    expect(clerestory.setWindowPropertyFrameAndDivider(fd2)).to be(true)
    width3 = clerestory.windowPropertyFrameAndDivider.get.frameWidth
    expect(width3).to be_within(0.001).of(width2)

    TBD.clean!
    argh[:option] = "poor (BETBG)"
    io, surfaces = processTBD(os_model_FD, argh)

    # There should be a conflict between both windows equipped with F&D.
    expect(TBD.status).to eq(TBD::ERROR)
    expect(TBD.logs.size).to eq(13)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)
    expect(surfaces.key?(nom)).to be(true)
    expect(surfaces[nom].key?(:windows)).to be(true)
    wins = surfaces[nom][:windows]
    expect(wins.size).to eq(3)
    expect(wins.key?("clerestory")).to be(true)
    expect(wins.key?(name)).to be(true)
    expect(wins["clerestory"].key?(:points)).to be(true)
    expect(wins[name].key?(:points)).to be(true)

    # As there are conflicts between both windows (due to conflicting Frame &
    # Divider parameters), TBD will ignore Frame & Divider coordinates and fall
    # back to original OpenStudio subsurface vertices.
    v1 = window_FD.vertices                   # original OSM vertices for window
    p1 = wins[name][:points]        # TBD window vertices offset by frame width
    expect((p1[0].x - v1[0].x).abs).to be_within(0.01).of(0)
    expect((p1[1].x - v1[1].x).abs).to be_within(0.01).of(0)
    expect((p1[2].x - v1[2].x).abs).to be_within(0.01).of(0)
    expect((p1[3].x - v1[3].x).abs).to be_within(0.01).of(0)
    expect((p1[0].y - v1[0].y).abs).to be_within(0.01).of(0)
    expect((p1[1].y - v1[1].y).abs).to be_within(0.01).of(0)
    expect((p1[2].y - v1[2].y).abs).to be_within(0.01).of(0)
    expect((p1[3].y - v1[3].y).abs).to be_within(0.01).of(0)
    expect((p1[0].z - v1[0].z).abs).to be_within(0.01).of(0)
    expect((p1[1].z - v1[1].z).abs).to be_within(0.01).of(0)
    expect((p1[2].z - v1[2].z).abs).to be_within(0.01).of(0)
    expect((p1[3].z - v1[3].z).abs).to be_within(0.01).of(0)

    v2 = clerestory.vertices
    p2 = wins["clerestory"][:points]             # same as original OSM vertices
    expect((p2[0].x - v2[0].x).abs).to be_within(0.01).of(0)
    expect((p2[1].x - v2[1].x).abs).to be_within(0.01).of(0)
    expect((p2[2].x - v2[2].x).abs).to be_within(0.01).of(0)
    expect((p2[3].x - v2[3].x).abs).to be_within(0.01).of(0)
    expect((p2[0].y - v2[0].y).abs).to be_within(0.01).of(0)
    expect((p2[1].y - v2[1].y).abs).to be_within(0.01).of(0)
    expect((p2[2].y - v2[2].y).abs).to be_within(0.01).of(0)
    expect((p2[3].y - v2[3].y).abs).to be_within(0.01).of(0)
    expect((p2[0].z - v2[0].z).abs).to be_within(0.01).of(0)
    expect((p2[1].z - v2[1].z).abs).to be_within(0.01).of(0)
    expect((p2[2].z - v2[2].z).abs).to be_within(0.01).of(0)
    expect((p2[3].z - v2[3].z).abs).to be_within(0.01).of(0)

    # In addition, the top of the "Office Front Wall Window 1" is no longer
    # aligned with the bottom of the clerestory.
    expect(((p1[0].z - p2[1].z).abs - width2).abs).to be_within(0.01).of(0)
    expect(((p1[3].z - p2[2].z).abs - width2).abs).to be_within(0.01).of(0)

    TBD.clean!
    vec1 = OpenStudio::Point3dVector.new
    vec2 = OpenStudio::Point3dVector.new
    p1.each { |p| vec1 << OpenStudio::Point3d.new(p.x, p.y, p.z) }
    p2.each { |p| vec2 << OpenStudio::Point3d.new(p.x, p.y, p.z) }
    expect(fits?(vec1, vec2)).to be(false)
    expect(overlaps?(vec1, vec2)).to be(false)
    expect(TBD.status).to eq(0)


    # Testing more complex cases e.g., triangular windows, irregular 4-side
    # windows, rough opening edges overlapping parent surface edges.
    fd_model = OpenStudio::Model::Model.new
    space = OpenStudio::Model::Space.new(fd_model)
    space.setName("FD space")
    t, r = transforms(fd_model, space)
    expect(t.nil?).to be(false)
    expect(r.nil?).to be(false)

    # All subsurfaces are Simple Glazing constructions.
    fenestration = OpenStudio::Model::Construction.new(fd_model)
    expect(fenestration.handle.to_s.empty?).to be(false)
    expect(fenestration.nameString.empty?).to be(false)
    expect(fenestration.nameString).to eq("Construction 1")
    fenestration.setName("FD fenestration")
    expect(fenestration.nameString).to eq("FD fenestration")
    expect(fenestration.layers.size).to eq(0)

    glazing = OpenStudio::Model::SimpleGlazing.new(fd_model)
    expect(glazing.handle.to_s.empty?).to be(false)
    expect(glazing.nameString.empty?).to be(false)
    expect(glazing.nameString).to eq("Window Material Simple Glazing System 1")
    glazing.setName("FD glazing")
    expect(glazing.nameString).to eq("FD glazing")
    expect(glazing.setUFactor(2.0)).to be(true)
    expect(glazing.setSolarHeatGainCoefficient(0.50)).to be(true)
    expect(glazing.setVisibleTransmittance(0.70)).to be(true)

    layers = OpenStudio::Model::MaterialVector.new
    layers << glazing
    expect(fenestration.setLayers(layers)).to be(true)
    expect(fenestration.layers.size).to eq(1)
    expect(fenestration.layers[0].handle.to_s).to eq(glazing.handle.to_s)
    expect(fenestration.uFactor.empty?).to be(false)
    expect(fenestration.uFactor.get).to be_within(0.1).of(2.0)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  0.00,  0.00, 10.00)
    vec << OpenStudio::Point3d.new(  0.00,  0.00,  0.00)
    vec << OpenStudio::Point3d.new( 10.00,  0.00,  0.00)
    vec << OpenStudio::Point3d.new( 10.00,  0.00, 10.00)
    dad = OpenStudio::Model::Surface.new(vec, fd_model)
    dad.setName("dad")
    expect(dad.setSpace(space)).to be(true)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  2.00,  0.00,  8.00)
    vec << OpenStudio::Point3d.new(  1.00,  0.00,  6.00)
    vec << OpenStudio::Point3d.new(  4.00,  0.00,  9.00)
    w1 = OpenStudio::Model::SubSurface.new(vec, fd_model)
    w1.setName("w1")
    expect(w1.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w1.setSurface(dad)).to be(true)
    expect(w1.setConstruction(fenestration)).to be(true)
    expect(w1.uFactor.empty?).to be(false)
    expect(w1.uFactor.get).to be_within(0.1).of(2.0)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  7.00,  0.00,  4.00)
    vec << OpenStudio::Point3d.new(  4.00,  0.00,  1.00)
    vec << OpenStudio::Point3d.new(  8.00,  0.00,  2.00)
    vec << OpenStudio::Point3d.new(  9.00,  0.00,  3.00)
    w2 = OpenStudio::Model::SubSurface.new(vec, fd_model)
    w2.setName("w2")
    expect(w2.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w2.setSurface(dad)).to be(true)
    expect(w2.setConstruction(fenestration)).to be(true)
    expect(w2.uFactor.empty?).to be(false)
    expect(w2.uFactor.get).to be_within(0.1).of(2.0)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  9.00,  0.00,  9.80)
    vec << OpenStudio::Point3d.new(  9.80,  0.00,  9.00)
    vec << OpenStudio::Point3d.new(  9.80,  0.00,  9.80)
    w3 = OpenStudio::Model::SubSurface.new(vec, fd_model)
    w3.setName("w3")
    expect(w3.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w3.setSurface(dad)).to be(true)
    expect(w3.setConstruction(fenestration)).to be(true)
    expect(w3.uFactor.empty?).to be(false)
    expect(w3.uFactor.get).to be_within(0.1).of(2.0)

    # Without Frame & Divider objects linked to subsurface.
    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:gross)).to be(true)
    expect(surface[:gross]).to be_a(Numeric)
    expect(surface[:gross]).to be_within(0.1).of(100)
    expect(surface.key?(:net)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w1"))
    expect(surface[:windows]["w1"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w1"].key?(:gross)).to be(true)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.01).of(1.5)
    expect(surface[:windows]["w1"].key?(:u)).to be(true)
    expect(surface[:windows]["w1"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w1"].key?(:points)).to be(true)
    expect(surface[:windows]["w1"][:points].size).to eq(3)

    # Adding a Frame & Divider object.
    fd = OpenStudio::Model::WindowPropertyFrameAndDivider.new(fd_model)
    expect(fd.setFrameWidth(0.200)).to be(true)   # 200mm (wide!) around glazing
    expect(fd.setFrameConductance(0.500)).to be(true)

    expect(w1.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w1.setWindowPropertyFrameAndDivider(fd)).to be(true)
    width = w1.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)                # good so far ...

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w1"))
    expect(surface[:windows]["w1"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w1"].key?(:gross)).to be(true)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.01).of(3.75)
    expect(surface[:windows]["w1"].key?(:u)).to be(true)
    expect(surface[:windows]["w1"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w1"].key?(:points)).to be(true)

    ptz = surface[:windows]["w1"][:points]
    expect(ptz.size).to eq(3)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # The following X & Z coordinates are all offset by 0.200 (frame width),
    # with respect to the original subsurface coordinates. For acute angles,
    # the rough opening edge intersection can be far, far away from the glazing
    # coordinates (+1m).
    expect(vec[0].x).to be_within(0.01).of( 1.85)
    expect(vec[0].y).to be_within(0.01).of( 0.00)
    expect(vec[0].z).to be_within(0.01).of( 8.15)
    expect(vec[1].x).to be_within(0.01).of( 0.27)
    expect(vec[1].y).to be_within(0.01).of( 0.00)
    expect(vec[1].z).to be_within(0.01).of( 4.99)
    expect(vec[2].x).to be_within(0.01).of( 5.01)
    expect(vec[2].y).to be_within(0.01).of( 0.00)
    expect(vec[2].z).to be_within(0.01).of( 9.73)

    # Adding a Frame & Divider object for w2.
    expect(w2.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w2.setWindowPropertyFrameAndDivider(fd)).to be(true)
    width = w2.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w2"))
    expect(surface[:windows]["w2"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w2"].key?(:gross)).to be(true)
    expect(surface[:windows]["w2"][:gross]).to be_within(0.01).of(8.64)
    expect(surface[:windows]["w2"].key?(:u)).to be(true)
    expect(surface[:windows]["w2"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w2"].key?(:points)).to be(true)

    ptz = surface[:windows]["w2"][:points]
    expect(ptz.size).to eq(4)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # # This window would have 2 shared edges (@right angle) with the parent.
    expect(vec[0].x).to be_within(0.01).of( 6.96)
    expect(vec[0].y).to be_within(0.01).of( 0.00)
    expect(vec[0].z).to be_within(0.01).of( 4.24)
    expect(vec[1].x).to be_within(0.01).of( 3.35)
    expect(vec[1].y).to be_within(0.01).of( 0.00)
    expect(vec[1].z).to be_within(0.01).of( 0.63)
    expect(vec[2].x).to be_within(0.01).of( 8.10)
    expect(vec[2].y).to be_within(0.01).of( 0.00)
    expect(vec[2].z).to be_within(0.01).of( 1.82)
    expect(vec[3].x).to be_within(0.01).of( 9.34)
    expect(vec[3].y).to be_within(0.01).of( 0.00)
    expect(vec[3].z).to be_within(0.01).of( 3.05)

    # Adding a Frame & Divider object for w3.
    expect(w3.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w3.setWindowPropertyFrameAndDivider(fd)).to be(true)
    width = w3.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w3"))
    expect(surface[:windows]["w3"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w3"].key?(:gross)).to be(true)
    expect(surface[:windows]["w3"][:gross]).to be_within(0.01).of(1.1)
    expect(surface[:windows]["w3"].key?(:u)).to be(true)
    expect(surface[:windows]["w3"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w3"].key?(:points)).to be(true)

    ptz = surface[:windows]["w3"][:points]
    expect(ptz.size).to eq(3)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # # This window would have 2 shared edges (@right angle) with the parent.
    expect(vec[0].x).to be_within(0.01).of( 8.52)
    expect(vec[0].y).to be_within(0.01).of( 0.00)
    expect(vec[0].z).to be_within(0.01).of(10.00)
    expect(vec[1].x).to be_within(0.01).of(10.00)
    expect(vec[1].y).to be_within(0.01).of( 0.00)
    expect(vec[1].z).to be_within(0.01).of( 8.52)
    expect(vec[2].x).to be_within(0.01).of(10.00)
    expect(vec[2].y).to be_within(0.01).of( 0.00)
    expect(vec[2].z).to be_within(0.01).of(10.00)


    # Repeat exercise, with parent surface & subsurfaces rotated 120 (CW).
    # (i.e., negative coordinates, Y-axis coordinates, etc.)
    fd2_model = OpenStudio::Model::Model.new
    space2 = OpenStudio::Model::Space.new(fd2_model)
    space2.setName("FD 2 space")
    t, r = transforms(fd2_model, space2)
    expect(t.nil?).to be(false)
    expect(r.nil?).to be(false)

    # All subsurfaces are Simple Glazing constructions.
    fenestration = OpenStudio::Model::Construction.new(fd2_model)
    expect(fenestration.handle.to_s.empty?).to be(false)
    expect(fenestration.nameString.empty?).to be(false)
    expect(fenestration.nameString).to eq("Construction 1")
    fenestration.setName("FD2 fenestration")
    expect(fenestration.nameString).to eq("FD2 fenestration")
    expect(fenestration.layers.size).to eq(0)

    glazing = OpenStudio::Model::SimpleGlazing.new(fd2_model)
    expect(glazing.handle.to_s.empty?).to be(false)
    expect(glazing.nameString.empty?).to be(false)
    expect(glazing.nameString).to eq("Window Material Simple Glazing System 1")
    glazing.setName("FD2 glazing")
    expect(glazing.nameString).to eq("FD2 glazing")
    expect(glazing.setUFactor(2.0)).to be(true)
    expect(glazing.setSolarHeatGainCoefficient(0.50)).to be(true)
    expect(glazing.setVisibleTransmittance(0.70)).to be(true)

    layers = OpenStudio::Model::MaterialVector.new
    layers << glazing
    expect(fenestration.setLayers(layers)).to be(true)
    expect(fenestration.layers.size).to eq(1)
    expect(fenestration.layers[0].handle.to_s).to eq(glazing.handle.to_s)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  0.00,  0.00, 10.00)
    vec << OpenStudio::Point3d.new(  0.00,  0.00,  0.00)
    vec << OpenStudio::Point3d.new( -5.00, -8.66,  0.00)
    vec << OpenStudio::Point3d.new( -5.00, -8.66, 10.00)
    dad = OpenStudio::Model::Surface.new(vec, fd2_model)
    dad.setName("dad")
    expect(dad.setSpace(space2)).to be(true)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -1.00, -1.73,  8.00)
    vec << OpenStudio::Point3d.new( -0.50, -0.87,  6.00)
    vec << OpenStudio::Point3d.new( -2.00, -3.46,  9.00)
    w1 = OpenStudio::Model::SubSurface.new(vec, fd2_model)
    w1.setName("w1")
    expect(w1.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w1.setSurface(dad)).to be(true)
    expect(w1.setConstruction(fenestration)).to be(true)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -3.50, -6.06,  4.00)
    vec << OpenStudio::Point3d.new( -2.00, -3.46,  1.00)
    vec << OpenStudio::Point3d.new( -4.00, -6.93,  2.00)
    vec << OpenStudio::Point3d.new( -4.50, -7.79,  3.00)
    w2 = OpenStudio::Model::SubSurface.new(vec, fd2_model)
    w2.setName("w2")
    expect(w2.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w2.setSurface(dad)).to be(true)
    expect(w2.setConstruction(fenestration)).to be(true)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -4.50, -7.79,  9.80)
    vec << OpenStudio::Point3d.new( -4.90, -8.49,  9.00)
    vec << OpenStudio::Point3d.new( -4.90, -8.49,  9.80)
    w3 = OpenStudio::Model::SubSurface.new(vec, fd2_model)
    w3.setName("w3")
    expect(w3.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w3.setSurface(dad)).to be(true)
    expect(w3.setConstruction(fenestration)).to be(true)
    expect(w3.grossArea).to be_within(0.01).of(0.32)

    # Without Frame & Divider objects linked to subsurface.
    surface = openings(fd2_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:gross)).to be(true)
    expect(surface[:gross]).to be_a(Numeric)
    expect(surface[:gross]).to be_within(0.1).of(100)
    expect(surface.key?(:net)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w1"))
    expect(surface[:windows]["w1"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w1"].key?(:gross)).to be(true)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.01).of(1.5)
    expect(surface[:windows]["w1"].key?(:u)).to be(true)
    expect(surface[:windows]["w1"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w1"].key?(:points)).to be(true)
    expect(surface[:windows]["w1"][:points].size).to eq(3)

    expect(surface[:windows].key?("w3"))
    expect(surface[:windows]["w3"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w3"].key?(:gross)).to be(true)
    expect(surface[:windows]["w3"][:gross]).to be_within(0.01).of(0.32)

    # Adding a Frame & Divider object.
    fd2 = OpenStudio::Model::WindowPropertyFrameAndDivider.new(fd2_model)
    expect(fd2.setFrameWidth(0.200)).to be(true)   # 200mm (wide!) around glazing
    expect(fd2.setFrameConductance(0.500)).to be(true)

    expect(w1.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w1.setWindowPropertyFrameAndDivider(fd2)).to be(true)
    width = w1.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)                # good so far ...

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w1"))
    expect(surface[:windows]["w1"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w1"].key?(:gross)).to be(true)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.01).of(3.75)
    expect(surface[:windows]["w1"].key?(:u)).to be(true)
    expect(surface[:windows]["w1"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w1"].key?(:points)).to be(true)

    ptz = surface[:windows]["w1"][:points]
    expect(ptz.size).to eq(3)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # The following X & Z coordinates are all offset by 0.200 (frame width),
    # with respect to the original subsurface coordinates. For acute angles,
    # the rough opening edge intersection can be far, far away from the glazing
    # coordinates (+1m).
    expect(vec[0].x).to be_within(0.01).of(-0.93)
    expect(vec[0].y).to be_within(0.01).of(-1.60)
    expect(vec[0].z).to be_within(0.01).of( 8.15)
    expect(vec[1].x).to be_within(0.01).of(-0.13)
    expect(vec[1].y).to be_within(0.01).of(-0.24) # SketchUP (-0.23)
    expect(vec[1].z).to be_within(0.01).of( 4.99)
    expect(vec[2].x).to be_within(0.01).of(-2.51)
    expect(vec[2].y).to be_within(0.01).of(-4.34)
    expect(vec[2].z).to be_within(0.01).of( 9.73)

    # Adding a Frame & Divider object for w2.
    expect(w2.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w2.setWindowPropertyFrameAndDivider(fd2)).to be(true)
    width = w2.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w2"))
    expect(surface[:windows]["w2"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w2"].key?(:gross)).to be(true)
    expect(surface[:windows]["w2"][:gross]).to be_within(0.01).of(8.64)
    expect(surface[:windows]["w2"].key?(:u)).to be(true)
    expect(surface[:windows]["w2"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w2"].key?(:points)).to be(true)

    ptz = surface[:windows]["w2"][:points]
    expect(ptz.size).to eq(4)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # # This window would have 2 shared edges (@right angle) with the parent.
    expect(vec[0].x).to be_within(0.01).of(-3.48)
    expect(vec[0].y).to be_within(0.01).of(-6.03)
    expect(vec[0].z).to be_within(0.01).of( 4.24)
    expect(vec[1].x).to be_within(0.01).of(-1.67)
    expect(vec[1].y).to be_within(0.01).of(-2.90)
    expect(vec[1].z).to be_within(0.01).of( 0.63)
    expect(vec[2].x).to be_within(0.01).of(-4.05)
    expect(vec[2].y).to be_within(0.01).of(-7.02)
    expect(vec[2].z).to be_within(0.01).of( 1.82)
    expect(vec[3].x).to be_within(0.01).of(-4.67)
    expect(vec[3].y).to be_within(0.01).of(-8.09)
    expect(vec[3].z).to be_within(0.01).of( 3.05)

    # Adding a Frame & Divider object for w3.
    expect(w3.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w3.setWindowPropertyFrameAndDivider(fd2)).to be(true)
    width = w3.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w3"))
    expect(surface[:windows]["w3"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w3"].key?(:gross)).to be(true)
    expect(surface[:windows]["w3"][:gross]).to be_within(0.01).of(1.1)
    expect(surface[:windows]["w3"].key?(:u)).to be(true)
    expect(surface[:windows]["w3"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w3"].key?(:points)).to be(true)

    ptz = surface[:windows]["w3"][:points]
    expect(ptz.size).to eq(3)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # # This window would have 2 shared edges (@right angle) with the parent.
    expect(vec[0].x).to be_within(0.01).of(-4.26)
    expect(vec[0].y).to be_within(0.01).of(-7.37) # SketchUp (-7.38)
    expect(vec[0].z).to be_within(0.01).of(10.00)
    expect(vec[1].x).to be_within(0.01).of(-5.00)
    expect(vec[1].y).to be_within(0.01).of(-8.66)
    expect(vec[1].z).to be_within(0.01).of( 8.52)
    expect(vec[2].x).to be_within(0.01).of(-5.00)
    expect(vec[2].y).to be_within(0.01).of(-8.66)
    expect(vec[2].z).to be_within(0.01).of(10.00)


    # Repeat 3rd time - 2x 30° rotations (along the 2 other axes).
    fd3_model = OpenStudio::Model::Model.new
    space3 = OpenStudio::Model::Space.new(fd3_model)
    space3.setName("FD 3 space")
    t, r = transforms(fd3_model, space3)
    expect(t.nil?).to be(false)
    expect(r.nil?).to be(false)

    # All subsurfaces are Simple Glazing constructions.
    fenestration = OpenStudio::Model::Construction.new(fd3_model)
    expect(fenestration.handle.to_s.empty?).to be(false)
    expect(fenestration.nameString.empty?).to be(false)
    expect(fenestration.nameString).to eq("Construction 1")
    fenestration.setName("FD3 fenestration")
    expect(fenestration.nameString).to eq("FD3 fenestration")
    expect(fenestration.layers.size).to eq(0)

    glazing = OpenStudio::Model::SimpleGlazing.new(fd3_model)
    expect(glazing.handle.to_s.empty?).to be(false)
    expect(glazing.nameString.empty?).to be(false)
    expect(glazing.nameString).to eq("Window Material Simple Glazing System 1")
    glazing.setName("FD3 glazing")
    expect(glazing.nameString).to eq("FD3 glazing")
    expect(glazing.setUFactor(2.0)).to be(true)
    expect(glazing.setSolarHeatGainCoefficient(0.50)).to be(true)
    expect(glazing.setVisibleTransmittance(0.70)).to be(true)

    layers = OpenStudio::Model::MaterialVector.new
    layers << glazing
    expect(fenestration.setLayers(layers)).to be(true)
    expect(fenestration.layers.size).to eq(1)
    expect(fenestration.layers[0].handle.to_s).to eq(glazing.handle.to_s)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -1.25,  6.50,  7.50)
    vec << OpenStudio::Point3d.new(  0.00,  0.00,  0.00)
    vec << OpenStudio::Point3d.new( -6.50, -6.25,  4.33)
    vec << OpenStudio::Point3d.new( -7.75,  0.25, 11.83)
    dad = OpenStudio::Model::Surface.new(vec, fd3_model)
    dad.setName("dad")
    dad.setSpace(space3)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -2.30,  3.95,  6.87)
    vec << OpenStudio::Point3d.new( -1.40,  3.27,  4.93)
    vec << OpenStudio::Point3d.new( -3.72,  3.35,  8.48)
    w1 = OpenStudio::Model::SubSurface.new(vec, fd3_model)
    w1.setName("w1")
    expect(w1.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w1.setSurface(dad)).to be(true)
    expect(w1.setConstruction(fenestration)).to be(true)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -5.05, -1.78,  6.03)
    vec << OpenStudio::Point3d.new( -2.72, -1.85,  2.48)
    vec << OpenStudio::Point3d.new( -5.45, -3.70,  4.96)
    vec << OpenStudio::Point3d.new( -6.22, -3.68,  6.15)
    w2 = OpenStudio::Model::SubSurface.new(vec, fd3_model)
    w2.setName("w2")
    expect(w2.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w2.setSurface(dad)).to be(true)
    expect(w2.setConstruction(fenestration)).to be(true)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -7.07,  0.74, 11.25)
    vec << OpenStudio::Point3d.new( -7.49, -0.28, 10.99)
    vec << OpenStudio::Point3d.new( -7.59,  0.24, 11.59)
    w3 = OpenStudio::Model::SubSurface.new(vec, fd3_model)
    w3.setName("w3")
    expect(w3.setSubSurfaceType("FixedWindow")).to be(true)
    expect(w3.setSurface(dad)).to be(true)
    expect(w3.setConstruction(fenestration)).to be(true)

    # Without Frame & Divider objects linked to subsurface.
    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:gross)).to be(true)
    expect(surface[:gross]).to be_a(Numeric)
    expect(surface[:gross]).to be_within(0.1).of(100)
    expect(surface.key?(:net)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w1"))
    expect(surface[:windows]["w1"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w1"].key?(:gross)).to be(true)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.02).of(1.5)
    expect(surface[:windows]["w1"].key?(:u)).to be(true)
    expect(surface[:windows]["w1"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w1"].key?(:points)).to be(true)
    expect(surface[:windows]["w1"][:points].size).to eq(3)

    # Adding a Frame & Divider object.
    fd3 = OpenStudio::Model::WindowPropertyFrameAndDivider.new(fd3_model)
    expect(fd3.setFrameWidth(0.200)).to be(true)  # 200mm (wide!) around glazing
    expect(fd3.setFrameConductance(0.500)).to be(true)

    expect(w1.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w1.setWindowPropertyFrameAndDivider(fd3)).to be(true)
    width = w1.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)                # good so far ...

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w1"))
    expect(surface[:windows]["w1"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w1"].key?(:gross)).to be(true)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.02).of(3.75)
    expect(surface[:windows]["w1"].key?(:u)).to be(true)
    expect(surface[:windows]["w1"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w1"].key?(:points)).to be(true)

    ptz = surface[:windows]["w1"][:points]
    expect(ptz.size).to eq(3)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # The following X & Z coordinates are all offset by 0.200 (frame width),
    # with respect to the original subsurface coordinates. For acute angles,
    # the rough opening edge intersection can be far, far away from the glazing
    # coordinates (+1m).
    expect(vec[0].x).to be_within(0.01).of(-2.22)
    expect(vec[0].y).to be_within(0.01).of( 4.14)
    expect(vec[0].z).to be_within(0.01).of( 6.91)
    expect(vec[1].x).to be_within(0.01).of(-0.80)
    expect(vec[1].y).to be_within(0.01).of( 3.07)
    expect(vec[1].z).to be_within(0.01).of( 3.86)
    expect(vec[2].x).to be_within(0.01).of(-4.47)
    expect(vec[2].y).to be_within(0.01).of( 3.19)
    expect(vec[2].z).to be_within(0.01).of( 9.46) # SketchUp (-9.47)

    # Adding a Frame & Divider object for w2.
    expect(w2.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w2.setWindowPropertyFrameAndDivider(fd3)).to be(true)
    width = w2.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w2"))
    expect(surface[:windows]["w2"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w2"].key?(:gross)).to be(true)
    expect(surface[:windows]["w2"][:gross]).to be_within(0.01).of(8.64)
    expect(surface[:windows]["w2"].key?(:u)).to be(true)
    expect(surface[:windows]["w2"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w2"].key?(:points)).to be(true)

    ptz = surface[:windows]["w2"][:points]
    expect(ptz.size).to eq(4)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # # This window would have 2 shared edges (@right angle) with the parent.
    expect(vec[0].x).to be_within(0.01).of(-5.05)
    expect(vec[0].y).to be_within(0.01).of(-1.59)
    expect(vec[0].z).to be_within(0.01).of( 6.20)
    expect(vec[1].x).to be_within(0.01).of(-2.25)
    expect(vec[1].y).to be_within(0.01).of(-1.68)
    expect(vec[1].z).to be_within(0.01).of( 1.92)
    expect(vec[2].x).to be_within(0.01).of(-5.49)
    expect(vec[2].y).to be_within(0.01).of(-3.88)
    expect(vec[2].z).to be_within(0.01).of( 4.87)
    expect(vec[3].x).to be_within(0.01).of(-6.45)
    expect(vec[3].y).to be_within(0.01).of(-3.85)
    expect(vec[3].z).to be_within(0.01).of( 6.33)

    # Adding a Frame & Divider object for w3.
    expect(w3.allowWindowPropertyFrameAndDivider).to be(true)
    expect(w3.setWindowPropertyFrameAndDivider(fd3)).to be(true)
    width = w3.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = openings(fd_model, dad)
    expect(surface.nil?).to be(false)
    expect(surface.is_a?(Hash)).to be(true)
    expect(surface.key?(:windows)).to be(true)
    expect(surface[:windows].is_a?(Hash)).to be(true)
    expect(surface[:windows].key?("w3"))
    expect(surface[:windows]["w3"].is_a?(Hash)).to be(true)
    expect(surface[:windows]["w3"].key?(:gross)).to be(true)
    expect(surface[:windows]["w3"][:gross]).to be_within(0.01).of(1.1)
    expect(surface[:windows]["w3"].key?(:u)).to be(true)
    expect(surface[:windows]["w3"][:u]).to be_within(0.01).of(2.0)
    expect(surface[:windows]["w3"].key?(:points)).to be(true)

    ptz = surface[:windows]["w3"][:points]
    expect(ptz.size).to eq(3)

    vec = OpenStudio::Point3dVector.new
    ptz.each { |p| vec << t * OpenStudio::Point3d.new(p.x, p.y, p.z) }

    # This window would have 2 shared edges (@right angle) with the parent.
    expect(vec[0].x).to be_within(0.01).of(-6.78)
    expect(vec[0].y).to be_within(0.01).of( 1.17)
    expect(vec[0].z).to be_within(0.01).of(11.19)
    expect(vec[1].x).to be_within(0.01).of(-7.56)
    expect(vec[1].y).to be_within(0.01).of(-0.72)
    expect(vec[1].z).to be_within(0.01).of(10.72)
    expect(vec[2].x).to be_within(0.01).of(-7.75)
    expect(vec[2].y).to be_within(0.01).of( 0.25)
    expect(vec[2].z).to be_within(0.01).of(11.83)
  end

  it "can flag errors and integrate TBD logs in JSON output" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    office = os_model.getSpaceByName("Zone1 Office")
    expect(office.empty?).to be(false)

    front_office_wall = os_model.getSurfaceByName("Office Front Wall")
    expect(front_office_wall.empty?).to be(false)
    front_office_wall = front_office_wall.get
    expect(front_office_wall.nameString).to eq("Office Front Wall")
    expect(front_office_wall.surfaceType).to eq("Wall")

    left_office_wall = os_model.getSurfaceByName("Office Left Wall")
    expect(left_office_wall.empty?).to be(false)
    left_office_wall = left_office_wall.get
    expect(left_office_wall.nameString).to eq("Office Left Wall")
    expect(left_office_wall.surfaceType).to eq("Wall")

    right_fine_wall = os_model.getSurfaceByName("Fine Storage Right Wall")
    expect(right_fine_wall.empty?).to be(false)
    right_fine_wall = right_fine_wall.get
    expect(right_fine_wall.nameString).to eq("Fine Storage Right Wall")
    expect(right_fine_wall.surfaceType).to eq("Wall")

    # Adding a small, 5-sided window to the "Office Front Wall" (above door).
    os_v = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 12.96, 0.00, 4.00)
    os_v << OpenStudio::Point3d.new( 12.04, 0.00, 3.50)
    os_v << OpenStudio::Point3d.new( 12.04, 0.00, 2.50)
    os_v << OpenStudio::Point3d.new( 13.87, 0.00, 2.50)
    os_v << OpenStudio::Point3d.new( 13.87, 0.00, 3.50)
    clerestory = OpenStudio::Model::SubSurface.new(os_v, os_model)
    clerestory.setName("clerestory")
    expect(clerestory.setSurface(front_office_wall)).to be(true)
    expect(clerestory.setSubSurfaceType("FixedWindow")).to be(true)
    # ... reminder: set subsurface type AFTER setting its parent surface.

    # A new, highly-conductive material (RSi = 0.001 m2.K/W) - the OS min.
    material = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    material.setName("poor material")
    expect(material.nameString).to eq("poor material")
    expect(material.setThermalResistance(0.001)).to be(true)
    expect(material.thermalResistance).to be_within(0.0001).of(0.001)
    mat = OpenStudio::Model::MaterialVector.new
    mat << material

    # A 'standard' variant (also gives RSi = 0.001 m2.K/W)
    material2 = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
    material2.setName("poor material2")
    expect(material2.nameString).to eq("poor material2")
    expect(material2.setThermalConductivity(3.0)).to be(true)
    expect(material2.thermalConductivity).to be_within(0.01).of(3.0)
    expect(material2.setThickness(0.003)).to be(true)
    expect(material2.thickness).to be_within(0.001).of(0.003)
    mat2 = OpenStudio::Model::MaterialVector.new
    mat2 << material2

    # Another 'massless' material, whose name already includes " tbd".
    material3 = OpenStudio::Model::MasslessOpaqueMaterial.new(os_model)
    material3.setName("poor material m tbd")
    expect(material3.nameString).to eq("poor material m tbd")
    expect(material3.setThermalResistance(1.0)).to be(true)
    expect(material3.thermalResistance).to be_within(0.1).of(1.0)
    mat3 = OpenStudio::Model::MaterialVector.new
    mat3 << material3

    # Assign highly-conductive material to a new construction.
    construction = OpenStudio::Model::Construction.new(os_model)
    construction.setName("poor construction")
    expect(construction.nameString).to eq("poor construction")
    expect(construction.layers.size).to eq(0)
    expect(construction.setLayers(mat2)).to be(true) # or switch with 'mat'
    expect(construction.layers.size).to eq(1)

    # Assign " tbd" massless material to a new construction.
    construction2 = OpenStudio::Model::Construction.new(os_model)
    construction2.setName("poor construction tbd")
    expect(construction2.nameString).to eq("poor construction tbd")
    expect(construction2.layers.size).to eq(0)
    expect(construction2.setLayers(mat3)).to be(true)
    expect(construction2.layers.size).to eq(1)

    # Assign construction to the "Office Left Wall".
    expect(left_office_wall.setConstruction(construction)).to be(true)

    # Assign construction2 to the "Fine Storage Right Wall".
    expect(right_fine_wall.setConstruction(construction2)).to be(true)

    subs = front_office_wall.subSurfaces
    expect(subs.empty?).to be(false)
    expect(subs.size).to eq(4)

    argh[:option] = "poor (BETBG)"
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse9.json")
    # {
    #   "schema": "https://github.com/rd2/tbd/blob/master/tbd.schema.json",
    #   "description": "testing error detection",
    #   "psis": [
    #     {
    #       "id": "detailed 2",
    #       "fenestration": 0.600
    #     },
    #     {
    #       "id": "regular (BETBG)",   <<<< ERROR #1 - can't reset built-in sets
    #       "fenestration": 0.700
    #     }
    #   ],
    #   "khis": [
    #     {
    #       "id": "cantilevered beam",
    #       "point": 0.6
    #     }
    #   ],
    #   "surfaces": [
    #     {
    #       "id": "Office Front Wall",
    #       "khis": [
    #         {
    #           "id": "beam",      <<<< ERROR #2 - 'beam' not previously defined
    #           "count": 3
    #         }
    #       ]
    #     },
    #     {
    #       "id": "Office Left Wall",
    #       "khis": [
    #         {
    #           "id": "cantilevered beam",
    #           "count": 300      <<<< WARNING #1 - heat loss too great (for m2)
    #         }
    #       ]
    #     }
    #   ],
    #   "edges": [
    #     {
    #       "psi": "detailed", <<<< ERROR #3 - 'detailed' not previously defined
    #       "type": "fenestration",
    #       "surfaces": [
    #         "Office Front Wall",
    #         "Office Front Wall Window 1"
    #       ]
    #     }
    #   ]
    # }
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    io, surfaces = processTBD(os_model, argh)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(io.key?(:edges))
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)
    expect(surfaces.key?("Office Front Wall")).to be(true)
    expect(surfaces["Office Front Wall"].key?(:edges)).to be(true)
    expect(surfaces.key?("Office Left Wall")).to be(true)
    expect(surfaces["Office Left Wall"].key?(:edges)).to be(true)
    expect(surfaces.key?("Fine Storage Right Wall")).to be(true)
    expect(surfaces["Fine Storage Right Wall"].key?(:edges)).to be(true)

    expect(TBD.status).to eq(TBD::ERROR)
    expect(TBD.logs.size).to eq(6)
    # TBD.logs.each { |log| puts log[:msg] }
    #   'clerestory' vertex count (3 or 4)
    #   Can't override 'regular (BETBG)' PSI set  - skipping
    #   'Office Front Wall' KHI 'beam' mismatch
    #   'Office Front Wall' edge PSI set mismatch - skipping
    #   Can't assign 180.007 W/K to 'Office Left Wall' - too conductive
    #   Can't derate 'Fine Storage Right Wall' - material already derated

    # Despite input file (non-fatal) errors, TBD successfully processes thermal
    # bridges and derates OSM construction materials by falling back on defaults
    # in the case of errors.

    # For the 5-sided window, TBD will simply ignore all edges/bridges linked to
    # the 'clerestory' subsurface.
    io[:edges].each do |edge|
      expect(edge.key?(:surfaces)).to be(true)
      edge[:surfaces].each { |s| expect(s).to_not eq("clerestory") }
    end
    expect(surfaces["Office Front Wall"][:edges].size).to eq(17)
    sills = 0
    surfaces["Office Front Wall"][:edges].values.each do |e|
      expect(e.key?(:type)).to be(true)
      sills += 1 if e[:type] == :sill
    end
    expect(sills).to eq(2)                                               # not 3

    # Fallback to ERROR # 1: not really a fallback, more a demonstration that
    # "regular (BETBG)" isn't referred to by any edge-linked derated surfaces.
    # ... & fallback to ERROR # 3: no edge relying on 'detailed' PSI set.
    io[:edges].each { |edge| expect(edge[:psi]).to eq("poor (BETBG)") }

    # Fallback to ERROR # 2: no KHI for "Office Front Wall".
    expect(io.key?(:khis)).to be(true)
    expect(io[:khis].size).to eq(1)
    expect(surfaces["Office Front Wall"].key?(:khis)).to be(false)

    # ... concerning the "Office Left Wall" (underatable material).
    left_office_wall = os_model.getSurfaceByName("Office Left Wall")
    expect(left_office_wall.empty?).to be(false)
    left_office_wall = left_office_wall.get
    c = left_office_wall.construction.get.to_Construction.get
    expect(c.numLayers).to eq(1)
    #layer = c.getLayer(0).to_MasslessOpaqueMaterial
    layer = c.getLayer(0).to_StandardOpaqueMaterial
    expect(layer.empty?).to be(false)
    layer = layer.get
    expect(layer.name.get).to eq("'Office Left Wall' m tbd")
    #expect(layer.thermalResistance).to be_within(0.001).of(0.001)
    expect(layer.thermalConductivity).to be_within(0.1).of(3.0)
    expect(layer.thickness).to be_within(0.001).of(0.003)
    # Regardless of the targetted material type ('standard' vs 'massless'), TBD
    # will ensure a minimal RSi value of 0.001 m2.K/W, i.e. no derating despite
    # the surface having thermal bridges.
    expect(surfaces["Office Left Wall"].key?(:heatloss)).to be(true)
    expect(surfaces["Office Left Wall"][:heatloss]).to be_within(0.1).of(180)
    expect(surfaces["Office Left Wall"].key?(:r_heatloss)).to be(true)
    expect(surfaces["Office Left Wall"][:r_heatloss]).to be_within(0.1).of(180)

    expect(surfaces["Fine Storage Right Wall"].key?(:heatloss)).to be(true)
    expect(surfaces["Fine Storage Right Wall"].key?(:r_heatloss)).to be(false)
    # ... concerning the new material (with a name already including " tbd").
    # TBD ignores all such materials (a safeguard against iterative TBD
    # runs). Contrary to the previous critical cases of highly conductive
    # materials, TBD doesn't even try to set the :r_heatloss hash value - tough!
    right_fine_wall = os_model.getSurfaceByName("Fine Storage Right Wall")
    expect(right_fine_wall.empty?).to be(false)
    right_fine_wall = right_fine_wall.get
    c = right_fine_wall.construction.get.to_Construction.get
    layer = c.getLayer(0).to_MasslessOpaqueMaterial
    expect(layer.empty?).to be(false)
    layer = layer.get
    expect(layer.name.get).to eq("poor material m tbd")
    expect(layer.thermalResistance).to be_within(0.1).of(1.0)

    # Mimics (somewhat) the TBD 'measure.rb' method 'exitTBD()'
    # ... should generate a 'logs' entry at the  of the JSON output file.
    status = TBD.msg(TBD.status)
    status = TBD.msg(TBD::INFO) if TBD.status.zero?

    tbd_log = { date: Time.now, status: status }

    results = []
    if surfaces
      surfaces.each do |id, surface|
        next if TBD.fatal?
        next unless surface.key?(:ratio)
        ratio  = format "%3.1f", surface[:ratio]
        name   = id.rjust(15, " ")
        output = "#{name} RSi derated by #{ratio}%"
        results << output
      end
    end
    tbd_log[:results] = results unless results.empty?

    tbd_msgs = []
    TBD.logs.each do |l|
      tbd_msgs << { level: TBD.tag(l[:level]), message: l[:message] }
    end
    tbd_log[:messages] = tbd_msgs unless tbd_msgs.empty?

    io[:log] = tbd_log

    # Deterministic sorting
    io[:schema]       = io.delete(:schema)      if io.key?(:schema)
    io[:description]  = io.delete(:description) if io.key?(:description)
    io[:log]          = io.delete(:log)         if io.key?(:log)
    io[:psis]         = io.delete(:psis)        if io.key?(:psis)
    io[:khis]         = io.delete(:khis)        if io.key?(:khis)
    io[:building]     = io.delete(:building)    if io.key?(:building)
    io[:stories]      = io.delete(:stories)     if io.key?(:stories)
    io[:spacetypes]   = io.delete(:spacetypes)  if io.key?(:spacetypes)
    io[:spaces]       = io.delete(:spaces)      if io.key?(:spaces)
    io[:surfaces]     = io.delete(:surfaces)    if io.key?(:surfaces)
    io[:edges]        = io.delete(:edges)       if io.key?(:edges)

    out = JSON.pretty_generate(io)
    outP = File.join(__dir__, "../json/tbd_warehouse9.out.json")
    File.open(outP, "w") { |outP| outP.puts out }
    # ... should contain 'log' entries at the start of the JSON output file.
  end

  it "can process an OSM converted from an IDF (with rotation)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/5Zone_2.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Testing min/max cooling/heating setpoints
    setpoints = heatingTemperatureSetpoints?(os_model)
    setpoints = coolingTemperatureSetpoints?(os_model) || setpoints
    expect(setpoints).to be(true)
    airloops = airLoopsHVAC?(os_model)
    expect(airloops).to be(false)

    os_model.getSpaces.each do |space|
      expect(space.thermalZone.empty?).to be(false)
      zone = space.thermalZone.get
      heating, _ = maxHeatScheduledSetpoint(zone)
      cooling, _ = minCoolScheduledSetpoint(zone)
      if zone.nameString == "PLENUM-1 Thermal Zone"
        expect(plenum?(space, airloops, setpoints)).to be(false)
        expect(heating.nil?).to be(true)
        expect(cooling.nil?).to be(true)
        next
      end
      expect(plenum?(space, airloops, setpoints)).to be(false)
      expect(heating).to be_within(0.1).of(22.2)
      expect(cooling).to be_within(0.1).of(23.9)
    end

    # Tracking insulated ceiling surfaces below PLENUM.
    os_model.getSurfaces.each do |s|
      next unless s.surfaceType == "RoofCeiling"
      next if s.outsideBoundaryCondition == "Outdoors"
      expect(s.isConstructionDefaulted).to be(false)
      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      id = c.nameString
      expect(id).to eq("CLNG-1")
      expect(c.layers.size).to eq(1)
      expect(c.layers[0].nameString).to eq("MAT-CLNG-1") # RSi 0.650
    end

    # Tracking outdoor-facing office walls.
    os_model.getSurfaces.each do |s|
      next unless s.surfaceType == "Wall"
      next unless s.outsideBoundaryCondition == "Outdoors"
      expect(s.isConstructionDefaulted).to be(false)
      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_Construction
      expect(c.empty?).to be(false)
      c = c.get
      id = c.nameString
      expect(id).to eq("WALL-1")
      expect(c.layers.size).to eq(4)
      expect(c.layers[0].nameString).to eq("WD01") # RSi 0.165
      expect(c.layers[1].nameString).to eq("PW03") # RSI 0.110
      expect(c.layers[2].nameString).to eq("IN02") # RSi 2.090
      expect(c.layers[3].nameString).to eq("GP01") # RSi 0.079
    end

    argh[:option] = "poor (BETBG)"
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(io.key?(:edges))
    expect(io[:edges].size).to eq(47)
    expect(surfaces.size).to eq(40)

    surfaces.each do |id, surface|
      expect(surface.key?(:conditioned)).to be(true)
      next unless surface[:conditioned]
      expect(surface.key?(:heating)).to be(true)
      expect(surface.key?(:cooling)).to be(true)

      # Testing glass door detection
      if surface.key?(:doors)
        surface[:doors].each do |i, door|
          expect(door.key?(:glazed)).to be(true)
          expect(door[:glazed]).to be(true)
          expect(door.key?(:u)).to be(true)
          expect(door[:u]).to be_a(Numeric)
          expect(door[:u]).to be_within(0.01).of(6.54)
        end
      end
    end

    ids = { a: "LEFT-1",
            b: "RIGHT-1",
            c: "FRONT-1",
            d: "BACK-1",
            e: "C1-1",
            f: "C2-1",
            g: "C3-1",
            h: "C4-1",
            i: "C5-1"  }.freeze

    surfaces.each do |id, surface|
      next if surface.key?(:edges)
      expect(ids.has_value?(id)).to be(false)
    end

    # Testing plenum/attic.
    surfaces.each do |id, surface|
      expect(surface.key?(:space)).to be(true)
      next unless surface[:space].nameString == "PLENUM-1"

      # Outdoor-facing surfaces are not derated.
      expect(surface.key?(:conditioned)).to be(true)
      expect(surface[:conditioned]).to be(false)
      expect(surface.key?(:heatloss)).to be(false)
      expect(surface.key?(:ratio)).to be(false)

      expect(surface.key?(:boundary)).to be(true)
      b = surface[:boundary]
      next if b == "Outdoors"

      # TBD/Topolys track adjacent CONDITIONED surface.
      expect(surfaces.key?(b)).to be(true)
      expect(surfaces[b].key?(:conditioned)).to be(true)
      expect(surfaces[b][:conditioned]).to be(true)

      next if id == "C5-1P"
      expect id == "C1-1P" || id == "C2-1P" || id == "C3-1P" || id == "C4-1P"
      expect(surfaces[b].key?(:heatloss)).to be(true)
      expect(surfaces[b].key?(:ratio)).to be(true)
      h = surfaces[b][:heatloss]
      expect(h).to be_within(0.01).of(5.79) if id == "C1-1P"
      expect(h).to be_within(0.01).of(2.89) if id == "C2-1P"
      expect(h).to be_within(0.01).of(5.79) if id == "C3-1P"
      expect(h).to be_within(0.01).of(2.89) if id == "C4-1P"
    end

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true) unless id == "C5-1"
      next if id == ids[:i]
      h = surface[:heatloss]

      s = os_model.getSurfaceByName(id)
      expect(s.empty?).to be(false)
      s = s.get
      expect(s.nameString).to eq(id)
      expect(s.isConstructionDefaulted).to be(false)
      expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      expect(h).to be_within(0.01).of(0) if id == "C5-1"
      expect(h).to be_within(0.01).of(64.92) if id == "FRONT-1"
    end
  end

  it "can handle TDDs" do
    types = OpenStudio::Model::SubSurface.validSubSurfaceTypeValues
    expect(types.is_a?(Array)).to be(true)
    expect(types.include?("TubularDaylightDome")).to be(true)
    expect(types.include?("TubularDaylightDiffuser")).to be(true)

    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # As of v3.3.0, OpenStudio SDK (fully) supports Tubular Daylighting Devices:
    #
    #   https://bigladdersoftware.com/epx/docs/9-6/input-output-reference/
    #   group-daylighting.html#daylightingdevicetubular
    #
    #   https://openstudio-sdk-documentation.s3.amazonaws.com/cpp/
    #   OpenStudio-3.3.0-doc/model/html/
    #   classopenstudio_1_1model_1_1_daylighting_device_tubular.html

    methods = OpenStudio::Model::Model.instance_methods.grep(/tubular/i)
    version = os_model.getVersion.versionIdentifier.split('.').map(&:to_i)
    v = version.join.to_i
    expect(v).is_a?(Numeric)

    if v < 330
      expect(methods.empty?).to be(true)
    else
      expect(methods.empty?).to be(false)
    end

    # For SDK versions >= v3.3.0, testing new TDD methods.
    unless v < 330
      # Simple Glazing constructions for both dome & diffuser.
      fenestration = OpenStudio::Model::Construction.new(os_model)
      fenestration.setName("tubular_fenestration")
      expect(fenestration.nameString).to eq("tubular_fenestration")
      expect(fenestration.layers.size).to eq(0)

      glazing = OpenStudio::Model::SimpleGlazing.new(os_model)
      glazing.setName("tubular_glazing")
      expect(glazing.nameString).to eq("tubular_glazing")
      expect(glazing.setUFactor(6.0)).to be(true)
      expect(glazing.setSolarHeatGainCoefficient(0.50)).to be(true)
      expect(glazing.setVisibleTransmittance(0.70)).to be(true)

      layers = OpenStudio::Model::MaterialVector.new
      layers << glazing
      expect(fenestration.setLayers(layers)).to be(true)
      expect(fenestration.layers.size).to eq(1)
      expect(fenestration.layers[0].handle.to_s).to eq(glazing.handle.to_s)
      expect(fenestration.uFactor.empty?).to be(false)
      expect(fenestration.uFactor.get).to be_within(0.1).of(6.0)

      # Tube walls.
      construction = OpenStudio::Model::Construction.new(os_model)
      construction.setName("tube_construction")
      expect(construction.nameString).to eq("tube_construction")
      expect(construction.layers.size).to eq(0)

      interior = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
      interior.setName("tube_wall")
      expect(interior.nameString).to eq("tube_wall")
      expect(interior.setRoughness("MediumRough")).to be(true)
      expect(interior.setThickness(0.0126)).to be(true)
      expect(interior.setConductivity(0.16)).to be(true)
      expect(interior.setDensity(784.9)).to be(true)
      expect(interior.setSpecificHeat(830)).to be(true)
      expect(interior.setThermalAbsorptance(0.9)).to be(true)
      expect(interior.setSolarAbsorptance(0.9)).to be(true)
      expect(interior.setVisibleAbsorptance(0.9)).to be(true)

      layers = OpenStudio::Model::MaterialVector.new
      layers << interior
      expect(construction.setLayers(layers)).to be(true)
      expect(construction.layers.size).to eq(1)
      expect(construction.layers[0].handle.to_s).to eq(interior.handle.to_s)

      # Host spaces & surfaces.
      sp1 = "Zone1 Office"
      sp2 = "Zone2 Fine Storage"

      z = "Zone2 Fine Storage ZN"

      s1 = "Office Roof"              #  Office surface hosting new TDD diffuser
      s2 = "Office Roof Reversed"     #          FineStorage floor, above office
      s3 = "Fine Storage Roof"        # FineStorage surface hosting new TDD dome

      # Fetch host spaces & surfaces.
      office = os_model.getSpaceByName(sp1)
      expect(office.empty?).to be(false)
      office = office.get

      storage = os_model.getSpaceByName(sp2)
      expect(storage.empty?).to be(false)
      storage = storage.get

      zone = storage.thermalZone
      expect(zone.empty?).to be(false)
      zone = zone.get
      expect(zone.nameString).to eq(z)

      ceiling = os_model.getSurfaceByName(s1)
      expect(ceiling.empty?).to be(false)
      ceiling = ceiling.get
      sp = ceiling.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(office)

      floor = os_model.getSurfaceByName(s2)
      expect(floor.empty?).to be(false)
      floor = floor.get
      sp = floor.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(storage)

      adj = ceiling.adjacentSurface
      expect(adj.empty?).to be(false)
      adj = adj.get
      expect(adj).to eq(floor)

      adj = floor.adjacentSurface
      expect(adj.empty?).to be(false)
      adj = adj.get
      expect(adj).to eq(ceiling)

      roof = os_model.getSurfaceByName(s3)
      expect(roof.empty?).to be(false)
      roof = roof.get
      sp = roof.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(storage)

      # Setting heights & Z-axis coordinates.
      ceiling_Z = ceiling.centroid.z
      roof_Z = roof.centroid.z
      length = roof_Z - ceiling_Z
      totalLength = length + 0.7
      dome_Z = ceiling_Z + totalLength

      # A new, 1mx1m diffuser subsurface in Office.
      os_v = OpenStudio::Point3dVector.new
      os_v << OpenStudio::Point3d.new( 11.0, 4.0, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 11.0, 5.0, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 10.0, 5.0, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 10.0, 4.0, ceiling_Z)
      diffuser = OpenStudio::Model::SubSurface.new(os_v, os_model)
      diffuser.setName("diffuser")
      expect(diffuser.setConstruction(fenestration)).to be(true)
      expect(diffuser.setSubSurfaceType("TubularDaylightDiffuser")).to be(true)
      expect(diffuser.setSurface(ceiling)).to be(true)
      expect(diffuser.uFactor.empty?).to be(false)
      expect(diffuser.uFactor.get).to be_within(0.1).of(6.0)

      # A new, 1mx1m dome subsurface above Fine Storage roof.
      os_v = OpenStudio::Point3dVector.new
      os_v << OpenStudio::Point3d.new( 11.0, 4.0, dome_Z)
      os_v << OpenStudio::Point3d.new( 11.0, 5.0, dome_Z)
      os_v << OpenStudio::Point3d.new( 10.0, 5.0, dome_Z)
      os_v << OpenStudio::Point3d.new( 10.0, 4.0, dome_Z)
      dome = OpenStudio::Model::SubSurface.new(os_v, os_model)
      dome.setName("dome")
      expect(dome.setConstruction(fenestration)).to be(true)
      expect(dome.setSubSurfaceType("TubularDaylightDome")).to be(true)
      expect(dome.setSurface(roof)).to be(true)
      expect(dome.uFactor.empty?).to be(false)
      expect(dome.uFactor.get).to be_within(0.1).of(6.0)

      expect(ceiling.tilt).to be_within(0.01).of(diffuser.tilt)
      expect(dome.tilt).to be_within(0.01).of(roof.tilt)

      rsi = 0.28   # default effective TDD thermal resistance (dome to diffuser)
      diameter = Math.sqrt(dome.grossArea/Math::PI) * 2

      tdd = OpenStudio::Model::DaylightingDeviceTubular.new(
              dome, diffuser, construction)

      expect(tdd.setDiameter(diameter)).to be(true)
      expect(tdd.setTotalLength(totalLength)).to be(true)
      expect(tdd.addTransitionZone(zone, length)).to be(true)
      cl = OpenStudio::Model::TransitionZoneVector
      expect(tdd.transitionZones.class).to eq(cl)
      expect(tdd.numberofTransitionZones).to be(1)
      expect(tdd.totalLength).to be_within(0.001).of(totalLength)

      expect(tdd.subSurfaceDome).to eq(dome)
      expect(tdd.subSurfaceDiffuser).to eq(diffuser)
      c = tdd.construction
      expect(c.to_Construction.empty?).to be(false)
      c = c.to_Construction.get
      expect(c.nameString).to eq(construction.nameString)
      expect(tdd.diameter).to be_within(0.001).of(diameter)
      expect(tdd.effectiveThermalResistance).to be_within(0.01).of(rsi)

      pth = File.join(__dir__, "files/osms/out/tdd_warehouse.osm")
      os_model.save(pth, true)

      # Testing if TBD recognizes the TDD as a "skylight" (for derating & UA').
      argh[:option] = "poor (BETBG)"
      io, surfaces = processTBD(os_model, argh)
      expect(TBD.status).to eq(0)
      expect(TBD.logs.empty?).to be(true)
      expect(io.nil?).to be(false)
      expect(io.is_a?(Hash)).to be(true)
      expect(io.empty?).to be(false)
      expect(surfaces.nil?).to be(false)
      expect(surfaces.is_a?(Hash)).to be(true)
      expect(surfaces.size).to eq(23)
      expect(io.key?(:edges))

      # Both diffuser and parent (office) ceiling are stored as TBD 'surfaces'.
      expect(surfaces.key?(s1)).to be(true)
      surface = surfaces[s1]
      expect(surface.key?(:skylights)).to be(true)
      expect(surface[:skylights].size).to be(1)
      expect(surface[:skylights].key?("diffuser")).to be(true)
      skylight = surface[:skylights]["diffuser"]
      expect(skylight.is_a?(Hash)).to be(true)
      expect(skylight.key?(:u)).to be(true)
      expect(skylight[:u]).to be_a(Numeric)
      expect(skylight[:u]).to be_within(0.01).of(1/rsi)
      # ... yet TBD only derates constructions of opaque surfaces in CONDITIONED
      # spaces if:
      #
      #   (i) facing outdoors or
      #   (ii) facing UNCONDITIONED spaces like attics (see psi.rb).
      #
      # Here, the ceiling is not tagged by TBD as a deratable surface - diffuser
      # edges are therefore not logged in TBD's 'edges'.
      expect(surface.key?(:heatloss)).to be(false)
      expect(surface.key?(:ratio)).to be(false)

      # Only edges of the dome (linked to the Fine Storage roof) are stored.
      io[:edges].each do |edge|
        expect(edge.is_a?(Hash)).to be(true)
        expect(edge.key?(:surfaces)).to be(true)
        expect(edge[:surfaces].is_a?(Array)).to be(true)
        edge[:surfaces].each do |id|
          next unless id == "dome" || id == "diffuser"
          expect(id).to eq("dome")
        end
      end

      expect(surfaces.key?(s3)).to be(true)
      surface = surfaces[s3]
      expect(surface.key?(:skylights)).to be(true)
      expect(surface[:skylights].size).to be(15)               # original 14x +1
      expect(surface[:skylights].key?("dome")).to be(true)
      surface[:skylights].each do |i, skylight|
        expect(skylight.key?(:u)).to be(true)
        expect(skylight[:u]).to be_a(Numeric)
        expect(skylight[:u]).to be_within(0.01).of(6.64) unless i == "dome"
        expect(skylight[:u]).to be_within(0.01).of(1/rsi) if i == "dome"
      end
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface[:heatloss]).to be_within(0.01).of(89.16)         # +2.0 W/K

      expect(io[:edges].size).to eq(304)          # 4x extra edges for dome only

      out = JSON.pretty_generate(io)
      outP = File.join(__dir__, "../json/tbd_warehouse15.out.json")
      File.open(outP, "w") { |outP| outP.puts out }

      # Re-use the exported file as input for another warehouse.
      os_model2 = translator.loadModel(pth)
      expect(os_model2.empty?).to be(false)
      os_model2 = os_model2.get

      argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
      argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse15.out.json")
      io2, surfaces = processTBD(os_model2, argh)
      expect(TBD.status).to eq(0)
      expect(TBD.logs.empty?).to be(true)
      expect(io.nil?).to be(false)
      expect(io.is_a?(Hash)).to be(true)
      expect(io.empty?).to be(false)
      expect(surfaces.nil?).to be(false)
      expect(surfaces.is_a?(Hash)).to be(true)
      expect(surfaces.size).to eq(23)

      # Now mimic (again) the export functionality of the measure.
      out2 = JSON.pretty_generate(io2)
      outP2 = File.join(__dir__, "../json/tbd_warehouse16.out.json")
      File.open(outP2, "w") { |outP2| outP2.puts out2 }

      # Both output files should be the same ...
      expect(FileUtils.identical?(outP, outP2)).to be(true)
    else
      # SDK pre-v3.3.0 testing on one of the existing skylights, as a tubular
      # TDD dome (without a complete TDD object).
      nom = "FineStorage_skylight_5"
      sky5 = os_model.getSubSurfaceByName(nom)
      expect(sky5.empty?).to be(false)
      sky5 = sky5.get
      expect(sky5.subSurfaceType.downcase).to eq("skylight")
      name = "U 1.17 SHGC 0.39 Simple Glazing Skylight U-1.17 SHGC 0.39 2"
      skylight = sky5.construction
      expect(skylight.empty?).to be(false)
      expect(skylight.get.nameString).to eq(name)

      expect(sky5.setSubSurfaceType("TubularDaylightDome")).to be(true)
      skylight = sky5.construction
      expect(skylight.empty?).to be(false)
      expect(skylight.get.nameString).to eq("Typical Interior Window")
      # Weird to see "Typical Interior Window" as a suitable construction for a
      # tubular skylight dome, but that's the assigned default construction in
      # the DOE prototype warehouse model.

      roof = os_model.getSurfaceByName("Fine Storage Roof")
      expect(roof.empty?).to be(false)
      roof = roof.get

      # Testing if TBD recognizes it as a "skylight" (for derating & UA').
      argh[:option] = "poor (BETBG)"
      io, surfaces = processTBD(os_model, argh)
      expect(TBD.status).to eq(0)
      expect(TBD.logs.empty?).to be(true)
      expect(io.nil?).to be(false)
      expect(io.is_a?(Hash)).to be(true)
      expect(io.empty?).to be(false)
      expect(surfaces.nil?).to be(false)
      expect(surfaces.is_a?(Hash)).to be(true)
      expect(io.key?(:edges))
      expect(io[:edges].size).to eq(300)
      expect(surfaces.size).to eq(23)
      expect(TBD.status).to eq(0)
      expect(TBD.logs.size).to eq(0)

      expect(surfaces.key?("Fine Storage Roof")).to be(true)
      surface = surfaces["Fine Storage Roof"]
      if surface.key?(:skylights)
        expect(surface[:skylights].key?(nom)).to be(true)
        surface[:skylights].each do |i, skylight|
          expect(skylight.key?(:u)).to be(true)
          expect(skylight[:u]).to be_a(Numeric)
          expect(skylight[:u]).to be_within(0.01).of(6.64) unless i == nom
          expect(skylight[:u]).to be_within(0.01).of(7.18) if i == nom
          # So TBD processes any subsurface perimeter, whether skylight, TDD,
          # etc. And it retrieves a calculated U-factor for TBD's UA' trade-off
          # calculations. A follow-up OpenStudio-launched EnergyPlus simulation
          # reveals that, despite having an incomplete TDD setup:
          #
          #   dome > tube > diffuser
          #
          # ... EnergyPlus will proceed without warning(s) for OpenStudio
          # < v3.3.0. Results reflect an expected increase in heating energy
          # (Climate Zone 7), due to the poor(er) performance of the dome.
        end
      end
    end
  end

  it "can handle TDDs in attics (false plenums)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/5Zone_2.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    version = os_model.getVersion.versionIdentifier.split('.').map(&:to_i)
    v = version.join.to_i
    expect(v).is_a?(Numeric)

    # For SDK versions >= v3.3.0, testing new DaylightingTubularDevice methods.
    unless v < 330
      # Both dome & diffuser: Simple Glazing constructions.
      fenestration = OpenStudio::Model::Construction.new(os_model)
      fenestration.setName("tubular_fenestration")
      expect(fenestration.nameString).to eq("tubular_fenestration")
      expect(fenestration.layers.size).to eq(0)

      glazing = OpenStudio::Model::SimpleGlazing.new(os_model)
      glazing.setName("tubular_glazing")
      expect(glazing.nameString).to eq("tubular_glazing")
      expect(glazing.setUFactor(6.0)).to be(true)
      expect(glazing.setSolarHeatGainCoefficient(0.50)).to be(true)
      expect(glazing.setVisibleTransmittance(0.70)).to be(true)

      layers = OpenStudio::Model::MaterialVector.new
      layers << glazing
      expect(fenestration.setLayers(layers)).to be(true)
      expect(fenestration.layers.size).to eq(1)
      expect(fenestration.layers[0].handle.to_s).to eq(glazing.handle.to_s)
      expect(fenestration.uFactor.empty?).to be(false)
      expect(fenestration.uFactor.get).to be_within(0.1).of(6.0)

      # Tube walls.
      construction = OpenStudio::Model::Construction.new(os_model)
      construction.setName("tube_construction")
      expect(construction.nameString).to eq("tube_construction")
      expect(construction.layers.size).to eq(0)

      interior = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
      interior.setName("tube_wall")
      expect(interior.nameString).to eq("tube_wall")
      expect(interior.setRoughness("MediumRough")).to be(true)
      expect(interior.setThickness(0.0126)).to be(true)
      expect(interior.setConductivity(0.16)).to be(true)
      expect(interior.setDensity(784.9)).to be(true)
      expect(interior.setSpecificHeat(830)).to be(true)
      expect(interior.setThermalAbsorptance(0.9)).to be(true)
      expect(interior.setSolarAbsorptance(0.9)).to be(true)
      expect(interior.setVisibleAbsorptance(0.9)).to be(true)

      layers = OpenStudio::Model::MaterialVector.new
      layers << interior
      expect(construction.setLayers(layers)).to be(true)
      expect(construction.layers.size).to eq(1)
      expect(construction.layers[0].handle.to_s).to eq(interior.handle.to_s)

      # Host spaces & surfaces.
      sp1 = "SPACE5-1"
      sp2 = "PLENUM-1"

      z = "PLENUM-1 Thermal Zone"

      s1 = "C5-1"  # sp1 surface hosting new TDD diffuser
      s2 = "C5-1P" # plenum surface, above sp1
      s3 = "TOP-1" # plenum surface hosting new TDD dome

      # Fetch host spaces & surfaces.
      space = os_model.getSpaceByName(sp1)
      expect(space.empty?).to be(false)
      space = space.get

      plenum = os_model.getSpaceByName(sp2)
      expect(plenum.empty?).to be(false)
      plenum = plenum.get

      zone = plenum.thermalZone
      expect(zone.empty?).to be(false)
      zone = zone.get
      expect(zone.nameString).to eq(z)

      ceiling = os_model.getSurfaceByName(s1)
      expect(ceiling.empty?).to be(false)
      ceiling = ceiling.get
      sp = ceiling.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(space)

      floor = os_model.getSurfaceByName(s2)
      expect(floor.empty?).to be(false)
      floor = floor.get
      sp = floor.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(plenum)

      adj = ceiling.adjacentSurface
      expect(adj.empty?).to be(false)
      adj = adj.get
      expect(adj).to eq(floor)

      adj = floor.adjacentSurface
      expect(adj.empty?).to be(false)
      adj = adj.get
      expect(adj).to eq(ceiling)

      roof = os_model.getSurfaceByName(s3)
      expect(roof.empty?).to be(false)
      roof = roof.get
      sp = roof.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(plenum)

      # Setting heights & Z-axis coordinates.
      ceiling_Z = ceiling.centroid.z
      roof_Z = roof.centroid.z
      length = roof_Z - ceiling_Z
      totalLength = length + 0.5
      dome_Z = ceiling_Z + totalLength

      # A new, 1mx1m diffuser subsurface in space ceiling.
      os_v = OpenStudio::Point3dVector.new
      os_v << OpenStudio::Point3d.new( 15.75,  7.15, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 15.75,  8.15, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 14.75,  8.15, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 14.75,  7.15, ceiling_Z)
      diffuser = OpenStudio::Model::SubSurface.new(os_v, os_model)
      diffuser.setName("diffuser")
      expect(diffuser.setConstruction(fenestration)).to be(true)
      expect(diffuser.setSubSurfaceType("TubularDaylightDiffuser")).to be(true)
      expect(diffuser.setSurface(ceiling)).to be(true)
      expect(diffuser.uFactor.empty?).to be(false)
      expect(diffuser.uFactor.get).to be_within(0.1).of(6.0)

      # A new, 1mx1m dome subsurface above Plenum roof.
      os_v = OpenStudio::Point3dVector.new
      os_v << OpenStudio::Point3d.new( 15.75,  7.15, dome_Z)
      os_v << OpenStudio::Point3d.new( 15.75,  8.15, dome_Z)
      os_v << OpenStudio::Point3d.new( 14.75,  8.15, dome_Z)
      os_v << OpenStudio::Point3d.new( 14.75,  7.15, dome_Z)
      dome = OpenStudio::Model::SubSurface.new(os_v, os_model)
      dome.setName("dome")
      expect(dome.setConstruction(fenestration)).to be(true)
      expect(dome.setSubSurfaceType("TubularDaylightDome")).to be(true)
      expect(dome.setSurface(roof)).to be(true)
      expect(dome.uFactor.empty?).to be(false)
      expect(dome.uFactor.get).to be_within(0.1).of(6.0)

      expect(ceiling.tilt).to be_within(0.01).of(diffuser.tilt)
      expect(dome.tilt).to be_within(0.01).of(roof.tilt)

      rsi = 0.28
      diameter = Math.sqrt(dome.grossArea/Math::PI) * 2

      tdd = OpenStudio::Model::DaylightingDeviceTubular.new(
              dome, diffuser, construction, diameter, totalLength, rsi)

      expect(tdd.addTransitionZone(zone, length)).to be(true)
      cl = OpenStudio::Model::TransitionZoneVector
      expect(tdd.transitionZones.class).to eq(cl)
      expect(tdd.numberofTransitionZones).to be(1)
      expect(tdd.totalLength).to be_within(0.001).of(totalLength)

      expect(tdd.subSurfaceDome).to eq(dome)
      expect(tdd.subSurfaceDiffuser).to eq(diffuser)
      c = tdd.construction
      expect(c.to_Construction.empty?).to be(false)
      c = c.to_Construction.get
      expect(c.nameString).to eq(construction.nameString)
      expect(tdd.diameter).to be_within(0.001).of(diameter)
      expect(tdd.effectiveThermalResistance).to be_within(0.01).of(rsi)

      pth = File.join(__dir__, "files/osms/out/tdd_5Z_test.osm")
      os_model.save(pth, true)

      # Testing if TBD recognizes the TDD as a "skylight" (for derating & UA').
      argh[:option] = "poor (BETBG)"
      io, surfaces = processTBD(os_model, argh)
      expect(TBD.status).to eq(0)
      expect(TBD.logs.empty?).to be(true)
      expect(io.nil?).to be(false)
      expect(io.is_a?(Hash)).to be(true)
      expect(io.empty?).to be(false)
      expect(surfaces.nil?).to be(false)
      expect(surfaces.is_a?(Hash)).to be(true)
      expect(surfaces.size).to eq(40)
      expect(io.key?(:edges))

      # Both diffuser and parent ceiling are stored as TBD 'surfaces'.
      expect(surfaces.key?(s1)).to be(true)
      surface = surfaces[s1]
      expect(surface.key?(:skylights)).to be(true)
      expect(surface[:skylights].size).to be(1)
      expect(surface[:skylights].key?("diffuser")).to be(true)
      skylight = surface[:skylights]["diffuser"]
      expect(skylight.key?(:u)).to be(true)
      expect(skylight[:u]).to be_a(Numeric)
      expect(skylight[:u]).to be_within(0.01).of(1/rsi)

      # ... yet TBD only derates constructions of opaque surfaces in CONDITIONED
      # spaces IF (i) facing outdoors or (ii) facing UNCONDITIONED spaces like
      # attics (see psi.rb). Here, the ceiling is tagged by TBD as a deratable
      # surface, and hence the diffuser edges are logged in TBD's 'edges'.
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      expect(surface[:heatloss]).to be_within(0.01).of(2.00)      # 4x 0.500 W/K

      # Only edges of the diffuser (linked to the ceiling) are stored.
      io[:edges].each do |edge|
        expect(edge.is_a?(Hash)).to be(true)
        expect(edge.key?(:surfaces)).to be(true)
        expect(edge[:surfaces].is_a?(Array)).to be(true)
        edge[:surfaces].each do |id|
          next unless id == "dome" || id == "diffuser"
          expect(id).to eq("diffuser")
        end
      end

      expect(surfaces.key?(s3)).to be(true)
      surface = surfaces[s3]
      expect(surface.key?(:skylights)).to be(true)
      expect(surface[:skylights].size).to be(1)
      expect(surface[:skylights].key?("dome")).to be(true)
      skylight = surface[:skylights]["dome"]
      expect(skylight.key?(:u)).to be(true)
      expect(skylight[:u]).to be_a(Numeric)
      expect(skylight[:u]).to be_within(0.01).of(1/rsi)
      expect(surface.key?(:heatloss)).to be(false)
      expect(surface.key?(:ratio)).to be(false)

      expect(io[:edges].size).to eq(51) # 4x extra edges for diffuser - not dome

      out = JSON.pretty_generate(io)
      outP = File.join(__dir__, "../json/tbd_5Z.out.json")
      File.open(outP, "w") { |outP| outP.puts out }

      # Re-use the exported file as input for another 5Z test.
      os_model2 = translator.loadModel(pth)
      expect(os_model2.empty?).to be(false)
      os_model2 = os_model2.get

      argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
      argh[:io_path] = File.join(__dir__, "../json/tbd_5Z.out.json")
      io2, surfaces = processTBD(os_model2, argh)
      expect(TBD.status).to eq(0)
      expect(TBD.logs.empty?).to be(true)
      expect(io.nil?).to be(false)
      expect(io.is_a?(Hash)).to be(true)
      expect(io.empty?).to be(false)
      expect(surfaces.nil?).to be(false)
      expect(surfaces.is_a?(Hash)).to be(true)
      expect(surfaces.size).to eq(40)

      # Now mimic (again) the export functionality of the measure.
      out2 = JSON.pretty_generate(io2)
      outP2 = File.join(__dir__, "../json/tbd_5Z_2.out.json")
      File.open(outP2, "w") { |outP2| outP2.puts out2 }

      # Both output files should be the same ...
      expect(FileUtils.identical?(outP, outP2)).to be(true)
    end
  end

  it "can handle TDDs in attics" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_smalloffice.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    version = os_model.getVersion.versionIdentifier.split('.').map(&:to_i)
    v = version.join.to_i
    expect(v).is_a?(Numeric)

    # For SDK versions >= v3.3.0, testing new DaylightingTubularDevice methods.
    unless v < 330
      # Both dome & diffuser: Simple Glazing constructions.
      fenestration = OpenStudio::Model::Construction.new(os_model)
      fenestration.setName("tubular_fenestration")
      expect(fenestration.nameString).to eq("tubular_fenestration")
      expect(fenestration.layers.size).to eq(0)

      glazing = OpenStudio::Model::SimpleGlazing.new(os_model)
      glazing.setName("tubular_glazing")
      expect(glazing.nameString).to eq("tubular_glazing")
      expect(glazing.setUFactor(6.0)).to be(true)
      expect(glazing.setSolarHeatGainCoefficient(0.50)).to be(true)
      expect(glazing.setVisibleTransmittance(0.70)).to be(true)

      layers = OpenStudio::Model::MaterialVector.new
      layers << glazing
      expect(fenestration.setLayers(layers)).to be(true)
      expect(fenestration.layers.size).to eq(1)
      expect(fenestration.layers[0].handle.to_s).to eq(glazing.handle.to_s)
      expect(fenestration.uFactor.empty?).to be(false)
      expect(fenestration.uFactor.get).to be_within(0.1).of(6.0)

      # Tube walls.
      construction = OpenStudio::Model::Construction.new(os_model)
      construction.setName("tube_construction")
      expect(construction.nameString).to eq("tube_construction")
      expect(construction.layers.size).to eq(0)

      interior = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
      interior.setName("tube_wall")
      expect(interior.nameString).to eq("tube_wall")
      expect(interior.setRoughness("MediumRough")).to be(true)
      expect(interior.setThickness(0.0126)).to be(true)
      expect(interior.setConductivity(0.16)).to be(true)
      expect(interior.setDensity(784.9)).to be(true)
      expect(interior.setSpecificHeat(830)).to be(true)
      expect(interior.setThermalAbsorptance(0.9)).to be(true)
      expect(interior.setSolarAbsorptance(0.9)).to be(true)
      expect(interior.setVisibleAbsorptance(0.9)).to be(true)

      layers = OpenStudio::Model::MaterialVector.new
      layers << interior
      expect(construction.setLayers(layers)).to be(true)
      expect(construction.layers.size).to eq(1)
      expect(construction.layers[0].handle.to_s).to eq(interior.handle.to_s)

      # Host spaces & surfaces.
      sp1 = "Core_ZN"
      sp2 = "Attic"

      z = "Attic ZN"

      s1 = "Core_ZN_ceiling"  # sp1 surface hosting new TDD diffuser
      s2 = "Attic_floor_core" # attic surface, above sp1
      s3 = "Attic_roof_north" # attic surface hosting new TDD dome

      # Fetch host spaces & surfaces.
      core = os_model.getSpaceByName(sp1)
      expect(core.empty?).to be(false)
      core = core.get

      attic = os_model.getSpaceByName(sp2)
      expect(attic.empty?).to be(false)
      attic = attic.get

      zone = attic.thermalZone
      expect(zone.empty?).to be(false)
      zone = zone.get
      expect(zone.nameString).to eq(z)

      ceiling = os_model.getSurfaceByName(s1)
      expect(ceiling.empty?).to be(false)
      ceiling = ceiling.get
      sp = ceiling.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(core)

      floor = os_model.getSurfaceByName(s2)
      expect(floor.empty?).to be(false)
      floor = floor.get
      sp = floor.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(attic)

      adj = ceiling.adjacentSurface
      expect(adj.empty?).to be(false)
      adj = adj.get
      expect(adj).to eq(floor)

      adj = floor.adjacentSurface
      expect(adj.empty?).to be(false)
      adj = adj.get
      expect(adj).to eq(ceiling)

      roof = os_model.getSurfaceByName(s3)
      expect(roof.empty?).to be(false)
      roof = roof.get
      sp = roof.space
      expect(sp.empty?).to be(false)
      sp = sp.get
      expect(sp).to eq(attic)

      # Setting heights & Z-axis coordinates.
      ceiling_Z = 3.05
      roof_Z = 5.51
      length = roof_Z - ceiling_Z
      totalLength = length + 1.0
      dome_Z = ceiling_Z + totalLength

      # A new, 1mx1m diffuser subsurface in Core ceiling.
      os_v = OpenStudio::Point3dVector.new
      os_v << OpenStudio::Point3d.new( 14.345, 10.845, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 14.345, 11.845, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 13.345, 11.845, ceiling_Z)
      os_v << OpenStudio::Point3d.new( 13.345, 10.845, ceiling_Z)
      diffuser = OpenStudio::Model::SubSurface.new(os_v, os_model)
      diffuser.setName("diffuser")
      expect(diffuser.setConstruction(fenestration)).to be(true)
      expect(diffuser.setSubSurfaceType("TubularDaylightDiffuser")).to be(true)
      expect(diffuser.setSurface(ceiling)).to be(true)
      expect(diffuser.uFactor.empty?).to be(false)
      expect(diffuser.uFactor.get).to be_within(0.1).of(6.0)

      # A new, 1mx1m dome subsurface above Attic roof.
      os_v = OpenStudio::Point3dVector.new
      os_v << OpenStudio::Point3d.new( 14.345, 10.845, dome_Z)
      os_v << OpenStudio::Point3d.new( 14.345, 11.845, dome_Z)
      os_v << OpenStudio::Point3d.new( 13.345, 11.845, dome_Z)
      os_v << OpenStudio::Point3d.new( 13.345, 10.845, dome_Z)
      dome = OpenStudio::Model::SubSurface.new(os_v, os_model)
      dome.setName("dome")
      expect(dome.setConstruction(fenestration)).to be(true)
      expect(dome.setSubSurfaceType("TubularDaylightDome")).to be(true)
      expect(dome.setSurface(roof)).to be(true)
      expect(dome.uFactor.empty?).to be(false)
      expect(dome.uFactor.get).to be_within(0.1).of(6.0)

      expect(ceiling.tilt).to be_within(0.01).of(diffuser.tilt)
      expect(dome.tilt).to be_within(0.01).of(0.0)
      expect(roof.tilt).to be_within(0.01).of(0.32)

      rsi = 0.28
      diameter = Math.sqrt(dome.grossArea/Math::PI) * 2

      tdd = OpenStudio::Model::DaylightingDeviceTubular.new(
              dome, diffuser, construction, diameter, totalLength, rsi)

      expect(tdd.addTransitionZone(zone, length)).to be(true)
      cl = OpenStudio::Model::TransitionZoneVector
      expect(tdd.transitionZones.class).to eq(cl)
      expect(tdd.numberofTransitionZones).to be(1)
      expect(tdd.totalLength).to be_within(0.001).of(totalLength)

      expect(tdd.subSurfaceDome).to eq(dome)
      expect(tdd.subSurfaceDiffuser).to eq(diffuser)
      c = tdd.construction
      expect(c.to_Construction.empty?).to be(false)
      c = c.to_Construction.get
      expect(c.nameString).to eq(construction.nameString)
      expect(tdd.diameter).to be_within(0.001).of(diameter)
      expect(tdd.effectiveThermalResistance).to be_within(0.01).of(rsi)

      pth = File.join(__dir__, "files/osms/out/tdd_smalloffice_test.osm")
      os_model.save(pth, true)

      # Testing if TBD recognizes the TDD as a "skylight" (for derating & UA').
      argh[:option] = "poor (BETBG)"
      io, surfaces = processTBD(os_model, argh)
      expect(TBD.status).to eq(0)
      expect(TBD.logs.empty?).to be(true)
      expect(io.nil?).to be(false)
      expect(io.is_a?(Hash)).to be(true)
      expect(io.empty?).to be(false)
      expect(surfaces.nil?).to be(false)
      expect(surfaces.is_a?(Hash)).to be(true)
      expect(surfaces.size).to eq(43)
      expect(io.key?(:edges))

      # Both diffuser and parent ceiling are stored as TBD 'surfaces'.
      expect(surfaces.key?(s1)).to be(true)
      surface = surfaces[s1]
      expect(surface.key?(:skylights)).to be(true)
      expect(surface[:skylights].key?("diffuser")).to be(true)
      skylight = surface[:skylights]["diffuser"]
      expect(skylight.key?(:u)).to be(true)
      expect(skylight[:u]).to be_a(Numeric)
      expect(skylight[:u]).to be_within(0.01).of(1/rsi)

      # ... yet TBD only derates constructions of opaque surfaces in CONDITIONED
      # spaces IF (i) facing outdoors or (ii) facing UNCONDITIONED spaces like
      # attics (see psi.rb). Here, the ceiling is tagged by TBD as a deratable
      # surface, and hence the diffuser edges are logged in TBD's 'edges'.
      expect(surface.key?(:heatloss)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      expect(surface[:heatloss]).to be_within(0.01).of(2.00)      # 4x 0.500 W/K

      # Only edges of the diffuser (linked to the ceiling) are stored.
      io[:edges].each do |edge|
        expect(edge.is_a?(Hash)).to be(true)
        expect(edge.key?(:surfaces)).to be(true)
        expect(edge[:surfaces].is_a?(Array)).to be(true)
        edge[:surfaces].each do |id|
          next unless id == "dome" || id == "diffuser"
          expect(id).to eq("diffuser")
        end
      end

      expect(surfaces.key?(s3)).to be(true)
      surface = surfaces[s3]
      expect(surface.key?(:skylights)).to be(true)
      expect(surface[:skylights].key?("dome")).to be(true)
      skylight = surface[:skylights]["dome"]
      expect(skylight.key?(:u)).to be(true)
      expect(skylight[:u]).to be_a(Numeric)
      expect(skylight[:u]).to be_within(0.01).of(1/rsi)
      expect(surface.key?(:heatloss)).to be(false)
      expect(surface.key?(:ratio)).to be(false)

      expect(io[:edges].size).to eq(109)      # 4x extra edges for diffuser only

      out = JSON.pretty_generate(io)
      outP = File.join(__dir__, "../json/tbd_smalloffice1.out.json")
      File.open(outP, "w") { |outP| outP.puts out }

      # Re-use the exported file as input for another test.
      os_model2 = translator.loadModel(pth)
      expect(os_model2.empty?).to be(false)
      os_model2 = os_model2.get

      argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
      argh[:io_path] = File.join(__dir__, "../json/tbd_smalloffice1.out.json")
      io2, surfaces = processTBD(os_model2, argh)
      expect(TBD.status).to eq(0)
      expect(TBD.logs.empty?).to be(true)
      expect(io.nil?).to be(false)
      expect(io.is_a?(Hash)).to be(true)
      expect(io.empty?).to be(false)
      expect(surfaces.nil?).to be(false)
      expect(surfaces.is_a?(Hash)).to be(true)
      expect(surfaces.size).to eq(43)

      # Now mimic (again) the export functionality of the measure.
      out2 = JSON.pretty_generate(io2)
      outP2 = File.join(__dir__, "../json/tbd_smalloffice2.out.json")
      File.open(outP2, "w") { |outP2| outP2.puts out2 }

      # Both output files should be the same ...
      expect(FileUtils.identical?(outP, outP2)).to be(true)
    end
  end

  it "can handle air gaps as materials" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    id = "Bulk Storage Rear Wall"
    s = os_model.getSurfaceByName(id)
    expect(s.empty?).to be(false)
    s = s.get
    expect(s.nameString).to eq(id)
    expect(s.surfaceType).to eq("Wall")
    expect(s.isConstructionDefaulted).to be(true)
    c = s.construction.get.to_Construction
    expect(c.empty?).to be(false)
    c = c.get
    expect(c.numLayers).to eq(3)

    gap = OpenStudio::Model::AirGap.new(os_model)
    expect(gap.handle.to_s.empty?).to be(false)
    expect(gap.nameString.empty?).to be(false)
    expect(gap.nameString).to eq("Material Air Gap 1")
    gap.setName("#{id} air gap")
    expect(gap.nameString).to eq("#{id} air gap")
    expect(gap.setThermalResistance(0.180)).to be(true)
    expect(gap.thermalResistance).to be_within(0.01).of(0.180)
    expect(c.insertLayer(1, gap)).to be(true)
    expect(c.numLayers).to eq(4)

    pth = File.join(__dir__, "files/osms/out/warehouse_airgap.osm")
    os_model.save(pth, true)

    argh[:option] = "poor (BETBG)"
    io, surfaces = processTBD(os_model, argh)
    # puts TBD.logs
    expect(TBD.status).to eq(0)
  end

  it "can uprate (ALL roof) constructions" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Mimics measure.
    walls = {c: {}, dft: "ALL wall constructions"}
    roofs = {c: {}, dft: "ALL roof constructions"}
    flors = {c: {}, dft: "ALL floor constructions"}
    walls[:c][walls[:dft]] = {a: 100000000000000}
    roofs[:c][roofs[:dft]] = {a: 100000000000000}
    flors[:c][flors[:dft]] = {a: 100000000000000}
    walls[:chx] = OpenStudio::StringVector.new
    roofs[:chx] = OpenStudio::StringVector.new
    flors[:chx] = OpenStudio::StringVector.new

    os_model.getSurfaces.each do |s|
      type = s.surfaceType.downcase
      next unless type == "wall" || type == "roofceiling" || type == "floor"
      next unless s.outsideBoundaryCondition.downcase == "outdoors"
      next if s.construction.empty?
      next if s.construction.get.to_LayeredConstruction.empty?
      lc = s.construction.get.to_LayeredConstruction.get
      id = lc.nameString
      next if walls[:c].key?(id)
      next if roofs[:c].key?(id)
      next if flors[:c].key?(id)
      a = lc.getNetArea

      # One challenge of the uprate approach concerns OpenStudio-reported
      # surface film resistances, which factor-in the slope of the surface and
      # surface emittances. As the uprate approach relies on user-defined Ut
      # factors (inputs, as targets to meet), it also considers surface film
      # resistances. In the schematic cross-section below, let's postulate that
      # each slope has a unique pitch: 50° (s1), 0° (s2), & 60° (s3). All three
      # surfaces reference the same construction.
      #
      #         s2
      #        _____
      #       /     \
      #   s1 /       \ s3
      #     /         \
      #
      # For highly-reflective interior finishes (think of Bruce Lee in Enter
      # the Dragon), the difference here in reported RSi could reach 0.1 m2.K/W
      # or R0.6. That's a 1% to 3% difference for a well-insulated construction.
      # This may seem significant, but the impact on energy simulation results
      # should be barely noticeable. However, these discrepancies could become
      # an irritant when processing an OpenStudio model for code compliance
      # purposes. For clear-field (Uo) calculations, a simple solution is ensure
      # that the (common) layered construction meets minimal code requirements
      # for the surface with the lowest film resistance, here s2. Thus surfaces
      # s1 & s3 will slightly overshoot the Uo target.
      #
      # For Ut calculations (which factor-in major thermal bridging), this is
      # not as straightforward as adjusting the construction layers by hand. Yet
      # conceptually, the approach here remains similar: for a selected
      # construction shared by more than one surface, the considered film
      # resistance will be that of the worst case encountered. The resulting Uo
      # for that uprated construction might be slightly lower (i.e., better
      # performing) than expected in some circumstances.
      f = s.filmResistance

      case type
      when "wall"
        walls[:c][id] = {a: a, lc: lc}
        walls[:c][id][:f] = f unless walls[:c][id].key?(:f)
        walls[:c][id][:f] = f if f < walls[:c][id][:f]
      when "roofceiling"
        roofs[:c][id] = {a: a, lc: lc}
        roofs[:c][id][:f] = f unless roofs[:c][id].key?(:f)
        roofs[:c][id][:f] = f if f < roofs[:c][id][:f]
      else
        flors[:c][id] = {a: a, lc: lc}
        flors[:c][id][:f] = f unless flors[:c][id].key?(:f)
        flors[:c][id][:f] = f if f < flors[:c][id][:f]
      end
    end

    walls[:c] = walls[:c].sort_by{ |k,v| v[:a] }.reverse!.to_h
    walls[:c][walls[:dft]][:a] = 0
    walls[:c].keys.each { |id| walls[:chx] << id }

    roofs[:c] = roofs[:c].sort_by{ |k,v| v[:a] }.reverse!.to_h
    roofs[:c][roofs[:dft]][:a] = 0
    roofs[:c].keys.each { |id| roofs[:chx] << id }

    flors[:c] = flors[:c].sort_by{ |k,v| v[:a] }.reverse!.to_h
    flors[:c][flors[:dft]][:a] = 0
    flors[:c].keys.each { |id| flors[:chx] << id }

    expect(roofs[:c].size).to eq(3)
    # puts roofs[:c].keys
    # Typical Insulated Metal Building Roof R-10.31 1
    # Typical Insulated Metal Building Roof R-18.18
    expect(roofs[:c].keys[0]).to eq("ALL roof constructions")
    expect(roofs[:c]["ALL roof constructions"][:a]).to be_within(TOL).of(0)
    roof1 = roofs[:c].values[1]
    roof2 = roofs[:c].values[2]
    expect(roof1[:a] > roof2[:a]).to be(true)
    expect(roof1[:f]).to be_within(TOL).of(roof2[:f])
    expect(roof1[:f]).to be_within(TOL).of(0.1360)
    expect(1/rsi(roof1[:lc], roof1[:f])).to be_within(TOL).of(0.5512)  # R ~10.3
    expect(1/rsi(roof2[:lc], roof2[:f])).to be_within(TOL).of(0.3124)  # R ~18.2

    argh[:option]       = "poor (BETBG)"
    argh[:uprate_roofs] = true
    argh[:roof_ut]      = 0.138                                      # NECB 2017
    argh[:roof_option]  = "Typical Insulated Metal Building Roof R-10.31 1"
    io, surfaces = processTBD(os_model, argh)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)
    expect(io.key?(:edges))
    expect(io[:edges].size).to eq(300)
  end

  it "can pre-process UA parameters" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    setpoints = heatingTemperatureSetpoints?(os_model)
    setpoints = coolingTemperatureSetpoints?(os_model) || setpoints
    expect(setpoints).to be(true)
    airloops = airLoopsHVAC?(os_model)
    expect(airloops).to be(true)

    os_model.getSpaces.each do |space|
      expect(space.thermalZone.empty?).to be(false)
      expect(plenum?(space, airloops, setpoints)).to be(false)
      zone = space.thermalZone.get
      heating, _ = maxHeatScheduledSetpoint(zone)
      cooling, _ = minCoolScheduledSetpoint(zone)
      if zone.nameString == "Zone1 Office ZN"
        expect(heating).to be_within(0.1).of(21.1)
        expect(cooling).to be_within(0.1).of(23.9)
      elsif zone.nameString == "Zone2 Fine Storage ZN"
        expect(heating).to be_within(0.1).of(15.6)
        expect(cooling).to be_within(0.1).of(26.7)
      else
        expect(heating).to be_within(0.1).of(10.0)
        expect(cooling).to be_within(0.1).of(50.0)
      end
    end

    ids = { a: "Office Front Wall",
            b: "Office Left Wall",
            c: "Fine Storage Roof",
            d: "Fine Storage Office Front Wall",
            e: "Fine Storage Office Left Wall",
            f: "Fine Storage Front Wall",
            g: "Fine Storage Left Wall",
            h: "Fine Storage Right Wall",
            i: "Bulk Storage Roof",
            j: "Bulk Storage Rear Wall",
            k: "Bulk Storage Left Wall",
            l: "Bulk Storage Right Wall" }.freeze

    id2 = { a: "Office Front Door",
            b: "Office Left Wall Door",
            c: "Fine Storage Left Door",
            d: "Fine Storage Right Door",
            e: "Bulk Storage Door-1",
            f: "Bulk Storage Door-2",
            g: "Bulk Storage Door-3",
            h: "Overhead Door 1",
            i: "Overhead Door 2",
            j: "Overhead Door 3",
            k: "Overhead Door 4",
            l: "Overhead Door 5",
            m: "Overhead Door 6",
            n: "Overhead Door 7" }.freeze

    psi = PSI.new
    ref = "code (Quebec)"
    has, val = psi.shorthands(ref)
    expect(has.empty?).to be(false)
    expect(val.empty?).to be(false)

    argh[:option] = "poor (BETBG)"
    argh[:seed] = "./files/osms/in/test_warehouse.osm"
    argh[:io_path] = File.join(__dir__, "../json/tbd_warehouse10.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    argh[:gen_ua] = true
    argh[:ua_ref] = ref
    argh[:version] = os_model.getVersion.versionIdentifier
    argh[:io], argh[:surfaces] = processTBD(os_model, argh)

    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(argh[:io].nil?).to be(false)
    expect(argh[:io].is_a?(Hash)).to be(true)
    expect(argh[:io].empty?).to be(false)
    expect(argh[:surfaces].nil?).to be(false)
    expect(argh[:surfaces].is_a?(Hash)).to be(true)
    expect(argh[:io].key?(:edges))
    expect(argh[:io][:edges].size).to eq(300)
    expect(argh[:surfaces].size).to eq(23)

    argh[:io][:description] = "test"

    # Set up 2x heating setpoint (HSTP) "blocks":
    #   bloc1: spaces/zones with HSTP >= 18°C
    #   bloc2: spaces/zones with HSTP < 18°C
    #   (ref: 2021 Quebec energy code 3.3. UA' trade-off methodology)
    #   ... could be generalized in the future e.g., more blocks, user-set HSTP.
    #
    # Determine UA' compliance separately for (i) bloc1 & (ii) bloc2.
    #
    # Each block's UA' = ∑ U•area + ∑ PSI•length + ∑ KHI•count
    blc = { walls:   0, roofs:     0, floors:    0, doors:     0,
            windows: 0, skylights: 0, rimjoists: 0, parapets:  0,
            trim:    0, corners:   0, balconies: 0, grade:     0,
            other:   0 # includes party wall edges, expansion joints, etc.
          }
    bloc1 = {}
    bloc2 = {}
    bloc1[:pro] = blc
    bloc1[:ref] = blc.clone
    bloc2[:pro] = blc.clone
    bloc2[:ref] = blc.clone

    argh[:surfaces].each do |id, surface|
      expect(surface.key?(:deratable)).to be(true)
      next unless surface[:deratable]
      expect(ids.has_value?(id)).to be(true)
      expect(surface.key?(:type)).to be(true)
      expect(surface.key?(:net)).to be(true)
      expect(surface[:net] > TOL).to be(true)

      expect(surface.key?(:u)).to be(true)
      expect(surface[:u] > TOL).to be(true)
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:a]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:b]
      expect(surface[:u]).to be_within(0.01).of(0.31) if id == ids[:c]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:d]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:e]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:f]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:g]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:h]
      expect(surface[:u]).to be_within(0.01).of(0.55) if id == ids[:i]
      expect(surface[:u]).to be_within(0.01).of(0.64) if id == ids[:j]
      expect(surface[:u]).to be_within(0.01).of(0.64) if id == ids[:k]
      expect(surface[:u]).to be_within(0.01).of(0.64) if id == ids[:l]

      # Reference values.
      expect(surface.key?(:ref)).to be(true)
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:a]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:b]
      expect(surface[:ref]).to be_within(0.01).of(0.18) if id == ids[:c]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:d]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:e]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:f]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:g]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:h]
      expect(surface[:ref]).to be_within(0.01).of(0.23) if id == ids[:i]
      expect(surface[:ref]).to be_within(0.01).of(0.34) if id == ids[:j]
      expect(surface[:ref]).to be_within(0.01).of(0.34) if id == ids[:k]
      expect(surface[:ref]).to be_within(0.01).of(0.34) if id == ids[:l]

      expect(surface.key?(:heating)).to be(true)
      expect(surface.key?(:cooling)).to be(true)

      bloc = bloc1
      bloc = bloc2 if surface[:heating] < 18

      if surface[:type] == :wall
        bloc[:pro][:walls] += surface[:net] * surface[:u]
        bloc[:ref][:walls] += surface[:net] * surface[:ref]
      elsif surface[:type] == :ceiling
        bloc[:pro][:roofs] += surface[:net] * surface[:u]
        bloc[:ref][:roofs] += surface[:net] * surface[:ref]
      else
        bloc[:pro][:floors] += surface[:net] * surface[:u]
        bloc[:ref][:floors] += surface[:net] * surface[:ref]
      end

      if surface.key?(:doors)
        surface[:doors].each do |i, door|
          expect(id2.has_value?(i)).to be(true)
          expect(door.key?(:gross)).to be(true)
          expect(door[:gross] > TOL).to be(true)
          expect(door.key?(:glazed)).to be(false)
          expect(door.key?(:u)).to be(true)
          expect(door[:u] > TOL).to be(true)
          expect(door[:u]).to be_within(0.01).of(3.98)
          expect(door.key?(:ref)).to be(true)
          expect(door[:ref] > TOL).to be(true)
          bloc[:pro][:doors] += door[:gross] * door[:u]
          bloc[:ref][:doors] += door[:gross] * door[:ref]
        end
      end

      if surface.key?(:skylights)
        surface[:skylights].each do |i, skylight|
          expect(skylight.key?(:gross)).to be(true)
          expect(skylight[:gross] > TOL).to be(true)
          expect(skylight.key?(:u)).to be(true)
          expect(skylight[:u] > TOL).to be(true)
          expect(skylight[:u]).to be_within(0.01).of(6.64)
          expect(skylight.key?(:ref)).to be(true)
          expect(skylight[:ref] > TOL).to be(true)
          bloc[:pro][:skylights] += skylight[:gross] * skylight[:u]
          bloc[:ref][:skylights] += skylight[:gross] * skylight[:ref]
        end
      end

      id3 = { a: "Office Front Wall Window 1",
              b: "Office Front Wall Window2" }.freeze

      if surface.key?(:windows)
        surface[:windows].each do |i, window|
          expect(window.key?(:u)).to be(true)
          expect(window.key?(:ref)).to be(true)
          expect(window[:ref] > TOL).to be(true)
          bloc[:pro][:windows] += window[:gross] * window[:u]
          bloc[:ref][:windows] += window[:gross] * window[:ref]
          expect(window[:u] > 0).to be(true)
          expect(window[:u]).to be_within(0.01).of(4.00) if i == id3[:a]
          expect(window[:u]).to be_within(0.01).of(3.50) if i == id3[:b]
          expect(window[:gross]).to be_within(0.1).of(5.58) if i == id3[:a]
          expect(window[:gross]).to be_within(0.1).of(5.58) if i == id3[:b]
          next if i == id3[:a] || i == id3[:b]
          expect(window[:gross]).to be_within(0.1).of(3.25)
          expect(window[:u]).to be_within(0.01).of(2.35)
        end
      end

      if surface.key?(:edges)
        surface[:edges].values.each do |edge|
          expect(edge.key?(:type)).to be(true)
          expect(edge.key?(:ratio)).to be(true)
          expect(edge.key?(:ref)).to be(true)
          expect(edge.key?(:psi)).to be(true)
          next unless edge[:psi] > TOL

          tt = psi.safeType(ref, edge[:type])
          expect(tt.nil?).to be(false)
          expect(edge[:ref]).to be_within(0.01).of(val[tt] * edge[:ratio])
          rate = edge[:ref] / edge[:psi] * 100

          case tt
          when :rimjoist
            expect(rate).to be_within(0.1).of(30.0)
            bloc[:pro][:rimjoists] += edge[:length] * edge[:psi]
            bloc[:ref][:rimjoists] += edge[:length] * val[tt] * edge[:ratio]
          when :parapet
            expect(rate).to be_within(0.1).of(40.6)
            bloc[:pro][:parapets] += edge[:length] * edge[:psi]
            bloc[:ref][:parapets] += edge[:length] * val[tt] * edge[:ratio]
          when :fenestration
            expect(rate).to be_within(0.1).of(40.0)
            bloc[:pro][:trim] += edge[:length] * edge[:psi]
            bloc[:ref][:trim] += edge[:length] * val[tt] * edge[:ratio]
          when :corner
            expect(rate).to be_within(0.1).of(35.3)
            bloc[:pro][:corners] += edge[:length] * edge[:psi]
            bloc[:ref][:corners] += edge[:length] * val[tt] * edge[:ratio]
          when :grade
            expect(rate).to be_within(0.1).of(52.9)
            bloc[:pro][:grade] += edge[:length] * edge[:psi]
            bloc[:ref][:grade] += edge[:length] * val[tt] * edge[:ratio]
          else
            expect(rate).to be_within(0.1).of( 0.0)
            bloc[:pro][:other] += edge[:length] * edge[:psi]
            bloc[:ref][:other] += edge[:length] * val[tt] * edge[:ratio]
          end
        end
      end

      if surface.key?(:pts)
        surface[:pts].values.each do |pts|
          expect(pts.key?(:val)).to be(true)
          expect(pts.key?(:n)).to be(true)
          bloc[:pro][:other] += pts[:val] * pts[:n]
          expect(pts.key?(:ref)).to be(true)
          bloc[:ref][:other] += pts[:ref] * pts[:n]
        end
      end
    end

    expect(bloc1[:pro][:walls]).to     be_within(0.1).of(  60.1)
    expect(bloc1[:pro][:roofs]).to     be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:floors]).to    be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:doors]).to     be_within(0.1).of(  23.3)
    expect(bloc1[:pro][:windows]).to   be_within(0.1).of(  57.1)
    expect(bloc1[:pro][:skylights]).to be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:rimjoists]).to be_within(0.1).of(  17.5)
    expect(bloc1[:pro][:parapets]).to  be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:trim]).to      be_within(0.1).of(  23.3)
    expect(bloc1[:pro][:corners]).to   be_within(0.1).of(   3.6)
    expect(bloc1[:pro][:balconies]).to be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:grade]).to     be_within(0.1).of(  29.8)
    expect(bloc1[:pro][:other]).to     be_within(0.1).of(   0.0)

    bloc1_pro_UA = bloc1[:pro].values.reduce(:+)
    expect(bloc1_pro_UA).to be_within(0.1).of(214.8)
    # Info: Design (fully heated): 199.2 W/K vs 114.2 W/K

    expect(bloc1[:ref][:walls]).to     be_within(0.1).of(  35.0)
    expect(bloc1[:ref][:roofs]).to     be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:floors]).to    be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:doors]).to     be_within(0.1).of(   5.3)
    expect(bloc1[:ref][:windows]).to   be_within(0.1).of(  35.3)
    expect(bloc1[:ref][:skylights]).to be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:rimjoists]).to be_within(0.1).of(   5.3)
    expect(bloc1[:ref][:parapets]).to  be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:trim]).to      be_within(0.1).of(   9.3)
    expect(bloc1[:ref][:corners]).to   be_within(0.1).of(   1.3)
    expect(bloc1[:ref][:balconies]).to be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:grade]).to     be_within(0.1).of(  15.8)
    expect(bloc1[:ref][:other]).to     be_within(0.1).of(   0.0)

    bloc1_ref_UA = bloc1[:ref].values.reduce(:+)
    expect(bloc1_ref_UA).to be_within(0.1).of(107.2)

    expect(bloc2[:pro][:walls]).to     be_within(0.1).of(1342.0)
    expect(bloc2[:pro][:roofs]).to     be_within(0.1).of(2169.2)
    expect(bloc2[:pro][:floors]).to    be_within(0.1).of(   0.0)
    expect(bloc2[:pro][:doors]).to     be_within(0.1).of( 245.6)
    expect(bloc2[:pro][:windows]).to   be_within(0.1).of(   0.0)
    expect(bloc2[:pro][:skylights]).to be_within(0.1).of( 454.3)
    expect(bloc2[:pro][:rimjoists]).to be_within(0.1).of(  17.5)
    expect(bloc2[:pro][:parapets]).to  be_within(0.1).of( 234.1)
    expect(bloc2[:pro][:trim]).to      be_within(0.1).of( 155.0)
    expect(bloc2[:pro][:corners]).to   be_within(0.1).of(  25.4)
    expect(bloc2[:pro][:balconies]).to be_within(0.1).of(   0.0)
    expect(bloc2[:pro][:grade]).to     be_within(0.1).of( 218.9)
    expect(bloc2[:pro][:other]).to     be_within(0.1).of(   1.6)

    bloc2_pro_UA = bloc2[:pro].values.reduce(:+)
    expect(bloc2_pro_UA).to be_within(0.1).of(4863.6)

    expect(bloc2[:ref][:walls]).to     be_within(0.1).of( 732.0)
    expect(bloc2[:ref][:roofs]).to     be_within(0.1).of( 961.8)
    expect(bloc2[:ref][:floors]).to    be_within(0.1).of(   0.0)
    expect(bloc2[:ref][:doors]).to     be_within(0.1).of(  67.5)
    expect(bloc2[:ref][:windows]).to   be_within(0.1).of(   0.0)
    expect(bloc2[:ref][:skylights]).to be_within(0.1).of( 225.9)
    expect(bloc2[:ref][:rimjoists]).to be_within(0.1).of(   5.3)
    expect(bloc2[:ref][:parapets]).to  be_within(0.1).of(  95.1)
    expect(bloc2[:ref][:trim]).to      be_within(0.1).of(  62.0)
    expect(bloc2[:ref][:corners]).to   be_within(0.1).of(   9.0)
    expect(bloc2[:ref][:balconies]).to be_within(0.1).of(   0.0)
    expect(bloc2[:ref][:grade]).to     be_within(0.1).of( 115.9)
    expect(bloc2[:ref][:other]).to     be_within(0.1).of(   1.0)

    bloc2_ref_UA = bloc2[:ref].values.reduce(:+)
    expect(bloc2_ref_UA).to be_within(0.1).of(2275.4)

    # Testing summaries function.
    ua = ua_summary(Time.now, argh)
    expect(ua.nil?).to be(false)
    expect(ua.empty?).to be(false)
    expect(ua.is_a?(Hash)).to be(true)
    expect(ua.key?(:model))

    expect(ua.key?(:fr)).to be(true)
    expect(ua[:fr].key?(:objective)).to be(true)
    expect(ua[:fr][:objective].empty?).to be(false)
    expect(ua[:fr].key?(:details)).to be(true)
    expect(ua[:fr][:details].is_a?(Array)).to be(true)
    expect(ua[:fr][:details].empty?).to be(false)
    expect(ua[:fr].key?(:areas)).to be(true)
    expect(ua[:fr][:areas].empty?).to be(false)
    expect(ua[:fr][:areas].is_a?(Hash)).to be(true)
    expect(ua[:fr][:areas].key?(:walls)).to be(true)
    expect(ua[:fr][:areas].key?(:roofs)).to be(true)
    expect(ua[:fr][:areas].key?(:floors)).to be(false)
    expect(ua[:fr].key?(:notes)).to be(true)
    expect(ua[:fr][:notes].empty?).to be(false)

    expect(ua[:fr].key?(:b1)).to be(true)
    expect(ua[:fr][:b1].empty?).to be(false)
    expect(ua[:fr][:b1].key?(:summary)).to be(true)
    expect(ua[:fr][:b1].key?(:walls)).to be(true)
    expect(ua[:fr][:b1].key?(:roofs)).to be(false)
    expect(ua[:fr][:b1].key?(:floors)).to be(false)
    expect(ua[:fr][:b1].key?(:doors)).to be(true)
    expect(ua[:fr][:b1].key?(:windows)).to be(true)
    expect(ua[:fr][:b1].key?(:skylights)).to be(false)
    expect(ua[:fr][:b1].key?(:rimjoists)).to be(true)
    expect(ua[:fr][:b1].key?(:parapets)).to be(false)
    expect(ua[:fr][:b1].key?(:trim)).to be(true)
    expect(ua[:fr][:b1].key?(:corners)).to be(true)
    expect(ua[:fr][:b1].key?(:balconies)).to be(false)
    expect(ua[:fr][:b1].key?(:grade)).to be(true)
    expect(ua[:fr][:b1].key?(:other)).to be(false)

    expect(ua[:fr].key?(:b2)).to be(true)
    expect(ua[:fr][:b2].empty?).to be(false)
    expect(ua[:fr][:b2].key?(:summary)).to be(true)
    expect(ua[:fr][:b2].key?(:walls)).to be(true)
    expect(ua[:fr][:b2].key?(:roofs)).to be(true)
    expect(ua[:fr][:b2].key?(:floors)).to be(false)
    expect(ua[:fr][:b2].key?(:doors)).to be(true)
    expect(ua[:fr][:b2].key?(:windows)).to be(false)
    expect(ua[:fr][:b2].key?(:skylights)).to be(true)
    expect(ua[:fr][:b2].key?(:rimjoists)).to be(true)
    expect(ua[:fr][:b2].key?(:parapets)).to be(true)
    expect(ua[:fr][:b2].key?(:trim)).to be(true)
    expect(ua[:fr][:b2].key?(:corners)).to be(true)
    expect(ua[:fr][:b2].key?(:balconies)).to be(false)
    expect(ua[:fr][:b2].key?(:grade)).to be(true)
    expect(ua[:fr][:b2].key?(:other)).to be(true)

    expect(ua[:en].key?(:b1)).to be(true)
    expect(ua[:en][:b1].empty?).to be(false)
    expect(ua[:en][:b1].key?(:summary)).to be(true)
    expect(ua[:en][:b1].key?(:walls)).to be(true)
    expect(ua[:en][:b1].key?(:roofs)).to be(false)
    expect(ua[:en][:b1].key?(:floors)).to be(false)
    expect(ua[:en][:b1].key?(:doors)).to be(true)
    expect(ua[:en][:b1].key?(:windows)).to be(true)
    expect(ua[:en][:b1].key?(:skylights)).to be(false)
    expect(ua[:en][:b1].key?(:rimjoists)).to be(true)
    expect(ua[:en][:b1].key?(:parapets)).to be(false)
    expect(ua[:en][:b1].key?(:trim)).to be(true)
    expect(ua[:en][:b1].key?(:corners)).to be(true)
    expect(ua[:en][:b1].key?(:balconies)).to be(false)
    expect(ua[:en][:b1].key?(:grade)).to be(true)
    expect(ua[:en][:b1].key?(:other)).to be(false)

    expect(ua[:en].key?(:b2)).to be(true)
    expect(ua[:en][:b2].empty?).to be(false)
    expect(ua[:en][:b2].key?(:summary)).to be(true)
    expect(ua[:en][:b2].key?(:walls)).to be(true)
    expect(ua[:en][:b2].key?(:roofs)).to be(true)
    expect(ua[:en][:b2].key?(:floors)).to be(false)
    expect(ua[:en][:b2].key?(:doors)).to be(true)
    expect(ua[:en][:b2].key?(:windows)).to be(false)
    expect(ua[:en][:b2].key?(:skylights)).to be(true)
    expect(ua[:en][:b2].key?(:rimjoists)).to be(true)
    expect(ua[:en][:b2].key?(:parapets)).to be(true)
    expect(ua[:en][:b2].key?(:trim)).to be(true)
    expect(ua[:en][:b2].key?(:corners)).to be(true)
    expect(ua[:en][:b2].key?(:balconies)).to be(false)
    expect(ua[:en][:b2].key?(:grade)).to be(true)
    expect(ua[:en][:b2].key?(:other)).to be(true)

    ud_md_en = ua_md(ua, :en)
    path = File.join(__dir__, "files/ua/ua_en.md")
    File.open(path, "w") { |file| file.puts ud_md_en }

    ud_md_fr = ua_md(ua, :fr)
    path = File.join(__dir__, "files/ua/ua_fr.md")
    File.open(path, "w") { |file| file.puts ud_md_fr }

    # Try with an incomplete reference, e.g. (non thermal bridging)
    TBD.clean!
    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # When faced with an edge that may be characterized by more than one thermal
    # bridge type (e.g. ground-floor door "sill" vs "grade" edge; "corner" vs
    # corner window "jamb"), TBD retains the edge type (amongst candidate edge
    # types) representing the greatest heat loss:
    #
    #   psi = edge[:psi].values.max
    #   type = edge[:psi].key(psi)
    #
    # As long as there is a slight difference in PSI-values between candidate
    # edge types, the automated selection will be deterministic. With 2 or more
    # edge types sharing the exact same PSI value (e.g. 0.3 W/K per m), the
    # final selection of edge type becomes less obvious. It is not randomly
    # selected, but rather based on the (somewhat arbitrary) design choice of
    # which edge type is processed first in psi.rb (line ~2300 onwards). For
    # instance, fenestration perimeter joints are treated before corners or
    # parapets. When dealing with equal hash values, Ruby's Hash "key" method
    # returns the first key (i.e. edge type) that matches the criterion:
    #
    # https://docs.ruby-lang.org/en/2.0.0/Hash.html#method-i-key
    #
    # From an energy simulation results perspective, the consequences of this
    # pseudo-random choice are insignificant (i.e. same PSI-value). For UA'
    # comparisons, the situation becomes less obvious in outlier cases. When a
    # reference value needs to be generated for the edge described above, TBD
    # retains the original autoselected edge type, yet applies reference PSI
    # values (e.g. code). So far so good. However, when "(non thermal bridging)"
    # is retained as a default PSI design set (not as a reference set), all edge
    # types will necessarily have 0 W/K per meter as PSI-values. Same with the
    # "efficient (BETBG)" PSI set (all but one type at 0.2 W/K per m). Not
    # obvious (for users) which edge type will be selected by TBD for multi-type
    # edges. This also has the undesirable effect of generating variations in
    # reference UA' tallies, depending on the chosen design PSI set (as the
    # reference PSI set may have radically different PSI-values depending on
    # the pseudo-random edge type selection). Fortunately, this effect is
    # limited to the somewhat academic PSI sets like "(non thermal bridging)" or
    # "efficient (BETBG)".
    #
    # In the end, the above discussion remains an "aide-mémoire" for future
    # guide material, yet also as a basis for peer-review commentary of upcoming
    # standards on thermal bridging.
    argh[:io] = nil
    argh[:surfaces] = nil
    argh[:option] = "(non thermal bridging)"
    argh[:io_path] = nil
    argh[:schema_path] = nil
    argh[:gen_ua] = true
    argh[:ua_ref] = ref
    argh[:io], argh[:surfaces] = processTBD(os_model, argh)

    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(argh[:io].nil?).to be(false)
    expect(argh[:io].is_a?(Hash)).to be(true)
    expect(argh[:io].empty?).to be(false)
    expect(argh[:surfaces].nil?).to be(false)
    expect(argh[:surfaces].is_a?(Hash)).to be(true)
    expect(argh[:io].key?(:edges))
    expect(argh[:io][:edges].size).to eq(300)
    expect(argh[:surfaces].size).to eq(23)

    # Testing summaries function.
    argh[:io][:description] = "testing non thermal bridging"

    ua = ua_summary(Time.now, argh)
    expect(ua.nil?).to be(false)
    expect(ua.empty?).to be(false)
    expect(ua.is_a?(Hash)).to be(true)
    expect(ua.key?(:model))

    en_ud_md = ua_md(ua, :en)
    path = File.join(__dir__, "files/ua/en_ua.md")
    File.open(path, "w") { |file| file.puts en_ud_md  }

    fr_ud_md = ua_md(ua, :fr)
    path = File.join(__dir__, "files/ua/fr_ua.md")
    File.open(path, "w") { |file| file.puts fr_ud_md }
  end

  it "can work off of a cloned model" do
    TBD.clean!
    argh1 = {option: "poor (BETBG)"}
    argh2 = {option: "poor (BETBG)"}
    argh3 = {option: "poor (BETBG)"}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    alt_model = model.clone
    alt_file = File.join(__dir__, "files/osms/out/alt_warehouse.osm")
    alt_model.save(alt_file, true)

    # Despite one being the clone of the other, files will not be identical,
    # namely due to unique handles.
    expect(FileUtils.identical?(file, alt_file)).to be(false)

    argh1[:io], argh1[:surfaces] = processTBD(model, argh1)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(argh1[:io].nil?).to be(false)
    expect(argh1[:io].is_a?(Hash)).to be(true)
    expect(argh1[:io].empty?).to be(false)
    expect(argh1[:io].key?(:edges)).to be(true)
    expect(argh1[:io][:edges].size).to eq(300)
    expect(argh1[:surfaces].nil?).to be(false)
    expect(argh1[:surfaces].is_a?(Hash)).to be(true)
    expect(argh1[:surfaces].size).to eq(23)
    out = JSON.pretty_generate(argh1[:io])
    outP = File.join(__dir__, "../json/tbd_warehouse12.out.json")
    File.open(outP, "w") { |outP| outP.puts out }

    TBD.clean!
    alt_file = File.join(__dir__, "files/osms/out/alt_warehouse.osm")
    alt_path = OpenStudio::Path.new(alt_file)
    alt_model = translator.loadModel(alt_path)
    expect(alt_model.empty?).to be(false)
    alt_model = alt_model.get

    argh2[:io], argh2[:surfaces] = processTBD(alt_model, argh2)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(argh2[:io].nil?).to be(false)
    expect(argh2[:io].is_a?(Hash)).to be(true)
    expect(argh2[:io].empty?).to be(false)
    expect(argh2[:io].key?(:edges)).to be(true)
    expect(argh2[:io][:edges].size).to eq(300)
    expect(argh2[:surfaces].nil?).to be(false)
    expect(argh2[:surfaces].is_a?(Hash)).to be(true)
    expect(argh2[:surfaces].size).to eq(23)
    out2 = JSON.pretty_generate(argh2[:io])
    outP2 = File.join(__dir__, "../json/tbd_warehouse13.out.json")
    File.open(outP2, "w") { |outP2| outP2.puts out2 }

    # The JSON output files are identical.
    expect(FileUtils.identical?(outP, outP2)).to be(true)

    time = Time.now

    # Original output UA' MD file.
    argh1[:ua_ref] = "code (Quebec)"
    argh1[:io][:description] = "testing equality"
    argh1[:version] = model.getVersion.versionIdentifier
    argh1[:seed] = File.join(__dir__, "files/osms/in/warehouse.osm")
    o_ua = ua_summary(time, argh1)
    expect(o_ua.nil?).to be(false)
    expect(o_ua.empty?).to be(false)
    expect(o_ua.is_a?(Hash)).to be(true)
    expect(o_ua.key?(:model))

    o_ud_md_en = ua_md(o_ua, :en)
    path1 = File.join(__dir__, "files/ua/o_ua_en.md")
    File.open(path1, "w") { |file| file.puts o_ud_md_en }

    # Alternate output UA' MD file.
    argh2[:ua_ref] = "code (Quebec)"
    argh2[:io][:description] = "testing equality"
    argh2[:version] = model.getVersion.versionIdentifier
    argh2[:seed] = File.join(__dir__, "files/osms/in/warehouse.osm")
    alt_ua = ua_summary(time, argh2)
    expect(alt_ua.nil?).to be(false)
    expect(alt_ua.empty?).to be(false)
    expect(alt_ua.is_a?(Hash)).to be(true)
    expect(alt_ua.key?(:model))

    alt_ud_md_en = ua_md(alt_ua, :en)
    path2 = File.join(__dir__, "files/ua/alt_ua_en.md")
    File.open(path2, "w") { |file| file.puts alt_ud_md_en }

    # Both output UA' MD files should be identical.
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(FileUtils.identical?(path1, path2)).to be(true)

    # Testing the Macumber solution.
    TBD.clean!
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    alt2_model = OpenStudio::Model::Model.new
    alt2_model.addObjects(model.toIdfFile.objects)
    alt2_file = File.join(__dir__, "files/osms/out/alt2_warehouse.osm")
    alt2_model.save(alt2_file, true)

    # Still get the differences in handles (not consequential at all if the TBD
    # JSON output files are identical).
    expect(FileUtils.identical?(file, alt2_file)).to be(false)

    argh3[:io], argh3[:surfaces] = processTBD(alt2_model, argh3)
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(argh3[:io].nil?).to be(false)
    expect(argh3[:io].is_a?(Hash)).to be(true)
    expect(argh3[:io].empty?).to be(false)
    expect(argh3[:io].key?(:edges)).to be(true)
    expect(argh3[:io][:edges].size).to eq(300)
    expect(argh3[:surfaces].nil?).to be(false)
    expect(argh3[:surfaces].is_a?(Hash)).to be(true)
    expect(argh3[:surfaces].size).to eq(23)

    out3 = JSON.pretty_generate(argh3[:io])
    outP3 = File.join(__dir__, "../json/tbd_warehouse14.out.json")
    File.open(outP3, "w") { |outP3| outP3.puts out3 }

    # Nice. Both TBD JSON output files are identical!
    # "/../json/tbd_warehouse12.out.json" vs "/../json/tbd_warehouse14.out.json"
    expect(FileUtils.identical?(outP, outP3)).to be(true)
  end

  it "can generate and access KIVA inputs (seb)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_seb.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Set one of the ground-facing surfaces to (Kiva) "Foundation".
    os_model.getSurfaces.each do |s|
      next unless s.nameString == "Open area 1 Floor"
      construction = s.construction.get
      expect(s.setOutsideBoundaryCondition("Foundation")).to be(true)
      expect(s.setConstruction(construction)).to be(true)
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
      next unless s.nameString == "Open area 1 Floor"
      s.setAdjacentFoundation(kiva_slab_2020s)
      arg = "TotalExposedPerimeter"
      s.createSurfacePropertyExposedFoundationPerimeter(arg, 12.59)
    end

    file = File.join(__dir__, "files/osms/out/os_model_KIVA.osm")
    os_model.save(file, true)

    # Now re-open for testing.
    path = OpenStudio::Path.new(file)
    os_model2 = translator.loadModel(path)
    expect(os_model2.empty?).to be(false)
    os_model2 = os_model2.get

    os_model2.getSurfaces.each do |s|
      next unless s.isGroundSurface
      next unless s.nameString == "Open area 1 Floor"
      construction = s.construction.get
      expect(s.setOutsideBoundaryCondition("Foundation")).to be(true)
      expect(s.setConstruction(construction)).to be(true)
    end

    # Set one of the linked outside-facing walls to (Kiva) "Foundation"
    os_model2.getSurfaces.each do |s|
      next unless s.nameString == "Openarea 1 Wall 5"
      construction = s.construction.get
      expect(s.setOutsideBoundaryCondition("Foundation")).to be(true)
      expect(s.setConstruction(construction)).to be(true)
    end

    kfs = os_model2.getFoundationKivas
    expect(kfs.empty?).to be(false)
    expect(kfs.size).to eq(4)

    settings = os_model2.getFoundationKivaSettings
    expect(settings.soilConductivity).to be_within(0.01).of(1.73)

    argh[:option] = "poor (BETBG)"
    argh[:gen_kiva] = true
    io, surfaces = processTBD(os_model2, argh)

    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(56)

    surfaces.each do |id, surface|
      next unless surface.key?(:foundation)
      next unless surface.key?(:kiva)
      expect(id).to eq("Open area 1 Floor").or eq("Openarea 1 Wall 5")
      if id == "Open area 1 Floor"
        expect(surface[:kiva]).to eq(:basement)
        expect(surface.key?(:exposed)).to be (true)
        expect(surface[:exposed]).to be_within(0.01).of(8.70)     # 12.59 - 3.89
      else
        expect(surface[:kiva]).to eq("Open area 1 Floor")
      end
    end
  end

  it "can generate and access KIVA inputs (midrise apts - variant)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/midrise_KIVA.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    argh[:option] = "poor (BETBG)"
    argh[:gen_kiva] = true
    io, surfaces = processTBD(os_model, argh)

    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(180)

    # Validate.
    surfaces.each do |id, surface|
      next unless surface.key?(:foundation)                    # ... only floors
      next unless surface.key?(:kiva)
      expect(surface[:kiva]).to eq(:slab)
      expect(surface.key?(:exposed)).to be(true)
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
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/midrise_KIVA.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    # Reset all ground-facing floor surfaces as "foundations".
    os_model.getSurfaces.each do |s|
      next unless s.outsideBoundaryCondition.downcase == "ground"
      construction = s.construction.get
      expect(s.setOutsideBoundaryCondition("Foundation")).to be(true)
      expect(s.setConstruction(construction)).to be(true)
    end

    argh[:option] = "poor (BETBG)"
    argh[:gen_kiva] = true
    io, surfaces = processTBD(os_model, argh)

    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(180)

    # Validate.
    surfaces.each do |id, surface|
      next unless surface.key?(:foundation)                        # only floors
      next unless surface.key?(:kiva)
      expect(surface[:kiva]).to eq(:slab)
      expect(surface.key?(:exposed)).to be(true)
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
        expect(exp).to be_within(0.01).of( 3.36) if id == "g Floor C"
      end
      expect(found).to be(true)
    end
  end

  it "can generate KIVA exposed perimeters (warehouse)" do
    TBD.clean!
    argh = {}

    translator = OpenStudio::OSVersion::VersionTranslator.new
    file = File.join(__dir__, "files/osms/in/test_warehouse.osm")
    path = OpenStudio::Path.new(file)
    os_model = translator.loadModel(path)
    expect(os_model.empty?).to be(false)
    os_model = os_model.get

    fl1 = "Fine Storage Floor"
    fl2 = "Office Floor"
    fl3 = "Bulk Storage Floor"

    # Reset all ground-facing floor surfaces as "foundations".
    os_model.getSurfaces.each do |s|
      next unless s.outsideBoundaryCondition.downcase == "ground"
      construction = s.construction.get
      expect(s.setOutsideBoundaryCondition("Foundation")).to be(true)
      expect(s.setConstruction(construction)).to be(true)
    end

    argh[:option] = "(non thermal bridging)"
    argh[:gen_kiva] = true
    io, surfaces = processTBD(os_model, argh)

    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(23)

    # Validate.
    surfaces.each do |id, surface|
      next unless surface.key?(:foundation)                        # only floors
      next unless surface.key?(:kiva)
      expect(surface[:kiva]).to eq(:slab)
      expect(surface.key?(:exposed)).to be(true)
      exp = surface[:exposed]

      found = false
      os_model.getSurfaces.each do |s|
        next unless s.nameString == id
        next unless s.outsideBoundaryCondition.downcase == "foundation"
        found = true

        expect(exp).to be_within(0.01).of( 71.62) if id == "fl1"
        expect(exp).to be_within(0.01).of( 35.05) if id == "fl2"
        expect(exp).to be_within(0.01).of(185.92) if id == "fl3"
      end
      expect(found).to be(true)
    end

    pth = File.join(__dir__, "files/osms/out/warehouse_KIVA.osm")
    os_model.save(pth, true)

    # Now re-open for testing.
    path = OpenStudio::Path.new(pth)
    os_model2 = translator.loadModel(path)
    expect(os_model2.empty?).to be(false)
    os_model2 = os_model2.get

    os_model2.getSurfaces.each do |s|
      next unless s.isGroundSurface
      expect(s.nameString).to eq(fl1).or eq(fl2).or eq(fl3)
      expect(s.outsideBoundaryCondition).to eq("Foundation")
    end

    kfs = os_model2.getFoundationKivas
    expect(kfs.empty?).to be(false)
    expect(kfs.size).to eq(3)
  end
end
