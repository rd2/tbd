require "psi"

RSpec.describe TBD do

  it "can compute uFactor for ceilings, walls, and floors" do

    os_model = OpenStudio::Model::Model.new
    space = OpenStudio::Model::Space.new(os_model)

    soffit = OpenStudio::Model::StandardOpaqueMaterial.new(os_model)
    soffit.setRoughness("Smooth")
    soffit.setThickness(0.0159)
    soffit.setConductivity(0.12)
    soffit.setDensity(544)
    soffit.setSpecificHeat(1210)
    soffit.setThermalAbsorptance(0.9)
    soffit.setSolarAbsorptance(0.7)
    soffit.setVisibleAbsorptance(0.7)

    layers = OpenStudio::Model::MaterialVector.new
    layers << soffit
    construction = OpenStudio::Model::Construction.new(os_model)
    construction.setLayers(layers)

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

    # make ground
    expect(floor.setOutsideBoundaryCondition("Outdoors")).to be(true)
    expect(floor.filmResistance).to be_within(0.001).of(0.190)

    # now make these surfaces not outdoors
    expect(ceiling.setOutsideBoundaryCondition("Adiabatic")).to be(true)
    expect(ceiling.filmResistance).to be_within(0.001).of(0.212)

    expect(wall.setOutsideBoundaryCondition("Adiabatic")).to be(true)
    expect(wall.filmResistance).to be_within(0.001).of(0.239)

    expect(floor.setOutsideBoundaryCondition("Adiabatic")).to be(true)
    expect(floor.filmResistance).to be_within(0.001).of(0.321)

  end
end
