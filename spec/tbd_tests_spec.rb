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

  it "can process testing JSON surface KHI entries" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    expect(TBD.level).to eq(INF)
    expect(TBD.reset(DBG)).to eq(DBG)
    expect(TBD.level).to eq(DBG)
    expect(TBD.clean!).to eq(DBG)

    # First, basic IO tests with invalid entries.
    k = TBD::KHI.new
    expect(k.point.is_a?(Hash)).to be(true)
    expect(k.point.size).to eq(6)

    # Invalid identifier key.
    new_KHI = { name: "new_KHI", point: 1.0 }
    expect(k.append(new_KHI)).to be(false)
    expect(TBD.debug?).to be(true)
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message].include?("Missing 'id' key")).to be(true)
    TBD.clean!

    # Invalid identifier.
    new_KHI = { id: nil, point: 1.0 }
    expect(k.append(new_KHI)).to be(false)
    expect(TBD.error?).to be(true)
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message].include?("'KHI id' NilClass?")).to be(true)
    TBD.clean!

    # Odd (yet valid) identifier.
    new_KHI = { id: [], point: 1.0 }
    expect(k.append(new_KHI)).to be(true)
    expect(TBD.status.zero?).to be(true)
    expect(k.point.keys.include?("[]")).to be(true)
    expect(k.point.size).to eq(7)

    # Existing identifier.
    new_KHI = { id: "code (Quebec)", point: 1.0 }
    expect(k.append(new_KHI)).to be(false)
    expect(TBD.error?).to be(true)
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message].include?("existing KHI entry")).to be(true)
    TBD.clean!

    # Missing point conductance.
    new_KHI = { id: "foo" }
    expect(k.append(new_KHI)).to be(false)
    expect(TBD.debug?).to be(true)
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message].include?("Missing 'point' key")).to be(true)


    # Valid JSON entries.
    TBD.clean!
    argh               = {}
    argh[:option     ] = "(non thermal bridging)"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_seb_n2.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)

    io        = json[:io      ]
    surfaces  = json[:surfaces]
    expect(TBD.status          ).to eq(    0)
    expect(surfaces.nil?       ).to be(false)
    expect(surfaces.is_a?(Hash)).to be( true)
    expect(surfaces.size       ).to eq(   56)
    expect(io.nil?             ).to be(false)
    expect(io.is_a?(Hash)      ).to be( true)
    expect(io.empty?           ).to be(false)

    # As the :building PSI set on file remains "(non thermal bridging)", one
    # should not expect differences in results, i.e. derating shouldn't occur.
    # However, the JSON file holds KHI entries for "Entryway  Wall 2" :
    # 3x "columns" @0.5 W/K + 4x supports @0.5W/K = 3.5 W/K
    surfaces.values.each do |surface|
      next unless surface.key?(:ratio)

      expect(surface[:heatloss]).to be_within(0.01).of(3.5)
    end
  end

  it "can process JSON surface KHI & PSI entries + building & edge" do
    translator = OpenStudio::OSVersion::VersionTranslator.new

    # First, basic IO tests with invalid entries.
    ps = TBD::PSI.new
    expect(ps.set.is_a?(Hash)).to be(true)
    expect(ps.has.is_a?(Hash)).to be(true)
    expect(ps.val.is_a?(Hash)).to be(true)
    expect(ps.set.size).to eq(8)
    expect(ps.has.size).to eq(8)
    expect(ps.val.size).to eq(8)

    expect(ps.gen(nil)).to be(false)
    expect(TBD.status.zero?).to be(true)

    # Invalid identifier key.
    new_PSI = { name: "new_PSI", balcony: 1.0 }
    expect(ps.append(new_PSI)).to be(false)
    expect(TBD.debug?).to be(true)
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message].include?("Missing 'id' key")).to be(true)
    TBD.clean!

    # Invalid identifier.
    new_PSI = { id: nil, balcony: 1.0 }
    expect(ps.append(new_PSI)).to be(false)
    expect(TBD.error?).to be(true)
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message].include?("'set ID' NilClass?")).to be(true)
    TBD.clean!

    # Odd (yet valid) identifier.
    new_PSI = { id: [], balcony: 1.0 }
    expect(ps.append(new_PSI)).to be(true)
    expect(TBD.status.zero?).to be(true)
    expect(ps.set.keys.include?("[]")).to be(true)
    expect(ps.has.keys.include?("[]")).to be(true)
    expect(ps.val.keys.include?("[]")).to be(true)
    expect(ps.set.size).to eq(9)
    expect(ps.has.size).to eq(9)
    expect(ps.val.size).to eq(9)

    # Existing identifier.
    new_PSI = { id: "code (Quebec)", balcony: 1.0 }
    expect(ps.append(new_PSI)).to be(false)
    expect(TBD.error?).to be(true)
    expect(TBD.logs.size).to eq(1)
    expect(TBD.logs.first[:message].include?("existing PSI set")).to be(true)
    TBD.clean!

    # Defined vs missing conductances.
    new_PSI = { id: "foo" }
    expect(ps.append(new_PSI)).to be(true)

    s = ps.shorthands("foo")
    expect(TBD.status.zero?).to be(true)
    expect(s.is_a?(Hash)).to be(true)
    expect(s.key?(:has) ).to be(true)
    expect(s.key?(:val) ).to be(true)

    [:joint, :transition].each do |type|
      expect(s[:has].key?(type)).to be(true)
      expect(s[:val].key?(type)).to be(true)
      expect(s[:has][type]     ).to be(true)
      expect(s[:val][type]     ).to be_within(TOL).of(0.000)
    end

    [:balcony, :rimjoist, :fenestration, :parapet].each do |type|
      expect(s[:has].key?(type)).to be( true)
      expect(s[:val].key?(type)).to be( true)
      expect(s[:has][type]     ).to be(false)
      expect(s[:val][type]     ).to be_within(TOL).of(0.000)
    end

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Valid JSON entries.
    TBD.clean!
    name               = "Entryway  Wall 5"
    argh               = {}
    argh[:option     ] = "(non thermal bridging)"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_seb_n4.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)

    io        = json[:io      ]
    surfaces  = json[:surfaces]
    expect(TBD.status          ).to eq(    0)
    expect(TBD.logs.empty?     ).to be( true)
    expect(surfaces.nil?       ).to be(false)
    expect(surfaces.is_a?(Hash)).to be( true)
    expect(surfaces.size       ).to eq(   56)
    expect(io.nil?             ).to be(false)
    expect(io.is_a?(Hash)      ).to be( true)
    expect(io.empty?           ).to be(false)

    # As the :building PSI set on file == "(non thermal bridgin)", derating
    # shouldn't occur at large. However, the JSON file holds a custom edge
    # entry for "Entryway  Wall 5" : "bad" fenestration permieters, which
    # only derates the host wall itself
    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"

      expect(surface.key?(:ratio)).to be(false)            unless id == name
      expect(surface[:heatloss]  ).to be_within(0.01).of(8.89) if id == name
    end
  end

  it "can pre-process UA parameters" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    ref = "code (Quebec)"

    argh               = {}
    argh[:option     ] = "poor (BETBG)"
    argh[:seed       ] = "./files/osms/in/warehouse.osm"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_warehouse10.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    argh[:gen_ua     ] = true
    argh[:ua_ref     ] = ref
    argh[:version    ] = OpenStudio.openStudioVersion

    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    heated = TBD.heatingTemperatureSetpoints?(model)
    cooled = TBD.coolingTemperatureSetpoints?(model)
    expect(heated).to be(true)
    expect(cooled).to be(true)

    model.getSpaces.each do |space|
      expect(space.thermalZone.empty?).to be(false)
      expect(TBD.unconditioned?(space)).to be(false)

      zone  = space.thermalZone.get
      stpts = TBD.setpoints(space)
      expect(stpts.is_a?(Hash)).to be(true)
      expect(stpts.key?(:heating)).to be(true)
      expect(stpts.key?(:cooling)).to be(true)

      heating = stpts[:heating]
      cooling = stpts[:cooling]
      expect(heating.is_a?(Float)).to be(true)
      expect(cooling.is_a?(Float)).to be(true)

      if zone.nameString == "Zone1 Office ZN"
        expect(heating).to be_within(0.1).of(21.1)
        expect(cooling).to be_within(0.1).of(23.9)
      elsif zone.nameString == "Zone2 Fine Storage ZN"
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
    expect( shrts[:has].empty?).to be(false)
    expect( shrts[:val].empty?).to be(false)
    has   = shrts[:has]
    val   = shrts[:val]

    expect(has.empty?).to be(false)
    expect(val.empty?).to be(false)
    json = TBD.process(model, argh)

    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    argh[:io      ] = json[:io      ]
    argh[:surfaces] = json[:surfaces]

    expect(TBD.status.zero?    ).to be(true)
    expect(TBD.logs.empty?     ).to be(true)

    expect(argh[:surfaces].nil?        ).to be(false)
    expect(argh[:surfaces].is_a?(Hash) ).to be( true)
    expect(argh[:surfaces].size        ).to eq(   23)
    expect(argh[:io      ].nil?        ).to be(false)
    expect(argh[:io      ].is_a?(Hash) ).to be( true)
    expect(argh[:io      ].empty?      ).to be(false)
    expect(argh[:io      ].key?(:edges)).to be( true)
    expect(argh[:io      ][:edges].size).to eq(  300)

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
      expect(surface.key?(:deratable)).to be(true)
      next unless surface[:deratable]

      expect(ids.has_value?(id) ).to be(true)
      expect(surface.key?(:type)).to be(true)
      expect(surface.key?(:net )).to be(true)
      expect(surface.key?(:u   )).to be(true)
      expect(surface[:net] > TOL).to be(true)
      expect(surface[:u  ] > TOL).to be(true)

      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:a]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:b]
      expect(surface[:u]).to be_within(0.01).of(0.31) if id == ids[:c]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:d]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:e]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:f]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:g]
      expect(surface[:u]).to be_within(0.01).of(0.48) if id == ids[:h]
      expect(surface[:u]).to be_within(0.01).of(0.55) if id == ids[:i]
      expect(surface[:u]).to be_within(0.01).of(0.64) if id == ids[:j]
      expect(surface[:u]).to be_within(0.01).of(0.64) if id == ids[:k]
      expect(surface[:u]).to be_within(0.01).of(0.64) if id == ids[:l]

      # Reference values.
      expect(surface.key?(:ref)).to be(true)
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:a]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:b]
      expect(surface[:ref]).to be_within(0.01).of(0.18) if id == ids[:c]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:d]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:e]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:f]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:g]
      expect(surface[:ref]).to be_within(0.01).of(0.28) if id == ids[:h]
      expect(surface[:ref]).to be_within(0.01).of(0.23) if id == ids[:i]
      expect(surface[:ref]).to be_within(0.01).of(0.34) if id == ids[:j]
      expect(surface[:ref]).to be_within(0.01).of(0.34) if id == ids[:k]
      expect(surface[:ref]).to be_within(0.01).of(0.34) if id == ids[:l]

      expect(surface.key?(:heating)).to be(true)
      expect(surface.key?(:cooling)).to be(true)
      bloc = bloc1
      bloc = bloc2 if surface[:heating] < 18

      if    surface[:type ] == :wall
        bloc[:pro][:walls ] += surface[:net] * surface[:u  ]
        bloc[:ref][:walls ] += surface[:net] * surface[:ref]
      elsif surface[:type ] == :ceiling
        bloc[:pro][:roofs ] += surface[:net] * surface[:u  ]
        bloc[:ref][:roofs ] += surface[:net] * surface[:ref]
      else                   # :floors
        bloc[:pro][:floors] += surface[:net] * surface[:u  ]
        bloc[:ref][:floors] += surface[:net] * surface[:ref]
      end

      if surface.key?(:doors)
        surface[:doors].each do |i, door|
          expect(id2.has_value?(i) ).to be( true)
          expect(door.key?(:gross )).to be( true)
          expect(door.key?(:glazed)).to be(false)
          expect(door.key?(:u     )).to be( true)
          expect(door.key?(:ref   )).to be( true)
          expect(door[:gross] > TOL).to be( true)
          expect(door[:u    ] > TOL).to be( true)
          expect(door[:ref  ] > TOL).to be( true)
          expect(door[:u    ]      ).to be_within(0.01).of(3.98)

          bloc[:pro][:doors] += door[:gross] * door[:u  ]
          bloc[:ref][:doors] += door[:gross] * door[:ref]
        end
      end

      if surface.key?(:skylights)
        surface[:skylights].each do |i, skylight|
          expect(skylight.key?(:gross )).to be(true)
          expect(skylight.key?(:u     )).to be(true)
          expect(skylight.key?(:ref   )).to be(true)
          expect(skylight[:u    ] > TOL).to be(true)
          expect(skylight[:gross] > TOL).to be(true)
          expect(skylight[:ref  ] > TOL).to be(true)
          expect(skylight[:u    ]      ).to be_within(0.01).of(6.64)

          bloc[:pro][:skylights] += skylight[:gross] * skylight[:u  ]
          bloc[:ref][:skylights] += skylight[:gross] * skylight[:ref]
        end
      end

      id3 = { a: "Office Front Wall Window 1",
              b: "Office Front Wall Window2"
            }.freeze

      if surface.key?(:windows)
        surface[:windows].each do |i, window|
          expect(window.key?(:u   )).to be(true)
          expect(window.key?(:ref )).to be(true)
          expect(window[:ref] > TOL).to be(true)

          bloc[:pro][:windows] += window[:gross] * window[:u  ]
          bloc[:ref][:windows] += window[:gross] * window[:ref]

          expect(window[:u] > 0).to be(true)
          expect(window[:u    ]).to be_within(0.01).of(4.00) if i == id3[:a]
          expect(window[:u    ]).to be_within(0.01).of(3.50) if i == id3[:b]
          expect(window[:gross]).to be_within(0.1 ).of(5.58) if i == id3[:a]
          expect(window[:gross]).to be_within(0.1 ).of(5.58) if i == id3[:b]

          next if i == id3[:a] || i == id3[:b]

          expect(window[:gross]).to be_within(0.1 ).of(3.25)
          expect(window[:u    ]).to be_within(0.01).of(2.35)
        end
      end

      if surface.key?(:edges)
        surface[:edges].values.each do |edge|
          expect(edge.key?(:type )).to be(true)
          expect(edge.key?(:ratio)).to be(true)
          expect(edge.key?(:ref  )).to be(true)
          expect(edge.key?(:psi  )).to be(true)
          next unless edge[:psi] > TOL

          tt   = psi.safe(ref, edge[:type])
          expect(tt.nil?   ).to be(false)
          expect(edge[:ref]).to be_within(0.01).of(val[tt] * edge[:ratio])
          rate = edge[:ref] / edge[:psi] * 100

          case tt
          when :rimjoist
            expect(rate).to be_within(0.1).of(30.0)
            bloc[:pro][:rimjoists] += edge[:length] * edge[:psi]
            bloc[:ref][:rimjoists] += edge[:length] * val[tt] * edge[:ratio]
          when :parapet
            expect(rate).to be_within(0.1).of(40.6)
            bloc[:pro][:parapets ] += edge[:length] * edge[:psi]
            bloc[:ref][:parapets ] += edge[:length] * val[tt] * edge[:ratio]
          when :fenestration
            expect(rate).to be_within(0.1).of(40.0)
            bloc[:pro][:trim     ] += edge[:length] * edge[:psi]
            bloc[:ref][:trim     ] += edge[:length] * val[tt] * edge[:ratio]
          when :corner
            expect(rate).to be_within(0.1).of(35.3)
            bloc[:pro][:corners  ] += edge[:length] * edge[:psi]
            bloc[:ref][:corners  ] += edge[:length] * val[tt] * edge[:ratio]
          when :grade
            expect(rate).to be_within(0.1).of(52.9)
            bloc[:pro][:grade    ] += edge[:length] * edge[:psi]
            bloc[:ref][:grade    ] += edge[:length] * val[tt] * edge[:ratio]
          else
            expect(rate).to be_within(0.1).of( 0.0)
            bloc[:pro][:other    ] += edge[:length] * edge[:psi]
            bloc[:ref][:other    ] += edge[:length] * val[tt] * edge[:ratio]
          end
        end
      end

      if surface.key?(:pts)
        surface[:pts].values.each do |pts|
          expect(pts.key?(:val)).to be(true)
          expect(pts.key?(:n  )).to be(true)
          expect(pts.key?(:ref)).to be(true)

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
    expect(bloc1_pro_UA).to be_within(0.1).of(214.8)
    # Info: Design (fully heated): 199.2 W/K vs 114.2 W/K

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

    bloc1_ref_UA = bloc1[:ref].values.reduce(:+)
    expect(bloc1_ref_UA           ).to be_within(0.1).of( 107.2)
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

    bloc2_pro_UA = bloc2[:pro].values.reduce(:+)
    expect(bloc2_pro_UA           ).to be_within(0.1).of(4863.6)
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

    bloc2_ref_UA = bloc2[:ref].values.reduce(:+)
    expect(bloc2_ref_UA).to be_within(0.1).of(2275.4)

    # Testing summaries function.
    ua = TBD.ua_summary(Time.now, argh)
    expect(ua.nil?        ).to be(false)
    expect(ua.empty?      ).to be(false)
    expect(ua.is_a?(Hash) ).to be( true)
    expect(ua.key?(:model)).to be( true)

    expect(ua.key?(:fr)            ).to be(true)
    expect(ua[:fr].key?(:objective)).to be(true)
    expect(ua[:fr].key?(:details  )).to be(true)
    expect(ua[:fr].key?(:areas    )).to be(true)
    expect(ua[:fr].key?(:notes    )).to be(true)

    expect(ua[:fr][:objective].empty?       ).to be(false)
    expect(ua[:fr][:details  ].is_a?(Array) ).to be( true)
    expect(ua[:fr][:details  ].empty?       ).to be(false)
    expect(ua[:fr][:areas    ].empty?       ).to be(false)
    expect(ua[:fr][:areas    ].is_a?(Hash)  ).to be( true)
    expect(ua[:fr][:areas    ].key?(:walls )).to be( true)
    expect(ua[:fr][:areas    ].key?(:roofs )).to be( true)
    expect(ua[:fr][:areas    ].key?(:floors)).to be(false)
    expect(ua[:fr][:notes    ].empty?       ).to be(false)

    expect(ua[:fr].key?(:b1)            ).to be( true)
    expect(ua[:fr][:b1].empty?          ).to be(false)
    expect(ua[:fr][:b1].key?(:summary  )).to be( true)
    expect(ua[:fr][:b1].key?(:walls    )).to be( true)
    expect(ua[:fr][:b1].key?(:roofs    )).to be(false)
    expect(ua[:fr][:b1].key?(:floors   )).to be(false)
    expect(ua[:fr][:b1].key?(:doors    )).to be( true)
    expect(ua[:fr][:b1].key?(:windows  )).to be( true)
    expect(ua[:fr][:b1].key?(:skylights)).to be(false)
    expect(ua[:fr][:b1].key?(:rimjoists)).to be( true)
    expect(ua[:fr][:b1].key?(:parapets )).to be(false)
    expect(ua[:fr][:b1].key?(:trim     )).to be( true)
    expect(ua[:fr][:b1].key?(:corners  )).to be( true)
    expect(ua[:fr][:b1].key?(:balconies)).to be(false)
    expect(ua[:fr][:b1].key?(:grade    )).to be( true)
    expect(ua[:fr][:b1].key?(:other    )).to be(false)

    expect(ua[:fr].key?(:b2)            ).to be( true)
    expect(ua[:fr][:b2].empty?          ).to be(false)
    expect(ua[:fr][:b2].key?(:summary  )).to be( true)
    expect(ua[:fr][:b2].key?(:walls    )).to be( true)
    expect(ua[:fr][:b2].key?(:roofs    )).to be( true)
    expect(ua[:fr][:b2].key?(:floors   )).to be(false)
    expect(ua[:fr][:b2].key?(:doors    )).to be( true)
    expect(ua[:fr][:b2].key?(:windows  )).to be(false)
    expect(ua[:fr][:b2].key?(:skylights)).to be( true)
    expect(ua[:fr][:b2].key?(:rimjoists)).to be( true)
    expect(ua[:fr][:b2].key?(:parapets )).to be( true)
    expect(ua[:fr][:b2].key?(:trim     )).to be( true)
    expect(ua[:fr][:b2].key?(:corners  )).to be( true)
    expect(ua[:fr][:b2].key?(:balconies)).to be(false)
    expect(ua[:fr][:b2].key?(:grade    )).to be( true)
    expect(ua[:fr][:b2].key?(:other    )).to be( true)

    expect(ua[:en].key?(:b1)            ).to be( true)
    expect(ua[:en][:b1].empty?          ).to be(false)
    expect(ua[:en][:b1].key?(:summary  )).to be( true)
    expect(ua[:en][:b1].key?(:walls    )).to be( true)
    expect(ua[:en][:b1].key?(:roofs    )).to be(false)
    expect(ua[:en][:b1].key?(:floors   )).to be(false)
    expect(ua[:en][:b1].key?(:doors    )).to be( true)
    expect(ua[:en][:b1].key?(:windows  )).to be( true)
    expect(ua[:en][:b1].key?(:skylights)).to be(false)
    expect(ua[:en][:b1].key?(:rimjoists)).to be( true)
    expect(ua[:en][:b1].key?(:parapets )).to be(false)
    expect(ua[:en][:b1].key?(:trim     )).to be( true)
    expect(ua[:en][:b1].key?(:corners  )).to be( true)
    expect(ua[:en][:b1].key?(:balconies)).to be(false)
    expect(ua[:en][:b1].key?(:grade    )).to be( true)
    expect(ua[:en][:b1].key?(:other    )).to be(false)

    expect(ua[:en].key?(:b2)            ).to be( true)
    expect(ua[:en][:b2].empty?          ).to be(false)
    expect(ua[:en][:b2].key?(:summary  )).to be( true)
    expect(ua[:en][:b2].key?(:walls    )).to be( true)
    expect(ua[:en][:b2].key?(:roofs    )).to be( true)
    expect(ua[:en][:b2].key?(:floors   )).to be(false)
    expect(ua[:en][:b2].key?(:doors    )).to be( true)
    expect(ua[:en][:b2].key?(:windows  )).to be(false)
    expect(ua[:en][:b2].key?(:skylights)).to be( true)
    expect(ua[:en][:b2].key?(:rimjoists)).to be( true)
    expect(ua[:en][:b2].key?(:parapets )).to be( true)
    expect(ua[:en][:b2].key?(:trim     )).to be( true)
    expect(ua[:en][:b2].key?(:corners  )).to be( true)
    expect(ua[:en][:b2].key?(:balconies)).to be(false)
    expect(ua[:en][:b2].key?(:grade    )).to be( true)
    expect(ua[:en][:b2].key?(:other    )).to be( true)

    ud_md_en = TBD.ua_md(ua, :en)
    path     = File.join(__dir__, "files/ua/ua_en.md")

    File.open(path, "w") { |file| file.puts ud_md_en }

    ud_md_fr = TBD.ua_md(ua, :fr)
    path     = File.join(__dir__, "files/ua/ua_fr.md")

    File.open(path, "w") { |file| file.puts ud_md_fr }

    # Try with an incomplete reference, e.g. (non thermal bridging).
    TBD.clean!
    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
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

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    argh[:io      ] = json[:io      ]
    argh[:surfaces] = json[:surfaces]

    expect(TBD.status.zero?).to be(true)
    expect(TBD.logs.empty? ).to be(true)

    expect(argh[:surfaces  ].nil?        ).to be(false)
    expect(argh[:surfaces  ].is_a?(Hash) ).to be( true)
    expect(argh[:surfaces  ].size        ).to eq(   23)
    expect(argh[:io        ].nil?        ).to be(false)
    expect(argh[:io        ].is_a?(Hash) ).to be( true)
    expect(argh[:io        ].empty?      ).to be(false)
    expect(argh[:io        ].key?(:edges)).to be( true)
    expect(argh[:io][:edges].size        ).to eq(  300)

    # Testing summaries function.
    argh[:io][:description] = "testing non thermal bridging"

    ua = TBD.ua_summary(Time.now, argh)
    expect(ua.nil?        ).to be(false)
    expect(ua.empty?      ).to be(false)
    expect(ua.is_a?(Hash) ).to be( true)
    expect(ua.key?(:model)).to be( true)

    en_ud_md = TBD.ua_md(ua, :en)
    path     = File.join(__dir__, "files/ua/en_ua.md")

    File.open(path, "w") { |file| file.puts en_ud_md  }

    fr_ud_md = TBD.ua_md(ua, :fr)
    path     = File.join(__dir__, "files/ua/fr_ua.md")

    File.open(path, "w") { |file| file.puts fr_ud_md }
  end # KEEP

  it "can work off of a cloned model" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    argh1 = { option: "poor (BETBG)" }
    argh2 = { option: "poor (BETBG)" }
    argh3 = { option: "poor (BETBG)" }

    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get
    mdl   = model.clone
    fil   = File.join(__dir__, "files/osms/out/alt_warehouse.osm")
    mdl.save(fil, true)

    # Despite one being the clone of the other, files will not be identical,
    # namely due to unique handles.
    expect(FileUtils.identical?(file, fil)).to be(false)

    json = TBD.process(model, argh1)
    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    argh1[:io      ] = json[:io      ]
    argh1[:surfaces] = json[:surfaces]

    expect(TBD.status.zero?             ).to be( true)
    expect(TBD.logs.empty?              ).to be( true)
    expect(argh1[:surfaces].nil?        ).to be(false)
    expect(argh1[:surfaces].is_a?(Hash) ).to be( true)
    expect(argh1[:surfaces].size        ).to eq(   23)
    expect(argh1[:io      ].nil?        ).to be(false)
    expect(argh1[:io      ].is_a?(Hash) ).to be( true)
    expect(argh1[:io      ].empty?      ).to be(false)
    expect(argh1[:io      ].key?(:edges)).to be( true)
    expect(argh1[:io      ][:edges].size).to eq(  300)

    out  = JSON.pretty_generate(argh1[:io])
    outP = File.join(__dir__, "../json/tbd_warehouse12.out.json")
    File.open(outP, "w") { |outP| outP.puts out }

    TBD.clean!
    fil  = File.join(__dir__, "files/osms/out/alt_warehouse.osm")
    pth  = OpenStudio::Path.new(fil)
    mdl  = translator.loadModel(pth)
    expect(mdl.empty?).to be(false)
    mdl  = mdl.get
    json = TBD.process(mdl, argh2)

    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    argh2[:io      ] = json[:io      ]
    argh2[:surfaces] = json[:surfaces]

    expect(TBD.status.zero?               ).to be( true)
    expect(TBD.logs.empty?                ).to be( true)
    expect(argh2[:surfaces  ].nil?        ).to be(false)
    expect(argh2[:surfaces  ].is_a?(Hash) ).to be( true)
    expect(argh2[:surfaces  ].size        ).to eq(   23)
    expect(argh2[:io        ].nil?        ).to be(false)
    expect(argh2[:io        ].is_a?(Hash) ).to be( true)
    expect(argh2[:io        ].empty?      ).to be(false)
    expect(argh2[:io        ].key?(:edges)).to be( true)
    expect(argh2[:io][:edges].size        ).to eq(  300)

    out2  = JSON.pretty_generate(argh2[:io])
    outP2 = File.join(__dir__, "../json/tbd_warehouse13.out.json")
    File.open(outP2, "w") { |outP2| outP2.puts out2 }

    # The JSON output files are identical.
    expect(FileUtils.identical?(outP, outP2)).to be(true)
    time = Time.now

    # Original output UA' MD file.
    argh1[:ua_ref          ] = "code (Quebec)"
    argh1[:io][:description] = "testing equality"
    argh1[:version         ] = OpenStudio.openStudioVersion
    argh1[:seed            ] = File.join(__dir__, "files/osms/in/warehouse.osm")
    o_ua = TBD.ua_summary(time, argh1)
    expect(o_ua.nil?        ).to be(false)
    expect(o_ua.empty?      ).to be(false)
    expect(o_ua.is_a?(Hash) ).to be( true)
    expect(o_ua.key?(:model)).to be( true)

    o_ud_md_en = TBD.ua_md(o_ua, :en)
    path1      = File.join(__dir__, "files/ua/o_ua_en.md")
    File.open(path1, "w") { |file| file.puts o_ud_md_en }

    # Alternate output UA' MD file.
    argh2[:ua_ref          ] = "code (Quebec)"
    argh2[:io][:description] = "testing equality"
    argh2[:version         ] = OpenStudio.openStudioVersion
    argh2[:seed            ] = File.join(__dir__, "files/osms/in/warehouse.osm")
    alt_ua = TBD.ua_summary(time, argh2)
    expect(alt_ua.nil?        ).to be(false)
    expect(alt_ua.empty?      ).to be(false)
    expect(alt_ua.is_a?(Hash) ).to be( true)
    expect(alt_ua.key?(:model)).to be( true)

    alt_ud_md_en = TBD.ua_md(alt_ua, :en)
    path2        = File.join(__dir__, "files/ua/alt_ua_en.md")
    File.open(path2, "w") { |file| file.puts alt_ud_md_en }

    # Both output UA' MD files should be identical.
    expect(TBD.status.zero?).to be(true)
    expect(TBD.logs.empty? ).to be(true)

    expect(FileUtils.identical?(path1, path2)).to be(true)

    # Testing the Macumber solution.
    TBD.clean!
    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    mdl2 = OpenStudio::Model::Model.new
    mdl2.addObjects(model.toIdfFile.objects)
    fil2 = File.join(__dir__, "files/osms/out/alt2_warehouse.osm")
    mdl2.save(fil2, true)

    # Still get the differences in handles (not consequential at all if the TBD
    # JSON output files are identical).
    expect(FileUtils.identical?(file, fil2)).to be(false)

    json = TBD.process(mdl2, argh3)
    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    argh3[:io      ] = json[:io      ]
    argh3[:surfaces] = json[:surfaces]

    expect(TBD.status.zero?).to be(true)
    expect(TBD.logs.empty? ).to be(true)

    expect(argh3[:surfaces  ].nil?        ).to be(false)
    expect(argh3[:surfaces  ].is_a?(Hash) ).to be( true)
    expect(argh3[:surfaces  ].size        ).to eq(   23)
    expect(argh3[:io        ].nil?        ).to be(false)
    expect(argh3[:io        ].is_a?(Hash) ).to be( true)
    expect(argh3[:io        ].empty?      ).to be(false)
    expect(argh3[:io        ].key?(:edges)).to be( true)
    expect(argh3[:io][:edges].size        ).to eq(  300)

    out3  = JSON.pretty_generate(argh3[:io])
    outP3 = File.join(__dir__, "../json/tbd_warehouse14.out.json")
    File.open(outP3, "w") { |outP3| outP3.puts out3 }

    # Nice. Both TBD JSON output files are identical!
    # "/../json/tbd_warehouse12.out.json" vs "/../json/tbd_warehouse14.out.json"
    expect(FileUtils.identical?(outP, outP3)).to be(true)
  end # KEEP

  it "can generate and access KIVA inputs (seb)" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    argh            = {}
    argh[:option  ] = "poor (BETBG)"
    argh[:gen_kiva] = true

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
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
    expect(oa1f.empty?).to be(false)
    oa1f = oa1f.get

    expect(oa1f.setOutsideBoundaryCondition("Foundation")).to be(true)
    oa1f.setAdjacentFoundation(kiva_slab_2020s)
    construction = oa1f.construction
    expect(construction.empty?).to be(false)
    construction = construction.get
    expect(oa1f.setConstruction(construction)).to be(true)

    arg = "TotalExposedPerimeter"
    per = oa1f.createSurfacePropertyExposedFoundationPerimeter(arg, 12.59)
    expect(per.empty?).to be(false)

    file = File.join(__dir__, "files/osms/out/seb_KIVA.osm")
    model.save(file, true)

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Re-open for testing.
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    oa1f = model.getSurfaceByName("Open area 1 Floor")
    expect(oa1f.empty?).to be(false)
    oa1f = oa1f.get

    expect(oa1f.outsideBoundaryCondition.downcase).to eq("foundation")
    foundation = oa1f.adjacentFoundation
    expect(foundation.empty?).to be(false)
    foundation = foundation.get

    oa15 = model.getSurfaceByName("Openarea 1 Wall 5") # 3.89m wide
    expect(oa15.empty?).to be(false)
    oa15 = oa15.get

    construction = oa15.construction.get
    expect(oa15.setOutsideBoundaryCondition("Foundation")).to be(true)
    expect(oa15.setAdjacentFoundation(foundation)        ).to be(true)
    expect(oa15.setConstruction(construction)            ).to be(true)

    kfs = model.getFoundationKivas
    expect(kfs.empty?).to be(false)
    expect(kfs.size  ).to eq(    4)

    settings = model.getFoundationKivaSettings
    expect(settings.soilConductivity).to be_within(0.01).of(1.73)

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    io        = json[:io      ]
    surfaces  = json[:surfaces]

    expect(TBD.status.zero?    ).to be( true)
    expect(TBD.logs.empty?     ).to be( true)
    expect(surfaces.nil?       ).to be(false)
    expect(surfaces.is_a?(Hash)).to be( true)
    expect(surfaces.size       ).to eq(   56)
    expect(io.nil?             ).to be(false)
    expect(io.is_a?(Hash)      ).to be( true)
    expect(io.empty?           ).to be(false)

    found_floor = false
    found_wall  = false

    surfaces.each do |id, surface|
      next unless surface.key?(:kiva)
      expect(id).to eq("Open area 1 Floor").or eq("Openarea 1 Wall 5")

      if id == "Open area 1 Floor"
        expect(surface[:kiva        ]).to eq(:basement)
        expect(surface.key?(:exposed)).to be(true)
        expect(surface[:exposed     ]).to be_within(0.01).of(8.70) # 12.6 - 3.9
        found_floor = true
      else
        expect(surface[:kiva        ]).to eq("Open area 1 Floor")
        found_wall = true
      end
    end

    expect(found_floor).to be(true)
    expect(found_wall ).to be(true)

    file = File.join(__dir__, "files/osms/out/seb_KIVA2.osm")
    model.save(file, true)

    # --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- --- #
    # Re-open & test initial model.
    TBD.clean!
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    model.getSurfaces.each do |s|
      next unless s.isGroundSurface
      next unless s.surfaceType.downcase == "floor"

      expect(s.setOutsideBoundaryCondition("Foundation")).to be(true)
    end

    argh            = {}
    argh[:option  ] = "(non thermal bridging)"
    argh[:gen_kiva] = true

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)

    io        = json[:io      ]
    surfaces  = json[:surfaces]
    expect(TBD.status.zero?    ).to be( true)
    expect(TBD.logs.empty?     ).to be( true)
    expect(surfaces.nil?       ).to be(false)
    expect(surfaces.is_a?(Hash)).to be( true)
    expect(surfaces.size       ).to eq(   56)
    expect(io.nil?             ).to be(false)
    expect(io.is_a?(Hash)      ).to be( true)
    expect(io.empty?           ).to be(false)

    surfaces.each do |id, s|
      next unless s.key?(:kiva)

      expect(s.key?(:exposed)).to be( true)
      slab = model.getSurfaceByName(id)
      expect(slab.empty?).to be(false)
      slab = slab.get

      expect(slab.adjacentFoundation.empty?).to be(false)
      perimeter = slab.surfacePropertyExposedFoundationPerimeter
      expect(perimeter.empty?).to be(false)
      perimeter = perimeter.get

      per = perimeter.totalExposedPerimeter
      expect(per.empty?).to be(false)
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

    argh  = {}
    file  = File.join(__dir__, "files/osms/in/midrise.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    argh[:option  ] = "poor (BETBG)"
    argh[:gen_kiva] = true

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)).to be(true)
    expect(json.key?(:io)).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to eq(0)
    expect(TBD.logs.empty?).to be(true)
    expect(io.nil?).to be(false)
    expect(io.is_a?(Hash)).to be(true)
    expect(io.empty?).to be(false)
    expect(surfaces.nil?).to be(false)
    expect(surfaces.is_a?(Hash)).to be(true)
    expect(surfaces.size).to eq(180)

    # Validate.
    surfaces.each do |id, surface|
      next unless surface.key?(:foundation) # ... only floors
      next unless surface.key?(:kiva)

      expect(surface[:kiva]).to eq(:slab)
      expect(surface.key?(:exposed)).to be(true)
      expect(id).to eq("g Floor C")
      expect(surface[:exposed]).to be_within(TOL).of(3.36)
      gFC = model.getSurfaceByName("g Floor C")
      expect(gFC.empty?).to be(false)
      gFC = gFC.get
      expect(gFC.outsideBoundaryCondition.downcase).to eq("foundation")
    end

    file = File.join(__dir__, "files/osms/out/midrise_KIVA.osm")
    model.save(file, true)
  end

  it "can test 5ZoneNoHVAC (failed) uprating" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    argh  = { option: "efficient (BETBG)" } # all PSI factors @ 0.2 W/K.m
    walls = []
    id    = "ASHRAE 189.1-2009 ExtWall Mass ClimateZone 5"
    file  = File.join(__dir__, "files/osms/in/5ZoneNoHVAC.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    # Get geometry data for testing (4x exterior walls, same construction).
    construction = nil

    model.getSurfaces.each do |s|
      next unless s.surfaceType == "Wall"
      next unless s.outsideBoundaryCondition == "Outdoors"

      walls << s.nameString
      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_LayeredConstruction
      expect(c.empty?).to be(false)
      c = c.get

      construction = c if construction.nil?
      expect(c).to eq(construction)
    end

    expect(walls.size              ).to eq( 4)
    expect(construction.nameString ).to eq(id)
    expect(construction.layers.size).to eq( 4)

    insulation = construction.layers[2].to_StandardOpaqueMaterial
    expect(insulation.empty?).to be(false)
    insulation = insulation.get
    expect(insulation.thickness).to be_within(0.0001).of(0.0794)
    expect(insulation.thermalConductivity).to be_within(0.0001).of(0.0432)
    original_r = insulation.thickness / insulation.thermalConductivity
    expect(original_r).to be_within(TOL).of(1.8380)

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status.zero?).to be(true)
    expect(TBD.logs.empty? ).to be(true)

    walls.each do |wall|
      expect(surfaces.key?(wall)           ).to be(true)
      expect(surfaces[wall].key?(:heatloss)).to be(true)

      long  = (surfaces[wall][:heatloss] - 27.746).abs < TOL # 40 metres wide
      short = (surfaces[wall][:heatloss] - 14.548).abs < TOL # 20 metres wide
      expect(long || short).to be(true)
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
    argh                = {}
    argh[:option      ] = "efficient (BETBG)" # all PSI factors @ 0.2 W/K.m
    argh[:uprate_walls] = true
    argh[:uprate_roofs] = true
    argh[:wall_option ] = "ALL wall constructions"
    argh[:roof_option ] = "ALL roof constructions"
    argh[:wall_ut     ] = 0.210 # NECB CZ7 2017 (RSi 4.76 / R27)
    argh[:roof_ut     ] = 0.138 # NECB CZ7 2017 (RSi 7.25 / R41)

    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash    )).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)

    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.error?     ).to be( true)
    expect(TBD.logs.empty?).to be(false)
    expect(TBD.logs.size  ).to eq(    2)

    expect(TBD.logs.first[:message].include?("Zero")            ).to be(true)
    expect(TBD.logs.first[:message].include?(": new Rsi")       ).to be(true)
    expect(TBD.logs.last[ :message].include?("Unable to uprate")).to be(true)

    expect(argh.key?(:wall_uo)).to be(false)
    expect(argh.key?(:roof_uo)).to be( true)
    expect(argh[:roof_uo].nil?).to be(false)
    expect(argh[:roof_uo]     ).to be_within(TOL).of(0.118) # RSi 8.47 (R48)

    # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
    # Final attempt, with PSI factors of 0.09 W/K per linear metre (JSON file).
    TBD.clean!
    argh                = {}
    argh[:io_path     ] = File.join(__dir__, "../json/tbd_5ZoneNoHVAC.json")
    argh[:schema_path ] = File.join(__dir__, "../tbd.schema.json")
    argh[:uprate_walls] = true
    argh[:uprate_roofs] = true
    argh[:wall_option ] = "ALL wall constructions"
    argh[:roof_option ] = "ALL roof constructions"
    argh[:wall_ut     ] = 0.210 # NECB CZ7 2017 (RSi 4.76 / R27)
    argh[:roof_ut     ] = 0.138 # NECB CZ7 2017 (RSi 7.25 / R41)

    walls = []
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)

    io        = json[:io      ]
    surfaces  = json[:surfaces]
    expect(TBD.status.zero?   ).to be( true)
    expect(argh.key?(:wall_uo)).to be( true)
    expect(argh.key?(:roof_uo)).to be( true)
    expect(argh[:wall_uo].nil?).to be(false)
    expect(argh[:roof_uo].nil?).to be(false)

    expect(argh[:wall_uo]).to be_within(TOL).of(0.086) # RSi 11.63 (R66)
    expect(argh[:roof_uo]).to be_within(TOL).of(0.129) # RSi  7.75 (R44)

    model.getSurfaces.each do |s|
      next unless s.surfaceType == "Wall"
      next unless s.outsideBoundaryCondition == "Outdoors"

      walls << s.nameString
      c = s.construction
      expect(c.empty?).to be(false)
      c = c.get.to_LayeredConstruction
      expect(c.empty?).to be(false)
      c = c.get

      expect(c.nameString.include?(" c tbd")).to be(true)
      expect(c.layers.size                  ).to eq(   4)

      insul = c.layers[2].to_StandardOpaqueMaterial
      expect(insul.empty?).to be(false)
      insul = insul.get
      expect(insul.nameString.include?(" uprated m tbd")).to be(true)

      expect(insul.thermalConductivity).to be_within(0.0001).of(0.0432)
      th1 = (insul.thickness - 0.191).abs < 0.001 # derated layer Rsi 4.42
      th2 = (insul.thickness - 0.186).abs < 0.001 # derated layer Rsi 4.31
      expect(th1 || th2).to be(true) # depending if 'short' or 'long' walls
    end

    walls.each do |wall|
      expect(surfaces.key?(wall)).to be(true)
      # r: uprated, non-derated layer Rsi
      # u: uprated, non-derated assembly
      expect(surfaces[wall].key?(:r)).to be(true)
      expect(surfaces[wall].key?(:u)).to be(true)

      expect(surfaces[wall][:r]).to be_within(0.001).of(11.205) # R64
      expect(surfaces[wall][:u]).to be_within(0.001).of( 0.086) # R66
    end

    # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
    # Realistic, BTAP-costed PSI factors.
    TBD.clean!
    jpath = "../json/tbd_5ZoneNoHVAC_btap.json"

    argh                = {}
    argh[:io_path     ] = File.join(__dir__, jpath)
    argh[:schema_path ] = File.join(__dir__, "../tbd.schema.json")
    argh[:uprate_walls] = true
    argh[:wall_option ] = "ALL wall constructions"
    argh[:wall_ut     ] = 0.210 # NECB CZ7 2017 (RSi 4.76 / R41)

    file  = File.join(__dir__, "files/osms/in/5ZoneNoHVAC.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    # Assign (missing) space types.
    north = model.getSpaceByName("Story 1 North Perimeter Space")
    east  = model.getSpaceByName("Story 1 East Perimeter Space" )
    south = model.getSpaceByName("Story 1 South Perimeter Space")
    west  = model.getSpaceByName("Story 1 West Perimeter Space" )
    core  = model.getSpaceByName("Story 1 Core Space"           )

    expect(north.empty?).to be(false)
    expect(east.empty? ).to be(false)
    expect(south.empty?).to be(false)
    expect(west.empty? ).to be(false)
    expect(core.empty? ).to be(false)

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

    audience.setName("Audience - auditorium" )
    warehouse.setName("Warehouse - fine"     )
    offices.setName("Office - enclosed"      )
    sales.setName("Sales area"               )
    workshop.setName("Workshop space"        )

    expect(north.setSpaceType(audience )).to be(true)
    expect( east.setSpaceType(warehouse)).to be(true)
    expect(south.setSpaceType(offices  )).to be(true)
    expect( west.setSpaceType(sales    )).to be(true)
    expect( core.setSpaceType(workshop )).to be(true)

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)

    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(argh.key?(:roof_uo)).to be(false)

    # OpenStudio prior to v3.5.X had a 3m maximum layer thickness, reflecting a
    # previous v8.8 EnergyPlus constraint. TBD caught such cases when uprating
    # (as per NECB requirements). From v3.5.0+, OpenStudio dropped the maximum
    # layer thickness limit, harmonizing with EnergyPlus:
    #
    #   https://github.com/NREL/OpenStudio/pull/4622
    if OpenStudio.openStudioVersion.split(".").join.to_i < 350
      expect(TBD.error?     ).to be( true)
      expect(TBD.logs.empty?).to be(false)
      expect(TBD.logs.size  ).to eq(    2)

      expect(TBD.logs.first[:message].include?("Invalid"        )).to be(true)
      expect(TBD.logs.first[:message].include?("Can't uprate "  )).to be(true)
      expect(TBD.logs.last[:message].include?("Unable to uprate")).to be(true)

      expect(argh.key?(:wall_uo)).to be(false)
    else
      expect(TBD.status.zero?).to be(true)
      expect(argh.key?(:wall_uo)).to be(true)
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
    expect(model.empty?).to be(false)
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

    argh                = {}
    argh[:option      ] = "(non thermal bridging)"
    argh[:io_path     ] = input
    argh[:schema_path ] = File.join(__dir__, "../tbd.schema.json")

    # Export to file. Both files should be the same.
    out     = JSON.pretty_generate(input)
    pth     = File.join(__dir__, "../json/tbd_seb_n2.out.json")
    File.open(pth, "w") { |pth| pth.puts out }
    initial = File.join(__dir__, "../json/tbd_seb_n2.json")
    expect(FileUtils.identical?(initial, pth)).to be(true)

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)

    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status.zero?    ).to be( true)
    expect(TBD.logs.empty?     ).to be( true)
    expect(io.nil?             ).to be(false)
    expect(io.is_a?(Hash)      ).to be( true)
    expect(io.empty?           ).to be(false)
    expect(surfaces.nil?       ).to be(false)
    expect(surfaces.is_a?(Hash)).to be( true)
    expect(surfaces.size       ).to eq(   56)

    surfaces.values.each do |surface|
      next unless surface.key?(:ratio)

      expect(surface[:heatloss]).to be_within(0.01).of(3.5)
    end
  end # KEEP

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
    #   - 'heatingTemperatureSetpoints?': ANY space holds heating setpoints?
    #   - 'coolingTemperatureSetpoints?': ANY space holds cooling setpoints?
    #
    # Users can consult the online OSut API documentation to know more.

    # Small office test case (UNCONDITIONED attic).
    argh  = { option: "code (Quebec)" }
    file  = File.join(__dir__, "files/osms/in/smalloffice.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get
    attic = model.getSpaceByName("Attic")
    expect(attic.empty?).to be(false)
    attic = attic.get

    model.getSpaces.each do |space|
      next if space == attic

      zone = space.thermalZone
      expect(zone.empty?).to be(false)
      zone = zone.get
      heat = TBD.maxHeatScheduledSetpoint(zone)
      cool = TBD.minCoolScheduledSetpoint(zone)

      expect(heat[:spt]).to be_within(TOL).of(21.11)
      expect(cool[:spt]).to be_within(TOL).of(23.89)
      expect(heat[:dual]).to be(true)
      expect(cool[:dual]).to be(true)

      expect(space.partofTotalFloorArea).to be(true)
      expect(TBD.plenum?(space)).to be(false)
      expect(TBD.unconditioned?(space)).to be(false)
      expect(TBD.setpoints(space)[:heating]).to be_within(TOL).of(21.11)
      expect(TBD.setpoints(space)[:cooling]).to be_within(TOL).of(23.89)
    end

    zone = attic.thermalZone
    expect(zone.empty?).to be(false)
    zone = zone.get
    heat = TBD.maxHeatScheduledSetpoint(zone)
    cool = TBD.minCoolScheduledSetpoint(zone)

    expect(heat[:spt].nil?).to be(true)
    expect(cool[:spt].nil?).to be(true)
    expect(heat[:dual]).to be(false)
    expect(cool[:dual]).to be(false)

    expect(TBD.plenum?(attic)).to be(false)
    expect(TBD.unconditioned?(attic)).to be(true)
    expect(TBD.setpoints(attic)[:heating].nil?).to be(true)
    expect(TBD.setpoints(attic)[:cooling].nil?).to be(true)
    expect(attic.partofTotalFloorArea).to be(false)
    expect(TBD.status.zero?).to be(true)

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)

    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(surfaces.nil?       ).to be(false)
    expect(surfaces.is_a?(Hash)).to be( true)
    expect(surfaces.size       ).to eq(   43)
    expect(TBD.status.zero?    ).to be( true)

    surfaces.each do |id, surface|
      next unless id.include?("_roof_")

      expect(id.include?("Attic")).to be(true)
      expect(surface.key?(:conditioned)).to be(true)
      expect(surface.key?(:deratable)).to be(true)
      expect(surface.key?(:ratio)).to be(false)
      expect(surface[:conditioned]).to be(false)
      expect(surface[:deratable]).to be(false)
    end

    # Now tag attic as an INDIRECTLYCONDITIONED space (linked to "Core_ZN").
    argh  = { option: "code (Quebec)" }
    file  = File.join(__dir__, "files/osms/in/smalloffice.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get
    attic = model.getSpaceByName("Attic")
    expect(attic.empty?).to be(false)
    attic = attic.get

    key = "indirectlyconditioned"
    val = "Core_ZN"
    expect(attic.additionalProperties.setFeature(key, val)).to be(true)
    expect(TBD.plenum?(attic)).to be(false)
    expect(TBD.unconditioned?(attic)).to be(false)
    expect(TBD.setpoints(attic)[:heating]).to be_within(TOL).of(21.11)
    expect(TBD.setpoints(attic)[:cooling]).to be_within(TOL).of(23.89)
    expect(TBD.status.zero?).to be(true)

    json = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)

    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(surfaces.nil?       ).to be(false)
    expect(surfaces.is_a?(Hash)).to be( true)
    expect(surfaces.size       ).to eq(   43)
    expect(TBD.status.zero?    ).to be( true)

    surfaces.each do |id, surface|
      next unless id.include?("_roof_")

      expect(id.include?("Attic")).to be(true)
      expect(surface.key?(:conditioned)).to be(true)
      expect(surface.key?(:deratable)).to be(true)
      expect(surface.key?(:ratio)).to be(true)
      expect(surface[:conditioned]).to be(true)
      expect(surface[:deratable]).to be(true)
    end

    expect(attic.additionalProperties.resetFeature(key)).to be(true)

    # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
    # The following variations of the 'FullServiceRestaurant' (v3.2.1) are
    # snapshots of incremental development of the same model. For each step,
    # the tests illustrate how TBD ends up considering the unoccupied space
    # (below roof) and sometimes show how simple variable changes allow users
    # to switch from UNCONDITIONED to INDIRECTLYCONDITIONED (or vice versa).
    unless OpenStudio.openStudioVersion.split(".").join.to_i < 321
      TBD.clean!

      # Unaltered template OpenStudio model:
      #   - constructions: NO
      #   - setpoints    : NO
      #   - HVAC         : NO
      argh  = { option: "code (Quebec)" }
      file  = File.join(__dir__, "files/osms/in/resto1.osm")
      path  = OpenStudio::Path.new(file)
      model = translator.loadModel(path)
      expect(model.empty?).to be(false)
      model = model.get
      attic = model.getSpaceByName("Attic")
      expect(attic.empty?).to be(false)
      attic = attic.get

      expect(model.getConstructions.empty?).to be(true)
      heated = TBD.heatingTemperatureSetpoints?(model)
      cooled = TBD.coolingTemperatureSetpoints?(model)
      expect(heated).to be(false)
      expect(cooled).to be(false)

      json = TBD.process(model, argh)
      expect(json.is_a?(Hash)    ).to be( true)
      expect(json.key?(:io      )).to be( true)
      expect(json.key?(:surfaces)).to be( true)

      io       = json[:io      ]
      surfaces = json[:surfaces]
      expect(surfaces.nil?       ).to be(false)
      expect(surfaces.is_a?(Hash)).to be( true)
      expect(surfaces.size       ).to eq(   18)
      expect(TBD.error?          ).to be( true)
      expect(TBD.logs.empty?     ).to be(false)

      TBD.logs.each do |log|
        msg     = log[:message]
        invalid = msg.include?("missing") || msg.include?("layer?")
        expect(invalid).to be(true)
      end

      expect(io.nil?        ).to be(false)
      expect(io.is_a?(Hash) ).to be( true)
      expect(io.empty?      ).to be(false)
      expect(io.key?(:edges)).to be(false)

      # As the model doesn't hold any constructions, TBD skips over any
      # derating steps. Yet despite the OpenStudio model not holding ANY valid
      # heating or cooling setpoints, ALL spaces are considered CONDITIONED.
      surfaces.values.each do |surface|
        expect(surface.is_a?(Hash)        ).to be( true)
        expect(surface.key?(:space       )).to be( true)
        expect(surface.key?(:stype       )).to be( true) # spacetype
        expect(surface.key?(:conditioned )).to be( true)
        expect(surface.key?(:deratable   )).to be( true)
        expect(surface.key?(:construction)).to be(false)
        expect(surface[:conditioned      ]).to be( true) # even attic
        expect(surface[:deratable        ]).to be(false) # no constructions!
      end

      # OSut correctly report spaces here as UNCONDITIONED. Tagging ALL spaces
      # instead as CONDITIONED in such (rare) cases is unique to TBD.
      id    = "attic-floor-dinning"
      expect(surfaces.key?(id)         ).to be( true)
      attic = surfaces[id][:space]
      heat  = TBD.setpoints(attic)[:heating]
      cool  = TBD.setpoints(attic)[:cooling]
      expect(TBD.unconditioned?(attic) ).to be( true)
      expect(heat.nil?                 ).to be( true)
      expect(cool.nil?                 ).to be( true)
      expect(attic.partofTotalFloorArea).to be(false)
      expect(attic.thermalZone.empty?  ).to be(false)
      zone  = attic.thermalZone.get
      expect(zone.isPlenum             ).to be(false)
      expect(TBD.plenum?(attic)        ).to be(false)


      # - ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- - #
      # A more developed 'FullServiceRestaurant' (midway BTAP generation):
      #   - constructions: YES
      #   - setpoints    : YES
      #   - HVAC         : NO
      TBD.clean!
      argh                = {}
      argh[:option      ] = "efficient (BETBG)"
      argh[:uprate_roofs] = true
      argh[:roof_option ] = "ALL roof constructions"
      argh[:roof_ut     ] = 0.138 # NECB CZ7 2017 (RSi 7.25 / R41)

      file  = File.join(__dir__, "files/osms/in/resto2.osm")
      path  = OpenStudio::Path.new(file)
      model = translator.loadModel(path)
      expect(model.empty?).to be(false)
      model = model.get

      # BTAP-set (interior) ceiling constructions (i.e. attic/plenum floors)
      # are characteristic of occupied floors (e.g. carpet over 4" concrete
      # slab). Clone/assign insulated roof construction to plenum/attic floors.
      set = model.getBuilding.defaultConstructionSet
      expect(set.empty?).to be(false)
      set = set.get

      interiors = set.defaultInteriorSurfaceConstructions
      exteriors = set.defaultExteriorSurfaceConstructions
      expect(interiors.empty?).to be(false)
      expect(exteriors.empty?).to be(false)
      interiors = interiors.get
      exteriors = exteriors.get
      roofs     = exteriors.roofCeilingConstruction
      expect(roofs.empty?).to be(false)
      roofs     = roofs.get
      insulated = roofs.clone(model).to_LayeredConstruction
      expect(insulated.empty?).to be(false)
      insulated = insulated.get
      insulated.setName("Insulated Attic Floors")
      expect(interiors.setRoofCeilingConstruction(insulated)).to be(true)

      # Validate re-assignment via individual attic floor surfaces.
      construction = nil
      ceilings     = []

      model.getSurfaces.each do |s|
        next unless s.surfaceType == "RoofCeiling"
        next unless s.outsideBoundaryCondition == "Surface"

        ceilings << s.nameString
        c = s.construction
        expect(c.empty?).to be(false)
        c = c.get.to_LayeredConstruction
        expect(c.empty?).to be(false)
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
      expect(model.getConstructions.empty?).to be(false)
      heated = TBD.heatingTemperatureSetpoints?(model)
      cooled = TBD.coolingTemperatureSetpoints?(model)
      expect(heated).to be(true)
      expect(cooled).to be(true)

      attic = model.getSpaceByName("attic")
      expect(attic.empty?).to be(false)
      attic = attic.get

      expect(attic.partofTotalFloorArea).to be(false)
      heat = TBD.setpoints(attic)[:heating]
      cool = TBD.setpoints(attic)[:cooling]
      expect(heat.nil?                 ).to be( true)
      expect(cool.nil?                 ).to be( true)

      expect(TBD.plenum?(attic)        ).to be(false)
      expect(attic.partofTotalFloorArea).to be(false)
      expect(attic.thermalZone.empty?  ).to be(false)
      zone = attic.thermalZone.get
      expect(zone.isPlenum             ).to be(false)

      tstat = zone.thermostat
      expect(tstat.empty?).to be(false)
      tstat = tstat.get
      expect(tstat.to_ThermostatSetpointDualSetpoint.empty?).to be(false)
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get

      expect(tstat.getHeatingSchedule.empty?).to be(true)
      expect(tstat.getCoolingSchedule.empty?).to be(true)
      heat = TBD.maxHeatScheduledSetpoint(zone)
      cool = TBD.minCoolScheduledSetpoint(zone)

      expect(heat.nil?       ).to be(false)
      expect(cool.nil?       ).to be(false)
      expect(heat.is_a?(Hash)).to be( true)
      expect(cool.is_a?(Hash)).to be( true)
      expect(heat.key?(:spt) ).to be( true)
      expect(cool.key?(:spt) ).to be( true)
      expect(heat.key?(:dual)).to be( true)
      expect(cool.key?(:dual)).to be( true)
      expect(heat[:spt ].nil?).to be( true)
      expect(cool[:spt ].nil?).to be( true)
      expect(heat[:dual]     ).to be(false)
      expect(cool[:dual]     ).to be(false)
      # The unoccupied space does not reference valid heating and/or cooling
      # temperature setpoint objects, and is therefore considered
      # UNCONDITIONED. Save for next iteration.
      file = File.join(__dir__, "files/osms/out/resto2a.osm")
      model.save(file, true)

      json = TBD.process(model, argh)
      expect(json.is_a?(Hash)    ).to be( true)
      expect(json.key?(:io)      ).to be( true)
      expect(json.key?(:surfaces)).to be( true)

      io       = json[:io      ]
      surfaces = json[:surfaces]
      expect(TBD.error?          ).to be(false)
      expect(surfaces.nil?       ).to be(false)
      expect(surfaces.is_a?(Hash)).to be( true)
      expect(surfaces.size       ).to eq(   18)
      expect(io.nil?             ).to be(false)
      expect(io.is_a?(Hash)      ).to be( true)
      expect(io.empty?           ).to be(false)
      expect(io.key?(:edges)     ).to be( true)
      expect(argh.key?(:wall_uo) ).to be(false)
      expect(argh.key?(:roof_uo) ).to be( true)
      expect(argh[:roof_uo]      ).to be_within(TOL).of(0.119)

      # Validate ceiling surfaces (both insulated & uninsulated).
      ua = 0.0
      a  = 0.0

      surfaces.each do |nom, surface|
        expect(surface.is_a?(Hash)        ).to be(true)
        expect(surface.key?(:conditioned )).to be(true)
        expect(surface.key?(:deratable   )).to be(true)
        expect(surface.key?(:construction)).to be(true)
        expect(surface.key?(:ground      )).to be(true)
        expect(surface.key?(:type        )).to be(true)
        next     if surface[:ground]
        next unless surface[:type  ] == :ceiling

        # Sloped attic roof surfaces ignored by TBD.
        id = surface[:construction].nameString
        expect(nom.include?("-roof")   ).to be( true) unless surface[:deratable]
        expect(id.include?("BTAP-Ext-")).to be( true) unless surface[:deratable]
        expect(surface[:conditioned]   ).to be(false) unless surface[:deratable]
        next unless surface[:deratable]
        next unless surface.key?(:heatloss)

        # Leaves only insulated attic ceilings.
        expect(id).to eq("Insulated Attic Floors") # original construction
        s = model.getSurfaceByName(nom)
        expect(s.empty?).to be(false)
        s = s.get
        c = s.construction
        expect(c.empty?).to be(false)
        c = c.get.to_LayeredConstruction
        expect(c.empty?).to be(false)
        c = c.get
        expect(c.nameString.include?("c tbd")).to be(true) # TBD-derated
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
      argh   = { option: "code (Quebec)" }
      file   = File.join(__dir__, "files/osms/out/resto2a.osm")
      path   = OpenStudio::Path.new(file)
      model  = translator.loadModel(path)
      expect(model.empty?).to be(false)
      model  = model.get
      heated = TBD.heatingTemperatureSetpoints?(model)
      cooled = TBD.coolingTemperatureSetpoints?(model)
      expect(model.getConstructions.empty?).to be(false)
      expect(heated).to be(true)
      expect(cooled).to be(true)

      # In this iteration, ensure the unoccupied space is considered as an
      # INDIRECTLYCONDITIONED plenum (instead of an UNCONDITIONED attic), by
      # temporarily adding a heating dual setpoint schedule object to its zone
      # thermostat (yet without valid scheduled temperatures).
      attic = model.getSpaceByName("attic")
      expect(attic.empty?              ).to be(false)
      attic = attic.get
      expect(attic.partofTotalFloorArea).to be(false)
      expect(attic.thermalZone.empty?  ).to be(false)
      zone  = attic.thermalZone.get
      expect(zone.isPlenum             ).to be(false)
      tstat = zone.thermostat
      expect(tstat.empty?              ).to be(false)
      tstat = tstat.get

      expect(tstat.to_ThermostatSetpointDualSetpoint.empty?).to be(false)
      tstat = tstat.to_ThermostatSetpointDualSetpoint.get

      # Before the addition.
      expect(tstat.getHeatingSchedule.empty?).to be(true)
      expect(tstat.getCoolingSchedule.empty?).to be(true)

      heat  = TBD.maxHeatScheduledSetpoint(zone)
      cool  = TBD.minCoolScheduledSetpoint(zone)
      stpts = TBD.setpoints(attic)

      expect(heat.nil?       ).to be(false)
      expect(cool.nil?       ).to be(false)
      expect(heat.is_a?(Hash)).to be( true)
      expect(cool.is_a?(Hash)).to be( true)
      expect(heat.key?(:spt )).to be( true)
      expect(cool.key?(:spt )).to be( true)
      expect(heat.key?(:dual)).to be( true)
      expect(cool.key?(:dual)).to be( true)
      expect(heat[:spt ].nil?).to be( true)
      expect(cool[:spt ].nil?).to be( true)
      expect(heat[:dual]     ).to be(false)
      expect(cool[:dual]     ).to be(false)

      expect(stpts[:heating].nil?).to be(true)
      expect(stpts[:cooling].nil?).to be(true)
      expect(TBD.unconditioned?(attic)).to be(true)
      expect(TBD.plenum?(attic)).to be(false)

      # Add a dual setpoint temperature schedule.
      identifier = "TEMPORARY attic setpoint schedule"
      sched = OpenStudio::Model::ScheduleCompact.new(model)
      sched.setName(identifier)
      expect(sched.constantValue.empty?                        ).to be(true)
      expect(tstat.setHeatingSetpointTemperatureSchedule(sched)).to be(true)

      # After the addition.
      expect(tstat.getHeatingSchedule.empty?).to be(false)
      expect(tstat.getCoolingSchedule.empty?).to be( true)
      heat  = TBD.maxHeatScheduledSetpoint(zone)
      stpts = TBD.setpoints(attic)

      expect(heat.nil?       ).to be(false)
      expect(heat.is_a?(Hash)).to be( true)
      expect(heat.key?(:spt )).to be( true)
      expect(heat.key?(:dual)).to be( true)
      expect(heat[:spt ].nil?).to be( true)
      expect(heat[:dual]     ).to be( true)
      expect(stpts[:heating]).to be_within(TOL).of(21.0)
      expect(stpts[:cooling]).to be_within(TOL).of(24.0)

      expect(TBD.unconditioned?(attic)).to be(false)
      expect(TBD.plenum?(attic)).to be(true) # works ...

      json  = TBD.process(model, argh)
      expect(json.is_a?(Hash)    ).to be( true)
      expect(json.key?(:io      )).to be( true)
      expect(json.key?(:surfaces)).to be( true)

      io       = json[:io      ]
      surfaces = json[:surfaces]
      expect(TBD.error?          ).to be( true)
      expect(TBD.logs.empty?     ).to be(false)

      # The incomplete (temporary) schedule triggers a non-FATAL TBD error.
      TBD.logs.each do |log|
        expect(log[:message].include?("Empty '"                 )).to be(true)
        expect(log[:message].include?("::scheduleCompactMinMax)")).to be(true)
      end

      expect(surfaces.nil?       ).to be(false)
      expect(surfaces.is_a?(Hash)).to be( true)
      expect(surfaces.size       ).to eq(   18)
      expect(io.nil?             ).to be(false)
      expect(io.is_a?(Hash)      ).to be( true)
      expect(io.empty?           ).to be(false)
      expect(io.key?(:edges     )).to be( true)

      surfaces.each do |nom, surface|
        expect(surface.is_a?(Hash)        ).to be(true)
        expect(surface.key?(:conditioned )).to be(true)
        expect(surface.key?(:deratable   )).to be(true)
        expect(surface.key?(:construction)).to be(true)
        expect(surface.key?(:ground      )).to be(true)
        expect(surface.key?(:type        )).to be(true)
        next unless surface[:type] == :ceiling

        # Sloped attic roof surfaces no longer ignored by TBD.
        id = surface[:construction].nameString
        expect(nom.include?("-roof")   ).to be( true)     if surface[:deratable]
        expect(id.include?("BTAP-Ext-")).to be( true)     if surface[:deratable]
        expect(surface[:conditioned]   ).to be( true)     if surface[:deratable]
        expect(nom.include?("_Ceiling")).to be( true) unless surface[:deratable]
        expect(surface[:conditioned]   ).to be( true) unless surface[:deratable]
        next unless surface[:deratable]
        next unless surface.key?(:heatloss)

        # Leaves only insulated attic ceilings.
        expect(id).to eq("BTAP-Ext-Roof-Metal:U-0.162") # original construction
        s = model.getSurfaceByName(nom)
        expect(s.empty?).to be(false)
        s = s.get
        c = s.construction
        expect(c.empty?).to be(false)
        c = c.get.to_LayeredConstruction
        expect(c.empty?).to be(false)
        c = c.get
        expect(c.nameString.include?("c tbd")).to be(true) # TBD-derated
      end

      # Once done, ensure temporary schedule is dissociated from the thermostat
      # and deleted from the model.
      tstat.resetHeatingSetpointTemperatureSchedule
      expect(tstat.getHeatingSchedule.empty?).to be(true)

      sched2 = model.getScheduleByName(identifier)
      expect(sched2.empty?   ).to be(false)
      sched.remove
      sched2 = model.getScheduleByName(identifier)
      expect(sched2.empty?   ).to be( true)
      heat   = TBD.maxHeatScheduledSetpoint(zone)
      stpts  = TBD.setpoints(attic)
      expect(heat.nil?       ).to be(false)
      expect(heat.is_a?(Hash)).to be( true)
      expect(heat.key?(:spt )).to be( true)
      expect(heat.key?(:dual)).to be( true)
      expect(heat[:spt ].nil?).to be( true)
      expect(heat[:dual]     ).to be(false)

      expect(stpts[:heating].nil?).to be(true)
      expect(stpts[:cooling].nil?).to be(true)
      expect(TBD.plenum?(attic)).to be(false) # as before ...


      # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
      TBD.clean!
      argh                = {}
      argh[:option      ] = "efficient (BETBG)"
      argh[:uprate_walls] = true
      argh[:uprate_roofs] = true
      argh[:wall_option ] = "ALL wall constructions"
      argh[:roof_option ] = "ALL roof constructions"
      argh[:wall_ut     ] = 0.210 # NECB CZ7 2017 (RSi 4.76 / R27)
      argh[:roof_ut     ] = 0.138 # NECB CZ7 2017 (RSi 7.25 / R41)

      # Same, altered model from previous iteration (yet to uprate):
      #   - constructions: YES
      #   - setpoints    : YES
      #   - HVAC         : NO
      file   = File.join(__dir__, "files/osms/out/resto2a.osm")
      path   = OpenStudio::Path.new(file)
      model  = translator.loadModel(path)
      expect(model.empty?).to be(false)
      model  = model.get
      expect(model.getConstructions.empty?).to be(false)
      heated = TBD.heatingTemperatureSetpoints?(model)
      cooled = TBD.coolingTemperatureSetpoints?(model)
      expect(heated).to be(true)
      expect(cooled).to be(true)

      # Get geometry data for testing (4x exterior roofs, same construction).
      id           = "BTAP-Ext-Roof-Metal:U-0.162"
      construction = nil
      roofs        = []

      model.getSurfaces.each do |s|
        next unless s.surfaceType == "RoofCeiling"
        next unless s.outsideBoundaryCondition == "Outdoors"

        roofs << s.nameString
        c = s.construction
        expect(c.empty?).to be(false)
        c = c.get.to_LayeredConstruction
        expect(c.empty?).to be(false)
        c = c.get
        construction = c if construction.nil?
        expect(c).to eq(construction)
      end

      expect(construction.getNetArea ).to be_within(TOL).of(569.51)
      expect(roofs.size              ).to eq( 4)
      expect(construction.nameString ).to eq(id)
      expect(construction.layers.size).to eq( 2)

      insulation = construction.layers[1].to_MasslessOpaqueMaterial
      expect(insulation.empty?).to be(false)
      insulation = insulation.get
      original_r = insulation.thermalResistance
      expect(original_r).to be_within(TOL).of(6.17)

      # Attic spacetype as plenum, an alternative to the inactive thermostat.
      attic = model.getSpaceByName("attic")
      expect(attic.empty?              ).to be(false)
      attic  = attic.get
      sptype = attic.spaceType
      expect(sptype.empty?).to be(false)
      sptype = sptype.get
      sptype.setName("Attic as Plenum")

      stpts = TBD.setpoints(attic)
      expect(stpts[:heating]).to be_within(TOL).of(21.0)
      expect(TBD.unconditioned?(attic)).to be(false)
      expect(TBD.plenum?(attic)).to be(true) # works ...

      json      = TBD.process(model, argh)
      expect(json.is_a?(Hash)    ).to be( true)
      expect(json.key?(:io      )).to be( true)
      expect(json.key?(:surfaces)).to be( true)
      io        = json[:io      ]
      surfaces  = json[:surfaces]
      expect(TBD.status.zero?    ).to be( true)
      expect(argh.key?(:wall_uo) ).to be( true)
      expect(argh.key?(:roof_uo) ).to be( true)
      expect(argh[:roof_uo]).to be_within(TOL).of(0.120) # RSi  8.3 ( R47)
      expect(argh[:wall_uo]).to be_within(TOL).of(0.012) # RSi 83.3 (R473)

      # Validate ceiling surfaces (both insulated & uninsulated).
      ua   = 0.0
      a    = 0
      area = 0

      surfaces.each do |nom, surface|
        expect(surface.is_a?(Hash)        ).to be(true)
        expect(surface.key?(:conditioned )).to be(true)
        expect(surface.key?(:deratable   )).to be(true)
        expect(surface.key?(:construction)).to be(true)
        expect(surface.key?(:ground      )).to be(true)
        expect(surface.key?(:type        )).to be(true)

        next     if surface[:ground]
        next unless surface[:type  ] == :ceiling

        # Sloped plenum roof surfaces no longer ignored by TBD.
        id = surface[:construction].nameString
        expect(nom.include?("-roof")   ).to be( true)     if surface[:deratable]
        expect(id.include?("BTAP-Ext-")).to be( true)     if surface[:deratable]
        expect(surface[:conditioned]   ).to be( true)     if surface[:deratable]
        expect(nom.include?("_Ceiling")).to be( true) unless surface[:deratable]
        expect(surface[:conditioned]   ).to be( true) unless surface[:deratable]

        next unless surface[:deratable]
        next unless surface.key?(:heatloss)

        # Leaves only insulated plenum roof surfaces.
        expect(id).to eq("BTAP-Ext-Roof-Metal:U-0.162") # original construction
        s = model.getSurfaceByName(nom)
        expect(s.empty?).to be(false)
        s = s.get
        c = s.construction
        expect(c.empty?).to be(false)
        c = c.get.to_LayeredConstruction
        expect(c.empty?).to be(false)
        c = c.get
        expect(c.nameString.include?("c tbd")).to be(true) # TBD-derated
        a  += surface[:net]
        ua += 1 / TBD.rsi(c, s.filmResistance) * surface[:net]
      end

      expect(ua / a).to be_within(TOL).of(argh[:roof_ut])

      roofs.each do |roof|
        expect(surfaces.key?(roof)            ).to be(true)
        expect(surfaces[roof].key?(:deratable)).to be(true)
        expect(surfaces[roof].key?(:edges    )).to be(true)
        expect(surfaces[roof][:deratable]     ).to be(true)

        surfaces[roof][:edges].values.each do |edge|
          expect(edge.key?(:psi   )).to be(true)
          expect(edge.key?(:length)).to be(true)
          expect(edge.key?(:ratio )).to be(true)
          expect(edge.key?(:type  )).to be(true)
          next if edge[:type] == :transition

          expect(edge[:ratio]).to be_within(TOL).of(0.579)
          expect(edge[:psi  ]).to be_within(TOL).of(0.200 * edge[:ratio])
        end

        loss = 22.61 * 0.200 * 0.579
        expect(surfaces[roof].key?(:heatloss)).to be(true)
        expect(surfaces[roof].key?(:net     )).to be(true)
        expect(surfaces[roof][:heatloss]     ).to be_within(TOL).of(loss)
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
    expect(TBD.status.zero?).to be true
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

  it "can factor-in Frame & Divider (F&D) objects" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    version    = OpenStudio.openStudioVersion.split(".").join.to_i
    TBD.clean!

    model = OpenStudio::Model::Model.new
    vec   = OpenStudio::Point3dVector.new
    vec  << OpenStudio::Point3d.new( 2.00, 0.00, 3.00)
    vec  << OpenStudio::Point3d.new( 2.00, 0.00, 1.00)
    vec  << OpenStudio::Point3d.new( 4.00, 0.00, 1.00)
    vec  << OpenStudio::Point3d.new( 4.00, 0.00, 3.00)
    sub   = OpenStudio::Model::SubSurface.new(vec, model)

    # Aide-mémoire: attributes/objects subsurfaces are allowed to have/be.
    OpenStudio::Model::SubSurface.validSubSurfaceTypeValues.each do |type|
      expect(sub.setSubSurfaceType(type)).to be true
      # FixedWindow
      # OperableWindow
      # Door
      # GlassDoor
      # OverheadDoor
      # Skylight
      # TubularDaylightDome
      # TubularDaylightDiffuser
      case type
      when "FixedWindow"
        expect(sub.allowWindowPropertyFrameAndDivider   ).to be true
        next if version < 330

        expect(sub.allowDaylightingDeviceTubularDiffuser).to be false
        expect(sub.allowDaylightingDeviceTubularDome    ).to be false
      when "OperableWindow"
        expect(sub.allowWindowPropertyFrameAndDivider   ).to be true
        next if version < 330

        expect(sub.allowDaylightingDeviceTubularDiffuser).to be false
        expect(sub.allowDaylightingDeviceTubularDome    ).to be false
      when "Door"
        expect(sub.allowWindowPropertyFrameAndDivider   ).to be false
        next if version < 330

        expect(sub.allowDaylightingDeviceTubularDiffuser).to be false
        expect(sub.allowDaylightingDeviceTubularDome    ).to be false
      when "GlassDoor"
        expect(sub.allowWindowPropertyFrameAndDivider   ).to be true
        next if version < 330

        expect(sub.allowDaylightingDeviceTubularDiffuser).to be false
        expect(sub.allowDaylightingDeviceTubularDome    ).to be false
      when "OverheadDoor"
        expect(sub.allowWindowPropertyFrameAndDivider   ).to be false
        next if version < 330

        expect(sub.allowDaylightingDeviceTubularDiffuser).to be false
        expect(sub.allowDaylightingDeviceTubularDome    ).to be false
      when "Skylight"
        if version < 321
          expect(sub.allowWindowPropertyFrameAndDivider ).to be false
        else
          expect(sub.allowWindowPropertyFrameAndDivider ).to be true
        end

        next if version < 330

        expect(sub.allowDaylightingDeviceTubularDiffuser).to be false
        expect(sub.allowDaylightingDeviceTubularDome    ).to be false
      when "TubularDaylightDome"
        expect(sub.allowWindowPropertyFrameAndDivider   ).to be false
        next if version < 330

        expect(sub.allowDaylightingDeviceTubularDiffuser).to be false
        expect(sub.allowDaylightingDeviceTubularDome    ).to be true
      when "TubularDaylightDiffuser"
        expect(sub.allowWindowPropertyFrameAndDivider   ).to be false
        next if version < 330

        expect(sub.allowDaylightingDeviceTubularDiffuser).to be true
        expect(sub.allowDaylightingDeviceTubularDome    ).to be false
      else
        expect(true).to be false # Unknown SubSurfaceType!
      end
    end

    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    wll = "Office Front Wall"
    win = "Office Front Wall Window 1"

    front = model.getSurfaceByName(wll)
    expect(front).to_not be_empty
    front = front.get

    argh               = {}
    argh[:option     ] = "poor (BETBG)"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_warehouse8.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status.zero?).to be true
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(23)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(300)

    n_transitions  = 0
    n_fen_edges    = 0
    n_heads        = 0
    n_sills        = 0
    n_jambs        = 0
    n_grades       = 0
    n_corners      = 0
    n_rimjoists    = 0
    fen_length     = 0

    t1 = :transition
    t2 = :fenestration
    t3 = :head
    t4 = :sill
    t5 = :jamb
    t6 = :gradeconvex
    t7 = :cornerconvex
    t8 = :rimjoist

    surfaces.each do |id, surface|
      next unless surface[:boundary].downcase == "outdoors"
      next unless surface.key?(:ratio)

      expect(surface).to have_key(:heatloss)
      expect(surface[:heatloss].abs).to be > 0
      next unless id == wll

      expect(surface[:heatloss]).to be_within(0.1).of(50.2)
      expect(surface).to have_key(:edges)
      expect(surface[:edges].size).to eq(17)

      surface[:edges].values.each do |edge|
        expect(edge).to have_key(:type)

        n_transitions += 1 if edge[:type] == t1
        n_fen_edges   += 1 if edge[:type] == t2
        n_heads       += 1 if edge[:type] == t3
        n_sills       += 1 if edge[:type] == t4
        n_jambs       += 1 if edge[:type] == t5
        n_grades      += 1 if edge[:type] == t6
        n_corners     += 1 if edge[:type] == t7
        n_rimjoists   += 1 if edge[:type] == t8

        fen_length    += edge[:length] if edge[:type] == t2
      end
    end

    expect(n_transitions).to eq(1)
    expect(n_fen_edges  ).to eq(4) # Office Front Wall Window 1
    expect(n_heads      ).to eq(2) # Window 2 & door
    expect(n_sills      ).to eq(1) # Window 2
    expect(n_jambs      ).to eq(4) # Window 2 & door
    expect(n_grades     ).to eq(3) # including door sill
    expect(n_corners    ).to eq(1)
    expect(n_rimjoists  ).to eq(1)

    # Net & gross areas, as well as fenestration perimeters, reflect cases
    # without frame & divider objects. This is also what would be reported by
    # SketchUp, for instance.
    expect(fen_length     ).to be_within(TOL).of( 10.36) # Window 1 perimeter
    expect(front.netArea  ).to be_within(TOL).of( 95.49)
    expect(front.grossArea).to be_within(TOL).of(110.54)

    # Open another warehouse model and add/assign a Frame & Divider object.
    file     = File.join(__dir__, "files/osms/in/warehouse.osm")
    path     = OpenStudio::Path.new(file)
    model_FD = translator.loadModel(path)
    expect(model_FD).to_not be_empty
    model_FD = model_FD.get

    # Adding/validating Frame & Divider object.
    fd    = OpenStudio::Model::WindowPropertyFrameAndDivider.new(model_FD)
    width = 0.03
    expect(fd.setFrameWidth(width)).to be true # 30mm (narrow) around glazing
    expect(fd.setFrameConductance(2.500)).to be true

    window_FD = model_FD.getSubSurfaceByName(win)
    expect(window_FD).to_not be_empty
    window_FD = window_FD.get

    expect(window_FD.allowWindowPropertyFrameAndDivider).to be true
    expect(window_FD.setWindowPropertyFrameAndDivider(fd)).to be true
    width2 = window_FD.windowPropertyFrameAndDivider.get.frameWidth
    expect(width2).to be_within(TOL).of(width)

    front_FD = model_FD.getSurfaceByName(wll)
    expect(front_FD).to_not be_empty
    front_FD = front_FD.get

    expect(window_FD.netArea  ).to be_within(TOL).of(  5.58)
    expect(window_FD.grossArea).to be_within(TOL).of(  5.58) # not 5.89 (OK)
    expect(front_FD.grossArea ).to be_within(TOL).of(110.54) # this is OK

    unless version < 340
      # As of v3.4.0, SDK-reported WWR ratio calculations will ignore added
      # frame areas if associated subsurfaces no longer 'fit' within the
      # parent surface polygon, or overlap any of their siblings. For v340 and
      # up, one can only rely on SDK-reported WWR to safely determine TRUE net
      # area for a parent surface.
      #
      # For older SDK versions, TBD/OSut methods are required to do the same.
      #
      #   https://github.com/NREL/OpenStudio/issues/4361
      #
      # Here, the parent wall net area reflects the added (valid) frame areas.
      # However, this net area reports erroneous values when F&D objects
      # 'conflict', e.g. they don't fit in, or they overlap their siblings.
      expect(window_FD.roughOpeningArea).to be_within(TOL).of( 5.89)
      expect(front_FD.netArea          ).to be_within(TOL).of(95.17) # great !!
      expect(front_FD.windowToWallRatio).to be_within(TOL).of(0.104) # !!
    else
      expect(front_FD.netArea          ).to be_within(TOL).of(95.49) # !95.17
      expect(front_FD.windowToWallRatio).to be_within(TOL).of(0.101) # !0.104
    end

    # If one runs an OpenStudio +v3.4 simulation with the exported file below
    # ("model_FD.osm"), EnergyPlus will correctly report (e.g. eplustbl.htm)
    # a building WWR (gross window-wall ratio) of 72% (vs 71% without F&D), due
    # to the slight increase in area of the "Office Front Wall Window 1" (from
    # 5.58 m2 to 5.89 m2). The report clearly distinguishes between the revised
    # glazing area of 5.58 m2 vs a new framing area of 0.31 m2 for this window.
    # Finally, the parent surface "Office Front Wall" area will also be
    # correctly reported as 95.17 m2 (vs 95.49 m2). So OpenStudio is correctly
    # forward translating the subsurface and linked Frame & Divider objects to
    # EnergyPlus (triangular subsurfaces not tested).
    #
    # For prior versions to v3.4, there are discrepencies between the net area
    # of the "Office Front Wall" reported by the OpenStudio API vs EnergyPlus.
    # This may seem minor when looking at the numbers above, but keep in mind a
    # single glazed subsurface is modified for this comparison. This difference
    # could easily reach 5% to 10% for models with many windows, especially
    # those with narrow aspect ratios (lots of framing).
    #
    # ... subsurface.netArea calculation here could be reconsidered :
    #
    #   https://github.com/NREL/OpenStudio/blob/
    #   70a5549c439eda69d6c514a7275254f71f7e3d2b/src/model/Surface.cpp#L1446
    pth = File.join(__dir__, "files/osms/out/model_FD.osm")
    model_FD.save(pth, true)

    argh               = {}
    argh[:option     ] = "poor (BETBG)"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_warehouse8.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    json     = TBD.process(model_FD, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status.zero?).to eq(true)
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(23)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(300)

    # TBD calling on workarounds.
    net_area   = surfaces[wll][:net  ]
    gross_area = surfaces[wll][:gross]
    expect(net_area  ).to be_within(TOL).of( 95.17) # ! API 95.49
    expect(gross_area).to be_within(TOL).of(110.54) # same
    expect(surfaces[wll]).to have_key(:windows)
    expect(surfaces[wll][:windows].size).to eq(2)

    surfaces[wll][:windows].each do |i, window|
      expect(window).to have_key(:points)
      expect(window[:points].size).to eq(4)
      next unless i == win

      expect(window).to have_key(:gross)
      expect(window[:gross]).to be_within(TOL).of(5.89) # ! API 5.58
    end

    # Adding a clerestory window, slightly above "Office Front Wall Window 1",
    # to test/validate overlapping cases. Starting with a safe case.
    cl_v  = OpenStudio::Point3dVector.new
    cl_v << OpenStudio::Point3d.new( 3.66, 0.00, 4.00)
    cl_v << OpenStudio::Point3d.new( 3.66, 0.00, 2.47)
    cl_v << OpenStudio::Point3d.new( 7.31, 0.00, 2.47)
    cl_v << OpenStudio::Point3d.new( 7.31, 0.00, 4.00)
    clerestory = OpenStudio::Model::SubSurface.new(cl_v, model_FD)
    clerestory.setName("clerestory")
    expect(clerestory.setSurface(front_FD)).to be true
    expect(clerestory.setSubSurfaceType("FixedWindow")).to be true
    # ... reminder: set subsurface type AFTER setting its parent surface!

    argh = { option: "poor (BETBG)" }

    json     = TBD.process(model_FD, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.warn?).to be true # surfaces have already been derated
    expect(TBD.logs.size).to eq(12)
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(23)
    expect(surfaces).to have_key(wll)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(305)

    expect(surfaces[wll]).to have_key(:windows)
    wins = surfaces[wll][:windows]
    expect(wins.size).to eq(3)
    expect(wins).to have_key("clerestory")
    expect(wins).to have_key(win)

    expect(wins["clerestory"]).to have_key(:points)
    expect(wins[win         ]).to have_key(:points)

    v1 = window_FD.vertices         # original OSM vertices for window
    f1 = TBD.offset(v1, width, 300) # offset vertices, forcing v300 version
    expect(f1).to be_a(OpenStudio::Point3dVector)
    expect(f1.size).to eq(4)

    f1.each { |f| expect(f).to be_a(OpenStudio::Point3d) }

    f1area = OpenStudio.getArea(f1)
    expect(f1area).to_not be_empty
    f1area = f1area.get

    expect(f1area).to be_within(TOL).of(5.89             )
    expect(f1area).to be_within(TOL).of(wins[win][:area ])
    expect(f1area).to be_within(TOL).of(wins[win][:gross])

    # For SDK versions prior to v321, the offset vertices are generated in the
    # right order with respect to the original subsurface vertices.
    expect((f1[0].x - v1[0].x).abs).to be_within(TOL).of(width)
    expect((f1[1].x - v1[1].x).abs).to be_within(TOL).of(width)
    expect((f1[2].x - v1[2].x).abs).to be_within(TOL).of(width)
    expect((f1[3].x - v1[3].x).abs).to be_within(TOL).of(width)
    expect((f1[0].y - v1[0].y).abs).to be_within(TOL).of(0    )
    expect((f1[1].y - v1[1].y).abs).to be_within(TOL).of(0    )
    expect((f1[2].y - v1[2].y).abs).to be_within(TOL).of(0    )
    expect((f1[3].y - v1[3].y).abs).to be_within(TOL).of(0    )
    expect((f1[0].z - v1[0].z).abs).to be_within(TOL).of(width)
    expect((f1[1].z - v1[1].z).abs).to be_within(TOL).of(width)
    expect((f1[2].z - v1[2].z).abs).to be_within(TOL).of(width)
    expect((f1[3].z - v1[3].z).abs).to be_within(TOL).of(width)

    v2 = clerestory.vertices
    p2 = wins["clerestory"][:points] # same as original OSM vertices

    expect((p2[0].x - v2[0].x).abs).to be_within(TOL).of(0)
    expect((p2[1].x - v2[1].x).abs).to be_within(TOL).of(0)
    expect((p2[2].x - v2[2].x).abs).to be_within(TOL).of(0)
    expect((p2[3].x - v2[3].x).abs).to be_within(TOL).of(0)
    expect((p2[0].y - v2[0].y).abs).to be_within(TOL).of(0)
    expect((p2[1].y - v2[1].y).abs).to be_within(TOL).of(0)
    expect((p2[2].y - v2[2].y).abs).to be_within(TOL).of(0)
    expect((p2[3].y - v2[3].y).abs).to be_within(TOL).of(0)
    expect((p2[0].z - v2[0].z).abs).to be_within(TOL).of(0)
    expect((p2[1].z - v2[1].z).abs).to be_within(TOL).of(0)
    expect((p2[2].z - v2[2].z).abs).to be_within(TOL).of(0)
    expect((p2[3].z - v2[3].z).abs).to be_within(TOL).of(0)

    # In addition, the top of the "Office Front Wall Window 1" is aligned with
    # the bottom of the clerestory, i.e. no conflicts between siblings.
    expect((f1[0].z - p2[1].z).abs).to be_within(TOL).of(0)
    expect((f1[3].z - p2[2].z).abs).to be_within(TOL).of(0)
    expect(TBD.warn?).to be true

    # Testing both 'fits?' & 'overlaps?' functions.
    TBD.clean!
    vec2 = OpenStudio::Point3dVector.new

    p2.each { |p| vec2 << OpenStudio::Point3d.new(p.x, p.y, p.z) }

    expect(TBD.fits?(f1, vec2)).to be false
    expect(TBD.overlaps?(f1, vec2)).to be false
    expect(TBD.status.zero?).to be true

    # Same exercise, yet provide clerestory with Frame & Divider.
    fd2    = OpenStudio::Model::WindowPropertyFrameAndDivider.new(model_FD)
    width2 = 0.03
    expect(fd2.setFrameWidth(width2)).to be true
    expect(fd2.setFrameConductance(2.500)).to be true
    expect(clerestory.allowWindowPropertyFrameAndDivider).to be true
    expect(clerestory.setWindowPropertyFrameAndDivider(fd2)).to be true
    width3 = clerestory.windowPropertyFrameAndDivider.get.frameWidth
    expect(width3).to be_within(TOL).of(width2)

    argh = { option: "poor (BETBG)" }

    json     = TBD.process(model_FD, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.error?).to be true # conflict between F&D windows
    expect(TBD.logs.size).to eq(13)
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(23)
    expect(surfaces).to have_key(wll)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(304)

    expect(surfaces[wll]).to have_key(:windows)
    wins = surfaces[wll][:windows]
    expect(wins.size).to eq(3)
    expect(wins).to have_key("clerestory")
    expect(wins).to have_key(win)
    expect(wins["clerestory"]).to have_key(:points)
    expect(wins[win         ]).to have_key(:points)

    # As there are conflicts between both windows (due to conflicting Frame &
    # Divider parameters), TBD will ignore Frame & Divider coordinates and fall
    # back to original OpenStudio subsurface vertices.
    v1 = window_FD.vertices # original OSM vertices for window
    p1 = wins[win][:points] # Topolys vertices, as original

    expect((p1[0].x - v1[0].x).abs).to be_within(TOL).of(0)
    expect((p1[1].x - v1[1].x).abs).to be_within(TOL).of(0)
    expect((p1[2].x - v1[2].x).abs).to be_within(TOL).of(0)
    expect((p1[3].x - v1[3].x).abs).to be_within(TOL).of(0)
    expect((p1[0].y - v1[0].y).abs).to be_within(TOL).of(0)
    expect((p1[1].y - v1[1].y).abs).to be_within(TOL).of(0)
    expect((p1[2].y - v1[2].y).abs).to be_within(TOL).of(0)
    expect((p1[3].y - v1[3].y).abs).to be_within(TOL).of(0)
    expect((p1[0].z - v1[0].z).abs).to be_within(TOL).of(0)
    expect((p1[1].z - v1[1].z).abs).to be_within(TOL).of(0)
    expect((p1[2].z - v1[2].z).abs).to be_within(TOL).of(0)
    expect((p1[3].z - v1[3].z).abs).to be_within(TOL).of(0)

    v2 = clerestory.vertices
    p2 = wins["clerestory"][:points] # same as original OSM vertices

    expect((p2[0].x - v2[0].x).abs).to be_within(TOL).of(0)
    expect((p2[1].x - v2[1].x).abs).to be_within(TOL).of(0)
    expect((p2[2].x - v2[2].x).abs).to be_within(TOL).of(0)
    expect((p2[3].x - v2[3].x).abs).to be_within(TOL).of(0)
    expect((p2[0].y - v2[0].y).abs).to be_within(TOL).of(0)
    expect((p2[1].y - v2[1].y).abs).to be_within(TOL).of(0)
    expect((p2[2].y - v2[2].y).abs).to be_within(TOL).of(0)
    expect((p2[3].y - v2[3].y).abs).to be_within(TOL).of(0)
    expect((p2[0].z - v2[0].z).abs).to be_within(TOL).of(0)
    expect((p2[1].z - v2[1].z).abs).to be_within(TOL).of(0)
    expect((p2[2].z - v2[2].z).abs).to be_within(TOL).of(0)
    expect((p2[3].z - v2[3].z).abs).to be_within(TOL).of(0)

    # In addition, the top of the "Office Front Wall Window 1" is no longer
    # aligned with the bottom of the clerestory.
    expect(((p1[0].z - p2[1].z).abs - width2).abs).to be_within(TOL).of(0)
    expect(((p1[3].z - p2[2].z).abs - width2).abs).to be_within(TOL).of(0)

    TBD.clean!
    vec1 = OpenStudio::Point3dVector.new
    vec2 = OpenStudio::Point3dVector.new

    p1.each { |p| vec1 << OpenStudio::Point3d.new(p.x, p.y, p.z) }
    p2.each { |p| vec2 << OpenStudio::Point3d.new(p.x, p.y, p.z) }

    expect(TBD.fits?(vec1, vec2)).to be false
    expect(TBD.overlaps?(vec1, vec2)).to be false
    expect(TBD.status.zero?).to be true


    # --- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --- #
    # Testing more complex cases e.g., triangular windows, irregular 4-side
    # windows, rough opening edges overlapping parent surface edges.
    model = OpenStudio::Model::Model.new
    space = OpenStudio::Model::Space.new(model)
    space.setName("Space")

    # All subsurfaces are Simple Glazing constructions.
    fen = OpenStudio::Model::Construction.new(model)
    fen.setName("FD fen")

    glazing = OpenStudio::Model::SimpleGlazing.new(model)
    glazing.setName("FD glazing")
    expect(glazing.setUFactor(2.0)).to be true

    layers = OpenStudio::Model::MaterialVector.new
    layers << glazing
    expect(fen.setLayers(layers)).to be true

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( 0.00, 0.00, 10.00)
    vec << OpenStudio::Point3d.new( 0.00, 0.00,  0.00)
    vec << OpenStudio::Point3d.new(10.00, 0.00,  0.00)
    vec << OpenStudio::Point3d.new(10.00, 0.00, 10.00)
    dad  = OpenStudio::Model::Surface.new(vec, model)
    dad.setName("dad")
    expect(dad.setSpace(space)).to be true

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( 2.00, 0.00, 8.00)
    vec << OpenStudio::Point3d.new( 1.00, 0.00, 6.00)
    vec << OpenStudio::Point3d.new( 4.00, 0.00, 9.00)
    w1   = OpenStudio::Model::SubSurface.new(vec, model)
    w1.setName("w1")
    expect(w1.setSubSurfaceType("FixedWindow")).to be true
    expect(w1.setSurface(dad)).to be true
    expect(w1.setConstruction(fen)).to be true
    expect(w1.uFactor).to_not be_empty
    expect(w1.uFactor.get).to be_within(0.1).of(2.0)
    expect(w1.netArea  ).to be_within(TOL).of(1.50)
    expect(w1.grossArea).to be_within(TOL).of(1.50)

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( 7.00, 0.00, 4.00)
    vec << OpenStudio::Point3d.new( 4.00, 0.00, 1.00)
    vec << OpenStudio::Point3d.new( 8.00, 0.00, 2.00)
    vec << OpenStudio::Point3d.new( 9.00, 0.00, 3.00)
    w2   = OpenStudio::Model::SubSurface.new(vec, model)
    w2.setName("w2")
    expect(w2.setSubSurfaceType("FixedWindow")).to be true
    expect(w2.setSurface(dad)).to be true
    expect(w2.setConstruction(fen)).to be true
    expect(w2.uFactor).to_not be_empty
    expect(w2.uFactor.get).to be_within(0.1).of(2.0)
    expect(w2.netArea  ).to be_within(TOL).of(6.00)
    expect(w2.grossArea).to be_within(TOL).of(6.00)

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( 9.00, 0.00, 9.80)
    vec << OpenStudio::Point3d.new( 9.80, 0.00, 9.00)
    vec << OpenStudio::Point3d.new( 9.80, 0.00, 9.80)
    w3   = OpenStudio::Model::SubSurface.new(vec, model)
    w3.setName("w3")
    expect(w3.setSubSurfaceType("FixedWindow")).to be true
    expect(w3.setSurface(dad)).to be true
    expect(w3.setConstruction(fen)).to be true
    expect(w3.uFactor).to_not be_empty
    expect(w3.uFactor.get).to be_within(0.1).of(2.0)
    expect(w3.netArea  ).to be_within(TOL).of(0.32)
    expect(w3.grossArea).to be_within(TOL).of(0.32)

    # Without Frame & Divider objects linked to subsurface.
    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:gross)
    expect(surface).to have_key(:net)
    expect(surface).to have_key(:windows)
    expect(surface[:gross]).to be_a(Numeric)
    expect(surface[:gross]).to be_within(0.1).of(100)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(TOL).of(1.500)
    expect(surface[:windows]["w2"][:gross]).to be_within(TOL).of(6.000)
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    # Adding a Frame & Divider object ...
    fd = OpenStudio::Model::WindowPropertyFrameAndDivider.new(model)
    expect(fd.setFrameWidth(0.200)).to be true # 200mm (wide!) around glazing
    expect(fd.setFrameConductance(0.500)).to be true

    expect(w1.allowWindowPropertyFrameAndDivider).to be true
    expect(w1.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w1.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(TOL).of(0.200)

    # TBD's 'properties' method relies on OSut's 'offset' solution when dealing
    # with subsurfaces with F&D. It offers 3x options:
    #   1. native, 3D vector-based calculations (only option for SDK < v321)
    #   2. SDK's reliance on Boost's 'buffer' (default for v300 < SDK < v340)
    #   3. SDK's 'rough opening' vertices (default for SDK v340+)
    #
    # Options #2 & #3 both rely on Boost's buffer. But SDK v340+ doesn't
    # correct generated Boost vertices (back to counterclockwise). Option #2
    # ensures counterclockwise sequences, although the first vertex in the array
    # is no longer in sync with the original OpenStudio vertices. Not
    # consequential for fitting and overlapping detection, or net/gross/rough
    # areas tallies. Otherwise, both options generate the same vertices.
    #
    # For triangular subsurfaces, Options #2 & #3 may generate additional
    # vertices near acute angles, e.g. 6 (3 of which would be ~colinear).
    # Calculated areas, as well as fitting & overlapping detection, still work.
    # Yet inaccuracies do creep in with respect to Option #1. To maintain
    # consistency in TBD calculations when switching SDK versions, TBD's use of
    # OSut's offset method is as follows (see 'properties' in geo.rb):
    #
    #    offset(s.vertices, width, 300)
    #
    # There may be slight differences in reported SDK results vs TBD UA reports
    # (e.g. WWR, net areas) with acute triangular windows ... which is fine.
    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:net)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(TOL).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(TOL).of(6.000)
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w1"][:points]
    expect(ptz.size).to eq(3) # 6 without the '300' offset argument above
    vec = OpenStudio::Point3dVector.new

    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }

    vec_area = OpenStudio.getArea(vec)
    expect(vec_area).to_not be_empty
    expect(vec_area.get).to be_within(TOL).of(surface[:windows]["w1"][:area])

    # The following X & Z coordinates are all offset by 0.200 (frame width),
    # with respect to the original subsurface coordinates. For acute angles,
    # the rough opening edge intersection can be far, far away from the glazing
    # coordinates (+1m).
    expect(vec[0].x).to be_within(TOL).of( 1.85)
    expect(vec[0].y).to be_within(TOL).of( 0.00)
    expect(vec[0].z).to be_within(TOL).of( 8.15)
    expect(vec[1].x).to be_within(TOL).of( 0.27)
    expect(vec[1].y).to be_within(TOL).of( 0.00)
    expect(vec[1].z).to be_within(TOL).of( 4.99)
    expect(vec[2].x).to be_within(TOL).of( 5.01)
    expect(vec[2].y).to be_within(TOL).of( 0.00)
    expect(vec[2].z).to be_within(TOL).of( 9.73)

    # Adding a Frame & Divider object for w2.
    expect(w2.allowWindowPropertyFrameAndDivider).to be true
    expect(w2.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w2.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(TOL).of(0.200)

    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(TOL).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(TOL).of(8.645)
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w2"][:points]
    expect(ptz.size).to eq(4)
    vec = OpenStudio::Point3dVector.new

    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }

    expect(vec[0].x).to be_within(TOL).of( 6.96)
    expect(vec[0].y).to be_within(TOL).of( 0.00)
    expect(vec[0].z).to be_within(TOL).of( 4.24)
    expect(vec[1].x).to be_within(TOL).of( 3.35)
    expect(vec[1].y).to be_within(TOL).of( 0.00)
    expect(vec[1].z).to be_within(TOL).of( 0.63)
    expect(vec[2].x).to be_within(TOL).of( 8.10)
    expect(vec[2].y).to be_within(TOL).of( 0.00)
    expect(vec[2].z).to be_within(TOL).of( 1.82)
    expect(vec[3].x).to be_within(TOL).of( 9.34)
    expect(vec[3].y).to be_within(TOL).of( 0.00)
    expect(vec[3].z).to be_within(TOL).of( 3.05)

    # Adding a Frame & Divider object for w3.
    expect(w3.allowWindowPropertyFrameAndDivider).to be true
    expect(w3.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w3.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(TOL).of(0.200)

    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(TOL).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(TOL).of(8.645)
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(1.100)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w3"][:points]
    expect(ptz.size).to eq(3)
    vec = OpenStudio::Point3dVector.new

    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }

    # This window would have 2 shared edges (@right angle) with the parent.
    expect(vec[0].x).to be_within(TOL).of( 8.52)
    expect(vec[0].y).to be_within(TOL).of( 0.00)
    expect(vec[0].z).to be_within(TOL).of(10.00)
    expect(vec[1].x).to be_within(TOL).of(10.00)
    expect(vec[1].y).to be_within(TOL).of( 0.00)
    expect(vec[1].z).to be_within(TOL).of( 8.52)
    expect(vec[2].x).to be_within(TOL).of(10.00)
    expect(vec[2].y).to be_within(TOL).of( 0.00)
    expect(vec[2].z).to be_within(TOL).of(10.00)


    # --- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --- #
    # Repeat exercise, with parent surface & subsurfaces rotated 120 (CW).
    # (i.e., negative coordinates, Y-axis coordinates, etc.)
    model = OpenStudio::Model::Model.new
    space = OpenStudio::Model::Space.new(model)
    space.setName("Space")

    # All subsurfaces are Simple Glazing constructions.
    fen = OpenStudio::Model::Construction.new(model)
    fen.setName("FD fen")

    glazing = OpenStudio::Model::SimpleGlazing.new(model)
    glazing.setName("FD glazing")
    expect(glazing.setUFactor(2.0)).to be true

    layers = OpenStudio::Model::MaterialVector.new
    layers << glazing
    expect(fen.setLayers(layers)).to be true

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new(  0.00,  0.00, 10.00)
    vec << OpenStudio::Point3d.new(  0.00,  0.00,  0.00)
    vec << OpenStudio::Point3d.new( -5.00, -8.66,  0.00)
    vec << OpenStudio::Point3d.new( -5.00, -8.66, 10.00)
    dad  = OpenStudio::Model::Surface.new(vec, model)
    dad.setName("dad")
    expect(dad.setSpace(space)).to be true

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -1.00, -1.73,  8.00)
    vec << OpenStudio::Point3d.new( -0.50, -0.87,  6.00)
    vec << OpenStudio::Point3d.new( -2.00, -3.46,  9.00)
    w1   = OpenStudio::Model::SubSurface.new(vec, model)
    w1.setName("w1")
    expect(w1.setSubSurfaceType("FixedWindow")).to be true
    expect(w1.setSurface(dad)).to be true
    expect(w1.setConstruction(fen)).to be true
    expect(w1.uFactor).to_not be_empty
    expect(w1.uFactor.get).to be_within(0.1).of(2.0)
    expect(w1.netArea  ).to be_within(TOL).of(1.50)
    expect(w1.grossArea).to be_within(TOL).of(1.50)

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -3.50, -6.060,  4.00)
    vec << OpenStudio::Point3d.new( -2.00, -3.460,  1.00)
    vec << OpenStudio::Point3d.new( -4.00, -6.930,  2.00)
    vec << OpenStudio::Point3d.new( -4.50, -7.795,  3.00)
    w2   = OpenStudio::Model::SubSurface.new(vec, model)
    w2.setName("w2")
    expect(w2.setSubSurfaceType("FixedWindow")).to be true
    expect(w2.setSurface(dad)).to be true
    expect(w2.setConstruction(fen)).to be true
    expect(w2.uFactor).to_not be_empty
    expect(w2.uFactor.get).to be_within(0.1).of(2.0)
    expect(w2.netArea  ).to be_within(TOL).of(6.00)
    expect(w2.grossArea).to be_within(TOL).of(6.00)

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -4.50, -7.79,  9.80)
    vec << OpenStudio::Point3d.new( -4.90, -8.49,  9.00)
    vec << OpenStudio::Point3d.new( -4.90, -8.49,  9.80)
    w3   = OpenStudio::Model::SubSurface.new(vec, model)
    w3.setName("w3")
    expect(w3.setSubSurfaceType("FixedWindow")).to be true
    expect(w3.setSurface(dad)).to be true
    expect(w3.setConstruction(fen)).to be true
    expect(w3.uFactor).to_not be_empty
    expect(w3.uFactor.get).to be_within(0.1).of(2.0)
    expect(w3.netArea  ).to be_within(TOL).of(0.32)
    expect(w3.grossArea).to be_within(TOL).of(0.32)

    # Without Frame & Divider objects linked to subsurface.
    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:gross)
    expect(surface).to have_key(:net)
    expect(surface).to have_key(:windows)
    expect(surface[:gross]).to be_a(Numeric)
    expect(surface[:gross]).to be_within(0.1).of(100)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(TOL).of(1.500)
    expect(surface[:windows]["w2"][:gross]).to be_within(TOL).of(6.000)
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    # Adding a Frame & Divider object.
    fd = OpenStudio::Model::WindowPropertyFrameAndDivider.new(model)
    expect(fd.setFrameWidth(0.200)).to be true # 200mm (wide!) around glazing
    expect(fd.setFrameConductance(0.500)).to be true

    expect(w1.allowWindowPropertyFrameAndDivider).to be true
    expect(w1.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w1.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(TOL).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(TOL).of(6.000)
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w1"][:points]
    expect(ptz).to be_a(Array)
    expect(ptz.size).to eq(3)
    vec = OpenStudio::Point3dVector.new

    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }

    area = OpenStudio.getArea(vec)
    expect(area).to_not be_empty
    expect(area.get).to be_within(TOL).of(surface[:windows]["w1"][:area])

    expect(vec[0].x).to be_within(TOL).of(-0.93)
    expect(vec[0].y).to be_within(TOL).of(-1.60)
    expect(vec[0].z).to be_within(TOL).of( 8.15)
    expect(vec[1].x).to be_within(TOL).of(-0.13)
    expect(vec[1].y).to be_within(TOL).of(-0.24) # SketchUP (-0.23)
    expect(vec[1].z).to be_within(TOL).of( 4.99)
    expect(vec[2].x).to be_within(TOL).of(-2.51)
    expect(vec[2].y).to be_within(TOL).of(-4.34)
    expect(vec[2].z).to be_within(TOL).of( 9.73)

    # Adding a Frame & Divider object for w2.
    expect(w2.allowWindowPropertyFrameAndDivider).to be true
    expect(w2.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w2.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(TOL).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(TOL).of(8.645)
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w2"][:points]
    expect(ptz.size).to eq(4)
    vec = OpenStudio::Point3dVector.new

    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }

    area = OpenStudio.getArea(vec)
    expect(area).to_not be_empty
    expect(area.get).to be_within(TOL).of(surface[:windows]["w2"][:area])

    expect(vec[0].x).to be_within(TOL).of(-3.48)
    expect(vec[0].y).to be_within(TOL).of(-6.03)
    expect(vec[0].z).to be_within(TOL).of( 4.24)
    expect(vec[1].x).to be_within(TOL).of(-1.67)
    expect(vec[1].y).to be_within(TOL).of(-2.90)
    expect(vec[1].z).to be_within(TOL).of( 0.63)
    expect(vec[2].x).to be_within(TOL).of(-4.05)
    expect(vec[2].y).to be_within(TOL).of(-7.02)
    expect(vec[2].z).to be_within(TOL).of( 1.82)
    expect(vec[3].x).to be_within(TOL).of(-4.67)
    expect(vec[3].y).to be_within(TOL).of(-8.09)
    expect(vec[3].z).to be_within(TOL).of( 3.05)

    # Adding a Frame & Divider object for w3.
    expect(w3.allowWindowPropertyFrameAndDivider).to be true
    expect(w3.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w3.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(TOL).of(0.200)

    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(TOL).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(TOL).of(8.645)
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(1.100)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w3"][:points]
    expect(ptz.size).to eq(3)
    vec = OpenStudio::Point3dVector.new

    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }

    area = OpenStudio.getArea(vec)
    expect(area).to_not be_empty
    expect(area.get).to be_within(TOL).of(surface[:windows]["w3"][:area])
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(1.1)

    expect(vec[0].x).to be_within(TOL).of(-4.26)
    expect(vec[0].y).to be_within(TOL).of(-7.37) # SketchUp (-7.38)
    expect(vec[0].z).to be_within(TOL).of(10.00)
    expect(vec[1].x).to be_within(TOL).of(-5.00)
    expect(vec[1].y).to be_within(TOL).of(-8.66)
    expect(vec[1].z).to be_within(TOL).of( 8.52)
    expect(vec[2].x).to be_within(TOL).of(-5.00)
    expect(vec[2].y).to be_within(TOL).of(-8.66)
    expect(vec[2].z).to be_within(TOL).of(10.00)


    # --- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- --- #
    # Repeat 3rd time - 2x 30° rotations (along the 2 other axes).
    model = OpenStudio::Model::Model.new
    space = OpenStudio::Model::Space.new(model)
    space.setName("Space")

    # All subsurfaces are Simple Glazing constructions.
    fen = OpenStudio::Model::Construction.new(model)
    fen.setName("FD3 fen")

    glazing = OpenStudio::Model::SimpleGlazing.new(model)
    glazing.setName("FD3 glazing")
    expect(glazing.setUFactor(2.0)).to be true

    layers = OpenStudio::Model::MaterialVector.new
    layers << glazing
    expect(fen.setLayers(layers)).to be true

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -1.25,  6.50,  7.50)
    vec << OpenStudio::Point3d.new(  0.00,  0.00,  0.00)
    vec << OpenStudio::Point3d.new( -6.50, -6.25,  4.33)
    vec << OpenStudio::Point3d.new( -7.75,  0.25, 11.83)
    dad  = OpenStudio::Model::Surface.new(vec, model)
    dad.setName("dad")
    expect(dad.setSpace(space)).to be true

    vec  = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -2.30,  3.95,  6.87)
    vec << OpenStudio::Point3d.new( -1.40,  3.27,  4.93)
    vec << OpenStudio::Point3d.new( -3.72,  3.35,  8.48)
    w1   = OpenStudio::Model::SubSurface.new(vec, model)
    w1.setName("w1")
    expect(w1.setSubSurfaceType("FixedWindow")).to be true
    expect(w1.setSurface(dad)).to be true
    expect(w1.setConstruction(fen)).to be true
    expect(w1.uFactor).to_not be_empty
    expect(w1.uFactor.get).to be_within(0.1).of(2.0)
    expect(w1.netArea  ).to be_within(TOL).of(1.50)
    expect(w1.grossArea).to be_within(TOL).of(1.50)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -5.05, -1.78,  6.03)
    vec << OpenStudio::Point3d.new( -2.72, -1.85,  2.48)
    vec << OpenStudio::Point3d.new( -5.45, -3.70,  4.96)
    vec << OpenStudio::Point3d.new( -6.225, -3.69,  6.13)
    w2 = OpenStudio::Model::SubSurface.new(vec, model)
    w2.setName("w2")
    expect(w2.setSubSurfaceType("FixedWindow")).to be true
    expect(w2.setSurface(dad)).to be true
    expect(w2.setConstruction(fen)).to be true
    expect(w2.uFactor).to_not be_empty
    expect(w2.uFactor.get).to be_within(0.1).of(2.0)
    expect(w2.netArea  ).to be_within(TOL).of(6.00)
    expect(w2.grossArea).to be_within(TOL).of(6.00)

    vec = OpenStudio::Point3dVector.new
    vec << OpenStudio::Point3d.new( -7.07,  0.74, 11.25)
    vec << OpenStudio::Point3d.new( -7.49, -0.28, 10.99)
    vec << OpenStudio::Point3d.new( -7.59,  0.24, 11.59)
    w3 = OpenStudio::Model::SubSurface.new(vec, model)
    w3.setName("w3")
    expect(w3.setSubSurfaceType("FixedWindow")).to be true
    expect(w3.setSurface(dad)).to be true
    expect(w3.setConstruction(fen)).to be true
    expect(w3.uFactor).to_not be_empty
    expect(w3.uFactor.get).to be_within(0.1).of(2.0)
    expect(w3.netArea  ).to be_within(TOL).of(0.32)
    expect(w3.grossArea).to be_within(TOL).of(0.32)

    # Without Frame & Divider objects linked to subsurface.
    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:gross)
    expect(surface).to have_key(:net)
    expect(surface).to have_key(:windows)
    expect(surface[:gross]).to be_a(Numeric)
    expect(surface[:gross]).to be_within(0.1).of(100)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.02).of(1.500)
    expect(surface[:windows]["w2"][:gross]).to be_within(0.02).of(6.000)
    expect(surface[:windows]["w3"][:gross]).to be_within(0.02).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    # Adding a Frame & Divider object.
    fd = OpenStudio::Model::WindowPropertyFrameAndDivider.new(model)
    expect(fd.setFrameWidth(0.200)).to be true
    expect(fd.setFrameConductance(0.500)).to be true

    expect(w1.allowWindowPropertyFrameAndDivider).to be true
    expect(w1.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w1.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(TOL).of(0.200)

    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.02).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(0.02).of(6.000)
    expect(surface[:windows]["w3"][:gross]).to be_within(0.02).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w1"][:points]
    expect(ptz).to be_a(Array)
    expect(ptz.size).to eq(3)
    vec = OpenStudio::Point3dVector.new

    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }

    area = OpenStudio.getArea(vec)
    expect(area).to_not be_empty
    expect(area.get).to be_within(TOL).of(surface[:windows]["w1"][:area])
    expect(vec[0].x).to be_within(TOL).of(-2.22)
    expect(vec[0].y).to be_within(TOL).of( 4.14)
    expect(vec[0].z).to be_within(TOL).of( 6.91)
    expect(vec[1].x).to be_within(TOL).of(-0.80)
    expect(vec[1].y).to be_within(TOL).of( 3.07)
    expect(vec[1].z).to be_within(TOL).of( 3.86)
    expect(vec[2].x).to be_within(TOL).of(-4.47)
    expect(vec[2].y).to be_within(TOL).of( 3.19)
    expect(vec[2].z).to be_within(TOL).of( 9.46) # SketchUp (-9.47)

    # Adding a Frame & Divider object for w2.
    expect(w2.allowWindowPropertyFrameAndDivider).to be true
    expect(w2.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w2.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.02).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(0.02).of(8.645)
    expect(surface[:windows]["w3"][:gross]).to be_within(0.02).of(0.320)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w2"][:points]
    expect(ptz.size).to eq(4)
    vec = OpenStudio::Point3dVector.new

    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }

    area = OpenStudio.getArea(vec)
    expect(area).to_not be_empty
    expect(area.get).to be_within(TOL).of(surface[:windows]["w2"][:area])
    expect(vec[0].x).to be_within(TOL).of(-5.055)
    expect(vec[0].y).to be_within(TOL).of(-1.595)
    expect(vec[0].z).to be_within(TOL).of( 6.200)
    expect(vec[1].x).to be_within(TOL).of(-2.250)
    expect(vec[1].y).to be_within(TOL).of(-1.680)
    expect(vec[1].z).to be_within(TOL).of( 1.920)
    expect(vec[2].x).to be_within(TOL).of(-5.490)
    expect(vec[2].y).to be_within(TOL).of(-3.880)
    expect(vec[2].z).to be_within(TOL).of( 4.870)
    expect(vec[3].x).to be_within(TOL).of(-6.450)
    expect(vec[3].y).to be_within(TOL).of(-3.865)
    expect(vec[3].z).to be_within(TOL).of( 6.315)

    # Adding a Frame & Divider object for w3.
    expect(w3.allowWindowPropertyFrameAndDivider).to be true
    expect(w3.setWindowPropertyFrameAndDivider(fd)).to be true
    width = w3.windowPropertyFrameAndDivider.get.frameWidth
    expect(width).to be_within(0.001).of(0.200)

    surface = TBD.properties(dad, argh)
    expect(surface).to_not be_nil
    expect(surface).to be_a(Hash)
    expect(surface).to have_key(:windows)
    expect(surface[:windows]).to be_a(Hash)
    expect(surface[:windows]).to have_key("w1")
    expect(surface[:windows]).to have_key("w2")
    expect(surface[:windows]).to have_key("w3")
    expect(surface[:windows]["w1"]).to be_a(Hash)
    expect(surface[:windows]["w2"]).to be_a(Hash)
    expect(surface[:windows]["w3"]).to be_a(Hash)
    expect(surface[:windows]["w1"]).to have_key(:gross)
    expect(surface[:windows]["w2"]).to have_key(:gross)
    expect(surface[:windows]["w3"]).to have_key(:gross)
    expect(surface[:windows]["w1"]).to have_key(:points)
    expect(surface[:windows]["w2"]).to have_key(:points)
    expect(surface[:windows]["w3"]).to have_key(:points)
    expect(surface[:windows]["w1"][:gross]).to be_within(0.02).of(3.750)
    expect(surface[:windows]["w2"][:gross]).to be_within(0.02).of(8.645)
    expect(surface[:windows]["w3"][:gross]).to be_within(0.02).of(1.100)
    expect(surface[:windows]["w1"][:points].size).to eq(3)
    expect(surface[:windows]["w2"][:points].size).to eq(4)
    expect(surface[:windows]["w3"][:points].size).to eq(3)

    ptz = surface[:windows]["w3"][:points]
    expect(ptz.size).to eq(3)
    vec = OpenStudio::Point3dVector.new
    ptz.each { |o| vec << OpenStudio::Point3d.new(o.x, o.y, o.z) }
    area = OpenStudio.getArea(vec)
    expect(area).to_not be_empty
    expect(area.get).to be_within(TOL).of(surface[:windows]["w3"][:area])
    expect(surface[:windows]["w3"][:gross]).to be_within(TOL).of(1.1)
    expect(vec[0].x).to be_within(TOL).of(-6.78)
    expect(vec[0].y).to be_within(TOL).of( 1.17)
    expect(vec[0].z).to be_within(TOL).of(11.19)
    expect(vec[1].x).to be_within(TOL).of(-7.56)
    expect(vec[1].y).to be_within(TOL).of(-0.72)
    expect(vec[1].z).to be_within(TOL).of(10.72)
    expect(vec[2].x).to be_within(TOL).of(-7.75)
    expect(vec[2].y).to be_within(TOL).of( 0.25)
    expect(vec[2].z).to be_within(TOL).of(11.83)
  end

  it "can uprate (ALL roof) constructions" do
    translator = OpenStudio::OSVersion::VersionTranslator.new
    TBD.clean!

    file = File.join(__dir__, "files/osms/in/warehouse.osm")
    path = OpenStudio::Path.new(file)
    model = translator.loadModel(path)
    expect(model).to_not be_empty
    model = model.get

    # Mimics measure.
    walls = {c: {}, dft: "ALL wall constructions" }
    roofs = {c: {}, dft: "ALL roof constructions" }
    flors = {c: {}, dft: "ALL floor constructions"}

    walls[:c][walls[:dft]] = {a: 100000000000000}
    roofs[:c][roofs[:dft]] = {a: 100000000000000}
    flors[:c][flors[:dft]] = {a: 100000000000000}
    
    walls[:chx] = OpenStudio::StringVector.new
    roofs[:chx] = OpenStudio::StringVector.new
    flors[:chx] = OpenStudio::StringVector.new

    model.getSurfaces.each do |s|
      type = s.surfaceType.downcase
      next unless ["wall", "roofceiling", "floor"].include?(type)
      next unless s.outsideBoundaryCondition.downcase == "outdoors"
      next     if s.construction.empty?
      next     if s.construction.get.to_LayeredConstruction.empty?

      lc = s.construction.get.to_LayeredConstruction.get
      id = lc.nameString
      next if walls[:c].key?(id)
      next if roofs[:c].key?(id)
      next if flors[:c].key?(id)

      a = lc.getNetArea
      # One challenge of the uprate approach concerns OpenStudio-reported
      # surface film resistances, which factor-in the slope of the surface and
      # surface emittances. As the uprate approach relies on user-defined Ut
      # factors (inputs, as targets to meet), it also considers surface film
      # resistances. In the schematic cross-section below, let's postulate that
      # each slope has a unique pitch: 50° (s1), 0° (s2), & 60° (s3). All three
      # surfaces reference the same construction.
      #
      #         s2
      #        _____
      #       /     \
      #   s1 /       \ s3
      #     /         \
      #
      # For highly-reflective interior finishes (think of Bruce Lee in Enter
      # the Dragon), the difference here in reported RSi could reach 0.1 m2.K/W
      # or R0.6. That's a 1% to 3% difference for a well-insulated construction.
      # This may seem significant, but the impact on energy simulation results
      # should be barely noticeable. However, these discrepancies could become
      # an irritant when processing an OpenStudio model for code compliance
      # purposes. For clear-field (Uo) calculations, a simple solution is ensure
      # that the (common) layered construction meets minimal code requirements
      # for the surface with the lowest film resistance, here s2. Thus surfaces
      # s1 & s3 will slightly overshoot the Uo target.
      #
      # For Ut calculations (which factor-in major thermal bridging), this is
      # not as straightforward as adjusting the construction layers by hand. Yet
      # conceptually, the approach here remains similar: for a selected
      # construction shared by more than one surface, the considered film
      # resistance will be that of the worst case encountered. The resulting Uo
      # for that uprated construction might be slightly lower (i.e., better
      # performing) than expected in some circumstances.
      f = s.filmResistance

      case type
      when "wall"
        walls[:c][id]     = {a: a, lc: lc}
        walls[:c][id][:f] = f unless walls[:c][id].key?(:f)
        walls[:c][id][:f] = f     if walls[:c][id][:f] > f
      when "roofceiling"
        roofs[:c][id]     = {a: a, lc: lc}
        roofs[:c][id][:f] = f unless roofs[:c][id].key?(:f)
        roofs[:c][id][:f] = f     if roofs[:c][id][:f] > f
      else
        flors[:c][id]     = {a: a, lc: lc}
        flors[:c][id][:f] = f unless flors[:c][id].key?(:f)
        flors[:c][id][:f] = f     if flors[:c][id][:f] > f
      end
    end

    walls[:c] = walls[:c].sort_by{ |k,v| v[:a] }.reverse!.to_h
    roofs[:c] = roofs[:c].sort_by{ |k,v| v[:a] }.reverse!.to_h
    flors[:c] = flors[:c].sort_by{ |k,v| v[:a] }.reverse!.to_h

    walls[:c][walls[:dft]][:a] = 0
    roofs[:c][roofs[:dft]][:a] = 0
    flors[:c][flors[:dft]][:a] = 0

    walls[:c].keys.each { |id| walls[:chx] << id }
    roofs[:c].keys.each { |id| roofs[:chx] << id }
    flors[:c].keys.each { |id| flors[:chx] << id }

    expect(roofs[:c].size).to eq(3)
    rf1 = "Typical Insulated Metal Building Roof R-10.31 1"
    rf2 = "Typical Insulated Metal Building Roof R-18.18"
    expect(roofs[:c].keys[0]).to eq("ALL roof constructions")
    expect(roofs[:c]["ALL roof constructions"][:a]).to be_within(TOL).of(0)
    roof1 = roofs[:c].values[1]
    roof2 = roofs[:c].values[2]
    expect(roof1[:a] > roof2[:a]).to be true
    expect(roof1[:f]).to be_within(TOL).of(roof2[:f])
    expect(roof1[:f]).to be_within(TOL).of(0.1360)
    expect(1/TBD.rsi(roof1[:lc], roof1[:f])).to be_within(TOL).of(0.5512) # R10
    expect(1/TBD.rsi(roof2[:lc], roof2[:f])).to be_within(TOL).of(0.3124) # R18

    # Deeper dive into rf1 (more prevalent).
    targeted = model.getConstructionByName(rf1)
    expect(targeted).to_not be_empty
    targeted = targeted.get
    expect(targeted.to_LayeredConstruction).to_not be_empty
    targeted = targeted.to_LayeredConstruction.get
    expect(targeted.is_a?(OpenStudio::Model::LayeredConstruction)).to be true
    expect(targeted.layers.size).to eq(2)

    targeted.layers.each do |layer|
      next unless layer.nameString == "Typical Insulation R-9.53 1"
      expect(layer.to_MasslessOpaqueMaterial).to_not be_empty
      layer = layer.to_MasslessOpaqueMaterial.get
      expect(layer.thermalResistance).to be_within(TOL).of(1.68) # m2.K/W (R9.5)
    end

    # argh[:roof_option ] = "Typical Insulated Metal Building Roof R-10.31 1"
    argh                = {}
    argh[:roof_option ] = "ALL roof constructions"
    argh[:option      ] = "poor (BETBG)"
    argh[:uprate_roofs] = true
    argh[:roof_ut     ] = 0.138 # NECB 2017 (RSi 7.25 / R41)

    json     = TBD.process(model, argh)
    expect(json).to be_a(Hash)
    expect(json).to have_key(:io)
    expect(json).to have_key(:surfaces)
    io       = json[:io      ]
    surfaces = json[:surfaces]
    expect(TBD.status).to be_zero
    expect(TBD.logs).to be_empty
    expect(surfaces).to be_a(Hash)
    expect(surfaces.size).to eq(23)
    expect(io).to be_a(Hash)
    expect(io).to have_key(:edges)
    expect(io[:edges].size).to eq(300)

    bulk = "Bulk Storage Roof"
    fine = "Fine Storage Roof"

    # OpenStudio objects.
    bulk_roof = model.getSurfaceByName(bulk)
    fine_roof = model.getSurfaceByName(fine)
    expect(bulk_roof).to_not be_empty
    expect(fine_roof).to_not be_empty
    bulk_roof = bulk_roof.get
    fine_roof = fine_roof.get

    bulk_construction = bulk_roof.construction
    fine_construction = fine_roof.construction
    expect(bulk_construction).to_not be_empty
    expect(fine_construction).to_not be_empty

    bulk_construction = bulk_construction.get.to_LayeredConstruction
    fine_construction = fine_construction.get.to_LayeredConstruction
    expect(bulk_construction).to_not be_empty
    expect(fine_construction).to_not be_empty

    bulk_construction = bulk_construction.get
    fine_construction = fine_construction.get
    expect(bulk_construction.nameString).to eq("Bulk Storage Roof c tbd")
    expect(fine_construction.nameString).to eq("Fine Storage Roof c tbd")
    expect(bulk_construction.layers.size).to eq(2)
    expect(fine_construction.layers.size).to eq(2)

    bulk_insulation = bulk_construction.layers.at(1).to_MasslessOpaqueMaterial
    fine_insulation = fine_construction.layers.at(1).to_MasslessOpaqueMaterial
    expect(bulk_insulation).to_not be_empty
    expect(fine_insulation).to_not be_empty

    bulk_insulation   = bulk_insulation.get
    fine_insulation   = fine_insulation.get
    bulk_insulation_r = bulk_insulation.thermalResistance
    fine_insulation_r = fine_insulation.thermalResistance
    expect(bulk_insulation_r).to be_within(TOL).of(7.307) # once derated
    expect(fine_insulation_r).to be_within(TOL).of(6.695) # once derated

    # TBD objects.
    expect(surfaces).to have_key(bulk)
    expect(surfaces).to have_key(fine)
    expect(surfaces[bulk]).to have_key(:heatloss)
    expect(surfaces[fine]).to have_key(:heatloss)
    expect(surfaces[bulk]).to have_key(:net)
    expect(surfaces[fine]).to have_key(:net)

    expect(surfaces[bulk][:heatloss]).to be_within(TOL).of(161.02)
    expect(surfaces[fine][:heatloss]).to be_within(TOL).of( 87.16)
    expect(surfaces[bulk][:net     ]).to be_within(TOL).of(3157.28)
    expect(surfaces[fine][:net     ]).to be_within(TOL).of(1372.60)

    heatloss = surfaces[bulk][:heatloss] + surfaces[fine][:heatloss]
    area     = surfaces[bulk][:net     ] + surfaces[fine][:net     ]

    expect(heatloss).to be_within(TOL).of( 248.19)
    expect(area    ).to be_within(TOL).of(4529.88)

    expect(surfaces[bulk]).to have_key(:construction) # not yet derated
    expect(surfaces[fine]).to have_key(:construction)

    expect(surfaces[bulk][:construction].nameString).to eq(rf1)
    expect(surfaces[fine][:construction].nameString).to eq(rf1) # no longer rf2

    uprated = model.getConstructionByName(rf1) # not yet derated
    expect(uprated).to_not be_empty
    uprated = uprated.get
    expect(uprated.to_LayeredConstruction).to_not be_empty
    uprated = uprated.to_LayeredConstruction.get

    expect(uprated.is_a?(OpenStudio::Model::LayeredConstruction)).to be true
    expect(uprated.layers.size).to eq(2)
    uprated_layer_r = 0

    uprated.layers.each do |layer|
      next unless layer.nameString.include?(" uprated")

      expect(layer.to_MasslessOpaqueMaterial).to_not be_empty
      layer           = layer.to_MasslessOpaqueMaterial.get
      uprated_layer_r = layer.thermalResistance
      expect(layer.thermalResistance).to be_within(TOL).of(11.65) # m2.K/W (R66)
    end

    rt = TBD.rsi(uprated, roof1[:f])
    expect(1/rt).to be_within(TOL).of(0.0849) # R67 (with surface films)

    # Bulk storage roof demonstration.
    u = surfaces[bulk][:heatloss] / surfaces[bulk][:net]
    expect(u).to be_within(TOL).of(0.051) # W/m2.K

    de_u   = 1 / uprated_layer_r + u
    de_r   = 1 / de_u
    bulk_r = de_r + roof1[:f]
    bulk_u = 1 / bulk_r
    expect(de_u).to be_within(TOL).of(0.137) # bit below required Ut of 0.138
    expect(de_r).to be_within(TOL).of(bulk_insulation_r) # 7.307, not 11.65
    ratio  = -(uprated_layer_r - de_r) * 100 / (uprated_layer_r + roof1[:f])
    expect(ratio).to be_within(TOL).of(-36.84)
    expect(surfaces[bulk]).to have_key(:ratio)
    expect(surfaces[bulk][:ratio]).to be_within(TOL).of(ratio)

    # Fine storage roof demonstration.
    u = surfaces[fine][:heatloss] / surfaces[fine][:net]
    expect(u).to be_within(TOL).of(0.063) # W/m2.K

    de_u   = 1 / uprated_layer_r + u
    de_r   = 1 / de_u
    fine_r = de_r + roof1[:f]
    fine_u = 1 / fine_r
    expect(de_u).to be_within(TOL).of(0.149) # above required Ut of 0.138
    expect(de_r).to be_within(TOL).of(fine_insulation_r) # 6.695, not 11.65
    ratio  = -(uprated_layer_r - de_r) * 100 / (uprated_layer_r + roof1[:f])
    expect(ratio).to be_within(TOL).of(-42.03)
    expect(surfaces[fine]).to have_key(:ratio)
    expect(surfaces[fine][:ratio]).to be_within(TOL).of(ratio)

    ua    = bulk_u * surfaces[bulk][:net] + fine_u * surfaces[fine][:net]
    ave_u = ua / area
    expect(ave_u).to be_within(TOL).of(argh[:roof_ut]) # area-weighted average

    file = File.join(__dir__, "files/osms/out/up_warehouse.osm")
    model.save(file, true)
  end # NOT OK !!!
end
