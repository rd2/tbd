##
# Flatten OpenStudio 3D points vs Z-axis (Z=0).
#
# @param [Array] pts OpenStudio Point3D array/vector
#
# @return [Array] Flattened OpenStudio 3D points array
def flatZ(pts)
  unless pts && (pts.is_a?(OpenStudio::Point3dVector) || pts.is_a?(Array))
    TBD.log(TBD::DEBUG, "Invalid pts to flatten (argument) - skipping")
    return OpenStudio::Point3dVector.new
  end

  vec = OpenStudio::Point3dVector.new
  pts.each do |pt|
    unless pt.class == OpenStudio::Point3d
      msg = "#{pt.class}? expected OSM 3D points to flatten - skipping"
      TBD.log(TBD::DEBUG, msg)
      return OpenStudio::Point3dVector.new
    end
    vec << OpenStudio::Point3d.new(pt.x, pt.y, 0)
  end
  vec
end

##
# Validates whether 1st OpenStudio polygon fits within 2nd polygon.
#
# @param [Array] poly1 Point3D array of convex polygon #1
# @param [Array] poly2 Point3D array of convex polygon #2
# @param [String] id1 Polygon #1 identifier (optional)
# @param [String] id2 Polygon #2 identifier (optional)
#
# @return Returns true if 1st polygon fits entirely within the 2nd polygon.
def fits?(poly1, poly2, id1 = "", id2 = "")
  unless poly1 && (poly1.is_a?(OpenStudio::Point3dVector) || poly1.is_a?(Array))
    msg = ""
    msg << "'#{id1}': " unless id1.empty?
    msg << "Invalid polygon (fits?, 1st argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  unless poly2 && (poly2.is_a?(OpenStudio::Point3dVector) || poly2.is_a?(Array))
    msg = ""
    msg << "'#{id2}': " unless id2.empty?
    msg << "Invalid polygon (fits?, 2nd argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  if poly1.empty?
    msg = ""
    msg << "'#{id1}': " unless id1.empty?
    msg << "Empty polygon (fits?, 1st argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  if poly2.empty?
    msg = ""
    msg << "'#{id2}': " unless id2.empty?
    msg << "Empty polygon (fits?, 2nd argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end

  poly1.each do |pt|
    unless pt.class == OpenStudio::Point3d
      msg = "#{pt.class}? "
      msg << "for '#{id1}': " unless id1.empty?
      msg << "Expected OpenStudio 3D points (fits?, 1st argument - skipping"
      TBD.log(TBD::DEBUG, msg)
      return false
    end
  end
  poly2.each do |pt|
    unless pt.class == OpenStudio::Point3d
      msg = "#{pt.class}? "
      msg << "for '#{id2}': " unless id2.empty?
      msg << "Expected OpenStudio 3D points (fits?, 2nd argument - skipping"
      TBD.log(TBD::DEBUG, msg)
      return false
    end
  end

  ft = OpenStudio::Transformation::alignFace(poly1).inverse
  ft_poly1 = flatZ( (ft * poly1).reverse )
  ft_poly2 = flatZ( (ft * poly2).reverse )

  area1 = OpenStudio::getArea(ft_poly1)
  if area1.empty?
    msg = "#{pt.class}? "
    msg << "for '#{id2}': " unless id2.empty?
    msg << "Invalid polygon area (fits?, 1st argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  area1 = area1.get

  area2 = OpenStudio::getArea(ft_poly2)
  if area2.empty?
    msg = "#{pt.class}? "
    msg << "for '#{id2}': " unless id2.empty?
    msg << "Invalid polygon area (fits?, 2nd argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  area2 = area2.get

  union = OpenStudio::join(ft_poly1, ft_poly2, TOL2)
  return false if union.empty?
  union = union.get
  area = OpenStudio::getArea(union)
  if area.empty?
    msg = "Can't determine if "
    msg << "'#{id1}' " unless id1.empty?
    msg << "fits? - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  area = area.get

  return false if area < TOL
  return true if (area - area2).abs < TOL
  return false if (area - area2).abs > TOL
  true
end

##
# Validates whether an OpenStudio polygon overlaps another polygon.
#
# @param [Array] poly1 Point3D array of convex polygon #1
# @param [Array] poly2 Point3D array of convex polygon #2
# @param [String] id1 Polygon #1 identifier (optional)
# @param [String] id2 Polygon #2 identifier (optional)
#
# @return Returns true if polygons overlaps (or either fits into the other).
def overlaps?(poly1, poly2, id1 = "", id2 = "")
  unless poly1 && (poly1.is_a?(OpenStudio::Point3dVector) || poly1.is_a?(Array))
    msg = ""
    msg << "'#{id1}': " unless id1.empty?
    msg << "Invalid polygon (overlaps?, 1st argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  unless poly2 && (poly2.is_a?(OpenStudio::Point3dVector) || poly2.is_a?(Array))
    msg = ""
    msg << "'#{id2}': " unless id2.empty?
    msg << "Invalid polygon (overlaps?, 2nd argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  if poly1.empty?
    msg = ""
    msg << "'#{id1}': " unless id1.empty?
    msg << "Empty polygon (overlaps?, 1st argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  if poly2.empty?
    msg = ""
    msg << "'#{id2}': " unless id2.empty?
    msg << "Empty polygon (overlaps?, 2nd argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end

  poly1.each do |pt|
    unless pt.class == OpenStudio::Point3d
      msg = "#{pt.class}? "
      msg << "for '#{id1}': " unless id1.empty?
      msg << "Expected OpenStudio 3D points (overlaps?, 1st argument - skipping"
      TBD.log(TBD::DEBUG, msg)
      return false
    end
  end
  poly2.each do |pt|
    unless pt.class == OpenStudio::Point3d
      msg = "#{pt.class}? "
      msg << "for '#{id2}': " unless id2.empty?
      msg << "Expected OpenStudio 3D points (overlaps?, 2nd argument - skipping"
      TBD.log(TBD::DEBUG, msg)
      return false
    end
  end

  ft = OpenStudio::Transformation::alignFace(poly1).inverse
  ft_poly1 = flatZ( (ft * poly1).reverse )
  ft_poly2 = flatZ( (ft * poly2).reverse )

  area1 = OpenStudio::getArea(ft_poly1)
  if area1.empty?
    msg = "#{pt.class}? "
    msg << "for '#{id2}': " unless id2.empty?
    msg << "Invalid polygon area (fits?, 1st argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  area1 = area1.get

  area2 = OpenStudio::getArea(ft_poly2)
  if area2.empty?
    msg = "#{pt.class}? "
    msg << "for '#{id2}': " unless id2.empty?
    msg << "Invalid polygon area (fits?, 2nd argument) - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  area2 = area2.get

  union = OpenStudio::join(ft_poly1, ft_poly2, TOL2)
  return false if union.empty?
  union = union.get
  area = OpenStudio::getArea(union)
  if area.empty?
    msg = "Can't determine if "
    msg << "'#{id1}' " unless id1.empty?
    msg << "overlaps? - skipping"
    TBD.log(TBD::DEBUG, msg)
    return false
  end
  area = area.get

  return false if area < TOL
  true
end

##
# Generate offset vertices by a certain width.
#
# @param [Array] pts OpenStudio Point3D array
# @param [Float] width Offset width
#
# @return [Array] Offset Topolys 3D points (original points if failed).
def offset(pts, width)
  unless pts && (pts.is_a?(OpenStudio::Point3dVector) || pts.is_a?(Array))
    msg = "Invalid subsurface vertices to offset - skipping"
    TBD.log(TBD::DEBUG, msg)
    return pts
  end

  return pts if width < TOL

  four = true if pts.size == 4
  ptz = {}

  ptz[:A] = {}
  ptz[:B] = {}
  ptz[:C] = {}
  ptz[:D] = {} if four

  ptz[:A][:pt] = Topolys::Point3D.new(pts[0].x, pts[0].y, pts[0].z)
  ptz[:B][:pt] = Topolys::Point3D.new(pts[1].x, pts[1].y, pts[1].z)
  ptz[:C][:pt] = Topolys::Point3D.new(pts[2].x, pts[2].y, pts[2].z)
  ptz[:D][:pt] = Topolys::Point3D.new(pts[3].x, pts[3].y, pts[3].z) if four

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
  ptz[:A][:from_next] = ptz[:A][:pt] - ptz[:B][:pt]
  ptz[:A][:from_prev] = ptz[:A][:pt] - ptz[:C][:pt] unless four
  ptz[:A][:from_prev] = ptz[:A][:pt] - ptz[:D][:pt] if four

  ptz[:B][:from_next] = ptz[:B][:pt] - ptz[:C][:pt]
  ptz[:B][:from_prev] = ptz[:B][:pt] - ptz[:A][:pt]

  ptz[:C][:from_next] = ptz[:C][:pt] - ptz[:A][:pt] unless four
  ptz[:C][:from_next] = ptz[:C][:pt] - ptz[:D][:pt] if four
  ptz[:C][:from_prev] = ptz[:C][:pt] - ptz[:B][:pt]

  ptz[:D][:from_next] = ptz[:D][:pt] - ptz[:A][:pt] if four
  ptz[:D][:from_prev] = ptz[:D][:pt] - ptz[:C][:pt] if four

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
  ptz[:A][:pl_from_next] = Topolys::Plane3D.new(ptz[:A][:pt], ptz[:A][:from_next])
  ptz[:A][:pl_from_prev] = Topolys::Plane3D.new(ptz[:A][:pt], ptz[:A][:from_prev])

  ptz[:B][:pl_from_next] = Topolys::Plane3D.new(ptz[:B][:pt], ptz[:B][:from_next])
  ptz[:B][:pl_from_prev] = Topolys::Plane3D.new(ptz[:B][:pt], ptz[:B][:from_prev])

  ptz[:C][:pl_from_next] = Topolys::Plane3D.new(ptz[:C][:pt], ptz[:C][:from_next])
  ptz[:C][:pl_from_prev] = Topolys::Plane3D.new(ptz[:C][:pt], ptz[:C][:from_prev])

  ptz[:D][:pl_from_next] = Topolys::Plane3D.new(ptz[:D][:pt], ptz[:D][:from_next]) if four
  ptz[:D][:pl_from_prev] = Topolys::Plane3D.new(ptz[:D][:pt], ptz[:D][:from_prev]) if four

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
  ptz[:A][:prev_unto_next_pl] = ptz[:A][:pl_from_next].project(ptz[:A][:pt] + ptz[:A][:from_prev])
  ptz[:A][:next_unto_prev_pl] = ptz[:A][:pl_from_prev].project(ptz[:A][:pt] + ptz[:A][:from_next])

  ptz[:B][:prev_unto_next_pl] = ptz[:B][:pl_from_next].project(ptz[:B][:pt] + ptz[:B][:from_prev])
  ptz[:B][:next_unto_prev_pl] = ptz[:B][:pl_from_prev].project(ptz[:B][:pt] + ptz[:B][:from_next])

  ptz[:C][:prev_unto_next_pl] = ptz[:C][:pl_from_next].project(ptz[:C][:pt] + ptz[:C][:from_prev])
  ptz[:C][:next_unto_prev_pl] = ptz[:C][:pl_from_prev].project(ptz[:C][:pt] + ptz[:C][:from_next])

  ptz[:D][:prev_unto_next_pl] = ptz[:D][:pl_from_next].project(ptz[:D][:pt] + ptz[:D][:from_prev]) if four
  ptz[:D][:next_unto_prev_pl] = ptz[:D][:pl_from_prev].project(ptz[:D][:pt] + ptz[:D][:from_next]) if four

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
  ptz[:A][:n_prev_unto_next_pl] = ptz[:A][:prev_unto_next_pl] - ptz[:A][:pt]
  ptz[:A][:n_next_unto_prev_pl] = ptz[:A][:next_unto_prev_pl] - ptz[:A][:pt]

  ptz[:B][:n_prev_unto_next_pl] = ptz[:B][:prev_unto_next_pl] - ptz[:B][:pt]
  ptz[:B][:n_next_unto_prev_pl] = ptz[:B][:next_unto_prev_pl] - ptz[:B][:pt]

  ptz[:C][:n_prev_unto_next_pl] = ptz[:C][:prev_unto_next_pl] - ptz[:C][:pt]
  ptz[:C][:n_next_unto_prev_pl] = ptz[:C][:next_unto_prev_pl] - ptz[:C][:pt]

  ptz[:D][:n_prev_unto_next_pl] = ptz[:D][:prev_unto_next_pl] - ptz[:D][:pt] if four
  ptz[:D][:n_next_unto_prev_pl] = ptz[:D][:next_unto_prev_pl] - ptz[:D][:pt] if four

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
  ptz[:A][:angle] = ptz[:A][:n_prev_unto_next_pl].angle(ptz[:A][:n_next_unto_prev_pl])
  ptz[:B][:angle] = ptz[:B][:n_prev_unto_next_pl].angle(ptz[:B][:n_next_unto_prev_pl])
  ptz[:C][:angle] = ptz[:C][:n_prev_unto_next_pl].angle(ptz[:C][:n_next_unto_prev_pl])
  ptz[:D][:angle] = ptz[:D][:n_prev_unto_next_pl].angle(ptz[:D][:n_next_unto_prev_pl]) if four

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
  ptz[:A][:from_next].normalize!
  ptz[:A][:n_prev_unto_next_pl].normalize!
  ptz[:A][:p] = ptz[:A][:pt] + (ptz[:A][:n_prev_unto_next_pl] * width) + (ptz[:A][:from_next] * width * Math.tan(ptz[:A][:angle]/2))

  ptz[:B][:from_next].normalize!
  ptz[:B][:n_prev_unto_next_pl].normalize!
  ptz[:B][:p] = ptz[:B][:pt] + (ptz[:B][:n_prev_unto_next_pl] * width) + (ptz[:B][:from_next] * width * Math.tan(ptz[:B][:angle]/2))

  ptz[:C][:from_next].normalize!
  ptz[:C][:n_prev_unto_next_pl].normalize!
  ptz[:C][:p] = ptz[:C][:pt] + (ptz[:C][:n_prev_unto_next_pl] * width) + (ptz[:C][:from_next] * width * Math.tan(ptz[:C][:angle]/2))

  ptz[:D][:from_next].normalize! if four
  ptz[:D][:n_prev_unto_next_pl].normalize! if four
  ptz[:D][:p] = ptz[:D][:pt] + (ptz[:D][:n_prev_unto_next_pl] * width) + (ptz[:D][:from_next] * width * Math.tan(ptz[:D][:angle]/2)) if four

  ptz
end

##
# Fetch a surface's subsurface opening areas & vertices.
#
# @param [OpenStudio::Model::Model] model An OpenStudio model
# @param [OpenStudio::Model::Surface] surface An OpenStudio surface
#
# @return [Hash] Returns surface with key attributes, including openings.
def openings(model, surface)
  surf = {}

  unless model && model.is_a?(OpenStudio::Model::Model)
    msg = "Can't find OpenStudio model for 'openings' - skipping"
    TBD.log(TBD::DEBUG, msg)
    return nil
  end
  unless surface && surface.is_a?(OpenStudio::Model::Surface)
    msg = "Can't find OpenStudio surface for 'openings' - skipping"
    TBD.log(TBD::DEBUG, msg)
    return nil
  end

  identifier = surface.nameString

  if surface.space.empty?
    msg = "Can't find space holding '#{identifier}' - skipping"
    TBD.log(TBD::ERROR, msg)
    return nil
  end
  surf[:space] = surface.space.get

  a = surf[:space].spaceType.empty?
  surf[:stype] = surf[:space].spaceType.get unless a
  a = surf[:space].buildingStory.empty?
  surf[:story] = surf[:space].buildingStory.get unless a

  # Site-specific (or absolute, or true) surface normal.
  t, r = transforms(model, surf[:space])
  unless t && r
    msg = "Can't process '#{identifier}' space transformation"
    TBD.log(TBD::FATAL, msg)
    return nil
  end

  n = trueNormal(surface, r)
  unless n
    msg = "Can't process '#{identifier}' true normal"
    TBD.log(TBD::FATAL, msg)
    return nil
  end
  surf[:n] = n

  surf[:gross] = surface.grossArea
  fd = false
  subs = {}

  subsurfaces = surface.subSurfaces.sort_by { |s| s.nameString }
  subsurfaces.each do |s|
    id = s.nameString

    unless s.vertices.size == 3 || s.vertices.size == 4
      msg = "Subsurface '#{id}' vertex count (must be 3 or 4) - skipping"
      TBD.log(TBD::ERROR, msg)
      next
    end

    typ = s.subSurfaceType.downcase
    type = :skylight
    type = :window if typ.include?("window")
    type = :door if typ.include?("door")
    glazed = true if type == :door && typ.include?("glass")

    gross = s.grossArea
    if gross < TOL
      msg = "Subsurface '#{id}' gross area (< TOL) - skipping"
      TBD.log(TBD::ERROR, msg)
      next
    end

    c = s.construction
    if c.empty?
      msg = "Subsurface '#{id}' missing construction - skipping"
      TBD.log(TBD::ERROR, msg)
      next
    end
    c = c.get.to_Construction.get

    # A subsurface may have an overall U-factor set by the user - a less
    # accurate option, yet easier to process (and often the only option
    # available). With EnergyPlus' "simple window" model, a subsurface's
    # construction has a single SimpleGlazing material/layer holding the whole
    # product U-factor.
    #
    #   https://bigladdersoftware.com/epx/docs/9-5/engineering-reference/
    #   window-calculation-module.html#simple-window-model
    #
    # In other cases, TBD will recover an 'additional property' tagged
    # "uFactor", assigned either to the individual subsurface itself, or else
    # assigned to its referenced construction (a more generic fallback).
    #
    # If all else fails, TBD will calculate an approximate whole product
    # U-factor by adding up the subsurface's construction material thermal
    # resistances (as well as the subsurface's parent surface film resistances).
    # This is the least accurate option, especially if subsurfaces have Frame
    # & Divider objects.

    u = s.uFactor
    u = s.additionalProperties.getFeatureAsDouble("uFactor") if u.empty?
    u = c.additionalProperties.getFeatureAsDouble("uFactor") if u.empty?
    if u.empty?
      r = rsi(c, surface.filmResistance)
      if r < TOL
        msg = "Subsurface '#{id}' U-factor unavailable - skipping"
        TBD.log(TBD::ERROR, msg)
        next
      else
        u = 1.0 / r
      end
    else
      u = u.get
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
    four = (s.vertices.size == 4)

    if s.windowPropertyFrameAndDivider.empty?
      vec = s.vertices
      area = gross
    else
      fd = true
      width = s.windowPropertyFrameAndDivider.get.frameWidth
      ptz = offset(s.vertices, width)

      # Re-convert Topolys 3D points into OpenStudio 3D points.
      vec = OpenStudio::Point3dVector.new
      vec << OpenStudio::Point3d.new(ptz[:A][:p].x, ptz[:A][:p].y, ptz[:A][:p].z)
      vec << OpenStudio::Point3d.new(ptz[:B][:p].x, ptz[:B][:p].y, ptz[:B][:p].z)
      vec << OpenStudio::Point3d.new(ptz[:C][:p].x, ptz[:C][:p].y, ptz[:C][:p].z)
      vec << OpenStudio::Point3d.new(ptz[:D][:p].x, ptz[:D][:p].y, ptz[:D][:p].z) if four
      area = OpenStudio::getArea(vec).get
    end

    sub = { v:      s.vertices,
            points: vec,
            n:      n,
            gross:  gross,
            area:   area,
            type:   type,
            u:      u }

    sub[:glazed] = true if glazed
    subs[id] = sub
  end

  # Test for conflicts (with fits?, overlaps?) between surfaces to determine
  # whether to keep original points or switch to std::vector of revised
  # coordinates, offset by Frame & Divider frame width. This will also
  # inadvertently catch pre-existing (yet nonetheless invalid) OpenStudio inputs
  # (without Frame & Dividers).
  valid = true
  subs.each do |id, sub|
    next unless fd
    next unless valid
    unless fits?(sub[:points], surface.vertices, id, identifier)
      msg = "Subsurface '#{id}' can't fit in '#{identifier}' - skipping"
      TBD.log(TBD::ERROR, msg)
      valid = false
    end
    subs.each do |i, sb|
      next unless valid
      next if i == id
      if overlaps?(sb[:points], sub[:points], id, identifier)
        msg = "Subsurface '#{id}' overlaps sibling '#{i}' - skipping"
        TBD.log(TBD::ERROR, msg)
        valid = false
      end
    end
  end

  if fd
    if valid
      # No conflicts. Reset subsurface gross area.
      subs.values.each { |sub| sub[:gross] = sub[:area] }
    else
      # One or more conflicts between the parent surface & one or more
      # subsurfaces, or between subsurfaces. Ignore Frame & Divider offsets
      # and revert to original vertices.
      subs.values.each { |sub| sub[:points] = sub[:v] }
      subs.values.each { |sub| sub[:area] = sub[:gross] }
    end
  end

  subarea = 0
  subs.values.each { |sub| subarea += sub[:area] }
  surf[:net] = surf[:gross] - subarea

  # Tranform final Point 3D sets, and store.
  pts = (t * surface.vertices).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }
  surf[:points] = pts
  surf[:minz] = ( pts.map { |p| p.z } ).min

  subs.each do |id, sub|
    pts = (t * sub[:points]).map { |v| Topolys::Point3D.new(v.x, v.y, v.z) }
    sub[:points] = pts
    sub[:minz] = ( pts.map { |p| p.z } ).min

    if sub[:type] == :window
      surf[:windows] = {} unless surf.has_key?(:windows)
      surf[:windows][id] = sub
    elsif sub[:type] == :door
      surf[:doors] = {} unless surf.has_key?(:doors)
      surf[:doors][id] = sub
    else # skylight
      surf[:skylights] = {} unless surf.has_key?(:skylights)
      surf[:skylights][id] = sub
    end
  end
  surf
end
