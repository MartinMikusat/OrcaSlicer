# OrcaSlicer System Architecture

## Overview

OrcaSlicer is a complex 3D printing slicer built on a fork of Bambu Studio (itself forked from PrusaSlicer). The architecture follows a clear separation between the core slicing engine (libslic3r) and the GUI application, with well-defined interfaces between components.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GUI Application                          │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────────────┐    │
│  │   MainFrame  │  │   Plater   │  │   Configuration    │    │
│  │              │  │            │  │      Tabs          │    │
│  └──────────────┘  └────────────┘  └─────────────────────┘    │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────────────┐    │
│  │  GLCanvas3D  │  │   Gizmos   │  │     Dialogs        │    │
│  │   (OpenGL)   │  │            │  │                    │    │
│  └──────────────┘  └────────────┘  └─────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┴────────────┐
                    │    Event System &      │
                    │    Message Passing     │
                    └───────────┬────────────┘
                                │
┌─────────────────────────────────────────────────────────────────┐
│                      Core Library (libslic3r)                   │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────────────┐    │
│  │    Model     │  │   Print    │  │      GCode         │    │
│  │  Management  │  │   Engine   │  │    Generator       │    │
│  └──────────────┘  └────────────┘  └─────────────────────┘    │
│  ┌──────────────┐  ┌────────────┐  ┌─────────────────────┐    │
│  │   Geometry   │  │    Fill    │  │     Support        │    │
│  │  Processing  │  │  Patterns  │  │    Generation      │    │
│  └──────────────┘  └────────────┘  └─────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

## Entry Points

### CLI Entry (`src/OrcaSlicer.cpp`)
- Command-line interface for batch processing
- Supports model loading, slicing, and G-code export
- Multi-plate batch processing
- Progress reporting via pipes (Linux)

### GUI Entry (`src/slic3r/GUI/GUI_App.cpp`)
- wxWidgets application class
- Initializes GUI subsystems
- Manages application lifecycle
- Handles command-line arguments for GUI mode

## Core Subsystems

### 1. Model Management
**Location**: `src/libslic3r/Model.*`

The model subsystem manages 3D objects and their properties:
- `Model`: Container for all objects in the scene
- `ModelObject`: Individual 3D object with geometry and settings
- `ModelVolume`: Part of an object (for multi-part objects)
- `ModelInstance`: Positioned instance of an object

Key features:
- Object transformation (translate, rotate, scale)
- Multi-material object support
- Modifier meshes and settings overrides
- Model validation and repair

### 2. Geometry Processing
**Location**: `src/libslic3r/` (various files)

Core geometric types and operations:
- `Point`, `Point3`: 2D/3D points
- `Polygon`, `ExPolygon`: 2D contours with holes
- `TriangleMesh`: 3D mesh representation
- `AABBMesh`: Spatial indexing for meshes

Advanced algorithms in `src/libslic3r/Geometry/`:
- Voronoi diagram generation
- Convex hull computation
- Curve fitting and smoothing
- Mesh boolean operations

### 3. Slicing Engine
**Location**: `src/libslic3r/Print.*`, `src/libslic3r/PrintObject.*`

The slicing pipeline:
1. **Print Preparation**
   - Object arrangement validation
   - Support generation if needed
   - Brim/skirt generation

2. **Layer Generation**
   - `TriangleMeshSlicer`: Slices 3D mesh into 2D contours
   - `SlicingAdaptive`: Calculates adaptive layer heights
   - `Layer`: Represents a single print layer
   - `LayerRegion`: Region within a layer with specific settings

3. **Path Generation**
   - `PerimeterGenerator`: Creates perimeter paths
   - `Fill/*`: Various infill pattern generators
   - `Arachne/*`: Variable-width path generation

4. **Feature Detection**
   - `BridgeDetector`: Identifies bridging areas
   - Overhang detection for support generation
   - Small feature detection for special handling

### 4. G-code Generation
**Location**: `src/libslic3r/GCode.*`

Converts paths to machine instructions:
- `GCode`: Main G-code generator class
- `GCodeWriter`: Low-level G-code formatting
- Post-processors in `src/libslic3r/GCode/`:
  - `CoolingBuffer`: Dynamic cooling control
  - `PressureEqualizer`: Pressure advance
  - `ConflictChecker`: Collision detection
  - `ThumbnailData`: Preview image generation

### 5. Configuration System
**Location**: `src/libslic3r/Config.*`, `src/libslic3r/Preset.*`

Hierarchical configuration management:
- `ConfigOption`: Base class for configuration values
- `DynamicConfig`: Runtime configuration container
- `Preset`: Named configuration set
- `PresetBundle`: Collection of presets (print, filament, printer)

Features:
- Configuration inheritance
- Profile import/export
- Validation and dependency checking
- JSON-based storage format

## GUI Architecture

### Main Window (`MainFrame`)
- Application menu bar and toolbar
- Status bar with progress indication
- Manages top-level dialogs
- Coordinates between different views

### Plater (`Plater`)
Central hub for 3D scene management:
- Object list management
- 3D view coordination
- Slicing process control
- Print preview generation

### 3D Rendering (`GLCanvas3D`)
OpenGL-based 3D visualization:
- Modern OpenGL with shaders
- Instanced rendering for performance
- Multiple rendering modes (solid, wireframe, etc.)
- Real-time preview updates

### Gizmos System
Interactive 3D manipulation tools:
- Base class: `GLGizmoBase`
- Implementations: Move, Rotate, Scale, Cut, Support Paint, etc.
- Event handling for mouse interaction
- Visual feedback and constraints

### Configuration Interface
Tabbed interface for settings:
- `Tab`: Base class for configuration tabs
- `TabPrint`: Print settings
- `TabFilament`: Material settings
- `TabPrinter`: Machine configuration
- Custom controls for specialized settings

## Threading and Async Operations

### Background Slicing (`BackgroundSlicingProcess`)
- Runs slicing in separate thread
- Progress reporting and cancellation
- Result marshaling to UI thread
- Memory-mapped file communication

### Job System
Framework for async operations:
- `Job`: Base class for background tasks
- `PlaterWorker`: Manages job queue
- Specialized jobs: `ArrangeJob`, `RotoptimizeJob`, `SendJob`
- Thread pool for parallel execution

### Thread Safety
- Core algorithms designed to be thread-safe
- Mutex protection for shared state
- UI updates via event system
- Careful memory management

## Communication Patterns

### Event System
- wxWidgets event infrastructure
- Custom events for application needs:
  - `EVT_SLICING_UPDATE`: Slicing progress
  - `EVT_GLCANVAS_*`: 3D view events
  - `EVT_EXPORT_BEGAN/FINISHED`: Export status

### Observer Pattern
- `ObjectBase` with modification tracking
- Observers notified of model changes
- Configuration change propagation
- Efficient update batching

### Message Passing
- Inter-thread communication via queues
- Platform-specific IPC for progress reporting
- WebSocket for network printer communication

## Data Flow

### Import to Export Pipeline

1. **File Import**
   - Format detection and parsing
   - Model validation and repair
   - Unit conversion if needed
   - Initial object placement

2. **Scene Setup**
   - Object arrangement on bed
   - Support generation
   - Multi-plate distribution
   - Settings assignment

3. **Slicing Process**
   - Layer generation
   - Path planning
   - Feature optimization
   - Multi-material coordination

4. **Export**
   - G-code generation
   - Post-processing
   - File output
   - Network transmission

## Memory Management

### Object Lifecycle
- Smart pointers for automatic management
- Shared ownership where appropriate
- Weak references to break cycles
- Explicit cleanup for large data

### Performance Optimizations
- Object pooling for small allocations
- Lazy evaluation of expensive operations
- Caching of computed results
- Memory-mapped files for large data

## Platform Abstraction

### Cross-Platform Support
- wxWidgets for UI abstraction
- Boost libraries for system features
- Custom wrappers for platform APIs
- Conditional compilation for specifics

### Platform-Specific Features
- Windows: Dark mode, file associations
- macOS: Native menu bar, gestures
- Linux: Desktop integration, package formats

## Extension Points

### Configuration Profiles
- JSON-based printer definitions
- Material property databases
- Custom print settings
- Post-processing scripts

### Plugin System
- Web-based plugin marketplace
- JavaScript bridge for integration
- G-code post-processors
- Custom calibration patterns

## Key Design Patterns

1. **Model-View-Controller**: Separation of data, presentation, and logic
2. **Observer**: Change notification throughout system
3. **Factory**: Object creation based on type
4. **Strategy**: Pluggable algorithms (fill patterns, supports)
5. **Command**: Undo/redo system implementation
6. **Singleton**: Application-wide services
7. **Facade**: Simplified interfaces to complex subsystems

## Odin Rewrite Considerations

### Architecture Advantages
- Clear module boundaries
- Well-defined interfaces
- Minimal coupling between subsystems
- Testable components

### Potential Improvements
- More explicit memory management
- Better error handling (vs exceptions)
- Simplified threading model
- More type safety
- Reduced dependency on external libraries

### Rewrite Strategy
1. Start with core geometry and mesh processing
2. Implement slicing algorithms
3. Build configuration system
4. Add G-code generation
5. Create new UI (possibly not wxWidgets)
6. Implement network features last