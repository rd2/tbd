# Thermal Bridging & Derating (TBD)  

An [OpenStudio Measure](https://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/) that first autodetects _major_ thermal bridges (like balconies, parapets and corners) in an OpenStudio model (.osm), and then _derates_ outside-facing, opaque surface constructions (walls, roofs and exposed floors). It interacts with the [OpenStudio SDK](https://openstudio-sdk-documentation.s3.amazonaws.com/index.html) and relies on AutomaticMagic's [Topolys](https://github.com/automaticmagic/topolys) gem, as well as rd2's [OSut](https://rubygems.org/gems/osut) gem.

## Guide & Downloads

Building professionals and energy modellers are encouraged to first consult the online [Guide](https://rd2.github.io/tbd/) - it provides an overview of the underlying theory, references, suggested OpenStudio workflows, etc. Users can download the latest _TBD_ version directly from the Guide itself, or under [releases](https://github.com/rd2/tbd/releases), or via NREL's [BCL](https://bcl.nrel.gov) (search for "bridging" or "rd2"). Questions can be posted on [UnmetHours](https://unmethours.com) - a very useful online resource for OpenStudio users. TBD is also available as a Ruby gem - add:  
```
gem "tbd", git: "https://github.com/rd2/tbd", branch: "master"
```  

... in a [bundled](https://bundler.io) _Measure_ development environment "Gemfile" (or preferably as a _gemspec_ dependency), and then run:  
```
bundle install (or 'bundle update')
```

## New Features  

Bugs or new feature requests for _TBD_ should be submitted [here](https://github.com/rd2/tbd/issues), while those more closely linked to _Topolys_ or _OSut_ should be submitted [here](https://github.com/automaticmagic/topolys/issues) or [here](https://github.com/rd2/osut/issues), respectively.

## Development

The installation and testing instructions in this section are for developers interested in exploring/tweaking a cloned/forked version of the source code. In an effort to _lighten_ TBD as a Ruby gem, only the most basic tests are deployed in this repository. More detailed tests are housed in a dedicated TBD [testing](https://github.com/rd2/tbd_tests) repo.

TBD is systematically tested against updated OpenStudio versions (since v3.0.0). The following instructions refer to OpenStudio v3.8.0, which requires Ruby v3.2.2. Earlier OpenStudio versions require Ruby v2.7.2. Adapt instructions for older (or newer) versions - see OpenStudio's [compatibility matrix](https://github.com/NREL/OpenStudio/wiki/OpenStudio-SDK-Version-Compatibility-Matrix).

### Windows Installation

Either install Ruby using the [RubyInstaller](https://rubyinstaller.org/downloads/archives/) for [Ruby 3.2.2 (x64)](https://github.com/oneclick/rubyinstaller2/releases/download/RubyInstaller-3.2.2-1/rubyinstaller-3.2.2-1-x64.exe), or preferably under a [WSL2](https://gist.github.com/brgix/0d968d8f32c41f13300dc6769414df79) environment. Run the following steps if going down the _RubyInstaller_ route. From the command line, check that the ruby installation returns the correct Ruby version:  
```
ruby -v
```

Install bundler, if not already installed:
```
bundler -v
gem install bundler -v 2.1
```

Install OpenStudio [3.8.0](https://github.com/NREL/OpenStudio/releases/tag/v3.8.0), or the OpenStudioApplication [1.8.0](https://github.com/openstudiocoalition/OpenStudioApplication/releases/tag/v1.8.0).

Create a new file ```C:\Ruby32-x64\lib\ruby\site_ruby\openstudio.rb``` (path may be different depending on the environment), and edit it so it _points_ to your new OpenStudio installation:
```
require 'C:\openstudio-3.8.0\Ruby\openstudio.rb'
```

Verify your OpenStudio and Ruby configuration:
```
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

### MacOS Installation

MacOS already comes with Ruby, but likely not the right Ruby version for the desired OpenStudio measure development [environment](https://github.com/NREL/OpenStudio/wiki/OpenStudio-SDK-Version-Compatibility-Matrix). Instructions here show how to install Ruby v3.2.2 alongside MacOS's own Ruby version. Although no longer officially supported, instructions for an OpenStudio v2.9.1 setup is described [here](https://github.com/rd2/tbd/blob/master/v291_MacOS.md).

From a Terminal, install [Homebrew](https://brew.sh/index) - nice for package distribution and management. Using Homebrew, install _rbenv_ (which allows users to manage multiple Ruby versions) and finally Ruby:
```
brew install rbenv
rbenv init
rbenv install 3.2.2
```

In the Terminal, check the Ruby version:
```
ruby -v
```

... should still report the current Ruby version used by MacOS. To ensure the right version is used for developing OpenStudio Measures, instruct _rbenv_ to switch Ruby version _locally_ within a user’s chosen directory (e.g. "sandbox380"):
```
mkdir ~/Documents/sandbox380
cd ~/Documents/sandbox380
rbenv local 3.2.2
ruby -v
```

… should now report the desired _local_ Ruby version, to be used by default for anything under the "sandbox380" directory tree. To ensure both Ruby versions are operational and safe, run the following checkup twice - once from a user’s home (or ~/), then from within e.g. "sandbox380":
```
cd ~/
ruby -ropen-uri -e 'eval URI.open("https://git.io/vQhWq").read'
cd ~/Documents/sandbox380
ruby -ropen-uri -e 'eval URI.open("https://git.io/vQhWq").read'
```

If successful, one should get a ```Hooray!``` from both Ruby versions confirming valid communication with [Rubygems](https://rubygems.org/).

[Bundler](https://bundler.io) is also required for managing Ruby gems and dependencies. With _rbenv_, the right _Bundler_ version should have been installed. If for whatever reason it wasn't installed:
```
bundler -v
gem install bundler -v 2.4.10
```

Install OpenStudio [3.8.0](https://github.com/NREL/OpenStudio/releases/tag/v3.8.0), or the OpenStudio Application [1.8.0](https://github.com/openstudiocoalition/OpenStudioApplication/releases/tag/v1.8.0).

Create a new file ```~/.rbenv/versions/3.2.2/lib/ruby/site_ruby/openstudio.rb``` (path may be different depending on the environment), and edit it so it _points_ to your new OpenStudio installation:
```
require '/Applications/OpenStudio-3.8.0/Ruby/openstudio.rb'
```

Verify your local OpenStudio and Ruby configuration:
```
cd ~/Documents/sandbox380
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Make sure you have latest version of _git_ (e.g. through Homebrew).

## Clone TBD

Once done with either the Windows or MacOS setup, ```git clone``` the TBD repo, e.g. under "sandbox380". Run the basic tests below to ensure the measure operates as expected.

## Complete list of test commands

Run the following (basic) tests from TBD's root repository:
```
bundle update (or 'bundle install')
bundle exec rake libraries
bundle exec rake
```

## Run tests using Docker - _optional_

Install [Docker](https://docs.docker.com/desktop/#download-and-install).

Pull the OpenStudio v3.8.0 Docker image:
```
docker pull nrel/openstudio:3.8.0
```

In the root repository:
```
docker run --name test --rm -d -t -v ${PWD}:/work -w /work nrel/openstudio:3.8.0
docker exec -t test bundle update
docker exec -t test bundle exec rake
docker kill test
```

## Support

Merci aux gouvernements du [Québec](https://transitionenergetique.gouv.qc.ca) et du Canada ([CNRC](https://nrc.canada.ca/en/research-development/research-collaboration/research-centres/construction-research-centre), [CanmetÉNERGIE](https://www.nrcan.gc.ca/energy/offices-labs/canmet/ottawa-research-centre/the-built-environment/23341)).

![Thanks to the Quebec and Canadian governments](./sponsors/qc_can.png "Thanks to the Quebec and Canadian governments")
