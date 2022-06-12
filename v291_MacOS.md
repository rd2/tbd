_We reiterate that building professionals and energy modellers can download the latest TBD version directly from the Guide itself, or under [releases](https://github.com/rd2/tbd/releases), or via NREL's [BCL](https://bcl.nrel.gov) (search for "bridging" or "rd2")._

_Those instead interested in exploring/tweaking the source code (cloned or forked versions of TBD) can follow the Windows or MacOS Ruby setup described in TBD's [README](https://github.com/rd2/tbd#readme)._

_The MacOS instructions below specifically target (older) Ruby v2.2.5 environments, needed for developing OpenStudio [v2.9.1](https://github.com/NREL/OpenStudio/releases/tag/v2.9.1) measures - the most up-to-date version that remains [compatible](https://github.com/NREL/OpenStudio/wiki/OpenStudio-SDK-Version-Compatibility-Matrix) with [SketchUp Make 2017](https://help.sketchup.com/en/downloading-older-versions). More recent OpenStudio versions (e.g. v3.4.0) can - to a large degree - safely translate older .osm files. Although TBD (and Topolys) are systematically tested against updated OpenStudio versions (v2.9.1 onwards), the following Ruby v2.2.5 setup is no longer tested or maintained. Nonetheless, it may be of some help for the more adventurous of you._


## v2.9.1 MacOS Instructions
_tested Catalina 10.15.4 up to Big Sur 11.4_

OpenStudio v2.9.1 measures require Ruby v2.2.5, which is several iterations behind the default Ruby v2.6 version available on any recently-purchased Mac. Although it is common to develop/test using more than one Ruby version, some effort is nonetheless required for older vintages: v2.2.5 is no longer officially supported, it requires the deprecated OpenSSL-1.0 (not 1.1), etc. To help Mac users (and potentially Linux users as well), the following steps are recommended (although architecture-specific tweaks may be required).

From a Terminal, install [Homebrew](https://brew.sh/index) - nice for package distribution and management. With a few tweaks, it will handle most package downloads, dependencies, etc. Using Homebrew, install OpenSSL-1.0, and then _rbenv_ (which allows users to manage multiple Ruby versions). One way of doing it:

```
brew install rbenv/tap/openssl@1.0
```

By _tapping_, Homebrew provides a way to access third-party repositories that are no longer officially supported by Homebrew, like Ruby v2.2.5 and OpenSSL-1.0. The above instruction tells Homebrew to install compatible versions of OpenSSL-1.0 with _rbenv_ (e.g. 1.0.2t, 1.0.2u).

Next, ensure that Homebrew and _rbenv_ use OpenSSL-1.0 for future, local Ruby development. Edit (or create) a user’s local _~/.zshrc_ file (instructions here are provided for _zsh_, the default macOS Terminal shell interface - _bash_ users: adapt!), by pasting-in the following:

```
eval "$(rbenv init - zsh)"
export PATH="/usr/local/opt/openssl@1.0/bin:$PATH"
export LDFLAGS="-L/usr/local/opt/openssl@1.0/lib"
export CPPFLAGS="-I/usr/local/opt/openssl@1.0/include"
export PKG_CONFIG_PATH="/usr/local/opt/openssl@1.0/lib/pkgconfig"
export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.0)"
```

There’s probably more there than necessary, but it should do the trick for the next few steps, and/or for future work. Quit the Terminal and start a new one, or simply _source_ the zshrc file:

```
source ~/.zshrc
```

Make sure the right OpenSSL version is recognized, and then instruct Homebrew to switch over to it:

```
openssl version
brew switch openssl 1.0.2t
```

… or whatever Openssl 1.0 version was installed, e.g. 1.0.2u. Then install _ruby-build_, _rbenv_ and finally Ruby v2.2.5:

```
brew install ruby-build
brew install rbenv
rbenv install 2.2.5
```

Install a compatible version of [bundler](https://bundler.io), great for managing Ruby gems and dependencies:

```
gem install bundler -v 1.17.3
```
In some cases, (temporarily) switching over to an insecure ```http``` connection to rubygems.org (instead of the default ```https```) may be required:
```
gem source -r https://rubygems.org/
gem source -a http://rubygems.org/
gem install bundler -v 1.17.3
gem source -r http://rubygems.org/
gem source -a https://rubygems.org/
```

In the Terminal, check the Ruby version:

```
ruby -v
```

... should still report the current Ruby version used by macOS (e.g. ```system``` or ```2.6```). To ensure Ruby v2.2.5 is used for developing OpenStudio v2.9.1-compatible measures, instruct _rbenv_ to use Ruby v2.2.5 _locally_ within a user’s chosen directory (e.g. "sandbox291"):

```
mkdir ~/Documents/sandbox291
cd ~/Documents/sandbox291
rbenv local 2.2.5
ruby -v
```

… should now report ```2.2.5``` as the local Ruby version, to be used by default for anything under the "sandbox291" directory tree. To ensure both Ruby versions are operational and safe, run the following checkup twice - once from a user’s _home_ (or ~/), then from within e.g., "sandbox291":

```
cd ~/
ruby -ropen-uri -e 'eval open("https://git.io/vQhWq").read'
cd ~/Documents/sandbox291
ruby -ropen-uri -e 'eval open("https://git.io/vQhWq").read'
```

If successful, one should get a ```Hooray!``` from both Ruby versions confirming valid communication with [Rubygems](https://rubygems.org/), yet with their specific RubyGems and OpenSSL versions, as well as their own SSL certificates.

Install OpenStudio [v2.9.1](https://github.com/NREL/OpenStudio/releases/tag/v2.9.1).

Then create the file _~/.rbenv/versions/2.2.5/lib/ruby/site_ruby/openstudio.rb_, and edit it so it _points_ to your new OpenStudio installation:

```
require '/Applications/OpenStudio-2.9.1/Ruby/openstudio.rb'
```

Verify your local OpenStudio and Ruby configuration:

```
cd ~/Documents/sandbox291
ruby -e "require 'openstudio'" -e "puts OpenStudio::Model::Model.new"
```

Install the latest version of _git_ (e.g. through Homebrew), and ```git clone``` the TBD measure under e.g., "sandbox291".

Run the basic [tests](https://github.com/rd2/tbd#complete-list-of-test-commands) to ensure the measure operates as expected.
