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

begin # try to load from the Topolys gem
  require "topolys"
rescue LoadError
  require_relative "topolys/model"
  require_relative "topolys/geometry"
  require_relative "topolys/transformation"
  require_relative "topolys/version"
end

begin # try to load from the Topolys gem
  require "oslg"
rescue LoadError
  require_relative "oslg/oslog"
  require_relative "osut/version"
end

begin # try to load from the Topolys gem
  require "osut"
rescue LoadError
  require_relative "osut/utils"
  require_relative "osut/version"
end

begin # try to load from the Topolys gem
  require "tbd/psi"
  require "tbd/geo"
  require "tbd/ua"
  require "tbd/version"
rescue LoadError
  require_relative "tbd/psi"
  require_relative "tbd/geo"
  require_relative "tbd/ua"
  require_relative "tbd/version"
end

module TBD
  extend OSut         # OpenStudio utilities

  TOL  = OSut::TOL    # default distance tolerance (m)
  TOL2 = OSut::TOL2   # default area tolerance (m2)
  DBG  = OSut::DEBUG  # github.com/rd2/oslg
  INF  = OSut::INFO   # github.com/rd2/oslg
  WRN  = OSut::WARN   # github.com/rd2/oslg
  ERR  = OSut::ERR    # github.com/rd2/oslg
  FTL  = OSut::FATAL  # github.com/rd2/oslg
  NS   = "nameString" # OpenStudio IdfObject nameString method

  extend TBD
end
