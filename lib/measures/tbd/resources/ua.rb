require "openstudio"

# Set reference values for points, edges & surfaces (& subsurfaces) to
# compute Quebec energy code (Section 3.3) UA' comparison (2021).
#
# @param [Hash] surfaces Preprocessed collection of TBD surfaces
# @param [Hash] sets A model's PSI sets
# @param [Bool] setpoints True if OpenStudio model has valid setpoints
#
# @return [Bool] Returns true if successful in generating UA' reference values
def qc33(surfaces, sets, setpoints)
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

  unless setpoints == true || setpoints == false
    TBD.log(TBD::DEBUG,
      "Variable 'setpoints' must be true/false for 3.3 UA' tradeoff")
    return false
  end

  surfaces.each do |id, surface|
    next unless surface.has_key?(:deratable)
    next unless surface[:deratable]
    next unless surface.has_key?(:type)
    if setpoints
      heating = -50
      cooling =  50
    else
      heating =  21
      cooling =  24
    end
    heating = surface[:heating] if surface.has_key?(:heating)
    cooling = surface[:cooling] if surface.has_key?(:cooling)

    # Start with surface U-factors.
    ref = 1.0 / 5.46
    ref = 1.0 / 3.60 if surface[:type] == :wall

    # Adjust for lower heating setpoint (assumes -25°C design conditions).
    ref *= 43.0 / (heating + 25.0) if heating < 18.0 && cooling > 40.0

    # And store.
    surface[:ref] = ref

    # Loop through subsurfaces.
    if surface.has_key?(:skylights)
      ref = 2.85
      ref *= 43.0 / (heating + 25.0) if heating < 18.0 && cooling > 40.0
      surface[:skylights].values.map { |skylight| skylight[:ref] = ref }
    end

    if surface.has_key?(:windows)
      ref = 2.0
      ref *= 43.0 / (heating + 25.0) if heating < 18.0 && cooling > 40.0
      surface[:windows].values.map { |window| window[:ref] = ref }
    end

    if surface.has_key?(:doors)
      surface[:doors].each do |i, door|
        ref = 0.9
        ref = 2.0 if door.has_key?(:glazed) && door[:glazed]
        ref *= 43.0 / (heating + 25.0) if heating < 18.0 && cooling > 40.0
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
# @return [Hash] Returns (multilingual) binned values for UA' summary.
def ua_summary(surfaces, date = Time.now, version = "",
               descr = "", file = "", ref = "")
  ua = {}

  unless surfaces && surfaces.is_a?(Hash)
    TBD.log(TBD::DEBUG, "Can't process UA' results - invalid arguments")
    return ua
  end
  return ua if surfaces.empty?

  languages = [:en, :fr]
  languages.each { |lang| ua[lang] = {} }

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

  # Set up 2x heating setpoint (HSTP) "blocks" (or bins):
  #   bloc1: spaces/zones with HSTP >= 18°C
  #   bloc2: spaces/zones with HSTP < 18°C
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

  languages.each do |lang|
    blc = [:b1, :b2]
    blc.each do |b|
      bloc = b1
      bloc = b2 if b == :b2

      pro_sum = bloc[:pro].values.reduce(:+)
      ref_sum = bloc[:ref].values.reduce(:+)
      if pro_sum > TOL
        ratio = nil
        ratio = 100.0 * (pro_sum - ref_sum) / ref_sum if ref_sum > TOL
        str = format("%.1f W/K (vs %.1f W/K)", pro_sum, ref_sum)
        str += format(" +%.1f%%", ratio) if ratio && pro_sum > ref_sum # **
        str += format(" -%.1f%%", ratio) if ratio && pro_sum < ref_sum
        ua[lang][b] = {}
        ua[:en][b][:summary] = "heated : #{str}"  if lang == :en
        ua[:fr][b][:summary] = "chauffé : #{str}" if lang == :fr

        # ** https://bugs.ruby-lang.org/issues/13761 (Ruby > 2.2.5)
        # str += format(" +%.1f%", ratio) if ratio && pro_sum > ref_sum ... becomes
        # str += format(" +%.1f%%", ratio) if ratio && pro_sum > ref_sum

        bloc[:pro].each do |k, v|
          rf = bloc[:ref][k]
          next if v < TOL && rf < TOL
          ratio = nil
          ratio = 100.0 * (v - rf) / rf if rf > TOL
          str = format("%.1f W/K (vs %.1f W/K)", v, rf)
          str += format(" +%.1f%%", ratio) if v > rf
          str += format(" -%.1f%%", ratio) if v < rf

          case k
          when :walls
            ua[:en][b][k] = "walls : #{str}"        if lang == :en
            ua[:fr][b][k] = "murs : #{str}"         if lang == :fr
          when :roofs
            ua[:en][b][k] = "roofs : #{str}"        if lang == :en
            ua[:fr][b][k] = "toits : #{str}"        if lang == :fr
          when :floors
            ua[:en][b][k] = "floors : #{str}"       if lang == :en
            ua[:fr][b][k] = "planchers : #{str}"    if lang == :fr
          when :doors
            ua[:en][b][k] = "doors : #{str}"        if lang == :en
            ua[:fr][b][k] = "portes : #{str}"       if lang == :fr
          when :windows
            ua[:en][b][k] = "windows : #{str}"      if lang == :en
            ua[:fr][b][k] = "fenêtres : #{str}"     if lang == :fr
          when :skylights
            ua[:en][b][k] = "skylights : #{str}"    if lang == :en
            ua[:fr][b][k] = "lanterneaux : #{str}"  if lang == :fr
          when :rimjoists
            ua[:en][b][k] = "rimjoists : #{str}"    if lang == :en
            ua[:fr][b][k] = "rives : #{str}"        if lang == :fr
          when :parapets
            ua[:en][b][k] = "parapets : #{str}"     if lang == :en
            ua[:fr][b][k] = "parapets : #{str}"     if lang == :fr
          when :trim
            ua[:en][b][k] = "trim : #{str}"         if lang == :en
            ua[:fr][b][k] = "chassis : #{str}"      if lang == :fr
          when :corners
            ua[:en][b][k] = "corners : #{str}"      if lang == :en
            ua[:fr][b][k] = "coins : #{str}"        if lang == :fr
          when :balconies
            ua[:en][b][k] = "balconies : #{str}"    if lang == :en
            ua[:fr][b][k] = "balcons : #{str}"      if lang == :fr
          when :grade
            ua[:en][b][k] = "grade : #{str}"        if lang == :en
            ua[:fr][b][k] = "tracé : #{str}"        if lang == :fr
          else
            ua[:en][b][k] = "other : #{str}"        if lang == :en
            ua[:fr][b][k] = "autres : #{str}"       if lang == :fr
          end
        end

        # Deterministic sorting
        ua[lang][b][:summary] = ua[lang][b].delete(:summary)
        if ua[lang][b].has_key?(:walls)
          ua[lang][b][:walls] = ua[lang][b].delete(:walls)
        end
        if ua[lang][b].has_key?(:roofs)
          ua[lang][b][:roofs] = ua[lang][b].delete(:roofs)
        end
        if ua[lang][b].has_key?(:floors)
          ua[lang][b][:floors] = ua[lang][b].delete(:floors)
        end
        if ua[lang][b].has_key?(:doors)
          ua[lang][b][:doors] = ua[lang][b].delete(:doors)
        end
        if ua[lang][b].has_key?(:windows)
          ua[lang][b][:windows] = ua[lang][b].delete(:windows)
        end
        if ua[lang][b].has_key?(:skylights)
          ua[lang][b][:skylights] = ua[lang][b].delete(:skylights)
        end
        if ua[lang][b].has_key?(:rimjoists)
          ua[lang][b][:rimjoists] = ua[lang][b].delete(:rimjoists)
        end
        if ua[lang][b].has_key?(:parapets)
          ua[lang][b][:parapets] = ua[lang][b].delete(:parapets)
        end
        if ua[lang][b].has_key?(:trim)
          ua[lang][b][:trim] = ua[lang][b].delete(:trim)
        end
        if ua[lang][b].has_key?(:corners)
          ua[lang][b][:corners] = ua[lang][b].delete(:corners)
        end
        if ua[lang][b].has_key?(:balconies)
          ua[lang][b][:balconies] = ua[lang][b].delete(:balconies)
        end
        if ua[lang][b].has_key?(:grade)
          ua[lang][b][:grade] = ua[lang][b].delete(:grade)
        end
        if ua[lang][b].has_key?(:other)
          ua[lang][b][:other] = ua[lang][b].delete(:other)
        end
      end
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

  if ua[lang].has_key?(:objective)
    report << "# #{ua[lang][:objective]}   "
    report << "   "
  end

  if ua[lang].has_key?(:details)
    ua[lang][:details].each { |d| report << "#{d}   " }
    report << "   "
  end

  if ua.has_key?(:model)
    report << "##### SUMMARY   "  if lang == :en
    report << "##### SOMMAIRE   " if lang == :fr
    report << "   "
    report << "#{ua[:model]}   "
    report << "   "
  end

  if ua[lang].has_key?(:b1) && ua[lang][:b1].has_key?(:summary)
    last = ua[lang][:b1].keys.to_a.last
    report << "* #{ua[lang][:b1][:summary]}"
    ua[lang][:b1].each do |k, v|
      next if k == :summary
      report << "  * #{v}" unless k == last
      report << "  * #{v}   " if k == last
      report << "   " if k == last
    end
    report << "   "
  end

  if ua[lang].has_key?(:b2) && ua[lang][:b2].has_key?(:summary)
    last = ua[lang][:b2].keys.to_a.last
    report << "* #{ua[lang][:b2][:summary]}"
    ua[lang][:b2].each do |k, v|
      next if k == :summary
      report << "  * #{v}" unless k == last
      report << "  * #{v}   " if k == last
      report << "   " if k == last
    end
    report << "   "
  end

  if ua.has_key?(:date)
    report << "##### DESCRIPTION   "
    report << "   "
    report << "* project : #{ua[:descr]}" if ua.has_key?(:descr) && lang == :en
    report << "* projet : #{ua[:descr]}"  if ua.has_key?(:descr) && lang == :fr
    model = ""
    model = "* model : #{ua[:file]}" if ua.has_key?(:file)
    model += " (v#{ua[:version]})" if ua.has_key?(:version)
    report << model unless model.empty?
    report << "* TBD version : v2.2.0"
    report << "* date : #{ua[:date]}"
    if lang == :en
      report << "* status : #{TBD.msg(TBD.status)}" unless TBD.status.zero?
      report << "* status : success !" if TBD.status.zero?
    elsif lang == :fr
      report << "* statut : #{TBD.msg(TBD.status)}" unless TBD.status.zero?
      report << "* status : succès !" if TBD.status.zero?
    end
    report << "   "
  end

  if ua[lang].has_key?(:areas)
    report << "##### AREAS   " if lang == :en
    report << "##### AIRES   " if lang == :fr
    report << "   "
    if ua[lang][:areas].has_key?(:walls)
      report << "* #{ua[lang][:areas][:walls]}"
    end
    if ua[lang][:areas].has_key?(:roofs)
      report << "* #{ua[lang][:areas][:roofs]}"
    end
    if ua[lang][:areas].has_key?(:floors)
      report << "* #{ua[lang][:areas][:floors]}"
    end
    report << "   "
  end

  if ua[lang].has_key?(:notes)
    report << "##### NOTES   "
    report << "   "
    report << "#{ua[lang][:notes]}   "
    report << "   "
  end

  report
end
