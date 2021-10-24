
### Basics

This section goes over the _bare bones minimum_ of what's needed to run TBD as an OpenStudio Measure, including minimal OpenStudio model requirements, what additional inputs are needed, and finally how to actually run the measure.

Experienced OpenStudio users should feel comfortable jumping right in. Newcomers to OpenStudio are encouraged to first check out the [OpenStudio primer](./openstudio.html "An OpenStudio primer for TBD users") and/or official online documentation for [OpenStudio](https://openstudio.net "OpenStudio"), including the [OpenStudio Application](https://openstudiocoalition.org// "OpenStudio Application") - more than useful!

### Context

OpenStudio construction details and geometry are required architectural inputs for TBD. _Complete_ OpenStudio models also hold abstract variables like thermal zones and schedules, as well as electrical loads, lighting and HVAC systems. TBD works fine with such _complete_ models, yet is well capable of handling _partial_ or _minimal_ OpenStudio models.

Why? Let's start by venturing that there's more than one way to approach building energy modelling. One obvious scenario is to hire competent energy modellers who take care of everything - they're specialized and very good at what they do. Yet it has its drawbacks as a _centralized_ solution. TBD works just as well within more _distributed_ approaches, where specialists may contribute to the same collective energy model, yet at different stages of the design and on different parts of the model - ideally under supervisory versioning control (just like software development). Architectural professionals should be encouraged to update and maintain geometry and construction parameters (including thermal bridging) of an OpenStudio model throughout the design process. Same goes for lighting consultants, estimators, LCA assessors, etc.

In other cases, architects may simply wish to explore whether their designs comply with certain prescriptive envelope targets, which can be efficiently ascertained using OpenStudio & TBD (and without running a single energy simulation). If they're unsuccessful in achieving e.g., [UA'](./ua.html "UA' assessments") trade-off targets, they can always compensate by handing off the model to lighting and HVAC modellers. For the latter, inheriting a complete _architectural_ energy model can be a huge time saver. This fits in well with integrated design processes, while encouraging a healthy division of labour and fair distribution of professional liability. Let's go over what TBD requires from a _minimal_ OpenStudio model.

### Minimal model requirements

__Fully enclosed geometry__: OpenStudio (and to a large extent EnergyPlus) work much better in general when a building model is _geometrically enclosed_ i.e., _air tight_ (no gaps between surfaces). This also means no unintentional surface overlaps or loosely intersecting edges, windows properly _fitting_ within the limits of their parent (or host) wall, etc. The example [warehouse](../index.html "Thermal Bridging & Derating") is a good visual of what this all means. It's worth mentioning, as some third-party design software offer mixed results with _enclosed geometry_ when auto-generating BIM-to-BEM models. TBD & Topolys do have some built-in tolerances (25 mm), but they can only do their job if vertices, edges and surfaces are well connected. Note that _partial_ OpenStudio models are not required to holds ALL building surfaces - just those that comprise the _building envelope_, in addition to interior floor surfaces. If a building has cantilevered balconies for instance, it's also a good idea to include those as shading surfaces (yet _aligned_ with floor surfaces).

__Materials & constructions__: Geometry is not enough. TBD must be able to retrieve referenced materials and multilayered constructions for all _envelope_ surfaces. The easiest way is via _Default Construction Sets_.

__Boundary conditions__: It's important that the OpenStudio model reflects intended exposure to surrounding environmental conditions, including which surfaces face the exterior vs the interior, the ground, etc. TBD will only seek to _derate_ outdoor-facing _envelope_ walls, roofs and exposed floors. Windows, doors and skylights are never derated. Adiabatic and ground-facing (or KIVA foundation) surfaces are also never derated.

### Optional model requirements

TBD does require additional OpenStudio inputs in some circumstances. Unheated or uncooled spaces (like attics and crawlspaces) are considered _unconditioned_: their outdoor-facing surfaces aren't part of the _building envelope_, and therefore not targeted by TBD. On the other hand, outdoor-facing surfaces of _indirectly-conditioned_ spaces like plenums are considered part of the _envelope_, and therefore should be derated. Sections 2.3.2 to 2.3.4 [here](https://www.pnnl.gov/main/publications/external/technical_reports/PNNL-26917.pdf "90.1-2016 Performance Rating Method Reference Manual") provide a good overview of the question. Here's the underlying logic that guides TBD in such cases:

- With _partial_ OpenStudio models, TBD will seek to derate ALL outside-facing surfaces by positing that ALL spaces are _conditioned_, with _assumed_ setpoints of ~21°C (heating) and ~24°C (cooling) à la BETBG. This is OK for most models (even those with plenums), yet not for those with attics or crawlspaces.  
- If a _more complete_ OpenStudio model has at least one space linked to a _thermal zone_ having temperature setpoints, TBD will instead seek to only derate outdoor-facing surfaces of such _conditioned_ spaces. TBD will safely ignore outdoor-facing surfaces in _unconditioned_ spaces like attics and crawlspaces, yet unfortunately also those of plenums.  
- With a _fairly complete_ OpenStudio model (complete with thermal zones, temperature setpoints, and HVAC air loops), spaces will be tagged as indirectly-conditioned _plenums_ if their linked thermal zones correspond to supply or return plenums as defined [here](https://bigladdersoftware.com/epx/docs/9-6/input-output-reference/group-air-path.html#airloophvacreturnplenum "EnergyPlus return air plenums") and [here](https://bigladdersoftware.com/epx/docs/9-6/input-output-reference/group-air-path.html#airloophvacsupplyplenum "EnergyPlus supply air plenums") (let's call this __case A__).
- In absence of HVAC air loops, 2x other cases trigger a _plenum_ tag: __case B__ where the space is considered excluded from the building's _total floor area_ (an OpenStudio variable), while having its thermal zone referencing an _inactive_ thermostat (i.e. can't extract valid setpoints); or finally __case C__ where the _spacetype_ name is simply set to "plenum" (case insensitive).

In summary, asking TBD to distinguish between _conditioned_ vs _indirectly-conditioned_ vs _unconditioned_ spaces requires a combination of the following, depending on whether attics and/or crawlspaces are found in the OpenStudio model:

- thermal zones  
- heating/cooling setpoints  
- HVAC air loops  

This is a _lot_ to ask of most technically proficient architects, as most items are pretty specific HVAC items. There are OpenStudio user scripts that will auto-generate thermal zones from spaces (one-to-one), but it's unlikely to match what the HVAC designer has in mind (and so not always a good idea). With _unconditioned_ spaces, better off asking the HVAC engineer/modeller to complete the setup.

### TBD menu options

Whether TBD is accessed from the _OpenStudio Application_ Measures' tab or through a [CLI](https://nrel.github.io/OpenStudio-user-documentation/reference/command_line_interface/ "OpenStudio CLI") _workflow_, users have access to the same 8 menu options (shown here with their default values):

![TBD Menu Options](../assets/images/TBD-inputs.png "TBD Menu Options")

JSON input/output files, _UA'_ reports and _KIVA_ inputs are described in detail in the _TBD customization_, _UA'_ and _KIVA_ sections, respectively.

The __Default thermal bridge (set)__ pull-down menu of predefined, compact _psi_ sets is key for newcomers, especially in the early design stages. Users simply need to switch between default sets (and rerun the measure) to get a sense of the degree of thermal _derating_ that would take place, and how this affects energy simulation results. It's easy, yet coarse as the entire building is treated uniformly (check the _TBD customization_ section on handling multiple _psi_ sets). Each default set holds a shortlist of common thermal bridge shorthands or keywords, as well as their respective values (in W/K per meter), that are applied by TBD:

- _rimjoist_: any wall/floor or sloped-roof/floor edge  
- _parapet_: any wall/roof edge  
- _fenestration_: any window, door, skylight perimeter edge  
- _corner_: any wall/wall edge  
- _balcony_: any floor/shading edge  
- _party_: any adiabatic/wall edge (or /floor, or /roof)  
- _grade_: any edge along a slab-on-grade or foundation wall  
- _joint_: any _flat_ edge that _derates_ (e.g. roof curb)  
- _transition_: any _flat_ edge that is not a _joint_  

A few of the above deserve explanation.

A shared edge between 2 parallel, aligned surfaces is tagged as a (mild) __transition__. In every default _psi_ set, _transition_ edges have a value of 0 W/K per meter, i.e. no _derating_ takes place. OpenStudio models can hold many such _flat_ edges, which usually do not constitute _major_ thermal bridges. For instance when they delineate plenum walls from those of the occupied space (above or below). In other cases, they're simply artefacts of third-party software that generated the OpenStudio geometry (e.g. tessellation). Whenever TBD can't easily label an edge, it relies on _transition_ as a fallback.

Some _flat_ edges should not be labelled as _transitions_, like expansion __joints__ (or roof curbs) - they should be considered as major thermal bridges. Yet TBD is unable to distinguish between _transitions_ and _joints_ from OpenStudio geometry alone. The _TBD customization_ section shows users how to reset auto-labelled _transition_ edges into _joints_ when needed.

When the angle between 2 exposed surfaces exceeds 45° around an edge, TBD tags it either as a __corner__ or a __parapet__ (depending on the situation).

When an exposed surface holds an edge that isn't shared by another exposed surface, it's either a sign of geometric inconsistency (it happens), or that the building shares a demising (or __party__) partition with a neighbouring building. If the edge links an adiabatic surface, it tags the edge as a _party_ thermal bridge - otherwise it resorts to a _transition_ fallback.

What happens when an edge can be tagged with more than one label? For instance when an edge is shared between wall, door (sill), floor and balcony? TBD ultimately labels the edge according to the _psi_ value that represents the greatest heat loss. So if the _fenestration_ and _rimjoist psi_ values are 0.5 W/K per meter, yet the _balcony psi_ value is 0.8 W/K per meter, then the edge is tagged as a _balcony_ thermal bridge.

Such TBD rules are described in finer detail in the source code itself, which is publicly accessible and well documented: check for Ruby (.rb) files under the /lib folder of the TBD GitHub repository.

### Where does one get _psi_ data?

The [BETBG](https://www.bchydro.com/powersmart/business/programs/new-construction.html "Building Envelope Thermal Bridging Guide") & [thermalenvelope.ca](https://thermalenvelope.ca) collections are great resources to start with. They rely in part on past research initiatives, like ASHRAE's RP-1365 (which is also great). Building energy codes and ISO standards are also relevant resources. TBD relies on all of these for its default _psi_ sets:

|                         | W/K per m |  
|                    :--- | :---      |
|      __poor (BETBG)__   |           |
|                rimjoist | 1.000     |
|                 parapet | 0.800     |
|            fenestration | 0.500     |
|                  corner | 0.850     |
|                 balcony | 1.000     |
|                   party | 0.850     |
|                   grade | 0.850     |
|                   joint | 0.300     |
|                         |           |
|     __regular (BETBG)__ |           |
|                rimjoist | 0.500     |
|                 parapet | 0.450     |
|            fenestration | 0.350     |
|                  corner | 0.450     |
|                 balcony | 0.500     |
|                   party | 0.450     |
|                   grade | 0.450     |
|                   joint | 0.200     |
|                         |           |
|   __efficient (BETBG)__ |           |
|                rimjoist | 0.200     |
|                 parapet | 0.200     |
|            fenestration | 0.200     |
|                  corner | 0.200     |
|                 balcony | 0.200     |
|                   party | 0.200     |
|                   grade | 0.200     |
|                   joint | 0.100     |
|                         |           |
|    __spandrel (BETBG)__ |           |
|                rimjoist | 0.615     |
|                 parapet | 1.000     |
|            fenestration | 0.000     |
|                  corner | 0.425     |
|                 balcony | 1.110     |
|                   party | 0.990     |
|                   grade | 0.880     |
|                   joint | 0.500     |
|                         |           |
| __spandrel HP (BETBG)__ |           |
|                rimjoist | 0.170     |
|                 parapet | 0.660     |
|            fenestration | 0.000     |
|                  corner | 0.200     |
|                 balcony | 0.400     |
|                   party | 0.500     |
|                   grade | 0.880     |
|                   joint | 0.140     |
|                         |           |
|       __code (Québec)__ |           |
|                rimjoist | 0.300     |
|                 parapet | 0.325     |
|            fenestration | 0.350     |
|                  corner | 0.300     |
|                 balcony | 0.500     |
|                   party | 0.450     |
|                   grade | 0.450     |
|                   joint | 0.200     |
|                         |           |

The _poor_, _regular_ and _efficient_ general sets mirror those of the BETBG, laid out at the beginning the BETBG document. They provide a good ballpark figure of _bottom-of-the-barrel_ vs _high-performance_ technologies. The (basic) vs high-performance (HP) _spandrel_ sets offer a range of expect values for curtain/window wall technologies (also from the BETBG). TBD provides support for the Québec building energy code (which holds explicit requirements on _major_ thermal bridging). Finally, there is also a _(non thermal bridging)_ set where all _psi_ values are fixed at 0 W/K per meter - mainly used for quality control and debugging purposes.

### Running TBD (EnergyPlus simulation mode)

Newcomers need to specify where OpenStudio _measures_ are stored on their computer (_Preferences_ > _Change My Measures Directory_) - just download TBD in there (from GitHub or BCL). For OpenStudio Application users, simply drag & drop TBD as an _OpenStudio Measure_.

As with most OpenStudio measures, TBD does not modify the original OpenStudio model (like adding new _derated_ constructions) before running an EnergyPlus simulation. OpenStudio makes a _behind-the-scenes_ copy of the model, which is in turn modified before simulation. Although the terminology may be confusing, leave the _Alter OpenStudio model_ option checked for EnergyPlus simulations - this option is strictly for _Apply Measures Now_. Once the _Default thermal bridge (set)_ is selected, save the model and run the simulation.

Results should show an increase in heating loads for cold climates. For ASHRAE climate zone 7, heating should increase between 3% to 13% (depending on the building type) for _poor_ to _regular_ thermal bridging details in an otherwise well-insulated envelope. Consult the _TBD Reporting_ section to learn more on TBD feedback.

### Running TBD (_Apply Measures Now_ mode)

(to do)

... _segue into customization_

[back](../index.html "Thermal Bridging & Derating")  
