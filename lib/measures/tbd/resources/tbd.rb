# MIT License
#
# Copyright (c) 2020-2024 Denis Bourgeois & Dan Macumber
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
  extend OSut            # OpenStudio utilities

  TOL  = OSut::TOL.dup   # default distance tolerance (m)
  TOL2 = OSut::TOL2.dup  # default area tolerance (m2)
  DBG  = OSut::DEBUG.dup # github.com/rd2/oslg
  INF  = OSut::INFO.dup  # github.com/rd2/oslg
  WRN  = OSut::WARN.dup  # github.com/rd2/oslg
  ERR  = OSut::ERR.dup   # github.com/rd2/oslg
  FTL  = OSut::FATAL.dup # github.com/rd2/oslg
  NS   = OSut::NS.dup    # OpenStudio IdfObject nameString method

  extend TBD
end
