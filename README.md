# Thermal Bridging & Derating (TBD)
This is a repo for an OpenStudio Measure that thermally _derates_ outside-facing opaque constructions (walls, roofs and exposed floors), due to _major_ thermal bridges (balconies, corners, fenestration perimeters, and so on). It relies on both the OpenStudio API and the AutomaticMagic [Topolys](https://github.com/automaticmagic/topolys) gem.

Within the context of building energy simulation (and as required by recent building energy codes and standards) a construction's nominal R-value (or inversely, its nominal U-value) should ideally be _derated_ to adequately factor-in _minor_ and _major_ thermal bridging. _Minor_ thermal bridging is attributable to regularly-spaced framing (such as studs and Z-bars): the resulting derated R-value from minor thermal bridging, generally known as a construction's _clear-field effective R-value_, is typically independent of a surface's actual geometry or adjacencies to other surfaces. _Major_ thermal bridging instead relates to a surface's geometry and its immediate adjacencies (e.g. parapet along a roof/wall intersection, rim joists, wall corners), protruding surfaces and penetrations (e.g. cantilevered balconies), etc. The measure loops through an OpenStudio model's outside-facing surfaces, identifies shared _edges_ with nearby envelope, floor slab and shading surfaces (a proxy for cantilevered balconies), applies (from a list of arguments - e.g. _poor_, _regular_, _efficient_) predefined linear conductance sets (PSI-values, in W/K per linear meter) to individual edge lengths (in m), and consequently derates a construction's clear-field effective R-value. Users of the measure should observe new, surface-specific constructions added to their OSM model and/or file, as well as systematic increases in construction U-values (i.e. decreases in insulating material thickness). The method and predefined values are taken from published research and standards such as ASHRAE's [RP-1365](https://www.techstreet.com/standards/rp-1365-thermal-performance-of-building-envelope-details-for-mid-and-high-rise-buildings?product_id=1806751), [BETBG](https://www.bchydro.com/powersmart/business/programs/new-construction.html) & [thermalenvelope.ca](https://thermalenvelope.ca), as well as ISO [10211](https://www.iso.org/standard/65710.html) and [14683](https://www.iso.org/standard/65706.html).


## TO DO
[Enhancements](https://github.com/rd2/tbd/issues) and documentation are planned over the next few weeks and months, including:
1. JSON customization and output - _completed_
2. ground-facing surfaces (e.g. KIVA foundations) - _completed_
3. fully-glazed surfaces with thermal bridges
4. adding point conductances - _completed_
5. generating building-level clear-field R-values
6. dealing with multipliers and spanners
7. logging warnings and errors - _completed_
8. guide material, case examples, how-to's

Submit [here](https://github.com/automaticmagic/topolys/issues) issues or desired enhancements more closely linked to Topolys.

Energy modelers simply interested in using the TBD OpenStudio _measure_ can either download the latest [release](https://github.com/rd2/tbd/releases) or access the measure via NREL's [BCL](https://bcl.nrel.gov) ... search for _bridging_ or _rd2_. The following installation and testing instructions are instead for those interested in exploring/tweaking the source code (cloned or forked versions of TBD).


## Windows Instructions

### Installation

Install Ruby using the [RubyInstaller](https://rubyinstaller.org/downloads/archives/) for [Ruby 2.7.2 (x64)](https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-2.7.2-1/rubyinstaller-devkit-2.7.2-1-x86.exe).

Check the ruby installation returns the correct Ruby version (v2.7.2):
```
ruby -v
```

Install bundler from the command line
```
gem install bundler -v 2.1
```

Install the OpenStudio Application [v1.2.0](https://github.com/openstudiocoalition/OpenStudioApplication/releases/tag/v1.2.0) or the OpenStudio SDK [3.2.0](https://github.com/NREL/OpenStudio/releases/tag/v3.2.0).  Create a file ```C:\ruby-2.7.2-1-x64-mingw32\lib\ruby\site_ruby\openstudio.rb``` and point it to your OpenStudio installation by editing the contents e.g.:

```ruby
require 'C:\openstudio-3.2.0\Ruby\openstudio.rb'
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

Pull the OpenStudio v3.2.0 Docker image:
```
docker pull nrel/openstudio:3.2.0
```

In the root repository:
```
docker run --name test --rm -d -t -v ${PWD}:/work -w /work nrel/openstudio:3.2.0
docker exec -t test bundle update
docker exec -t test bundle exec rake update_library_files
docker exec -t test bundle exec rake
docker kill test
```


## MacOS Instructions

MacOS already comes with Ruby, but maybe not the right Ruby version for the desired OpenStudio measure development [environment](https://github.com/NREL/OpenStudio/wiki/OpenStudio-SDK-Version-Compatibility-Matrix). The instructions here show how to install Ruby v2.7.2 (alongside MacOS's own Ruby version). Ruby v2.7.2 is compatible with OpenStudio [v3.2.0](https://github.com/NREL/OpenStudio/releases/tag/v3.2.0) and the OpenStudio Application [v1.2.0](https://github.com/openstudiocoalition/OpenStudioApplication/releases/tag/v1.2.0). An OpenStudio v2.9.1 setup is described [here](https://github.com/rd2/tbd/blob/ua/v291_MacOS.md).

From a Terminal, install [Homebrew](https://brew.sh/index) - nice for package distribution and management. Using Homebrew, install _ruby-build_, _rbenv_ (which allows users to manage multiple Ruby versions) and finally Ruby v2.7.2:

```
brew install ruby-build
brew install rbenv
rbenv install 2.7.2
```

Install the OpenStudio Application v1.2.0 (or the SDK v3.2.0). Then create the file _~/.rbenv/versions/2.7.2/lib/ruby/site_ruby/openstudio.rb_, and point it to your OpenStudio installation by editing the contents, e.g.:

```
require '/Applications/OpenStudio-2.7.2/Ruby/openstudio.rb'
```

In the Terminal, check the Ruby version:

```
ruby -v
```

It should report the current Ruby version used by macOS (e.g. ‘system’, or '2.6'). To ensure Ruby v2.7.2 is used for developing OpenStudio v3.2.0-compatible measures, a safe way is to instruct _rbenv_ to use Ruby v2.7.2 for anything within a user’s OpenStudio directory (the default OpenStudio installation would add a /Users/user/OpenStudio folder, containing a Measures folder):

```
cd ~/OpenStudio
rbenv local 2.7.2
ruby -v
```

… should report ```2.7.2``` as the local Ruby version, to be used by default for anything under the OpenStudio directory tree (including anything under Measures). To ensure both Ruby versions are operational and safe, run the following checkup twice - once from a user’s home (or ~/) directory, then from within the local OpenStudio environment:

```
cd ~/
ruby -ropen-uri -e 'eval open("https://git.io/vQhWq").read'
cd OpenStudio
ruby -ropen-uri -e 'eval open("https://git.io/vQhWq").read'
```

If successful, one should get a ```Hooray!``` from both Ruby versions confirming valid communication with [Rubygems](https://rubygems.org/). It may be necessary to first install [bundler](https://bundler.io). If not, now’s a good time:

```
cd ~/OpensStudio
gem install bundler -v 2.1
```

Verify your OpenStudio and Ruby configuration:

```
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Install the latest version of _git_ (e.g. through Homebrew), and _git clone_ the TBD measure under the user’s local OpenStudio Measures directory.

Run the basic tests below to ensure the measure operates as expected.


## Complete list of test commands

Run the following (basic) tests in the root repository of the cloned TBD measure:
```
bundle update
bundle exec rake update_library_files
bundle exec rake
```

For more extensive testing, run the following test suites (also in the root repository of the cloned TBD measure):
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

## Support

_Merci !_ to the following organizations

[![](https://github.com/rd2/tbd/blob/master/sponsors/quebec.png)](https://transitionenergetique.gouv.qc.ca)
[![](https://github.com/rd2/tbd/blob/master/sponsors/canada.png)](https://nrc.canada.ca/en/research-development/research-collaboration/research-centres/construction-research-centre)
