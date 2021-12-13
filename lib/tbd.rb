begin
  # Try to load from the Topolys gem.
  require "topolys"
rescue LoadError
  require_relative "topolys/model"
  require_relative "topolys/geometry"
  require_relative "topolys/transformation"
  require_relative "topolys/version"
end

begin
  #   # Try to load from the tbd gem.
  require "tbd/psi"
  require "tbd/conditioned"
  require "tbd/framedivider"
  require "tbd/ua"
  require "tbd/log"
  require "tbd/version"
rescue LoadError
  require_relative "tbd/psi"
  require_relative "tbd/conditioned"
  require_relative "tbd/framedivider"
  require_relative "tbd/ua"
  require_relative "tbd/log"
  require_relative "tbd/version"
end
