begin
  # try to load from the gems
  require "topolys"
  require "psi"
rescue LoadError
  # load from measure resource dir
  require_relative "resources/psi.rb"
  require_relative "resources/geometry.rb"
  require_relative "resources/model.rb"
  require_relative "resources/transformation.rb"
  require_relative "resources/version.rb"
end

# start the measure
class TBDMeasure < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return "Thermal Bridging & Derating (TBD)"
  end

  # human readable description
  def description
    return "Thermally derates opaque constructions from major thermal bridges"
  end

  # human readable description of modeling approach
  def modeler_description
    return "(see github.com/rd2/tbd)"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new
    psi = PSI.new

    choices = OpenStudio::StringVector.new
    psi.set.keys.each do |k| choices << k.to_s; end
    option = OpenStudio::Measure::OSArgument.makeChoiceArgument("option", choices, true)
    option.setDisplayName("Thermal bridge option")
    option.setDescription("e.g. poor, regular, efficient, code")
    option.setDefaultValue("poor (BC Hydro)")
    args << option

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # assign the user inputs to variables
    option = runner.getStringArgumentValue("option", user_arguments)
    psi = PSI.new
    set = psi.set[option]

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    building = model.getBuilding

    t_model = Topolys::Model.new

    surfaces = {}
    model.getSurfaces.each do |s|
      next if s.space.empty?
      space = s.space.get
      id = s.nameString

      # site transformation & rotation
      t, r = transforms(model, space)
      n = trueNormal(s, r)

      type = :floor
      type = :ceiling if /ceiling/i.match(s.surfaceType)
      type = :wall if /wall/i.match(s.surfaceType)

      ground = s.isGroundSurface
      boundary = s.outsideBoundaryCondition

      points = (t * s.vertices).map{ |v| Topolys::Point3D.new(v.x, v.y, v.z) }
      minz = (points.map{ |p| p.z }).min

      surfaces[id] = {
        type:     type,
        ground:   ground,
        boundary: boundary,
        net:      s.netArea,
        points:   points,
        minz:     minz,
        n:        n
      }
    end # (opaque) surfaces populated

    # Fetch OpenStudio subsurfaces & key attributes
    # puts OpenStudio::Model::SubSurface::validSubSurfaceTypeValues
    model.getSubSurfaces.each do |s|
      next if s.space.empty?
      next if s.surface.empty?
      space = s.space.get
      dad = s.surface.get.nameString
      id = s.nameString

      # site transformation & rotation
      t, r = transforms(model, space)
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

    # Split "surfaces" hash into "floors", "ceilings" and "walls" hashes
    floors = surfaces.select{ |i, p| p[:type] == :floor }
    floors = floors.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h

    ceilings = surfaces.select{ |i, p| p[:type] == :ceiling }
    ceilings = ceilings.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h

    walls = surfaces.select{|i, p| p[:type] == :wall }
    walls = walls.sort_by{ |i, p| [p[:minz], p[:space]] }.to_h

    # Remove ":type" (now redundant)
    surfaces.values.each do |p| p.delete_if { |ii, _| ii == :type }; end

    # Fetch OpenStudio shading surfaces & key attributes
    shades = {}
    model.getShadingSurfaces.each do |s|
      next if s.shadingSurfaceGroup.empty?
       group = s.shadingSurfaceGroup.get
       id = s.nameString

       # site transformation & rotation
       t, r = transforms(model, group)

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

    # Mutually populate TBD & Topolys surfaces. Keep track of created "holes".
    holes = {}
    floor_holes = populateTBDdads(t_model, floors)
    ceiling_holes = populateTBDdads(t_model, ceilings)
    wall_holes = populateTBDdads(t_model, walls)

    holes.merge!(floor_holes)
    holes.merge!(ceiling_holes)
    holes.merge!(wall_holes)

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

    # next, floors, ceilings & walls; then shades
    tbdSurfaceEdges(floors, edges)
    tbdSurfaceEdges(ceilings, edges)
    tbdSurfaceEdges(walls, edges)
    tbdSurfaceEdges(shades, edges)

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

    # Topolys edges may constitute thermal bridges (and therefore thermally
    # derate linked OpenStudio surfaces), depending on a number of factors such
    # as surface types and boundary conditions. Thermal bridging attributes
    # (type & PSI-value pairs) are grouped into PSI sets, normally accessed
    # through the 'set' user-argument (in the OpenStudio Measure interface).
    psi = PSI.new
    psi_set = psi.set["poor (BC Hydro)"]
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

    # loop through each edge and assign heat loss to linked surfaces
    edges.each do |identifier, edge|
      next unless edge.has_key?(:psi)
      psi = edge[:psi].values.max
      next unless psi > 0.01
      bridge = { psi: psi,
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
    surfaces.values.each do |surface|
      next unless surface.has_key?(:edges)
      surface[:heatloss] = 0
      surface[:edges].values.each do |edge|
        surface[:heatloss] += edge[:psi] * edge[:length]
      end
    end

    # Derated (cloned) constructions are unique to each deratable surface.
    # Unique construction names are prefixed with the surface name,
    # and suffixed with " tbd", indicating that the construction is
    # henceforth thermally derated. The " tbd" expression is also key in
    # avoiding inadvertent derating - TBD will not derate constructions
    # (or rather materials) having " tbd" in its OpenStudio name.

    surfaces.each do |id, surface|
      next unless surface.has_key?(:edges)
      model.getSurfaces.each do |s|
        next unless id == s.nameString

        # Retrieve current surface construction
        current_c = nil
        if s.isConstructionDefaulted
          # check for building default set
          building_default_set = building.defaultConstructionSet
          unless building_default_set.empty?
            building_default_set = building_default_set.get
            current_c = building_default_set.getDefaultConstruction(s)
            next if current_c.empty?
            current_c = current_c.get
          else
            # no building-specific defaults - resort to first set @model level
            model_default_sets = model.getDefaultConstructionSets
            next if model_default_sets.empty?
            model_default_set = model_default_sets.first
            current_c = model_default_set.getDefaultConstruction(s)
            next if current_c.empty?
            current_c = current_c.get
          end # no defaults - surface-specific construction
          construction_name = current_c.nameString
          c = current_c.clone(model).to_Construction.get
        else
          current_c = s.construction.get
          construction_name = current_c.nameString
          c = current_c.clone(model).to_Construction.get
        end

        # index - of layer/material (to derate) in cloned construction
        # type  - either massless (RSi) or standard (k + d)
        # r     - initial RSi value of the targeted layer to derate
        index, type, r = deratableLayer(c)
        unless index.is_a?(Numeric) && index >=0 && index < c.layers.size
          raise "#{id} layer failure : index: #{index}"
        end

        # m     - newly derated, cloned material
        m = derate(model, s, id, surface, c, index, type, r)
        unless m.nil?

          c.setLayer(index, m)
          c.setName("#{id} #{construction_name} tbd")

          # compute current RSi value from layers
          current_R = s.filmResistance
          current_c.to_Construction.get.layers.each do |l|
            r = 0
            unless l.to_MasslessOpaqueMaterial.empty?
              l                 = l.to_MasslessOpaqueMaterial.get
              r                 = l.thermalResistance
            end

            unless l.to_StandardOpaqueMaterial.empty?
              l                 = l.to_StandardOpaqueMaterial.get
              k                 = l.thermalConductivity
              d                 = l.thickness
              r                 = d / k
            end
            current_R += r
          end

          s.setConstruction(c)

          # compute updated RSi value from layers
          updated_R = s.filmResistance
          updated_c = s.construction.get
          updated_c.to_Construction.get.layers.each do |l|
            r = 0
            unless l.to_MasslessOpaqueMaterial.empty?
              l = l.to_MasslessOpaqueMaterial.get
              r = l.thermalResistance
            end

            unless l.to_StandardOpaqueMaterial.empty?
              l = l.to_StandardOpaqueMaterial.get
              k = l.thermalConductivity
              d = l.thickness
              r = d / k
            end
            updated_R += r
          end

          ratio  = -(current_R - updated_R) * 100 / current_R
          ratio  = format "%3.1f", ratio
          name   = s.nameString.rjust(15, " ")
          output = "#{name} RSi derated by #{ratio}%"
          runner.registerInfo(output)
        end
      end
    end

    return true
  end
end

# register the measure to be used by the application
TBDMeasure.new.registerWithApplication
