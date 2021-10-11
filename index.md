A guide to [TBD](https://github.com/rd2/tbd) - an [OpenStudio Measure](https://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/) that auto-detects _major_ thermal bridges (like balconies, parapets and corners) and then _derates_ outside-facing opaque constructions (walls, roofs and exposed floors).

### In a nutshell ...

_Thermal bridges_ are structural elements that interrupt the continuity of insulation in building envelopes. A curtain wall spandrel back pan may hold in place an R17 (RSi 3.0) batt of insulation, yet the spandrel's overall R-value may trickle down to R5 (RSi 0.9) - less than a third of its nominal value. This drop in performance is due to highly conductive materials (e.g. galvanized steel, aluminium), spandrel height-to-width ratio, and how the back pan is held in place continuously along spandrel edges.

_Minor_ thermal bridges are regularly-spaced supports or framing elements (such as studs and Z-bars): the initial _derated_ R-value (from _minor_ thermal bridging), generally known as a construction's _clear-field effective R-value_, is largely independent of a surface's actual geometry or adjacencies to other surfaces. This means design changes to surface geometry (e.g. floor-to-ceiling height, number of windows) can be made without having to update surface _clear-field effective R-values_ - very practical. For a few simple 2D framing configurations, the ASHRAE Fundamentals and ISO standards support established hand-calculations like _parallel-path_ and _isothermal-planes_ methods. Yet in most cases, designers are better off consulting published collections of common configurations (with estimated _clear-field effective R-values_), such the [BETBG](https://www.bchydro.com/powersmart/business/programs/new-construction.html) or [thermalenvelope.ca](https://thermalenvelope.ca).

_Major_ thermal bridging instead relates to a surface's geometry and its immediate adjacencies (e.g. thermal bridging along roof parapets, slab edges, corners, cantilevered balconies). While surface area heat loss (under _standard_ test conditions) is best represented with U-values (or interchangeably U-factors) in W/K per square meter, linear thermal conductances from _major_ thermal bridges are commonly annotated using the greek letter PSI (units in W/K per meter) - KHI for point conductances (in W/K per point). Both _BETBG_ and _thermalenvelope.ca_ links above provide useful PSI and KHI data for common cases.

Contrary to _minor_ thermal bridging, changing a room's height or adding windows should trigger a revised calculation of _major_ thermal bridging effects. This can be quite daunting, time-consuming and error-prone to do by hand (per design iteration), given the hundreds (if not thousands) of _major_ thermal bridges in a building model. The simple [US DOE Commercial Reference Warehouse Model](https://www.energy.gov/eere/buildings/commercial-reference-buildings) illustrated here has over 300 of such _major_ thermal bridges - mostly around fenestration.

![US DOE Commercial Reference Warehouse](./assets/images/warehouse.png "US DOE Commercial Reference Warehouse")

Relying on the [Topolys](https://github.com/automaticmagic/topolys) gem, TBD automatically - and pretty instantaneously - identifies and manages _major_ thermal bridges behind the scenes for OpenStudio users.

### Energy Simulation

While materials, constructions and envelope surfaces are well established variables in OpenStudio and energy simulation engines like EnergyPlus, _edges_ and _points_ are not! TBD automatically factors-in PSI and KHI losses from _major_ thermal bridges it manages, by further _derating_ a construction's _clear-field effective R-value_ - more specifically by further decreasing its insulating layer thickness. This approach, in line with published research and standards such as ASHRAE's [RP-1365](https://www.techstreet.com/standards/rp-1365-thermal-performance-of-building-envelope-details-for-mid-and-high-rise-buildings?product_id=1806751), _BETBG_ & _thermalenvelope.ca_, as well as ISO [10211](https://www.iso.org/standard/65710.html) and [14683](https://www.iso.org/standard/65706.html), is best summarized as follows:
```
Ut = Uo + ( ∑PSI•L )/A + ( ∑KHI•n )/A
```
... where:

__Ut__ : final _derated_ construction transmittance, in W/K per square meter  
__Uo__ : initial _clear field_ transmittance, in W/K per square meter  
__PSI__ : linear transmittance for a given surface edge, in W/K per meter  
__L__ : length of the surface edge, in meters  
__KHI__ : point transmittance for a given beam, post, etc.  
__n__ : number of similar beams, posts, etc.  
__A__ : opaque surface area, in square meters  

As discussed in some detail further on, TBD users are required to initially define generic __PSI__ and __KHI__ values that best characterize the _major_ thermal bridges in their project - TBD/Topolys automatically identify individual _edge_ occurrences in the OpenStudio model, just as with geometric variables like __L__ and __A__ (... __n__ requires specific treatment, discussed a bit further).

Each OpenStudio construction is usually comprised of multiple material layers (typically 2 or 3 at a minimum), each of which has a thermal resistance. Users are expected to have already factored in _minor_ thermal bridging effects by decreasing the nominal thickness of the _insulating_ layer of each construction - a standard technique in energy simulation. __Uo__ is simply the inverse of the sum of resulting layer resistances (yet excluding the effect of surface air films). Behind the scenes, TBD automatically generates new _derated_ materials and constructions - the latter having their unique __Ut__.

[OpenStudio primer for TBD](./pages/openstudio.html "An OpenStudio primer for TBD users") 
[Gathering inputs](./pages/inputs.html "Basic TBD inputs and workflow")  
[Customization](./pages/custom.html "Customizing TBD inputs")  
[Reporting](./pages/reports.html "What TBD reports back")  
[KIVA](./pages/kiva.html "Kiva support")  
[UA'](./pages/ua.html "UA' assessments")  


_(in progress ...)_
