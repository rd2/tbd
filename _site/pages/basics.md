
### Basics

This section goes over the _bare bones minimum_ of what's needed to run TBD as an OpenStudio Measure, including minimal OpenStudio model requirements, what additional inputs are needed, and finally how to actually run the measure.

Experienced OpenStudio users should feel comfortable jumping right in. Newcomers to OpenStudio are encouraged to first check out the [OpenStudio primer](./openstudio.html "An OpenStudio primer for TBD users") and/or official online documentation for [OpenStudio](https://openstudio.net "OpenStudio"), including the [OpenStudio Application](https://openstudiocoalition.org// "OpenStudio Application") - more than useful!

### Context

OpenStudio construction details and geometry are required architectural inputs for TBD. _Complete_ OpenStudio models also hold abstract variables like thermal zones and schedules, in addition to electrical loads, lighting and HVAC systems. TBD works fine with such _complete_ models, yet is well capable of handling _partial_ or _minimal_ OpenStudio models.

Why? Let's start by venturing that there's more than one way to approach building energy modelling. One obvious scenario is to hire competent building energy modellers who take care of everything - they're specialized and very good at what they do. Yet it has its drawbacks as a _centralized_ solution. TBD works just as well within more _distributed_ approaches, where specialists may contribute to the same collective energy model, yet at different stages of the design and on different parts of the model - ideally under supervisory versioning control (just like software development). Architectural professionals should be encouraged in updating and maintaining geometry and construction parameters (including thermal bridging) of an OpenStudio model throughout the design process. Same goes for lighting consultants, estimators, LCA assessors, etc.

In other cases, architects may simply wish to explore whether their designs comply with certain envelope prescriptive targets, which can be efficiently ascertained using OpenStudio & TBD (and without running a single energy simulation). If they're unsuccessful in achieving e.g., [UA'](./ua.html "UA' assessments") trade-off targets, they can always hand off the model to lighting and HVAC modellers. For the latter, inheriting a complete _architectural_ energy model can be a huge time saver. This fits in well with integrated design processes, while encouraging a healthy division of labour and fair distribution of professional liability. Let's go over what TBD requires from a _minimal_ OpenStudio model.

### Minimal model requirements

__Fully enclosed geometry__: OpenStudio (and to a large extent EnergyPlus) work much better in general when a building model is _geometrically enclosed_ i.e., _air tight_ (no gaps between surfaces). This also means no unintentional surface overlaps or loosely intersecting edges, windows properly _fitting_ within the limits of their parent (or host) wall, etc. The example [warehouse](../index.html "Thermal Bridging & Derating") is a good visual of what this all means. It's worth mentioning, as some third-party design software offer mixed results with _enclosed geometry_ when auto-generating BIM-to-OSM models. TBD & Topolys do have some built-in tolerances (25 mm), but they can only do their job if vertices, edges and surfaces are well connected. Note that _partial_ OpenStudio models are not required to holds ALL building surfaces - just those that comprise the _building envelope_, as well as interior floor surfaces. If a building has cantilevered balconies for instance, it's also a good idea to include those as shading surfaces.

__Materials & constructions__: Geometry is not enough. TBD must be able to retrieve referenced materials and multilayered constructions for all _envelope_ surfaces. The easiest way is via _Default Construction Sets_.

__Boundary conditions__: It's important that the OpenStudio model reflects intended exposure to surrouding environmental conditions, including which surfaces face outside air vs the interior, the ground, etc. TBD will do a better job if the model is accurate. TBD will only _derate_ outside-facing _envelope_ walls, roofs and exposed floors. Windows, doors and skylights are never derated. Adiabatic and ground-facing (or KIVA foundation) surfaces are also never derated.

### Optional model requirements

- thermal zoning  
- heating/cooling _setpoints_  
- HVAC air loops  

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
