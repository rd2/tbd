

###### (Automatically generated documentation)

# Thermal Bridging & Derating (TBD)

## Description
Thermally derates opaque constructions from major thermal bridges

## Modeler Description
(see github.com/rd2/tbd)

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Load TBD.json
Loads existing TDB.json from model directory, overrides other arguments if true.
**Name:** load_tbd_json,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Default thermal bridge option to use if not reading TDB.json
e.g. poor, regular, efficient, code
**Name:** option,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Write TBD.json
Write TBD.json to customize for subsequent runs, edit and place in model directory
**Name:** write_tbd_json,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




