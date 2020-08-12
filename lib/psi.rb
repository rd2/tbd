class PSI
  # @return [Hash] PSI set
  attr_reader :set

  def initialize
    @set = {}

    # The following examples are defaults (* stated, ** presumed). Users may edit
    # these sets, add new sets, or even read-in other sets on file.
    @set[ "poor (BC Hydro)" ] =
    {
      rimjoist:     1.000, # *
      parapet:      0.800, # *
      fenestration: 0.500, # *
      concave:      0.850, # *
      convex:       0.850, # *
      balcony:      1.000, # *
      party:        1.000, # **
      grade:        1.000  # **
    }.freeze

    @set[ "regular (BC Hydro)" ] =
    {
      rimjoist:     0.500, # *
      parapet:      0.450, # *
      fenestration: 0.350, # *
      concave:      0.450, # *
      convex:       0.450, # *
      balcony:      0.500, # *
      party:        0.500, # **
      grade:        0.450  # *
    }.freeze

    @set[ "efficient (BC Hydro)" ] =
    {
      rimjoist:     0.200, # *
      parapet:      0.200, # *
      fenestration: 0.200, # *
      concave:      0.200, # *
      convex:       0.200, # *
      balcony:      0.200, # *
      party:        0.200, # *
      grade:        0.200  # *
    }.freeze
    # www.bchydro.com/content/dam/BCHydro/customer-portal/documents/power-smart/
    # business/programs/BETB-Building-Envelope-Thermal-Bridging-Guide-v1-3.pdf

    @set[ "code (Quebec)" ] = # NECB-QC (code-compliant) defaults:
    {
      rimjoist:     0.300, # *
      parapet:      0.325, # *
      fenestration: 0.350, # **
      concave:      0.450, # **
      convex:       0.450, # **
      balcony:      0.500, # *
      party:        0.500, # **
      grade:        0.450  # *
    }.freeze
    # www2.publicationsduquebec.gouv.qc.ca/dynamicSearch/telecharge.php?type=1&file=72541.pdf

    @set[ "(without thermal bridges)" ] = # ... would not derate surfaces:
    {
      rimjoist:     0.000, #
      parapet:      0.000, #
      fenestration: 0.000, #
      concave:      0.000, #
      convex:       0.000, #
      balcony:      0.000, #
      party:        0.000, # **
      grade:        0.000  # *
    }.freeze
  end
end
