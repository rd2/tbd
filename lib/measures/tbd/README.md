

###### (Automatically generated documentation)

# Thermal Bridging and Derating - TBD

## Description
Derates opaque constructions from major thermal bridges.

## Modeler Description
(see github.com/rd2/tbd)

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Load 'tbd.json'
Loads existing 'tbd.json' file from model 'files' directory, may override 'default thermal bridge' pull-down option.
**Name:** load_tbd_json,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Default thermal bridge option
e.g. 'poor', 'regular', 'efficient', 'code' (may be overridden by 'tbd.json' file).
**Name:** option,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Write 'tbd.out.json'
Write 'tbd.out.json' file to customize for subsequent runs. Edit and place in model 'files' directory as 'tbd.json'.
**Name:** write_tbd_json,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Generate UA' report
Compare ∑U•A + ∑PSI•L + ∑KHI•n, vs UA' reference (pull-down option below)
**Name:** gen_UA_report,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### UA' reference
e.g. 'poor', 'regular', 'efficient', 'code'.
**Name:** ua_reference,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Generate Kiva inputs
Generate Kiva settings & objects if any model surfaces have 'foundation' boundary conditions ('ground' facing surfaces are ignored).
**Name:** gen_kiva,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Force-generate Kiva inputs
Overwrites all 'ground' boundary conditions as 'foundation' before generating Kiva inputs (preferred solution).
**Name:** gen_kiva_force,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




