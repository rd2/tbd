require "openstudio"

##
# Flatten OpenStudio 3D points vs Z-axis (Z=0).
#
# @param [Array] pts OpenStudio Point3D array/vector
#
# @return [Array] Flattened OS 3D points array
def flatZ(pts)
  unless pts && (pts.is_a?(OpenStudio::Point3dVector) || pts.is_a?(Array))
    TBD.log(TBD::DEBUG,
      "Invalid pts to flatten (argument) - skipping")
    return pts
  end

  pts.each do |pt|
    unless pt.class == OpenStudio::Point3d
      TBD.log(TBD::DEBUG,
        "#{pt.class}? expected OSM 3D points to flatten - skipping")
      next
    end
    pt = OpenStudio::Point3d.new(pt.x, pt.y, 0)
  end
  pts
end

##
# Validate whether an OpenStudio subsurface can 'fit in' (vs parent, siblings)
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [String] id SubSurface identifier
# @param [Array] pts Point3D array of subsurface 'id'
#
# @return [Bool] Returns true if subsurface can fit in.
def fit?(model, id, pts)
  unless model && model.is_a?(OpenStudio::Model::Model)
    TBD.log(TBD::DEBUG,
      "Can't find or validate OSM (argument) for subsurface fit - skipping")
    return false
  end
  unless pts && (pts.is_a?(OpenStudio::Point3dVector) || pts.is_a?(Array))
    TBD.log(TBD::DEBUG,
      "Invalid subsurface pts to fit (argument) - skipping")
    return false
  end

  pts.each do |pt|
    unless pt.class == OpenStudio::Point3d
      TBD.log(TBD::DEBUG,
        "#{pt.class}? expected OSM 3D points to fit - skipping")
      return false
    end
  end

  s = model.getSubSurfaceByName(id)
  if s.empty?
    TBD.log(TBD::DEBUG,
      "Can't find '#{id}' OSM subsurface to fit - skipping")
    return false
  end

  s = s.get
  if s.surface.empty?
    TBD.log(TBD::DEBUG,
      "Missing subsurface '#{id}' OSM parent surface entry - skipping")
    return false
  end

  nom = s.surface.get.nameString
  parent = model.getSurfaceByName(nom)
  if parent.empty?
    TBD.log(TBD::DEBUG,
      "Can't find subsurface '#{id}' OSM parent surface '#{nom}' - skipping")
    return false
  end

  parent = parent.get
  ft = OpenStudio::Transformation::alignFace(parent.vertices).inverse
  ft_parent = (ft * parent.vertices).reverse
  ft_parent = flatZ(ft_parent)

  siblings = []
  model.getSubSurfaces.each do |sub|
    next if sub.nameString == id
    next if sub.surface.empty?
    next unless sub.surface.get.nameString == parent.nameString
    siblings << flatZ( (ft * sub.vertices).reverse )
  end

  ft_pts = flatZ(ft * pts)
  ft_pts.each do |ft_pt|
    return false unless OpenStudio::pointInPolygon(ft_pt, ft_parent, TOL)
    siblings.each do |sibling|
      return false if OpenStudio::pointInPolygon(ft_pt, sibling, TOL)
    end
  end
  true
end

##
# Calculate triangle area.
#
# @param [Array] pts Point3D array (3x)
#
# @return [Float] triangle area (m2)
# @return [Array] subsurface rough opening sorted Topolys 3D points
def areaHeron(pts)
  unless pts && pts.is_a?(Array) && pts.size == 3
    TBD.log(TBD::DEBUG,
      "Invalid subsurface pts (argument) to calculate area - skipping")
    return 0
  end

  pts.each do |pt|
    unless pt.class == Topolys::Point3D
      TBD.log(TBD::DEBUG,
        "#{pt.class}? expected OSM 3D points to calculate area - skipping")
      return 0
    end
  end

  e = []
  e << { v0: pts[0], v1: pts[1], mag: (pts[1] - pts[0]).magnitude }
  e << { v0: pts[1], v1: pts[2], mag: (pts[2] - pts[1]).magnitude }
  e << { v0: pts[2], v1: pts[0], mag: (pts[0] - pts[2]).magnitude }

  if matches?(e[0], e[1]) || matches?(e[1], e[2]) || matches?(e[2], e[0])
    TBD.log(TBD::DEBUG,
      "Unique triangle edges to calculate area - skipping")
    return 0
  end
  e = e.sort_by{ |p| p[:mag] }

  # Kahan's stable implementation of Heron's formula for triangle area.
  # area = 1/4 sqrt( (a+(b+c)) (c-(a-b)) (c+(a-b)) (a+(b-c)) ) ... a > b > c
  a = e[0][:mag]
  b = e[1][:mag]
  c = e[2][:mag]
  0.25 * Math.sqrt( (a+(b+c)) * (c-(a-b)) * (c+(a-b)) * (a+(b-c)) )
end

##
# Calculate subsurface rough opening area & vertices.
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [String] id SubSurface identifier
#
# @return [Float] Returns subsurface rough opening area (m2)
# @return [Array] Returns subsurface rough opening OpenStudio 3D points
def opening(model, id)
  unless model && model.is_a?(OpenStudio::Model::Model)
    TBD.log(TBD::DEBUG,
      "Can't find or validate OSM (argument) for area & vertices - skipping")
    return 0, nil
  end

  s = model.getSubSurfaceByName(id)
  if s.empty?
    TBD.log(TBD::DEBUG,
      "Can't find OSM '#{id}' subsurface for area & vertices - skipping")
    return 0, nil
  end

  s = s.get
  points = s.vertices
  unless points.size == 3 || points.size == 4
    TBD.log(TBD::ERROR,
      "OSM subsurface '#{id}' vertex count (must be 3 or 4) - skipping")
    return 0, points
  end

  area = s.grossArea
  if area < TOL
    TBD.log(TBD::ERROR,
      "OSM subsurface '#{id}' gross area (< TOL) - skipping")
    return 0, points
  end

  # Should verify convexity of vertex wire/face ...
  #
  #       A
  #      / \
  #     /   \
  #    /     \
  #   / C --- D    <<< allowed as OpenStudio/E+ subsurface?
  #  / /
  #  B
  #
  # Should convert (annoying) 4-point subsurface into triangle ...
  #        A
  #       / \
  #      /   \
  #     /     \
  #    B - C - D   <<< allowed as OpenStudio/E+ subsurface?
  #
  return area, points if s.windowPropertyFrameAndDivider.empty?
  width = s.windowPropertyFrameAndDivider.get.frameWidth
  return area, points if width < TOL

  four = true if s.vertices.size == 4
  pts = {}

  pts[:A] = {}
  pts[:B] = {}
  pts[:C] = {}
  pts[:D] = {} if four

  pts[:A][:pt] = Topolys::Point3D.new(points[0].x, points[0].y, points[0].z)
  pts[:B][:pt] = Topolys::Point3D.new(points[1].x, points[1].y, points[1].z)
  pts[:C][:pt] = Topolys::Point3D.new(points[2].x, points[2].y, points[2].z)
  pts[:D][:pt] = Topolys::Point3D.new(points[3].x, points[3].y, points[3].z) if four

  # Generate vector pairs, from next point & from previous point.
  #
  #
  #
  #
  #
  #
  #             A <---------- B
  #              ^
  #               \
  #                \
  #                 C (or D)
  #
  pts[:A][:from_next] = pts[:A][:pt] - pts[:B][:pt]
  pts[:A][:from_prev] = pts[:A][:pt] - pts[:C][:pt] unless four
  pts[:A][:from_prev] = pts[:A][:pt] - pts[:D][:pt] if four

  pts[:B][:from_next] = pts[:B][:pt] - pts[:C][:pt]
  pts[:B][:from_prev] = pts[:B][:pt] - pts[:A][:pt]

  pts[:C][:from_next] = pts[:C][:pt] - pts[:A][:pt] unless four
  pts[:C][:from_next] = pts[:C][:pt] - pts[:D][:pt] if four
  pts[:C][:from_prev] = pts[:C][:pt] - pts[:B][:pt]

  pts[:D][:from_next] = pts[:D][:pt] - pts[:A][:pt] if four
  pts[:D][:from_prev] = pts[:D][:pt] - pts[:C][:pt] if four

  # Generate 3D plane from vectors.
  #
  #
  #             |  <<< 3D plane ... from point A, with normal B>A
  #             |
  #             |
  #             |
  # <---------- A <---------- B
  #             |\
  #             | \
  #             |  \
  #             |   C (or D)
  #
  pts[:A][:pl_from_next] = Topolys::Plane3D.new(pts[:A][:pt], pts[:A][:from_next])
  pts[:A][:pl_from_prev] = Topolys::Plane3D.new(pts[:A][:pt], pts[:A][:from_prev])

  pts[:B][:pl_from_next] = Topolys::Plane3D.new(pts[:B][:pt], pts[:B][:from_next])
  pts[:B][:pl_from_prev] = Topolys::Plane3D.new(pts[:B][:pt], pts[:B][:from_prev])

  pts[:C][:pl_from_next] = Topolys::Plane3D.new(pts[:C][:pt], pts[:C][:from_next])
  pts[:C][:pl_from_prev] = Topolys::Plane3D.new(pts[:C][:pt], pts[:C][:from_prev])

  pts[:D][:pl_from_next] = Topolys::Plane3D.new(pts[:D][:pt], pts[:D][:from_next]) if four
  pts[:D][:pl_from_prev] = Topolys::Plane3D.new(pts[:D][:pt], pts[:D][:from_prev]) if four

  # Project an extended point (pC) unto 3D plane.
  #
  #             pC   <<< projected unto extended B>A 3D plane
  #        eC   |
  #          \  |
  #           \ |
  #            \|
  # <---------- A <---------- B
  #             |\
  #             | \
  #             |  \
  #             |   C (or D)
  #
  pts[:A][:prev_unto_next_pl] = pts[:A][:pl_from_next].project(pts[:A][:pt] + pts[:A][:from_prev])
  pts[:A][:next_unto_prev_pl] = pts[:A][:pl_from_prev].project(pts[:A][:pt] + pts[:A][:from_next])

  pts[:B][:prev_unto_next_pl] = pts[:B][:pl_from_next].project(pts[:B][:pt] + pts[:B][:from_prev])
  pts[:B][:next_unto_prev_pl] = pts[:B][:pl_from_prev].project(pts[:B][:pt] + pts[:B][:from_next])

  pts[:C][:prev_unto_next_pl] = pts[:C][:pl_from_next].project(pts[:C][:pt] + pts[:C][:from_prev])
  pts[:C][:next_unto_prev_pl] = pts[:C][:pl_from_prev].project(pts[:C][:pt] + pts[:C][:from_next])

  pts[:D][:prev_unto_next_pl] = pts[:D][:pl_from_next].project(pts[:D][:pt] + pts[:D][:from_prev]) if four
  pts[:D][:next_unto_prev_pl] = pts[:D][:pl_from_prev].project(pts[:D][:pt] + pts[:D][:from_next]) if four

  # Generate vector from point (e.g. A) to projected extended point (pC).
  #
  #             pC
  #        eC   ^
  #          \  |
  #           \ |
  #            \|
  # <---------- A <---------- B
  #             |\
  #             | \
  #             |  \
  #             |   C (or D)
  #
  pts[:A][:n_prev_unto_next_pl] = pts[:A][:prev_unto_next_pl] - pts[:A][:pt]
  pts[:A][:n_next_unto_prev_pl] = pts[:A][:next_unto_prev_pl] - pts[:A][:pt]

  pts[:B][:n_prev_unto_next_pl] = pts[:B][:prev_unto_next_pl] - pts[:B][:pt]
  pts[:B][:n_next_unto_prev_pl] = pts[:B][:next_unto_prev_pl] - pts[:B][:pt]

  pts[:C][:n_prev_unto_next_pl] = pts[:C][:prev_unto_next_pl] - pts[:C][:pt]
  pts[:C][:n_next_unto_prev_pl] = pts[:C][:next_unto_prev_pl] - pts[:C][:pt]

  pts[:D][:n_prev_unto_next_pl] = pts[:D][:prev_unto_next_pl] - pts[:D][:pt] if four
  pts[:D][:n_next_unto_prev_pl] = pts[:D][:next_unto_prev_pl] - pts[:D][:pt] if four

  # Fetch angle between both extended vectors (A>pC & A>pB), then normalize (Cn).
  #
  #             pC
  #        eC   ^
  #          \  |
  #           \ Cn
  #            \|
  # <---------- A <---------- B
  #             |\
  #             | \
  #             |  \
  #             |   C (or D)
  #
  pts[:A][:angle] = pts[:A][:n_prev_unto_next_pl].angle(pts[:A][:n_next_unto_prev_pl])
  pts[:B][:angle] = pts[:B][:n_prev_unto_next_pl].angle(pts[:B][:n_next_unto_prev_pl])
  pts[:C][:angle] = pts[:C][:n_prev_unto_next_pl].angle(pts[:C][:n_next_unto_prev_pl])
  pts[:D][:angle] = pts[:D][:n_prev_unto_next_pl].angle(pts[:D][:n_next_unto_prev_pl]) if four

  # Generate new 3D points A', B', C' (and D') ... zigzag.
  #
  #
  #
  #
  #     A' ---------------------- B'
  #      \
  #       \      A <---------- B
  #        \      \
  #         \      \
  #          \      \
  #           C'      C
  pts[:A][:from_next].normalize!
  pts[:A][:n_prev_unto_next_pl].normalize!
  pts[:A][:p] = pts[:A][:pt] + (pts[:A][:n_prev_unto_next_pl] * width) + (pts[:A][:from_next] * width * Math.tan(pts[:A][:angle]/2))

  pts[:B][:from_next].normalize!
  pts[:B][:n_prev_unto_next_pl].normalize!
  pts[:B][:p] = pts[:B][:pt] + (pts[:B][:n_prev_unto_next_pl] * width) + (pts[:B][:from_next] * width * Math.tan(pts[:B][:angle]/2))

  pts[:C][:from_next].normalize!
  pts[:C][:n_prev_unto_next_pl].normalize!
  pts[:C][:p] = pts[:C][:pt] + (pts[:C][:n_prev_unto_next_pl] * width) + (pts[:C][:from_next] * width * Math.tan(pts[:C][:angle]/2))

  pts[:D][:from_next].normalize! if four
  pts[:D][:n_prev_unto_next_pl].normalize! if four
  pts[:D][:p] = pts[:D][:pt] + (pts[:D][:n_prev_unto_next_pl] * width) + (pts[:D][:from_next] * width * Math.tan(pts[:D][:angle]/2)) if four

  # Re-convert Topolys 3D points into OpenStudio 3D points for fitting test.
  vec = OpenStudio::Point3dVector.new
  vec << OpenStudio::Point3d.new(pts[:A][:p].x, pts[:A][:p].y, pts[:A][:p].z)
  vec << OpenStudio::Point3d.new(pts[:B][:p].x, pts[:B][:p].y, pts[:B][:p].z)
  vec << OpenStudio::Point3d.new(pts[:C][:p].x, pts[:C][:p].y, pts[:C][:p].z)
  vec << OpenStudio::Point3d.new(pts[:D][:p].x, pts[:D][:p].y, pts[:D][:p].z) if four

  return area, points unless fit?(model, id, vec)

  tr1 = []
  tr1 << pts[:A][:p]
  tr1 << pts[:B][:p]
  tr1 << pts[:C][:p]
  area1 = areaHeron(tr1)

  area2 = 0
  if four
    tr2 = []
    tr2 << pts[:A][:p]
    tr2 << pts[:C][:p]
    tr2 << pts[:D][:p]
    area2 = areaHeron(tr2)
  end
  area = area1 + area2

  return area, vec
end
