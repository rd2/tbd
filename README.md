# Thermal Bridging &amp; Derating (tbd)

This is a repo for an OpenStudio Measure that thermally derates opaque constructions (e.g. walls, roofs) based on major thermal bridges (e.g. balconies, corners, fenestration perimeters). It relies on both the OpenStudio API and the AutomaticMagic Topolys gem.

(to complete)

## Run tests

Run the following tests in the root repository of the cloned measure:

```
bundle update
bundle exec rake update_library_files
bundle exec rake
```
