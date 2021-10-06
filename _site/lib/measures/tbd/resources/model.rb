begin
  require "topolys/version"
rescue LoadError
  require File.join(File.dirname(__FILE__), 'version.rb')
end

require 'json'
require 'securerandom'
require 'set'

# Topology represents connections between geometry in a model.
#
# Class structure inspired from Topologic's RCH (Rigorous Class Hierarchy)
#               (excerpts from https://topologic.app/Software/)
# Topology:     Abstract superclass holding constructors, properties and
#               methods used by other subclasses that extend it.
# Vertex:       1D entity equivalent to a geometry point.
# Edge:         1D entity defined by two vertices.
# Wire:         Contiguous collection of Edges where adjacent Edges are
#               connected by shared Vertices.
# Face:         2D region defined by a collection of closed Wires.
# Shell:        Contiguous collection of Faces, where adjacent Faces are
#               connected by shared Edges.
# Cell:         3D region defined by a collection of closed Shells.
# CellComplex:  Contiguous collection of Cells where adjacent Cells are
#               connected by shared Faces.
# Cluster:      Collection of any topologic entities.

# TODO : start integrating warning logs à la raise ...
module Topolys

  @@normal_tol = 0.000001
  @@planar_tol = 0.01

  ## Tolerance for normal vector checks
  def Topolys.normal_tol
    @@normal_tol
  end

  ## Tolerance for planarity checks
  def Topolys.planar_tol
    @@planar_tol
  end

  ##
  # Checks if one array of objects is the same as another array of objects.
  # The order of objects must be the same but the two arrays may start at different indices.
  #
  # @param [Array] objects1 Array
  # @param [Array] objects2 Array
  #
  # @return [Integer] Returns offset between objects2 and objects1 or nil
  def Topolys.find_offset(objects1, objects2)

    n = objects1.size
    return nil if objects2.size != n

    offset = objects2.index{|obj| objects1[0].id == obj.id}
    return nil if !offset

    objects1.each_index do |i|
      return nil if objects1[i].id != objects2[(offset+i)%n].id
    end

    return offset
  end

  # The Topolys Model contains many Topolys Objects, a Topolys Object can only be
  # connected to other Topolys Objects in the same Topolys Model.  To enforce this
  # Topolys Objects should not be constructed directly, they should be retrieved using
  # the Topolys Model get_* object methods.
  class Model
    attr_reader :vertices, :edges, :directed_edges, :wires, :faces, :shells, :cells
    attr_reader :tol, :tol2

    def initialize(tol=nil)

      # changing tolerance on a model after construction would be very complicated
      # you would have to go through and regroup points, etc
      if !tol.is_a?(Numeric)
        tol = 0.01
      end
      @tol = tol
      @tol2 = @tol**2

      @vertices = []
      @edges = []
      @directed_edges = []
      @wires = []
      @faces = []
      @shells = []
      @cells = []
    end

    def all_objects
      @vertices + @edges + @directed_edges + @wires + @faces + @shells + @cells
    end

    def to_json
      result= {
        vertices: @vertices.map { |v| v.to_json },
        edges: @edges.map { |e| e.to_json },
        directed_edges: @directed_edges.map { |de| de.to_json },
        wires: @wires.map { |w| w.to_json },
        faces: @faces.map { |f| f.to_json },
        shells: @shells.map { |s| s.to_json },
        cells: @cells.map { |c| c.to_json }
      }
      return result
    end

    def self.from_json(obj)
      model = Model.new
      id_map = {}

      obj[:vertices].each do |v|
        p = v[:point]
        point = Point3D.new(p[:x], p[:y], p[:z])
        vertex = model.get_vertex(point)
        set_id(vertex, v[:id])
        vertex.attributes = v[:attributes] if v[:attributes]
        id_map[v[:id]] = vertex
      end

      obj[:edges].each do |e|
        v0 = id_map[e[:v0]]
        v1 = id_map[e[:v1]]
        edge = model.get_edge(v0, v1)
        set_id(edge, e[:id])
        edge.attributes = e[:attributes] if e[:attributes]
        id_map[e[:id]] = edge
      end

      obj[:directed_edges].each do |de|
        edge = id_map[de[:edge]]
        inverted = de[:inverted]
        directed_edge = nil
        if inverted
          directed_edge = model.get_directed_edge(edge.v1, edge.v0)
        else
          directed_edge = model.get_directed_edge(edge.v0, edge.v1)
        end
        set_id(directed_edge, de[:id])
        directed_edge.attributes = de[:attributes] if de[:attributes]
        id_map[de[:id]] = directed_edge
      end

      obj[:wires].each do |w|
        vertices = []
        w[:directed_edges].each do |id|
          directed_edge = id_map[id]
          vertices << directed_edge.v0
        end
        wire = model.get_wire(vertices)
        set_id(wire, w[:id])
        wire.attributes = w[:attributes] if w[:attributes]
        id_map[w[:id]] = wire
      end

      obj[:faces].each do |f|
        outer = id_map[f[:outer]]
        holes = []
        f[:holes].each do |id|
          holes << id_map[id]
        end
        face = model.get_face(outer, holes)
        set_id(face, f[:id])
        face.attributes = f[:attributes] if f[:attributes]
        id_map[f[:id]] = face
      end

      obj[:shells].each do |s|
        faces = []
        s[:faces].each do |id|
          faces << id_map[id]
        end
        shell = model.get_shell(faces)
        set_id(shell, s[:id])
        shell.attributes = s[:attributes] if s[:attributes]
        id_map[s[:id]] = shell
      end

      return model
    end

    def self.schema_file
      return File.join(File.dirname(__FILE__), "./schema/topolys.json")
    end

    def self.schema
      s = File.read(schema_file)
      return JSON.parse(s)
    end

    def to_s
      JSON.pretty_generate(to_json)
    end

    def save(file)
      File.open(file, 'w') do |file|
        file.puts self.to_s
      end
    end

    def to_graphviz
      result = "digraph model {\n"
      result += "  rankdir=LR\n"
      all_objects.each do |obj|
        obj.children.each { |child| result += "  #{child.short_name} -> #{obj.short_name}\n" }
        #obj.parents.each { |parent| result += "  #{parent.short_name} -> #{obj.short_name}\n" }
      end
      result += " }"

      return result
    end

    def save_graphviz(file)
      File.open(file, 'w') do |file|
        file.puts to_graphviz
      end
    end

    # @param [Vertex] vertex
    # @param [Edge] edge
    # @return [Point3D] Point3D of vertex projected on edge or nil
    def vertex_intersect_edge(vertex, edge)
      if vertex.id == edge.v0.id || vertex.id == edge.v1.id
        return nil
      end

      new_point, length = project_point_on_edge(edge.v0.point, edge.v1.point, vertex.point)

      return new_point
    end

    # @param [Point3D] point
    # @return [Vertex] Vertex
    def get_vertex(point)
      # search for point and return corresponding vertex if it exists
      v = find_existing_vertex(point)
      return v if v

      # otherwise create new vertex
      v = Vertex.new(point)
      @vertices << v

      # check if this vertex needs to be inserted on any edge
      updated = false
      @edges.each do |edge|
        if new_point = vertex_intersect_edge(v, edge)

          # point might need to be added to multiple edges
          # point can be updated to project it onto edge, don't update multiple times
          if !updated
            # simulate friend access to set point on vertex
            v.instance_variable_set(:@point, new_point)
            v.recalculate
            updated = true
          end

          # now split the edge with this vertex
          split_edge(edge, v)
        end
      end

      return v
    end

    # @param [Point3D] point
    # @return [Vertex] Vertex or nil
    def find_existing_vertex(point)
      # search for point and return corresponding vertex if it exists
      # otherwise create new vertex
      @vertices.each do |v|
        p = v.point

        ## L1 norm
        #if ((p.x-point.x).abs < @tol) &&
        #    (p.y-point.y).abs < @tol) &&
        #    (p.z-point.z).abs < @tol))
        #  return v
        #end

        # L2 norm
        if ((p.x-point.x)**2 + (p.y-point.y)**2 + (p.z-point.z)**2) < @tol2
          return v
        end
      end

      return nil
    end

    # @param [Array] points Array of Point3D
    # @return [Array] Array of Vertex
    def get_vertices(points)
      points.map {|p| get_vertex(p)}
    end

    # @param [Vertex] v0
    # @param [Vertex] v1
    # @return [Edge] Edge
    def get_edge(v0, v1)
      # search for edge and return if it exists
      e = find_existing_edge(v0, v1)
      return e if e

      # otherwise create new edge
      @vertices << v0 if !@vertices.find {|v| v.id == v0.id}
      @vertices << v1 if !@vertices.find {|v| v.id == v1.id}

      edge = Edge.new(v0, v1)
      @edges << edge
      return edge
    end

    # @param [Vertex] v0
    # @param [Vertex] v1
    # @return [Edge] Edge or nil
    def find_existing_edge(v0, v1)
      @edges.each do |e|
        if (e.v0.id == v0.id) && (e.v1.id == v1.id)
          return e
        elsif (e.v0.id == v1.id) && (e.v1.id == v0.id)
          return e
        end
      end
      return nil
    end

    # @param [Vertex] v0
    # @param [Vertex] v1
    # @return [DirectedEdge] DirectedEdge
    def get_directed_edge(v0, v1)
      # search for directed edge and return if it exists
      de = find_existing_directed_edge(v0, v1)
      return de if de

      # otherwise create new directed edge
      edge = get_edge(v0, v1)

      inverted = false
      if (edge.v0.id != v0.id)
        inverted = true
      end

      directed_edge = DirectedEdge.new(edge, inverted)
      @directed_edges << directed_edge
      return directed_edge
    end

    # @param [Vertex] v0
    # @param [Vertex] v1
    # @return [DirectedEdge] DirectedEdge
    def find_existing_directed_edge(v0, v1)
      # search for directed edge and return if it exists
      @directed_edges.each do |de|
        if (de.v0.id == v0.id) && (de.v1.id == v1.id)
          return de
        end
      end
      return nil
    end

    # @param [Array] vertices Array of Vertex, assumes closed wire (e.g. first vertex is also last vertex)
    # @return [Wire] Wire
    def get_wire(vertices)
      # search for wire and return if exists
      # otherwise create new wire

      # insert any existing model vertices that should be inserted on the edges in vertices
      vertices = insert_vertices_on_edges(vertices)

      n = vertices.size
      directed_edges = []
      vertices.each_index do |i|
        directed_edges << get_directed_edge(vertices[i], vertices[(i+1)%n])
      end

      # see if we already have this wire
      @wires.each do |wire|
        if wire.circular_equal?(directed_edges)
          return wire
        end
      end

      wire = nil
      begin
        wire = Wire.new(directed_edges)
        @wires << wire
      rescue => exception
        puts exception
      end

      return wire
    end

    # @param [Wire] outer Outer wire
    # @param [Array] holes Array of Wire
    # @return [Face] Face Returns Face or nil if wires are not in model
    def get_face(outer, holes)
      # search for face and return if exists
      # otherwise create new face

      hole_ids = holes.map{|h| h.id}.sort
      @faces.each do |face|
        if face.outer.id == outer.id
          if face.holes.map{|h| h.id}.sort == hole_ids
            return face
          end
        end
      end

      # all the wires have to be in the model
      return nil if @wires.index{|w| w.id == outer.id}.nil?
      holes.each do |hole|
        return nil if @wires.index{|w| w.id == outer.id}.nil?
      end

      face = nil
      begin
        face = Face.new(outer, holes)
        @faces << face
      rescue => exception
        puts exception
      end

      return face
    end

    # @param [Array] faces Array of Face
    # @return [Shell] Returns Shell or nil if faces are not in model or not connected
    def get_shell(faces)

      # all the faces have to be in the model
      faces.each do |face|
        return nil if @faces.index{|f| f.id == face.id}.nil?
      end

      # check if we already have this shell
      face_ids = faces.map{|f| f.id}.sort
      @shells.each do |shell|
        if shell.faces.map{|f| f.id}.sort == face_ids
          return shell
        end
      end

      # create a new shell
      shell = nil
      begin
        shell = Shell.new(faces)
        @shells << shell
      rescue => exception
        puts exception
      end

      return shell
    end

    # @param [Object] object Object
    # @return [Object] Returns reversed object
    def get_reverse(object)
      if object.is_a?(Vertex)
        return object
      elsif object.is_a?(Edge)
        return object
      elsif object.is_a?(DirectedEdge)
        return get_directed_edge(object.v1, object.v0)
      elsif object.is_a?(Wire)
        return get_wire(object.vertices.reverse)
      elsif object.is_a?(Face)
        reverse_outer = get_wire(object.outer.vertices.reverse)
        reverse_holes = []
        object.holes.each do |hole|
          reverse_holes << get_wire(hole.vertices.reverse)
        end
        return get_face(reverse_outer, reverse_holes)
      elsif object.is_a?(Shell)
        # can't reverse a shell
        return nil
      end

      return nil
    end

    private

    ##
    # Set id on an object, used in deserialization
    #
    # @param [Object] obj Object to modify
    # @param [String] id New id
    def self.set_id(obj, id)
      # simulate friend access to set id on object
      obj.instance_variable_set(:@id, id)
    end

    ##
    # Inserts existing model vertices that should be included in vertices
    #
    # @param [Array] Array of original vertices
    # @return [Array] Array with inserted model vertices
    def insert_vertices_on_edges(vertices)

      bb = BoundingBox.new
      ids = ::Set.new
      vertices.each do |vertex|
        bb.add_point(vertex.point)
        ids.add(vertex.id)
      end

      # find vertices that might be inserted
      vertices_to_check = []
      @vertices.each do |vertex|
        next if ids.include?(vertex.id)

        if bb.include?(vertex.point)
          vertices_to_check << vertex
        end
      end

      # temporarily close vertices
      vertices << vertices[0]

      # check if any vertices need to be inserted on this edge
      new_vertices = []
      (0...vertices.size-1).each do |i|
        v_this = vertices[i]
        v_next = vertices[i+1]

        new_vertices << v_this

        vertices_to_add = []
        vertices_to_check.each do |vertex|
          new_point, length = project_point_on_edge(v_this.point, v_next.point, vertex.point)
          if new_point
            vertices_to_add << {vertex: vertex, new_point: new_point, length: length}
          end
        end

        vertices_to_add.sort! { |x, y| x[:length] <=> y[:length] }

        vertices_to_add.each { |vs| new_vertices << vs[:vertex] }
      end

      new_vertices << vertices[-1]

      # pop the last vertex
      vertices.pop
      new_vertices.pop

      # DLM: it's possible that inserting the vertices on the edge would make the face non-planar
      # but if we move the vertices that could break other surfaces

      #if vertices.size != new_vertices.size
      #  puts "old vertices"
      #  puts vertices.map {|v| v.point.to_s }
      #  puts "new vertices"
      #  puts new_vertices.map {|v| v.point.to_s }
      #end

      return new_vertices
    end

    # @param [Point3D] p0 Point3D at beginning of edge
    # @param [Point3D] p1 Point3D at end of edge
    # @param [Point3D] p Point3D to project onto edge
    # @return [Point3D] new point projected onto edge or nil
    # @return [Numeric] length of new point projected along edge or nil
    def project_point_on_edge(p0, p1, p)
      vector1 = (p1 - p0)
      edge_length = vector1.magnitude
      vector1.normalize!

      vector2 = (p - p0)

      length = vector1.dot(vector2)
      if length < 0 || length > edge_length
        return nil, nil
      end

      new_point = p0 + (vector1*length)

      distance = (p - new_point).magnitude
      if distance > @tol
        return nil, nil
      end

      return new_point, length
    end

    ##
    # Adds new vertex between edges's v0 and v1, edge now goes from
    # v0 to new vertex and a new_edge goes from new vertex to v1.
    # Updates directed edges which reference edge.
    #
    # @param [Edge] edge Edge to modify
    # @param [Vertex] new_vertex Vertex to add
    def split_edge(edge, new_vertex)
      v1 = edge.v1

      # simulate friend access to set v1 on edge
      edge.instance_variable_set(:@v1, new_vertex)
      edge.recalculate

      # make a new edge
      new_edge = get_edge(new_vertex, v1)

      # update the directed edges referencing this edge
      parents = edge.parents.dup
      parents.each do |directed_edge|
        split_directed_edge(directed_edge, new_edge)
      end
    end

    ##
    # Creates a new directed edge in same direction for the new edge.
    # Updates wires which reference directed edge.
    #
    # @param [DirectedEdge] directed_edge Existing directed edge
    # @param [Edge] new_edge New edge
    def split_directed_edge(directed_edge, new_edge)

      # directed edge is pointing to the new updated edge
      directed_edge.recalculate

      # make a new directed edge for the new edge
      offset = nil
      new_directed_edge = nil
      if directed_edge.inverted
        offset = 0
        new_directed_edge = get_directed_edge(new_edge.v1, new_edge.v0)
      else
        offset = 1
        new_directed_edge = get_directed_edge(new_edge.v0, new_edge.v1)
      end

      # update the wires referencing this directed edge
      parents = directed_edge.parents.dup
      parents.each do |wire|
        split_wire(wire, directed_edge, offset, new_directed_edge)
      end
    end

    ##
    # Inserts new directed edge after directed edge in wire
    #
    # @param [Wire] wire Existing wire
    # @param [DirectedEdge] directed_edge Existing directed edge
    # @param [Integer] offset 0 to insert new_directed_edge edge before directed_edge, 1 to insert after
    # @param [DirectedEdge] directed_edge New directed edge to insert
    def split_wire(wire, directed_edge, offset, new_directed_edge)

      directed_edges = wire.directed_edges

      index = directed_edges.index{|de| de.id == directed_edge.id}
      return nil if !index

      directed_edges.insert(index + offset, new_directed_edge)

      # simulate friend access to set directed_edges on wire
      wire.instance_variable_set(:@directed_edges, directed_edges)
      wire.recalculate

      # no need to update faces referencing this wire
    end

  end # Model

  class Object

    # @return [-] attribute linked to a pre-speficied key (e.g. keyword)
    attr_accessor :attributes  # a [k,v] hash of properties required by a parent
                               # app, but of no intrinsic utility to Topolys.
                               # e.g. a thermal bridge PSI type
                               #      "attribute[:bridge] = :balcony
                               # e.g. air leakage crack type (ASHRAE Fund's)
                               #      "attribute[:crack] = :sliding
                               # e.g. LCA $ element type
                               #      "attribute[$lca] = :parapet"

    # @return [String] Unique string id
    attr_reader :id

    # @return [Array] Array of parent Objects
    attr_reader :parents

    # @return [Array] Array of child Objects
    attr_reader :children

    ##
    # Initialize the object with read only attributes.
    # If read only attributes are changed externally, must call recalculate.
    #
    def initialize
      @attributes = {}
      @id = SecureRandom.uuid
      @parents = []
      @children = []
    end

    ##
    # Must be called when read only attributes are updated externally.
    # Recalculates cached attribute values and links children with parents.
    # Throws if a class invariant is violated.
    #
    def recalculate
    end

    # @return [String] Unique string id
    def hash
      @id
    end

    # @return [Hash] Hash containing JSON serialized fields
    def to_json
      result = { id: @id}
      result[:attributes] = @attributes if !@attributes.empty?
      return result
    end

    # @return [String] Short id used for Graphviz
    def short_id
      @id.slice(0,6)
    end

    # @return [String] Short name used for Graphviz
    def short_name
      "#{self.class.to_s.gsub('Topolys::','').gsub('DirectedEdge', 'DEdge')}_#{short_id}"
    end

    # @return [String] To string
    def to_s
      short_name
    end

    def debug(str)
      #puts "#{str}#{self.class} #{short_id} has [#{@parents.map{|p| p.short_id}.join(', ')}] parents and [#{@children.map{|c| c.short_id}.join(', ')}] children"
    end

    # @return [Class] Class of Parent objects
    def parent_class
      NilClass
    end

    # @return [Class] Class of Child objects
    def child_class
      NilClass
    end

    ##
    # Links a parent with a child object
    #
    # @param [Object] parent A parent object to link
    # @param [Object] child A child object to link
    def Object.link(parent, child)
      child.link_parent(parent)
      parent.link_child(child)
    end

    ##
    # Unlinks a parent from a child object
    #
    # @param [Object] parent A parent object to unlink
    # @param [Object] child A child object to unlink
    def Object.unlink(parent, child)
      child.unlink_parent(parent)
      parent.unlink_child(child)
    end

    ##
    # Links a parent object
    #
    # @param [Object] object A parent object to link
    def link_parent(object)
      #puts "link parent #{object.short_id} with child #{self.short_id}"
      if object && object.is_a?(parent_class)
        @parents << object if !@parents.find {|obj| obj.id == object.id }
      end
    end

    ##
    # Unlinks a parent object
    #
    # @param [Object] object A parent object to unlink
    def unlink_parent(object)
      #puts "unlink parent #{object.short_id} from child #{self.short_id}"
      @parents.reject!{ |obj| obj.id == object.id }
    end

    ##
    # Links a child object
    #
    # @param [Object] object A child object to link
    def link_child(object)
      #puts "link child #{object.short_id} with parent #{self.short_id}"
      if object && object.is_a?(child_class)
        @children << object if !@children.find {|obj| obj.id == object.id }
      end
    end

    ##
    # Unlinks a child object
    #
    # @param [Object] object A child object to unlink
    def unlink_child(object)
      #puts "unlink child #{object.short_id} from parent #{self.short_id}"
      @children.reject!{ |obj| obj.id == object.id }
    end

  end # Object

  class Vertex < Object

    # @return [Point3D] Point3D geometry
    attr_reader :point

    ##
    # Initializes a Vertex object, use Model.get_point instead
    #
    # Throws if point is incorrect type
    #
    # @param [Point3D] point
    def initialize(point)
      super()
      @point = point

      recalculate
    end

    def to_json
      result = super
      result[:point] = { x: @point.x, y: @point.y, z: @point.z }
      return result
    end

    def recalculate
      super()
    end

    def parent_class
      Edge
    end

    def child_class
      NilClass
    end

    def edges
      @parents
    end

  end # Vertex

  class Edge < Object

    # @return [Vertex] the initial vertex, the edge origin
    attr_reader :v0

    # @return [Vertex] the second vertex, the edge terminal point
    attr_reader :v1

    # @return [Numeric] the length of this edge
    attr_reader :length
    alias magnitude length

    ##
    # Initializes an Edge object, use Model.get_edge instead
    #
    # Throws if v0 or v1 are incorrect type or refer to same vertex
    #
    # @param [Vertex] v0 The origin Vertex
    # @param [Vertex] v1 The terminal Vertex
    def initialize(v0, v1)
      super()
      @v0 = v0
      @v1 = v1

      recalculate
    end

    def to_json
      result = super
      result[:v0] = @v0.id
      result[:v1] = @v1.id
      return result
    end

    def recalculate
      super()

      # TODO: should catch if 'origin' or 'terminal' are not Vertex objects
      # TODO: should also catch if 'origin' or 'terminal' refer to same object or are within tol of each other

      debug("before: ")

      # unlink from any previous vertices
      @children.reverse_each {|child| Object.unlink(self, child)}

      # link to current vertices
      Object.link(self, @v0)
      Object.link(self, @v1)

      debug("after: ")

      # recompute cached properties and check invariants
      vector = @v1.point - @v0.point
      @length = vector.magnitude
    end

    def parent_class
      DirectedEdge
    end

    def child_class
      Vertex
    end

    def forward_edge
      @parents.first{|de| !de.inverted}
    end

    def reverse_edge
      @parents.first{|de| de.inverted}
    end

    def directed_edges
      @parents
    end

    def vertices
      @children
    end

  end # Edge

  class DirectedEdge < Object

    # @return [Vertex] the initial vertex, the directed edge origin
    attr_reader :v0

    # @return [Vertex] the second vertex, the directed edge terminal point
    attr_reader :v1

    # @return [Edge] the edge this directed edge points to
    attr_reader :edge

    # @return [Boolean] true if this is a forward directed edge, false otherwise
    attr_reader :inverted

    # @return [Numeric] the length of this edge
    attr_reader :length

    # @return [Vector3D] the vector of this directed edge
    attr_reader :vector

    ##
    # Initializes a DirectedEdge object, use Model.get_directed_edge instead
    #
    # Throws if edge or inverted are incorrect type
    #
    # @param [Edge] edge The underlying edge
    # @param [Boolean] inverted True if this is a forward DirectedEdge, false otherwise
    def initialize(edge, inverted)
      super()
      @edge = edge
      @inverted = inverted

      recalculate
    end

    def to_json
      result = super
      result[:edge] = @edge.id
      result[:inverted] = @inverted
      return result
    end

    def recalculate
      super()

      debug("before: ")

      # unlink from any previous edges
      @children.reverse_each {|child| Object.unlink(self, child)}

      # link with current edge
      Object.link(self, @edge)

      debug("after: ")

      # recompute cached properties and check invariants
      if @inverted
        @v0 = edge.v1
        @v1 = edge.v0
      else
        @v0 = edge.v0
        @v1 = edge.v1
      end

      @vector = @v1.point - @v0.point
      @length = @vector.magnitude
    end

    def parent_class
      Wire
    end

    def child_class
      Edge
    end

    def wires
      @parents
    end

    def edges
      @children
    end

  end # DirectedEdge

  class Wire < Object

    # @return [Array] array of directed edges
    attr_reader :directed_edges

    # @return [Plane3D] plane of this wire
    attr_reader :plane

    # @return [Vector3D] outward normal of this wire's plane
    attr_reader :normal

    ##
    # Initializes a Wire object
    #
    # Throws if directed_edges is incorrect type or if not sequential, not planar, or not closed
    #
    # @param [Edge] edge The underlying edge
    # @param [Boolean] inverted True if this is a forward DirectedEdge, false otherwise
    def initialize(directed_edges)
      super()
      @directed_edges = directed_edges

      recalculate
    end

    def to_json
      result = super
      result[:directed_edges] = @directed_edges.map { |de| de.id }
      return result
    end

    def recalculate
      super()

      # unlink from any previous directed edges
      @children.reverse_each {|child| Object.unlink(self, child)}

      # link with current directed edges
      @directed_edges.each {|de| Object.link(self, de)}

      # recompute cached properties and check invariants

      raise "Empty edges" if @directed_edges.empty?
      raise "Not sequential" if !sequential?
      raise "Not closed" if !closed?

      @normal = nil
      largest = 0
      (0...@directed_edges.size-1).each do |i|
        temp = @directed_edges[i].vector.cross(@directed_edges[i+1].vector)
        if temp.magnitude > largest
          largest = temp.magnitude
          @normal = temp
        end
      end

      raise "Cannot compute normal" if @normal.nil?
      raise "Normal has 0 length" if largest == 0

      @normal.normalize!

      @plane = Topolys::Plane3D.new(@directed_edges[0].v0.point, @normal)

      @directed_edges.each do |de|
        raise "Point not on plane" if (de.v0.point - @plane.project(de.v0.point)).magnitude > Topolys.planar_tol
        raise "Point not on plane" if (de.v1.point - @plane.project(de.v1.point)).magnitude > Topolys.planar_tol
      end
    end

    def parent_class
      Face
    end

    def child_class
      DirectedEdge
    end

    def faces
      @parents
    end

    ##
    # @return [Array] Array of Edge
    def edges
      @directed_edges.map {|de| de.edge}
    end

    ##
    # @return [Array] Array of Vertex
    def vertices
      @directed_edges.map {|de| de.v0}
    end

    ##
    # @return [Array] Array of Point3D
    def points
      vertices.map {|v| v.point}
    end

    ##
    # Validates if directed edges are sequential
    #
    # @return [Bool] Returns true if sequential
    def sequential?
      n = @directed_edges.size
      @directed_edges.each_index do |i|
        break if i == n-1

        # e.g. check if first edge v0 == last edge v
        #      check if each intermediate, nieghbouring v0 & v are equal
        #      e.g. by relying on 'inverted?'
        #      'answer = true' if all checks out
        return false if @directed_edges[i].v1.id != @directed_edges[i+1].v0.id
      end
      return true
    end

    ##
    # Validates if directed edges are closed
    #
    # @return [Bool] Returns true if closed
    def closed?
      n = @directed_edges.size
      return false if n < 3
      return @directed_edges[n-1].v1.id == @directed_edges[0].v0.id
    end

    ##
    # Checks if this Wire's directed edges are the same as another array of directed edges.
    # The order of directed edges must be the same but the two arrays may start at different indices.
    #
    # @param [Array] directed_edges Array of DirectedEdge
    #
    # @return [Bool] Returns true if the wires are circular_equal, false otherwise
    def circular_equal?(directed_edges)

      if !Topolys::find_offset(@directed_edges, directed_edges).nil?
        return true
      end

      return false
    end

    ##
    # Checks if this Wire is reverse equal to another Wire.
    # The order of directed edges must be the same but the two arrays may start at different indices.
    #
    # @param [Wire] other Other Wire
    #
    # @return [Bool] Returns true if the wires are reverse_equal, false otherwise
    def reverse_equal?(other)
      # TODO: implement
      return false
    end

    # TODO : deleting an edge, inserting a sequential edge, etc.

    ##
    # Gets 3D wire perimeter length
    #
    # @return [Float] Returns perimeter of 3D wire
    def perimeter
      @directed_edges.inject(0){|sum, de| sum + de.length }
    end

    ##
    # Gets shared edges with another wire
    #
    # @return [Array] Returns array of shared edges
    def shared_edges(other)
      return nil unless other.is_a?(Wire)

      result = []
      @directed_edges.each do |de|
        other.directed_edges.each do |other_de|
          result << de.edge if de.edge.id == other_de.edge.id
        end
      end

      return result
    end

  end # Wire

  class Face < Object

    # @return [Wire] outer polygon
    attr_reader :outer

    # @return [Array] Array of Wire
    attr_reader :holes

    ##
    # Initializes a Face object
    #
    # Throws if outer or holes are incorrect type or if holes have incorrect winding
    #
    # @param [Wire] outer The outer boundary
    # @param [Array] holes Array of inner wires
    def initialize(outer, holes)
      super()
      @outer = outer
      @holes = holes

      recalculate
    end

    def to_json
      result = super
      result[:outer] = @outer.id
      result[:holes] = @holes.map { |h| h.id }
      return result
    end

    def recalculate
      super()

      # unlink from any previous wires
      @children.reverse_each {|child| Object.unlink(self, child)}

      # link with current wires
      Object.link(self, outer)
      @holes.each {|hole| Object.link(self, hole)}

      # recompute cached properties and check invariants

      # check that holes have same normal as outer
      normal = @outer.normal
      @holes.each do |hole|
        raise "Hole does not have correct winding, #{hole.normal.dot(normal)}" if hole.normal.dot(normal) < 1 - Topolys.normal_tol
      end

      # check that holes are on same plane as outer
      plane = @outer.plane
      @holes.each do |hole|
        hole.points.each do |point|
          raise "Point not on plane" if (point - plane.project(point)).magnitude > Topolys.planar_tol
        end
      end

      # TODO: check that holes are contained within outer

    end

    def parent_class
      Shell
    end

    def child_class
      Wire
    end

    def shells
      @parents
    end

    def wires
      @children
    end

    def shared_outer_edges(other)
      return nil unless other.is_a?(Face)

      result = []
      @outer.directed_edges.each do |de|
        other.outer.directed_edges.each do |other_de|
          # next if de.id == other.de
          result << de.edge if de.edge.id == other_de.edge.id
        end
      end

      return result
    end

  end # Face

  class Shell < Object

    # @return [Array] Array of Face
    attr_reader :faces

    # @return [Array] Array of all edges from outer faces
    attr_reader :all_edges

    # @return [Array] Array of shared edges from outer faces
    attr_reader :shared_edges

    # @return [Hash] Map edges to array of outer faces
    attr_reader :edge_to_face_map

    # @return [Matrix] Matrix of level 1 face to face connections
    attr_reader :connection_matrix

    ##
    # Initializes a Shell object
    #
    # Throws if faces are not connected
    #
    # @param [Array] faces Array of Face
    def initialize(faces)
      super()
      @faces = faces
      @all_edges = []
      @shared_edges = []
      @edge_to_face_map = {}
      @connection_matrix = Matrix.identity(faces.size)

      recalculate
    end

    def to_json
      result = super
      result[:faces] = @faces.map { |h| h.id }
      return result
    end

    def recalculate

      # unlink from any previous faces
      @children.reverse_each {|child| Object.unlink(self, child)}

      # link with current faces
      @faces.each {|face| Object.link(self, face)}

      # recompute cached properties and check invariants
      n = @faces.size

      # can't have duplicate faces
      face_ids = @faces.map{|face| face.id}.uniq.sort
      raise "Duplicate faces in shell" if face_ids.size != n

      @all_edges = []
      @shared_edges = []
      @edge_to_face_map = {}
      @connection_matrix = Matrix.identity(faces.size)
      (0...n).each do |i|

        # populate edge_to_face_map and all_edges
        @faces[i].outer.edges.each do |edge|
          @edge_to_face_map[edge.id] = [] if @edge_to_face_map[edge.id].nil?
          @edge_to_face_map[edge.id] << @faces[i]
          @all_edges << edge
        end

        # loop over other edges
        (i+1...n).each do |j|
          shared_edges = @faces[i].shared_outer_edges(@faces[j])
          #puts "#{i}, #{j}, [#{shared_edges.map{|e| e.short_name}.join(', ')}]"
          @shared_edges.concat(shared_edges)
          if !shared_edges.empty?
            @connection_matrix[i,j] = @connection_matrix[j,i] = 1
          end
        end
      end
      @shared_edges.uniq! {|e| e.id}
      @shared_edges.sort_by! {|e| e.id}
      @all_edges.uniq! {|e| e.id}
      @all_edges.sort_by! {|e| e.id}

      temp_last = @connection_matrix
      temp = normalize_connection_matrix(temp_last * @connection_matrix)
      i = 0
      while temp_last != temp
        temp_last = temp
        temp = normalize_connection_matrix(temp * @connection_matrix)
        i += 1
        break if i > 100
      end

      # check that every face is connected to every other faces
      temp.each {|connection| raise "Faces not connected in shell" if connection == 0}

    end

    def normalize_connection_matrix(m)
      n = faces.size
      result = Matrix.identity(n)
      (0...n).each do |i|
        (i+1...n).each do |j|
          result[i,j] = result[j,i] = (m[i,j] > 0 ? 1 : 0)
        end
      end
      return result
    end

    ##
    # Checks if faces form a closed Shell
    #
    # @return [Bool] Returns true if closed
    def closed?
      @edge_to_face_map.each_value do |faces|
        return false if faces.size != 2
      end

      return @all_edges == @shared_edges
    end

    def parent_class
      NilClass
    end

    def child_class
      Face
    end

    def faces
      @children
    end

  end # Shell

end # TOPOLYS
