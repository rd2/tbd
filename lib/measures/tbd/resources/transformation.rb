require 'matrix'

class Matrix
  def []=(i, j, x)
    @rows[i][j] = x
  end
end

module Topolys

  # Transformations can be applied to Geometry. Ported from OpenStudio Transformation library.

  class Transformation
  
    # @return [Matrix] internal 4x4 matrix
    attr_reader :matrix
    
    ##
    # Initializes an Transformation object
    #
    # @param [Matrix] matrix A 4x4 matrix, defaults to identity
    def initialize(matrix=Matrix.identity(4))
      raise "Incorrect argument for Transformation, expected Matrix but got #{matrix.class}" unless matrix.is_a?(Matrix)
      @matrix = matrix
    end
    
    # translation along vector
    def Transformation.translation(translation)
      return nil if !translation.is_a?(Vector3D)
      
      matrix = Matrix.identity(4)
      matrix[0,3] = translation.x
      matrix[1,3] = translation.y
      matrix[2,3] = translation.z      
      
      return Transformation.new(matrix)
    end
  
    ##
    # Initializes a rotation about origin defined by axis and angle (radians)
    #
    def Transformation.rotation(axis, radians)
      return nil if !axis.is_a?(Vector3D)
      return nil if !radians.is_a?(Numeric)
      return nil if (axis.magnitude < Float::EPSILON)
      normal = axis
      normal.normalize!
      
      # Rodrigues' rotation formula / Rotation matrix from Euler axis/angle
      # I*cos(radians) + I*(1-cos(radians))*axis*axis^T + Q*sin(radians)
      # Q = [0, -axis[2], axis[1]; axis[2], 0, -axis[0]; -axis[1], axis[0], 0]
      p = normal.outer_product(normal)
      i = Matrix.identity(3)
      q = Matrix.zero(3)
      q[0,1] = -normal.z
      q[0,2] =  normal.y
      q[1,0] =  normal.z
      q[1,2] = -normal.x
      q[2,0] = -normal.y
      q[2,1] =  normal.x

      # rotation matrix
      r = i*Math.cos(radians) + (1-Math.cos(radians))*p + q*Math.sin(radians)

      matrix = Matrix.identity(4)
      matrix[0,0] = r[0,0]
      matrix[0,1] = r[0,1]
      matrix[0,2] = r[0,2]
      matrix[1,0] = r[1,0]
      matrix[1,1] = r[1,1]
      matrix[1,2] = r[1,2]
      matrix[2,0] = r[2,0]
      matrix[2,1] = r[2,1]
      matrix[2,2] = r[2,2]
      
      return Transformation.new(matrix)
    end

    ##
    # Multiplies a Transformation by geometry class
    #
    # @param [Obj] obj A geometry object
    #
    # @return [Obj] Returns a new, transformed object - nil if not a geometry object
    def *(obj)
      if obj.is_a?(Point3D)
        return mult_point(obj)
      elsif obj.is_a?(Vector3D)
        return mult_vector(obj)
      elsif obj.is_a?(Array)
        return mult_array(obj)
      elsif obj.is_a?(Transformation)
        return mult_transformation(obj)
      end
      return nil
    end
    
    private
    
    def mult_point(point)
      temp = Matrix.column_vector([point.x, point.y, point.z, 1])
      temp = @matrix*temp
      return Point3D.new(temp[0,0],temp[1,0],temp[2,0])
    end
    
    def mult_vector(vector)
      temp = Matrix.column_vector([vector.x, vector.y, vector.z, 1])
      temp = @matrix*temp
      return Vector3D.new(temp[0,0],temp[1,0],temp[2,0])
    end
    
    def mult_array(array)
      array.map {|obj| self*obj}
    end
    
    def mult_transformation(obj)
      Transformation.new(@matrix * obj.matrix)
    end

  end
end
