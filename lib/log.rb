# In most cases, critical (and many non-critical) OSM anomalies would be caught
# by EnergyPlus at the start of a simulation (should list a few examples). As
# TBD is designed to run 'standalone' (e.g. Apply Measures Now), TBD shouldn't
# (or couldn't) strictly rely on EnergyPlus to catch such errors (and somehow
# warn users of potentially invalid results). TBD is designed to minimally log
# warnings, non-fatal & fatal errors that may put its internal processes at risk
# (should list a few examples). The presence of a "tbd.log" file in an OSM
# project 'files' folder should be interpreted as 'bad' - something to look into
# and/or remediate.
module TBD
  DEBUG = 1 # for debugging
  INFO  = 2 # informative e.g. derating successful for a given surface
  WARN  = 3 # very few ...
  ERROR = 4 # e.g. out-of-range material conductivity, 5-sided window, TBD file
  FATAL = 5 # e.g. fail to find/open OSM file, fail to translate file to OSM

  # Aiming for similar OS/E+ logic concerning anomalies. For instance, E+ will
  # still run with out-of-range material or fluid properties. This triggers an
  # ERROR in E+, but it's up to users to decide what to do with sim results.
  #
  # Given that, TBD will have but a few checks which could raise FATAL cases
  # (see examples above). The remainder of TBD checks would trigger ERROR
  # logs, where either part of an OSM is ignored (e.g., 5-sided window) or TBD
  # exits without derating altogether (yet still have an E+ simulation run).
  # Consequently, TBD will emit very few WARN log messages.
  #
  # https://energyplus.net/sites/default/files/docs/site_v8.3.0/
  # Tips_and_Tricks_Using_EnergyPlus/Tips_and_Tricks_Using_EnergyPlus/
  # index.html#example-error-messages-for-the-input-processor

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

  # Highest log level reached so far in TBD process sequence. Setting this to
  # lower than WARN (i.e., below minimal level triggering a "tbd.log" file).
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
