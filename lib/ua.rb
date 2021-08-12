require "openstudio"

# Set reference values for points, edges & surfaces (& subsurfaces) to
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
# @param [Time] date Time stamp
# @param [String] version OpenStudio version (optional)
# @param [String] descr Project description (optional)
# @param [String] file OSM file name (optional)
# @param [String] ref UA' reference (optional)
#
# @return [Hash] Returns binned values for UA' summary.
def ua_summary(surfaces, date = Time.now, version = "",
               descr = "", file = "", ref = "")
  ua = {}

  unless surfaces && surfaces.is_a?(Hash)
    TBD.log(TBD::DEBUG, "Can't process UA' results - invalid arguments")
    return ua
  end
  return ua if surfaces.empty?

  ua[:en] = {}
  ua[:fr] = {}
  ua[:model] = "∑U•A + ∑PSI•L + ∑KHI•n"
  ua[:date] = date
  ua[:version] = version unless version.nil? || version.empty?
  ua[:descr] = descr unless descr.nil? || descr.empty?
  ua[:file] = file unless file.nil? || file.empty?

  walls  = { net: 0, gross: 0, subs: 0 }
  roofs  = { net: 0, gross: 0, subs: 0 }
  floors = { net: 0, gross: 0, subs: 0 }
  areas  = { walls: walls, roofs: roofs, floors: floors }

  has = {}
  val = {}
  unless ref.empty?
    psi = PSI.new
    has, val = psi.shorthands(ref)
    if has.empty? || val.empty?
      TBD.log(TBD::ERROR, "Invalid UA' reference set - skipping")
    else
      case ref
      when "code (Quebec)"
        ua[:model] += " : Design vs 'code (Quebec)'"
        ua[:en][:objective] = "COMPLIANCE ASSESSMENT"
        ua[:en][:details] = []
        ua[:en][:details] << "Quebec Construction Code, Chapter I.1"
        ua[:en][:details] << "NECB 2015, modified version (2020)"
        ua[:en][:details] << "Division B, Section 3.3"
        ua[:en][:details] << "Building Envelope Trade-off Path"

        ua[:en][:notes] = "Automated assessement from the OpenStudio "         \
          "Measure, Thermal Bridging and Derating (TBD). Open source and MIT-" \
          "licensed, TBD is provided as is (without warranty). Results are "   \
          "based on user input not subject to prior validation (see "          \
          "DESCRIPTION), and as such the assessment shall not be considered "  \
          "as a certification of compliance. Calculations, which comply with " \
          "Section 3.3 requirements, are described and documented in the "     \
          "source code: https://github.com/rd2/tbd."

        ua[:fr][:objective] = "ANALYSE DE CONFORMITÉ"
        ua[:fr][:details] = []
        ua[:fr][:details] << "Code de construction du Québec, Chapitre I.1"
        ua[:fr][:details] << "CNÉB 2015, version modifiée (2020)"
        ua[:fr][:details] << "Division B, Section 3.3"
        ua[:fr][:details] << "Méthode des solutions de remplacement"

        ua[:fr][:notes] = "Analyse automatisée réalisée par la "                \
          "measure OpenStudio, 'Thermal Bridging and Derating' (ou TBD). "     \
          "Distribuée librement (licence MIT), TBD est offerte "               \
          "telle quelle (sans garantie). Les résultats sont tributaires "      \
          "d'intrants fournis par l'utilisateur sans validation préalable "    \
          "(voir DESCRIPTION). L'analyse n'est donc pas une attestation "      \
          "de conformité. Les calculs, conformes aux dispositions de la "      \
          "Section 3.3, sont décrits et documentés au sein du code source : "  \
          "https://github.com/rd2/tbd."
      else
        # More to come ...
      end
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
          other:   0 } # includes party wall edges, expansion joints, etc.

  b1 = {}
  b2 = {}
  b1[:pro] = blc                                              #  proposed design
  b1[:ref] = blc.clone                                        #        reference
  b2[:pro] = blc.clone                                        #  proposed design
  b2[:ref] = blc.clone                                        #        reference

  # Loop through surfaces, subsurfaces and edges and populate bloc1 & bloc2.
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

    bloc = b1
    bloc = b2 if heating < 18

    reference = surface.has_key?(:ref)
    if type == :wall
      areas[:walls][:net] += surface[:net]
      bloc[:pro][:walls] += surface[:net] * surface[:u]
      bloc[:ref][:walls] += surface[:net] * surface[:ref] if reference
    elsif type == :ceiling
      areas[:roofs][:net] += surface[:net]
      bloc[:pro][:roofs] += surface[:net] * surface[:u]
      bloc[:ref][:roofs] += surface[:net] * surface[:ref] if reference
    else
      areas[:floors][:net] += surface[:net]
      bloc[:pro][:floors] += surface[:net] * surface[:u]
      bloc[:ref][:floors] += surface[:net] * surface[:ref] if reference
    end

    if surface.has_key?(:doors)
      surface[:doors].values.each do |door|
        next unless door.has_key?(:gross)
        next unless door[:gross] > TOL
        next unless door.has_key?(:u)
        next unless door[:u] > TOL
        areas[:walls][:subs] += door[:gross] if type == :wall
        areas[:roofs][:subs] += door[:gross] if type == :ceiling
        areas[:floors][:subs] += door[:gross] if type == :floor
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
        areas[:walls][:subs] += window[:gross] if type == :wall
        areas[:roofs][:subs] += window[:gross] if type == :ceiling
        areas[:floors][:subs] += window[:gross] if type == :floor
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
        areas[:walls][:subs] += sky[:gross] if type == :wall
        areas[:roofs][:subs] += sky[:gross] if type == :ceiling
        areas[:floors][:subs] += sky[:gross] if type == :floor
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
        when /head/i
          bloc[:pro][:trim] += loss
        when /sill/i
          bloc[:pro][:trim] += loss
        when /jamb/i
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

        case tt.to_s
        when /rimjoist/i
          bloc[:ref][:rimjoists] += loss
        when /parapet/i
          bloc[:ref][:parapets] += loss
        when /fenestration/i
          bloc[:ref][:trim] += loss
        when /head/i
          bloc[:ref][:trim] += loss
        when /sill/i
          bloc[:ref][:trim] += loss
        when /jamb/i
          bloc[:ref][:trim] += loss
        when /corner/i
          bloc[:ref][:corners] += loss
        when /grade/i
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

  # Fully-heated summary.
  pro_sum = b1[:pro].values.reduce(:+)
  ref_sum = b1[:ref].values.reduce(:+)

  if pro_sum > TOL
    ratio = nil
    ratio = 100.0 * (pro_sum - ref_sum) / ref_sum if ref_sum > TOL
    str = format("%.1f W/K (vs %.1f W/K)", pro_sum, ref_sum)
    str += format(" +%.1f%%", ratio) if ratio && pro_sum > ref_sum # **
    str += format(" -%.1f%%", ratio) if ratio && pro_sum < ref_sum
    ua[:en][:b1] = {}
    ua[:fr][:b1] = {}
    ua[:en][:b1][:summary] = "heated : #{str}"
    ua[:fr][:b1][:summary] = "chauffé : #{str}"

    # ** https://bugs.ruby-lang.org/issues/13761 (Ruby > 2.2.5)
    # str += format(" +%.1f%", ratio) if ratio && pro_sum > ref_sum ... becomes
    # str += format(" +%.1f%%", ratio) if ratio && pro_sum > ref_sum

    b1[:pro].each do |k, v|
      rf = b1[:ref][k]
      next if v < TOL && rf < TOL
      ratio = nil
      ratio = 100.0 * (v - rf) / rf if rf > TOL
      str = format("%.1f W/K (vs %.1f W/K)", v, rf)
      str += format(" +%.1f%%", ratio) if v > rf
      str += format(" -%.1f%%", ratio) if v < rf

      case k
      when :walls
        ua[:en][:b1][k] = "walls : #{str}"
        ua[:fr][:b1][k] = "murs : #{str}"
      when :roofs
        ua[:en][:b1][k] = "roofs : #{str}"
        ua[:fr][:b1][k] = "toits : #{str}"
      when :floors
        ua[:en][:b1][k] = "floors : #{str}"
        ua[:fr][:b1][k] = "planchers : #{str}"
      when :doors
        ua[:en][:b1][k] = "doors : #{str}"
        ua[:fr][:b1][k] = "portes : #{str}"
      when :windows
        ua[:en][:b1][k] = "windows : #{str}"
        ua[:fr][:b1][k] = "fenêtres : #{str}"
      when :skylights
        ua[:en][:b1][k] = "skylights : #{str}"
        ua[:fr][:b1][k] = "lanterneaux : #{str}"
      when :rimjoists
        ua[:en][:b1][k] = "rimjoists : #{str}"
        ua[:fr][:b1][k] = "rives : #{str}"
      when :parapets
        ua[:en][:b1][k] = "parapets : #{str}"
        ua[:fr][:b1][k] = "parapets : #{str}"
      when :trim
        ua[:en][:b1][k] = "trim : #{str}"
        ua[:fr][:b1][k] = "chassis : #{str}"
      when :corners
        ua[:en][:b1][k] = "corners : #{str}"
        ua[:fr][:b1][k] = "coins : #{str}"
      when :balconies
        ua[:en][:b1][k] = "balconies : #{str}"
        ua[:fr][:b1][k] = "balcons : #{str}"
      when :grade
        ua[:en][:b1][k] = "grade : #{str}"
        ua[:fr][:b1][k] = "tracé : #{str}"
      else
        ua[:en][:b1][k] = "other : #{str}"
        ua[:fr][:b1][k] = "autres : #{str}"
      end
    end

    # Deterministic sorting
    ua[:en][:b1][:summary] = ua[:en][:b1].delete(:summary)
    if ua[:en][:b1].has_key?(:walls)
      ua[:en][:b1][:walls] = ua[:en][:b1].delete(:walls)
    end
    if ua[:en][:b1].has_key?(:roofs)
      ua[:en][:b1][:roofs] = ua[:en][:b1].delete(:roofs)
    end
    if ua[:en][:b1].has_key?(:floors)
      ua[:en][:b1][:floors] = ua[:en][:b1].delete(:floors)
    end
    if ua[:en][:b1].has_key?(:doors)
      ua[:en][:b1][:doors] = ua[:en][:b1].delete(:doors)
    end
    if ua[:en][:b1].has_key?(:windows)
      ua[:en][:b1][:windows] = ua[:en][:b1].delete(:windows)
    end
    if ua[:en][:b1].has_key?(:skylights)
      ua[:en][:b1][:skylights] = ua[:en][:b1].delete(:skylights)
    end
    if ua[:en][:b1].has_key?(:rimjoists)
      ua[:en][:b1][:rimjoists] = ua[:en][:b1].delete(:rimjoists)
    end
    if ua[:en][:b1].has_key?(:parapets)
      ua[:en][:b1][:parapets] = ua[:en][:b1].delete(:parapets)
    end
    if ua[:en][:b1].has_key?(:trim)
      ua[:en][:b1][:trim] = ua[:en][:b1].delete(:trim)
    end
    if ua[:en][:b1].has_key?(:corners)
      ua[:en][:b1][:corners] = ua[:en][:b1].delete(:corners)
    end
    if ua[:en][:b1].has_key?(:balconies)
      ua[:en][:b1][:balconies] = ua[:en][:b1].delete(:balconies)
    end
    if ua[:en][:b1].has_key?(:grade)
      ua[:en][:b1][:grade] = ua[:en][:b1].delete(:grade)
    end
    if ua[:en][:b1].has_key?(:other)
      ua[:en][:b1][:other] = ua[:en][:b1].delete(:other)
    end

    ua[:fr][:b1][:summary] = ua[:fr][:b1].delete(:summary)
    if ua[:fr][:b1].has_key?(:walls)
      ua[:fr][:b1][:walls] = ua[:fr][:b1].delete(:walls)
    end
    if ua[:fr][:b1].has_key?(:roofs)
      ua[:fr][:b1][:roofs] = ua[:fr][:b1].delete(:roofs)
    end
    if ua[:fr][:b1].has_key?(:floors)
      ua[:fr][:b1][:floors] = ua[:fr][:b1].delete(:floors)
    end
    if ua[:fr][:b1].has_key?(:doors)
      ua[:fr][:b1][:doors] = ua[:fr][:b1].delete(:doors)
    end
    if ua[:fr][:b1].has_key?(:windows)
      ua[:fr][:b1][:windows] = ua[:fr][:b1].delete(:windows)
    end
    if ua[:fr][:b1].has_key?(:skylights)
      ua[:fr][:b1][:skylights] = ua[:fr][:b1].delete(:skylights)
    end
    if ua[:fr][:b1].has_key?(:rimjoists)
      ua[:fr][:b1][:rimjoists] = ua[:fr][:b1].delete(:rimjoists)
    end
    if ua[:fr][:b1].has_key?(:parapets)
      ua[:fr][:b1][:parapets] = ua[:fr][:b1].delete(:parapets)
    end
    if ua[:fr][:b1].has_key?(:trim)
      ua[:fr][:b1][:trim] = ua[:fr][:b1].delete(:trim)
    end
    if ua[:fr][:b1].has_key?(:corners)
      ua[:fr][:b1][:corners] = ua[:fr][:b1].delete(:corners)
    end
    if ua[:fr][:b1].has_key?(:balconies)
      ua[:fr][:b1][:balconies] = ua[:fr][:b1].delete(:balconies)
    end
    if ua[:fr][:b1].has_key?(:grade)
      ua[:fr][:b1][:grade] = ua[:fr][:b1].delete(:grade)
    end
    if ua[:fr][:b1].has_key?(:other)
      ua[:fr][:b1][:other] = ua[:fr][:b1].delete(:other)
    end
  end

  # Repeat for semi-heated.
  pro_sum = b2[:pro].values.reduce(:+)
  ref_sum = b2[:ref].values.reduce(:+)

  if pro_sum > TOL
    ratio = nil
    ratio = 100.0 * (pro_sum - ref_sum) / ref_sum if ref_sum > TOL
    str = format("%.1f W/K (vs %.1f W/K)", pro_sum, ref_sum)
    str += format(" +%.1f%%", ratio) if ratio && pro_sum > ref_sum
    str += format(" -%.1f%%", ratio) if ratio && pro_sum < ref_sum
    ua[:en][:b2] = {}
    ua[:fr][:b2] = {}
    ua[:en][:b2][:summary] = "semi-heated : #{str}"
    ua[:fr][:b2][:summary] = "semi-chauffé : #{str}"

    b2[:pro].each do |k, v|
      rf = b2[:ref][k]
      next if v < TOL && rf < TOL
      ratio = nil
      ratio = 100.0 * (v - rf) / rf if rf > TOL
      str = format("%.1f W/K (vs %.1f W/K)", v, rf)
      str += format(" +%.1f%%", ratio) if v > rf
      str += format(" -%.1f%%", ratio) if v < rf

      case k
      when :walls
        ua[:en][:b2][k] = "walls : #{str}"
        ua[:fr][:b2][k] = "murs : #{str}"
      when :roofs
        ua[:en][:b2][k] = "roofs : #{str}"
        ua[:fr][:b2][k] = "toits : #{str}"
      when :floors
        ua[:en][:b2][k] = "floors : #{str}"
        ua[:fr][:b2][k] = "planchers : #{str}"
      when :doors
        ua[:en][:b2][k] = "doors : #{str}"
        ua[:fr][:b2][k] = "portes : #{str}"
      when :windows
        ua[:en][:b2][k] = "windows : #{str}"
        ua[:fr][:b2][k] = "fenêtres : #{str}"
      when :skylights
        ua[:en][:b2][k] = "skylights : #{str}"
        ua[:fr][:b2][k] = "lanterneaux : #{str}"
      when :rimjoists
        ua[:en][:b2][k] = "rimjoists : #{str}"
        ua[:fr][:b2][k] = "rives : #{str}"
      when :parapets
        ua[:en][:b2][k] = "parapets : #{str}"
        ua[:fr][:b2][k] = "parapets : #{str}"
      when :trim
        ua[:en][:b2][k] = "trim : #{str}"
        ua[:fr][:b2][k] = "chassis : #{str}"
      when :corners
        ua[:en][:b2][k] = "corners : #{str}"
        ua[:fr][:b2][k] = "coins : #{str}"
      when :balconies
        ua[:en][:b2][k] = "balconies : #{str}"
        ua[:fr][:b2][k] = "balcons : #{str}"
      when :grade
        ua[:en][:b2][k] = "grade : #{str}"
        ua[:fr][:b2][k] = "tracé : #{str}"
      else
        ua[:en][:b2][k] = "other : #{str}"
        ua[:fr][:b2][k] = "autres : #{str}"
      end
    end

    # Deterministic sorting
    ua[:en][:b2][:summary] = ua[:en][:b2].delete(:summary)
    if ua[:en][:b2].has_key?(:walls)
      ua[:en][:b2][:walls] = ua[:en][:b2].delete(:walls)
    end
    if ua[:en][:b2].has_key?(:roofs)
      ua[:en][:b2][:roofs] = ua[:en][:b2].delete(:roofs)
    end
    if ua[:en][:b2].has_key?(:floors)
      ua[:en][:b2][:floors] = ua[:en][:b2].delete(:floors)
    end
    if ua[:en][:b2].has_key?(:doors)
      ua[:en][:b2][:doors] = ua[:en][:b2].delete(:doors)
    end
    if ua[:en][:b2].has_key?(:windows)
      ua[:en][:b2][:windows] = ua[:en][:b2].delete(:windows)
    end
    if ua[:en][:b2].has_key?(:skylights)
      ua[:en][:b2][:skylights] = ua[:en][:b2].delete(:skylights)
    end
    if ua[:en][:b2].has_key?(:rimjoists)
      ua[:en][:b2][:rimjoists] = ua[:en][:b2].delete(:rimjoists)
    end
    if ua[:en][:b2].has_key?(:parapets)
      ua[:en][:b2][:parapets] = ua[:en][:b2].delete(:parapets)
    end
    if ua[:en][:b2].has_key?(:trim)
      ua[:en][:b2][:trim] = ua[:en][:b2].delete(:trim)
    end
    if ua[:en][:b2].has_key?(:corners)
      ua[:en][:b2][:corners] = ua[:en][:b2].delete(:corners)
    end
    if ua[:en][:b2].has_key?(:balconies)
      ua[:en][:b2][:balconies] = ua[:en][:b2].delete(:balconies)
    end
    if ua[:en][:b2].has_key?(:grade)
      ua[:en][:b2][:grade] = ua[:en][:b2].delete(:grade)
    end
    if ua[:en][:b2].has_key?(:other)
      ua[:en][:b2][:other] = ua[:en][:b2].delete(:other)
    end

    ua[:fr][:b2][:summary] = ua[:fr][:b2].delete(:summary)
    if ua[:fr][:b2].has_key?(:walls)
      ua[:fr][:b2][:walls] = ua[:fr][:b2].delete(:walls)
    end
    if ua[:fr][:b2].has_key?(:roofs)
      ua[:fr][:b2][:roofs] = ua[:fr][:b2].delete(:roofs)
    end
    if ua[:fr][:b2].has_key?(:floors)
      ua[:fr][:b2][:floors] = ua[:fr][:b2].delete(:floors)
    end
    if ua[:fr][:b2].has_key?(:doors)
      ua[:fr][:b2][:doors] = ua[:fr][:b2].delete(:doors)
    end
    if ua[:fr][:b2].has_key?(:windows)
      ua[:fr][:b2][:windows] = ua[:fr][:b2].delete(:windows)
    end
    if ua[:fr][:b2].has_key?(:skylights)
      ua[:fr][:b2][:skylights] = ua[:fr][:b2].delete(:skylights)
    end
    if ua[:fr][:b2].has_key?(:rimjoists)
      ua[:fr][:b2][:rimjoists] = ua[:fr][:b2].delete(:rimjoists)
    end
    if ua[:fr][:b2].has_key?(:parapets)
      ua[:fr][:b2][:parapets] = ua[:fr][:b2].delete(:parapets)
    end
    if ua[:fr][:b2].has_key?(:trim)
      ua[:fr][:b2][:trim] = ua[:fr][:b2].delete(:trim)
    end
    if ua[:fr][:b2].has_key?(:corners)
      ua[:fr][:b2][:corners] = ua[:fr][:b2].delete(:corners)
    end
    if ua[:fr][:b2].has_key?(:balconies)
      ua[:fr][:b2][:balconies] = ua[:fr][:b2].delete(:balconies)
    end
    if ua[:fr][:b2].has_key?(:grade)
      ua[:fr][:b2][:grade] = ua[:fr][:b2].delete(:grade)
    end
    if ua[:fr][:b2].has_key?(:other)
      ua[:fr][:b2][:other] = ua[:fr][:b2].delete(:other)
    end
  end

  # Areas (m2).
  areas[:walls][:gross] = areas[:walls][:net] + areas[:walls][:subs]
  areas[:roofs][:gross] = areas[:roofs][:net] + areas[:roofs][:subs]
  areas[:floors][:gross] = areas[:floors][:net] + areas[:floors][:subs]
  ua[:en][:areas] = {}
  ua[:fr][:areas] = {}

  str = format("walls : %.1f m2 (net)", areas[:walls][:net])
  str += format(", %.1f m2 (gross)", areas[:walls][:gross])
  ua[:en][:areas][:walls] = str unless areas[:walls][:gross] < TOL
  str = format("roofs : %.1f m2 (net)", areas[:roofs][:net])
  str += format(", %.1f m2 (gross)", areas[:roofs][:gross])
  ua[:en][:areas][:roofs] = str unless areas[:roofs][:gross] < TOL
  str = format("floors : %.1f m2 (net)", areas[:floors][:net])
  str += format(", %.1f m2 (gross)", areas[:floors][:gross])
  ua[:en][:areas][:floors] = str unless areas[:floors][:gross] < TOL

  str = format("murs : %.1f m2 (net)", areas[:walls][:net])
  str += format(", %.1f m2 (brut)", areas[:walls][:gross])
  ua[:fr][:areas][:walls] = str unless areas[:walls][:gross] < TOL
  str = format("toits : %.1f m2 (net)", areas[:roofs][:net])
  str += format(", %.1f m2 (brut)", areas[:roofs][:gross])
  ua[:fr][:areas][:roofs] = str unless areas[:roofs][:gross] < TOL
  str = format("planchers : %.1f m2 (net)", areas[:floors][:net])
  str += format(", %.1f m2 (brut)", areas[:floors][:gross])
  ua[:fr][:areas][:floors] = str unless areas[:floors][:gross] < TOL

  ua
end

# Generate MD-formatted file.
#
# @param [Hash] ua Preprocessed collection of UA-related strings
# @param [String] lang Preferred language ("en" vs "fr")
#
# @return [Array] Returns MD-formatted strings.
def ua_md(ua, lang = :en)
  report = []

  unless ua && ua.is_a?(Hash)
    TBD.log(TBD::DEBUG, "Can't generate UA' MD report - invalid arguments")
    return report
  end
  if ua.empty?
    TBD.log(TBD::DEBUG, "Can't generate UA' MD report - empty summary")
    return report
  end
  unless ua.has_key?(lang)
    TBD.log(TBD::DEBUG, "Can't generate UA' MD report - language mismatch")
    return report
  end

  if lang == :en && ua[:en].has_key?(:objective)
    report << "# #{ua[:en][:objective]}   "
    report << "   "
  elsif lang == :fr && ua[:fr].has_key?(:objective)
    report << "# #{ua[:fr][:objective]}   "
    report << "   "
  end

  if lang == :en && ua[:en].has_key?(:details)
    ua[:en][:details].each { |d| report << "#{d}   " }
    report << "   "
  elsif lang == :fr && ua[:fr].has_key?(:details)
    ua[:fr][:details].each { |d| report << "#{d}   " }
    report << "   "
  end

  if lang == :en && ua.has_key?(:model)
    report << "##### SUMMARY   "
    report << "   "
    report << "#{ua[:model]}   "
    report << "   "
  elsif lang == :fr && ua.has_key?(:model)
    report << "##### SOMMAIRE   "
    report << "   "
    report << "#{ua[:model]}   "
    report << "   "
  end

  if lang == :en && ua[:en].has_key?(:b1)
    if ua[:en][:b1].has_key?(:summary)
      last = ua[:en][:b1].keys.to_a.last
      report << "* #{ua[:en][:b1][:summary]}"
      ua[:en][:b1].each do |k, v|
        next if k == :summary
        report << "  * #{v}" unless k == last
        report << "  * #{v}   " if k == last
        report << "   " if k == last
      end
      report << "   "
    end
  elsif lang == :fr && ua[:fr].has_key?(:b1)
    if ua[:fr][:b1].has_key?(:summary)
      last = ua[:fr][:b1].keys.to_a.last
      report << "* #{ua[:fr][:b1][:summary]}"
      ua[:fr][:b1].each do |k, v|
        next if k == :summary
        report << "  * #{v}" unless k == last
        report << "  * #{v}   " if k == last
        report << "   " if k == last
      end
      report << "   "
    end
  end

  if lang == :en && ua[:en].has_key?(:b2)
    if ua[:en][:b2].has_key?(:summary)
      last = ua[:en][:b2].keys.to_a.last
      report << "* #{ua[:en][:b2][:summary]}"
      ua[:en][:b2].each do |k, v|
        next if k == :summary
        report << "  * #{v}" unless k == last
        report << "  * #{v}   " if k == last
        report << "   " if k == last
      end
      report << "   "
    end
  elsif lang == :fr && ua[:fr].has_key?(:b2)
    last = ua[:fr][:b2].keys.to_a.last
    if ua[:fr][:b2].has_key?(:summary)
      report << "* #{ua[:fr][:b2][:summary]}"
      ua[:fr][:b2].each do |k, v|
        next if k == :summary
        report << "  * #{v}" unless k == last
        report << "  * #{v}   " if k == last
        report << "   " if k == last
      end
      report << "   "
    end
  end

  if lang == :en && ua.has_key?(:date)
    report << "##### DESCRIPTION   "
    report << "   "
    report << "* project : #{ua[:descr]}" if ua.has_key?(:descr)
    model = ""
    model = "* model : #{ua[:file]}" if ua.has_key?(:file)
    model += " (v#{ua[:version]})" if ua.has_key?(:version)
    report << model unless model.empty?
    report << "* TBD version : v2.2.0"
    report << "* date : #{ua[:date]}"
    report << "* status : #{TBD.msg(TBD.status)}" unless TBD.status.zero?
    report << "* status : success !" if TBD.status.zero?
    report << "   "
  elsif lang == :fr && ua.has_key?(:date)
    report << "##### DESCRIPTION   "
    report << "   "
    report << "* projet : #{ua[:descr]}" if ua.has_key?(:descr)
    model = ""
    model = "* modèle : #{ua[:file]}" if ua.has_key?(:file)
    model += " (v#{ua[:version]})" if ua.has_key?(:version)
    report << model unless model.empty?
    report << "* TBD version : v2.2.0"
    report << "* date : #{ua[:date]}"
    report << "* statut : #{TBD.msg(TBD.status)}" unless TBD.status.zero?
    report << "* status : succès !" if TBD.status.zero?
    report << "   "
  end

  if lang == :en && ua[:en].has_key?(:areas)
    report << "##### AREAS   "
    report << "   "
    if ua[:en][:areas].has_key?(:walls)
      report << "* #{ua[:en][:areas][:walls]}"
    end
    if ua[:en][:areas].has_key?(:roofs)
      report << "* #{ua[:en][:areas][:roofs]}"
    end
    if ua[:en][:areas].has_key?(:floors)
      report << "* #{ua[:en][:areas][:floors]}"
    end
    report << "   "
  elsif lang == :fr && ua[:en].has_key?(:areas)
    report << "##### AIRES   "
    report << "   "
    if ua[:fr][:areas].has_key?(:walls)
      report << "* #{ua[:fr][:areas][:walls]}"
    end
    if ua[:fr][:areas].has_key?(:roofs)
      report << "* #{ua[:fr][:areas][:roofs]}"
    end
    if ua[:fr][:areas].has_key?(:floors)
      report << "* #{ua[:fr][:areas][:floors]}"
    end
    report << "   "
  end

  if lang == :en && ua[:en].has_key?(:notes)
    report << "##### NOTES   "
    report << "   "
    report << "#{ua[:en][:notes]}   "
    report << "   "
  elsif lang == :fr && ua[:fr].has_key?(:notes)
    report << "##### NOTES   "
    report << "   "
    report << "#{ua[:fr][:notes]}   "
    report << "   "
  end

  report
end
