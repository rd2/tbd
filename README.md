# Thermal Bridging & Derating (TBD)  

An [OpenStudio Measure](https://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/) that first autodetects _major_ thermal bridges (like balconies, parapets and corners) in an OpenStudio model (.osm), and then _derates_ outside-facing, opaque surface constructions (walls, roofs and exposed floors). It relies on both the [OpenStudio SDK](https://openstudio-sdk-documentation.s3.amazonaws.com/index.html) and the AutomaticMagic [Topolys](https://github.com/automaticmagic/topolys) gem.

## Guide & Downloads

Building professionals and energy modellers are encouraged to first consult the online [Guide](https://rd2.github.io/tbd/) - it provides an overview of the underlying theory, references, suggested OpenStudio workflows, etc. Users can download the latest _TBD_ version directly from the Guide itself, or under [releases](https://github.com/rd2/tbd/releases), or via NREL's [BCL](https://bcl.nrel.gov) (search for "bridging" or "rd2").

Questions can be posted on [UnmetHours](https://unmethours.com) - a very useful online resource for OpenStudio users.

TBD can also be deployed as a Ruby gem, by adding this line to an application's _Gemfile_:
```
gem "tbd", github: "rd2/tbd", branch: "master"
```  
And then execute:
```
bundle update
```

## New Features  

Upcoming enhancements are in the works. Bugs and new feature requests for _TBD_ should be submitted [here](https://github.com/rd2/tbd/issues), while those more closely linked to _Topolys_ should be submitted [here](https://github.com/automaticmagic/topolys/issues).

## Development

The installation and testing instructions in this section are for developers interested in exploring/tweaking a cloned/forked version of the source code.

TBD is systematically tested against updated OpenStudio versions (since v2.9.1). The following instructions refer to OpenStudio v3.3.0 (requiring Ruby v2.7.2), strictly as an example. Adapt the instructions for more recent versions - see OpenStudio's [compatibility matrix](https://github.com/NREL/OpenStudio/wiki/OpenStudio-SDK-Version-Compatibility-Matrix).

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

Install the OpenStudio SDK [3.3.0](https://github.com/NREL/OpenStudio/releases/tag/v3.0.0), or the OpenStudio Application [1.3.0](https://github.com/openstudiocoalition/OpenStudioApplication/releases/tag/v1.3.0).

Create a new file ```C:\Ruby27-x64\lib\ruby\site_ruby\openstudio.rb```  (path may be different depending on the environment), and edit it so it _points_ to your new OpenStudio installation:

```
require 'C:\openstudio-3.3.0\Ruby\openstudio.rb'
```

Verify your OpenStudio and Ruby configuration:
```
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Run basic tests to ensure the measure operates properly (see end of this README).


### MacOS Installation

MacOS already comes with Ruby, but maybe not the right Ruby version for the desired OpenStudio measure development [environment](https://github.com/NREL/OpenStudio/wiki/OpenStudio-SDK-Version-Compatibility-Matrix). Instructions here show how to install Ruby v2.7.2 alongside MacOS's own Ruby version. An OpenStudio v2.9.1 setup is described [here](https://github.com/rd2/tbd/blob/master/v291_MacOS.md).

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

... should still report the current Ruby version used by MacOS. To ensure the right version is used for developing OpenStudio Measures, instruct _rbenv_ to switch Ruby version _locally_ within a user’s chosen directory (e.g. "sandbox330"):

```
mkdir ~/Documents/sandbox330
cd ~/Documents/sandbox330
rbenv local 2.7.2
ruby -v
```
… should report the desired _local_ Ruby version, to be used by default for anything under the "sandbox330" directory tree. To ensure both Ruby versions are operational and safe, run the following checkup twice - once from a user’s home (or ~/), then from within e.g., "sandbox330":

```
cd ~/
ruby -ropen-uri -e 'eval URI.open("https://git.io/vQhWq").read'
cd ~/Documents/sandbox330
ruby -ropen-uri -e 'eval URI.open("https://git.io/vQhWq").read'
```

If successful, one should get a ```Hooray!``` from both Ruby versions confirming valid communication with [Rubygems](https://rubygems.org/).

Install the OpenStudio SDK [3.3.0](https://github.com/NREL/OpenStudio/releases/tag/v3.0.0), or the OpenStudio Application [1.3.0](https://github.com/openstudiocoalition/OpenStudioApplication/releases/tag/v1.3.0).

Create a new file ```~/.rbenv/versions/2.7.2/lib/ruby/site_ruby/openstudio.rb```  (path may be different depending on the environment), and edit it so it _points_ to your new OpenStudio installation:

```
require '/Applications/OpenStudio-3.3.0/Ruby/openstudio.rb'
```

Verify your local OpenStudio and Ruby configuration:

```
cd ~/Documents/sandbox330
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Install the latest version of _git_ (e.g. through Homebrew), and ```git clone``` the TBD measure e.g., under "sandbox330".

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

Pull the OpenStudio v3.3.0 Docker image:
```
docker pull nrel/openstudio:3.3.0
```

In the root repository:
```
docker run --name test --rm -d -t -v ${PWD}:/work -w /work nrel/openstudio:3.3.0
docker exec -t test bundle update
docker exec -t test bundle exec rake update_library_files
docker exec -t test bundle exec rake
docker kill test
```

## Support

_Merci !_ to the following organizations

[![](https://github.com/rd2/tbd/blob/master/sponsors/quebec.png)](https://transitionenergetique.gouv.qc.ca)
[![](https://github.com/rd2/tbd/blob/master/sponsors/canada.png)](https://nrc.canada.ca/en/research-development/research-collaboration/research-centres/construction-research-centre)
