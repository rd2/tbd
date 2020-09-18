# Thermal Bridging & Derating (tbd)
This is a repo for an OpenStudio Measure that _thermally derates_ outside-facing opaque constructions (walls, roofs and exposed floors), based on _major_ thermal bridges (balconies, corners, fenestration perimeters, and so on). It relies on both the OpenStudio API and the AutomaticMagic [Topolys](https://github.com/automaticmagic/topolys) gem.

Within the context of building energy simulation (and as required by recent building energy codes and standards) a construction's nominal R-value (or inversely, its nominal U-value) should ideally be _derated_ to adequately factor-in _minor_ and _major_ thermal bridging. _Minor_ thermal bridging is attributable to regularly-spaced framing (such as studs, Z-bars, etc.): the resulting derated R-value from minor thermal bridging, generally known as a construction's _clear-field effective R-value_, is typically independent of a surface's actual geometry or adjacencies to other surfaces. _Major_ thermal bridging instead relates to a surface's geometry and its immediate adjacencies (e.g. parapet along a roof/wall intersection, rim joists, wall corners), protruding surfaces and penetrations (e.g. cantilevered balconies), etc. The measure loops through an OpenStudio model's outside-facing surfaces, identifies shared _edges_ with nearby envelope, floor slab and shading surfaces (a proxy for cantilevered balconies), applies (from a list of arguments - e.g. _poor_, _regular_, _efficient_) predefined linear conductance sets (PSI-values, in W/K per linear meter) to individual edge lengths (in m), and consequently derates a construction's clear-field effective R-value. Users of the measure should observe new, surface-specific constructions to their OSM model and/or file, as well as systematic increases in construction U-values (i.e. decreases in insulating material thickness). The method and predefined values are taken from published research and standards such as ASHRAE's [RP-1365](https://www.techstreet.com/standards/rp-1365-thermal-performance-of-building-envelope-details-for-mid-and-high-rise-buildings?product_id=1806751), follow-up work from [BC Hydro/Morrison-Hershfield](https://www.bchydro.com/powersmart/business/programs/new-construction.html), as well as ISO [10211](https://www.iso.org/standard/65710.html) and [14683](https://www.iso.org/standard/65706.html).


## TO DO
[Enhancements](https://github.com/rd2/tbd/issues) and documentation are planned over the next few weeks and months, including:
1. JSON I/O
2. dealing with ground-facing surfaces (e.g. foundation walls, slabs on grade)
3. dealing with fully-glazed surfaces with thermal bridges
4. adding point conductances
5. logging warnings and errors
6. guide material, case examples, how-to's

Submit [here](https://github.com/automaticmagic/topolys/issues) issues or desired enhancements more closely linked to Topolys.

The following installation and testing instructions refer to OpenStudio 2.9.1, yet the measure is regularly tested against OpenStudio 3.0.0.


## Windows Instructions

### Installation

Install Ruby using the [RubyInstaller](https://rubyinstaller.org/downloads/archives/) for [Ruby 2.2.5 (x64)](https://dl.bintray.com/oneclick/rubyinstaller/rubyinstaller-2.2.5-x64.exe).

Check the ruby installation returns the correct Ruby version (2.2.5):
```
ruby -v
```

Install bundler from the command line
```
gem install bundler -v 1.17.3
```

Install [OpenStudio 2.9.1](https://github.com/NREL/OpenStudio/releases/tag/v2.9.1).  Create a file ```C:\ruby-2.2.5-x64-mingw32\lib\ruby\site_ruby\openstudio.rb``` and point it to your OpenStudio installation by editing the contents.  E.g.:

```ruby
require 'C:\openstudio-2.9.1\Ruby\openstudio.rb'
```

Verify your OpenStudio and Ruby configuration:
```
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Run basic tests to ensure the measure operates properly (see end of this README).


## Run tests using Docker

Install Docker for Windows:
```
https://docs.docker.com/docker-for-windows/install/
```

Pull the OpenStudio 2.9.1 Docker image:
```
docker pull nrel/openstudio:2.9.1
```

In the root repository:
```
docker run --name test --rm -d -t -v ${PWD}:/work -w /work nrel/openstudio:2.9.1
docker exec -t test bundle update
docker exec -t test bundle exec rake update_library_files
docker exec -t test bundle exec rake
docker kill test
```


## MacOS (e.g. Catalina 10.15.4) Instructions

OpenStudio [2.9.1](https://github.com/NREL/OpenStudio/releases/tag/v2.9.1) is the most up-to-date version that remains [compatible](https://github.com/NREL/OpenStudio/wiki/OpenStudio-Version-Compatibility-Matrix) with SketchUp 2017. OpenStudio 2.9.1 measures require Ruby 2.2.5, which is several iterations behind the default Ruby 2.6 version available on any recently-purchased Mac. Although it is quite common for developers to have access to more than one Ruby version, some effort is required for Ruby versions < 2.3 (e.g. 2.2.5 is no longer officially supported, OpenSSL-1.0 (not 1.1) is required yet considered deprecated). To help Mac users (and potentially Linux users as well), the following steps are recommended (although architecture-specific tweaks may be required).

From a Terminal, install [Homebrew](https://brew.sh/index) - nice for package distribution and management. With a few tweaks, it will handle most package downloads, dependencies, etc. Using Homebrew, install OpenSSL-1.0, and then _rbenv_ (which allows users to manage multiple Ruby versions). One way of doing it:

```
brew install rbenv/tap/openssl@1.0
```

By _tapping_, Homebrew provides a way to access third-party repositories that are usually no longer officially supported by Homebrew, like Ruby 2.2.5 and OpenSSL-1.0. The above instruction tells Homebrew to install compatible versions of OpenSSL-1.0 with _rbenv_ (e.g. 1.0.2t, 1.0.2u).

Next, ensure that Homebrew and _rbenv_ use OpenSSL-1.0 (at least locally) for future, local Ruby development. Edit (or create) a user’s local _~/.zshrc_ file (instructions are here provided for zsh, the default macOS Terminal shell interface - for bash, adapt), by pasting-in the following:

```
eval "$(rbenv init - zsh)"
export PATH="/usr/local/opt/openssl@1.0/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/openssl@1.0/lib"
export CPPFLAGS="-I/usr/local/opt/openssl@1.0/include"
export PKG_CONFIG_PATH="/usr/local/opt/openssl@1.0/lib/pkgconfig"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.0)"
```

There’s probably more there than necessary, but it should do the trick for the next few steps, and for future work. Quit the Terminal and start a new one, or simply _source_ the zshrc file:

```
source ~/.zshrc
```

Make sure the right OpenSSL version is recognized, and then instruct Homebrew to switch over to it:

```
openssl version
brew switch openssl 1.0.2t
```

… or whatever Openssl 1.0 version was installed, e.g. 1.0.2u. Then install _ruby-build_, _rbenv_ and finally Ruby 2.2.5:

```
brew install ruby-build
brew install rbenv
rbenv install 2.2.5
```

Install OpenStudio 2.9.1. Then create the file _~/.rbenv/versions/2.2.5/lib/ruby/site_ruby/openstudio.rb_, and point it to your OpenStudio installation by editing the contents, e.g.:

```
require '/Applications/OpenStudio-2.9.1/Ruby/openstudio.rb'
```

In the Terminal, check the Ruby version:

```
ruby -v
```

It should report the current Ruby version used by macOS (e.g. ‘system’, or '2.6'). To ensure Ruby 2.2.5 is used for OpenStudio measures, a safe way is to instruct _rbenv_ to use Ruby 2.2.5 for anything within a user’s OpenStudio directory (the default OpenStudio installation would add a /Users/user/OpenStudio folder, containing a Measures folder):

```
cd ~/OpenStudio
rbenv local 2.2.5
ruby -v
```

… should report 2.2.5 as the local version of Ruby, to be used by default for anything under the OpenStudio directory tree (including anything under Measures). To ensure both Ruby versions are operational and safe, run the following checkup (once from a user’s home (or ~/) directory, then from within the local OpenStudio environment):

```
cd ~/
ruby -ropen-uri -e 'eval open("https://git.io/vQhWq").read'
cd OpenStudio
ruby -ropen-uri -e 'eval open("https://git.io/vQhWq").read'
```

If successful, one should get a _Hooray!_ from both Ruby versions confirming valid communication with [Rubygems](https://rubygems.org/), yet with their specific RubyGems and OpenSSL versions, as well as their own SSL certificates. In some cases, (temporarily) switching over to an insecure http connection to rubygems.org (instead of the default https) may be necessary. It may also be necessary to first install bundler. If not, now’s a good time:

```
cd ~/OpensStudio
gem install bundler -v 1.17.3
```

Verify your OpenStudio and Ruby configuration:

```
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Install the latest version of _git_ (e.g. through Homebrew), and _git clone_ the measure under the user’s local OpenStudio Measures directory.

Run the basic tests below to ensure the measure operates as expected.


## Complete list of test commands

Run the following (basic) tests in the root repository of the cloned measure:
```
bundle update
bundle exec rake update_library_files
bundle exec rake
```

For more extensive testing, run the following test suites in the root repository of the cloned measure:
```
bundle update
bundle exec rake osm_suite:clean
bundle exec rake osm_suite:run
bundle exec rake prototype_suite:clean
bundle exec rake prototype_suite:run
```

Or run all test suites:

```
bundle update
bundle exec rake suites_clean
bundle exec rake suites_run
```
