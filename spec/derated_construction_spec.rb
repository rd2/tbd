require "psi"

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
  end
end
