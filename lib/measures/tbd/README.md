

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


### Load tbd.json
Loads existing tbd.json from model files directory, overrides other arguments if true.
**Name:** load_tbd_json,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Default thermal bridge option to use if not reading tbd.json
e.g. poor, regular, efficient, code
**Name:** option,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Write tbd.out.json
Write tbd.out.json to customize for subsequent runs. Edit and place in model files directory as tbd.json
**Name:** write_tbd_json,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




