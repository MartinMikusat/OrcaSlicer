# OrcaSlicer Technical Documentation

This documentation provides a comprehensive technical analysis of OrcaSlicer's features and implementation details, intended to support a potential rewrite in Odin.

## Documentation Structure

### Core Systems
- [Geometry & Mesh Processing](./core/geometry.md) - 3D model handling, mesh operations
- [Slicing Engine](./core/slicing.md) - Layer generation and slicing algorithms
- [G-code Generation](./core/gcode.md) - Toolpath planning and G-code output
- [Configuration System](./core/configuration.md) - Settings, profiles, and inheritance

### Feature Documentation
- [Print Features](./features/print_features.md) - Infill, supports, bridges, etc.
- [Calibration Tools](./features/calibration.md) - Temperature towers, flow calibration
- [Multi-Material Support](./features/multi_material.md) - MMU, AMS, tool changing
- [Network Printing](./features/network_printing.md) - OctoPrint, Klipper, Moonraker

### UI Components
- [Main Interface](./ui/main_interface.md) - Window layout and organization
- [3D Scene](./ui/3d_scene.md) - OpenGL rendering and interaction
- [Gizmos](./ui/gizmos.md) - Object manipulation tools
- [Configuration Tabs](./ui/configuration.md) - Settings interface

### Algorithms
- [Infill Patterns](./algorithms/infill.md) - Various infill algorithms
- [Support Generation](./algorithms/supports.md) - Tree supports, normal supports
- [Path Planning](./algorithms/path_planning.md) - Travel optimization, seam placement
- [Mesh Operations](./algorithms/mesh_ops.md) - Boolean operations, simplification

### Data Structures
- [Object Model](./data/object_model.md) - Model, ModelObject, ModelInstance
- [Print Data](./data/print_data.md) - Print, PrintObject, PrintRegion
- [Configuration](./data/configuration.md) - ConfigOption types and storage
- [Geometry Types](./data/geometry_types.md) - Points, polygons, meshes

### File Formats
- [3MF Format](./formats/3mf.md) - Project file format
- [STL/OBJ Import](./formats/mesh_formats.md) - Mesh file handling
- [G-code Format](./formats/gcode.md) - Output format specification
- [Config Files](./formats/config.md) - JSON profile format

### Implementation Notes
- [Memory Management](./implementation/memory.md) - Object lifecycle and ownership
- [Threading Model](./implementation/threading.md) - Parallel processing approach
- [Error Handling](./implementation/errors.md) - Exception and error strategies
- [Platform Specifics](./implementation/platform.md) - OS-specific code

## Analysis Approach

Each document follows this structure:
1. **Overview** - High-level description of the component
2. **Current Implementation** - How it works in C++
3. **Key Classes/Functions** - Important code elements
4. **Algorithms** - Detailed algorithm descriptions
5. **Data Flow** - How data moves through the system
6. **Dependencies** - What it relies on
7. **Odin Considerations** - Notes for rewrite

## Getting Started

Begin with:
1. [Core Architecture Overview](./architecture.md) - System-wide design
2. [Feature Catalog](./feature_catalog.md) - Complete feature list
3. [Build & Dependencies](./build_system.md) - Build process analysis