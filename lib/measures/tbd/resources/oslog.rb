# BSD 3-Clause License
#
# Copyright (c) 2022-2024, Denis Bourgeois
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
#    contributors may be used to endorse or promote products derived from
#    this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

module OSlg
  DEBUG = 1 # e.g. for debugging e.g. "argument String? expecting Integer"
  INFO  = 2 # e.g. informative e.g. "success! no errors, no warnings"
  WARN  = 3 # e.g. warnings e.g. "partial success, see non-fatal warnings"
  ERROR = 4 # e.g. erros e.g. "partial success, see non-fatal errors"
  FATAL = 5 # e.g. failures e.g. "stopping! encountered fatal errors"

  # each log is a Hash with keys :level (Integer) and :message (String)
  @@logs = []

  # preset strings matching log levels
  @@tag = [
           "", # (empty string)
      "DEBUG", # DEBUG
       "INFO", # INFO
    "WARNING", # WARNING
      "ERROR", # ERROR
      "FATAL"  # FATAL
  ].freeze

  # preset strings matching log status
  @@msg = [
                                                 "", # (empty string)
                                    "Debugging ...", # DEBUG
                  "Success! No errors, no warnings", # INFO
       "Partial success, raised non-fatal warnings", # WARNING
    "Partial success, encountered non-fatal errors", # ERROR
                  "Failure, triggered fatal errors"  # FATAL
  ].freeze

  @@level  = INFO # initial log level
  @@status = 0    # initial status

  ##
  # Returns log entries.
  #
  # @return [Array<Hash>] log entries (see @@logs)
  def logs
    @@logs
  end

  ##
  # Returns current log level.
  #
  # @return [DEBUG, INFO, WARN, ERROR, FATAL] log level
  def level
    @@level
  end

  ##
  # Returns current log status.
  #
  # @return [0, DEBUG, INFO, WARN, ERROR, FATAL] log status
  def status
    @@status
  end

  ##
  # Returns whether current status is DEBUG.
  #
  # @return [Bool] whether current log status is DEBUG
  def debug?
    @@status == DEBUG
  end

  ##
  # Returns whether current status is INFO.
  #
  # @return [Bool] whether current log status is INFO
  def info?
    @@status == INFO
  end

  ##
  # Returns whether current status is WARN.
  #
  # @return [Bool] whether current log status is WARN
  def warn?
    @@status == WARN
  end

  ##
  # Returns whether current status is ERROR.
  #
  # @return [Bool] whether current log status is ERROR
  def error?
    @@status == ERROR
  end

  ##
  # Returns whether current status is FATAL.
  #
  # @return [Bool] whether current log status is FATAL
  def fatal?
    @@status == FATAL
  end

  ##
  # Returns preset OSlg string that matches log level.
  #
  # @param lvl [#to_i] 0, DEBUG, INFO, WARN, ERROR or FATAL
  #
  # @return [String] preset OSlg tag (see @@tag)
  def tag(lvl)
    return "" unless lvl.respond_to?(:to_i)

    lvl = lvl.to_i
    return "" if lvl < DEBUG
    return "" if lvl > FATAL

    @@tag[lvl]

  end

  ##
  # Returns preset OSlg message that matches log status.
  #
  # @param stat [Integer] 0, DEBUG, INFO, WARN, ERROR or FATAL
  #
  # @return [String] preset OSlg message (see @@msg)
  def msg(stat)
    return "" unless stat.respond_to?(:to_i)

    stat = stat.to_i
    return "" if stat < DEBUG
    return "" if stat > FATAL

    @@msg[stat]
  end

  ##
  # Converts object to String and trims if necessary.
  #
  # @param txt [#to_s] a stringable object
  # @param length [#to_i] maximum return string length
  #
  # @return [String] a trimmed message string (empty unless stringable)
  def trim(txt = "", length = 60)
    length = 60 unless length.respond_to?(:to_i)
    length = length.to_i if length.respond_to?(:to_i)
    return "" unless txt.respond_to?(:to_s)

    txt = txt.to_s.strip
    txt = txt[0...length] + " ..." if txt.length > length

    txt
  end

  ##
  # Resets level, if lvl (input) is within accepted range.
  #
  # @param lvl [#to_i] DEBUG, INFO, WARN, ERROR or FATAL
  #
  # @return [DEBUG, INFO, WARN, ERROR, FATAL] updated/current level
  def reset(lvl = DEBUG)
    return @@level unless lvl.respond_to?(:to_i)

    lvl = lvl.to_i
    return @@level if lvl < DEBUG
    return @@level if lvl > FATAL

    @@level = lvl
  end

  ##
  # Logs a new entry, if provided arguments are valid.
  #
  # @param lvl [#to_i] DEBUG, INFO, WARN, ERROR or FATAL
  # @param message [#to_s] user-provided log message
  #
  # @example A user warning
  #   log(WARN, "Surface area < 100cm2")
  #
  # @return [DEBUG, INFO, WARN, ERROR, FATAL] updated/current status
  def log(lvl = DEBUG, message = "")
    return @@status unless lvl.respond_to?(:to_i)
    return @@status unless message.respond_to?(:to_s)

    lvl = lvl.to_i
    message = message.to_s
    return @@status if lvl < DEBUG
    return @@status if lvl > FATAL
    return @@status if lvl < @@level

    @@logs << {level: lvl, message: message}
    return @@status unless lvl > @@status

    @@status = lvl
  end

  ##
  # Logs template 'invalid object' message, if provided arguments are valid.
  #
  # @param id [#to_s] 'invalid object' identifier
  # @param mth [#to_s] calling method identifier
  # @param ord [#to_i] calling method argument order number of obj (optional)
  # @param lvl [#to_i] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res what to return (optional)
  #
  # @example An invalid argument, logging a FATAL error, returning FALSE
  #   return invalid("area", "sum", 0, FATAL, false) if area > 1000000
  #
  # @return user-provided object
  # @return [nil] if user hasn't provided an object to return
  def invalid(id = "", mth = "", ord = 0, lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless ord.respond_to?(:to_i)
    return res unless lvl.respond_to?(:to_i)

    ord = ord.to_i
    lvl = lvl.to_i
    id  = trim(id)
    mth = trim(mth)
    return res if id.empty?
    return res if mth.empty?
    return res if lvl < DEBUG
    return res if lvl > FATAL

    msg = "Invalid '#{id}' "
    msg += "arg ##{ord} " if ord > 0
    msg += "(#{mth})"
    log(lvl, msg)

    res
  end

  ##
  # Logs template 'instance/class mismatch' message, if provided arguments are
  # valid. The message is not logged if the provided object to evaluate is an
  # actual instance of the target class.
  #
  # @param id [#to_s] mismatched object identifier
  # @param obj the object to validate
  # @param cl [Class] target class
  # @param mth [#to_s] calling method identifier (optional)
  # @param lvl [#to_i] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res what to return (optional)
  #
  # @example A mismatched argument instance/class
  #   mismatch("area", area, Float, "sum") unless area.is_a?(Numeric)
  #
  # @return user-provided object
  # @return [nil] if user hasn't provided an object to return
  def mismatch(id = "", obj = nil, cl = nil, mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless cl.is_a?(Class)
    return res if obj.is_a?(cl)
    return res unless lvl.respond_to?(:to_i)

    lvl = lvl.to_i
    id  = trim(id)
    mth = trim(mth)
    return res if id.empty?
    return res if mth.empty?
    return res if lvl < DEBUG
    return res if lvl > FATAL

    log(lvl, "'#{id}' #{obj.class}? expecting #{cl} (#{mth})")

    res
  end

  ##
  # Logs template 'missing hash key' message, if provided arguments are valid.
  # The message is not logged if the provided key exists.
  #
  # @param id [#to_s] Hash identifier
  # @param hsh [Hash] hash to validate
  # @param key missing key
  # @param mth [#to_s] calling method identifier
  # @param lvl [#to_i] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res what to return (optional)
  #
  # @example A missing Hash key
  #   hashkey("floor area", floor, :area, "sum") unless floor.key?(:area)
  #
  # @return user-provided object
  # @return [nil] if user hasn't provided an object to return
  def hashkey(id = "", hsh = {}, key = "", mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless hsh.is_a?(Hash)
    return res if hsh.key?(key)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    lvl = lvl.to_i
    id  = trim(id)
    mth = trim(mth)
    return res if id.empty?
    return res if mth.empty?
    return res if lvl < DEBUG
    return res if lvl > FATAL

    log(lvl, "Missing '#{key}' key in '#{id}' Hash (#{mth})")

    res
  end

  ##
  # Logs template 'empty' message, if provided arguments are valid.
  #
  # @param id [#to_s] empty object identifier
  # @param mth [#to_s] calling method identifier
  # @param lvl [#to_i] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res what to return (optional)
  #
  # @example An uninitialized variable, logging an ERROR, returning FALSE
  #   empty("zone", "conditioned?", FATAL, false) if space.thermalZone.empty?
  #
  # @return user-provided object
  # @return [nil] if user hasn't provided an object to return
  def empty(id = "", mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    lvl = lvl.to_i
    id  = trim(id)
    mth = trim(mth)
    return res if id.empty?
    return res if mth.empty?
    return res if lvl < DEBUG
    return res if lvl > FATAL

    log(lvl, "Empty '#{id}' (#{mth})")

    res
  end

  ##
  # Logs template 'zero' value message, if provided arguments are valid.
  #
  # @param id [#to_s] zero object identifier
  # @param mth [#to_s] calling method identifier
  # @param lvl [#to_i] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res what to return (optional)
  #
  # @example A near-zero variable
  #   zero("floor area", "sum") if floor[:area].abs < TOL
  #
  # @return user-provided object
  # @return [nil] if user hasn't provided an object to return
  def zero(id = "", mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    ord = ord.to_i
    lvl = lvl.to_i
    id  = trim(id)
    mth = trim(mth)
    return res if id.empty?
    return res if mth.empty?
    return res if lvl < DEBUG
    return res if lvl > FATAL

    log(lvl, "Zero '#{id}' (#{mth})")

    res
  end

  ##
  # Logs template 'negative' message, if provided arguments are valid.
  #
  # @param id [#to_s] negative object identifier
  # @param mth [String] calling method identifier
  # @param lvl [Integer] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res [Object] what to return (optional)
  #
  # @example A negative variable
  #   negative("floor area", "sum") if floor[:area] < 0
  #
  # @return user-provided object
  # @return [nil] if user hasn't provided an object to return
  def negative(id = "", mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    lvl = lvl.to_i
    id  = trim(id)
    mth = trim(mth)
    return res if id.empty?
    return res if mth.empty?
    return res if lvl < DEBUG
    return res if lvl > FATAL

    log(lvl, "Negative '#{id}' (#{mth})")

    res
  end

  ##
  # Resets log status and entries.
  #
  # @return [Integer] current log level
  def clean!
    @@status = 0
    @@logs   = []

    @@level
  end

  ##
  # Callback when other modules extend OSlg
  #
  # @param base [Object] instance or class object
  def self.extended(base)
    base.send(:include, self)
  end
end
