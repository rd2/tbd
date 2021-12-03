### Reporting

The OpenStudio _runner_ will provide pre-simulation TBD feedback. If successful, TBD reports which opaque surfaces were _derated_ and by how much.
```
Initializing workflow.
Processing OpenStudio Measures.
Applying TBD Measure
Result: Success
Info: RSi derated by -19.0% : Bulk Storage Left Wall
Info: RSi derated by -14.9% : Bulk Storage Rear Wall
Info: RSi derated by -15.1% : Bulk Storage Right Wall
[...]

Translating the OpenStudio Model to EnergyPlus.
Processing EnergyPlus Measures.
Starting Simulation.
EnergyPlus Starting.
```
If a surface has been _derated_ by let's say 20%, that means TBD has provided that EnergyPlus surface with a new, cloned construction having a _derated R-value_ at 80% of its initial _clear-field effective R-value_. TBD will also print out this same feedback, as well as any errors or warnings, in a _tbd.out.json_ file in the project's _files_ folder.
```
warehouse.osm
warehouse/
|-- files/
|   |-- tbd.out.json
|   |-- somewhere.epw
|-- reports/
|-- run
|-- ...
```
### Errors and warnings

Critical (and many non-critical) OpenStudio model anomalies are often caught by EnergyPlus at the start of a simulation (e.g. 5-sided windows). As TBD is also designed to run _standalone_ under _Apply Measures Now_, TBD shouldn't (or couldn't) strictly rely on EnergyPlus to catch such errors (and somehow warn users of potentially invalid results). TBD is designed to minimally log warnings, as well as non-fatal & fatal errors, that may put its internal processes at risk (e.g. red-flagging 5-sided windows in an OpenStudio model). The presence of FATAL, ERROR or WARNING log entries should be interpreted as __bad__, something to look into and/or remediate. EnergyPlus often runs with e.g. out-of-range material or fluid properties, which triggers a non-fatal ERROR - it's up to users to decide what to do with simulation results. TBD attempts something similar:

__FATAL__ errors halt all TBD processes and prevents OpenStudio from launching an EnergyPlus simulation. TBD has but a few checks which could raise FATAL cases. These would be mainly linked to missing, incomplete or invalid OpenStudio (or TBD) files or key file entries e.g., badly structured JSON files, invalid OpenStudio vertex transformation parameters, a missing or incomplete TBD _building psi_ set.

The vast majority of TBD checks would log non-fatal __ERROR__ messages when encountering invalid OpenStudio or TBD file entries (structurally sound, yet invalid _vis-à-vis_ TBD or EnergyPlus limitations). In such cases, the object is simply ignored. TBD pursues its (otherwise valid) calculations, and OpenStudio ultimately launches an EnergyPlus simulation. If a simulation indeed runs (ultimately a _go/no-go_ decision by the EnergyPlus simulation engine), it's again up to users to decide if simulation results are valid (or minimally useful) given the context. An example would be TBD ignoring thermal bridging effects of 4x window edges, when the window has invalid (optional) _frame & divider_ inputs in the OpenStudio model. The insulation material of the host surface may nonetheless be _derated_ from the edges of its other (valid) windows, but not from those of the poorly-defined one. In short, non-fatal ERROR logs point to bad input a user can readily fix.

TBD emits very few __WARNING__ log messages, mainly triggered from inherit limitations of the underlying _derating_ methodology (something the user has limited control over beforehand). For instance, a surface the size of a dinner plate has a very limited area to accommodate the additional heat loss from _major_ thermal bridging (which may trigger a WARNING log message). It's usually not a good idea to have such small surfaces in an OpenStudio model to start with, but neither OpenStudio nor EnergyPlus will necessarily warn users of such occurrences. It's also up to users to decide on the suitable course of action.

TBD - as with many other OpenStudio Measures - is written in Ruby. TBD integrates a number of sanity checks to ensure Ruby doesn't crash (e.g. invalid access to uninitialized variables), especially for lower-level functions. When this occurs, there are safe fallbacks. But a __DEBUG__ error is nonetheless logged by TBD. DEBUG errors are almost always signs of a bug (to be [reported](https://github.com/rd2/tbd/issues)). This is strictly made available for development purposes - TBD does not offer a proper _production debugging_ mode per se.

[back](../index.html "Thermal Bridging & Derating")
