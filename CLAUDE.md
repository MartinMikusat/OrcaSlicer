# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OrcaSlicer is an open-source 3D printing slicer forked from Bambu Studio/PrusaSlicer. It's a C++17 codebase with a clear separation between the core slicing engine (`libslic3r`) and GUI application (`slic3r`). The project features advanced calibration tools, multi-material support, network printing capabilities, and extensive printer compatibility.

## Odin Rewrite Project Scope

**IMPORTANT**: The long-term goal is to rewrite OrcaSlicer in Odin. However, the initial scope is deliberately limited to focus on core functionality:

### ✅ In Scope for Odin Rewrite
- **Core Slicing Engine**: Geometry processing, layer generation, path planning
- **Basic Print Settings**: Layer heights, walls, infill patterns, speeds
- **File I/O**: STL, 3MF import/export, G-code generation
- **Support Generation**: Basic support algorithms (tree and traditional)
- **Simple GUI**: Basic model loading, slicing, and preview
- **Configuration System**: Core print settings and presets

### ❌ Out of Scope (Initially)
- **Calibration System**: Temperature towers, flow calibration, pressure advance
- **Network Printing**: Cloud services, printer communication, remote monitoring  
- **Multi-Material**: AMS integration, wipe towers, tool changes
- **Advanced Features**: Variable layer heights, ironing, fuzzy skin
- **Complex UI**: Advanced gizmos, wizards, complex dialogs

When working on this project, prioritize the in-scope features and avoid implementing the excluded functionality until the core system is stable and complete.

**Project Progress Tracking**: See `TODO.md` in the project root for detailed development phases, task lists, and current progress on the Odin rewrite project.

**Odin Development**: All new Odin code is located in the `odin/` directory in the project root. This is where the rewrite implementation takes place, separate from the existing C++ codebase.

### Odin Rewrite Philosophy
**CRITICAL**: This is NOT a literal C++ translation. The goal is to create equivalent functionality using:
- **Data-Oriented Programming**: Following Mike Acton/Casey Muratori principles
- **Maximum Performance**: Cache-friendly data layouts, minimal indirection
- **Idiomatic Odin**: Use Odin's strengths (procedures, structs, enums, slices)
- **Batch Processing**: Transform data in bulk, avoid per-object operations
- **Memory Efficiency**: Contiguous arrays, structure-of-arrays over array-of-structures

### Data-Oriented Design Principles
- **Data is the problem**: Design around data transformations, not object models
- **Cache locality**: Keep related data together in memory
- **SIMD-friendly**: Use data layouts that enable vectorization
- **Minimize branching**: Prefer data-driven dispatch over conditionals
- **Batch operations**: Process arrays of data, not individual items
- **No unnecessary abstraction**: If it doesn't solve a real data problem, remove it

Study the C++ implementation to understand the algorithms and functionality, then implement equivalent behavior using data-oriented Odin patterns.

## Build System & Commands

### Build Scripts
- **Windows:** `build_release_vs2022.bat` (requires Visual Studio 2022, CMake 3.13-3.31.x)
- **macOS:** `./build_release_macos.sh [options]` (requires Xcode, specific CMake version)
- **Linux:** `./build_linux.sh -u && ./build_linux.sh -disr` or Docker-based builds

### macOS Build Options
```bash
./build_release_macos.sh -d    # Build dependencies only
./build_release_macos.sh -s    # Build slicer only
./build_release_macos.sh -x    # Use Ninja generator (faster)
./build_release_macos.sh -a arm64  # Specify architecture
```

### CMake Requirements
- CMake 3.13+ (Windows: exactly 3.13.x-3.31.x series)
- Platform-specific deployment targets enforced
- Dependency management through `deps/` directory

## Testing Framework

### Test Structure
- **Framework:** Catch2 (configured in `tests/CMakeLists.txt`)
- **Test Data:** Located in `tests/data/`
- **Test Categories:**
  - `tests/libslic3r/` - Core slicing engine tests
  - `tests/fff_print/` - FFF printing tests  
  - `tests/sla_print/` - SLA printing tests
  - `tests/libnest2d/` - Nesting algorithm tests

### Running Tests
Tests are built as part of the main build process. Individual test executables are generated for each test category.

## Code Architecture

### Core Components
- `src/libslic3r/` - Platform-agnostic slicing engine
  - Geometry processing, slicing algorithms, G-code generation
  - Configuration system, file format handling
  - Fill patterns, support generation, path planning
- `src/slic3r/` - GUI application (wxWidgets-based)
  - 3D scene rendering, user interface components
  - Print job management, printer communication

### Key Libraries & Dependencies
- **Geometry:** libigl, clipper, admesh, qhull
- **GUI:** wxWidgets, ImGui, OpenGL
- **File I/O:** miniz, expat, nlohmann/json
- **Algorithms:** TBB (threading), Eigen (linear algebra)
- **Networking:** libcurl, WebView2 (Windows)

### File Format Support
- **Input:** STL, OBJ, 3MF, AMF, STEP
- **Output:** G-code, 3MF project files
- **Configuration:** JSON-based printer/material profiles

## Configuration System

### Profile Structure
- Printer profiles in `resources/profiles/`
- Material settings, process profiles
- JSON-based configuration with inheritance
- Runtime profile validation and processing

### Key Configuration Classes
- `ConfigOption` - Individual setting definitions
- `ConfigBase` - Configuration containers
- `Preset` - Profile management
- `PresetBundle` - Complete configuration sets

## Development Guidelines

### Code Style
- C++17 standard throughout
- Platform-specific code isolated in `src/platform/`
- Header-only libraries preferred where possible
- Extensive use of templates and generic programming

### Memory Management
- Smart pointers used extensively
- Clear object ownership patterns
- RAII principles throughout

### Error Handling
- Exception-based error handling
- Comprehensive validation at API boundaries
- Graceful degradation for non-critical failures

## Network Printing Support

OrcaSlicer supports 15+ network printing hosts including:
- OctoPrint, Klipper/Moonraker, PrusaLink
- Bambu Lab printers, Duet, RepRapFirmware
- Custom host implementations possible

## Advanced Features

### Calibration System
- Temperature towers, flow rate calibration
- Pressure advance testing, retraction tuning
- Automated test pattern generation

### Multi-Material Support
- Tool-changing printers, MMU support
- Bambu AMS integration
- Advanced purge tower algorithms

### Print Quality Features
- Precise wall generation, seam control
- Adaptive layer heights, variable width extrusion
- Bridge detection and optimization

## Troubleshooting Build Issues

### Windows
- Ensure correct CMake version (3.13.x-3.31.x)
- Avoid Strawberry Perl PATH conflicts
- Install required runtimes: WebView2, vcredist2019

### macOS
- Use correct Xcode version
- Handle app quarantine for unsigned builds
- Ensure proper architecture selection (arm64/x86_64)

### Dependencies
- All dependencies managed through `deps/` system
- Platform-specific dependency resolution
- Version pinning for reproducible builds

## Technical Documentation

Extensive technical documentation is available in the `llm/` directory, including:
- Architecture analysis and component documentation
- Algorithm implementations and data structures  
- File format specifications and UI component details
- Feature catalogs and implementation notes

This documentation provides deep technical insight into OrcaSlicer's implementation and can guide development decisions and architectural understanding.