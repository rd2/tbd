# In most cases, critical (and many non-critical) OSM anomalies would be caught
# by EnergyPlus at the start of a simulation (e.g., 5-sided windows). As TBD is
# is designed to run 'standalone' (e.g. Apply Measures Now), TBD shouldn't
# (or couldn't) strictly rely on EnergyPlus to catch such errors (and somehow
# warn users of potentially invalid results). TBD is designed to minimally log
# warnings, as well as non-fatal & fatal errors, that may put its internal
# processes at risk (e.g., red-flagging 5-sided windows in the .osm file). The
# presence of FATAL, ERROR or WARNING log entries in a generated TBD JSON file
# (saved under an OSM project 'files' folder) should be interpreted as 'bad',
# something to look into and/or remediate.

module TBD
  # EnergyPlus will run with out-of-range material or fluid properties. This
  # triggers an ERROR in EnergyPlus, but it's up to users to decide what to do
  # with simulation results. TBD attempts something similar.
  #
  # FATAL errors halts all TBD processes and prevents OpenStudio from launching
  # an EnergyPlus simulation. TBD will have but a few checks which would raise
  # FATAL cases. These would be mainly linked to missing, structurally invalid
  # or incomplete OSM or TBD files (or key file entries) e.g., badly structured
  # TBD JSON file, invalid OSM vertex transformation parameters, a missing or
  # incomplete TBD 'building' PSI set.
  #
  # The vast majority of TBD checks would log non-fatal ERROR messages when
  # encountering invalid OSM or TBD file entries (structurally sound, yet
  # invalid vis-à-vis TBD or EnergyPlus limitations). In such cases, the object
  # is simply ignored. TBD pursues its (otherwise valid) calculations, and
  # OpenStudio will ultimately launch an EnergyPlus simulation. If a simulation
  # indeed ran (ultimately a go/no-go by the EnergyPlus simulation engine), it
  # would be up to users to decide if the simulation results were valid, useful,
  # etc. given the context. An example would be TBD ignoring the thermal
  # bridging effects of 4x window edges, when the window has invalid frame &
  # divider (optional) inputs in the OSM. The insulation material of the host
  # surface may nonetheless be derated by the edges of its other (valid)
  # windows, but not by those of the poorly-defined one. In short, non-fatal
  # ERROR logs point to bad input a user can fix.
  #
  # TBD will emit very few WARN log messages. TBD warnings are mainly triggered
  # from inherit limitations of the underlying derating methodology (something
  # the user has limited control over beforehand). For instance, a surface the
  # size of a dinner plate has a very limited area to accommodate the additional
  # heat loss from thermal bridging (which may trigger a WARNING log message).
  # It's usually not a good idea to have such small surfaces in an OSM, but
  # neither OpenStudio nor EnergyPlus will necessarily warn users of such
  # occurrences. It's up to users to decide on the suitable course of action.
  #
  # TBD also offers the possiblity of logging informative messages (although
  # currently unused). Finally, TBD integrates a number of sanity checks to
  # ensure Ruby doesn't crash (e.g. invalid access to uninitialized variables),
  # especially for lower-level functions. When this occurs, there are safe
  # fallbacks and exists, but the DEBUG error is nonetheless logged by TBD.
  # DEBUG errors are almost always signs of a bug (to be fixed). This is for
  # strictly made available for development purposes - TBD does not offer a
  # 'production debugging' mode.
  DEBUG = 1 # for debugging
  INFO  = 2 # informative
  WARN  = 3 # e.g. unable to derate a material (too thin, too small)
  ERROR = 4 # e.g. out-of-range material k, 5-sided window, bad TBD JSON entry
  FATAL = 5 # e.g. fail to find/open OSM file, fail to translate file to OSM

  @@logs = []
  @@log_level = INFO

  @@tag = []
  @@tag[0]     = ""
  @@tag[DEBUG] = "DEBUG"
  @@tag[INFO]  = "INFO"
  @@tag[WARN]  = "WARNING"
  @@tag[ERROR] = "ERROR"
  @@tag[FATAL] = "FATAL"

  @@msg = []
  @@msg[0]     = ""
  @@msg[DEBUG] = "Debugging ..."
  @@msg[INFO]  = "Success! No errors, no warnings"
  @@msg[WARN]  = "Partial success, raised non-fatal warnings"
  @@msg[ERROR] = "Partial success, encountered non-fatal errors"
  @@msg[FATAL] = "Failure, triggered fatal errors"

  # Highest log level reached so far in TBD process sequence.
  @@log_status = 0

  def self.logs
    @@logs
  end

  def self.log_level
    @@log_level
  end

  def self.status
    @@log_status
  end

  def self.warn?
    return @@log_status == WARN
  end

  def self.error?
    return @@log_status == ERROR
  end

  def self.fatal?
    return @@log_status == FATAL
  end

  def self.tag(log_level)
    return @@tag[log_level] if log_level >= DEBUG && log_level <= FATAL
    return ""
  end

  def self.msg(log_status)
    return @@msg[log_status] if log_level >= DEBUG && log_level <= FATAL
    return ""
  end

  def self.set_log_level(log_level)
    @@log_level = log_level
  end

  def self.log(log_level, message)
    # puts "TBD: (#{TBD.tag(log_level)} vs #{TBD.tag(@@log_level)}) '#{message}'"
    if log_level >= @@log_level
      @@logs << { level: log_level, message: message }

      # May go from INFO to WARN, or to ERROR, or to FATAL
      @@log_status = log_level if log_level > @@log_status
    end
  end

  def self.clean!
    @@log_level = INFO
    @@log_status = 0
    @@logs = []
  end
end
