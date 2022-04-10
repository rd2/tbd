### Uprating

By default, TBD presumes an OpenStudio model's opaque surfaces (maybe in the hundreds) refer to one (or a few) common multilayered constructions that reflect _clear-field_ design intent. TBD subsequently _derates_ these multilayered constructions on a surface-per-surface basis for energy simulation purposes. So while each construction has a unique _clear-field_ __Uo__ value, each surface has a unique _derated_ __Ut__ value (once TBD is done).

Depending on the _extent_ of thermal bridging (due to each surface's edge lengths and _psi_ values), surface-specific _derating_ can range from _barely noticeable_ to _extensive_ (e.g. > 50%). One may start off with a single, common construction for all exterior wall surfaces, the latter will end up with sometimes radically different __Ut__ values.

```
Ut = Uo + ( ∑psi • L )/A + ( ∑khi • n )/A
```

This presumption is consistent with typical building energy simulation workflows. Yet determining what should be the initial (common) construction __Uo__ value may not be straightforward. What happens when designers are unsure of what initial _clear-field_ __Uo__ value they should start off with, given façade layouts and thermal bridging design choices? Is it economically wise to aim for much lower __Uo__ values, as a means to compensate for _major_ thermal bridging?

In some cases, building professionals may even choose (or are required) to achieve a maximum, area-weighted average __Ut__ for all exterior wall surfaces. It's the case for prescriptive requirements of the Canadian NECB 2017 and 2020 editions, e.g., a final, wall area-weighted average __Ut__ of 0.210 W/m2.K (R27) for climate zone 7 (NECB 2017). Depending on the _extent_ of thermal bridging, the initial _clear-field_ __Uo__ value for that single, common construction may need to be 0.160 (or much, much lower).

So in addition to _derating_ construction __Uo__ values (to final surface __Ut__ values) for energy simulation purposes, TBD offers designers the option to first autogenerate required _clear-field_ __Uo__ values (a process called _uprating_) to meet a given target, by reordering the above equation.

```
Uo = Ut - ( ∑psi • L )/A + ( ∑khi • n )/A
```

_Uprating_ menu options (see [Basics](./basics.html "Basic TBD workflow")), are paired together for _walls_, _roofs_ and/or exposed _floors_ (let's make things easy here by limiting the discussion to walls). The default value assigned to the "Wall construction(s) to 'uprate'" pull-down menu option is "NONE", disabling any _uprating_ calculations for walls. TBD nonetheless pre-scans an OpenStudio model to retrieve referenced wall constructions in order of prevalence - referenced constructions covering a larger area are listed higher up in the pull-down list. Users can either limit _uprating_ calculations to one (1x) such referenced wall construction, or to "ALL wall constructions" in a building model. The latter is an all-encompassing solution, overriding previously set construction assignments (the most prevalent wall construction is nonetheless retained as the basis for subsequent _uprating_ - and then _derating_ - calculations). Users can also set the desired, area-weighted __Ut__ value for selected walls (default values are those of the NECB 2017 for climate zone 7).

TBD will log (and flash on screen if using the OpenStudio Application) the calculated _clear-field_ __Uo__ value required to achieve the desired area-weighted __Ut__ for walls (see [Reporting](./reports.html "What TBD reports back")).

```
An initial wall Uo of 0.162 W/m2•K is required to achieve an overall Ut of 0.210 W/m2•K for ALL wall constructions.
```

The _uprating_ calculations are similar to [UA'](./ua.html "UA' assessments")  assessments, yet in reverse order. In any _UA_-type exercise (like the _uprating_ calculations), a significantly weaker component will have a disproportionate effect vs its area (as summarized in the very first paragraph of this [guide](../index.html "Thermal Bridging & Derating"), "In a nutshell ..."). For very efficient envelope designs (e.g. continuous outboard insulation, thermally-broken cladding clips, minimal fenestration, favourable façade aspect ratios), the degree of _uprating_ may be quite reasonable. It may however be very challenging (and onerous) to meet such ambitious __Ut__ targets when factoring-in weaker components (e.g., spandrels, poor detailing, lots of fenestration).

We strongly recommend to first investigate this feature relying on _Apply Measures Now_ feedback (ideally UNCHECKing the __Alter OpenStudio model__ option, as discussed at the end of [Basics](./basics.html "Basic TBD workflow")), to get a sense of how significant the _uprating_ calculations may end up altering your initial designs.

[back](../index.html "Thermal Bridging & Derating")  
