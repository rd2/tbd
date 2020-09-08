require "openstudio"
require "topolys"
require "psi"

RSpec.describe TBD do
  it "can process thermal bridging and derating : LoScrigno" do
    # The following populates both OpenStudio and Topolys models of "Lo scrigno"
    # (or Jewel Box), by Renzo Piano (Lingotto Factory, Turin); a cantilevered,
    # single space art gallery (space #1), above a slanted plenum (space #2),
    # and resting on four main pillars. For the purposes of the spec, vertical
    # access (elevator and stairs, fully glazed) are modelled as extensions
    # of either space.

    # Returns site/space transformation & rotation
    def transforms(model, group)
      if model && group
        unless model.is_a?(OpenStudio::Model::Model)
          raise "Expected OpenStudio model - got #{model.class}"
        end
        unless group.is_a?(OpenStudio::Model::Space)               ||
               group.is_a?(OpenStudio::Model::ShadingSurfaceGroup)
          raise "Expected OpenStudio group - got a #{group.class}"
        end
        t = group.siteTransformation
        r = group.directionofRelativeNorth + model.getBuilding.northAxis
        return t, r
      end
    end

    # Returns site-specific (or absolute) Topolys surface normal
    def trueNormal(s, r)
      if s && r
        c = OpenStudio::Model::PlanarSurface
        raise "Expected #{c} - got #{s.class}" unless s.is_a?(c)
        raise "Expected a numeric - got #{r.class}" unless r.is_a?(Numeric)

        n = Topolys::Vector3D.new(s.outwardNormal.x * Math.cos(r) -
                                  s.outwardNormal.y * Math.sin(r), # x
                                  s.outwardNormal.x * Math.sin(r) +
                                  s.outwardNormal.y * Math.cos(r), # y
                                  s.outwardNormal.z)               # z
        return n
      end
    end

    # Returns Topolys vertices and a Topolys wire from Topolys points. As
    # a side effect, it will - if successful - also populate the Topolys
    # model with the vertices and wire.
    def topolysObjects(model, points)
      if model && points
        unless model.is_a?(Topolys::Model)
          raise "Expected Topolys model - got #{model.class}"
        end
        unless points.is_a?(Array)
          raise "Expected array of Topolys points - got a #{points.class}"
        end
        unless points.size > 2
          raise "Expected more than 2 points - got #{points.size}"
        end

        vertices = model.get_vertices(points)
        wire = model.get_wire(vertices)
        return vertices, wire
      end
    end

    # Populates hash of TBD kids, relying on Topolys. As
    # a side effect, it will - if successful - also populate the Topolys
    # model with Topolys vertices, wires, holes.
    def populateTBDkids(model, kids)
      holes = []
      if model && kids
        unless model.is_a?(Topolys::Model)
          raise "Expected Topolys model - got #{model.class}"
        end
        unless kids.is_a?(Hash)
          raise "Expected hash of TBD surafces - got a #{kids.class}"
        end
        kids.each do |id, properties|
          vtx, hole = topolysObjects(model, properties[:points])
          hole.attributes[:id] = id
          hole.attributes[:n] = properties[:n] if properties.has_key?(:n)
          properties[:hole] = hole
          holes << hole
        end
      end
      return holes
    end

    # Populates hash of TBD surfaces, relying on Topolys. As
    # a side effect, it will - if successful - also populate the Topolys
    # model with Topolys vertices, wires, holes & faces.
    def populateTBDdads(model, dads)
      tbd_holes = {}

      if model && dads
        unless model.is_a?(Topolys::Model)
          raise "Expected Topolys model - got #{model.class}"
        end
        unless dads.is_a?(Hash)
          raise "Expected hash of TBD surfaces - got a #{dads.class}"
        end

        dads.each do |id, properties|
          vertices, wire = topolysObjects(model, properties[:points])

          # create surface holes for kids
          holes = []
          if properties.has_key?(:windows)
            holes += populateTBDkids(model, properties[:windows])
          end
          if properties.has_key?(:doors)
            holes += populateTBDkids(model, properties[:doors])
          end
          if properties.has_key?(:skylights)
            holes += populateTBDkids(model, properties[:skylights])
          end

          face = model.get_face(wire, holes)
          raise "Cannot build face for #{id}" if face.nil?

          face.attributes[:id] = id
          face.attributes[:n] = properties[:n] if properties.has_key?(:n)
          properties[:face] = face

          # populate hash of created holes (to return)
          holes.each do |h| tbd_holes[h.attributes[:id]] = h; end
        end
      end
      return tbd_holes
    end

    def tbdSurfaceEdges(surfaces, edges)
      if surfaces
        unless surfaces.is_a?(Hash)
          raise "Expected hash of TBD surfaces - got a #{surfaces.class}"
        end
        unless edges.is_a?(Hash)
          raise "Expected hash of TBD edges - got a #{edges.class}"
        end

        surfaces.each do |id, properties|
          unless properties.has_key?(:face)
            raise "Missing Topolys face for #{id}"
          end
          properties[:face].wires.each do |wire|
            wire.edges.each do |e|
              unless edges.has_key?(e.id)
                edges[e.id] = {length: e.length,
                               v0: e.v0,
                               v1: e.v1,
                               surfaces: {}}
              end
              unless edges[e.id][:surfaces].has_key?(id)
                edges[e.id][:surfaces][id] = {wire: wire.id}
              end
            end
          end
        end
      end
    end

    def deratableLayer(construction)
      # identify insulating material (and key attributes) within a construction
      r                     = 0.0         # R-value of insulating material
      index                 = nil         # index of insulating material
      type                  = nil         # nil, :massless; or :standard
      i                     = 0           # iterator

      construction.layers.each do |m|
        unless m.to_MasslessOpaqueMaterial.empty?
          m                 = m.to_MasslessOpaqueMaterial.get
          next unless         m.thermalResistance > 0.001
          next unless         m.thermalResistance > r
          r                 = m.thermalResistance
          index             = i
          type              = :massless
          i += 1
        end

        unless m.to_StandardOpaqueMaterial.empty?
          m                 = m.to_StandardOpaqueMaterial.get
          k                 = m.thermalConductivity
          d                 = m.thickness
          next unless         d > 0.003
          next unless         k < 3.0
          next unless         d / k > r
          r                 = d / k
          index             = i
          type              = :standard
          i += 1
        end
      end
      return index, type, r
    end

    def derate(os_model, os_surface, id, surface, c, index, type, r)
      m = nil
      if surface.has_key?(:heatloss)                    &&
         surface.has_key?(:net)                         &&
         surface[:heatloss].is_a?(Numeric)              &&
         surface[:net].is_a?(Numeric)                   &&
         id == os_surface.nameString                    &&
         index != nil                                   &&
         index.is_a?(Integer)                           &&
         index >= 0                                     &&
         r.is_a?(Numeric)                               &&
         r >= 0.001                                     &&
         / tbd/i.match(c.nameString) == nil             &&
         (type == :massless || type == :standard)

         # puts c.nameString
         # tbd/i.match(c.nameString) == nil

         u            = surface[:heatloss] / surface[:net]
         loss         = 0.0
         de_u         = 1.0 / r + u                       # derated U
         de_r         = 1.0 / de_u                        # derated R

         if type == :massless
           m          = c.getLayer(index).to_MasslessOpaqueMaterial.get
           m          = m.clone(os_model)
           m          = m.to_MasslessOpaqueMaterial.get
                        m.setName("#{id} #{m.nameString} tbd")

           unless de_r > 0.001
             de_r     = 0.001
             de_u     = 1.0 / de_r
             loss     = (de_u - 1.0 / r) / surface[:net]
           end
           m.setThermalResistance(de_r)

         else # type == :standard
           m          = c.getLayer(index).to_StandardOpaqueMaterial.get
           m          = m.clone(os_model)
           m          = m.to_StandardOpaqueMaterial.get
                        m.setName("#{id} #{m.nameString} tbd")
           k          = m.thermalConductivity
           if de_r > 0.001
             d        = de_r * k
             unless d > 0.003
               d      = 0.003
               k      = d / de_r
               unless k < 3.0
                 k    = 3.0
                 loss = (k / d - 1.0 / r) / surface[:net]
               end
             end

           else              # de_r < 0.001 m2.K/W
             d        = 0.001 * k
             unless d > 0.003
               d      = 0.003
               k      = d / 0.001
             end
             loss     = (k / d - 1.0 / r) / surface[:net]
           end
           m.setThickness(d)
           m.setThermalConductivity(k)
         end

         if m.nil?
           puts "nilled?"
         else
           #puts c.nameString
           #c.setLayer(index, m)
           surface[:r_heatloss] = loss if loss > 0
           #os_surface.setConstruction(c)
           #puts os_surface.construction.get.nameString
         end
       end
       return m
    end

    os_model = OpenStudio::Model::Model.new
    os_g = OpenStudio::Model::Space.new(os_model) # gallery "g" & elevator "e"
    os_g.setName("scrigno_gallery")
    os_p = OpenStudio::Model::Space.new(os_model) # plenum "p" & stairwell "s"
    os_p.setName("scrigno_plenum")
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
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 46.0) #   2.0m
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 44.0) #   1.0m
    os_v << OpenStudio::Point3d.new( 46.4, 40.2, 44.0) #   2.0m
    os_v << OpenStudio::Point3d.new( 46.4, 40.2, 46.0) #   1.0m
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

    # create the Topolys Model
    t_model = Topolys::Model.new

    # Fetch OpenStudio (opaque) surfaces & key attributes
    # puts OpenStudio::Model::Surface::validSurfaceTypeValues
    surfaces = {}
    os_model.getSurfaces.each do |s|
      next if s.space.empty? # TBD ignores orphaned surfaces; log warning?
      space = s.space.get
      id = s.nameString

      # site transformation & rotation
      t, r = transforms(os_model, space)

      # Site-specific (or absolute, or true) surface normal, here only for
      # temporary testing of Topolys equivalence (in absolute coordinates).
      n = trueNormal(s, r)

      type = :floor
      type = :ceiling if /ceiling/i.match(s.surfaceType)
      type = :wall if /wall/i.match(s.surfaceType)

      ground = s.isGroundSurface
      boundary = s.outsideBoundaryCondition

      points = (t * s.vertices).map{ |v| Topolys::Point3D.new(v.x, v.y, v.z) }
      minz = (points.map{ |p| p.z }).min

      # content of the hash will evolve over the next few iterations
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

    # Fetch OpenStudio subsurfaces & key attributes
    # puts OpenStudio::Model::SubSurface::validSubSurfaceTypeValues
    os_model.getSubSurfaces.each do |s|
      next if s.space.empty?    # TBD ignores orphaned subs; log warning?
      next if s.surface.empty?  # TBD ignores orphaned subs; log warning?
      space = s.space.get
      dad = s.surface.get.nameString
      id = s.nameString

      # site transformation & rotation
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

    # Sort kids
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

    # Split "surfaces" hash into "floors", "ceilings" and "walls" hashes
    floors = surfaces.select{ |i, p| p[:type] == :floor }
    floors = floors.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h
    expect(floors.size).to eq(7)

    ceilings = surfaces.select{ |i, p| p[:type] == :ceiling }
    ceilings = ceilings.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h
    expect(ceilings.size).to eq(3)

    walls = surfaces.select{|i, p| p[:type] == :wall }
    walls = walls.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h
    expect(walls.size).to eq(17)

    # Remove ":type" (now redundant)
    surfaces.values.each do |p| p.delete_if { |ii, _| ii == :type }; end

    # Fetch OpenStudio shading surfaces & key attributes
    shades = {}
    os_model.getShadingSurfaces.each do |s|
      next if s.shadingSurfaceGroup.empty? # ignoring orphaned shades ... log?
       group = s.shadingSurfaceGroup.get
       id = s.nameString

       # site transformation & rotation
       t, r = transforms(os_model, group)

       # shading surface groups may also be linked to (rotated) spaces
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

    # start with hole edges
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

    # next, floors, ceilings & walls; then shades
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
    # edge), clockwise as one is looking in the opposite position of the edge
    # vector. For instance, a vertical edge has a reference vector pointing
    # North - surfaces eastward of the edge are (0°,180°], while surfaces
    # westward of the edge are (180°,360°].

    # Much of the following code is of a topological nature, and should ideally
    # (or eventually) become available functionality offered by Topolys.
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

              # generate a plane between origin, terminal & point
              # only consider planes that share the same normal as wire
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

            # adjust angle [180°, 360°] if necessary
            adjust = false

            if vertical
              adjust = true if east.dot(farthest_V) < -0.01
            else
              if north.dot(farthest_V).abs < 0.01 ||
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
    #edges.values.each do |edge|
    #  if edge[:surfaces].size > 1
        #puts "edge of (#{edge[:length]}m) is linked to #{edge[:surfaces].size}:"
    #    edge[:surfaces].each do |i, surface|
          #puts "... #{i} : #{surface[:angle]}"
    #    end
    #  end
    #end
    expect(edges.size).to eq(89)
    expect(t_model.edges.size).to eq(89)

    # Topolys edges may constitute thermal bridges (and therefore thermally
    # derate linked OpenStudio surfaces), depending on a number of factors such
    # as surface types and boundary conditions. Thermal bridging attributes
    # (type & PSI-value pairs) are grouped into PSI sets, normally accessed
    # through the 'set' user-argument (in the OpenStudio Measure interface).
    psi = PSI.new
    psi_set = psi.set["poor (BC Hydro)"]
    #psi_set = psi.set["code (Quebec)"]

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
        # puts surface.keys
        # :wire (unique Topolys string identifier)
        # :angle (0°,360°]

        deratable = true if floors.has_key?(id)
        deratable = true if ceilings.has_key?(id)
        deratable = true if walls.has_key?(id)
      end
      next unless deratable

      psi = {}
      edge[:surfaces].keys.each do |id|
        if surfaces.has_key?(id)

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

        end # edge has surface id as key
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

    # loop through each edge and assign heat loss to linked surfaces
    edges.each do |identifier, edge|
      next unless edge.has_key?(:psi)
      next unless edge[:psi].values.max > 0.01
      bridge = { psi: edge[:psi].values.max,
                 type: edge[:psi].key(psi),
                 length: edge[:length] }

      # retrieve valid linked surfaces as deratables
      deratables = {}
      edge[:surfaces].each do |id, surface|
        next unless surfaces.has_key?(id)
        next unless surfaces[id][:boundary].downcase == "outdoors"
        deratables[id] = surface
      end

      # retrieve linked openings
      openings = {}
      if edge[:psi].has_key?(:fenestration)
        edge[:surfaces].each do |id, surface|
          next unless holes.has_key?(id)
          openings[id] = surface
        end
      end

      next if openings.size > 1 # edge links 2x openings

      # prune if edge links an opening and its parent, as well as 1x other
      # opaque surface (i.e. corner window derates neighbour - not parent)
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

      # split thermal bridge heat loss equally amongst deratable surfaces
      bridge[:psi] /= deratables.size

      # assign heat loss from thermal bridges to surfaces
      deratables.each do |id, deratable|
        surfaces[id][:edges] = {} unless surfaces[id].has_key?(:edges)
        surfaces[id][:edges][identifier] = bridge
      end
    end

    # assign thermal bridging heat loss [in W/K] to each deratable surface
    n_surfaces_to_derate = 0
    surfaces.values.each do |surface|
      next unless surface.has_key?(:edges)
      surface[:heatloss] = 0
      surface[:edges].values.each do |edge|
        surface[:heatloss] += edge[:psi] * edge[:length]
      end
      n_surfaces_to_derate += 1
    end
    expect(n_surfaces_to_derate).to eq(22)

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

    ceiling_c   = defaults.roofCeilingConstruction.get.to_Construction.get
    wall_c      = defaults.wallConstruction.get.to_Construction.get
    floor_c     = defaults.floorConstruction.get.to_Construction.get

    # Derated (cloned) constructions are unique to each deratable surface.
    # Unique construction names are prefixed with the surface name,
    # and suffixed with " tbd", indicating that the construction is
    # henceforth thermally derated.
    floors.each do |id, floor|
      next unless floor.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        if s.isConstructionDefaulted
          construction_name = floor_c.nameString
          c = floor_c.clone(os_model).to_Construction.get
        else
          construction_name = s.construction.get.nameString
          c = s.construction.get.clone(os_model).to_Construction.get
        end
        index, type, r = deratableLayer(c)
        m = derate(os_model, s, id, floor, c, index, type, r)
        unless m.nil?
          c.setLayer(index, m)
          c.setName("#{id} #{construction_name} tbd")
          s.setConstruction(c)
        end
      end
    end

    floors.each do |id, floor|
      next unless floor.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    ceilings.each do |id, ceiling|
      next unless ceiling.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        if s.isConstructionDefaulted
          construction_name = ceiling_c.nameString
          c = ceiling_c.clone(os_model).to_Construction.get
        else
          construction_name = s.construction.get.nameString
          c = s.construction.get.clone(os_model).to_Construction.get
        end
        index, type, r = deratableLayer(c)
        m = derate(os_model, s, id, ceiling, c, index, type, r)
        unless m.nil?
          c.setLayer(index, m)
          c.setName("#{id} #{construction_name} tbd")
          s.setConstruction(c)
        end
      end
    end

    ceilings.each do |id, ceiling|
      next unless ceiling.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        expect(s.isConstructionDefaulted).to be(false)
        expect(/ tbd/i.match(s.construction.get.nameString)).to_not eq(nil)
      end
    end

    walls.each do |id, wall|
      next unless wall.has_key?(:edges)
      os_model.getSurfaces.each do |s|
        next unless id == s.nameString
        if s.isConstructionDefaulted
          construction_name = wall_c.nameString
          c = wall_c.clone(os_model).to_Construction.get
        else
          construction_name = s.construction.get.nameString
          c = s.construction.get.clone(os_model).to_Construction.get
        end
        index, type, r = deratableLayer(c)
        m = derate(os_model, s, id, wall, c, index, type, r)
        unless m.nil?
          c.setLayer(index, m)
          c.setName("#{id} #{construction_name} tbd")
          s.setConstruction(c)
        end
      end
    end

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
