# BSD 3-Clause License
#
# Copyright (c) 2022, Denis Bourgeois
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
  DEBUG        = 1
  INFO         = 2
  WARN         = 3
  ERROR        = 4
  FATAL        = 5

  @@logs       = []
  @@level      = INFO
  @@status     = 0

  @@tag        = []
  @@tag[0    ] = ""
  @@tag[DEBUG] = "DEBUG"
  @@tag[INFO ] = "INFO"
  @@tag[WARN ] = "WARNING"
  @@tag[ERROR] = "ERROR"
  @@tag[FATAL] = "FATAL"

  @@msg        = []
  @@msg[0    ] = ""
  @@msg[DEBUG] = "Debugging ..."
  @@msg[INFO ] = "Success! No errors, no warnings"
  @@msg[WARN ] = "Partial success, raised non-fatal warnings"
  @@msg[ERROR] = "Partial success, encountered non-fatal errors"
  @@msg[FATAL] = "Failure, triggered fatal errors"

  ##
  # Return log entries.
  #
  # @return [Array] current log entries
  def logs
    @@logs
  end

  ##
  # Return current log level.
  #
  # @return [Integer] DEBUG, INFO, WARN, ERROR or FATAL
  def level
    @@level
  end

  ##
  # Return current log status.
  #
  # @return [Integer] DEBUG, INFO, WARN, ERROR or FATAL
  def status
    @@status
  end

  ##
  # Return whether current status is DEBUG
  #
  # @return [Bool] true if DEBUG
  def debug?
    @@status == DEBUG
  end

  ##
  # Return whether current status is INFO
  #
  # @return [Bool] true if INFO
  def info?
    @@status == INFO
  end

  ##
  # Return whether current status is WARN
  #
  # @return [Bool] true if WARN
  def warn?
    @@status == WARN
  end

  ##
  # Return whether current status is ERROR
  #
  # @return [Bool] true if ERROR
  def error?
    @@status == ERROR
  end

  ##
  # Return whether current status is FATAL
  #
  # @return [Bool] true if FATAL
  def fatal?
    @@status == FATAL
  end

  ##
  # Return string equivalent of level
  #
  # @param level [Integer] DEBUG, INFO, WARN, ERROR or FATAL
  #
  # @return [String] "DEBUG", "INFO", "WARN", "ERROR" or "FATAL"
  def tag(level)
    return @@tag[level] if level >= DEBUG && level <= FATAL
    ""
  end

  ##
  # Return preset OSlg message linked to status.
  #
  # @param status [Integer] DEBUG, INFO, WARN, ERROR or FATAL
  #
  # @return [String] preset OSlg message
  def msg(status)
    return @@msg[status] if status >= DEBUG && status <= FATAL
    ""
  end

  ##
  # Set level.
  #
  # @param level [Integer] DEBUG, INFO, WARN, ERROR or FATAL
  #
  # @return [Integer] current level
  def reset(level)
    @@level = level if level >= DEBUG && level <= FATAL
  end

  ##
  # Log new entry.
  #
  # @param level [Integer] DEBUG, INFO, WARN, ERROR or FATAL
  # @param message [String] user-provided message
  #
  # @return [Integer] current status
  def log(level = DEBUG, message = "")
    if level >= DEBUG && level <= FATAL && level >= @@level
      @@logs << {level: level, message: message}
      @@status = level if level > @@status
    end
    @@status
  end

  ##
  # Log template 'invalid object' message and return user-set object.
  #
  # @param id [String] invalid object identifier
  # @param mth [String] calling method identifier
  # @param ord [Integer] calling method argument order number of obj (optional)
  # @param lvl [Integer] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res [Object] what to return (optional)
  #
  # @return [Object] return object if specified by user
  # @return [Nil] nil if return object undefined
  def invalid(id = "", mth = "", ord = 0, lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless ord.respond_to?(:to_i)
    return res unless lvl.respond_to?(:to_i)

    id  = id.to_s.strip
    mth = mth.to_s.strip
    ord = ord.to_i
    lvl = lvl.to_i

    id = id[0...60] + " ..." if id.length > 60
    return res if id.empty?

    mth = mth[0...60] + " ..." if mth.length > 60
    return res if mth.empty?

    msg  = "Invalid '#{id}' "
    msg += "arg ##{ord} " if ord > 0
    msg += "(#{mth})"
    log(lvl, msg) if lvl >= DEBUG && lvl <= FATAL
    res
  end

  ##
  # Log template 'instance/class mismatch' message and return user-set object.
  #
  # @param id [String] mismatched object identifier
  # @param obj [Object] object to validate
  # @param cl [Class] target class
  # @param mth [String] calling method identifier
  # @param lvl [Integer] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res [Object] what to return (optional)
  #
  # @return [Object] return object if specified by user
  # @return [Nil] nil if return object undefined
  def mismatch(id = "", obj = nil, cl = nil, mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless cl.is_a?(Class)
    return res if obj.is_a?(cl)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    mth = mth.to_s.strip
    id  = id.to_s.strip
    lvl = lvl.to_i

    id = id[0...60] + " ..." if id.length > 60
    return res if id.empty?

    mth = mth[0...60] + " ..." if mth.length > 60
    return res if mth.empty?

    msg = "'#{id}' #{obj.class}? expecting #{cl} (#{mth})"
    log(lvl, msg) if lvl >= DEBUG && lvl <= FATAL
    res
  end

  ##
  # Log template 'missing hash key' message and return user-set object.
  #
  # @param id [String] Hash identifier
  # @param hsh [Hash] hash to validate
  # @param key [Object] missing key
  # @param mth [String] calling method identifier
  # @param lvl [Integer] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res [Object] what to return (optional)
  #
  # @return [Object] return object if specified by user
  # @return [Nil] nil if return object undefined
  def hashkey(id = "", hsh = {}, key = "", mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless hsh.is_a?(Hash)
    return res if hsh.key?(key)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    id  = id.to_s.strip
    mth = mth.to_s.strip
    lvl = lvl.to_i

    id = id[0...60] + " ..." if id.length > 60
    return res if id.empty?

    mth = mth[0...60] + " ..." if mth.length > 60
    return res if mth.empty?

    msg  = "Missing '#{key}' key in '#{id}' Hash (#{mth})"
    log(lvl, msg) if lvl >= DEBUG && lvl <= FATAL
    res
  end

  ##
  # Log template 'empty (uninitialized)' message and return user-set object.
  #
  # @param id [String] empty object identifier
  # @param mth [String] calling method identifier
  # @param lvl [Integer] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res [Object] what to return (optional)
  #
  # @return [Object] return object if specified by user
  # @return [Nil] nil if return object undefined
  def empty(id = "", mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    id  = id.to_s.strip
    mth = mth.to_s.strip
    lvl = lvl.to_i

    id = id[0...60] + " ..." if id.length > 60
    return res if id.empty?

    mth = mth[0...60] + " ..." if mth.length > 60
    return res if mth.empty?

    msg  = "Empty '#{id}' (#{mth})"
    log(lvl, msg) if lvl >= DEBUG && lvl <= FATAL
    res
  end

  ##
  # Log template 'near zero' message and return user-set object.
  #
  # @param id [String] zero object identifier
  # @param mth [String] calling method identifier
  # @param lvl [Integer] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res [Object] what to return (optional)
  #
  # @return [Object] return object if specified by user
  # @return [Nil] nil if return object undefined
  def zero(id = "", mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    id  = id.to_s.strip
    mth = mth.to_s.strip
    ord = ord.to_i
    lvl = lvl.to_i

    id = id[0...60] + " ..." if id.length > 60
    return res if id.empty?

    mth = mth[0...60] + " ..." if mth.length > 60
    return res if mth.empty?

    msg  = "Zero '#{id}' (#{mth})"
    log(lvl, msg) if lvl >= DEBUG && lvl <= FATAL
    res
  end

  ##
  # Log template 'negative' message and return user-set object.
  #
  # @param id [String] negative object identifier
  # @param mth [String] calling method identifier
  # @param lvl [Integer] DEBUG, INFO, WARN, ERROR or FATAL (optional)
  # @param res [Object] what to return (optional)
  #
  # @return [Object] return object if specified by user
  # @return [Nil] nil if return object undefined
  def negative(id = "", mth = "", lvl = DEBUG, res = nil)
    return res unless id.respond_to?(:to_s)
    return res unless mth.respond_to?(:to_s)
    return res unless lvl.respond_to?(:to_i)

    id  = id.to_s.strip
    mth = mth.to_s.strip
    ord = ord.to_i
    lvl = lvl.to_i

    id = id[0...60] + " ..." if id.length > 60
    return res if id.empty?

    mth = mth[0...60] + " ..." if mth.length > 60
    return res if mth.empty?
    
    msg  = "Negative '#{id}' (#{mth})"
    log(lvl, msg) if lvl >= DEBUG && lvl <= FATAL
    res
  end

  ##
  # Reset log status and entries.
  #
  # @return [Integer] current level
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
