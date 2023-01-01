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

# Topolys gem files.
require_relative "model"
require_relative "geometry"
require_relative "transformation"
require_relative "version"

# OSlg gem file.
require_relative "oslog"

# OSut gem file.
require_relative "utils"

# TBD gem files.
require_relative "psi"
require_relative "geo"
require_relative "ua"

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
