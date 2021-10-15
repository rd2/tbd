
### Basics

This section goes over the _bare bones minimum_ of what's needed to run TBD as an OpenStudio Measure, including minimal OpenStudio model requirements, what additional inputs are needed, and finally how to actually run the measure.

Experienced OpenStudio users should feel comfortable jumping right in. Newcomers to OpenStudio are encouraged to first check out the [OpenStudio primer](./openstudio.html "An OpenStudio primer for TBD users") and/or official online documentation for [OpenStudio](https://openstudio.net "OpenStudio"), including the [OpenStudio Application](https://openstudiocoalition.org// "OpenStudio Application") - more than useful!

### Context

OpenStudio construction details and geometry are required architectural inputs for TBD. _Complete_ OpenStudio models also hold abstract variables like thermal zones and schedules, in addition to electrical loads, lighting and HVAC systems. TBD works fine with such _complete_ models, yet is well capable of handling _partial_ or _minimal_ OpenStudio models.

Why? Let's start by venturing that there's more than one way to approach building energy modelling. One obvious scenario is to hire competent building energy modellers who take care of everything - they're specialized and very good at what they do. Yet it has its drawbacks as a _centralized_ solution. TBD works just as well within more _distributed_ approaches, where specialists may contribute to the same collective energy model, yet at different stages of the design and on different parts of the model - ideally under supervisory versioning control (just like software development). Architectural professionals should be encouraged to update and maintain geometry and construction parameters (including thermal bridging) of an OpenStudio model throughout the design process. Same goes for lighting consultants, estimators, LCA assessors, etc.

In other cases, architects may simply wish to explore whether their designs comply with certain envelope prescriptive targets, which can be efficiently ascertained using OpenStudio & TBD (and without running a single energy simulation). If they're unsuccessful in achieving e.g., [UA'](./ua.html "UA' assessments") trade-off targets, they can always hand off the model to lighting and HVAC modellers. For the latter, inheriting a complete _architectural_ energy model can be a huge time saver. This fits in well with integrated design processes, while encouraging a healthy division of labour and fair distribution of professional liability. Let's go over what TBD requires from a _minimal_ OpenStudio model.

### Minimal model requirements

__Fully enclosed geometry__: OpenStudio (and to a large extent EnergyPlus) work much better in general when a building model is _geometrically enclosed_ i.e., _air tight_ (no gaps between surfaces). This also means no unintentional surface overlaps or loosely intersecting edges, windows properly _fitting_ within the limits of their parent (or host) wall, etc. The example [warehouse](../index.html "Thermal Bridging & Derating") is a good visual of what this all means. It's worth mentioning, as some third-party design software offer mixed results with _enclosed geometry_ when auto-generating BIM-to-OSM models. TBD & Topolys do have some built-in tolerances (25 mm), but they can only do their job if vertices, edges and surfaces are well connected. Note that _partial_ OpenStudio models are not required to holds ALL building surfaces - just those that comprise the _building envelope_, as well as interior floor surfaces. If a building has cantilevered balconies for instance, it's also a good idea to include those as shading surfaces.

__Materials & constructions__: Geometry is not enough. TBD must be able to retrieve referenced materials and multilayered constructions for all _envelope_ surfaces. The easiest way is via _Default Construction Sets_.

__Boundary conditions__: It's important that the OpenStudio model reflects intended exposure to surrounding environmental conditions, including which surfaces face the exterior vs the interior, the ground, etc. TBD will only seek to _derate_ outdoor-facing _envelope_ walls, roofs and exposed floors. Windows, doors and skylights are never derated. Adiabatic and ground-facing (or KIVA foundation) surfaces are also never derated.

### Optional model requirements

TBD does require additional OpenStudio inputs in some circumstances. Unheated or uncooled spaces (like attics and crawlspaces) are considered _unconditioned_: their outdoor-facing surfaces aren't part of the _building envelope_, and therefore not targeted by TBD. On the other hand, outdoor-facing surfaces of _indirectly-conditioned_ spaces like plenums are considered part of the _envelope_, and therefore should be derated. Sections 2.3.2 to 2.3.4 [here](https://www.pnnl.gov/main/publications/external/technical_reports/PNNL-26917.pdf "90.1-2016 Performance Rating Method Reference Manual") provide a good overview of the question. Here's the underlying logic that guides TBD in such cases:

- With _partial_ OpenStudio models, TBD will seek to derate ALL outside-facing surfaces by positing that ALL spaces are _conditioned_, with _assumed_ setpoints of ~21°C (heating) and ~24°C (cooling) à la BETBG. This is OK for most models (even those with plenums), yet not for those with attics or crawlspaces.  
- If a _more complete_ OpenStudio model has at least one space linked to a _thermal zone_ having temperature setpoints, TBD will instead seek to only derate outdoor-facing surfaces of such _conditioned_ spaces. TBD will safely ignore outdoor-facing surfaces in _unconditioned_ spaces like attics and crawlspaces, yet unfortunately also those of plenums.  
- With a _fairly complete_ OpenStudio model (complete with thermal zones, temperature setpoints, and HVAC air loops), spaces will be tagged as indirectly-conditioned _plenums_ if their linked thermal zones correspond to supply or return plenums as defined [here](https://bigladdersoftware.com/epx/docs/9-6/input-output-reference/group-air-path.html#airloophvacreturnplenum "EnergyPlus return air plenums") and [here](https://bigladdersoftware.com/epx/docs/9-6/input-output-reference/group-air-path.html#airloophvacsupplyplenum "EnergyPlus supply air plenums") (let's call this _case A_).
- In absence of HVAC air loops, 2x other cases trigger a _plenum_ tag: _case B_ where the space is considered excluded from building's total floor area (an OpenStudio variable), while having its thermal zone referencing an _inactive_ thermostat (i.e., can't extract valid setpoints); or _case C_ where the _spacetype_ name is simply set to "plenum" (case insensitive).

In summary, asking TBD to distinguish between _conditioned_ vs _indirectly-conditioned_ vs _unconditioned_ spaces requires a combination of the following, depending on whether attics and/or crawlspaces are found in the OpenStudio model:

- thermal zones  
- heating/cooling setpoints  
- HVAC air loops  

This is a _lot_ to ask of most technically-inclined architects, as these are pretty specific HVAC items. There are OpenStudio user scripts that will auto-generate thermal zones from spaces (one-to-one), but it's unlikely to match what the HVAC designer has in mind (and therefore often not a great idea). So with _unconditioned_ spaces, better off asking the HVAC engineer/modeller to complete the setup.

### Where does one get psi data?

- TBD defaults  
- envelope details & specs  
- manufacturer data  
- [BETBG](https://www.bchydro.com/powersmart/business/programs/new-construction.html "Building Envelope Thermal Bridging Guide") & [thermalenvelope.ca](https://thermalenvelope.ca)  
- past research projects  
- codes and standards  

### TBD menu options

(to do)

### Running TBD (energy simulation mode)

(to do)

### Running TBD (_Apply Measures Now_ mode)

(to do)

... _segue into customization_

[back](../index.html "Thermal Bridging & Derating")  
