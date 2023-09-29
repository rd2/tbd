require "tbd"
require "fileutils"

RSpec.describe TBD do
  TOL  = TBD::TOL
  TOL2 = TBD::TOL2
  DBG  = TBD::DBG
  INF  = TBD::INF
  WRN  = TBD::WRN
  ERR  = TBD::ERR
  FTL  = TBD::FTL

  it "can process JSON surface KHI entries" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    expect(TBD.level     ).to eq(INF)
    expect(TBD.reset(DBG)).to eq(DBG)
    expect(TBD.level     ).to eq(DBG)
    expect(TBD.clean!    ).to eq(DBG)

    # First, basic IO tests with invalid entries.
    k = TBD::KHI.new
    expect(k.point).to be_a(Hash)
    expect(k.point.size).to eq(14)

    # Invalid identifier key.
    new_KHI = { name: "new_KHI", point: 1.0 }
    expect(k.append(new_KHI)).to be false
    expect(TBD.debug?).to be true
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message]).to include("Missing 'id' key")
    TBD.clean!

    # Invalid identifier.
    new_KHI = { id: nil, point: 1.0 }
    expect(k.append(new_KHI)).to be false
    expect(TBD.error?).to be true
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message]).to include("'KHI id' NilClass?")
    TBD.clean!

    # Odd (yet valid) identifier.
    new_KHI = { id: [], point: 1.0 }
    expect(k.append(new_KHI)).to be true
    expect(TBD.status).to be_zero
    expect(k.point.keys).to include("[]")
    expect(k.point.size).to eq(15)

    # Existing identifier.
    new_KHI = { id: "code (Quebec)", point: 1.0 }
    expect(k.append(new_KHI)).to be false
    expect(TBD.error?).to be true
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message]).to include("existing KHI entry")
    TBD.clean!

    # Missing point conductance.
    new_KHI = { id: "foo" }
    expect(k.append(new_KHI)).to be false
    expect(TBD.debug?).to be true
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message]).to include("Missing 'point' key")


    # Valid JSON entries.
    TBD.clean!

    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    argh               = {}
    argh[:option     ] = "(non thermal bridging)"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_seb_n2.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(56)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(106)

    # As the :building PSI set on file remains "(non thermal bridging)", one
    # should not expect differences in results, i.e. derating shouldn't occur.
    # However, the JSON file holds KHI entries for "Entryway  Wall 2" :
    # 3x "columns" @0.5 W/K + 4x supports @0.5W/K = 3.5 W/K
    surfaces.values.each do |surface|
      next unless surface.key?(:ratio)

      expect(surface[:heatloss]).to be_within(TOL).of(3.5)
    end
  end

  it "can process JSON surface KHI & PSI entries + building & edge" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    # First, basic IO tests with invalid entries.
    ps = TBD::PSI.new
    expect(ps.set).to be_a(Hash)
    expect(ps.has).to be_a(Hash)
    expect(ps.val).to be_a(Hash)
    expect(ps.set.size).to eq(16)
    expect(ps.has.size).to eq(16)
    expect(ps.val.size).to eq(16)

    expect(ps.gen(nil)).to be false
    expect(TBD.status).to be_zero

    # Invalid identifier key.
    new_PSI = { name: "new_PSI", balcony: 1.0 }
    expect(ps.append(new_PSI)).to be false
    expect(TBD.debug?).to be true
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message]).to include("Missing 'id' key")
    TBD.clean!

    # Invalid identifier.
    new_PSI = { id: nil, balcony: 1.0 }
    expect(ps.append(new_PSI)).to be false
    expect(TBD.error?).to be true
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message]).to include("'set ID' NilClass?")
    TBD.clean!

    # Odd (yet valid) identifier.
    new_PSI = { id: [], balcony: 1.0 }
    expect(ps.append(new_PSI)).to be true
    expect(TBD.status).to be_zero
    expect(ps.set.keys).to include("[]")
    expect(ps.has.keys).to include("[]")
    expect(ps.val.keys).to include("[]")
    expect(ps.set.size).to eq(17)
    expect(ps.has.size).to eq(17)
    expect(ps.val.size).to eq(17)

    # Existing identifier.
    new_PSI = { id: "code (Quebec)", balcony: 1.0 }
    expect(ps.append(new_PSI)).to be false
    expect(TBD.error?).to be true
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message]).to include("existing PSI set")
    TBD.clean!

    # Side test on balcony/sill.
    expect(ps.safe("code (Quebec)", :balconysillconcave)).to eq(:balconysill)

    # Defined vs missing conductances.
    new_PSI = { id: "foo" }
    expect(ps.append(new_PSI)).to be true

    s = ps.shorthands("foo")
    expect(TBD.status).to be_zero
    expect(s).to be_a(Hash)
    expect(s).to have_key(:has)
    expect(s).to have_key(:val)

    [:joint, :transition].each do |type|
      expect(s[:has]).to have_key(type)
      expect(s[:val]).to have_key(type)
      expect(s[:has][type]).to be true
      expect(s[:val][type]).to be_within(TOL).of(0)
    end

    [:balcony, :rimjoist, :fenestration, :parapet].each do |type|
      expect(s[:has]).to have_key(type)
      expect(s[:val]).to have_key(type)
      expect(s[:has][type]).to be false
      expect(s[:val][type]).to be_within(TOL).of(0)
    end

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Valid JSON entries.
    TBD.clean!

    name  = "Entryway  Wall 5"
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    # Consider the plenum as UNCONDITIONED.
    plnum = model.getSpaceByName("Level 0 Ceiling Plenum")
    expect(plnum).to_not be_empty
    plnum = plnum.get
    expect(TBD.unconditioned?(plnum)).to be false

    key = "space_conditioning_category"
    val = "Unconditioned"
    expect(plnum.additionalProperties.hasFeature(key)).to be false
    expect(plnum.additionalProperties.setFeature(key, val)).to be true
    expect(TBD.plenum?(plnum)).to be true
    expect(TBD.unconditioned?(plnum)).to be true
    expect(TBD.setpoints(plnum)[:heating]).to be_nil
    expect(TBD.setpoints(plnum)[:cooling]).to be_nil
    expect(TBD.status).to be_zero

    argh               = {}
    argh[:option     ] = "(non thermal bridging)"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_seb_n4.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(56)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(80)

    # As the :building PSI set on file == "(non thermal bridging)", derating
    # shouldn't occur at large. However, the JSON file holds a custom edge
    # entry for "Entryway  Wall 5" : "bad" fenestration perimeters, which
    # only derates the host wall itself
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"

      expect(surface).to_not have_key(:ratio)           unless id == name
      expect(surface[:heatloss]).to be_within(TOL).of(8.89) if id == name
    end
  end

  it "can pre-process UA parameters" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    ref   = "code (Quebec)"
    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    heated = TBD.heatingTemperatureSetpoints?(model)
    cooled = TBD.coolingTemperatureSetpoints?(model)
    expect(heated).to be true
    expect(cooled).to be true

    model.getSpaces.each do |space|
      expect(TBD.unconditioned?(space)).to be false
      stpts = TBD.setpoints(space)
      expect(stpts).to be_a(Hash)
      expect(stpts).to have_key(:heating)
      expect(stpts).to have_key(:cooling)

      heating = stpts[:heating]
      cooling = stpts[:cooling]
      expect(heating).to be_a(Numeric)
      expect(cooling).to be_a(Numeric)

      if space.nameString == "Zone1 Office"
        expect(heating).to be_within(0.1).of(21.1)
        expect(cooling).to be_within(0.1).of(23.9)
      elsif space.nameString == "Zone2 Fine Storage"
        expect(heating).to be_within(0.1).of(15.6)
        expect(cooling).to be_within(0.1).of(26.7)
      else
        expect(heating).to be_within(0.1).of(10.0)
        expect(cooling).to be_within(0.1).of(50.0)
      end
    end

    ids = { a: "Office Front Wall",
            b: "Office Left Wall",
            c: "Fine Storage Roof",
            d: "Fine Storage Office Front Wall",
            e: "Fine Storage Office Left Wall",
            f: "Fine Storage Front Wall",
            g: "Fine Storage Left Wall",
            h: "Fine Storage Right Wall",
            i: "Bulk Storage Roof",
            j: "Bulk Storage Rear Wall",
            k: "Bulk Storage Left Wall",
            l: "Bulk Storage Right Wall"
          }.freeze

    id2 = { a: "Office Front Door",
            b: "Office Left Wall Door",
            c: "Fine Storage Left Door",
            d: "Fine Storage Right Door",
            e: "Bulk Storage Door-1",
            f: "Bulk Storage Door-2",
            g: "Bulk Storage Door-3",
            h: "Overhead Door 1",
            i: "Overhead Door 2",
            j: "Overhead Door 3",
            k: "Overhead Door 4",
            l: "Overhead Door 5",
            m: "Overhead Door 6",
            n: "Overhead Door 7"
          }.freeze

    psi   = TBD::PSI.new
    shrts = psi.shorthands(ref)

    expect(shrts[:has]).to_not be_empty
    expect(shrts[:val]).to_not be_empty
    has = shrts[:has]
    val = shrts[:val]

    expect(has).to_not be_empty
    expect(val).to_not be_empty

    argh               = {}
    argh[:option     ] = "poor (BETBG)"
    argh[:seed       ] = "./files/osms/in/warehouse.osm"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_warehouse10.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    argh[:gen_ua     ] = true
    argh[:ua_ref     ] = ref
    argh[:version    ] = OpenStudio.openStudioVersion

    TBD.process(model, argh)
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty

    expect(argh).to have_key(:surfaces)
    expect(argh).to have_key(:io)
    expect(argh[:surfaces]).to be_a(Hash)
    expect(argh[:surfaces].size).to eq(23)

    expect(argh[:io]).to be_a(Hash)
    expect(argh[:io]).to_not be_empty
    expect(argh[:io]).to have_key(:edges)
    expect(argh[:io][:edges].size).to eq(300)

    argh[:io][:description] = "test"
    # Set up 2x heating setpoint (HSTP) "blocks":
    #   bloc1: spaces/zones with HSTP >= 18°C
    #   bloc2: spaces/zones with HSTP < 18°C
    #   (ref: 2021 Quebec energy code 3.3. UA' trade-off methodology)
    #   ... could be generalized in the future e.g., more blocks, user-set HSTP.
    #
    # Determine UA' compliance separately for (i) bloc1 & (ii) bloc2.
    #
    # Each block's UA' = ∑ U•area + ∑ PSI•length + ∑ KHI•count
    blc = { walls:   0, roofs:     0, floors:    0, doors:     0,
            windows: 0, skylights: 0, rimjoists: 0, parapets:  0,
            trim:    0, corners:   0, balconies: 0, grade:     0,
            other:   0 # includes party wall edges, expansion joints, etc.
          }

    bloc1       = {}
    bloc2       = {}
    bloc1[:pro] = blc
    bloc1[:ref] = blc.clone
    bloc2[:pro] = blc.clone
    bloc2[:ref] = blc.clone

    argh[:surfaces].each do |id, surface|
      expect(surface).to have_key(:deratable)
      next unless surface[:deratable]

      expect(ids).to have_value(id)
      expect(surface).to have_key(:type)
      expect(surface).to have_key(:net )
      expect(surface).to have_key(:u)

      expect(surface[:net] > TOL).to be true
      expect(surface[:u  ] > TOL).to be true

      expect(surface[:u]).to be_within(TOL).of(0.48) if id == ids[:a]
      expect(surface[:u]).to be_within(TOL).of(0.48) if id == ids[:b]
      expect(surface[:u]).to be_within(TOL).of(0.31) if id == ids[:c]
      expect(surface[:u]).to be_within(TOL).of(0.48) if id == ids[:d]
      expect(surface[:u]).to be_within(TOL).of(0.48) if id == ids[:e]
      expect(surface[:u]).to be_within(TOL).of(0.48) if id == ids[:f]
      expect(surface[:u]).to be_within(TOL).of(0.48) if id == ids[:g]
      expect(surface[:u]).to be_within(TOL).of(0.48) if id == ids[:h]
      expect(surface[:u]).to be_within(TOL).of(0.55) if id == ids[:i]
      expect(surface[:u]).to be_within(TOL).of(0.64) if id == ids[:j]
      expect(surface[:u]).to be_within(TOL).of(0.64) if id == ids[:k]
      expect(surface[:u]).to be_within(TOL).of(0.64) if id == ids[:l]

      # Reference values.
      expect(surface).to have_key(:ref)

      expect(surface[:ref]).to be_within(TOL).of(0.28) if id == ids[:a]
      expect(surface[:ref]).to be_within(TOL).of(0.28) if id == ids[:b]
      expect(surface[:ref]).to be_within(TOL).of(0.18) if id == ids[:c]
      expect(surface[:ref]).to be_within(TOL).of(0.28) if id == ids[:d]
      expect(surface[:ref]).to be_within(TOL).of(0.28) if id == ids[:e]
      expect(surface[:ref]).to be_within(TOL).of(0.28) if id == ids[:f]
      expect(surface[:ref]).to be_within(TOL).of(0.28) if id == ids[:g]
      expect(surface[:ref]).to be_within(TOL).of(0.28) if id == ids[:h]
      expect(surface[:ref]).to be_within(TOL).of(0.23) if id == ids[:i]
      expect(surface[:ref]).to be_within(TOL).of(0.34) if id == ids[:j]
      expect(surface[:ref]).to be_within(TOL).of(0.34) if id == ids[:k]
      expect(surface[:ref]).to be_within(TOL).of(0.34) if id == ids[:l]

      expect(surface).to have_key(:heating)
      expect(surface).to have_key(:cooling)
      bloc = bloc1
      bloc = bloc2 if surface[:heating] < 18

      if surface[:type ] == :wall
        bloc[:pro][:walls ] += surface[:net] * surface[:u  ]
        bloc[:ref][:walls ] += surface[:net] * surface[:ref]
      elsif surface[:type ] == :ceiling
        bloc[:pro][:roofs ] += surface[:net] * surface[:u  ]
        bloc[:ref][:roofs ] += surface[:net] * surface[:ref]
      else
        bloc[:pro][:floors] += surface[:net] * surface[:u  ]
        bloc[:ref][:floors] += surface[:net] * surface[:ref]
      end

      if surface.key?(:doors)
        surface[:doors].each do |i, door|
          expect(id2).to have_value(i)
          expect(door).to_not have_key(:glazed)
          expect(door).to have_key(:gross )
          expect(door).to have_key(:u)
          expect(door).to have_key(:ref)
          expect(door[:gross] > TOL).to be true
          expect(door[:ref  ] > TOL).to be true
          expect(door[:u    ] > TOL).to be true
          expect(door[:u    ]).to be_within(TOL).of(3.98)
          bloc[:pro][:doors] += door[:gross] * door[:u  ]
          bloc[:ref][:doors] += door[:gross] * door[:ref]
        end
      end

      if surface.key?(:skylights)
        surface[:skylights].each do |i, skylight|
          expect(skylight).to have_key(:gross)
          expect(skylight).to have_key(:u)
          expect(skylight).to have_key(:ref)
          expect(skylight[:gross] > TOL).to be true
          expect(skylight[:ref  ] > TOL).to be true
          expect(skylight[:u    ] > TOL).to be true
          expect(skylight[:u    ]).to be_within(TOL).of(6.64)
          bloc[:pro][:skylights] += skylight[:gross] * skylight[:u  ]
          bloc[:ref][:skylights] += skylight[:gross] * skylight[:ref]
        end
      end

      id3 = { a: "Office Front Wall Window 1",
              b: "Office Front Wall Window2"
            }.freeze

      if surface.key?(:windows)
        surface[:windows].each do |i, window|
          expect(window).to have_key(:u)
          expect(window).to have_key(:ref)
          expect(window[:ref] > TOL).to be true

          bloc[:pro][:windows] += window[:gross] * window[:u  ]
          bloc[:ref][:windows] += window[:gross] * window[:ref]

          expect(window[:u    ] > 0).to be true
          expect(window[:u    ]).to be_within(TOL).of(4.00) if i == id3[:a]
          expect(window[:u    ]).to be_within(TOL).of(3.50) if i == id3[:b]
          expect(window[:gross]).to be_within(TOL).of(5.58) if i == id3[:a]
          expect(window[:gross]).to be_within(TOL).of(5.58) if i == id3[:b]

          next if [id3[:a], id3[:b]].include?(i)

          expect(window[:gross]).to be_within(TOL).of(3.25)
          expect(window[:u    ]).to be_within(TOL).of(2.35)
        end
      end

      if surface.key?(:edges)
        surface[:edges].values.each do |edge|
          expect(edge).to have_key(:type )
          expect(edge).to have_key(:ratio)
          expect(edge).to have_key(:ref  )
          expect(edge).to have_key(:psi  )
          next unless edge[:psi] > TOL

          tt = psi.safe(ref, edge[:type])
          expect(tt).to_not be_nil

          expect(edge[:ref]).to be_within(TOL).of(val[tt] * edge[:ratio])
          rate = edge[:ref] / edge[:psi] * 100

          case tt
          when :rimjoist
            expect(rate).to be_within(0.1).of(30.0)
            bloc[:pro][:rimjoists] += edge[:length] * edge[:psi  ]
            bloc[:ref][:rimjoists] += edge[:length] * edge[:ratio] * val[tt]
          when :parapet
            expect(rate).to be_within(0.1).of(40.6)
            bloc[:pro][:parapets ] += edge[:length] * edge[:psi  ]
            bloc[:ref][:parapets ] += edge[:length] * edge[:ratio] * val[tt]
          when :fenestration
            expect(rate).to be_within(0.1).of(40.0)
            bloc[:pro][:trim     ] += edge[:length] * edge[:psi  ]
            bloc[:ref][:trim     ] += edge[:length] * edge[:ratio] * val[tt]
          when :door
            expect(rate).to be_within(0.1).of(40.0)
            bloc[:pro][:trim     ] += edge[:length] * edge[:psi  ]
            bloc[:ref][:trim     ] += edge[:length] * edge[:ratio] * val[tt]
          when :skylight
            expect(rate).to be_within(0.1).of(40.0)
            bloc[:pro][:trim     ] += edge[:length] * edge[:psi  ]
            bloc[:ref][:trim     ] += edge[:length] * edge[:ratio] * val[tt]
          when :corner
            expect(rate).to be_within(0.1).of(35.3)
            bloc[:pro][:corners  ] += edge[:length] * edge[:psi  ]
            bloc[:ref][:corners  ] += edge[:length] * edge[:ratio] * val[tt]
          when :grade
            expect(rate).to be_within(0.1).of(52.9)
            bloc[:pro][:grade    ] += edge[:length] * edge[:psi  ]
            bloc[:ref][:grade    ] += edge[:length] * edge[:ratio] * val[tt]
          else
            expect(rate).to be_within(0.1).of( 0.0)
            bloc[:pro][:other    ] += edge[:length] * edge[:psi  ]
            bloc[:ref][:other    ] += edge[:length] * edge[:ratio] * val[tt]
          end
        end
      end

      if surface.key?(:pts)
        surface[:pts].values.each do |pts|
          expect(pts).to have_key(:val)
          expect(pts).to have_key(:n)
          expect(pts).to have_key(:ref)
          bloc[:pro][:other] += pts[:val] * pts[:n]
          bloc[:ref][:other] += pts[:ref] * pts[:n]
        end
      end
    end

    expect(bloc1[:pro][:walls    ]).to be_within(0.1).of(  60.1)
    expect(bloc1[:pro][:roofs    ]).to be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:floors   ]).to be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:doors    ]).to be_within(0.1).of(  23.3)
    expect(bloc1[:pro][:windows  ]).to be_within(0.1).of(  57.1)
    expect(bloc1[:pro][:skylights]).to be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:rimjoists]).to be_within(0.1).of(  17.5)
    expect(bloc1[:pro][:parapets ]).to be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:trim     ]).to be_within(0.1).of(  23.3)
    expect(bloc1[:pro][:corners  ]).to be_within(0.1).of(   3.6)
    expect(bloc1[:pro][:balconies]).to be_within(0.1).of(   0.0)
    expect(bloc1[:pro][:grade    ]).to be_within(0.1).of(  29.8)
    expect(bloc1[:pro][:other    ]).to be_within(0.1).of(   0.0)

    bloc1_pro_UA = bloc1[:pro].values.reduce(:+)
    bloc1_ref_UA = bloc1[:ref].values.reduce(:+)
    bloc2_pro_UA = bloc2[:pro].values.reduce(:+)
    bloc2_ref_UA = bloc2[:ref].values.reduce(:+)

    expect(bloc1_pro_UA).to be_within(0.1).of( 214.8)
    expect(bloc1_ref_UA).to be_within(0.1).of( 107.2)
    expect(bloc2_pro_UA).to be_within(0.1).of(4863.6)
    expect(bloc2_ref_UA).to be_within(0.1).of(2275.4)

    expect(bloc1[:ref][:walls    ]).to be_within(0.1).of(  35.0)
    expect(bloc1[:ref][:roofs    ]).to be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:floors   ]).to be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:doors    ]).to be_within(0.1).of(   5.3)
    expect(bloc1[:ref][:windows  ]).to be_within(0.1).of(  35.3)
    expect(bloc1[:ref][:skylights]).to be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:rimjoists]).to be_within(0.1).of(   5.3)
    expect(bloc1[:ref][:parapets ]).to be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:trim     ]).to be_within(0.1).of(   9.3)
    expect(bloc1[:ref][:corners  ]).to be_within(0.1).of(   1.3)
    expect(bloc1[:ref][:balconies]).to be_within(0.1).of(   0.0)
    expect(bloc1[:ref][:grade    ]).to be_within(0.1).of(  15.8)
    expect(bloc1[:ref][:other    ]).to be_within(0.1).of(   0.0)

    expect(bloc2[:pro][:walls    ]).to be_within(0.1).of(1342.0)
    expect(bloc2[:pro][:roofs    ]).to be_within(0.1).of(2169.2)
    expect(bloc2[:pro][:floors   ]).to be_within(0.1).of(   0.0)
    expect(bloc2[:pro][:doors    ]).to be_within(0.1).of( 245.6)
    expect(bloc2[:pro][:windows  ]).to be_within(0.1).of(   0.0)
    expect(bloc2[:pro][:skylights]).to be_within(0.1).of( 454.3)
    expect(bloc2[:pro][:rimjoists]).to be_within(0.1).of(  17.5)
    expect(bloc2[:pro][:parapets ]).to be_within(0.1).of( 234.1)
    expect(bloc2[:pro][:trim     ]).to be_within(0.1).of( 155.0)
    expect(bloc2[:pro][:corners  ]).to be_within(0.1).of(  25.4)
    expect(bloc2[:pro][:balconies]).to be_within(0.1).of(   0.0)
    expect(bloc2[:pro][:grade    ]).to be_within(0.1).of( 218.9)
    expect(bloc2[:pro][:other    ]).to be_within(0.1).of(   1.6)

    expect(bloc2[:ref][:walls    ]).to be_within(0.1).of( 732.0)
    expect(bloc2[:ref][:roofs    ]).to be_within(0.1).of( 961.8)
    expect(bloc2[:ref][:floors   ]).to be_within(0.1).of(   0.0)
    expect(bloc2[:ref][:doors    ]).to be_within(0.1).of(  67.5)
    expect(bloc2[:ref][:windows  ]).to be_within(0.1).of(   0.0)
    expect(bloc2[:ref][:skylights]).to be_within(0.1).of( 225.9)
    expect(bloc2[:ref][:rimjoists]).to be_within(0.1).of(   5.3)
    expect(bloc2[:ref][:parapets ]).to be_within(0.1).of(  95.1)
    expect(bloc2[:ref][:trim     ]).to be_within(0.1).of(  62.0)
    expect(bloc2[:ref][:corners  ]).to be_within(0.1).of(   9.0)
    expect(bloc2[:ref][:balconies]).to be_within(0.1).of(   0.0)
    expect(bloc2[:ref][:grade    ]).to be_within(0.1).of( 115.9)
    expect(bloc2[:ref][:other    ]).to be_within(0.1).of(   1.0)

    # Testing summaries function.
    ua = TBD.ua_summary(Time.now, argh)
    expect(ua).to_not be_nil
    expect(ua).to_not be_empty
    expect(ua).to be_a(Hash)
    expect(ua).to have_key(:model)
    expect(ua).to have_key(:fr)

    expect(ua[:fr]).to have_key(:objective)
    expect(ua[:fr]).to have_key(:details)
    expect(ua[:fr]).to have_key(:areas)
    expect(ua[:fr]).to have_key(:notes)

    expect(ua[:fr][:objective]).to_not be_empty

    expect(ua[:fr][:details]).to be_a(Array)
    expect(ua[:fr][:details]).to_not be_empty

    expect(ua[:fr][:areas]).to be_a(Hash)
    expect(ua[:fr][:areas]).to_not be_empty
    expect(ua[:fr][:areas]).to have_key(:walls)
    expect(ua[:fr][:areas]).to have_key(:roofs)
    expect(ua[:fr][:areas]).to_not have_key(:floors)
    expect(ua[:fr][:notes]).to_not be_empty

    expect(ua[:fr]).to have_key(:b1)
    expect(ua[:fr][:b1]).to_not be_empty
    expect(ua[:fr][:b1]).to have_key(:summary)
    expect(ua[:fr][:b1]).to have_key(:walls)
    expect(ua[:fr][:b1]).to have_key(:doors)
    expect(ua[:fr][:b1]).to have_key(:windows)
    expect(ua[:fr][:b1]).to have_key(:rimjoists)
    expect(ua[:fr][:b1]).to have_key(:trim)
    expect(ua[:fr][:b1]).to have_key(:corners)
    expect(ua[:fr][:b1]).to have_key(:grade)
    expect(ua[:fr][:b1]).to_not have_key(:roofs)
    expect(ua[:fr][:b1]).to_not have_key(:floors)
    expect(ua[:fr][:b1]).to_not have_key(:skylights)
    expect(ua[:fr][:b1]).to_not have_key(:parapets)
    expect(ua[:fr][:b1]).to_not have_key(:balconies)
    expect(ua[:fr][:b1]).to_not have_key(:other)

    expect(ua[:fr]).to have_key(:b2)
    expect(ua[:fr][:b2]).to_not be_empty
    expect(ua[:fr][:b2]).to have_key(:summary)
    expect(ua[:fr][:b2]).to have_key(:walls)
    expect(ua[:fr][:b2]).to have_key(:roofs)
    expect(ua[:fr][:b2]).to have_key(:doors)
    expect(ua[:fr][:b2]).to have_key(:skylights)
    expect(ua[:fr][:b2]).to have_key(:rimjoists)
    expect(ua[:fr][:b2]).to have_key(:parapets)
    expect(ua[:fr][:b2]).to have_key(:trim)
    expect(ua[:fr][:b2]).to have_key(:corners)
    expect(ua[:fr][:b2]).to have_key(:grade)
    expect(ua[:fr][:b2]).to have_key(:other)
    expect(ua[:fr][:b2]).to_not have_key(:floors)
    expect(ua[:fr][:b2]).to_not have_key(:windows)
    expect(ua[:fr][:b2]).to_not have_key(:balconies)

    expect(ua[:en]).to have_key(:b1)
    expect(ua[:en][:b1]).to_not be_empty
    expect(ua[:en][:b1]).to have_key(:summary)
    expect(ua[:en][:b1]).to have_key(:walls)
    expect(ua[:en][:b1]).to have_key(:doors)
    expect(ua[:en][:b1]).to have_key(:windows)
    expect(ua[:en][:b1]).to have_key(:rimjoists)
    expect(ua[:en][:b1]).to have_key(:trim)
    expect(ua[:en][:b1]).to have_key(:corners)
    expect(ua[:en][:b1]).to have_key(:grade)
    expect(ua[:en][:b1]).to_not have_key(:roofs)
    expect(ua[:en][:b1]).to_not have_key(:floors)
    expect(ua[:en][:b1]).to_not have_key(:skylights)
    expect(ua[:en][:b1]).to_not have_key(:parapets )
    expect(ua[:en][:b1]).to_not have_key(:balconies)
    expect(ua[:en][:b1]).to_not have_key(:other)

    expect(ua[:en]).to have_key(:b2)
    expect(ua[:en][:b2]).to_not be_empty
    expect(ua[:en][:b2]).to have_key(:summary)
    expect(ua[:en][:b2]).to have_key(:walls)
    expect(ua[:en][:b2]).to have_key(:roofs)
    expect(ua[:en][:b2]).to have_key(:doors)
    expect(ua[:en][:b2]).to have_key(:skylights)
    expect(ua[:en][:b2]).to have_key(:rimjoists)
    expect(ua[:en][:b2]).to have_key(:parapets)
    expect(ua[:en][:b2]).to have_key(:trim)
    expect(ua[:en][:b2]).to have_key(:corners)
    expect(ua[:en][:b2]).to have_key(:grade)
    expect(ua[:en][:b2]).to have_key(:other)
    expect(ua[:en][:b2]).to_not have_key(:floors)
    expect(ua[:en][:b2]).to_not have_key(:windows)
    expect(ua[:en][:b2]).to_not have_key(:balconies)

    ud_md_en = TBD.ua_md(ua, :en)
    ud_md_fr = TBD.ua_md(ua, :fr)
    path_en  = File.join(__dir__, "files/ua/ua_en.md")
    path_fr  = File.join(__dir__, "files/ua/ua_fr.md")

    File.open(path_en, "w") { |file| file.puts ud_md_en }
    File.open(path_fr, "w") { |file| file.puts ud_md_fr }

    # Try with an incomplete reference, e.g. (non thermal bridging).
    TBD.clean!

    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    # When faced with an edge that may be characterized by more than one thermal
    # bridge type (e.g. ground-floor door "sill" vs "grade" edge; "corner" vs
    # corner window "jamb"), TBD retains the edge type (amongst candidate edge
    # types) representing the greatest heat loss:
    #
    #   psi = edge[:psi].values.max
    #   type = edge[:psi].key(psi)
    #
    # As long as there is a slight difference in PSI-values between candidate
    # edge types, the automated selection will be deterministic. With 2 or more
    # edge types sharing the exact same PSI factor (e.g. 0.3 W/K per m), the
    # final selection of edge type becomes less obvious. It is not randomly
    # selected, but rather based on the (somewhat arbitrary) design choice of
    # which edge type is processed first in psi.rb (line ~1300 onwards). For
    # instance, fenestration perimeter joints are treated before corners or
    # parapets. When dealing with equal hash values, Ruby's Hash "key" method
    # returns the first key (i.e. edge type) that matches the criterion:
    #
    #   https://docs.ruby-lang.org/en/2.0.0/Hash.html#method-i-key
    #
    # From an energy simulation results perspective, the consequences of this
    # pseudo-random choice are insignificant (i.e. same PSI-value). For UA'
    # comparisons, the situation becomes less obvious in outlier cases. When a
    # reference value needs to be generated for the edge described above, TBD
    # retains the original autoselected edge type, yet applies reference PSI
    # values (e.g. code). So far so good. However, when "(non thermal bridging)"
    # is retained as a default PSI design set (not as a reference set), all edge
    # types will necessarily have 0 W/K per metre as PSI-values. Same with the
    # "efficient (BETBG)" PSI set (all but one type at 0.2 W/K per m). Not
    # obvious (for users) which edge type will be selected by TBD for multi-type
    # edges. This also has the undesirable effect of generating variations in
    # reference UA' tallies, depending on the chosen design PSI set (as the
    # reference PSI set may have radically different PSI-values depending on
    # the pseudo-random edge type selection). Fortunately, this effect is
    # limited to the somewhat academic PSI sets like "(non thermal bridging)" or
    # "efficient (BETBG)".
    #
    # In the end, the above discussion remains an "aide-mémoire" for future
    # guide material, yet also as a basis for peer-review commentary of upcoming
    # standards on thermal bridging.
    argh[:io         ] = nil
    argh[:surfaces   ] = nil
    argh[:option     ] = "(non thermal bridging)"
    argh[:io_path    ] = nil
    argh[:schema_path] = nil
    argh[:gen_ua     ] = true
    argh[:ua_ref     ] = ref

    TBD.process(model, argh)
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(argh).to have_key(:surfaces)
    expect(argh).to have_key(:io)

    expect(argh[:surfaces]).to be_a(Hash)
    expect(argh[:surfaces].size).to eq(23)

    expect(argh[:io]).to be_a(Hash)
    expect(argh[:io]).to have_key(:edges)
    expect(argh[:io][:edges].size).to eq(300)

    # Testing summaries function.
    argh[:io][:description] = "testing non thermal bridging"

    ua = TBD.ua_summary(Time.now, argh)
    expect(ua).to_not be_nil
    expect(ua).to be_a(Hash)
    expect(ua).to_not be_empty
    expect(ua).to have_key(:model)

    en_ud_md = TBD.ua_md(ua, :en)
    fr_ud_md = TBD.ua_md(ua, :fr)
    path_en  = File.join(__dir__, "files/ua/en_ua.md")
    path_fr  = File.join(__dir__, "files/ua/fr_ua.md")
    File.open(path_en, "w") { |file| file.puts en_ud_md }
    File.open(path_fr, "w") { |file| file.puts fr_ud_md }
  end

  it "can work off of a cloned model" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    argh1 = { option: "poor (BETBG)" }
    argh2 = { option: "poor (BETBG)" }
    argh3 = { option: "poor (BETBG)" }

    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get
    mdl   = model.clone
    fil   = File.join(__dir__, "files/osms/out/alt_warehouse.osm")
    mdl.save(fil, true)

    # Despite one being the clone of the other, files will not be identical,
    # namely due to unique handles.
    expect(FileUtils).to_not be_identical(file, fil)

    TBD.process(model, argh1)
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty

    expect(argh1).to have_key(:surfaces)
    expect(argh1).to have_key(:io)

    expect(argh1[:surfaces]).to be_a(Hash)
    expect(argh1[:surfaces].size).to eq(23)

    expect(argh1[:io]).to be_a(Hash)
    expect(argh1[:io]).to have_key(:edges)
    expect(argh1[:io][:edges].size).to eq(300)

    out  = JSON.pretty_generate(argh1[:io])
    outP = File.join(__dir__, "../json/tbd_warehouse12.out.json")
    File.open(outP, "w") { |outP| outP.puts out }

    TBD.clean!
    fil  = File.join(__dir__, "files/osms/out/alt_warehouse.osm")
    pth  = OpenStudio::Path.new(fil)
    mdl  = translator.loadModel(pth)
    expect(mdl).to_not be_empty
    mdl  = mdl.get

    TBD.process(mdl, argh2)
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty

    expect(argh2).to have_key(:surfaces)
    expect(argh2).to have_key(:io)

    expect(argh2[:surfaces]).to be_a(Hash)
    expect(argh2[:surfaces].size).to eq(23)

    expect(argh2[:io]).to be_a(Hash)
    expect(argh2[:io]).to have_key(:edges)
    expect(argh2[:io][:edges].size).to eq(300)

    # The JSON output files are identical.
    out2  = JSON.pretty_generate(argh2[:io])
    outP2 = File.join(__dir__, "../json/tbd_warehouse13.out.json")
    File.open(outP2, "w") { |outP2| outP2.puts out2 }
    expect(FileUtils).to be_identical(outP, outP2)

    time = Time.now

    # Original output UA' MD file.
    argh1[:ua_ref          ] = "code (Quebec)"
    argh1[:io][:description] = "testing equality"
    argh1[:version         ] = OpenStudio.openStudioVersion
    argh1[:seed            ] = File.join(__dir__, "files/osms/in/warehouse.osm")

    o_ua = TBD.ua_summary(time, argh1)
    expect(o_ua).to_not be_nil
    expect(o_ua).to_not be_empty
    expect(o_ua).to be_a(Hash)
    expect(o_ua).to have_key(:model)

    o_ud_md_en = TBD.ua_md(o_ua, :en)
    path1      = File.join(__dir__, "files/ua/o_ua_en.md")
    File.open(path1, "w") { |file| file.puts o_ud_md_en }

    # Alternate output UA' MD file.
    argh2[:ua_ref          ] = "code (Quebec)"
    argh2[:io][:description] = "testing equality"
    argh2[:version         ] = OpenStudio.openStudioVersion
    argh2[:seed            ] = File.join(__dir__, "files/osms/in/warehouse.osm")

    alt_ua = TBD.ua_summary(time, argh2)
    expect(alt_ua).to_not be_nil
    expect(alt_ua).to_not be_empty
    expect(alt_ua).to be_a(Hash)
    expect(alt_ua).to have_key(:model)

    alt_ud_md_en = TBD.ua_md(alt_ua, :en)
    path2        = File.join(__dir__, "files/ua/alt_ua_en.md")
    File.open(path2, "w") { |file| file.puts alt_ud_md_en }

    # Both output UA' MD files should be identical.
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(FileUtils).to be_identical(path1, path2)

    # Testing the Macumber suggestion (thumbs' up).
    TBD.clean!

    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    mdl2 = OpenStudio::Model::Model.new
    mdl2.addObjects(model.toIdfFile.objects)
    fil2 = File.join(__dir__, "files/osms/out/alt2_warehouse.osm")
    mdl2.save(fil2, true)

    # Still get the differences in handles (not consequential at all if the TBD
    # JSON output files are identical).
    expect(FileUtils).to_not be_identical(file, fil2)

    TBD.process(mdl2, argh3)
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty

    expect(argh3).to have_key(:surfaces)
    expect(argh3).to have_key(:io)

    expect(argh3[:surfaces]).to be_a(Hash)
    expect(argh3[:surfaces].size).to eq(23)

    expect(argh3[:io]).to be_a(Hash)
    expect(argh3[:io]).to have_key(:edges)
    expect(argh3[:io][:edges].size).to eq(300)

    out3  = JSON.pretty_generate(argh3[:io])
    outP3 = File.join(__dir__, "../json/tbd_warehouse14.out.json")
    File.open(outP3, "w") { |outP3| outP3.puts out3 }

    # Nice. Both TBD JSON output files are identical!
    # "/../json/tbd_warehouse12.out.json" vs "/../json/tbd_warehouse14.out.json"
    expect(FileUtils).to be_identical(outP, outP3)
  end

  it "can generate and access KIVA inputs (seb)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    # For continuous insulation and/or finishings, OpenStudio/EnergyPlus/Kiva
    # offer 2x solutions :
    #
    #   1. Add standard - not massless - materials as new construction layers
    #   2. Add Kiva custom blocks
    #
    # ... sticking with Option #1. A few examples:

    # Generic 1-1/2" XPS insulation.
    xps_38mm = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    xps_38mm.setName("XPS_38mm")
    xps_38mm.setRoughness("Rough")
    xps_38mm.setThickness(0.0381)
    xps_38mm.setConductivity(0.029)
    xps_38mm.setDensity(28)
    xps_38mm.setSpecificHeat(1450)
    xps_38mm.setThermalAbsorptance(0.9)
    xps_38mm.setSolarAbsorptance(0.7)

    # 1. Current code-compliant slab-on-grade (perimeter) solution.
    kiva_slab_2020s = OpenStudio::Model::FoundationKiva.new(model)
    kiva_slab_2020s.setName("Kiva slab 2020s")
    kiva_slab_2020s.setInteriorHorizontalInsulationMaterial(xps_38mm)
    kiva_slab_2020s.setInteriorHorizontalInsulationWidth(1.2)
    kiva_slab_2020s.setInteriorVerticalInsulationMaterial(xps_38mm)
    kiva_slab_2020s.setInteriorVerticalInsulationDepth(0.138)

    # 2. Beyond-code slab-on-grade (continuous) insulation setup. Add 1-1/2"
    #    XPS insulation layer (under slab) to surface construction.
    kiva_slab_HP = OpenStudio::Model::FoundationKiva.new(model)
    kiva_slab_HP.setName("Kiva slab HP")

    # 3. Do the same for (full height) basements - no insulation under slab for
    #    vintages 1980s & 2020s. Add (full-height) layered insulation and/or
    #    finishing to basement wall construction.
    kiva_basement = OpenStudio::Model::FoundationKiva.new(model)
    kiva_basement.setName("Kiva basement")

    # 4. Beyond-code basement slab (perimeter) insulation setup. Add
    #    (full-height)layered insulation and/or finishing to basement wall
    #    construction.
    kiva_basement_HP = OpenStudio::Model::FoundationKiva.new(model)
    kiva_basement_HP.setName("Kiva basement HP")
    kiva_basement_HP.setInteriorHorizontalInsulationMaterial(xps_38mm)
    kiva_basement_HP.setInteriorHorizontalInsulationWidth(1.2)
    kiva_basement_HP.setInteriorVerticalInsulationMaterial(xps_38mm)
    kiva_basement_HP.setInteriorVerticalInsulationDepth(0.138)

    # Set "Foundation" as boundary condition of 1x slab-on-grade, and link it
    # to 1x Kiva Foundation object.
    oa1f = model.getSurfaceByName("Open area 1 Floor")
    expect(oa1f).to_not be_empty
    oa1f = oa1f.get

    expect(oa1f.setOutsideBoundaryCondition("Foundation")).to be true
    oa1f.setAdjacentFoundation(kiva_slab_2020s)
    construction = oa1f.construction
    expect(construction).to_not be_empty
    construction = construction.get
    expect(oa1f.setConstruction(construction)).to be true

    arg = "TotalExposedPerimeter"
    per = oa1f.createSurfacePropertyExposedFoundationPerimeter(arg, 12.59)
    expect(per).to_not be_empty

    file = File.join(__dir__, "files/osms/out/seb_KIVA.osm")
    model.save(file, true)

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Re-open for testing.
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    oa1f = model.getSurfaceByName("Open area 1 Floor")
    expect(oa1f).to_not be_empty
    oa1f = oa1f.get

    expect(oa1f.outsideBoundaryCondition.downcase).to eq("foundation")
    foundation = oa1f.adjacentFoundation
    expect(foundation).to_not be_empty
    foundation = foundation.get

    oa15 = model.getSurfaceByName("Openarea 1 Wall 5") # 3.89m wide
    expect(oa15).to_not be_empty
    oa15 = oa15.get

    construction = oa15.construction.get
    expect(oa15.setOutsideBoundaryCondition("Foundation")).to be true
    expect(oa15.setAdjacentFoundation(foundation)        ).to be true
    expect(oa15.setConstruction(construction)            ).to be true

    kfs = model.getFoundationKivas
    expect(kfs).to_not be_empty
    expect(kfs.size).to eq(4)

    settings = model.getFoundationKivaSettings
    expect(settings.soilConductivity).to be_within(TOL).of(1.73)

    argh            = {}
    argh[:option  ] = "poor (BETBG)"
    argh[:gen_kiva] = true

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(56)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(105)

    found_floor = false
    found_wall  = false

    surfaces.each do |id, surface|
      next unless surface.key?(:kiva)

      expect(id).to eq("Open area 1 Floor").or eq("Openarea 1 Wall 5")

      if id == "Open area 1 Floor"
        expect(surface[:kiva]).to eq(:basement)
        expect(surface).to have_key(:exposed)
        expect(surface[:exposed]).to be_within(TOL).of(8.70) # 12.6 - 3.9
        found_floor = true
      else
        expect(surface[:kiva]).to eq("Open area 1 Floor")
        found_wall = true
      end
    end

    expect(found_floor).to be true
    expect(found_wall ).to be true

    file = File.join(__dir__, "files/osms/out/seb_KIVA2.osm")
    model.save(file, true)

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Re-open & test initial model.
    TBD.clean!
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    model.getSurfaces.each do |s|
      next unless s.isGroundSurface
      next unless s.surfaceType.downcase == "floor"

      expect(s.setOutsideBoundaryCondition("Foundation")).to be true
    end

    argh            = {}
    argh[:option  ] = "(non thermal bridging)"
    argh[:gen_kiva] = true

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(56)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(106)

    surfaces.each do |id, s|
      next unless s.key?(:kiva)

      expect(s).to have_key(:exposed)
      slab = model.getSurfaceByName(id)
      expect(slab).to_not be_empty
      slab = slab.get

      expect(slab.adjacentFoundation).to_not be_empty
      perimeter = slab.surfacePropertyExposedFoundationPerimeter
      expect(perimeter).to_not be_empty
      perimeter = perimeter.get

      per = perimeter.totalExposedPerimeter
      expect(per).to_not be_empty
      per = per.get
      expect((per - s[:exposed]).abs).to be_within(TOL).of(0)

      expect(per).to be_within(TOL).of( 8.81) if id == "Small office 1 Floor"
      expect(per).to be_within(TOL).of( 8.21) if id == "Utility 1 Floor"
      expect(per).to be_within(TOL).of(12.59) if id == "Open area 1 Floor"
      expect(per).to be_within(TOL).of( 6.95) if id == "Entry way  Floor"
    end

    file = File.join(__dir__, "files/osms/out/seb_KIVA3.osm")
    model.save(file, true)
  end

  it "can generate and access KIVA inputs (midrise apts)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    file  = File.join(__dir__, "files/osms/in/midrise.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    argh            = {}
    argh[:option  ] = "poor (BETBG)"
    argh[:gen_kiva] = true

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(180)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(282)

    # Validate.
    surfaces.each do |id, surface|
      next unless surface.key?(:foundation) # ... only floors
      next unless surface.key?(:kiva)

      expect(surface[:kiva]).to eq(:slab)
      expect(surface).to have_key(:exposed)
      expect(id).to eq("g Floor C")
      expect(surface[:exposed]).to be_within(TOL).of(3.36)
      gFC = model.getSurfaceByName("g Floor C")
      expect(gFC).to_not be_empty
      gFC = gFC.get
      expect(gFC.outsideBoundaryCondition.downcase).to eq("foundation")
    end

    file = File.join(__dir__, "files/osms/out/midrise_KIVA2.osm")
    model.save(file, true)
  end

  it "can test 5ZoneNoHVAC (failed) uprating" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    walls = []
    id    = "ASHRAE 189.1-2009 ExtWall Mass ClimateZone 5"
    file  = File.join(__dir__, "files/osms/in/5ZoneNoHVAC.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    # Get geometry data for testing (4x exterior walls, same construction).
    construction = nil

    model.getSurfaces.each do |s|
      next unless s.surfaceType == "Wall"
      next unless s.outsideBoundaryCondition == "Outdoors"

      walls << s.nameString
      c = s.construction
      expect(c).to_not be_empty
      c = c.get.to_LayeredConstruction
      expect(c).to_not be_empty
      c = c.get

      construction = c if construction.nil?
      expect(c).to eq(construction)
    end

    expect(walls.size              ).to eq( 4)
    expect(construction.nameString ).to eq(id)
    expect(construction.layers.size).to eq( 4)

    insulation = construction.layers[2].to_StandardOpaqueMaterial
    expect(insulation).to_not be_empty
    insulation = insulation.get
    expect(insulation.thickness).to be_within(0.0001).of(0.0794)
    expect(insulation.thermalConductivity).to be_within(0.0001).of(0.0432)
    original_r = insulation.thickness / insulation.thermalConductivity
    expect(original_r).to be_within(TOL).of(1.8380)

    argh = { option: "efficient (BETBG)" } # all PSI factors @ 0.2 W/K•m

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty

    walls.each do |wall|
      expect(surfaces).to have_key(wall)
      expect(surfaces[wall]).to have_key(:heatloss)

      long  = (surfaces[wall][:heatloss] - 27.746).abs < TOL # 40 metres wide
      short = (surfaces[wall][:heatloss] - 14.548).abs < TOL # 20 metres wide
      expect(long || short).to be true
    end

    # The 4-sided model has 2x "long" front/back + 2x "short" side exterior
    # walls, with a total TBD-calculated heat loss (from thermal bridging) of:
    #
    #   2x 27.746 W/K + 2x 14.548 W/K = ~84.588 W/K
    #
    # Spread over ~273.6 m2 of gross wall area, that is A LOT! Why (given the
    # "efficient" PSI factors)? Each wall has a long "strip" window, almost the
    # full wall width (reaching to within a few millimetres of each corner).
    # This ~slices the host wall into 2x very narrow strips. Although the
    # thermal bridging details are considered "efficient", the total length of
    # linear thermal bridges is very high given the limited exposed (gross)
    # area. If area-weighted, derating the insulation layer of the referenced
    # wall construction above would entail factoring in this extra thermal
    # conductance of ~0.309 W/m2•K (84.6/273.6), which would reduce the
    # insulation thickness quite significantly.
    #
    #   Ut = Uo + ( ∑psi • L )/A
    #
    # Expressed otherwise:
    #
    #   Ut = Uo + 0.309
    #
    # So what initial Uo factor should the construction offer (prior to
    # derating) to ensure compliance with NECB2017/2020 prescriptive
    # requirements (one of the few energy codes with prescriptive Ut
    # requirements)? For climate zone 7, the target Ut is 0.210 W/m2•K (Rsi
    # 4.76 m2•K/W or R27). Taking into account air film resistances and
    # non-insulating layer resistances (e.g. ~Rsi 1 m2•K/W), the prescribed
    # (max) layer Ut becomes ~0.277 (Rsi 3.6 or R20.5).
    #
    #   0.277 = Uo? + 0.309
    #
    # Duh-oh! Even with an infinitely thick insulation layer (Uo ~= 0), it
    # would be impossible to reach NECB2017/2020 prescritive requirements with
    # "efficient" thermal breaks. Solutions? Eliminate windows :\ Otherwise,
    # further improve detailing as to achieve ~0.1 W/K per linear metre
    # (easier said than done). Here, an average PSI factor of 0.150 W/K per
    # linear metre (i.e. ~76.1 W/K instead of ~84.6 W/K) still won't cut it
    # for a Uo of 0.01 W/m2•K (Rsi 100 or R568). Instead, an average PSI factor
    # of 0.090 (~45.6 W/K, very high performance) would allow compliance for a
    # Uo of 0.1 W/m2•K (Rsi 10 or R57, ... $$$).
    #
    # Long story short: there will inevitably be cases where TBD is unable to
    # "uprate" a construction prior to "derating". This is neither a TBD bug
    # nor an RP-1365/ISO model limitation. It is simply "bad" input, although
    # likely unintentional. Nevertheless, TBD should exit in such cases with
    # an ERROR message.
    #
    # And if one were to instead model each of the OpenStudio walls described
    # above as 2x distinct OpenStudio surfaces? e.g.:
    #   - 95% of exposed wall area Uo 0.01 W/m2•K
    #   - 5% of exposed wall area as a "thermal bridge" strip (~5.6 W/m2•K *)
    #
    #     * (76.1 W/K over 5% of 273.6 m2)
    #
    # One would still consistently arrive at the same area-weighted average
    # Ut, in this case 0.288 (> 0.277). No free lunches.
    #
    # ---
    #
    # TBD's "uprating" method reorders the equation and attempts the
    # following:
    #
    #   Uo = 0.277 - ( ∑psi • L )/A
    #
    # The method exits with an ERROR in 2x cases:
    #   - calculated Uo is negative, i.e. ( ∑psi • L )/A > 0.277
    #   - calculated layer r violates E+ material constraints (e.g. too thin)

    # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
    # Retrying the previous example, yet requesting uprating calculations:
    TBD.clean!

    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    argh                = {}
    argh[:option      ] = "efficient (BETBG)" # all PSI factors @ 0.2 W/K•m
    argh[:uprate_walls] = true
    argh[:uprate_roofs] = true
    argh[:wall_option ] = "ALL wall constructions"
    argh[:roof_option ] = "ALL roof constructions"
    argh[:wall_ut     ] = 0.210 # NECB CZ7 2017 (RSi 4.76 / R27)
    argh[:roof_ut     ] = 0.138 # NECB CZ7 2017 (RSi 7.25 / R41)

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.error?).to be true
    expect(TBD.logs.size).to eq(2)
    expect(TBD.logs.first[:message]).to include("Zero")
    expect(TBD.logs.first[:message]).to include(": new Rsi")
    expect(TBD.logs.last[ :message]).to include("Unable to uprate")

    expect(argh).to_not have_key(:wall_uo)
    expect(argh).to     have_key(:roof_uo)
    expect(argh[:roof_uo]).to_not be_nil
    expect(argh[:roof_uo]).to be_within(TOL).of(0.118) # RSi 8.47 (R48)

    # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
    # Final attempt, with PSI factors of 0.09 W/K per linear metre (JSON file).
    TBD.clean!

    walls = []
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    argh                = {}
    argh[:io_path     ] = File.join(__dir__, "../json/tbd_5ZoneNoHVAC.json")
    argh[:schema_path ] = File.join(__dir__, "../tbd.schema.json")
    argh[:uprate_walls] = true
    argh[:uprate_roofs] = true
    argh[:wall_option ] = "ALL wall constructions"
    argh[:roof_option ] = "ALL roof constructions"
    argh[:wall_ut     ] = 0.210 # NECB CZ7 2017 (RSi 4.76 / R27)
    argh[:roof_ut     ] = 0.138 # NECB CZ7 2017 (RSi 7.25 / R41)

    json      = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io        = json[:io      ]
    surfaces  = json[:surfaces]
    expect(TBD.status).to be_zero

    expect(argh).to have_key(:wall_uo)
    expect(argh).to have_key(:roof_uo)
    expect(argh[:wall_uo]).to_not be_nil
    expect(argh[:roof_uo]).to_not be_nil
    expect(argh[:wall_uo]).to be_within(TOL).of(0.086) # RSi 11.63 (R66)
    expect(argh[:roof_uo]).to be_within(TOL).of(0.129) # RSi  7.75 (R44)

    model.getSurfaces.each do |s|
      next unless s.surfaceType == "Wall"
      next unless s.outsideBoundaryCondition == "Outdoors"

      walls << s.nameString
      c = s.construction
      expect(c).to_not be_empty
      c = c.get.to_LayeredConstruction
      expect(c).to_not be_empty
      c = c.get

      expect(c.nameString).to include(" c tbd")
      expect(c.layers.size).to eq(4)

      insul = c.layers[2].to_StandardOpaqueMaterial
      expect(insul).to_not be_empty
      insul = insul.get
      expect(insul.nameString).to include(" uprated m tbd")

      expect(insul.thermalConductivity).to be_within(0.0001).of(0.0432)
      th1 = (insul.thickness - 0.191).abs < 0.001 # derated layer Rsi 4.42
      th2 = (insul.thickness - 0.186).abs < 0.001 # derated layer Rsi 4.31
      expect(th1 || th2).to be true # depending if 'short' or 'long' walls
    end

    walls.each do |wall|
      expect(surfaces).to have_key(wall)
      expect(surfaces[wall]).to have_key(:r) # uprated, non-derated layer Rsi
      expect(surfaces[wall]).to have_key(:u) # uprated, non-derated assembly
      expect(surfaces[wall][:r]).to be_within(0.001).of(11.205) # R64
      expect(surfaces[wall][:u]).to be_within(0.001).of( 0.086) # R66
    end

    # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
    # Realistic, BTAP-costed PSI factors.
    TBD.clean!

    jpath = "../json/tbd_5ZoneNoHVAC_btap.json"
    file  = File.join(__dir__, "files/osms/in/5ZoneNoHVAC.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    # Assign (missing) space types.
    north = model.getSpaceByName("Story 1 North Perimeter Space")
    east  = model.getSpaceByName("Story 1 East Perimeter Space")
    south = model.getSpaceByName("Story 1 South Perimeter Space")
    west  = model.getSpaceByName("Story 1 West Perimeter Space")
    core  = model.getSpaceByName("Story 1 Core Space")

    expect(north).to_not be_empty
    expect(east ).to_not be_empty
    expect(south).to_not be_empty
    expect(west ).to_not be_empty
    expect(core ).to_not be_empty

    north = north.get
    east  = east.get
    south = south.get
    west  = west.get
    core  = core.get

    audience  = OpenStudio::Model::SpaceType.new(model)
    warehouse = OpenStudio::Model::SpaceType.new(model)
    offices   = OpenStudio::Model::SpaceType.new(model)
    sales     = OpenStudio::Model::SpaceType.new(model)
    workshop  = OpenStudio::Model::SpaceType.new(model)

    audience.setName("Audience - auditorium")
    warehouse.setName("Warehouse - fine")
    offices.setName("Office - enclosed")
    sales.setName("Sales area")
    workshop.setName("Workshop space")

    expect(north.setSpaceType(audience )).to be true
    expect( east.setSpaceType(warehouse)).to be true
    expect(south.setSpaceType(offices  )).to be true
    expect( west.setSpaceType(sales    )).to be true
    expect( core.setSpaceType(workshop )).to be true

    argh                = {}
    argh[:io_path     ] = File.join(__dir__, jpath)
    argh[:schema_path ] = File.join(__dir__, "../tbd.schema.json")
    argh[:uprate_walls] = true
    argh[:wall_option ] = "ALL wall constructions"
    argh[:wall_ut     ] = 0.210 # NECB CZ7 2017 (RSi 4.76 / R41)

    TBD.process(model, argh)
    expect(argh).to_not have_key(:roof_uo)

    # OpenStudio prior to v3.5.X had a 3m maximum layer thickness, reflecting a
    # previous v8.8 EnergyPlus constraint. TBD caught such cases when uprating
    # (as per NECB requirements). From v3.5.0+, OpenStudio dropped the maximum
    # layer thickness limit, harmonizing with EnergyPlus:
    #
    #   https://github.com/NREL/OpenStudio/pull/4622
    if OpenStudio.openStudioVersion.split(".").join.to_i < 350
      expect(TBD.error?).to be true
      expect(TBD.logs).to_not be_empty
      expect(TBD.logs.size).to eq(2)

      expect(TBD.logs.first[:message]).to include("Invalid")
      expect(TBD.logs.first[:message]).to include("Can't uprate ")
      expect(TBD.logs.last[:message ]).to include("Unable to uprate")

      expect(argh).to_not have_key(:wall_uo)
    else
      expect(TBD.status).to be_zero
      expect(argh).to have_key(:wall_uo)
      expect(argh[:wall_uo]).to be_within(0.0001).of(0.0089) # RSi 112 (R638)
    end
  end

  it "can test Hash inputs" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    input  = {}
    schema = "https://github.com/rd2/tbd/blob/master/tbd.schema.json"
    file   = File.join(__dir__, "files/osms/in/seb.osm")
    path   = OpenStudio::Path.new(file)
    model  = translator.loadModel(path)
    expect(model).to_not be_empty
    model  = model.get

    # Rather than reading a TBD JSON input file (e.g. "json/tbd_seb_n2.json"),
    # read in the same content as a Hash. Better for scripted batch runs.
    psis     = []
    khis     = []
    surfaces = []

    psi                 = {}
    psi[:id           ] = "good"
    psi[:parapet      ] = 0.500
    psi[:party        ] = 0.900
    psis << psi

    psi                 = {}
    psi[:id           ] = "compliant"
    psi[:rimjoist     ] = 0.300
    psi[:parapet      ] = 0.325
    psi[:fenestration ] = 0.350
    psi[:corner       ] = 0.450
    psi[:balcony      ] = 0.500
    psi[:party        ] = 0.500
    psi[:grade        ] = 0.450
    psis << psi

    khi                 = {}
    khi[:id           ] = "column"
    khi[:point        ] = 0.500
    khis << khi

    khi                 = {}
    khi[:id           ] = "support"
    khi[:point        ] = 0.500
    khis << khi

    surface             = {}
    surface[:id       ] = "Entryway  Wall 5"
    surface[:khis     ] = []
    surface[:khis     ] << { id: "column",  count: 3 }
    surface[:khis     ] << { id: "support", count: 4 }
    surfaces << surface

    input[:schema     ] = schema
    input[:description] = "testing JSON surface KHI entries"
    input[:psis       ] = psis
    input[:khis       ] = khis
    input[:surfaces   ] = surfaces

    # Export to file. Both files should be the same.
    out     = JSON.pretty_generate(input)
    pth     = File.join(__dir__, "../json/tbd_seb_n2.out.json")
    File.open(pth, "w") { |pth| pth.puts out }
    initial = File.join(__dir__, "../json/tbd_seb_n2.json")
    expect(FileUtils).to be_identical(initial, pth)

    argh                = {}
    argh[:option      ] = "(non thermal bridging)"
    argh[:io_path     ] = input
    argh[:schema_path ] = File.join(__dir__, "../tbd.schema.json")

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(56)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(106)

    surfaces.values.each do |surface|
      next unless surface.key?(:ratio)

      expect(surface[:heatloss]).to be_within(TOL).of(3.5)
    end
  end

  it "can check for attics vs plenums" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    # Outdoor-facing surfaces of UNCONDITIONED spaces are never derated by TBD.
    # Yet determining whether an OpenStudio space should be considered
    # UNCONDITIONED (e.g. an attic), rather than INDIRECTLYCONDITIONED
    # (e.g. a plenum) can be tricky depending on the (incomplete) state of
    # development of an OpenStudio model. In determining the conditioning
    # status of each OpenStudio space, TBD relies on OSut methods:
    #   - 'setpoints(space)': applicable space heating/cooling setpoints
    #   - 'heatingTemperatureSetpoints?': ANY space holding heating setpoints?
    #   - 'coolingTemperatureSetpoints?': ANY space holding cooling setpoints?
    #
    # Users can consult the online OSut API documentation to know more.

    # Small office test case (UNCONDITIONED attic).
    file  = File.join(__dir__, "files/osms/in/smalloffice.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get
    attic = model.getSpaceByName("Attic")
    expect(attic).to_not be_empty
    attic = attic.get

    model.getSpaces.each do |space|
      next if space == attic

      zone = space.thermalZone
      expect(zone).to_not be_empty
      zone = zone.get
      heat = TBD.maxHeatScheduledSetpoint(zone)
      cool = TBD.minCoolScheduledSetpoint(zone)

      expect(heat[:spt]).to be_within(TOL).of(21.11)
      expect(cool[:spt]).to be_within(TOL).of(23.89)
      expect(heat[:dual]).to be true
      expect(cool[:dual]).to be true

      expect(space.partofTotalFloorArea).to be true
      expect(TBD.plenum?(space)).to be false
      expect(TBD.unconditioned?(space)).to be false
      expect(TBD.setpoints(space)[:heating]).to be_within(TOL).of(21.11)
      expect(TBD.setpoints(space)[:cooling]).to be_within(TOL).of(23.89)
    end

    zone = attic.thermalZone
    expect(zone).to_not be_empty
    zone = zone.get
    heat = TBD.maxHeatScheduledSetpoint(zone)
    cool = TBD.minCoolScheduledSetpoint(zone)

    expect(heat[:spt ]).to be_nil
    expect(cool[:spt ]).to be_nil
    expect(heat[:dual]).to be false
    expect(cool[:dual]).to be false

    expect(TBD.plenum?(attic)).to be false
    expect(TBD.unconditioned?(attic)).to be true
    expect(TBD.setpoints(attic)[:heating]).to be_nil
    expect(TBD.setpoints(attic)[:cooling]).to be_nil
    expect(attic.partofTotalFloorArea).to be false
    expect(TBD.status).to be_zero

    argh = { option: "code (Quebec)" }

    json     = TBD.process(model, argh)
    expect(TBD.status).to be_zero
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(43)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(105)

    surfaces.each do |id, surface|
      next unless id.include?("_roof_")

      expect(id).to include("Attic")
      expect(surface).to_not have_key(:ratio)
      expect(surface).to have_key(:conditioned)
      expect(surface).to have_key(:deratable)
      expect(surface[:conditioned]).to be false
      expect(surface[:deratable]).to be false
    end

    # Now tag attic as an INDIRECTLYCONDITIONED space (linked to "Core_ZN").
    file  = File.join(__dir__, "files/osms/in/smalloffice.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get
    attic = model.getSpaceByName("Attic")
    expect(attic).to_not be_empty
    attic = attic.get

    key = "indirectlyconditioned"
    val = "Core_ZN"
    expect(attic.additionalProperties.setFeature(key, val)).to be true
    expect(TBD.plenum?(attic)).to be false
    expect(TBD.unconditioned?(attic)).to be false
    expect(TBD.setpoints(attic)[:heating]).to be_within(TOL).of(21.11)
    expect(TBD.setpoints(attic)[:cooling]).to be_within(TOL).of(23.89)
    expect(TBD.status).to be_zero

    argh = { option: "code (Quebec)" }

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(43)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(110)

    surfaces.each do |id, surface|
      next unless id.include?("_roof_")

      expect(id).to include("Attic")
      expect(surface).to have_key(:ratio)
      expect(surface).to have_key(:conditioned)
      expect(surface).to have_key(:deratable)
      expect(surface[:conditioned]).to be true
      expect(surface[:deratable]).to be true
    end

    expect(attic.additionalProperties.resetFeature(key)).to be true

    # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
    # The following variations of the 'FullServiceRestaurant' (v3.2.1) are
    # snapshots of incremental development of the same model. For each step,
    # the tests illustrate how TBD ends up considering the unoccupied space
    # (below roof) and how simple variable changes allow users to switch from
    # UNCONDITIONED to INDIRECTLYCONDITIONED (or vice versa).
    unless OpenStudio.openStudioVersion.split(".").join.to_i < 321
      TBD.clean!

      # Unaltered template OpenStudio model:
      #   - constructions: NO
      #   - setpoints    : NO
      #   - HVAC         : NO
      file  = File.join(__dir__, "files/osms/in/resto1.osm")
      path  = OpenStudio::Path.new(file)
      model = translator.loadModel(path)
      expect(model).to_not be_empty
      model = model.get
      attic = model.getSpaceByName("Attic")
      expect(attic).to_not be_empty
      attic = attic.get

      expect(model.getConstructions).to be_empty
      heated = TBD.heatingTemperatureSetpoints?(model)
      cooled = TBD.coolingTemperatureSetpoints?(model)
      expect(heated).to be false
      expect(cooled).to be false

      argh  = { option: "code (Quebec)" }

      json     = TBD.process(model, argh)
      expect(json).to be_a(Hash)
      expect(json).to have_key(:io)
      expect(json).to have_key(:surfaces)
      io       = json[:io      ]
      surfaces = json[:surfaces]
      expect(TBD.error?).to be true
      expect(TBD.logs).to_not be_empty
      expect(surfaces).to be_a(Hash)
      expect(surfaces.size).to eq(18)
      expect(io).to be_a(Hash)
      expect(io).to_not have_key(:edges)

      TBD.logs.each do |log|
        expect(log[:message]).to include("missing").or include("layer?")
      end

      # As the model doesn't hold any constructions, TBD skips over any
      # derating steps. Yet despite the OpenStudio model not holding ANY valid
      # heating or cooling setpoints, ALL spaces are considered CONDITIONED.
      surfaces.values.each do |surface|
        expect(surface).to be_a(Hash)
        expect(surface).to have_key(:space)
        expect(surface).to have_key(:stype) # spacetype
        expect(surface).to have_key(:conditioned)
        expect(surface).to have_key(:deratable)
        expect(surface).to_not have_key(:construction)
        expect(surface[:conditioned]).to be true # even attic
        expect(surface[:deratable  ]).to be false # no constructions!
      end

      # OSut correctly report spaces here as UNCONDITIONED. Tagging ALL spaces
      # instead as CONDITIONED in such (rare) cases is unique to TBD.
      id = "attic-floor-dinning"
      expect(surfaces).to have_key(id)

      attic = surfaces[id][:space]
      heat  = TBD.setpoints(attic)[:heating]
      cool  = TBD.setpoints(attic)[:cooling]
      expect(TBD.unconditioned?(attic)).to be true
      expect(heat).to be_nil
      expect(cool).to be_nil
      expect(attic.partofTotalFloorArea).to be false
      expect(TBD.plenum?(attic)).to be false


      # - ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- - #
      # A more developed 'FullServiceRestaurant' (midway BTAP generation):
      #   - constructions: YES
      #   - setpoints    : YES
      #   - HVAC         : NO
      TBD.clean!

      file  = File.join(__dir__, "files/osms/in/resto2.osm")
      path  = OpenStudio::Path.new(file)
      model = translator.loadModel(path)
      expect(model).to_not be_empty
      model = model.get

      # BTAP-set (interior) ceiling constructions (i.e. attic/plenum floors)
      # are characteristic of occupied floors (e.g. carpet over 4" concrete
      # slab). Clone/assign insulated roof construction to plenum/attic floors.
      set = model.getBuilding.defaultConstructionSet
      expect(set).to_not be_empty
      set = set.get

      interiors = set.defaultInteriorSurfaceConstructions
      exteriors = set.defaultExteriorSurfaceConstructions
      expect(interiors).to_not be_empty
      expect(exteriors).to_not be_empty
      interiors = interiors.get
      exteriors = exteriors.get
      roofs     = exteriors.roofCeilingConstruction
      expect(roofs).to_not be_empty
      roofs     = roofs.get
      insulated = roofs.clone(model).to_LayeredConstruction
      expect(insulated).to_not be_empty
      insulated = insulated.get
      insulated.setName("Insulated Attic Floors")
      expect(interiors.setRoofCeilingConstruction(insulated)).to be true

      # Validate re-assignment via individual attic floor surfaces.
      construction = nil
      ceilings     = []

      model.getSurfaces.each do |s|
        next unless s.surfaceType == "RoofCeiling"
        next unless s.outsideBoundaryCondition == "Surface"

        ceilings << s.nameString
        c = s.construction
        expect(c).to_not be_empty
        c = c.get.to_LayeredConstruction
        expect(c).to_not be_empty
        c = c.get
        expect(TBD.rsi(c, s.filmResistance)).to be_within(TOL).of(6.38)

        construction = c if construction.nil?
        expect(c).to eq(construction)
      end

      expect(construction            ).to eq(insulated)
      expect(construction.getNetArea ).to be_within(TOL).of(511.15)
      expect(ceilings.size           ).to eq(2)
      expect(construction.layers.size).to eq(2)
      expect(construction.nameString ).to eq("Insulated Attic Floors")
      expect(model.getConstructions).to_not be_empty
      heated = TBD.heatingTemperatureSetpoints?(model)
      cooled = TBD.coolingTemperatureSetpoints?(model)
      expect(heated).to be true
      expect(cooled).to be true

      attic = model.getSpaceByName("attic")
      expect(attic).to_not be_empty
      attic = attic.get

      expect(attic.partofTotalFloorArea).to be false
      heat = TBD.setpoints(attic)[:heating]
      cool = TBD.setpoints(attic)[:cooling]
      expect(heat).to be_nil
      expect(cool).to be_nil

      expect(TBD.plenum?(attic)).to be false
      expect(attic.partofTotalFloorArea).to be false
      expect(attic.thermalZone).to_not be_empty
      zone = attic.thermalZone.get
      expect(zone.isPlenum).to be false

      tstat = zone.thermostat
      expect(tstat).to_not be_empty
      tstat = tstat.get
      expect(tstat.to_ThermostatSetpointDualSetpoint).to_not be_empty
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get
      expect(tstat.getHeatingSchedule).to be_empty
      expect(tstat.getCoolingSchedule).to be_empty

      heat = TBD.maxHeatScheduledSetpoint(zone)
      cool = TBD.minCoolScheduledSetpoint(zone)
      expect(heat).to_not be_nil
      expect(cool).to_not be_nil
      expect(heat).to be_a(Hash)
      expect(cool).to be_a(Hash)
      expect(heat).to have_key(:spt)
      expect(cool).to have_key(:spt)
      expect(heat).to have_key(:dual)
      expect(cool).to have_key(:dual)
      expect(heat[:spt]).to be_nil
      expect(cool[:spt]).to be_nil
      expect(heat[:dual]).to be false
      expect(cool[:dual]).to be false

      # The unoccupied space does not reference valid heating and/or cooling
      # temperature setpoint objects, and is therefore considered
      # UNCONDITIONED. Save for next iteration.
      file = File.join(__dir__, "files/osms/out/resto2a.osm")
      model.save(file, true)

      argh                = {}
      argh[:option      ] = "efficient (BETBG)"
      argh[:uprate_roofs] = true
      argh[:roof_option ] = "ALL roof constructions"
      argh[:roof_ut     ] = 0.138 # NECB CZ7 2017 (RSi 7.25 / R41)

      json     = TBD.process(model, argh)
      expect(json).to be_a(Hash)
      expect(json).to have_key(:io)
      expect(json).to have_key(:surfaces)
      io       = json[:io      ]
      surfaces = json[:surfaces]
      expect(TBD.status).to be_zero
      expect(TBD.logs).to be_empty
      expect(surfaces).to be_a(Hash)
      expect(surfaces.size).to eq(18)
      expect(io).to be_a(Hash)
      expect(io).to have_key(:edges)
      expect(io[:edges].size).to eq(31)

      expect(argh).to_not have_key(:wall_uo)
      expect(argh).to have_key(:roof_uo)
      expect(argh[:roof_uo]).to be_within(TOL).of(0.119)

      # Validate ceiling surfaces (both insulated & uninsulated).
      ua = 0.0
      a  = 0.0

      surfaces.each do |nom, surface|
        expect(surface).to be_a(Hash)

        expect(surface).to have_key(:conditioned)
        expect(surface).to have_key(:deratable)
        expect(surface).to have_key(:construction)
        expect(surface).to have_key(:ground)
        expect(surface).to have_key(:type)
        next     if surface[:ground]
        next unless surface[:type  ] == :ceiling

        # Sloped attic roof surfaces ignored by TBD.
        id = surface[:construction].nameString
        expect(nom).to include("-roof"    ) unless surface[:deratable]
        expect(id ).to include("BTAP-Ext-") unless surface[:deratable]
        expect(surface[:conditioned]   ).to be false unless surface[:deratable]
        next unless surface[:deratable]
        next unless surface.key?(:heatloss)

        # Leaves only insulated attic ceilings.
        expect(id).to eq("Insulated Attic Floors") # original construction
        s = model.getSurfaceByName(nom)
        expect(s).to_not be_empty
        s = s.get
        c = s.construction
        expect(c).to_not be_empty
        c = c.get.to_LayeredConstruction
        expect(c).to_not be_empty
        c = c.get

        expect(c.nameString).to include("c tbd") # TBD-derated
        a  += surface[:net]
        ua += 1 / TBD.rsi(c, s.filmResistance) * surface[:net]
      end

      expect(ua / a).to be_within(TOL).of(argh[:roof_ut])


      # - ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- - #
      # Altered model from previous iteration, yet no uprating this round.
      #   - constructions: YES
      #   - setpoints    : YES
      #   - HVAC         : NO
      TBD.clean!

      file   = File.join(__dir__, "files/osms/out/resto2a.osm")
      path   = OpenStudio::Path.new(file)
      model  = translator.loadModel(path)
      expect(model).to_not be_empty
      model  = model.get
      heated = TBD.heatingTemperatureSetpoints?(model)
      cooled = TBD.coolingTemperatureSetpoints?(model)
      expect(model.getConstructions).to_not be_empty
      expect(heated).to be true
      expect(cooled).to be true

      # In this iteration, ensure the unoccupied space is considered as an
      # INDIRECTLYCONDITIONED plenum (instead of an UNCONDITIONED attic), by
      # temporarily adding a heating dual setpoint schedule object to its zone
      # thermostat (yet without valid scheduled temperatures).
      attic = model.getSpaceByName("attic")
      expect(attic).to_not be_empty
      attic = attic.get
      expect(attic.partofTotalFloorArea).to be false
      expect(attic.thermalZone).to_not be_empty
      zone  = attic.thermalZone.get
      expect(zone.isPlenum).to be false
      tstat = zone.thermostat
      expect(tstat).to_not be_empty
      tstat = tstat.get

      expect(tstat.to_ThermostatSetpointDualSetpoint).to_not be_empty
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get

      # Before the addition.
      expect(tstat.getHeatingSchedule).to be_empty
      expect(tstat.getCoolingSchedule).to be_empty

      heat  = TBD.maxHeatScheduledSetpoint(zone)
      cool  = TBD.minCoolScheduledSetpoint(zone)
      stpts = TBD.setpoints(attic)

      expect(heat).to_not be_nil
      expect(cool).to_not be_nil
      expect(heat).to be_a(Hash)
      expect(cool).to be_a(Hash)
      expect(heat).to have_key(:spt)
      expect(cool).to have_key(:spt)
      expect(heat).to have_key(:dual)
      expect(cool).to have_key(:dual)
      expect(heat[:spt]).to be_nil
      expect(cool[:spt]).to be_nil
      expect(heat[:dual]).to be false
      expect(cool[:dual]).to be false

      expect(stpts[:heating]).to be_nil
      expect(stpts[:cooling]).to be_nil
      expect(TBD.unconditioned?(attic)).to be true
      expect(TBD.plenum?(attic)).to be false

      # Add a dual setpoint temperature schedule.
      identifier = "TEMPORARY attic setpoint schedule"

      sched = OpenStudio::Model::ScheduleCompact.new(model)
      sched.setName(identifier)
      expect(sched.constantValue).to be_empty
      expect(tstat.setHeatingSetpointTemperatureSchedule(sched)).to be true

      # After the addition.
      expect(tstat.getHeatingSchedule).to_not be_empty
      expect(tstat.getCoolingSchedule).to be_empty
      heat  = TBD.maxHeatScheduledSetpoint(zone)
      stpts = TBD.setpoints(attic)

      expect(heat).to_not be_nil
      expect(heat).to be_a(Hash)
      expect(heat).to have_key(:spt)
      expect(heat).to have_key(:dual)
      expect(heat[:spt ]).to be_nil
      expect(heat[:dual]).to be true

      expect(stpts[:heating]).to be_within(TOL).of(21.0)
      expect(stpts[:cooling]).to be_within(TOL).of(24.0)

      expect(TBD.unconditioned?(attic)).to be false
      expect(TBD.plenum?(attic)).to be true # works ...

      argh = { option: "code (Quebec)" }

      json     = TBD.process(model, argh)
      expect(json ).to be_a(Hash)
      expect(json).to have_key(:io)
      expect(json).to have_key(:surfaces)
      io       = json[:io      ]
      surfaces = json[:surfaces]
      expect(TBD.error?).to be true
      expect(TBD.logs.size).to eq(18)
      expect(surfaces).to be_a(Hash)
      expect(surfaces.size).to eq(18)
      expect(io).to be_a(Hash)
      expect(io).to have_key(:edges)
      expect(io[:edges].size).to eq(35)

      # The incomplete (temporary) schedule triggers a non-FATAL TBD error.
      TBD.logs.each do |log|
        expect(log[:message]).to include("Empty '")
        expect(log[:message]).to include("::scheduleCompactMinMax)")
      end

      surfaces.each do |nom, surface|
        expect(surface).to be_a(Hash)

        expect(surface).to have_key(:conditioned)
        expect(surface).to have_key(:deratable)
        expect(surface).to have_key(:construction)
        expect(surface).to have_key(:ground)
        expect(surface).to have_key(:type)
        next unless surface[:type] == :ceiling

        # Sloped attic roof surfaces no longer ignored by TBD.
        id = surface[:construction].nameString
        expect(nom).to include("-roof"    )     if surface[:deratable]
        expect(nom).to include("_Ceiling" ) unless surface[:deratable]
        expect(id ).to include("BTAP-Ext-")     if surface[:deratable]

        expect(surface[:conditioned]).to be true
        next unless surface[:deratable]
        next unless surface.key?(:heatloss)

        # Leaves only insulated attic ceilings.
        expect(id).to eq("BTAP-Ext-Roof-Metal:U-0.162") # original construction
        s = model.getSurfaceByName(nom)
        expect(s).to_not be_empty
        s = s.get
        c = s.construction
        expect(c).to_not be_empty
        c = c.get.to_LayeredConstruction
        expect(c).to_not be_empty
        c = c.get
        expect(c.nameString).to include("c tbd") # TBD-derated
      end

      # Once done, ensure temporary schedule is dissociated from the thermostat
      # and deleted from the model.
      tstat.resetHeatingSetpointTemperatureSchedule
      expect(tstat.getHeatingSchedule).to be_empty

      sched2 = model.getScheduleByName(identifier)
      expect(sched2).to_not be_empty
      sched2.get.remove
      sched2 = model.getScheduleByName(identifier)
      expect(sched2).to be_empty

      heat  = TBD.maxHeatScheduledSetpoint(zone)
      stpts = TBD.setpoints(attic)

      expect(heat).to be_a(Hash)
      expect(heat).to have_key(:spt )
      expect(heat).to have_key(:dual)
      expect(heat[:spt ]).to be_nil
      expect(heat[:dual]).to be false

      expect(stpts[:heating]).to be_nil
      expect(stpts[:cooling]).to be_nil
      expect(TBD.plenum?(attic)).to be false # as before ...


      # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
      TBD.clean!

      # Same, altered model from previous iteration (yet to uprate):
      #   - constructions: YES
      #   - setpoints    : YES
      #   - HVAC         : NO
      file  = File.join(__dir__, "files/osms/out/resto2a.osm")
      path  = OpenStudio::Path.new(file)
      model = translator.loadModel(path)
      expect(model).to_not be_empty
      model = model.get
      expect(model.getConstructions).to_not be_empty

      heated = TBD.heatingTemperatureSetpoints?(model)
      cooled = TBD.coolingTemperatureSetpoints?(model)
      expect(heated).to be true
      expect(cooled).to be true

      # Get geometry data for testing (4x exterior roofs, same construction).
      id           = "BTAP-Ext-Roof-Metal:U-0.162"
      construction = nil
      roofs        = []

      model.getSurfaces.each do |s|
        next unless s.surfaceType == "RoofCeiling"
        next unless s.outsideBoundaryCondition == "Outdoors"

        roofs << s.nameString
        c = s.construction
        expect(c).to_not be_empty
        c = c.get.to_LayeredConstruction
        expect(c).to_not be_empty
        c = c.get

        construction = c if construction.nil?
        expect(c).to eq(construction)
      end

      expect(construction.getNetArea ).to be_within(TOL).of(569.51)
      expect(roofs.size              ).to eq( 4)
      expect(construction.nameString ).to eq(id)
      expect(construction.layers.size).to eq( 2)

      insulation = construction.layers[1].to_MasslessOpaqueMaterial
      expect(insulation).to_not be_empty
      insulation = insulation.get
      original_r = insulation.thermalResistance
      expect(original_r).to be_within(TOL).of(6.17)

      # Attic spacetype as plenum, an alternative to the inactive thermostat.
      attic  = model.getSpaceByName("attic")
      expect(attic).to_not be_empty
      attic  = attic.get
      sptype = attic.spaceType
      expect(sptype).to_not be_empty
      sptype = sptype.get
      sptype.setName("Attic as Plenum")

      stpts = TBD.setpoints(attic)
      expect(stpts[:heating]).to be_within(TOL).of(21.0)
      expect(TBD.unconditioned?(attic)).to be false
      expect(TBD.plenum?(attic)).to be true # works ...

      argh                = {}
      argh[:option      ] = "efficient (BETBG)"
      argh[:uprate_walls] = true
      argh[:uprate_roofs] = true
      argh[:wall_option ] = "ALL wall constructions"
      argh[:roof_option ] = "ALL roof constructions"
      argh[:wall_ut     ] = 0.210 # NECB CZ7 2017 (RSi 4.76 / R27)
      argh[:roof_ut     ] = 0.138 # NECB CZ7 2017 (RSi 7.25 / R41)

      json     = TBD.process(model, argh)
      expect(json).to be_a(Hash)
      expect(json).to have_key(:io)
      expect(json).to have_key(:surfaces)
      io       = json[:io      ]
      surfaces = json[:surfaces]
      expect(TBD.status).to be_zero

      expect(argh).to have_key(:wall_uo)
      expect(argh).to have_key(:roof_uo)
      expect(argh[:roof_uo]).to be_within(TOL).of(0.120) # RSi  8.3 ( R47)
      expect(argh[:wall_uo]).to be_within(TOL).of(0.012) # RSi 83.3 (R473)

      # Validate ceiling surfaces (both insulated & uninsulated).
      ua   = 0.0
      a    = 0
      area = 0

      surfaces.each do |nom, surface|
        expect(surface).to be_a(Hash)
        expect(surface).to have_key(:conditioned)
        expect(surface).to have_key(:deratable)
        expect(surface).to have_key(:construction)
        expect(surface).to have_key(:ground)
        expect(surface).to have_key(:type)
        next     if surface[:ground]
        next unless surface[:type  ] == :ceiling

        # Sloped plenum roof surfaces no longer ignored by TBD.
        id = surface[:construction].nameString
        expect(nom).to include("-roof"    ) if surface[:deratable]
        expect(id ).to include("BTAP-Ext-") if surface[:deratable]

        expect(surface[:conditioned]).to be true     if surface[:deratable]
        expect(nom).to include("_Ceiling") unless surface[:deratable]
        expect(surface[:conditioned]).to be true unless surface[:deratable]

        next unless surface[:deratable]
        next unless surface.key?(:heatloss)

        # Leaves only insulated plenum roof surfaces.
        expect(id).to eq("BTAP-Ext-Roof-Metal:U-0.162") # original construction
        s = model.getSurfaceByName(nom)
        expect(s).to_not be_empty
        s = s.get
        c = s.construction
        expect(c).to_not be_empty
        c = c.get.to_LayeredConstruction
        expect(c).to_not be_empty
        c = c.get
        expect(c.nameString).to include("c tbd") # TBD-derated

        a  += surface[:net]
        ua += 1 / TBD.rsi(c, s.filmResistance) * surface[:net]
      end

      expect(ua / a).to be_within(TOL).of(argh[:roof_ut])

      roofs.each do |roof|
        expect(surfaces).to have_key(roof)
        expect(surfaces[roof]).to have_key(:deratable)
        expect(surfaces[roof]).to have_key(:edges)
        expect(surfaces[roof][:deratable]).to be true

        surfaces[roof][:edges].values.each do |edge|
          expect(edge).to have_key(:psi)
          expect(edge).to have_key(:length)
          expect(edge).to have_key(:ratio)
          expect(edge).to have_key(:type)
          next if edge[:type] == :transition

          expect(edge[:ratio]).to be_within(TOL).of(0.579)
          expect(edge[:psi  ]).to be_within(TOL).of(0.200 * edge[:ratio])
        end

        loss = 22.61 * 0.200 * 0.579
        expect(surfaces[roof]).to have_key(:heatloss)
        expect(surfaces[roof]).to have_key(:net)
        expect(surfaces[roof][:heatloss]).to be_within(TOL).of(loss)
        area += surfaces[roof][:net]
      end

      expect(area).to be_within(TOL).of(569.50)
    end
  end

  it "can factor in negative PSI values (JSON input)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    argh               = {}
    argh[:option     ] = "compliant" # superseded by :building PSI set on file
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_warehouse4.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a Hash
    expect(surfaces.size).to eq(23)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(300)

    ids = { a: "Office Front Wall",
            b: "Office Left Wall",
            c: "Fine Storage Roof",
            d: "Fine Storage Office Front Wall",
            e: "Fine Storage Office Left Wall",
            f: "Fine Storage Front Wall",
            g: "Fine Storage Left Wall",
            h: "Fine Storage Right Wall",
            i: "Bulk Storage Roof",
            j: "Bulk Storage Rear Wall",
            k: "Bulk Storage Left Wall",
            l: "Bulk Storage Right Wall" }.freeze

    surfaces.each do |id, surface|
      expect(ids).to have_value(id)         if surface.key?(:edges)
      expect(ids).to_not have_value(id) unless surface.key?(:edges)
    end

    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      next unless surface.key?(:ratio)

      expect(ids).to have_value(id)
      expect(surface).to have_key(:heatloss)

      # Ratios are typically negative e.g., a steel corner column decreasing
      # linked surface RSi values. In some cases, a corner PSI can be positive
      # (and thus increasing linked surface RSi values). This happens when
      # estimating PSI values for convex corners while relying on an interior
      # dimensioning convention e.g., BETBG Detail 7.6.2, ISO 14683.
      expect(surface[:ratio]).to be_within(TOL).of(0.18) if id == ids[:a]
      expect(surface[:ratio]).to be_within(TOL).of(0.55) if id == ids[:b]
      expect(surface[:ratio]).to be_within(TOL).of(0.15) if id == ids[:d]
      expect(surface[:ratio]).to be_within(TOL).of(0.43) if id == ids[:e]
      expect(surface[:ratio]).to be_within(TOL).of(0.20) if id == ids[:f]
      expect(surface[:ratio]).to be_within(TOL).of(0.13) if id == ids[:h]
      expect(surface[:ratio]).to be_within(TOL).of(0.12) if id == ids[:j]
      expect(surface[:ratio]).to be_within(TOL).of(0.04) if id == ids[:k]
      expect(surface[:ratio]).to be_within(TOL).of(0.04) if id == ids[:l]

      # In such cases, negative heatloss means heat gained.
      expect(surface[:heatloss]).to be_within(TOL).of(-0.10) if id == ids[:a]
      expect(surface[:heatloss]).to be_within(TOL).of(-0.10) if id == ids[:b]
      expect(surface[:heatloss]).to be_within(TOL).of(-0.10) if id == ids[:d]
      expect(surface[:heatloss]).to be_within(TOL).of(-0.10) if id == ids[:e]
      expect(surface[:heatloss]).to be_within(TOL).of(-0.20) if id == ids[:f]
      expect(surface[:heatloss]).to be_within(TOL).of(-0.20) if id == ids[:h]
      expect(surface[:heatloss]).to be_within(TOL).of(-0.40) if id == ids[:j]
      expect(surface[:heatloss]).to be_within(TOL).of(-0.20) if id == ids[:k]
      expect(surface[:heatloss]).to be_within(TOL).of(-0.20) if id == ids[:l]
    end
  end

  it "can process thermal bridging and derating: LoScrigno" do
    # expect(TBD.level     ).to eq(INF)
    expect(TBD.reset(DBG)).to eq(DBG)
    expect(TBD.level     ).to eq(DBG)
    expect(TBD.clean!    ).to eq(DBG)
    # The following populates OpenStudio and Topolys models of "Lo Scrigno"
    # (or Jewel Box), by Renzo Piano (Lingotto Factory, Turin); a cantilevered,
    # single space art gallery (space #1) above a supply plenum with slanted
    # undersides (space #2), and resting on four main pillars.

    # The first ~800 lines generate the OpenStudio model from scratch, relying
    # the OpenStudio SDK and SketchUp-fed 3D surface vertices. It would be
    # easier to simply read in the saved .osm file (1x-time generation) of the
    # model. The generation code is maintained as is for debugging purposes
    # (e.g. SketchUp-reported vertices are +/- accurate). The remaining 1/3
    # of this first RSpec reproduces TBD's 'process' method. It is repeated
    # step-by-step here for detailed testing purposes.
    model    = OpenStudio::Model::Model.new
    building = model.getBuilding

    os_s = OpenStudio::Model::ShadingSurfaceGroup.new(model)
    # For the purposes of the RSpec, vertical access (elevator and stairs,
    # normally fully glazed) are modelled as (opaque) extensions of either
    # space. Surfaces are prefixed as follows:
    #   - "g_" : art gallery
    #   - "p_" : underfloor plenum (supplying gallery)
    #   - "s_" : stairwell (leading to/through plenum & gallery)
    #   - "e_" : (side) elevator leading to gallery
    os_g = OpenStudio::Model::Space.new(model) # gallery & elevator
    os_p = OpenStudio::Model::Space.new(model) # plenum & stairwell
    os_g.setName("scrigno_gallery")
    os_p.setName( "scrigno_plenum")

    # For the purposes of the spec, all opaque envelope assemblies are built up
    # from a single, 3-layered construction. All subsurfaces are Simple Glazing
    # constructions.
    construction = OpenStudio::Model::Construction.new(model)
    fenestration = OpenStudio::Model::Construction.new(model)
    elevator     = OpenStudio::Model::Construction.new(model)
    shadez       = OpenStudio::Model::Construction.new(model)
    glazing      = OpenStudio::Model::SimpleGlazing.new(model)
    exterior     = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
    xps8x25mm    = OpenStudio::Model::MasslessOpaqueMaterial.new(model)
    insulation   = OpenStudio::Model::StandardOpaqueMaterial.new(model)
    interior     = OpenStudio::Model::StandardOpaqueMaterial.new(model)

    construction.setName("scrigno_construction")
    fenestration.setName("scrigno_fen")
    elevator.setName("elevator")
    shadez.setName("scrigno_shading")
    glazing.setName("scrigno_glazing")
    exterior.setName("scrigno_exterior")
    xps8x25mm.setName("xps8x25mm")
    insulation.setName("scrigno_insulation")
    interior.setName("scrigno_interior")

    # Material properties.
    expect(exterior.setRoughness("Rough"        )).to be true
    expect(insulation.setRoughness("MediumRough")).to be true
    expect(interior.setRoughness("MediumRough"  )).to be true
    expect(xps8x25mm.setRoughness("Rough"       )).to be true

    expect(glazing.setUFactor(                 2.0000)).to be true
    expect(glazing.setSolarHeatGainCoefficient(0.5000)).to be true
    expect(glazing.setVisibleTransmittance(    0.7000)).to be true

    expect(exterior.setThermalResistance(      0.3626)).to be true
    expect(exterior.setThermalAbsorptance(     0.9000)).to be true
    expect(exterior.setSolarAbsorptance(       0.7000)).to be true
    expect(exterior.setVisibleAbsorptance(     0.7000)).to be true

    expect(insulation.setThickness(            0.1184)).to be true
    expect(insulation.setConductivity(         0.0450)).to be true
    expect(insulation.setDensity(            265.0000)).to be true
    expect(insulation.setSpecificHeat(       836.8000)).to be true
    expect(insulation.setThermalAbsorptance(   0.9000)).to be true
    expect(insulation.setSolarAbsorptance(     0.7000)).to be true
    expect(insulation.setVisibleAbsorptance(   0.7000)).to be true

    expect(interior.setThickness(              0.0126)).to be true
    expect(interior.setConductivity(           0.1600)).to be true
    expect(interior.setDensity(              784.9000)).to be true
    expect(interior.setSpecificHeat(         830.0000)).to be true
    expect(interior.setThermalAbsorptance(     0.9000)).to be true
    expect(interior.setSolarAbsorptance(       0.9000)).to be true
    expect(interior.setVisibleAbsorptance(     0.9000)).to be true

    expect(xps8x25mm.setThermalResistance( 8 * 0.8800)).to be true
    expect(xps8x25mm.setThermalAbsorptance(    0.9000)).to be true
    expect(xps8x25mm.setSolarAbsorptance(      0.7000)).to be true
    expect(xps8x25mm.setVisibleAbsorptance(    0.7000)).to be true

    # Layered constructions.
    layers = OpenStudio::Model::MaterialVector.new
    layers << glazing
    expect(fenestration.setLayers(layers)).to be true

    layers = OpenStudio::Model::MaterialVector.new
    layers << exterior
    layers << insulation
    layers << interior
    expect(construction.setLayers(layers)).to be true

    layers  = OpenStudio::Model::MaterialVector.new
    layers << exterior
    layers << xps8x25mm
    layers << interior
    expect(elevator.setLayers(layers)).to be true

    layers  = OpenStudio::Model::MaterialVector.new
    layers << exterior
    expect(shadez.setLayers(layers)).to be true

    defaults = OpenStudio::Model::DefaultSurfaceConstructions.new(model)
    subs     = OpenStudio::Model::DefaultSubSurfaceConstructions.new(model)
    set      = OpenStudio::Model::DefaultConstructionSet.new(model)

    expect(defaults.setWallConstruction(          construction)).to be true
    expect(defaults.setRoofCeilingConstruction(   construction)).to be true
    expect(defaults.setFloorConstruction(         construction)).to be true
    expect(subs.setFixedWindowConstruction(       fenestration)).to be true
    expect(subs.setOperableWindowConstruction(    fenestration)).to be true
    expect(subs.setDoorConstruction(              fenestration)).to be true
    expect(subs.setGlassDoorConstruction(         fenestration)).to be true
    expect(subs.setOverheadDoorConstruction(      fenestration)).to be true
    expect(subs.setSkylightConstruction(          fenestration)).to be true
    expect(set.setAdiabaticSurfaceConstruction(   construction)).to be true
    expect(set.setInteriorPartitionConstruction(  construction)).to be true
    expect(set.setDefaultExteriorSurfaceConstructions(defaults)).to be true
    expect(set.setDefaultInteriorSurfaceConstructions(defaults)).to be true
    expect(set.setDefaultInteriorSubSurfaceConstructions( subs)).to be true
    expect(set.setDefaultExteriorSubSurfaceConstructions( subs)).to be true
    expect(set.setSpaceShadingConstruction(             shadez)).to be true
    expect(set.setBuildingShadingConstruction(          shadez)).to be true
    expect(set.setSiteShadingConstruction(              shadez)).to be true
    expect(building.setDefaultConstructionSet(             set)).to be true

    # Set building shading surfaces:
    # (4x above gallery roof + 2x North/South balconies)
    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 12.4, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new( 12.4, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 45.0, 50.0)

    os_r1_shade = OpenStudio::Model::ShadingSurface.new(os_v, model)
    os_r1_shade.setName("r1_shade")
    expect(os_r1_shade.setShadingSurfaceGroup(os_s)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 22.7, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 37.5, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 37.5, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 45.0, 50.0)

    os_r2_shade = OpenStudio::Model::ShadingSurface.new(os_v, model)
    os_r2_shade.setName("r2_shade")
    expect(os_r2_shade.setShadingSurfaceGroup(os_s)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 22.7, 32.5, 50.0)
    os_v << OpenStudio::Point3d.new( 22.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 32.5, 50.0)

    os_r3_shade = OpenStudio::Model::ShadingSurface.new(os_v, model)
    os_r3_shade.setName("r3_shade")
    expect(os_r3_shade.setShadingSurfaceGroup(os_s)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 48.7, 45.0, 50.0)
    os_v << OpenStudio::Point3d.new( 48.7, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 59.0, 25.0, 50.0)
    os_v << OpenStudio::Point3d.new( 59.0, 45.0, 50.0)

    os_r4_shade = OpenStudio::Model::ShadingSurface.new(os_v, model)
    os_r4_shade.setName("r4_shade")
    expect(os_r4_shade.setShadingSurfaceGroup(os_s)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 41.7, 44.0)
    os_v << OpenStudio::Point3d.new( 45.7, 41.7, 44.0)
    os_v << OpenStudio::Point3d.new( 45.7, 40.2, 44.0)

    os_N_balcony = OpenStudio::Model::ShadingSurface.new(os_v, model)
    os_N_balcony.setName("N_balcony") # 1.70m as thermal bridge
    expect(os_N_balcony.setShadingSurfaceGroup(os_s)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.1, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 28.1, 28.3, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 28.3, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 44.0)

    os_S_balcony = OpenStudio::Model::ShadingSurface.new(os_v, model)
    os_S_balcony.setName("S_balcony") # 19.3m as thermal bridge
    expect(os_S_balcony.setShadingSurfaceGroup(os_s)).to be true

    # 1st space: gallery (g) with elevator (e) surfaces
    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5)
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5)

    os_g_W_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_g_W_wall.setName("g_W_wall")
    expect(os_g_W_wall.setSpace(os_g)).to be true
    expect(os_g_W_wall.surfaceType.downcase).to eq("wall")
    expect(os_g_W_wall.isConstructionDefaulted).to be true

    c = set.getDefaultConstruction(os_g_W_wall).get.to_LayeredConstruction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be true
    expect(c.nameString).to eq("scrigno_construction")

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5)
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5)

    os_g_N_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_g_N_wall.setName("g_N_wall")
    expect(os_g_N_wall.setSpace(os_g)).to be true
    expect(os_g_N_wall.uFactor).to_not be_empty
    expect(os_g_N_wall.uFactor.get).to be_within(TOL).of(0.31)

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 46.0)
    os_v << OpenStudio::Point3d.new( 47.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 46.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 46.4, 40.2, 46.0)

    os_g_N_door = OpenStudio::Model::SubSurface.new(os_v, model)
    os_g_N_door.setName("g_N_door")
    expect(os_g_N_door.setSubSurfaceType("GlassDoor")).to be true
    expect(os_g_N_door.setSurface(os_g_N_wall)).to be true
    expect(os_g_N_door.uFactor).to_not be_empty
    expect(os_g_N_door.uFactor.get).to be_within(TOL).of(2.00)

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5)

    os_g_E_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_g_E_wall.setName("g_E_wall")
    expect(os_g_E_wall.setSpace(os_g)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5)
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 49.5)

    os_g_S1_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_g_S1_wall.setName("g_S1_wall")
    expect(os_g_S1_wall.setSpace(os_g)).to be true
    expect(os_g_S1_wall.uFactor).to_not be_empty
    expect(os_g_S1_wall.uFactor.get).to be_within(TOL).of(0.31)

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 49.5)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 46.7)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 46.7)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 49.5)

    os_g_S2_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_g_S2_wall.setName("g_S2_wall")
    expect(os_g_S2_wall.setSpace(os_g)).to be true
    expect(os_g_S2_wall.uFactor).to_not be_empty
    expect(os_g_S2_wall.uFactor.get).to be_within(TOL).of(0.31)

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 49.5)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5)

    os_g_S3_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_g_S3_wall.setName("g_S3_wall")
    expect(os_g_S3_wall.setSpace(os_g)).to be true
    expect(os_g_S3_wall.uFactor).to_not be_empty
    expect(os_g_S3_wall.uFactor.get).to be_within(TOL).of(0.31)

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 46.4, 29.8, 46.0)
    os_v << OpenStudio::Point3d.new( 46.4, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 47.4, 29.8, 46.0)

    os_g_S3_door = OpenStudio::Model::SubSurface.new(os_v, model)
    os_g_S3_door.setName("g_S3_door")
    expect(os_g_S3_door.setSubSurfaceType("GlassDoor")).to be true
    expect(os_g_S3_door.setSurface(os_g_S3_wall)).to be true
    expect(os_g_S3_door.uFactor).to_not be_empty
    expect(os_g_S3_door.uFactor.get).to be_within(TOL).of(2.00)

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 49.5)
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 49.5)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 49.5)
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 49.5)

    os_g_top = OpenStudio::Model::Surface.new(os_v, model)
    os_g_top.setName("g_top")
    expect(os_g_top.setSpace(os_g)).to be true
    expect(os_g_top.uFactor).to_not be_empty
    expect(os_g_top.uFactor.get).to be_within(TOL).of(0.31)
    expect(os_g_top.surfaceType.downcase).to eq("roofceiling")
    expect(os_g_top.isConstructionDefaulted).to be true

    c = set.getDefaultConstruction(os_g_top).get.to_LayeredConstruction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be true
    expect(c.nameString).to eq("scrigno_construction")

    # Leaving a 1" strip of rooftop (0.915 m2) so roof m2 > skylight m2.
    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2        , 49.5)
    os_v << OpenStudio::Point3d.new( 17.4, 29.8 + 0.025, 49.5)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8 + 0.025, 49.5)
    os_v << OpenStudio::Point3d.new( 54.0, 40.2        , 49.5)

    os_g_sky = OpenStudio::Model::SubSurface.new(os_v, model)
    os_g_sky.setName("g_sky")
    expect(os_g_sky.setSurface(os_g_top)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 46.7)
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 46.7)
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 46.7)

    os_e_top = OpenStudio::Model::Surface.new(os_v, model)
    os_e_top.setName("e_top")
    expect(os_e_top.setSpace(os_g)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 40.8)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 40.8)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8)
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8)

    os_e_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_e_floor.setName("e_floor")
    expect(os_e_floor.setSpace(os_g)).to be true
    expect(os_e_floor.setOutsideBoundaryCondition("Outdoors")).to be true
    expect(os_e_floor.surfaceType.downcase).to eq("floor")
    expect(os_e_floor.isConstructionDefaulted).to be true

    c = set.getDefaultConstruction(os_e_floor).get.to_LayeredConstruction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be true
    expect(c.nameString).to eq("scrigno_construction")
    expect(os_e_floor.setConstruction(elevator)).to be true
    expect(os_e_floor.isConstructionDefaulted).to be false

    c = os_e_floor.construction.get.to_LayeredConstruction.get
    expect(c.numLayers).to eq(3)
    expect(c.isOpaque).to be true
    expect(c.nameString).to eq("elevator")

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 46.7)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 40.8)
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 40.8)
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 46.7)

    os_e_W_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_e_W_wall.setName("e_W_wall")
    expect(os_e_W_wall.setSpace(os_g)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 46.7)
    os_v << OpenStudio::Point3d.new( 24.0, 28.3, 40.8)
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8)
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7)

    os_e_S_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_e_S_wall.setName("e_S_wall")
    expect(os_e_S_wall.setSpace(os_g)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 46.7)
    os_v << OpenStudio::Point3d.new( 28.0, 28.3, 40.8)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 46.7)

    os_e_E_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_e_E_wall.setName("e_E_wall")
    expect(os_e_E_wall.setSpace(os_g)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4060)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 40.8000)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 40.8000)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0075)

    os_e_N_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_e_N_wall.setName("e_N_wall")
    expect(os_e_N_wall.setSpace(os_g)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0000)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4060)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0075)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0000)

    os_e_p_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_e_p_wall.setName("e_p_wall")
    expect(os_e_p_wall.setSpace(os_g)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0)

    os_g_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_g_floor.setName("g_floor")
    expect(os_g_floor.setSpace(os_g) ).to be true

    # 2nd space: plenum (p) with stairwell (s) surfaces
    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0)

    os_p_top = OpenStudio::Model::Surface.new(os_v, model)
    os_p_top.setName("p_top")
    expect(os_p_top.setSpace(os_p)).to be true
    expect(os_p_top.setAdjacentSurface(os_g_floor)).to be true
    expect(os_g_floor.setAdjacentSurface(os_p_top)).to be true
    expect(os_p_top.setOutsideBoundaryCondition(  "Surface")).to be true
    expect(os_g_floor.setOutsideBoundaryCondition("Surface")).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0000)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0075)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4060)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0000)

    os_p_e_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_p_e_wall.setName("p_e_wall")
    expect(os_p_e_wall.setSpace(os_p)).to be true
    expect(os_e_p_wall.setAdjacentSurface(os_p_e_wall)).to be true
    expect(os_p_e_wall.setAdjacentSurface(os_e_p_wall)).to be true
    expect(os_p_e_wall.setOutsideBoundaryCondition("Surface")).to be true
    expect(os_e_p_wall.setOutsideBoundaryCondition("Surface")).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0000)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0075)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 44.0000)

    os_p_S1_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_p_S1_wall.setName("p_S1_wall")
    expect(os_p_S1_wall.setSpace(os_p)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 44.0000)
    os_v << OpenStudio::Point3d.new( 28.0, 29.8, 42.4060)
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.0000)
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0000)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0000)

    os_p_S2_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_p_S2_wall.setName("p_S2_wall")
    expect(os_p_S2_wall.setSpace(os_p)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0)
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.0)
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0)

    os_p_N_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_p_N_wall.setName("p_N_wall")
    expect(os_p_N_wall.setSpace(os_p)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.0)
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.0)
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0)
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0)

    os_p_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_p_floor.setName("p_floor")
    expect(os_p_floor.setSpace(os_p)).to be true
    expect(os_p_floor.setOutsideBoundaryCondition("Outdoors")).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 40.7, 29.8, 42.0)
    os_v << OpenStudio::Point3d.new( 40.7, 40.2, 42.0)
    os_v << OpenStudio::Point3d.new( 54.0, 40.2, 44.0)
    os_v << OpenStudio::Point3d.new( 54.0, 29.8, 44.0)

    os_p_E_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_p_E_floor.setName("p_E_floor")
    expect(os_p_E_floor.setSpace(os_p)).to be true
    expect(os_p_E_floor.setSurfaceType("Floor")).to be true # walls by default

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 17.4, 29.8, 44.0000)
    os_v << OpenStudio::Point3d.new( 17.4, 40.2, 44.0000)
    os_v << OpenStudio::Point3d.new( 24.0, 40.2, 43.0075)
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0075)

    os_p_W1_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_p_W1_floor.setName("p_W1_floor")
    expect(os_p_W1_floor.setSpace(os_p)).to be true
    expect(os_p_W1_floor.setSurfaceType("Floor")).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 29.8, 43.0075)
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.0075)
    os_v << OpenStudio::Point3d.new( 30.7, 33.1, 42.0000)
    os_v << OpenStudio::Point3d.new( 30.7, 29.8, 42.0000)

    os_p_W2_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_p_W2_floor.setName("p_W2_floor")
    expect(os_p_W2_floor.setSpace(os_p)).to be true
    expect(os_p_W2_floor.setSurfaceType("Floor")).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.0075)
    os_v << OpenStudio::Point3d.new( 24.0, 40.2, 43.0075)
    os_v << OpenStudio::Point3d.new( 30.7, 40.2, 42.0000)
    os_v << OpenStudio::Point3d.new( 30.7, 36.9, 42.0000)

    os_p_W3_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_p_W3_floor.setName("p_W3_floor")
    expect(os_p_W3_floor.setSpace(os_p)).to be true
    expect(os_p_W3_floor.setSurfaceType("Floor")).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.2556)
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.2556)
    os_v << OpenStudio::Point3d.new( 30.7, 36.9, 42.0000)
    os_v << OpenStudio::Point3d.new( 30.7, 33.1, 42.0000)

    os_p_W4_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_p_W4_floor.setName("p_W4_floor")
    expect(os_p_W4_floor.setSpace(os_p)).to be true
    expect(os_p_W4_floor.setSurfaceType("Floor")).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.0075)
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.8000)
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.8000)
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.0075)

    os_s_W_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_s_W_wall.setName("s_W_wall")
    expect(os_s_W_wall.setSpace(os_p)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.2556)
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.8000)
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.8000)
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 43.0075)

    os_s_N_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_s_N_wall.setName("s_N_wall")
    expect(os_s_N_wall.setSpace(os_p)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.2556)
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.8000)
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.8000)
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 42.2556)

    os_s_E_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_s_E_wall.setName("s_E_wall")
    expect(os_s_E_wall.setSpace(os_p)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 43.0075)
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.8000)
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.8000)
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 42.2556)

    os_s_S_wall = OpenStudio::Model::Surface.new(os_v, model)
    os_s_S_wall.setName("s_S_wall")
    expect(os_s_S_wall.setSpace(os_p)).to be true

    os_v  = OpenStudio::Point3dVector.new
    os_v << OpenStudio::Point3d.new( 24.0, 33.1, 40.8)
    os_v << OpenStudio::Point3d.new( 24.0, 36.9, 40.8)
    os_v << OpenStudio::Point3d.new( 29.0, 36.9, 40.8)
    os_v << OpenStudio::Point3d.new( 29.0, 33.1, 40.8)

    os_s_floor = OpenStudio::Model::Surface.new(os_v, model)
    os_s_floor.setName("s_floor")
    expect(os_s_floor.setSpace(os_p)).to be true
    expect(os_s_floor.setSurfaceType("Floor")).to be true
    expect(os_s_floor.setOutsideBoundaryCondition("Outdoors")).to be true

    # Assign thermal zones.
    model.getSpaces.each do |space|
      zone = OpenStudio::Model::ThermalZone.new(model)
      zone.setName("#{space.nameString}|zone")
      space.setThermalZone(zone)
    end

    pth = File.join(__dir__, "files/osms/out/loscrigno.osm")
    model.save(pth, true)


    t_model  = Topolys::Model.new
    argh     = { setpoints: false, parapet: true }
    surfaces = {}

    model.getSurfaces.sort_by { |s| s.nameString }.each do |s|
      surface = TBD.properties(s, argh)
      expect(surface).to_not be_nil
      expect(surface).to be_a(Hash)
      expect(surface).to have_key(:space)

      surfaces[s.nameString] = surface
    end

    expect(surfaces.size).to eq(31)

    surfaces.each do |id, surface|
      expect(surface[:conditioned]).to be true
      expect(surface).to have_key(:heating)
      expect(surface).to have_key(:cooling)
    end

    surfaces.each do |id, surface|
      expect(surface).to_not have_key(:deratable)
      surface[:deratable] = false
      next     if surface[:ground     ]
      next unless surface[:conditioned]

      unless surface[:boundary].downcase == "outdoors"
        next unless surfaces.key?(surface[:boundary])
        next     if surfaces[surface[:boundary]][:conditioned]
      end

      expect(surface).to have_key(:index)
      surface[:deratable] = true
    end

    [:windows, :doors, :skylights].each do |holes| # sort kids
      surfaces.values.each do |surface|
        next unless surface.key?(holes)

        surface[holes] = surface[holes].sort_by { |_, s| s[:minz] }.to_h
      end
    end

    expect(surfaces["g_top"    ]).to have_key(:type)
    expect(surfaces["g_S1_wall"]).to have_key(:type)
    expect(surfaces["g_S2_wall"]).to have_key(:type)
    expect(surfaces["g_S3_wall"]).to have_key(:type)
    expect(surfaces["g_N_wall" ]).to have_key(:type)

    expect(surfaces["g_top"    ]).to have_key(:skylights)
    expect(surfaces["g_top"    ]).to_not have_key(:windows)
    expect(surfaces["g_top"    ]).to_not have_key(:doors)

    expect(surfaces["g_S1_wall"]).to_not have_key(:skylights)
    expect(surfaces["g_S1_wall"]).to_not have_key(:windows)
    expect(surfaces["g_S1_wall"]).to_not have_key(:doors)

    expect(surfaces["g_S2_wall"]).to_not have_key(:skylights)
    expect(surfaces["g_S2_wall"]).to_not have_key(:windows)
    expect(surfaces["g_S2_wall"]).to_not have_key(:doors)

    expect(surfaces["g_S3_wall"]).to_not have_key(:skylights)
    expect(surfaces["g_S3_wall"]).to_not have_key(:windows)
    expect(surfaces["g_S3_wall"]).to have_key(:doors)

    expect(surfaces["g_N_wall"]).to_not have_key(:skylights)
    expect(surfaces["g_N_wall"]).to_not have_key(:windows)
    expect(surfaces["g_N_wall"]).to have_key(:doors)

    expect(surfaces["g_top"    ][:skylights].size).to eq(1)
    expect(surfaces["g_S3_wall"][:doors    ].size).to eq(1)
    expect(surfaces["g_N_wall" ][:doors    ].size).to eq(1)
    expect(surfaces["g_top"    ][:skylights]).to have_key("g_sky")
    expect(surfaces["g_S3_wall"][:doors    ]).to have_key("g_S3_door")
    expect(surfaces["g_N_wall" ][:doors    ]).to have_key("g_N_door")

    # Split "surfaces" hash into "floors", "ceilings" and "walls" hashes.
    floors   = surfaces.select  { |_, s|  s[:type] == :floor   }
    ceilings = surfaces.select  { |_, s|  s[:type] == :ceiling }
    walls    = surfaces.select  { |_, s|  s[:type] == :wall    }

    floors   = floors.sort_by   { |_, s| [s[:minz], s[:space]] }.to_h
    ceilings = ceilings.sort_by { |_, s| [s[:minz], s[:space]] }.to_h
    walls    = walls.sort_by    { |_, s| [s[:minz], s[:space]] }.to_h

    expect(floors.size  ).to eq( 9) # 7
    expect(ceilings.size).to eq( 3)
    expect(walls.size   ).to eq(19) # 17

    # Fetch OpenStudio shading surfaces & key attributes.
    shades = {}

    model.getShadingSurfaces.each do |s|
      expect(s.shadingSurfaceGroup).to_not be_empty
      id      = s.nameString
      group   = s.shadingSurfaceGroup.get
      shading = group.to_ShadingSurfaceGroup
      tr      = TBD.transforms(group)

      expect(tr).to be_a(Hash)
      expect(tr).to have_key(:t)
      expect(tr).to have_key(:r)
      t = tr[:t]
      r = tr[:r]
      expect(t).to_not be_nil
      expect(r).to_not be_nil

      expect(shading).to_not be_empty
      empty = shading.get.space.empty?
      r    += shading.get.space.get.directionofRelativeNorth unless empty
      n     = TBD.trueNormal(s, r)
      expect(n).to_not be_nil

      points = (t * s.vertices).map{ |v| Topolys::Point3D.new(v.x, v.y, v.z) }

      minz = (points.map{ |p| p.z }).min

      shades[id] = { group: group, points: points, minz: minz, n: n }
    end

    expect(shades.size).to eq(6)

    # Mutually populate TBD & Topolys surfaces. Keep track of created "holes".
    holes         = {}
    floor_holes   = TBD.dads(t_model, floors)
    ceiling_holes = TBD.dads(t_model, ceilings)
    wall_holes    = TBD.dads(t_model, walls)

    holes.merge!(floor_holes)
    holes.merge!(ceiling_holes)
    holes.merge!(wall_holes)

    expect(floor_holes       ).to be_empty
    expect(ceiling_holes.size).to eq(1)
    expect(wall_holes.size   ).to eq(2)
    expect(holes.size        ).to eq(3)

    floors.values.each do |props| # testing normals
      t_x = props[:face].outer.plane.normal.x
      t_y = props[:face].outer.plane.normal.y
      t_z = props[:face].outer.plane.normal.z

      expect(props[:n].x).to be_within(0.001).of(t_x)
      expect(props[:n].y).to be_within(0.001).of(t_y)
      expect(props[:n].z).to be_within(0.001).of(t_z)
    end

    # OpenStudio (opaque) surfaces VS number of Topolys (opaque) faces.
    expect(surfaces.size     ).to eq(31)
    expect(t_model.faces.size).to eq(31)

    TBD.dads(t_model, shades)
    expect(t_model.faces.size).to eq(37)

    # Loop through Topolys edges and populate TBD edge hash. Initially, there
    # should be a one-to-one correspondence between Topolys and TBD edge
    # objects. Use Topolys-generated identifiers as unique edge hash keys.
    edges = {}

    holes.each do |id, wire| # start with hole edges
      wire.edges.each do |e|
        i  = e.id
        l  = e.length
        ex = edges.key?(i)

        edges[i] = { length: l, v0: e.v0, v1: e.v1, surfaces: {} } unless ex

        next if edges[i][:surfaces].key?(wire.attributes[:id])

        edges[i][:surfaces][wire.attributes[:id]] = { wire: wire.id }
      end
    end

    expect(edges.size).to eq(12)

    # Next, floors, ceilings & walls; then shades.
    TBD.faces(floors, edges)

    expect(edges.size).to eq(51)

    TBD.faces(ceilings, edges)
    expect(edges.size).to eq(60)

    TBD.faces(walls, edges)
    expect(edges.size).to eq(78)

    TBD.faces(shades, edges)
    expect(        edges.size).to eq(100)
    expect(t_model.edges.size).to eq(100)

    # edges.values.each do |edge|
    #   puts "#{'%5.2f' % edge[:length]}m #{edge[:surfaces].keys.to_a}"
    # end
    # 10.38m ["g_sky", "g_top", "g_W_wall"]
    # 36.60m ["g_sky", "g_top"]
    # 10.38m ["g_sky", "g_top", "g_E_wall"]
    # 36.60m ["g_sky", "g_top", "g_N_wall"]
    #  2.00m ["g_N_door", "g_N_wall"]
    #  1.00m ["g_N_door", "g_floor", "p_top", "p_N_wall", "g_N_wall", "N_balcony"]
    #  2.00m ["g_N_door", "g_N_wall"]
    #  1.00m ["g_N_door", "g_N_wall"]
    #  2.00m ["g_S3_door", "g_S3_wall"]
    #  1.00m ["g_S3_door", "g_floor", "p_top", "p_S2_wall", "g_S3_wall", "S_balcony"]
    #  2.00m ["g_S3_door", "g_S3_wall"]
    #  1.00m ["g_S3_door", "g_S3_wall"]
    #  1.50m ["e_floor", "e_W_wall"]
    #  4.00m ["e_floor", "e_N_wall"]
    #  1.50m ["e_floor", "e_E_wall"]
    #  4.00m ["e_floor", "e_S_wall"]
    #  3.80m ["s_floor", "s_W_wall"]
    #  5.00m ["s_floor", "s_N_wall"]
    #  3.80m ["s_floor", "s_E_wall"]
    #  5.00m ["s_floor", "s_S_wall"]
    # 10.40m ["p_E_floor", "p_floor"]
    # 13.45m ["p_E_floor", "p_N_wall"]
    # 10.40m ["p_E_floor", "g_floor", "p_top", "g_E_wall"]
    # 13.45m ["p_E_floor", "p_S2_wall"]
    #  3.30m ["p_W2_floor", "p_W1_floor"]
    #  5.06m ["p_W2_floor", "s_S_wall"]
    #  1.72m ["p_W2_floor", "p_W4_floor"]
    #  3.30m ["p_W2_floor", "p_floor"]
    #  2.73m ["p_W2_floor", "p_S2_wall"]
    #  4.04m ["p_W2_floor", "e_N_wall", "e_p_wall", "p_e_wall"]
    #  3.80m ["p_floor", "p_W4_floor"]
    #  3.30m ["p_floor", "p_W3_floor"]
    # 10.00m ["p_floor", "p_N_wall"]
    # 10.00m ["p_floor", "p_S2_wall"]
    #  3.80m ["p_W4_floor", "s_E_wall"]
    #  1.72m ["p_W4_floor", "p_W3_floor"]
    #  3.30m ["p_W3_floor", "p_W1_floor"]
    #  6.78m ["p_W3_floor", "p_N_wall"]
    #  5.06m ["p_W3_floor", "s_N_wall"]
    # 10.40m ["p_W1_floor", "g_floor", "p_top", "g_W_wall"]
    #  6.67m ["p_W1_floor", "p_N_wall"]
    #  3.80m ["p_W1_floor", "s_W_wall"]
    #  6.67m ["p_W1_floor", "p_S1_wall"]
    # 28.30m ["g_floor", "p_top", "p_N_wall", "g_N_wall"]
    #  0.70m ["g_floor", "p_top", "p_N_wall", "g_N_wall", "N_balcony"]
    #  6.60m ["g_floor", "p_top", "p_N_wall", "g_N_wall"]
    #  6.60m ["g_floor", "p_top", "p_S2_wall", "g_S3_wall"]
    # 18.30m ["g_floor", "p_top", "p_S2_wall", "g_S3_wall", "S_balcony"]
    #  0.10m ["g_floor", "p_top", "p_S2_wall", "g_S3_wall"]
    #  4.00m ["g_floor", "p_top", "e_p_wall", "p_e_wall"]
    #  6.60m ["g_floor", "p_top", "p_S1_wall", "g_S1_wall"]
    #  1.50m ["e_top", "e_W_wall"]
    #  4.00m ["e_top", "e_S_wall"]
    #  1.50m ["e_top", "e_E_wall"]
    #  4.00m ["e_top", "g_S2_wall"]
    #  0.02m ["g_top", "g_W_wall"]
    #  6.60m ["g_top", "g_S1_wall"]
    #  4.00m ["g_top", "g_S2_wall"]
    # 26.00m ["g_top", "g_S3_wall"]
    #  0.02m ["g_top", "g_E_wall"]
    #  5.90m ["e_E_wall", "e_S_wall"]
    #  1.61m ["e_E_wall", "e_N_wall"]
    #  1.59m ["e_E_wall", "p_S2_wall", "e_p_wall", "p_e_wall"]
    #  2.70m ["e_E_wall", "g_S3_wall"]
    #  2.21m ["e_N_wall", "e_W_wall"]
    #  5.90m ["e_S_wall", "e_W_wall"]
    #  2.70m ["e_W_wall", "g_S1_wall"]
    #  0.99m ["e_W_wall", "e_p_wall", "p_e_wall", "p_S1_wall"]
    #  2.21m ["s_S_wall", "s_W_wall"]
    #  1.46m ["s_S_wall", "s_E_wall"]
    #  1.46m ["s_N_wall", "s_E_wall"]
    #  2.21m ["s_N_wall", "s_W_wall"]
    #  5.50m ["g_W_wall", "g_N_wall"]
    #  5.50m ["g_W_wall", "g_S1_wall"]
    #  2.80m ["g_S1_wall", "g_S2_wall"]
    #  5.50m ["g_N_wall", "g_E_wall"]
    #  5.50m ["g_E_wall", "g_S3_wall"]
    #  2.80m ["g_S3_wall", "g_S2_wall"]
    #  1.50m ["S_balcony"]
    # 19.30m ["S_balcony"]
    #  1.50m ["S_balcony"]
    #  1.50m ["N_balcony"]
    #  1.70m ["N_balcony"]
    #  1.50m ["N_balcony"]
    #  7.50m ["r3_shade", "r1_shade"]
    # 26.00m ["r3_shade"]
    #  7.50m ["r3_shade", "r4_shade"]
    # 26.00m ["r3_shade"]
    #  7.50m ["r2_shade", "r1_shade"]
    # 26.00m ["r2_shade"]
    #  7.50m ["r2_shade", "r4_shade"]
    # 26.00m ["r2_shade"]
    #  5.00m ["r4_shade"]
    # 10.30m ["r4_shade"]
    # 20.00m ["r4_shade"]
    # 10.30m ["r4_shade"]
    # 20.00m ["r1_shade"]
    # 10.30m ["r1_shade"]
    #  5.00m ["r1_shade"]
    # 10.30m ["r1_shade"]

    # The following surfaces should all share an edge.
    p_S2_wall_face = walls["p_S2_wall"][:face]
    e_p_wall_face  = walls["e_p_wall" ][:face]
    p_e_wall_face  = walls["p_e_wall" ][:face]
    e_E_wall_face  = walls["e_E_wall" ][:face]

    p_S2_wall_edge_ids = Set.new(p_S2_wall_face.outer.edges.map{ |oe| oe.id} )
    e_p_wall_edges_ids = Set.new( e_p_wall_face.outer.edges.map{ |oe| oe.id} )
    p_e_wall_edges_ids = Set.new( p_e_wall_face.outer.edges.map{ |oe| oe.id} )
    e_E_wall_edges_ids = Set.new( e_E_wall_face.outer.edges.map{ |oe| oe.id} )

    intersection = p_S2_wall_edge_ids &
                   e_p_wall_edges_ids &
                   p_e_wall_edges_ids
    expect(intersection.size).to eq(1)

    intersection = p_S2_wall_edge_ids &
                   e_p_wall_edges_ids &
                   p_e_wall_edges_ids &
                   e_E_wall_edges_ids
    expect(intersection.size).to eq(1)

    shared_edges = p_S2_wall_face.shared_outer_edges(e_p_wall_face)
    expect(shared_edges.size).to eq(1)
    expect(shared_edges.first.id).to eq(intersection.to_a.first)

    shared_edges = p_S2_wall_face.shared_outer_edges(p_e_wall_face)
    expect(shared_edges.size).to eq(1)
    expect(shared_edges.first.id).to eq(intersection.to_a.first)

    shared_edges = p_S2_wall_face.shared_outer_edges(e_E_wall_face)
    expect(shared_edges.size).to eq(1)
    expect(shared_edges.first.id).to eq(intersection.to_a.first)

    # g_floor and p_top should be connected with all edges shared
    g_floor_face  = floors["g_floor"][:face]
    p_top_face    = ceilings["p_top"][:face]
    g_floor_wire  = g_floor_face.outer
    g_floor_edges = g_floor_wire.edges
    p_top_wire    = p_top_face.outer
    p_top_edges   = p_top_wire.edges
    shared_edges  = p_top_face.shared_outer_edges(g_floor_face)

    expect(g_floor_edges.size).to be > 4
    expect(g_floor_edges.size).to eq(p_top_edges.size)
    expect( shared_edges.size).to eq(p_top_edges.size)

    g_floor_edges.each do |g_floor_edge|
      expect(p_top_edges.find { |e| e.id == g_floor_edge.id } ).to be_truthy
    end

    expect(floors.size  ).to eq( 9)
    expect(ceilings.size).to eq( 3)
    expect(walls.size   ).to eq(19)
    expect(shades.size  ).to eq( 6)

    zenith = Topolys::Vector3D.new(0, 0, 1).freeze
    north  = Topolys::Vector3D.new(0, 1, 0).freeze
    east   = Topolys::Vector3D.new(1, 0, 0).freeze

    edges.values.each do |edge|
      origin     = edge[:v0].point
      terminal   = edge[:v1].point
      dx         = (origin.x - terminal.x).abs
      dy         = (origin.y - terminal.y).abs
      dz         = (origin.z - terminal.z).abs
      horizontal = dz.abs < TOL
      vertical   = dx < TOL && dy < TOL
      edge_V     = terminal - origin
      expect(edge_V.magnitude > TOL).to be true
      edge_plane = Topolys::Plane3D.new(origin, edge_V)

      if vertical
        reference_V = north.dup
      elsif horizontal
        reference_V = zenith.dup
      else
        reference   = edge_plane.project(origin + zenith)
        reference_V = reference - origin
      end

      edge[:surfaces].each do |id, surface|
        t_model.wires.each do |wire|
          next unless surface[:wire] == wire.id

          normal     = surfaces[id][:n]         if surfaces.key?(id)
          normal     = holes[id].attributes[:n] if holes.key?(id)
          normal     = shades[id][:n]           if shades.key?(id)
          farthest   = Topolys::Point3D.new(origin.x, origin.y, origin.z)
          farthest_V = farthest - origin
          inverted   = false
          i_origin   = wire.points.index(origin)
          i_terminal = wire.points.index(terminal)
          i_last     = wire.points.size - 1

          if i_terminal == 0
            inverted = true unless i_origin == i_last
          elsif i_origin == i_last
            inverted = true unless i_terminal == 0
          else
            inverted = true unless i_terminal - i_origin == 1
          end

          wire.points.each do |point|
            next if point == origin
            next if point == terminal

            point_on_plane    = edge_plane.project(point)
            origin_point_V    = point_on_plane - origin
            point_V_magnitude = origin_point_V.magnitude
            next unless point_V_magnitude > TOL

            if inverted
              plane = Topolys::Plane3D.from_points(terminal, origin, point)
            else
              plane = Topolys::Plane3D.from_points(origin, terminal, point)
            end

            dnx = (normal.x - plane.normal.x).abs
            dny = (normal.y - plane.normal.y).abs
            dnz = (normal.z - plane.normal.z).abs
            next unless dnx < TOL && dny < TOL && dnz < TOL

            farther    = point_V_magnitude > farthest_V.magnitude
            farthest   = point          if farther
            farthest_V = origin_point_V if farther
          end

          angle = edge_V.angle(farthest_V)
          expect(angle).to be_within(TOL).of(Math::PI / 2)
          angle = reference_V.angle(farthest_V)

          adjust = false

          if vertical
            adjust = true if east.dot(farthest_V) < -TOL
          else
            dN  = north.dot(farthest_V)
            dN1 = north.dot(farthest_V).abs - 1

            if dN.abs < TOL || dN1.abs < TOL
              adjust = true if east.dot(farthest_V) < -TOL
            else
              adjust = true if dN < -TOL
            end
          end

          angle  = 2 * Math::PI - angle if adjust
          angle -= 2 * Math::PI         if (angle - 2 * Math::PI).abs < TOL
          surface[:angle ] = angle
          farthest_V.normalize!
          surface[:polar ] = farthest_V
          surface[:normal] = normal
        end # end of edge-linked, surface-to-wire loop
      end # end of edge-linked surface loop

      edge[:horizontal] = horizontal
      edge[:vertical  ] = vertical
      edge[:surfaces  ] = edge[:surfaces].sort_by{ |i, p| p[:angle] }.to_h
    end # end of edge loop

    expect(edges.size        ).to eq(100)
    expect(t_model.edges.size).to eq(100)

    argh[:option] = "poor (BETBG)"
    expect(argh.size).to eq(3)

    json = TBD.inputs(surfaces, edges, argh)
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty

    expect(argh.size).to eq(5)
    expect(argh).to have_key(:option)
    expect(argh).to have_key(:setpoints)
    expect(argh).to have_key(:parapet)
    expect(argh).to have_key(:io_path)
    expect(argh).to have_key(:schema_path)

    expect(argh[:option     ]).to eq("poor (BETBG)")
    expect(argh[:setpoints  ]).to be false
    expect(argh[:parapet    ]).to be true
    expect(argh[:io_path    ]).to be_nil
    expect(argh[:schema_path]).to be_nil

    expect(json).to be_a(Hash)
    expect(json).to have_key(:psi)
    expect(json).to have_key(:khi)
    expect(json).to have_key(:io)

    expect(json[:psi]).to be_a(TBD::PSI)
    expect(json[:khi]).to be_a(TBD::KHI)
    expect(json[:io ]).to_not be_empty
    expect(json[:io ]).to have_key(:building)
    expect(json[:io ][:building]).to have_key(:psi)

    psi    = json[:io][:building][:psi]
    shorts = json[:psi].shorthands(psi)
    expect(shorts[:has]).to_not be_empty
    expect(shorts[:val]).to_not be_empty

    edges.values.each do |edge|
      next unless edge.key?(:surfaces)

      deratables = []
      set        = {}

      edge[:surfaces].keys.each do |id|
        next unless surfaces.key?(id)

        deratables << id if surfaces[id][:deratable]
      end

      next if deratables.empty?

      edge[:surfaces].keys.each do |id|
        next unless surfaces.key?(id)
        next unless deratables.include?(id)

        # Evaluate current set content before processing a new linked surface.
        is               = {}
        is[:head        ] = set.keys.to_s.include?("head")
        is[:sill        ] = set.keys.to_s.include?("sill")
        is[:jamb        ] = set.keys.to_s.include?("jamb")
        is[:doorhead    ] = set.keys.to_s.include?("doorhead")
        is[:doorsill    ] = set.keys.to_s.include?("doorsill")
        is[:doorjamb    ] = set.keys.to_s.include?("doorjamb")
        is[:skylighthead] = set.keys.to_s.include?("skylighthead")
        is[:skylightsill] = set.keys.to_s.include?("skylightsill")
        is[:skylightjamb] = set.keys.to_s.include?("skylightjamb")
        is[:spandrel    ] = set.keys.to_s.include?("spandrel")
        is[:corner      ] = set.keys.to_s.include?("corner")
        is[:parapet     ] = set.keys.to_s.include?("parapet")
        is[:roof        ] = set.keys.to_s.include?("roof")
        is[:party       ] = set.keys.to_s.include?("party")
        is[:grade       ] = set.keys.to_s.include?("grade")
        is[:balcony     ] = set.keys.to_s.include?("balcony")
        is[:balconysill ] = set.keys.to_s.include?("balconysill")
        is[:rimjoist    ] = set.keys.to_s.include?("rimjoist")

        # Label edge as ...
        #         :head,         :sill,         :jamb (vertical fenestration)
        #     :doorhead,     :doorsill,     :doorjamb (opaque door)
        # :skylighthead, :skylightsill, :skylightjamb (all other cases)
        #
        # ... if linked to:
        #   1x subsurface (vertical or non-vertical)
        edge[:surfaces].keys.each do |i|
          break    if is[:head        ]
          break    if is[:sill        ]
          break    if is[:jamb        ]
          break    if is[:doorhead    ]
          break    if is[:doorsill    ]
          break    if is[:doorjamb    ]
          break    if is[:skylighthead]
          break    if is[:skylightsill]
          break    if is[:skylightjamb]
          next     if deratables.include?(i)
          next unless holes.key?(i)

          # In most cases, subsurface edges simply delineate the rough opening
          # of its base surface (here, a "gardian"). Door sills, corner windows,
          # as well as a subsurface header aligned with a plenum "floor"
          # (ceiling tiles), are common instances where a subsurface edge links
          # 2x (opaque) surfaces. Deratable surface "id" may not be the gardian
          # of subsurface "i" - the latter may be a neighbour. The single
          # "target" surface to derate is not the gardian in such cases.
          gardian = deratables.size == 1 ? id : ""
          target  = gardian

          # Retrieve base surface's subsurfaces.
          windows   = surfaces[id].key?(:windows)
          doors     = surfaces[id].key?(:doors)
          skylights = surfaces[id].key?(:skylights)

          windows   =   windows ? surfaces[id][:windows  ] : {}
          doors     =     doors ? surfaces[id][:doors    ] : {}
          skylights = skylights ? surfaces[id][:skylights] : {}

          # The gardian is "id" if subsurface "ids" holds "i".
          ids = windows.keys + doors.keys + skylights.keys

          if gardian.empty?
            other = deratables.first == id ? deratables.last : deratables.first

            gardian = ids.include?(i) ?    id : other
            target  = ids.include?(i) ? other : id

            windows   = surfaces[gardian].key?(:windows)
            doors     = surfaces[gardian].key?(:doors)
            skylights = surfaces[gardian].key?(:skylights)

            windows   =   windows ? surfaces[gardian][:windows  ] : {}
            doors     =     doors ? surfaces[gardian][:doors    ] : {}
            skylights = skylights ? surfaces[gardian][:skylights] : {}

            ids = windows.keys + doors.keys + skylights.keys
          end

          unless ids.include?(i)
            log(ERR, "Orphaned subsurface #{i} (mth)")
            next
          end

          window   =   windows.key?(i) ?   windows[i] : {}
          door     =     doors.key?(i) ?     doors[i] : {}
          skylight = skylights.key?(i) ? skylights[i] : {}

          sub = window   unless window.empty?
          sub = door     unless door.empty?
          sub = skylight unless skylight.empty?

          window = sub[:type] == :window
          door   = sub[:type] == :door
          glazed = door && sub.key?(:glazed) && sub[:glazed]

          s1      = edge[:surfaces][target]
          s2      = edge[:surfaces][i     ]
          concave = TBD.concave?(s1, s2)
          convex  = TBD.convex?(s1, s2)
          flat    = !concave && !convex

          # Subsurface edges are tagged as head, sill or jamb, regardless of
          # building PSI set subsurface-related tags. If the latter is simply
          # :fenestration, then its single PSI factor is systematically
          # assigned to e.g. a window's :head, :sill & :jamb edges.
          #
          # Additionally, concave or convex variants also inherit from the base
          # type if undefined in the PSI set.
          #
          # If a subsurface is not horizontal, TBD tags any horizontal edge as
          # either :head or :sill based on the polar angle of the subsurface
          # around the edge vs sky zenith. Otherwise, all other subsurface edges
          # are tagged as :jamb.
          if ((s2[:normal].dot(zenith)).abs - 1).abs < TOL # horizontal surface
            if glazed || window
              set[:jamb       ] = shorts[:val][:jamb       ] if flat
              set[:jambconcave] = shorts[:val][:jambconcave] if concave
              set[:jambconvex ] = shorts[:val][:jambconvex ] if convex
               is[:jamb       ] = true
            elsif door
              set[:doorjamb       ] = shorts[:val][:doorjamb       ] if flat
              set[:doorjambconcave] = shorts[:val][:doorjambconcave] if concave
              set[:doorjambconvex ] = shorts[:val][:doorjambconvex ] if convex
               is[:doorjamb       ] = true
            else
              set[:skylightjamb       ] = shorts[:val][:skylightjamb       ] if flat
              set[:skylightjambconcave] = shorts[:val][:skylightjambconcave] if concave
              set[:skylightjambconvex ] = shorts[:val][:skylightjambconvex ] if convex
               is[:skylightjamb       ] = true
            end
          else
            if glazed || window
              if edge[:horizontal]
                if s2[:polar].dot(zenith) < 0
                  set[:head       ] = shorts[:val][:head       ] if flat
                  set[:headconcave] = shorts[:val][:headconcave] if concave
                  set[:headconvex ] = shorts[:val][:headconvex ] if convex
                   is[:head       ] = true
                else
                  set[:sill       ] = shorts[:val][:sill       ] if flat
                  set[:sillconcave] = shorts[:val][:sillconcave] if concave
                  set[:sillconvex ] = shorts[:val][:sillconvex ] if convex
                   is[:sill       ] = true
                end
              else
                set[:jamb       ] = shorts[:val][:jamb       ] if flat
                set[:jambconcave] = shorts[:val][:jambconcave] if concave
                set[:jambconvex ] = shorts[:val][:jambconvex ] if convex
                 is[:jamb       ] = true
              end
            elsif door
              if edge[:horizontal]
                if s2[:polar].dot(zenith) < 0

                  set[:doorhead       ] = shorts[:val][:doorhead       ] if flat
                  set[:doorheadconcave] = shorts[:val][:doorheadconcave] if concave
                  set[:doorheadconvex ] = shorts[:val][:doorheadconvex ] if convex
                   is[:doorhead       ] = true
                else
                  set[:doorsill       ] = shorts[:val][:doorsill       ] if flat
                  set[:doorsillconcave] = shorts[:val][:doorsillconcave] if concave
                  set[:doorsillconvex ] = shorts[:val][:doorsillconvex ] if convex
                   is[:doorsill       ] = true
                end
              else
                set[:doorjamb       ] = shorts[:val][:doorjamb       ] if flat
                set[:doorjambconcave] = shorts[:val][:doorjambconcave] if concave
                set[:doorjambconvex ] = shorts[:val][:doorjambconvex ] if convex
                 is[:doorjamb       ] = true
              end
            else
              if edge[:horizontal]
                if s2[:polar].dot(zenith) < 0
                  set[:skylighthead       ] = shorts[:val][:skylighthead       ] if flat
                  set[:skylightheadconcave] = shorts[:val][:skylightheadconcave] if concave
                  set[:skylightheadconvex ] = shorts[:val][:skylightheadconvex ] if convex
                   is[:skylighthead       ] = true
                else
                  set[:skylightsill       ] = shorts[:val][:skylightsill       ] if flat
                  set[:skylightsillconcave] = shorts[:val][:skylightsillconcave] if concave
                  set[:skylightsillconvex ] = shorts[:val][:skylightsillconvex ] if convex
                   is[:skylightsill       ] = true
                end
              else
                set[:skylightjamb       ] = shorts[:val][:skylightjamb       ] if flat
                set[:skylightjambconcave] = shorts[:val][:skylightjambconcave] if concave
                set[:skylightjambconvex ] = shorts[:val][:skylightjambconvex ] if convex
                 is[:skylightjamb       ] = true
              end
            end
          end
        end

        # Label edge as :spandrel if linked to:
        #   1x deratable, non-spandrel wall
        #   1x deratable, spandrel wall
        edge[:surfaces].keys.each do |i|
          break     if is[:spandrel]
          break unless deratables.size == 2
          break unless walls.key?(id)
          break unless walls[id][:spandrel]
          next      if i == id
          next  unless deratables.include?(i)
          next  unless walls.key?(i)
          next      if walls[i][:spandrel]

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i ]
          concave = TBD.concave?(s1, s2)
          convex  = TBD.convex?(s1, s2)
          flat    = !concave && !convex

          set[:spandrel       ] = shorts[:val][:spandrel       ] if flat
          set[:spandrelconcave] = shorts[:val][:spandrelconcave] if concave
          set[:spandrelconvex ] = shorts[:val][:spandrelconvex ] if convex
           is[:spandrel       ] = true
        end

        # Label edge as :cornerconcave or :cornerconvex if linked to:
        #   2x deratable walls & f(relative polar wall vectors around edge)
        edge[:surfaces].keys.each do |i|
          break     if is[:corner]
          break unless deratables.size == 2
          break unless walls.key?(id)
          next      if i == id
          next  unless deratables.include?(i)
          next  unless walls.key?(i)

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i ]
          concave = TBD.concave?(s1, s2)
          convex  = TBD.convex?(s1, s2)

          set[:cornerconcave] = shorts[:val][:cornerconcave] if concave
          set[:cornerconvex ] = shorts[:val][:cornerconvex ] if convex
           is[:corner       ] = true
        end

        # Label edge as :parapet/:roof if linked to:
        #   1x deratable wall
        #   1x deratable ceiling
        edge[:surfaces].keys.each do |i|
          break     if is[:parapet]
          break     if is[:roof   ]
          break unless deratables.size == 2
          break unless ceilings.key?(id)
          next      if i == id
          next  unless deratables.include?(i)
          next  unless walls.key?(i)

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i ]
          concave = TBD.concave?(s1, s2)
          convex  = TBD.convex?(s1, s2)
          flat    = !concave && !convex

          if argh[:parapet]
            set[:parapet       ] = shorts[:val][:parapet       ] if flat
            set[:parapetconcave] = shorts[:val][:parapetconcave] if concave
            set[:parapetconvex ] = shorts[:val][:parapetconvex ] if convex
             is[:parapet       ] = true
          else
            set[:roof       ] = shorts[:val][:roof       ] if flat
            set[:roofconcave] = shorts[:val][:roofconcave] if concave
            set[:roofconvex ] = shorts[:val][:roofconvex ] if convex
             is[:roof       ] = true
          end
        end

        # Label edge as :party if linked to:
        #   1x OtherSideCoefficients surface
        #   1x (only) deratable surface
        edge[:surfaces].keys.each do |i|
          break     if is[:party]
          break unless deratables.size == 1
          next      if i == id
          next  unless surfaces.key?(i)
          next      if holes.key?(i)
          next      if shades.key?(i)

          facing = surfaces[i][:boundary].downcase
          next unless facing == "othersidecoefficients"

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i ]
          concave = concave?(s1, s2)
          convex  = convex?(s1, s2)
          flat    = !concave && !convex

          set[:party       ] = shorts[:val][:party       ] if flat
          set[:partyconcave] = shorts[:val][:partyconcave] if concave
          set[:partyconvex ] = shorts[:val][:partyconvex ] if convex
           is[:party       ] = true
        end

        # Label edge as :grade if linked to:
        #   1x surface (e.g. slab or wall) facing ground
        #   1x surface (i.e. wall) facing outdoors
        edge[:surfaces].keys.each do |i|
          break     if is[:grade]
          break unless deratables.size == 1
          next      if i == id
          next  unless surfaces.key?(i)
          next  unless surfaces[i].key?(:ground)
          next  unless surfaces[i][:ground]

          s1      = edge[:surfaces][id]
          s2      = edge[:surfaces][i]
          concave = TBD.concave?(s1, s2)
          convex  = TBD.convex?(s1, s2)
          flat    = !concave && !convex

          set[:grade       ] = shorts[:val][:grade       ] if flat
          set[:gradeconcave] = shorts[:val][:gradeconcave] if concave
          set[:gradeconvex ] = shorts[:val][:gradeconvex ] if convex
           is[:grade       ] = true
        end

        # Label edge as :rimjoist, :balcony or :balconysill if linked to:
        #   1x deratable surface
        #   1x CONDITIONED floor
        #   1x shade (optional)
        #   1x subsurface (optional)
        balcony     = false
        balconysill = false

        edge[:surfaces].keys.each do |i|
          break if balcony
          next  if i == id

          balcony = shades.key?(i)
        end

        edge[:surfaces].keys.each do |i|
          break unless balcony
          break     if balconysill
          next      if i == id

          balconysill = holes.key?(i)
        end

        edge[:surfaces].keys.each do |i|
          break     if is[:rimjoist] || is[:balcony] || is[:balconysill]
          break unless deratables.size == 2
          break     if floors.key?(id)
          next      if i == id
          next  unless floors.key?(i)
          next  unless floors[i].key?(:conditioned)
          next  unless floors[i][:conditioned]
          next      if floors[i][:ground]

          other = deratables.first unless deratables.first == id
          other = deratables.last  unless deratables.last  == id
          other = id                   if deratables.size  == 1

          s1      = edge[:surfaces][id   ]
          s2      = edge[:surfaces][other]
          concave = TBD.concave?(s1, s2)
          convex  = TBD.convex?(s1, s2)
          flat    = !concave && !convex

          if balconysill
            set[:balconysill       ] = shorts[:val][:balconysill       ] if flat
            set[:balconysillconcave] = shorts[:val][:balconysillconcave] if concave
            set[:balconysillconvex ] = shorts[:val][:balconysillconvex ] if convex
             is[:balconysill       ] = true
          elsif balcony
            set[:balcony        ] = shorts[:val][:balcony        ] if flat
            set[:balconyconcave ] = shorts[:val][:balconyconcave ] if concave
            set[:balconyconvex  ] = shorts[:val][:balconyconvex  ] if convex
             is[:balcony        ] = true
          else
            set[:rimjoist       ] = shorts[:val][:rimjoist       ] if flat
            set[:rimjoistconcave] = shorts[:val][:rimjoistconcave] if concave
            set[:rimjoistconvex ] = shorts[:val][:rimjoistconvex ] if convex
             is[:rimjoist       ] = true
          end
        end # edge's surfaces loop
      end

      edge[:psi] = set unless set.empty?
      edge[:set] = psi unless set.empty?
    end # edge loop

    # Tracking (mild) transitions.
    transitions = {}

    edges.each do |tag, edge|
      trnz      = []
      deratable = false
      next     if edge.key?(:psi)
      next unless edge.key?(:surfaces)

      edge[:surfaces].keys.each do |id|
        next unless surfaces.key?(id)
        next unless surfaces[id][:deratable]

        deratable = surfaces[id][:deratable]
        trnz << id
      end

      next unless deratable

      edge[:psi] = { transition: 0.000 }
      edge[:set] = json[:io][:building][:psi]

      transitions[tag] = trnz unless trnz.empty?
    end

    # Lo Scrigno: such transitions occur between plenum floor plates.
    expect(transitions).to_not be_empty
    expect(transitions.size).to eq(10)
    # transitions.values.each { |trr| puts "#{trr}\n" }
    # ["p_E_floor" , "p_floor"   ] *
    # ["p_W2_floor", "p_W1_floor"] +
    # ["p_W4_floor", "p_W2_floor"] $
    # ["p_floor"   , "p_W2_floor"] *
    # ["p_floor"   , "p_W4_floor"] *
    # ["p_floor"   , "p_W3_floor"] *
    # ["p_W3_floor", "p_W4_floor"] $
    # ["p_W3_floor", "p_W1_floor"] +
    # ["g_S2_wall" , "g_S1_wall" ] !
    # ["g_S3_wall" , "g_S2_wall" ] !
    w1_count = 0

    transitions.values.each do |trnz|
      expect(trnz.size).to eq(2)

      if trnz.include?("g_S2_wall")     # !
        expect(trnz).to include("g_S1_wall").or include("g_S3_wall")
      elsif trnz.include?("p_W1_floor") # +
        w1_count += 1
        expect(trnz).to include("p_W2_floor").or include("p_W3_floor")
      elsif trnz.include?("p_floor")    # *
        expect(trnz).to_not include("p_W1_floor")
      else                              # $
        expect(trnz).to include("p_W4_floor")
      end
    end

    expect(w1_count).to eq(2)

    # At this stage, edges may have been tagged multiple times (e.g. :sill as
    # well as :balconysill); TBD has yet to make final edge type determinations.
    n_derating_edges                 = 0
    n_edges_at_grade                 = 0
    n_edges_as_balconies             = 0
    n_edges_as_balconysills          = 0
    n_edges_as_parapets              = 0
    n_edges_as_rimjoists             = 0
    n_edges_as_concave_rimjoists     = 0
    n_edges_as_convex_rimjoists      = 0
    n_edges_as_fenestrations         = 0
    n_edges_as_heads                 = 0
    n_edges_as_sills                 = 0
    n_edges_as_jambs                 = 0
    n_edges_as_concave_jambs         = 0
    n_edges_as_convex_jambs          = 0
    n_edges_as_doorheads             = 0
    n_edges_as_doorsills             = 0
    n_edges_as_doorjambs             = 0
    n_edges_as_doorconcave_jambs     = 0
    n_edges_as_doorconvex_jambs      = 0
    n_edges_as_skylightheads         = 0
    n_edges_as_skylightsills         = 0
    n_edges_as_skylightjambs         = 0
    n_edges_as_skylightconcave_jambs = 0
    n_edges_as_skylightconvex_jambs  = 0
    n_edges_as_corners               = 0
    n_edges_as_concave_corners       = 0
    n_edges_as_convex_corners        = 0
    n_edges_as_transitions           = 0

    edges.values.each do |edge|
      next unless edge.key?(:psi)

      n_derating_edges                 += 1
      n_edges_at_grade                 += 1 if edge[:psi].key?(:grade)
      n_edges_at_grade                 += 1 if edge[:psi].key?(:gradeconcave)
      n_edges_at_grade                 += 1 if edge[:psi].key?(:gradeconvex)
      n_edges_as_balconies             += 1 if edge[:psi].key?(:balcony)
      n_edges_as_balconysills          += 1 if edge[:psi].key?(:balconysill)
      n_edges_as_parapets              += 1 if edge[:psi].key?(:parapetconcave)
      n_edges_as_parapets              += 1 if edge[:psi].key?(:parapetconvex)
      n_edges_as_rimjoists             += 1 if edge[:psi].key?(:rimjoist)
      n_edges_as_concave_rimjoists     += 1 if edge[:psi].key?(:rimjoistconcave)
      n_edges_as_convex_rimjoists      += 1 if edge[:psi].key?(:rimjoistconvex)
      n_edges_as_fenestrations         += 1 if edge[:psi].key?(:fenestration)
      n_edges_as_heads                 += 1 if edge[:psi].key?(:head)
      n_edges_as_sills                 += 1 if edge[:psi].key?(:sill)
      n_edges_as_jambs                 += 1 if edge[:psi].key?(:jamb)
      n_edges_as_concave_jambs         += 1 if edge[:psi].key?(:jambconcave)
      n_edges_as_convex_jambs          += 1 if edge[:psi].key?(:jambconvex)
      n_edges_as_doorheads             += 1 if edge[:psi].key?(:doorhead)
      n_edges_as_doorsills             += 1 if edge[:psi].key?(:doorsill)
      n_edges_as_doorjambs             += 1 if edge[:psi].key?(:doorjamb)
      n_edges_as_doorconcave_jambs     += 1 if edge[:psi].key?(:doorjambconcave)
      n_edges_as_doorconvex_jambs      += 1 if edge[:psi].key?(:doorjambconvex)
      n_edges_as_skylightheads         += 1 if edge[:psi].key?(:skylighthead)
      n_edges_as_skylightsills         += 1 if edge[:psi].key?(:skylightsill)
      n_edges_as_skylightjambs         += 1 if edge[:psi].key?(:skylightjamb)
      n_edges_as_skylightconcave_jambs += 1 if edge[:psi].key?(:skylightjambconcave)
      n_edges_as_skylightconvex_jambs  += 1 if edge[:psi].key?(:skylightjambconvex)
      n_edges_as_corners               += 1 if edge[:psi].key?(:corner)
      n_edges_as_concave_corners       += 1 if edge[:psi].key?(:cornerconcave)
      n_edges_as_convex_corners        += 1 if edge[:psi].key?(:cornerconvex)
      n_edges_as_transitions           += 1 if edge[:psi].key?(:transition)
    end

    expect(n_derating_edges                ).to eq(77)
    expect(n_edges_at_grade                ).to eq( 0)
    expect(n_edges_as_balconies            ).to eq( 2) # not balconysills
    expect(n_edges_as_balconysills         ).to eq( 2) # == sills
    expect(n_edges_as_parapets             ).to eq(12) # 5x around rooftop strip
    expect(n_edges_as_rimjoists            ).to eq( 5)
    expect(n_edges_as_concave_rimjoists    ).to eq( 5)
    expect(n_edges_as_convex_rimjoists     ).to eq(18)
    expect(n_edges_as_fenestrations        ).to eq( 0)
    expect(n_edges_as_heads                ).to eq( 2) # "vertical fenestration"
    expect(n_edges_as_sills                ).to eq( 2) # == balcony sills
    expect(n_edges_as_jambs                ).to eq( 4)
    expect(n_edges_as_concave_jambs        ).to eq( 0)
    expect(n_edges_as_convex_jambs         ).to eq( 0)
    expect(n_edges_as_doorheads            ).to eq( 0) # "vertical fenestration"
    expect(n_edges_as_doorsills            ).to eq( 0) # "vertical fenestration"
    expect(n_edges_as_doorjambs            ).to eq( 0) # "vertical fenestration"
    expect(n_edges_as_doorconcave_jambs    ).to eq( 0) # "vertical fenestration"
    expect(n_edges_as_doorconvex_jambs     ).to eq( 0) # "vertical fenestration"
    expect(n_edges_as_skylightheads        ).to eq( 0)
    expect(n_edges_as_skylightsills        ).to eq( 0)
    expect(n_edges_as_skylightjambs        ).to eq( 1) # along 1" rooftop strip
    expect(n_edges_as_skylightconcave_jambs).to eq( 0)
    expect(n_edges_as_skylightconvex_jambs ).to eq( 3) # 3x parapet edges
    expect(n_edges_as_corners              ).to eq( 0)
    expect(n_edges_as_concave_corners      ).to eq( 4)
    expect(n_edges_as_convex_corners       ).to eq(12)
    expect(n_edges_as_transitions          ).to eq(10)

    # Loop through each edge and assign heat loss to linked surfaces.
    edges.each do |identifier, edge|
      next unless  edge.key?(:psi)

      rsi        = 0
      max        = edge[:psi].values.max
      type       = edge[:psi].key(max)
      length     = edge[:length]
      bridge     = { psi: max, type: type, length: length }
      deratables = {}
      apertures  = {}

      if edge.key?(:sets) && edge[:sets].key?(type)
        edge[:set] = edge[:sets][type]
      end

      # Retrieve valid linked surfaces as deratables.
      edge[:surfaces].each do |id, s|
        next unless surfaces.key?(id)

        deratables[id] = s if surfaces[id][:deratable]
      end

      edge[:surfaces].each { |id, s| apertures[id] = s if holes.key?(id) }
      next if apertures.size > 1 # edge links 2x openings

      # Prune dad if edge links an opening, its dad and an uncle.
      if deratables.size > 1 && apertures.size > 0
        deratables.each do |id, deratable|
          [:windows, :doors, :skylights].each do |types|
            next unless surfaces[id].key?(types)

            surfaces[id][types].keys.each do |sub|
              deratables.delete(id) if apertures.key?(sub)
            end
          end
        end
      end

      next if deratables.empty?

      # Sum RSI of targeted insulating layer from each deratable surface.
      deratables.each do |id, deratable|
        expect(surfaces[id]).to have_key(:r)
        rsi += surfaces[id][:r]
      end

      # Assign heat loss from thermal bridges to surfaces, in proportion to
      # insulating layer thermal resistance
      deratables.each do |id, deratable|
        ratio = 0
        ratio = surfaces[id][:r] / rsi if rsi > 0.001
        loss  = bridge[:psi] * ratio
        b     = { psi: loss, type: bridge[:type], length: length, ratio: ratio }
        surfaces[id][:edges] = {} unless surfaces[id].key?(:edges)
        surfaces[id][:edges][identifier] = b
      end
    end

    # Assign thermal bridging heat loss [in W/K] to each deratable surface.
    n_surfaces_to_derate = 0

    surfaces.each do |id, surface|
      next unless surface.key?(:edges)

      n_surfaces_to_derate += 1
      surface[:heatloss]    = 0
      e = surface[:edges].values

      e.each { |edge| surface[:heatloss] += edge[:psi] * edge[:length] }
    end

    expect(n_surfaces_to_derate).to eq(27) # if "poor (BETBG)"

    ["e_p_wall", "g_floor", "p_top", "p_e_wall"].each do |id|
      expect(surfaces[id]).to_not have_key(:heatloss)
    end

    # If "poor (BETBG)".
    expect(surfaces["e_E_wall"  ][:heatloss]).to be_within(TOL).of( 6.02)
    expect(surfaces["e_N_wall"  ][:heatloss]).to be_within(TOL).of( 4.73)
    expect(surfaces["e_S_wall"  ][:heatloss]).to be_within(TOL).of( 7.70)
    expect(surfaces["e_W_wall"  ][:heatloss]).to be_within(TOL).of( 6.02)
    expect(surfaces["e_floor"   ][:heatloss]).to be_within(TOL).of( 8.01)
    expect(surfaces["e_top"     ][:heatloss]).to be_within(TOL).of( 4.40)
    expect(surfaces["g_E_wall"  ][:heatloss]).to be_within(TOL).of(18.19)
    expect(surfaces["g_N_wall"  ][:heatloss]).to be_within(TOL).of(54.25)
    expect(surfaces["g_S1_wall" ][:heatloss]).to be_within(TOL).of( 9.43)
    expect(surfaces["g_S2_wall" ][:heatloss]).to be_within(TOL).of( 3.20)
    expect(surfaces["g_S3_wall" ][:heatloss]).to be_within(TOL).of(28.88)
    expect(surfaces["g_W_wall"  ][:heatloss]).to be_within(TOL).of(18.19)
    expect(surfaces["g_top"     ][:heatloss]).to be_within(TOL).of(32.96)
    expect(surfaces["p_E_floor" ][:heatloss]).to be_within(TOL).of(18.65)
    expect(surfaces["p_N_wall"  ][:heatloss]).to be_within(TOL).of(37.25)
    expect(surfaces["p_S1_wall" ][:heatloss]).to be_within(TOL).of( 7.06)
    expect(surfaces["p_S2_wall" ][:heatloss]).to be_within(TOL).of(27.27)
    expect(surfaces["p_W1_floor"][:heatloss]).to be_within(TOL).of(13.77)
    expect(surfaces["p_W2_floor"][:heatloss]).to be_within(TOL).of( 5.92)
    expect(surfaces["p_W3_floor"][:heatloss]).to be_within(TOL).of( 5.92)
    expect(surfaces["p_W4_floor"][:heatloss]).to be_within(TOL).of( 1.90)
    expect(surfaces["p_floor"   ][:heatloss]).to be_within(TOL).of(10.00)
    expect(surfaces["s_E_wall"  ][:heatloss]).to be_within(TOL).of( 5.04)
    expect(surfaces["s_N_wall"  ][:heatloss]).to be_within(TOL).of( 6.58)
    expect(surfaces["s_S_wall"  ][:heatloss]).to be_within(TOL).of( 6.58)
    expect(surfaces["s_W_wall"  ][:heatloss]).to be_within(TOL).of( 5.68)
    expect(surfaces["s_floor"   ][:heatloss]).to be_within(TOL).of( 8.80)

    surfaces.each do |id, surface|
      next unless surface.key?(:construction)
      next unless surface.key?(:index)
      next unless surface.key?(:ltype)
      next unless surface.key?(:r)
      next unless surface.key?(:edges)
      next unless surface.key?(:heatloss)
      next unless surface[:heatloss].abs > TOL

      s = model.getSurfaceByName(id)
      next if s.empty?

      s = s.get

      index     = surface[:index       ]
      current_c = surface[:construction]
      c         = current_c.clone(model).to_LayeredConstruction.get
      m         = nil
      m         = TBD.derate(id, surface, c) if index

      if m
        c.setLayer(index, m)
        c.setName("#{id} c tbd")
        s.setConstruction(c)

        if s.outsideBoundaryCondition.downcase == "surface"
          unless s.adjacentSurface.empty?
            adjacent = s.adjacentSurface.get
            nom      = adjacent.nameString
            default  = adjacent.isConstructionDefaulted == false

            if default && surfaces.key?(nom)
              current_cc = surfaces[nom][:construction]
              cc         = current_cc.clone(model).to_LayeredConstruction.get
              cc.setLayer(surfaces[nom][:index], m)
              cc.setName("#{nom} c tbd")
              adjacent.setConstruction(cc)
            end
          end
        end
      end
    end

    floors.each do |id, floor|
      next unless floor.key?(:edges)

      s = model.getSurfaceByName(id)
      expect(s).to_not be_empty
      expect(s.get.isConstructionDefaulted).to be false
      expect(s.get.construction.get.nameString).to include(" tbd")
    end

    ceilings.each do |id, ceiling|
      next unless ceiling.key?(:edges)

      s = model.getSurfaceByName(id)
      expect(s).to_not be_empty
      expect(s.get.isConstructionDefaulted).to be false
      expect(s.get.construction.get.nameString).to include(" tbd")
    end

    walls.each do |id, wall|
      next unless wall.key?(:edges)

      s = model.getSurfaceByName(id)
      expect(s).to_not be_empty
      expect(s.get.isConstructionDefaulted).to be false
      expect(s.get.construction.get.nameString).to include(" tbd")
    end
  end

  it "can check for balcony sills (ASHRAE 90.1 2022)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    # "Lo Scrigno" (or Jewel Box), by Renzo Piano (Lingotto Factory, Turin); a
    # cantilevered, single space art gallery (space #1) above a supply plenum
    # with slanted undersides (space #2) resting on four main pillars.
    file  = File.join(__dir__, "files/osms/in/loscrigno.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    argh = {option: "90.1.22|steel.m|default"}

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a Hash
    expect(surfaces.size).to eq(31)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(77)

    n_edges_at_grade             = 0
    n_edges_as_balconies         = 0
    n_edges_as_balconysills      = 0
    n_edges_as_concave_parapets  = 0
    n_edges_as_convex_parapets   = 0
    n_edges_as_concave_roofs     = 0
    n_edges_as_convex_roofs      = 0
    n_edges_as_rimjoists         = 0
    n_edges_as_concave_rimjoists = 0
    n_edges_as_convex_rimjoists  = 0
    n_edges_as_fenestrations     = 0
    n_edges_as_heads             = 0
    n_edges_as_sills             = 0
    n_edges_as_jambs             = 0
    n_edges_as_doorheads         = 0
    n_edges_as_doorsills         = 0
    n_edges_as_doorjambs         = 0
    n_edges_as_skylightjambs     = 0
    n_edges_as_concave_jambs     = 0
    n_edges_as_convex_jambs      = 0
    n_edges_as_corners           = 0
    n_edges_as_concave_corners   = 0
    n_edges_as_convex_corners    = 0
    n_edges_as_transitions       = 0

    io[:edges].each do |edge|
      expect(edge).to have_key(:type)

      n_edges_at_grade             += 1 if edge[:type] == :grade
      n_edges_at_grade             += 1 if edge[:type] == :gradeconcave
      n_edges_at_grade             += 1 if edge[:type] == :gradeconvex
      n_edges_as_balconies         += 1 if edge[:type] == :balcony
      n_edges_as_balconies         += 1 if edge[:type] == :balconyconcave
      n_edges_as_balconies         += 1 if edge[:type] == :balconyconvex
      n_edges_as_balconysills      += 1 if edge[:type] == :balconysill
      n_edges_as_balconysills      += 1 if edge[:type] == :balconysillconcave
      n_edges_as_balconysills      += 1 if edge[:type] == :balconysillconvex
      n_edges_as_concave_parapets  += 1 if edge[:type] == :parapetconcave
      n_edges_as_convex_parapets   += 1 if edge[:type] == :parapetconvex
      n_edges_as_concave_roofs     += 1 if edge[:type] == :roofconcave
      n_edges_as_convex_roofs      += 1 if edge[:type] == :roofconvex
      n_edges_as_rimjoists         += 1 if edge[:type] == :rimjoist
      n_edges_as_concave_rimjoists += 1 if edge[:type] == :rimjoistconcave
      n_edges_as_convex_rimjoists  += 1 if edge[:type] == :rimjoistconvex
      n_edges_as_fenestrations     += 1 if edge[:type] == :fenestration
      n_edges_as_heads             += 1 if edge[:type] == :head
      n_edges_as_heads             += 1 if edge[:type] == :headconcave
      n_edges_as_heads             += 1 if edge[:type] == :headconvex
      n_edges_as_sills             += 1 if edge[:type] == :sill
      n_edges_as_sills             += 1 if edge[:type] == :sillconcave
      n_edges_as_sills             += 1 if edge[:type] == :sillconvex
      n_edges_as_jambs             += 1 if edge[:type] == :jamb
      n_edges_as_concave_jambs     += 1 if edge[:type] == :jambconcave
      n_edges_as_convex_jambs      += 1 if edge[:type] == :jambconvex
      n_edges_as_doorheads         += 1 if edge[:type] == :doorhead
      n_edges_as_doorsills         += 1 if edge[:type] == :doorsill
      n_edges_as_doorjambs         += 1 if edge[:type] == :doorjamb
      n_edges_as_skylightjambs     += 1 if edge[:type] == :skylightjamb
      n_edges_as_skylightjambs     += 1 if edge[:type] == :skylightjambconvex
      n_edges_as_corners           += 1 if edge[:type] == :corner
      n_edges_as_concave_corners   += 1 if edge[:type] == :cornerconcave
      n_edges_as_convex_corners    += 1 if edge[:type] == :cornerconvex
      n_edges_as_transitions       += 1 if edge[:type] == :transition
    end

    # Lo Scrigno holds 8x wall/roof edges:
    #   - 4x along gallery roof/skylight (all convex)
    #   - 4x along the elevator roof (3x convex + 1x concave)
    #
    # The gallery wall/roof edges are not modelled here "as built", but rather
    # closer to details of another Renzo Piano extension: the Modern Wing of the
    # Art Institute of Chicago. Both galleries are similar in that daylighting
    # is zenithal, covering all (or nearly all) of the roof surface. In the
    # case of Chicago, the roof is ~entirely glazed (as reflected in the model).
    #
    # www.archdaily.com/24652/the-modern-wing-renzo-piano/
    # 5010473228ba0d42220015f8-the-modern-wing-renzo-piano-image?next_project=no
    #
    # However, a small 1" strip is maintained along the South roof/wall edge of
    # the gallery to ensure skylight area < roof area.
    #
    # No judgement here on the suitability of the design for either Chicago or
    # Turin. The model nonetheless remains an interesting (~extreme) test case
    # for TBD. Except along the South parapet, the transition from "wall-to-roof"
    # and "roof-to-skylight" are one and the same. So is the edge a :skylight
    # edge? or a :parapet (or :roof) edge? They're both. In such cases, the final
    # selection in TBD is based on the greatest PSI factor. In ASHRAE 90.1 2022,
    # only "vertical fenestration" edge PSI factors are explicitely
    # stated/published. For this reason, the 8x TBD-built-in ASHRAE PSI sets
    # have 0 W/K per meter assigned for any non-regulated edge, e.g.:
    #
    #   - skylight perimeters
    #   - non-fenestrated door perimeters
    #   - corners
    #
    # There are (possibly) 2x admissible interpretations of how to treat
    # non-regulated heat losss (edges as linear thermal bridges) in 90.1:
    #   1. assign 0 W/K•m for both proposed design and budget building models
    #   2. assign more realistic PSi factors, equally to both proposed/budget
    #
    # In both cases, the treatment of non-regulated heat loss remains "neutral"
    # between both proposed design and budget building models. Option #2 remains
    # closer to reality (more heat loss in winter, likely more heat gain in
    # summer), which is preferable for HVAC autosizing. Yet 90.1 (2022) ECB
    # doesn't seem to afford this type of flexibility, contrary to the "neutral"
    # treatment of (non-regulated) miscellaneous (process) loads. So for now,
    # TBD's built-in ASHRAE 90.1 2022 (A10) PSI factor sets recflect option #1.
    #
    # Users who choose option #2 can always write up a custom ASHRAE 90.1 (A10)
    # PSI factor set on file (tbd.json), initially based on the built-in 90.1
    # sets while resetting non-zero PSI factors.
    expect(n_edges_at_grade            ).to eq( 0)
    expect(n_edges_as_balconies        ).to eq( 2)
    expect(n_edges_as_balconysills     ).to eq( 2) # (2x instances of GlassDoor)
    expect(n_edges_as_concave_parapets ).to eq( 1)
    expect(n_edges_as_convex_parapets  ).to eq(11)
    expect(n_edges_as_concave_roofs    ).to eq( 0)
    expect(n_edges_as_convex_roofs     ).to eq( 0)
    expect(n_edges_as_rimjoists        ).to eq( 5)
    expect(n_edges_as_concave_rimjoists).to eq( 5)
    expect(n_edges_as_convex_rimjoists ).to eq(18)
    expect(n_edges_as_fenestrations    ).to eq( 0)
    expect(n_edges_as_heads            ).to eq( 2) # GlassDoor == fenestration
    expect(n_edges_as_sills            ).to eq( 0) # (2x balconysills)
    expect(n_edges_as_jambs            ).to eq( 4)
    expect(n_edges_as_concave_jambs    ).to eq( 0)
    expect(n_edges_as_convex_jambs     ).to eq( 0)
    expect(n_edges_as_doorheads        ).to eq( 0)
    expect(n_edges_as_doorjambs        ).to eq( 0)
    expect(n_edges_as_doorsills        ).to eq( 0)
    expect(n_edges_as_skylightjambs    ).to eq( 1) # along 1" rooftop strip
    expect(n_edges_as_corners          ).to eq( 0)
    expect(n_edges_as_concave_corners  ).to eq( 4)
    expect(n_edges_as_convex_corners   ).to eq(12)
    expect(n_edges_as_transitions      ).to eq(10)

    # For the purposes of the RSpec, vertical access (elevator and stairs,
    # normally fully glazed) are modelled as (opaque) extensions of either
    # space. Deratable (exterior) surfaces are grouped, prefixed as follows:
    #
    #   - "g_" : art gallery
    #   - "p_" : underfloor plenum (supplying gallery)
    #   - "s_" : stairwell (leading to/through plenum & gallery)
    #   - "e_" : (side) elevator leading to gallery
    #
    # East vs West walls have equal heat loss (W/K) from major thermal bridging
    # as they are symmetrical. North vs South walls differ slightly due to:
    #   - adjacency with elevator walls
    #   - different balcony lengths
    expect(surfaces["g_E_wall"  ][:heatloss]).to be_within(TOL).of( 4.30)
    expect(surfaces["g_W_wall"  ][:heatloss]).to be_within(TOL).of( 4.30)
    expect(surfaces["g_N_wall"  ][:heatloss]).to be_within(TOL).of(15.95)
    expect(surfaces["g_S1_wall" ][:heatloss]).to be_within(TOL).of( 1.87)
    expect(surfaces["g_S2_wall" ][:heatloss]).to be_within(TOL).of( 1.04)
    expect(surfaces["g_S3_wall" ][:heatloss]).to be_within(TOL).of( 8.19)

    expect(surfaces["e_top"     ][:heatloss]).to be_within(TOL).of( 1.43)
    expect(surfaces["e_E_wall"  ][:heatloss]).to be_within(TOL).of( 0.32)
    expect(surfaces["e_W_wall"  ][:heatloss]).to be_within(TOL).of( 0.32)
    expect(surfaces["e_N_wall"  ][:heatloss]).to be_within(TOL).of( 0.95)
    expect(surfaces["e_S_wall"  ][:heatloss]).to be_within(TOL).of( 0.85)
    expect(surfaces["e_floor"   ][:heatloss]).to be_within(TOL).of( 2.46)

    expect(surfaces["s_E_wall"  ][:heatloss]).to be_within(TOL).of( 1.17)
    expect(surfaces["s_W_wall"  ][:heatloss]).to be_within(TOL).of( 1.17)
    expect(surfaces["s_N_wall"  ][:heatloss]).to be_within(TOL).of( 1.54)
    expect(surfaces["s_S_wall"  ][:heatloss]).to be_within(TOL).of( 1.54)
    expect(surfaces["s_floor"   ][:heatloss]).to be_within(TOL).of( 2.70)

    expect(surfaces["p_W1_floor"][:heatloss]).to be_within(TOL).of( 4.23)
    expect(surfaces["p_W2_floor"][:heatloss]).to be_within(TOL).of( 1.82)
    expect(surfaces["p_W3_floor"][:heatloss]).to be_within(TOL).of( 1.82)
    expect(surfaces["p_W4_floor"][:heatloss]).to be_within(TOL).of( 0.58)
    expect(surfaces["p_E_floor" ][:heatloss]).to be_within(TOL).of( 5.73)
    expect(surfaces["p_N_wall"  ][:heatloss]).to be_within(TOL).of(11.44)
    expect(surfaces["p_S2_wall" ][:heatloss]).to be_within(TOL).of( 8.16)
    expect(surfaces["p_S1_wall" ][:heatloss]).to be_within(TOL).of( 2.04)
    expect(surfaces["p_floor"   ][:heatloss]).to be_within(TOL).of( 3.07)

    expect(argh).to have_key(:io)
    out  = JSON.pretty_generate(argh[:io])
    outP = File.join(__dir__, "../json/tbd_loscrigno1.out.json")
    File.open(outP, "w") { |outP| outP.puts out }
  end

  it "can switch between parapet/roof edge types" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    file  = File.join(__dir__, "files/osms/in/loscrigno.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    # Switching wall/roof edges from/to:
    #    - "parapet" PSI factor 0.26 W/K•m
    #    - "roof"    PSI factor 0.02 W/K•m !!
    #
    # ... as per 90.1 2022 (non-"parapet" admisible thresholds are much lower).
    argh = {option: "90.1.22|steel.m|default", parapet: false}

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a Hash
    expect(surfaces.size).to eq(31)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(77)

    n_edges_at_grade             = 0
    n_edges_as_balconies         = 0
    n_edges_as_balconysills      = 0
    n_edges_as_concave_parapets  = 0
    n_edges_as_convex_parapets   = 0
    n_edges_as_concave_roofs     = 0
    n_edges_as_convex_roofs      = 0
    n_edges_as_rimjoists         = 0
    n_edges_as_concave_rimjoists = 0
    n_edges_as_convex_rimjoists  = 0
    n_edges_as_fenestrations     = 0
    n_edges_as_heads             = 0
    n_edges_as_sills             = 0
    n_edges_as_jambs             = 0
    n_edges_as_doorheads         = 0
    n_edges_as_doorsills         = 0
    n_edges_as_doorjambs         = 0
    n_edges_as_skylightjambs     = 0
    n_edges_as_concave_jambs     = 0
    n_edges_as_convex_jambs      = 0
    n_edges_as_corners           = 0
    n_edges_as_concave_corners   = 0
    n_edges_as_convex_corners    = 0
    n_edges_as_transitions       = 0

    io[:edges].each do |edge|
      expect(edge).to have_key(:type)

      n_edges_at_grade             += 1 if edge[:type] == :grade
      n_edges_at_grade             += 1 if edge[:type] == :gradeconcave
      n_edges_at_grade             += 1 if edge[:type] == :gradeconvex
      n_edges_as_balconies         += 1 if edge[:type] == :balcony
      n_edges_as_balconies         += 1 if edge[:type] == :balconyconcave
      n_edges_as_balconies         += 1 if edge[:type] == :balconyconvex
      n_edges_as_balconysills      += 1 if edge[:type] == :balconysill
      n_edges_as_balconysills      += 1 if edge[:type] == :balconysillconcave
      n_edges_as_balconysills      += 1 if edge[:type] == :balconysillconvex
      n_edges_as_concave_parapets  += 1 if edge[:type] == :parapetconcave
      n_edges_as_convex_parapets   += 1 if edge[:type] == :parapetconvex
      n_edges_as_concave_roofs     += 1 if edge[:type] == :roofconcave
      n_edges_as_convex_roofs      += 1 if edge[:type] == :roofconvex
      n_edges_as_rimjoists         += 1 if edge[:type] == :rimjoist
      n_edges_as_concave_rimjoists += 1 if edge[:type] == :rimjoistconcave
      n_edges_as_convex_rimjoists  += 1 if edge[:type] == :rimjoistconvex
      n_edges_as_fenestrations     += 1 if edge[:type] == :fenestration
      n_edges_as_heads             += 1 if edge[:type] == :head
      n_edges_as_heads             += 1 if edge[:type] == :headconcave
      n_edges_as_heads             += 1 if edge[:type] == :headconvex
      n_edges_as_sills             += 1 if edge[:type] == :sill
      n_edges_as_sills             += 1 if edge[:type] == :sillconcave
      n_edges_as_sills             += 1 if edge[:type] == :sillconvex
      n_edges_as_jambs             += 1 if edge[:type] == :jamb
      n_edges_as_concave_jambs     += 1 if edge[:type] == :jambconcave
      n_edges_as_convex_jambs      += 1 if edge[:type] == :jambconvex
      n_edges_as_doorheads         += 1 if edge[:type] == :doorhead
      n_edges_as_doorsills         += 1 if edge[:type] == :doorsill
      n_edges_as_doorjambs         += 1 if edge[:type] == :doorjamb
      n_edges_as_skylightjambs     += 1 if edge[:type] == :skylightjamb
      n_edges_as_skylightjambs     += 1 if edge[:type] == :skylightjambconvex
      n_edges_as_corners           += 1 if edge[:type] == :corner
      n_edges_as_concave_corners   += 1 if edge[:type] == :cornerconcave
      n_edges_as_convex_corners    += 1 if edge[:type] == :cornerconvex
      n_edges_as_transitions       += 1 if edge[:type] == :transition
    end

    expect(n_edges_at_grade            ).to eq( 0)
    expect(n_edges_as_balconies        ).to eq( 2)
    expect(n_edges_as_balconysills     ).to eq( 2) # (2x instances of GlassDoor)
    expect(n_edges_as_concave_parapets ).to eq( 0) #  1x if parapet (not roof)
    expect(n_edges_as_convex_parapets  ).to eq( 0) # 11x if parapet (not roof)
    expect(n_edges_as_concave_roofs    ).to eq( 1)
    expect(n_edges_as_convex_roofs     ).to eq(11)
    expect(n_edges_as_rimjoists        ).to eq( 5)
    expect(n_edges_as_concave_rimjoists).to eq( 5)
    expect(n_edges_as_convex_rimjoists ).to eq(18)
    expect(n_edges_as_fenestrations    ).to eq( 0)
    expect(n_edges_as_heads            ).to eq( 2) # GlassDoor == fenestration
    expect(n_edges_as_sills            ).to eq( 0) # (2x balconysills)
    expect(n_edges_as_jambs            ).to eq( 4)
    expect(n_edges_as_concave_jambs    ).to eq( 0)
    expect(n_edges_as_convex_jambs     ).to eq( 0)
    expect(n_edges_as_doorheads        ).to eq( 0)
    expect(n_edges_as_doorjambs        ).to eq( 0)
    expect(n_edges_as_doorsills        ).to eq( 0)
    expect(n_edges_as_skylightjambs    ).to eq( 1) # along 1" rooftop strip
    expect(n_edges_as_corners          ).to eq( 0)
    expect(n_edges_as_concave_corners  ).to eq( 4)
    expect(n_edges_as_convex_corners   ).to eq(12)
    expect(n_edges_as_transitions      ).to eq(10)

    #      roof PSI :  0.02 W/K•m
    # - parapet PSI :  0.26 W/K•m
    # ---------------------------
    # =   delta PSI : -0.24 W/K•m
    #
    # e.g. East & West   : reduction of 10.4m x -0.24 W/K•m = -2.496 W/K
    # e.g. North         : reduction of 36.6m x -0.24 W/K•m = -8.784 W/K
    #
    # Total length of roof/parapets : 11m + 2x 36.6m + 2x 10.4m = 105m
    # ... 105m x -0.24 W/K•m = -25.2 W/K
    expect(surfaces["g_E_wall"  ][:heatloss]).to be_within(TOL).of( 1.80) #   4.3 = -2.5
    expect(surfaces["g_W_wall"  ][:heatloss]).to be_within(TOL).of( 1.80) #   4.3 = -2.5
    expect(surfaces["g_N_wall"  ][:heatloss]).to be_within(TOL).of( 7.17) # 15.95 = -8.8
    expect(surfaces["g_S1_wall" ][:heatloss]).to be_within(TOL).of( 1.08) #  1.87 = -0.8
    expect(surfaces["g_S2_wall" ][:heatloss]).to be_within(TOL).of( 0.08) #  1.04 = -1.0
    expect(surfaces["g_S3_wall" ][:heatloss]).to be_within(TOL).of( 5.07) #  8.19 = -3.1

    expect(surfaces["e_top"     ][:heatloss]).to be_within(TOL).of( 0.11) #  1.32 = -1.2
    expect(surfaces["e_E_wall"  ][:heatloss]).to be_within(TOL).of( 0.14) #  0.32 = -0.2
    expect(surfaces["e_W_wall"  ][:heatloss]).to be_within(TOL).of( 0.14) #  0.32 = -0.2
    expect(surfaces["e_N_wall"  ][:heatloss]).to be_within(TOL).of( 0.95)
    expect(surfaces["e_S_wall"  ][:heatloss]).to be_within(TOL).of( 0.37) #  0.85 = -0.5
    expect(surfaces["e_floor"   ][:heatloss]).to be_within(TOL).of( 2.46)

    expect(surfaces["s_E_wall"  ][:heatloss]).to be_within(TOL).of( 1.17)
    expect(surfaces["s_W_wall"  ][:heatloss]).to be_within(TOL).of( 1.17)
    expect(surfaces["s_N_wall"  ][:heatloss]).to be_within(TOL).of( 1.54)
    expect(surfaces["s_S_wall"  ][:heatloss]).to be_within(TOL).of( 1.54)
    expect(surfaces["s_floor"   ][:heatloss]).to be_within(TOL).of( 2.70)

    expect(surfaces["p_W1_floor"][:heatloss]).to be_within(TOL).of( 4.23)
    expect(surfaces["p_W2_floor"][:heatloss]).to be_within(TOL).of( 1.82)
    expect(surfaces["p_W3_floor"][:heatloss]).to be_within(TOL).of( 1.82)
    expect(surfaces["p_W4_floor"][:heatloss]).to be_within(TOL).of( 0.58)
    expect(surfaces["p_E_floor" ][:heatloss]).to be_within(TOL).of( 5.73)
    expect(surfaces["p_N_wall"  ][:heatloss]).to be_within(TOL).of(11.44)
    expect(surfaces["p_S2_wall" ][:heatloss]).to be_within(TOL).of( 8.16)
    expect(surfaces["p_S1_wall" ][:heatloss]).to be_within(TOL).of( 2.04)
    expect(surfaces["p_floor"   ][:heatloss]).to be_within(TOL).of( 3.07)

    expect(argh).to have_key(:io)
    out  = JSON.pretty_generate(argh[:io])
    outP = File.join(__dir__, "../json/tbd_loscrigno1.out.json")
    File.open(outP, "w") { |outP| outP.puts out }
  end
end
