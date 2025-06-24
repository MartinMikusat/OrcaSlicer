# Documentation TODO

## Missing Files Referenced in README.md

The following files are referenced in the README.md but don't exist yet:

### Features
- `./features/print_features.md` - Infill, supports, bridges, etc.
- `./features/calibration.md` - Temperature towers, flow calibration
- `./features/multi_material.md` - MMU, AMS, tool changing

### UI Components
- `./ui/3d_scene.md` - OpenGL rendering and interaction
- `./ui/gizmos.md` - Object manipulation tools
- `./ui/configuration.md` - Settings interface

### Algorithms
- `./algorithms/infill.md` - Various infill algorithms
- `./algorithms/supports.md` - Tree supports, normal supports
- `./algorithms/path_planning.md` - Travel optimization, seam placement
- `./algorithms/mesh_ops.md` - Boolean operations, simplification

### Data Structures
- `./data/object_model.md` - Model, ModelObject, ModelInstance
- `./data/print_data.md` - Print, PrintObject, PrintRegion
- `./data/configuration.md` - ConfigOption types and storage
- `./data/geometry_types.md` - Points, polygons, meshes

### File Formats
- `./formats/3mf.md` - Project file format
- `./formats/mesh_formats.md` - Mesh file handling
- `./formats/gcode.md` - Output format specification
- `./formats/config.md` - JSON profile format

### Implementation Notes
- `./implementation/memory.md` - Object lifecycle and ownership
- `./implementation/threading.md` - Parallel processing approach
- `./implementation/errors.md` - Exception and error strategies
- `./implementation/platform.md` - OS-specific code

## Naming Convention Applied

All files now follow the `lowercase-with-hyphens.md` naming convention:
-  `configuration-system-analysis.md` (was `CONFIGURATION_SYSTEM_ANALYSIS.md`)
-  `geometry-architecture-analysis.md` (was `GEOMETRY_ARCHITECTURE_ANALYSIS.md`)
-  `file-format-analysis.md` (was `ORCA_FILE_FORMAT_ANALYSIS.md`)
-  `slicing-engine-documentation.md` (was `OrcaSlicer_Slicing_Engine_Documentation.md`)
-  `feature-catalog.md` (was `feature_catalog.md`)
-  `build-system.md` (was `build_system.md`)
-  `network-printing.md` (was `network_printing.md`)
-  `main-interface.md` (was `main_interface.md`)
-  UI files renamed consistently

## Next Steps

1. Create missing documentation files listed above
2. Populate empty directories (`algorithms/`, `data/`, `implementation/`)
3. Verify all internal cross-references are updated
4. Consider adding a documentation index or table of contents