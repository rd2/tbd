# MIT License
#
# Copyright (c) 2020-2022 Denis Bourgeois & Dan Macumber
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

  puts "... relying on Topolys gem"
rescue LoadError
  require_relative "topolys/model"
  require_relative "topolys/geometry"
  require_relative "topolys/transformation"
  require_relative "topolys/version"

  puts "... fallback to local Topolys files"
end

begin
  # Try to load from the tbd gem.
  require "tbd/psi"
  require "tbd/conditioned"
  require "tbd/framedivider"
  require "tbd/ua"
  require "tbd/log"
  require "tbd/version"

  puts "... relying on TBD gem"
rescue LoadError
  require_relative "tbd/psi"
  require_relative "tbd/conditioned"
  require_relative "tbd/framedivider"
  require_relative "tbd/ua"
  require_relative "tbd/log"
  require_relative "tbd/version"

  puts "... fallback to local TBD files"
end
