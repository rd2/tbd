# MIT License
#
# Copyright (c) 2020-2023 Denis Bourgeois & Dan Macumber
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

require "openstudio"

begin
  # Try to load from the Topolys gem.
  require "topolys"

  puts "... relying on the Topolys gem"
rescue LoadError
  require_relative "topolys/model"
  require_relative "topolys/geometry"
  require_relative "topolys/transformation"
  require_relative "topolys/version"

  puts "... fallback to local Topolys files"
end

begin
  # Try to load from the OSlg gem.
  require "oslg"

  puts "... relying on the OSlg gem"
rescue LoadError
  require_relative "oslg/oslog"
  require_relative "osut/version"

  puts "... fallback to local OSlg files"
end

begin
  # Try to load from the OSut gem.
  require "osut"

  puts "... relying on the OSut gem"
rescue LoadError
  require_relative "osut/utils"
  require_relative "osut/version"

  puts "... fallback to local OSut files"
end

begin
  # Try to load from the TBD gem.
  require "tbd/psi"
  require "tbd/geo"
  require "tbd/ua"
  require "tbd/version"

  puts "... relying on the TBD gem"
rescue LoadError
  require_relative "tbd/psi"
  require_relative "tbd/geo"
  require_relative "tbd/ua"
  require_relative "tbd/version"

  puts "... fallback to local TBD files"
end

module TBD
  extend OSut         #                                     OpenStudio utilities

  TOL  = OSut::TOL
  TOL2 = OSut::TOL2
  DBG  = OSut::DEBUG  #   mainly to flag invalid arguments for devs (buggy code)
  INF  = OSut::INFO   #           informs TBD user of measure success or failure
  WRN  = OSut::WARN   # e.g. WARN users of 'iffy' .osm inputs (yet not critical)
  ERR  = OSut::ERR    #                            e.g. flag invalid .osm inputs
  FTL  = OSut::FATAL  #                     e.g. invalid TBD JSON format/entries
  NS   = "nameString" #                   OpenStudio IdfObject nameString method

  extend TBD
end
