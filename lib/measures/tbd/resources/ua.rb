require "openstudio"

# Generate reference values for points, edges & surfaces (& subsurfaces) to
# compute Quebec energy code (Section 3.3) UA' comparison (2021).
#
# @param [Hash] surfaces Preprocessed collection of TBD surfaces
# @param [Has] sets A model's PSI sets
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
    next unless surface.has_key?(:heating)
    heating = surface[:heating]
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
