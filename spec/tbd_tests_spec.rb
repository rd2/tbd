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
    TBD.clean!
    argh               = {}
    argh[:option     ] = "(non thermal bridging)"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_seb_n2.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    tr    = OpenStudio::OSVersion::VersionTranslator.new
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = tr.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get
    json  = TBD.process(model, argh)

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
    TBD.clean!
    name               = "Entryway  Wall 5"
    argh               = {}
    argh[:option     ] = "(non thermal bridging)"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_seb_n4.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")

    tr    = OpenStudio::OSVersion::VersionTranslator.new
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = tr.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get
    json  = TBD.process(model, argh)

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
    TBD.clean!
    ref                = "code (Quebec)"
    argh               = {}
    argh[:option     ] = "poor (BETBG)"
    argh[:seed       ] = "./files/osms/in/warehouse.osm"
    argh[:io_path    ] = File.join(__dir__, "../json/tbd_warehouse10.json")
    argh[:schema_path] = File.join(__dir__, "../tbd.schema.json")
    argh[:gen_ua     ] = true
    argh[:ua_ref     ] = ref
    argh[:version    ] = OpenStudio.openStudioVersion

    tr    = OpenStudio::OSVersion::VersionTranslator.new
    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = tr.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    spts  = TBD.heatingTemperatureSetpoints?(model)
    spts  = TBD.coolingTemperatureSetpoints?(model) || spts
    lps   = TBD.airLoopsHVAC?(model)

    expect(spts).to be(true)
    expect(lps ).to be(true)

    model.getSpaces.each do |space|
      expect(space.thermalZone.empty?     ).to be(false)
      expect(TBD.plenum?(space, lps, spts)).to be(false)

      zone     = space.thermalZone.get
      heat_spt = TBD.maxHeatScheduledSetpoint(zone)
      cool_spt = TBD.minCoolScheduledSetpoint(zone)
      expect(heat_spt.key?(:spt)).to be(true)
      expect(cool_spt.key?(:spt)).to be(true)
      heating  = heat_spt[ :spt]
      cooling  = cool_spt[ :spt]

      if    zone.nameString == "Zone1 Office ZN"
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
            l: "Bulk Storage Right Wall" }.freeze

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
            n: "Overhead Door 7" }.freeze

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
              b: "Office Front Wall Window2" }.freeze

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
    tr    = OpenStudio::OSVersion::VersionTranslator.new
    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = tr.loadModel(path)
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
    # edge types sharing the exact same PSI value (e.g. 0.3 W/K per m), the
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
    TBD.clean!
    argh1 = { option: "poor (BETBG)" }
    argh2 = { option: "poor (BETBG)" }
    argh3 = { option: "poor (BETBG)" }
    tr    = OpenStudio::OSVersion::VersionTranslator.new
    file  = File.join(__dir__, "files/osms/in/warehouse.osm")
    path  = OpenStudio::Path.new(file)
    model = tr.loadModel(path)
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

    out = JSON.pretty_generate(argh1[:io])
    outP = File.join(__dir__, "../json/tbd_warehouse12.out.json")
    File.open(outP, "w") { |outP| outP.puts out }

    TBD.clean!
    fil  = File.join(__dir__, "files/osms/out/alt_warehouse.osm")
    pth  = OpenStudio::Path.new(fil)
    mdl  = tr.loadModel(pth)
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

    out2 = JSON.pretty_generate(argh2[:io])
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
    model = tr.loadModel(path)
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
    TBD.clean!
    argh            = {}
    argh[:option  ] = "poor (BETBG)"
    argh[:gen_kiva] = true

    tr    = OpenStudio::OSVersion::VersionTranslator.new
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = tr.loadModel(path)
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

    # Re-open for testing.
    path  = OpenStudio::Path.new(file)
    model = tr.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    oa1f = model.getSurfaceByName("Open area 1 Floor")
    expect(oa1f.empty?).to be(false)
    oa1f = oa1f.get
    expect(oa1f.outsideBoundaryCondition.downcase).to eq("foundation")
    foundation = oa1f.adjacentFoundation
    expect(foundation.empty?).to be(false)
    foundation = foundation.get

    oa15 = model.getSurfaceByName("Openarea 1 Wall 5")              # 3.89m wide
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

    # Re-open & test initial model.
    TBD.clean!
    file  = File.join(__dir__, "files/osms/in/seb.osm")
    path  = OpenStudio::Path.new(file)
    model = tr.loadModel(path)
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

    json      = TBD.process(model, argh)
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

  it "can test 5ZoneNoHVAC (failed) uprating" do
    v = OpenStudio.openStudioVersion.split(".").map(&:to_i).join.to_i

    if v < 350 # 5ZoneNoHVAC holds an Air Wall material (deprecated +v3.5).
      TBD.clean!
      argh  = { option: "efficient (BETBG)" }
      walls = []
      id    = "ASHRAE 189.1-2009 ExtWall Mass ClimateZone 5"
      tr    = OpenStudio::OSVersion::VersionTranslator.new
      file  = File.join(__dir__, "files/osms/in/5ZoneNoHVAC.osm")
      path  = OpenStudio::Path.new(file)
      model = tr.loadModel(path)
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

      json      = TBD.process(model, argh)
      expect(json.is_a?(Hash)    ).to be(true)
      expect(json.key?(:io      )).to be(true)
      expect(json.key?(:surfaces)).to be(true)
      io        = json[:io      ]
      surfaces  = json[:surfaces]
      expect(TBD.status.zero?    ).to be(true)
      expect(TBD.logs.empty?     ).to be(true)

      walls.each do |wall|
        expect(surfaces.key?(wall)           ).to be(true)
        expect(surfaces[wall].key?(:heatloss)).to be(true)

        long  = (surfaces[wall][:heatloss] - 27.746).abs < TOL  # 40 metres wide
        short = (surfaces[wall][:heatloss] - 14.548).abs < TOL  # 20 metres wide
        valid = long || short
        expect(valid).to be(true)
      end

      # The 4-sided model has 2x "long" front/back + 2x "short" side exterior
      # walls, with a total TBD-calculated heat loss (from thermal bridging) of:
      #
      #   2x 27.746 W/K + 2x 14.548 W/K = ~84.588 W/K
      #
      # Spread over ~273.6 m2 of gross wall area, that is A LOT! Why (given the
      # "efficient" PSI values)? Each wall has a long "strip" window, almost the
      # full wall width (reaching to within a few millimetres of each corner).
      # This ~slices the host wall into 2x very narrow strips. Although the
      # thermal bridging details are considered "efficient", the total length of
      # linear thermal bridges is very high given the limited exposed (gross)
      # area. If area-weighted, derating the insulation layer of the referenced
      # wall construction above would entail factoring in this extra thermal
      # conductance of ~0.309 W/m2.K (84.6/273.6), which would reduce the
      # insulation thickness quite significantly.
      #
      #   Ut = Uo + ( ∑psi • L )/A
      #
      # Expressed otherwise:
      #
      #   Ut = Uo + 0.309
      #
      # So what initial Uo value should the construction offer (prior to
      # derating) to ensure compliance with NECB2017/2020 prescriptive
      # requirements (one of the few energy codes with prescriptive Ut
      # requirements)? For climate zone 7, the target Ut is 0.210 W/m2.K (Rsi
      # 4.76 m2.K/W or R27). Taking into account air film resistances and
      # non-insulating layer resistances (e.g. ~Rsi 1 m2.K/W), the prescribed
      # (max) layer Ut becomes ~0.277 (Rsi 3.6 or R20.5).
      #
      #   0.277 = Uo? + 0.309
      #
      # Duh-oh! Even with an infinitely thick insulation layer (Uo ~= 0), it
      # would be impossible to reach NECB2017/2020 prescritive requirements with
      # "efficient" thermal breaks. Solutions? Eliminate windows :\ Otherwise,
      # further improve detailing as to achieve ~0.1 W/K per linear metre
      # (easier said than done). Here, an average PSI value of 0.150 W/K per
      # linear metre (i.e. ~76.1 W/K instead of ~84.6 W/K) still won't cut it
      # for a Uo of 0.01 W/m2.K (Rsi 100 or R568). Instead, an average PSI value
      # of 0.090 (~45.6 W/K, very high performance) would allow compliance for a
      # Uo of 0.1 W/m2.K (Rsi 10 or R57, ... $$$).
      #
      # Long story short: there will inevitably be cases where TBD is unable to
      # "uprate" a construction prior to "derating". This is neither a TBD bug
      # nor an RP-1365/ISO model limitation. It is simply "bad" input, although
      # likely unintentional. Nevertheless, TBD should exit in such cases with
      # an ERROR message.
      #
      # And if one were to instead model each of the OpenStudio walls described
      # above as 2x distinct OpenStudio surfaces? e.g.:
      #   - 95% of exposed wall area Uo 0.01 W/m2.K
      #   - 5% of exposed wall area as a "thermal bridge" strip (~5.6 W/m2.K *)
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
      #
      # Retrying the previous example, yet requesting uprating calculations:
      TBD.clean!
      argh                = {}
      argh[:option      ] = "efficient (BETBG)"
      argh[:uprate_walls] = true
      argh[:uprate_roofs] = true
      argh[:wall_option ] = "ALL wall constructions"
      argh[:roof_option ] = "ALL roof constructions"
      argh[:wall_ut     ] = 0.210               # NECB CZ7 2017 (RSi 4.76 / R27)
      argh[:roof_ut     ] = 0.138               # NECB CZ7 2017 (RSi 7.25 / R41)

      model = tr.loadModel(path)
      expect(model.empty?).to be(false)
      model = model.get
      json  = TBD.process(model, argh)

      expect(json.is_a?(Hash    )).to be( true)
      expect(json.key?(:io      )).to be( true)
      expect(json.key?(:surfaces)).to be( true)
      io        = json[:io      ]
      surfaces  = json[:surfaces]
      expect(TBD.error?          ).to be( true)
      expect(TBD.logs.empty?     ).to be(false)
      expect(TBD.logs.size       ).to eq(    2)

      expect(TBD.logs.first[:message].include?("Zero")            ).to be(true)
      expect(TBD.logs.first[:message].include?(": new Rsi")       ).to be(true)
      expect(TBD.logs.last[ :message].include?("Unable to uprate")).to be(true)

      expect(argh.key?(:wall_uo)).to be(false)
      expect(argh.key?(:roof_uo)).to be( true)
      expect(argh[:roof_uo].nil?).to be(false)
      expect(argh[:roof_uo]     ).to be_within(TOL).of(0.118)   # RSi 8.47 (R48)

      # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
      TBD.clean!
      argh                = {}
      argh[:io_path     ] = File.join(__dir__, "../json/tbd_5ZoneNoHVAC.json")
      argh[:schema_path ] = File.join(__dir__, "../tbd.schema.json")
      argh[:uprate_walls] = true
      argh[:uprate_roofs] = true
      argh[:wall_option ] = "ALL wall constructions"
      argh[:roof_option ] = "ALL roof constructions"
      argh[:wall_ut     ] = 0.210               # NECB CZ7 2017 (RSi 4.76 / R27)
      argh[:roof_ut     ] = 0.138               # NECB CZ7 2017 (RSi 7.25 / R41)

      walls = []
      model = tr.loadModel(path)
      expect(model.empty?).to be(false)
      model = model.get
      json  = TBD.process(model, argh)

      expect(json.is_a?(Hash)    ).to be( true)
      expect(json.key?(:io      )).to be( true)
      expect(json.key?(:surfaces)).to be( true)
      io        = json[:io      ]
      surfaces  = json[:surfaces]
      expect(TBD.status.zero?    ).to be( true)
      expect(argh.key?(:wall_uo) ).to be( true)
      expect(argh.key?(:roof_uo) ).to be( true)
      expect(argh[:wall_uo].nil? ).to be(false)
      expect(argh[:roof_uo].nil? ).to be(false)

      expect(argh[:wall_uo]).to be_within(TOL).of(0.086)       # RSi 11.63 (R66)
      expect(argh[:roof_uo]).to be_within(TOL).of(0.129)       # RSi  7.75 (R44)

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
        th  = th1 || th2                  # depending if 'short' or 'long' walls
        expect(th).to be(true)
      end

      walls.each do |wall|
        expect(surfaces.key?(wall)).to be(true)
        # r: uprated, non-derated layer Rsi
        # u: uprated, non-derated assembly
        expect(surfaces[wall].key?(:r)).to be(true)
        expect(surfaces[wall].key?(:u)).to be(true)

        expect(surfaces[wall][:r]).to be_within(0.001).of(11.205)          # R64
        expect(surfaces[wall][:u]).to be_within(0.001).of( 0.086)          # R66
      end

      # -- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- ---- -- #
      # Final attempt, with PSI values of 0.09 W/K per linear metre (JSON file).
      v = OpenStudio.openStudioVersion.split(".").map(&:to_i).join.to_i

      unless v < 320
        TBD.clean!
        argh  = {}
        argh[:io_path] = File.join(__dir__, "../json/tbd_5ZoneNoHVAC_btap.json")
        file  = File.join(__dir__, "files/osms/in/5ZoneNoHVAC_btap.osm")
        path  = OpenStudio::Path.new(file)
        model = tr.loadModel(path)
        expect(model.empty?).to be(false)
        model = model.get

        argh[:schema_path ] = File.join(__dir__, "../tbd.schema.json")
        argh[:uprate_walls] = true
        argh[:wall_option ] = "ALL wall constructions"
        argh[:wall_ut     ] = 0.210             # NECB CZ7 2017 (RSi 4.76 / R41)

        json      = TBD.process(model, argh)
        expect(json.is_a?(Hash)    ).to be(true)
        expect(json.key?(:io      )).to be(true)
        expect(json.key?(:surfaces)).to be(true)
        io        = json[:io      ]
        surfaces  = json[:surfaces]
        expect(TBD.error?         ).to be( true)
        expect(TBD.logs.empty?    ).to be(false)
        expect(TBD.logs.size      ).to eq(    2)

        expect(TBD.logs.first[:message].include?("Invalid")).to         be(true)
        expect(TBD.logs.first[:message].include?("Can't uprate ")).to   be(true)
        expect(TBD.logs.last[:message].include?("Unable to uprate")).to be(true)

        expect(argh.key?(:wall_uo)).to be(false)
        expect(argh.key?(:roof_uo)).to be(false)
      end
    end
  end

  it "can test Hash inputs" do
    TBD.clean!
    input  = {}
    schema = "https://github.com/rd2/tbd/blob/master/tbd.schema.json"
    tr     = OpenStudio::OSVersion::VersionTranslator.new
    file   = File.join(__dir__, "files/osms/in/seb.osm")
    path   = OpenStudio::Path.new(file)
    model  = tr.loadModel(path)
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

    json      = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be( true)
    expect(json.key?(:io      )).to be( true)
    expect(json.key?(:surfaces)).to be( true)
    io        = json[:io      ]
    surfaces  = json[:surfaces]
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

  it "can process floorszone multipliers" do
    TBD.clean!
    argh           = {}
    argh[:option ] = "code (Quebec)"

    file  = File.join(__dir__, "files/osms/in/midrise_KIVA.osm")
    path  = OpenStudio::Path.new(file)
    tr    = OpenStudio::OSVersion::VersionTranslator.new
    model = tr.loadModel(path)
    expect(model.empty?).to be(false)
    model = model.get

    json      = TBD.process(model, argh)
    expect(json.is_a?(Hash)    ).to be(true)
    expect(json.key?(:io      )).to be(true)
    expect(json.key?(:surfaces)).to be(true)
    io        = json[:io      ]
    surfaces  = json[:surfaces]
    expect(TBD.status.zero?    ).to be(true)
    expect(TBD.logs.empty?     ).to be(true)

    model.getSurfaces.each do |surface|
      id = surface.nameString
      next unless surface.surfaceType.downcase == "floor"
      next     if surface.isGroundSurface

      facing = surface.outsideBoundaryCondition.downcase
      floor  = id.downcase.include?("floor")
      top    = id.downcase.include?("t ")
      mid    = id.downcase.include?("m ")
      expect(floor && (top || mid)).to be(true)
      expect(facing).to eq("adiabatic")

      io[:edges].each do |edge|
        next unless edge[:surfaces].include?(id)

        expect(edge[:type]).to eq(:rimjoist)
      end
    end
  end
end
