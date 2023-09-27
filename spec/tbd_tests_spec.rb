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
    east  = model.getSpaceByName("Story 1 East Perimeter Space" )
    south = model.getSpaceByName("Story 1 South Perimeter Space")
    west  = model.getSpaceByName("Story 1 West Perimeter Space" )
    core  = model.getSpaceByName("Story 1 Core Space"           )

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

  it "can check for balcony sills (ASHRAE 90.1 2022)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    # The following populates OpenStudio and Topolys models of "Lo Scrigno"
    # (or Jewel Box), by Renzo Piano (Lingotto Factory, Turin); a cantilevered,
    # single space art gallery (space #1) above a supply plenum with slanted
    # undersides (space #2) resting on four main pillars.
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
    expect(surfaces.size).to eq(27)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(66)

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
    # case of Chicago, the roof is entirely glazed (as reflected in the model):
    #
    # www.archdaily.com/24652/the-modern-wing-renzo-piano/
    # 5010473228ba0d42220015f8-the-modern-wing-renzo-piano-image?next_project=no
    #
    # This is allowed in OpenStudio, yet SketchUp (via the plugin) would
    # complain.
    #
    # No judgement here on the suitability of the design for either Chicago or
    # Turin. The model nonetheless remains an interesting (~extreme) test case
    # for TBD. Here, the transition from "wall-to-roof" and "roof-to-skylight"
    # are one and the same. So is the edge a :skylight edge? or a :parapet (or
    # :roof) edge? They're both. In such cases, the final selection in TBD is
    # based on the greatest PSI factor. In ASHRAE 90.1 2022, only "vertical
    # fenestration" edge PSI factors are explicitely stated/published. For this
    # reason, the 8x TBD-built-in ASHRAE PSI sets have 0 W/K per meter assigned
    # for any non-regulated edge, e.g.:
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
    # Users who prefer option #2 can always write up a custom ASHRAE 90.1 (A10)
    # PSI factor set on file (tbd.json), initially based on the built-in 90.1
    # sets yet while resetting non-zero PSI factors.
    expect(n_edges_at_grade            ).to eq( 0)
    expect(n_edges_as_balconies        ).to eq( 2)
    expect(n_edges_as_balconysills     ).to eq( 2) # (2x instances of GlassDoor)
    expect(n_edges_as_concave_parapets ).to eq( 1)
    expect(n_edges_as_convex_parapets  ).to eq( 7)
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
    expect(n_edges_as_skylightjambs    ).to eq( 0) # (4 of 7x convex parapets)
    expect(n_edges_as_corners          ).to eq( 0)
    expect(n_edges_as_concave_corners  ).to eq( 4)
    expect(n_edges_as_convex_corners   ).to eq(12)
    expect(n_edges_as_transitions      ).to eq( 4)

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
    expect(surfaces["g_S_wall"  ][:heatloss]).to be_within(TOL).of(15.86)

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
    expect(surfaces["p_W2_floor"][:heatloss]).to be_within(TOL).of( 4.22)
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
    expect(surfaces.size).to eq(27)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(66)

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
    expect(n_edges_as_concave_parapets ).to eq( 0) # 1 if parapet (not roof)
    expect(n_edges_as_convex_parapets  ).to eq( 0) # 7 if parapet (not roof)
    expect(n_edges_as_concave_roofs    ).to eq( 1)
    expect(n_edges_as_convex_roofs     ).to eq( 7) # 7 - 4x "convex jambs"
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
    expect(n_edges_as_skylightjambs    ).to eq( 0) # (4 of 7x convex roofs)
    expect(n_edges_as_corners          ).to eq( 0)
    expect(n_edges_as_concave_corners  ).to eq( 4)
    expect(n_edges_as_convex_corners   ).to eq(12)
    expect(n_edges_as_transitions      ).to eq( 4)

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
    expect(surfaces["g_S_wall"  ][:heatloss]).to be_within(TOL).of( 6.59) # 15.85 = -9.3

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
    expect(surfaces["p_W2_floor"][:heatloss]).to be_within(TOL).of( 4.22)
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
