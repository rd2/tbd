### Customization

_placeholder for JSON file validation : https://jsonschemalint.com/#!/version/draft-04/markup/json_

### Dimensionning

Envelope surfaces are either modelled in OpenStudio based on _outer_ dimensions (i.e. following the exterior cladding, as in ASHRAE 90.1), or on _inner_ dimensions (i.e. following the interior finishing, as in the Canadian NECB). For most _flat_ edges, this isn't critical. But for concave or convex corners and parapets, adjustments to _psi_ values may be warranted if there is a mismatch in conventions between the OpenStudio model vs published _psi_ data (e.g. BETBG). For instance, BETBG data reflects an _inner_ dimensioning convention, while ISO 14683 reports _psi_ values for both conventions. The following equation may be used to adjust BETBG _psi_ values for e.g., convex corners, when relying on _outer_ dimensions in OpenStudio.
```
PSIe = PSIi + Uo * 2(Li - Le), where:

PSIe = adjusted PSI (W/K per m)
PSIi = published PSI value (W/K per m)
  Uo = average clear field effective U-value (W/K per m2)
  Li = from interior corner to "zone of influence" limits (m)
  Le = from exterior corner to "zone of influence" limits (m)
```
The _zone of influence_ usually ranges between ~1.0 to 1.2 meters - but the key parameter here is really the resulting wall thickness, and whether the sign is positive or negative - depending if it's a convex or concave corner. The BETBG and ISO standards provide detailed discussions on the subject.

[back](../index.html "Thermal Bridging & Derating")
