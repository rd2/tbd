require "openstudio"

# Generate reference values for points, edges & surfaces (& subsurfaces) to
# compute Quebec energy code (Section 3.3) UA' comparison (2021).
#
# @param [Hash] surfaces Preprocessed collection of TBD surfaces
# @param [Hash] sets A model's PSI sets
#
# @return [Bool] Returns true if successful in generating UA' reference values
def qc33(surfaces, sets)
  unless surfaces && surfaces.is_a?(Hash) && sets && sets.is_a?(PSI)
    TBD.log(TBD::DEBUG,
      "Can't process Quebec energy code UA' inputs - invalid arguments")
    return false
  end

  has, val = sets.shorthands("code (Quebec)")
  if has.empty? || val.empty?
    TBD.log(TBD::DEBUG,
      "Missing Quebec energy code PSI set for 3.3 UA' tradeoff")
    return false
  end

  surfaces.each do |id, surface|
    next unless surface.has_key?(:deratable)
    next unless surface[:deratable]
    next unless surface.has_key?(:type)
    heating = 21.0
    heating = surface[:heating] if surface.has_key?(:heating)
    cooling = 50.0
    cooling = surface[:cooling] if surface.has_key?(:cooling)

    # Start with surface U-factors.
    ref = 1.0 / 5.46
    ref = 1.0 / 3.60 if surface[:type] == :wall

    # Adjust for lower heating setpoint (assumes -25°C design conditions).
    ref *= 43.0 / (heating + 25.0) if heating < 18.0 && cooling >= 18.0

    # And store.
    surface[:ref] = ref

    # Loop through subsurfaces.
    if surface.has_key?(:skylights)
      ref = 2.85
      ref *= 43.0 / (heating + 25.0) if heating < 18.0 && cooling >= 18.0
      surface[:skylights].values.map { |skylight| skylight[:ref] = ref }
    end

    if surface.has_key?(:windows)
      ref = 2.0
      ref *= 43.0 / (heating + 25.0) if heating < 18.0 && cooling >= 18.0
      surface[:windows].values.map { |window| window[:ref] = ref }
    end

    if surface.has_key?(:doors)
      surface[:doors].each do |i, door|
        ref = 0.9
        ref = 2.0 if door.has_key?(:glazed) && door[:glazed]
        ref *= 43.0 / (heating + 25.0) if heating < 18.0 && cooling >= 18.0
        door[:ref] = ref
      end
    end

    # Loop through point thermal bridges.
    if surface.has_key?(:pts)
      surface[:pts].map { |i, pt| pt[:ref] = 0.5 }
    end

    # Loop through linear thermal bridges.
    if surface.has_key?(:edges)
      surface[:edges].values.each do |edge|
        next unless edge.has_key?(:type)
        next unless edge.has_key?(:ratio)
        tt = sets.safeType("code (Quebec)", edge[:type])
        edge[:ref] = val[tt] * edge[:ratio] if tt
      end
    end
  end
  true
end

# Generate UA' summary.
#
# @param [Hash] surfaces Preprocessed collection of TBD surfaces
# @param [String] ref UA' reference
#
# @return [Hash] Returns aggregate values for UA' summary.
def ua_summary(surfaces, ref = "")
  summary = {}

  unless surfaces && surfaces.is_a?(Hash)
    TBD.log(TBD::DEBUG, "Can't process UA' results - invalid arguments")
    return summary
  end

  has = {}
  val = {}
  unless ref.empty?
    psi = PSI.new
    has, val = psi.shorthands(ref)
    if has.empty? || val.empty?
      TBD.log(TBD::ERROR, "Invalid UA' reference set - skipping")
    end
  end

  # Set up 3x heating setpoint (HSTP) "blocks":
  #   bloc1: spaces/zones with HSTP >= 18°C
  #   bloc2: spaces/zones with HSTP < 18°C
  #   bloc3: spaces/zones without HSTP (i.e. unheated)
  #   (ref: 2021 Quebec energy code 3.3. UA' trade-off methodology)
  #   (... can be extended in the future to cover other standards)
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
  bloc1[:pro] = blc                                           #  proposed design
  bloc1[:ref] = blc.clone                                     # reference design
  bloc2[:pro] = blc.clone                                     #  proposed design
  bloc2[:ref] = blc.clone                                     # reference design

  surfaces.values.each do |surface|
    next unless surface.has_key?(:deratable)
    next unless surface[:deratable]
    next unless surface.has_key?(:type)
    type = surface[:type]
    next unless type == :wall || type == :ceiling || type == :floor
    next unless surface.has_key?(:net)
    next unless surface[:net] > TOL
    next unless surface.has_key?(:u)
    next unless surface[:u] > TOL
    heating = 21.0
    heating = surface[:heating] if surface.has_key?(:heating)
    cooling = 50.0
    cooling = surface[:cooling] if surface.has_key?(:cooling)

    bloc = bloc1
    bloc = bloc2 if heating < 18

    reference = surface.has_key?(:ref)
    if type == :wall
      bloc[:pro][:walls] += surface[:net] * surface[:u]
      bloc[:ref][:walls] += surface[:net] * surface[:ref] if reference
    elsif type == :ceiling
      bloc[:pro][:roofs] += surface[:net] * surface[:u]
      bloc[:ref][:roofs] += surface[:net] * surface[:ref] if reference
    else
      bloc[:pro][:floors] += surface[:net] * surface[:u]
      bloc[:ref][:floors] += surface[:net] * surface[:ref] if reference
    end

    if surface.has_key?(:doors)
      surface[:doors].values.each do |door|
        next unless door.has_key?(:gross)
        next unless door[:gross] > TOL
        next unless door.has_key?(:u)
        next unless door[:u] > TOL
        bloc[:pro][:doors] += door[:gross] * door[:u]
        next unless door.has_key?(:ref)
        bloc[:ref][:doors] += door[:gross] * door[:ref]
      end
    end

    if surface.has_key?(:windows)
      surface[:windows].values.each do |window|
        next unless window.has_key?(:gross)
        next unless window[:gross] > TOL
        next unless window.has_key?(:u)
        next unless window[:u] > TOL
        bloc[:pro][:windows] += window[:gross] * window[:u]
        next unless window.has_key?(:ref)
        bloc[:ref][:windows] += window[:gross] * window[:ref]
      end
    end

    if surface.has_key?(:skylights)
      surface[:skylights].values.each do |sky|
        next unless sky.has_key?(:gross)
        next unless sky[:gross] > TOL
        next unless sky.has_key?(:u)
        next unless sky[:u] > TOL
        bloc[:pro][:skylights] += sky[:gross] * sky[:u]
        next unless sky.has_key?(:ref)
        bloc[:ref][:skylights] += sky[:gross] * sky[:ref]
      end
    end

    if surface.has_key?(:edges)
      surface[:edges].values.each do |edge|
        next unless edge.has_key?(:type)
        next unless edge.has_key?(:length)
        next unless edge[:length] > TOL
        next unless edge.has_key?(:psi)

        loss = edge[:length] * edge[:psi]
        type = edge[:type].to_s

        case type
        when /rimjoist/i
          bloc[:pro][:rimjoists] += loss
        when /parapet/i
          bloc[:pro][:parapets] += loss
        when /fenestration/i
          bloc[:pro][:trim] += loss
        when /corner/i
          bloc[:pro][:corners] += loss
        when /grade/i
          bloc[:pro][:grade] += loss
        else
          bloc[:pro][:other] += loss
        end

        next unless edge.has_key?(:ref)
        next unless edge.has_key?(:ratio)
        next if val.nil?
        tt = psi.safeType(ref, edge[:type])
        loss = edge[:length] * val[tt] * edge[:ratio]
        case tt
        when :rimjoist
          bloc[:ref][:rimjoists] += loss
        when :parapet
          bloc[:ref][:parapets] += loss
        when :fenestration
          bloc[:ref][:trim] += loss
        when :corner
          bloc[:ref][:corners] += loss
        when :grade
          bloc[:ref][:grade] += loss
        else
          bloc[:ref][:other] += loss
        end
      end
    end

    if surface.has_key?(:pts)
      surface[:pts].values.each do |pts|
        next unless pts.has_key?(:val)
        next unless pts.has_key?(:n)
        bloc[:pro][:other] += pts[:val] * pts[:n]
        next unless pts.has_key?(:ref)
        bloc[:ref][:other] += pts[:ref] * pts[:n]
      end
    end
  end

  summary[:bloc1] = bloc1
  summary[:bloc2] = bloc2
  summary
end
