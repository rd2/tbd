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


## Instructions

Energy modellers simply interested in using TBD as an OpenStudio Measure can either download the latest [release](https://github.com/rd2/tbd/releases) or access the measure via NREL's [BCL](https://bcl.nrel.gov) ... search for _bridging_ or _rd2_. The following installation and testing instructions are instead for those interested in exploring/tweaking a cloned/forked version of the source code.

TBD is systematically tested against updated OpenStudio versions (since v2.9.1). The instructions refer to OpenStudio v3.2.1 (requiring Ruby v2.7.2) strictly as an example. Adapt the instructions for more recent versions - see OpenStudio's [compatibility matrix](https://github.com/NREL/OpenStudio/wiki/OpenStudio-SDK-Version-Compatibility-Matrix).

### Windows Installation

Install Ruby using the [RubyInstaller](https://rubyinstaller.org/downloads/archives/) for [Ruby 2.7.2 (x64)](https://github.com/oneclick/rubyinstaller2/releases/tag/RubyInstaller-2.7.2-1/rubyinstaller-2.7.2-1-x64.exe).

From the command line, check that the ruby installation returns the correct Ruby version:
```
ruby -v
```

Install bundler:
```
gem install bundler -v 2.1
```

Install the OpenStudio SDK [3.2.1](https://github.com/NREL/OpenStudio/releases/tag/v3.2.1).

Create a file ```C:\Ruby27-x64\lib\ruby\site_ruby\openstudio.rb```  (path may be different depending on the environment) and _point it_ to your OpenStudio installation by editing the contents e.g.:

```
require 'C:\openstudio-3.2.1\Ruby\openstudio.rb'
```

Verify your OpenStudio and Ruby configuration:
```
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Run basic tests to ensure the measure operates properly (see end of this README).


### MacOS Installation

MacOS already comes with Ruby, but maybe not the right Ruby version for the desired OpenStudio measure development [environment](https://github.com/NREL/OpenStudio/wiki/OpenStudio-SDK-Version-Compatibility-Matrix). Instructions here show how to install Ruby v2.7.2 alongside MacOS's own Ruby version. An OpenStudio v2.9.1 setup is described [here](https://github.com/rd2/tbd/blob/ua/v291_MacOS.md).

From a Terminal, install [Homebrew](https://brew.sh/index) - nice for package distribution and management. Using Homebrew, install _rbenv_ (which allows users to manage multiple Ruby versions) and finally Ruby:

```
brew install rbenv
rbenv init
rbenv install 2.7.2
```
Install [bundler](https://bundler.io), great for managing Ruby gems and dependencies:

```
gem install bundler -v 2.1
```

In the Terminal, check the Ruby version:

```
ruby -v
```

... should still report the current Ruby version used by MacOS. To ensure the right version is used for developing OpenStudio Measures, instruct _rbenv_ to switch Ruby version _locally_ within a user’s chosen directory (e.g. "sandbox321"):

```
mkdir ~/Documents/sandbox321
cd ~/Documents/sandbox321
rbenv local 2.7.2
ruby -v
```
… should report the desired _local_ Ruby version, to be used by default for anything under the "sandbox321" directory tree. To ensure both Ruby versions are operational and safe, run the following checkup twice - once from a user’s home (or ~/), then from within e.g., "sandbox321":

```
cd ~/
ruby -ropen-uri -e 'eval URI.open("https://git.io/vQhWq").read'
cd ~/Documents/sandbox321
ruby -ropen-uri -e 'eval URI.open("https://git.io/vQhWq").read'
```

If successful, one should get a ```Hooray!``` from both Ruby versions confirming valid communication with [Rubygems](https://rubygems.org/).

Install the [OpenStudio SDK](https://www.openstudio.net/downloads).

Then create the file _~/.rbenv/versions/2.7.2/lib/ruby/site_ruby/openstudio.rb_, and _point it_ to your OpenStudio installation by editing the contents, e.g.:

```
require '/Applications/OpenStudio-3.2.1/Ruby/openstudio.rb'
```

Verify your local OpenStudio and Ruby configuration:

```
cd ~/Documents/sandbox321
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Install the latest version of _git_ (e.g. through Homebrew), and ```git clone``` the TBD measure e.g., under "sandbox321".

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

## Run tests using Docker - _optional_

Install [Docker](https://docs.docker.com/desktop/#download-and-install).

Pull the OpenStudio v3.2.1 Docker image:
```
docker pull nrel/openstudio:3.2.1
```

In the root repository:
```
docker run --name test --rm -d -t -v ${PWD}:/work -w /work nrel/openstudio:3.2.1
docker exec -t test bundle update
docker exec -t test bundle exec rake update_library_files
docker exec -t test bundle exec rake
docker kill test
```

## Support

_Merci !_ to the following organizations

[![](https://github.com/rd2/tbd/blob/master/sponsors/quebec.png)](https://transitionenergetique.gouv.qc.ca)
[![](https://github.com/rd2/tbd/blob/master/sponsors/canada.png)](https://nrc.canada.ca/en/research-development/research-collaboration/research-centres/construction-research-centre)
