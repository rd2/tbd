# MIT License
#
# Copyright (c) 2020-2022 Denis Bourgeois & Dan Macumber
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

##
# Calculates construction Uo (including surface film resistances) to meet Ut.
#
# @param [OpenStudio::Model::Model] model An OS model
# @param [OpenStudio::Model::LayeredConstruction] lc An OS layered construction
# @param [String] id Layered construction identifier
# @param [Double] heatloss Heat loss from major thermal bridging [W/K]
# @param [Double] film Target surface film resistance [m2.K/W]
# @param [Double] ut Target overall Ut for lc [W/m2.K]
#
# @return [Double] Returns (new) construction Uo [W/m2.K] required to meet Ut.
def uo(model, lc, id, heatloss, film, ut)
  uo = nil
  m = nil
  cl1 = OpenStudio::Model::Model
  cl2 = OpenStudio::Model::LayeredConstruction

  unless id.is_a?(String)
    TBD.log(TBD::DEBUG,
      "Can't set Uo, #{id.class}? expected an ID String - skipping")
    return uo, m
  end
  unless model && model.is_a?(cl1)
    TBD.log(TBD::DEBUG,
      "Can't set Uo for #{id}, #{model.class}?  expected #{cl1} - skipping")
    return uo, m
  end
  unless lc.is_a?(cl2)
    TBD.log(TBD::ERROR,
      "Can't set Uo for '#{id}', #{lc.class}? expected #{cl2} - skipping")
    return uo, m
  end

  index, ltype, r = deratableLayer(lc)      # insulating layer index, type & RSi
  index = nil unless index.is_a?(Numeric)
  index = nil unless index >= 0
  index = nil unless index < lc.layers.size

  unless index
    TBD.log(TBD::ERROR,
      "Can't set Uo for '#{id}', invalid layer index - skipping")
    return uo, m
  end
  unless heatloss.is_a?(Numeric)
    TBD.log(TBD::DEBUG,
      "Can't set Uo for '#{id}', non-numeric heatloss - skipping")
    return uo, m
  end
  unless heatloss > 0
    TBD.log(TBD::WARN,
      "Can't set Uo for '#{id}', 0 W/K heatloss - skipping")
    return uo, m
  end
  unless film.is_a?(Numeric) && film > 0
    TBD.log(TBD::DEBUG,
      "Can't set Uo for '#{id}', negative or non-numeric film - skipping")
    return uo, m
  end
  unless ut.is_a?(Numeric) && ut > 0 && ut < 5.678
    TBD.log(TBD::DEBUG,
      "Can't set Uo for '#{id}': negative, non-numeric or low Ut - skipping")
    return uo, m
  end

  area = lc.getNetArea
  if area < TOL
    TBD.log(TBD::ERROR,
      "Can't set Uo for '#{id}', area ~0 m2 - skipping")
    return uo, m
  end

  # First, calculate initial layer RSi to initially meet Ut target.
  rt             = 1 / ut                               # target construction Rt
  ro             = rsi(lc, film)                       # current construction Ro
  new_r          = r + (rt - ro)                     # new, un-derated layer RSi
  new_u          = 1 / new_r

  # puts rt, ro, new_r, new_u

  # Then, uprate (if possible) to counter expected thermal bridging effects.
  u_psi          = heatloss / area                              # from psi & khi
  new_u          = new_u - u_psi        # uprated layer USi to counter psi & khi
  new_r          = 1 / new_u            # uprated layer RSi to counter psi & khi

  unless new_r > 0.001
    TBD.log(TBD::ERROR,
      "Can't uprate '#{id}', calculated low or negative Rsi - skipping")
    return uo, m
  end

  loss           = 0.0   # residual heatloss not assigned to layer (maybe) [W/K]

  if ltype == :massless
    m            = lc.getLayer(index).to_MasslessOpaqueMaterial

    unless m.empty?
      m          = m.get.clone(model).to_MasslessOpaqueMaterial.get
                   m.setName("#{id} uprated")

      unless new_r > 0.001
        new_r    = 0.001
        loss     = (new_u - 1 / new_r) * area
      end
      m.setThermalResistance(new_r)
    end

  else                                                      # ltype == :standard
    m            = lc.getLayer(index).to_StandardOpaqueMaterial
    unless m.empty?
      m          = m.get.clone(model).to_StandardOpaqueMaterial.get
                   m.setName("#{id} uprated")
      k          = m.thermalConductivity

      if new_r > 0.001
        d        = new_r * k
        unless d > 0.003
          d      = 0.003
          k      = d / new_r
          unless k < 3.0
            k    = 3.0

            loss = (new_u - k / d) * area
          end
        end
      else                                                # new_r < 0.001 m2.K/W
        d        = 0.001 * k
        unless d > 0.003
          d      = 0.003
          k      = d / 0.001
        end
        loss     = (new_u - k / d) * area
      end

      unless m.setThickness(d)
        TBD.log(TBD::ERROR,
          "Unable to uprate insulation layer (> 3m) of '#{id}' - skipping")
        return uo, nil
      else
        m.setThermalConductivity(k)
      end
    end
  end

  unless m
    TBD.log(TBD::DEBUG,
      "Unable to uprate insulation layer of '#{id}' - skipping")
    return uo, nil
  else
    lc.setLayer(index, m)
    uo = 1 / rsi(lc, film)
  end

  if loss > TOL
    h_loss  = format "%.3f", loss
    TBD.log(TBD::ERROR,
      "Can't assign #{h_loss} W/K to '#{id}', too conductive - skipping")
    return nil, nil
  end

  return uo, m
end

##
# Uprate insulation layer of construction, based on user-selected Ut (argh).
#
# @param [OpenStudio::Model::Model] model An OpenStudio model
# @param [Hash] surfaces Preprocessed collection of TBD surfaces
# @param [Hash] arguments Arguments
#
# @return [Bool] Returns True if successfully uprated; False if fail
def uprate(model, surfaces, argh)
  unless model && surfaces && argh
    TBD.log(TBD::DEBUG, "Uprate - invalid inputs")
    return false
  end
  cl = OpenStudio::Model::Model
  unless model.is_a?(cl)
    TBD.log(TBD::DEBUG, "Uprate, model #{model.class} - expected #{cl}")
    return false
  end
  unless surfaces.is_a?(Hash)
    TBD.log(TBD::DEBUG, "Uprate, surfaces #{surfaces.class} - expected Hash")
    return false
  end
  unless argh.is_a?(Hash)
    TBD.log(TBD::DEBUG, "Uprate, argh #{argh.class} - expected Hash")
    return false
  end

  argh[:uprate_walls]  = false unless argh.key?(:uprate_walls)
  argh[:uprate_roofs]  = false unless argh.key?(:uprate_roofs)
  argh[:uprate_floors] = false unless argh.key?(:uprate_floors)
  argh[:wall_ut]       = 5.678 unless argh.key?(:wall_ut)
  argh[:roof_ut]       = 5.678 unless argh.key?(:roof_ut)
  argh[:floor_ut]      = 5.678 unless argh.key?(:floor_ut)
  argh[:wall_option]   = ""    unless argh.key?(:wall_option)
  argh[:roof_option]   = ""    unless argh.key?(:roof_option)
  argh[:floor_option]  = ""    unless argh.key?(:floor_option)

  groups = {wall: {}, roof: {}, floor: {}}
  groups[:wall ][:up] = argh[:uprate_walls]
  groups[:roof ][:up] = argh[:uprate_roofs]
  groups[:floor][:up] = argh[:uprate_floors]
  groups[:wall ][:ut] = argh[:wall_ut]
  groups[:roof ][:ut] = argh[:roof_ut]
  groups[:floor][:ut] = argh[:floor_ut]
  groups[:wall ][:op] = argh[:wall_option]
  groups[:roof ][:op] = argh[:roof_option]
  groups[:floor][:op] = argh[:floor_option]

  groups.each do |label, g|
    next unless g[:up]
    next unless g[:ut].is_a?(Numeric)
    next unless g[:ut] < 5.678
    coll = {}
    area = 0
    film = 100000000000000
    lc = nil
    uo = nil
    id = ""

    all = g[:op].downcase == "all wall constructions" ||
          g[:op].downcase == "all roof constructions" ||
          g[:op].downcase == "all floor constructions"

    if g[:op].empty?
      TBD.log(TBD::ERROR, "Missing construction to uprate - skipping")
    elsif all
      model.getSurfaces.each do |s|
        next unless s.surfaceType.downcase.include?(label.to_s)
        next unless s.outsideBoundaryCondition.downcase == "outdoors"
        next if s.construction.empty?
        next if s.construction.get.to_LayeredConstruction.empty?
        c = s.construction.get.to_LayeredConstruction.get
        i = c.nameString

        # Reliable unless referenced by other surface types e.g. floor vs wall.
        if c.getNetArea > area
          area = c.getNetArea
          lc = c
          id = i
        end

        film = s.filmResistance if s.filmResistance < film
        nom = s.nameString
        coll[i] = {area: c.getNetArea, lc: c, s: {}} unless coll.key?(i)
        coll[i][:s][nom] = {a: s.netArea} unless coll[i][:s].key?(nom)
      end
    else
      id = g[:op]
      c = model.getConstructionByName(id)

      if c.empty?
        TBD.log(TBD::ERROR,
          "Unknown construction '#{id}' to uprate - skipping")
      else
        c = c.get.to_LayeredConstruction

        if c.empty?
          TBD.log(TBD::ERROR,
            "Non-layered construction '#{id}' to uprate - skipping")
        else
          lc = c.get
          area = lc.getNetArea
          coll[id] = {area: area, lc: lc, s: {}}

          model.getSurfaces.each do |s|
            next unless s.surfaceType.downcase.include?(label.to_s)
            next unless s.outsideBoundaryCondition.downcase == "outdoors"
            next if s.construction.empty?
            next if s.construction.get.to_LayeredConstruction.empty?
            lc = s.construction.get.to_LayeredConstruction.get
            next unless id == lc.nameString
            nom = s.nameString
            film = s.filmResistance if s.filmResistance < film
            coll[id][:s][nom] = {a: s.netArea} unless coll[id][:s].key?(nom)
          end
        end
      end
    end

    if coll.empty?
      TBD.log(TBD::ERROR, "No construction to uprate - skipping")
      next
    elsif lc                        # valid layered construction, good to uprate
      # Ensure lc is referenced by surface types == label.
      model.getSurfaces.each do |s|
        next if s.construction.empty?
        next if s.construction.get.to_LayeredConstruction.empty?
        c = s.construction.get.to_LayeredConstruction.get
        i = c.nameString
        next unless coll.key?(i)

        unless s.surfaceType.downcase.include?(label.to_s)
          TBD.log(TBD::ERROR,
            "Won't uprate '#{s.nameString}': (#{label.to_s} only) - cloning")
          cloned = c.clone(model).to_LayeredConstruction.get
          cloned.setName("'#{i}' cloned")
          s.setConstruction(cloned)

          if surfaces.key?(s.nameString)
            surfaces[s.nameString][:construction] = cloned
          end

          coll[i][:s].delete(s.nameString)
          coll[i][:area] = c.getNetArea
          next
        end
      end

      index, ltype, r = deratableLayer(lc)
      index = nil unless index.is_a?(Numeric)
      index = nil unless index >= 0
      index = nil unless index < lc.layers.size

      unless index
        TBD.log(TBD::ERROR, "Can't ID insulation index for '#{id}' - skipping")
        next
      end

      heatloss = 0                   # sum of applicable psi & khi effects [W/K]
      coll.each do |i, col|
        next unless col.key?(:s)
        next unless col.is_a?(Hash)
        col[:s].keys.each do |nom|
          next unless surfaces.key?(nom)
          surface = surfaces[nom]
          next unless surface.key?(:deratable)
          next unless surface[:deratable]
          next unless surface.key?(:construction)
          next unless surface.key?(:index)
          next unless surface.key?(:ltype)
          next unless surface.key?(:r)
          next unless surface.key?(:type)
          type = surface[:type].to_s.downcase
          type = "roof" if type == "ceiling"
          next unless type.include?(label.to_s)

          # Tally applicable psi + khi.
          heatloss += surface[:heatloss] if surface.key?(:heatloss)

          # Skip construction reassignment if already referencing right one.
          unless surface[:construction] == lc
            s = model.getSurfaceByName(nom)
            next if s.empty?
            s = s.get

            if s.isConstructionDefaulted
              set = defaultConstructionSet(model, s)
              constructions = set.defaultExteriorSurfaceConstructions.get
              case s.surfaceType.downcase
              when "roofceiling"
                constructions.setRoofCeilingConstruction(lc)
              when "floor"
                constructions.setFloorConstruction(lc)
              else
                constructions.setWallConstruction(lc)
              end
            else
              s.setConstruction(lc)
            end

            # Reset TBD surface attributes.
            surface[:construction] = lc
            surface[:index]        = index
            surface[:ltype]        = ltype
            surface[:r]            = r                               # temporary
          end
        end
      end

      # Merge to ensure a single entry for coll Hash.
      coll.each do |i, col|
        next if i == id
        next unless coll.key?(id)
        coll[id][:area] += col[:area]
        col[:s].each do |nom, s|
          coll[id][:s][nom] = s unless coll[id][:s].key?(nom)
        end
      end

      coll.delete_if { |i, _| i != id }
      unless coll.size == 1
        TBD.log(TBD::DEBUG, "Collection should equal 1 for '#{id}' - skipping")
        next
      end

      uo, m = uo(model, lc, id, heatloss, film, g[:ut])
      unless uo && m
        TBD.log(TBD::ERROR, "Unable to uprate '#{id}' - skipping")
        next
      end

      index, ltype, r = deratableLayer(lc)

      # Loop through coll :s, and reset :r - likely modified by uo().
      coll.values.first[:s].keys.each do |nom|
        next unless surfaces.key?(nom)
        surface = surfaces[nom]
        next unless surface.key?(:deratable)
        next unless surface[:deratable]
        next unless surface.key?(:construction)
        next unless surface[:construction] == lc
        next unless surface.key?(:index)
        next unless surface[:index] == index
        next unless surface.key?(:ltype)
        next unless surface[:ltype] == ltype
        next unless surface.key?(:type)
        type = surface[:type].to_s.downcase
        type = "roof" if type == "ceiling"
        next unless type.include?(label.to_s)
        next unless surface.key?(:r)
        surface[:r] = r                                                  # final
      end

      case label
      when :wall
        argh[:wall_uo] = uo
      when :roof
        argh[:roof_uo] = uo
      else
        argh[:floor_uo] = uo
      end

    else
      TBD.log(TBD::ERROR, "Nilled construction to uprate - skipping")
      return false
    end
  end

  true
end

##
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
    next unless surface.key?(:deratable)
    next unless surface[:deratable]
    next unless surface.key?(:type)
    if setpoints
      heating = -50
      cooling =  50
    else
      heating =  21
      cooling =  24
    end
    heating = surface[:heating] if surface.key?(:heating)
    cooling = surface[:cooling] if surface.key?(:cooling)

    # Start with surface U-factors.
    ref = 1 / 5.46
    ref = 1 / 3.60 if surface[:type] == :wall

    # Adjust for lower heating setpoint (assumes -25°C design conditions).
    ref *= 43 / (heating + 25) if heating < 18 && cooling > 40

    # And store.
    surface[:ref] = ref

    # Loop through subsurfaces.
    if surface.key?(:skylights)
      ref = 2.85
      ref *= 43 / (heating + 25) if heating < 18 && cooling > 40
      surface[:skylights].values.map { |skylight| skylight[:ref] = ref }
    end

    if surface.key?(:windows)
      ref = 2.0
      ref *= 43 / (heating + 25) if heating < 18 && cooling > 40
      surface[:windows].values.map { |window| window[:ref] = ref }
    end

    if surface.key?(:doors)
      surface[:doors].each do |i, door|
        ref = 0.9
        ref = 2.0 if door.key?(:glazed) && door[:glazed]
        ref *= 43 / (heating + 25) if heating < 18 && cooling > 40
        door[:ref] = ref
      end
    end

    # Loop through point thermal bridges.
    if surface.key?(:pts)
      surface[:pts].map { |i, pt| pt[:ref] = 0.5 }
    end

    # Loop through linear thermal bridges.
    if surface.key?(:edges)
      surface[:edges].values.each do |edge|
        next unless edge.key?(:type)
        next unless edge.key?(:ratio)
        tt = sets.safeType("code (Quebec)", edge[:type])
        edge[:ref] = val[tt] * edge[:ratio] if tt
      end
    end
  end

  true
end

##
# Generate UA' summary.
#
# @param [Time] date Time stamp
# @param [Hash] argh Arguments
#
# @return [Hash] Returns (multilingual) binned values for UA' summary.
def ua_summary(date = Time.now, argh = {})
  ua = {}
  argh = {}                    unless argh.is_a?(Hash)

  argh[:seed] = ""             unless argh.key?(:seed)
  argh[:ua_ref] = ""           unless argh.key?(:ua_ref)
  argh[:surfaces] = nil        unless argh.key?(:surfaces)
  argh[:version] = ""          unless argh.key?(:version)
  argh[:io] = {}               unless argh.key?(:io)
  argh[:io][:description] = "" unless argh[:io].key?(:description)

  unless argh[:surfaces] && argh[:surfaces].is_a?(Hash)
    TBD.log(TBD::DEBUG, "Can't process UA' results - invalid arguments")
    return ua
  end
  return ua if argh[:surfaces].empty?

  descr        = argh[:io][:description]
  file         = argh[:seed]
  version      = argh[:version]
  ua[:descr]   = ""
  ua[:file]    = ""
  ua[:version] = ""
  ua[:descr]   = descr unless descr.nil? || descr.empty?
  ua[:file]    = file unless file.nil? || file.empty?
  ua[:version] = version unless version.nil? || version.empty?
  ua[:model]   = "∑U•A + ∑PSI•L + ∑KHI•n"
  ua[:date]    = date

  languages = [:en, :fr]
  languages.each { |lang| ua[lang] = {} }

  ua[:en][:notes] = "Automated assessment from the OpenStudio Measure, "       \
    "Thermal Bridging and Derating (TBD). Open source and MIT-licensed, TBD "  \
    "is provided as is (without warranty). Procedures are documented in "      \
    "the source code: https://github.com/rd2/tbd. "

  ua[:fr][:notes] = "Analyse automatisée réalisée par la measure OpenStudio, " \
    "'Thermal Bridging and Derating' (ou TBD). Distribuée librement (licence " \
    "MIT), TBD est offerte telle quelle (sans garantie). L'approche est "      \
    "documentée au sein du code source : https://github.com/rd2/tbd."

  walls  = { net: 0, gross: 0, subs: 0 }
  roofs  = { net: 0, gross: 0, subs: 0 }
  floors = { net: 0, gross: 0, subs: 0 }
  areas  = { walls: walls, roofs: roofs, floors: floors }

  has = {}
  val = {}
  psi = PSI.new
  unless argh[:ua_ref].empty?
    has, val = psi.shorthands(argh[:ua_ref])
    if has.empty? || val.empty?
      TBD.log(TBD::ERROR, "Invalid UA' reference set - skipping")
    else
      ua[:model] += " : Design vs '#{argh[:ua_ref]}'"
      case argh[:ua_ref]
      when "code (Quebec)"
        ua[:en][:objective] = "COMPLIANCE ASSESSMENT"
        ua[:en][:details] = []
        ua[:en][:details] << "Quebec Construction Code, Chapter I.1"
        ua[:en][:details] << "NECB 2015, modified version (2020)"
        ua[:en][:details] << "Division B, Section 3.3"
        ua[:en][:details] << "Building Envelope Trade-off Path"

        ua[:en][:notes] << " Calculations comply with Section 3.3 "            \
          "requirements. Results are based on user input not subject to "      \
          "prior validation (see DESCRIPTION), and as such the assessment "    \
          "shall not be considered as a certification of compliance."

        ua[:fr][:objective] = "ANALYSE DE CONFORMITÉ"
        ua[:fr][:details] = []
        ua[:fr][:details] << "Code de construction du Québec, Chapitre I.1"
        ua[:fr][:details] << "CNÉB 2015, version modifiée (2020)"
        ua[:fr][:details] << "Division B, Section 3.3"
        ua[:fr][:details] << "Méthode des solutions de remplacement"

        ua[:fr][:notes] << " Les calculs sont conformes aux dispositions de "  \
          "la Section 3.3. Les résultats sont tributaires d'intrants fournis " \
          "par l'utilisateur, sans validation préalable (voir DESCRIPTION). "  \
          "Ce document ne peut constituer une attestation de conformité. "
      else
        ua[:en][:objective] = "UA'"
        ua[:fr][:objective] = "UA'"
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
  argh[:surfaces].each do |id, surface|
    next unless surface.key?(:deratable)
    next unless surface[:deratable]
    next unless surface.key?(:type)
    type = surface[:type]
    next unless type == :wall || type == :ceiling || type == :floor
    next unless surface.key?(:net)
    next unless surface[:net] > TOL
    next unless surface.key?(:u)
    next unless surface[:u] > TOL
    heating = 21.0
    heating = surface[:heating] if surface.key?(:heating)

    bloc = b1
    bloc = b2 if heating < 18

    reference = surface.key?(:ref)
    if type == :wall
      areas[:walls][:net] += surface[:net]
      bloc[:pro][:walls] += surface[:net] * surface[:u]
      bloc[:ref][:walls] += surface[:net] * surface[:ref] if reference
      bloc[:ref][:walls] += surface[:net] * surface[:u] unless reference
    elsif type == :ceiling
      areas[:roofs][:net] += surface[:net]
      bloc[:pro][:roofs] += surface[:net] * surface[:u]
      bloc[:ref][:roofs] += surface[:net] * surface[:ref] if reference
      bloc[:ref][:roofs] += surface[:net] * surface[:u] unless reference
    else
      areas[:floors][:net] += surface[:net]
      bloc[:pro][:floors] += surface[:net] * surface[:u]
      bloc[:ref][:floors] += surface[:net] * surface[:ref] if reference
      bloc[:ref][:floors] += surface[:net] * surface[:u] unless reference
    end

    if surface.key?(:doors)
      surface[:doors].values.each do |door|
        next unless door.key?(:gross)
        next unless door[:gross] > TOL
        next unless door.key?(:u)
        next unless door[:u] > TOL
        areas[:walls][:subs] += door[:gross] if type == :wall
        areas[:roofs][:subs] += door[:gross] if type == :ceiling
        areas[:floors][:subs] += door[:gross] if type == :floor
        bloc[:pro][:doors] += door[:gross] * door[:u]
        if door.key?(:ref)
          bloc[:ref][:doors] += door[:gross] * door[:ref]
        else
          bloc[:ref][:doors] += door[:gross] * door[:u]
        end
      end
    end

    if surface.key?(:windows)
      surface[:windows].values.each do |window|
        next unless window.key?(:gross)
        next unless window[:gross] > TOL
        next unless window.key?(:u)
        next unless window[:u] > TOL
        areas[:walls][:subs] += window[:gross] if type == :wall
        areas[:roofs][:subs] += window[:gross] if type == :ceiling
        areas[:floors][:subs] += window[:gross] if type == :floor
        bloc[:pro][:windows] += window[:gross] * window[:u]
        if window.key?(:ref)
          bloc[:ref][:windows] += window[:gross] * window[:ref]
        else
          bloc[:ref][:windows] += window[:gross] * window[:u]
        end
      end
    end

    if surface.key?(:skylights)
      surface[:skylights].values.each do |sky|
        next unless sky.key?(:gross)
        next unless sky[:gross] > TOL
        next unless sky.key?(:u)
        next unless sky[:u] > TOL
        areas[:walls][:subs] += sky[:gross] if type == :wall
        areas[:roofs][:subs] += sky[:gross] if type == :ceiling
        areas[:floors][:subs] += sky[:gross] if type == :floor
        bloc[:pro][:skylights] += sky[:gross] * sky[:u]
        if sky.key?(:ref)
          bloc[:ref][:skylights] += sky[:gross] * sky[:ref]
        else
          bloc[:ref][:skylights] += sky[:gross] * sky[:u]
        end
      end
    end

    if surface.key?(:edges)
      surface[:edges].values.each do |edge|
        next unless edge.key?(:type)
        next unless edge.key?(:length)
        next unless edge[:length] > TOL
        next unless edge.key?(:psi)

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

        next if val.empty?
        next if argh[:ua_ref].empty?
        tt = psi.safeType(argh[:ua_ref], edge[:type])
        if edge.key?(:ref)
          loss = edge[:length] * edge[:ref]
        else
          loss = edge[:length] * val[tt] * edge[:ratio]
        end

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

    if surface.key?(:pts)
      surface[:pts].values.each do |pts|
        next unless pts.key?(:val)
        next unless pts.key?(:n)
        bloc[:pro][:other] += pts[:val] * pts[:n]
        next unless pts.key?(:ref)
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
      if pro_sum > TOL || ref_sum > TOL
        ratio = nil
        ratio = (100.0 * (pro_sum - ref_sum) / ref_sum).abs if ref_sum > TOL
        str = format("%.1f W/K (vs %.1f W/K)", pro_sum, ref_sum)
        str += format(" +%.1f%%", ratio) if ratio && pro_sum > ref_sum # **
        str += format(" -%.1f%%", ratio) if ratio && pro_sum < ref_sum
        ua[lang][b] = {}
        if b == :b1
          ua[:en][b][:summary] = "heated : #{str}"  if lang == :en
          ua[:fr][b][:summary] = "chauffé : #{str}" if lang == :fr
        else
          ua[:en][b][:summary] = "semi-heated : #{str}"  if lang == :en
          ua[:fr][b][:summary] = "semi-chauffé : #{str}" if lang == :fr
        end

        # ** https://bugs.ruby-lang.org/issues/13761 (Ruby > 2.2.5)
        # str += format(" +%.1f%", ratio) if ratio && pro_sum > ref_sum ... now:
        # str += format(" +%.1f%%", ratio) if ratio && pro_sum > ref_sum

        bloc[:pro].each do |k, v|
          rf = bloc[:ref][k]
          next if v < TOL && rf < TOL
          ratio = nil
          ratio = (100.0 * (v - rf) / rf).abs if rf > TOL
          str = format("%.1f W/K (vs %.1f W/K)", v, rf)
          str += format(" +%.1f%%", ratio) if ratio && v > rf
          str += format(" -%.1f%%", ratio) if ratio && v < rf

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
        if ua[lang][b].key?(:walls)
          ua[lang][b][:walls] = ua[lang][b].delete(:walls)
        end
        if ua[lang][b].key?(:roofs)
          ua[lang][b][:roofs] = ua[lang][b].delete(:roofs)
        end
        if ua[lang][b].key?(:floors)
          ua[lang][b][:floors] = ua[lang][b].delete(:floors)
        end
        if ua[lang][b].key?(:doors)
          ua[lang][b][:doors] = ua[lang][b].delete(:doors)
        end
        if ua[lang][b].key?(:windows)
          ua[lang][b][:windows] = ua[lang][b].delete(:windows)
        end
        if ua[lang][b].key?(:skylights)
          ua[lang][b][:skylights] = ua[lang][b].delete(:skylights)
        end
        if ua[lang][b].key?(:rimjoists)
          ua[lang][b][:rimjoists] = ua[lang][b].delete(:rimjoists)
        end
        if ua[lang][b].key?(:parapets)
          ua[lang][b][:parapets] = ua[lang][b].delete(:parapets)
        end
        if ua[lang][b].key?(:trim)
          ua[lang][b][:trim] = ua[lang][b].delete(:trim)
        end
        if ua[lang][b].key?(:corners)
          ua[lang][b][:corners] = ua[lang][b].delete(:corners)
        end
        if ua[lang][b].key?(:balconies)
          ua[lang][b][:balconies] = ua[lang][b].delete(:balconies)
        end
        if ua[lang][b].key?(:grade)
          ua[lang][b][:grade] = ua[lang][b].delete(:grade)
        end
        if ua[lang][b].key?(:other)
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

##
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
  unless ua.key?(lang)
    TBD.log(TBD::DEBUG, "Can't generate UA' MD report - language mismatch")
    return report
  end

  if ua[lang].key?(:objective)
    report << "# #{ua[lang][:objective]}   "
    report << "   "
  end

  if ua[lang].key?(:details)
    ua[lang][:details].each { |d| report << "#{d}   " }
    report << "   "
  end

  if ua.key?(:model)
    report << "##### SUMMARY   "  if lang == :en
    report << "##### SOMMAIRE   " if lang == :fr
    report << "   "
    report << "#{ua[:model]}   "
    report << "   "
  end

  if ua[lang].key?(:b1) && ua[lang][:b1].key?(:summary)
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

  if ua[lang].key?(:b2) && ua[lang][:b2].key?(:summary)
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

  if ua.key?(:date)
    report << "##### DESCRIPTION   "
    report << "   "
    report << "* project : #{ua[:descr]}" if ua.key?(:descr) && lang == :en
    report << "* projet : #{ua[:descr]}"  if ua.key?(:descr) && lang == :fr
    model = ""
    model = "* model : #{ua[:file]}" if ua.key?(:file) if lang == :en
    model = "* modèle : #{ua[:file]}" if ua.key?(:file) if lang == :fr
    model += " (v#{ua[:version]})" if ua.key?(:version)
    report << model unless model.empty?
    report << "* TBD : v2.4.4"
    report << "* date : #{ua[:date]}"
    if lang == :en
      report << "* status : #{TBD.msg(TBD.status)}" unless TBD.status.zero?
      report << "* status : success !" if TBD.status.zero?
    elsif lang == :fr
      report << "* statut : #{TBD.msg(TBD.status)}" unless TBD.status.zero?
      report << "* statut : succès !" if TBD.status.zero?
    end
    report << "   "
  end

  if ua[lang].key?(:areas)
    report << "##### AREAS   " if lang == :en
    report << "##### AIRES   " if lang == :fr
    report << "   "
    if ua[lang][:areas].key?(:walls)
      report << "* #{ua[lang][:areas][:walls]}"
    end
    if ua[lang][:areas].key?(:roofs)
      report << "* #{ua[lang][:areas][:roofs]}"
    end
    if ua[lang][:areas].key?(:floors)
      report << "* #{ua[lang][:areas][:floors]}"
    end
    report << "   "
  end

  if ua[lang].key?(:notes)
    report << "##### NOTES   "
    report << "   "
    report << "#{ua[lang][:notes]}   "
    report << "   "
  end

  report
end
