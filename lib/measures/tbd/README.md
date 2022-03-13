

###### (Automatically generated documentation)

# Thermal Bridging and Derating - TBD

## Description
Derates opaque constructions from major thermal bridges.

## Modeler Description
Consult rd2.github.io/tbd

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Alter OpenStudio model (Apply Measures Now)
For EnergyPlus simulations, leave CHECKED. For iterative exploration with Apply Measures Now, UNCHECK to preserve original OpenStudio model.
**Name:** alter_model,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Load 'tbd.json'
Loads existing 'tbd.json' file (under '/files'), may override 'default thermal bridge' set.
**Name:** load_tbd_json,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Default thermal bridge set
e.g. 'poor', 'regular', 'efficient', 'code' (may be overridden by 'tbd.json' file).
**Name:** option,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Write 'tbd.out.json'
Write out 'tbd.out.json' file e.g., to customize for subsequent runs (edit, and place under '/files' as 'tbd.json').
**Name:** write_tbd_json,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Generate UA' report
Compare ∑U•A + ∑PSI•L + ∑KHI•n : 'Design' vs UA' reference (see pull-down option below).
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
Generates Kiva settings & objects for surfaces with 'foundation' boundary conditions (not 'ground').
**Name:** gen_kiva,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Force-generate Kiva inputs
Overwrites 'ground' boundary conditions as 'foundation' before generating Kiva inputs (recommended).
**Name:** gen_kiva_force,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




