module Topolys

  # Point3D, Vector3D, and Plane3D represents the 3D position and orientation
  # of geometry in Topolys.  Geometry is separate from topology (connections).

  class Point3D

    # @return [Float] X, Y, or Z coordinate
    attr_reader :x, :y, :z

    ##
    # Initializes a Point3D object
    #
    # @param [Float] X-coordinate
    # @param [Float] Y-coordinate
    # @param [Float] Z-coordinate
    def initialize(x, y, z)
      raise "Incorrect x argument for Point3D, expected Numeric but got #{x.class}" unless x.is_a?(Numeric)
      raise "Incorrect y argument for Point3D, expected Numeric but got #{y.class}" unless y.is_a?(Numeric)
      raise "Incorrect z argument for Point3D, expected Numeric but got #{z.class}" unless z.is_a?(Numeric)
      @x = x
      @y = y
      @z = z
    end

    def to_s
      "[#{@x}, #{@y}, #{@z}]"
    end

    ##
    # Adds a 3D vector to self
    #
    # @param [Vector3D] vector A Vector3D
    #
    # @return [Point3D] Returns a new Point3D - nil if vector not a Vector3D
    def +(vector)
      return nil unless vector.is_a?(Topolys::Vector3D)
      x = @x + vector.x
      y = @y + vector.y
      z = @z + vector.z
      return Topolys::Point3D.new(x, y, z)
    end

    ##
    # Generates a 3D vector which goes from other to self
    #
    # @param [Point3D] other Another 3D point
    #
    # @return [Vector3D] Returns a new Vector3D - nil if other not a Point3D
    def -(other)
      return nil unless other.is_a?(Topolys::Point3D)
      x = @x - other.x
      y = @y - other.y
      z = @z - other.z
      return Topolys::Vector3D.new(x, y, z)
    end

  end # Point3D

  class Vector3D

    # @return [Float] X, Y, or Z component
    attr_reader :x, :y, :z

    ##
    # Initializes a Vector3D object
    #
    # @param [Float] X-coordinate
    # @param [Float] Y-coordinate
    # @param [Float] Z-coordinate
    def initialize(x, y, z)
      raise "Incorrect x argument for Vector3D, expected Numeric but got #{x.class}" unless x.is_a?(Numeric)
      raise "Incorrect y argument for Vector3D, expected Numeric but got #{y.class}" unless y.is_a?(Numeric)
      raise "Incorrect z argument for Vector3D, expected Numeric but got #{z.class}" unless z.is_a?(Numeric)
      @x = x
      @y = y
      @z = z
    end

    def to_s
      "[#{@x}, #{@y}, #{@z}]"
    end

    def Vector3D.x_axis
      Vector3D.new(1,0,0)
    end

    def Vector3D.y_axis
      Vector3D.new(0,1,0)
    end

    def Vector3D.z_axis
      Vector3D.new(0,0,1)
    end

    ##
    # Adds 2x 3D vectors - overrides '+' operator
    #
    # @param [Vector3D] other Another 3D vector
    #
    # @return [Vector3D] Returns a new 3D resultant vector - nil if not Vector3D objects
    def +(other)
      return nil unless other.is_a?(Topolys::Vector3D)
      x = @x + other.x
      y = @y + other.y
      z = @z + other.z
      return Topolys::Vector3D.new(x, y, z)
    end

    ##
    # Subtracts a 3D vector from another 3D vector - overrides '-' operator.
    # Leaves original 3D vector intact if other is not a Vector3D object
    #
    # @param [Vector3D] other Another 3D vector
    #
    # @return [Vector3D] Returns a new 3D resultant vector - nil if not Vector3D objects
    def -(other)
      return nil unless other.is_a?(Topolys::Vector3D)
      x = @x - other.x
      y = @y - other.y
      z = @z - other.z
      return Topolys::Vector3D.new(x, y, z)
    end

    ##
    # Multiplies a 3D vector by a scalar
    #
    # @param [Float] scalar A scalar
    #
    # @return [Vector3D] Returns a new, scaled 3D vector - nil if not numeric
    def *(scalar)
      return nil unless scalar.is_a?(Numeric)
      x = @x * scalar
      y = @y * scalar
      z = @z * scalar
      return Topolys::Vector3D.new(x, y, z)
    end

    ##
    # Divides a 3D vector by a non-zero scalar
    #
    # @param [Float] scalar A non-zero scalar
    #
    # @return [Vector3D] Returns a new, scaled 3D vector - nil if 0 or not numeric
    def /(scalar)
      return nil unless scalar.is_a?(Numeric)
      return nil if scalar.zero?
      x = @x / scalar
      y = @y / scalar
      z = @z / scalar
      Topolys::Vector3D.new(x, y, z)
    end

    ##
    # Gets 3D vector magnitude (or length)
    #
    # @return [Float] Returns magnitude of the 3D vector
    def magnitude
      Math.sqrt(@x**2 + @y**2 + @z**2)
    end

    ##
    # Normalizes a 3D vector
    def normalize!
      n = magnitude
      unless n.zero?
        @x /= n
        @y /= n
        @z /= n
      end
    end

    ##
    # Gets the dot (or inner) product of self & another 3D vector
    #
    # @param [Vector3D] other Another 3D vector
    #
    # @return [Float] Returns dot product - nil if not Vector3D objects
    def dot(other)
      return nil unless other.is_a?(Topolys::Vector3D)
      return @x * other.x + @y * other.y + @z * other.z
    end

    ##
    # Gets the cross product between self & another 3D vector
    #
    # @param [Vector3D] other Another 3D vector
    #
    # @return [Vector3D] Returns cross product - nil if not Vector3D objects
    def cross(other)
      return nil unless other.is_a?(Topolys::Vector3D)
      x = @y * other.z - @z * other.y
      y = @z * other.x - @x * other.z
      z = @x * other.y - @y * other.x
      return Topolys::Vector3D.new(x, y, z)
    end

    ##
    # Gets the outer product between self & another 3D vector
    #
    # @param [Vector3D] other Another 3D vector
    #
    # @return [Matrix] Returns outer product
    def outer_product(other)
      return nil unless other.is_a?(Topolys::Vector3D)
      result = Matrix.zero(3,3)
      result[0,0] = @x*other.x
      result[0,1] = @x*other.y
      result[0,2] = @x*other.z
      result[1,0] = @y*other.x
      result[1,1] = @y*other.y
      result[1,2] = @y*other.z
      result[2,0] = @z*other.x
      result[2,1] = @z*other.y
      result[2,2] = @z*other.z
      return result
    end

    ##
    # Gets angle [0,PI) between self & another 3D vector
    #
    # @param [Vector3D] other Another 3D vector
    #
    # @return [Float] Returns angle - nil if not Vector3D objects
    def angle(other)
      return nil unless other.is_a?(Topolys::Vector3D)
      prod = magnitude * other.magnitude
      return nil if prod.zero?
      val = dot(other) / prod
      val = [-1.0, val].max
      val = [ val, 1.0].min
      Math.acos(val)
    end

  end # Vector3D

  class Plane3D

    # @return [Point3D] arbitrary point on plane
    attr_reader :point

    # @return [Vector3D] normalized vector perpendicular to plane
    attr_reader :normal

    ##
    # Initializes a Plane3D object from a point and an outward normal
    #
    # @param [Point3d] point
    # @param [Vector3D] normal
    def initialize(point, normal)
      raise "Incorrect point argument for Plane3D, expected Point3D but got #{point.class}" unless point.is_a?(Topolys::Point3D)
      raise "Incorrect normal argument for Plane3D, expected Vector3D but got #{normal.class}" unless normal.is_a?(Topolys::Vector3D)
      raise "Incorrect normal argument for Plane3D, magnitude too small" unless normal.magnitude > Float::EPSILON

      @point = Point3D.new(point.x, point.y, point.z)
      @normal = Vector3D.new(normal.x, normal.y, normal.z)
      @normal.normalize!

      # coefficients for equation of a plane
      @a = @normal.x
      @b = @normal.y
      @c = @normal.z
      @d = -(@a*@point.x + @b*@point.y + @c*@point.z)
    end

    def to_s
      "[#{@a}, #{@b}, #{@c}, #{@d}]"
    end

    ##
    # Initializes a Plane3D object from three non-colinear points
    #
    # @param [Point3d] point1
    # @param [Point3d] point2
    # @param [Point3d] point3
    def Plane3D.from_points(point1, point2, point3)
      return nil unless point1.is_a?(Topolys::Point3D)
      return nil unless point2.is_a?(Topolys::Point3D)
      return nil unless point3.is_a?(Topolys::Point3D)

      normal = (point2-point1).cross(point3-point1)
      return nil unless normal.magnitude > Float::EPSILON

      return Plane3D.new(point1, normal)
    end

    ##
    # Initializes a Plane3D object from a point and two vectors
    #
    # @param [Point3d] point
    # @param [Vector3D] xaxis
    # @param [Vector3D] yaxis
    def Plane3D.from_point_axes(point, xaxis, yaxis)
      return nil unless point.is_a?(Topolys::Point3D)
      return nil unless xaxis.is_a?(Topolys::Vector3D)
      return nil unless yaxis.is_a?(Topolys::Vector3D)

      normal = xaxis.cross(yaxis)
      return nil unless normal.magnitude > Float::EPSILON

      return Plane3D.new(point, normal)
    end

    # TODO: implement methods below

    ##
    # Project a Point3d to this plane
    #
    # @param [Point3d] point
    #
    # @return [Point3d] Returns point projected to this plane
    def project(point)
      dist = @normal.dot(point-@point)
      return point + normal*(-dist)
    end

  end # Plane3D

  class BoundingBox

    attr_reader :minx, :maxx, :miny, :maxy, :minz, :maxz

    def initialize(tol = 0.001)
      @tol = tol
      @minx = Float::INFINITY
      @miny = Float::INFINITY
      @minz = Float::INFINITY
      @maxx = -Float::INFINITY
      @maxy = -Float::INFINITY
      @maxz = -Float::INFINITY
    end

    def add_point(point)
      @minx = [point.x, @minx].min
      @miny = [point.y, @miny].min
      @minz = [point.z, @minz].min
      @maxx = [point.x, @maxx].max
      @maxy = [point.y, @maxy].max
      @maxz = [point.z, @maxz].max
    end

    def include?(point)
      result = ((point.x >= @minx - @tol) && (point.x <= @maxx + @tol)) &&
               ((point.y >= @miny - @tol) && (point.y <= @maxy + @tol)) &&
               ((point.z >= @minz - @tol) && (point.z <= @maxz + @tol))
      return result
    end

 end # BoundingBox

end # TOPOLYS
