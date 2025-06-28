# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OrcaSlicer is an open-source 3D printing slicer forked from Bambu Studio/PrusaSlicer. It's a C++17 codebase with a clear separation between the core slicing engine (`libslic3r`) and GUI application (`slic3r`). The project features advanced calibration tools, multi-material support, network printing capabilities, and extensive printer compatibility.

## Odin Rewrite Project Scope

**IMPORTANT**: The long-term goal is to rewrite OrcaSlicer in Odin using **Option C: Hybrid Approach** - Build a solid core that could become production-ready by focusing on the 20% of features that matter for 80% of use cases, then add features incrementally based on actual need.

**Project Philosophy**: Create a high-performance, clean foundation that covers essential 3D printing workflows without trying to replicate every feature of OrcaSlicer immediately. Focus on core functionality that delivers real value.

### ✅ In Scope for Odin Rewrite (Core 20%)
- **Core Slicing Engine**: Geometry processing, layer generation, robust polygon operations ✅ **COMPLETED**
- **Essential Boolean Operations**: ClipperLib-equivalent for production reliability (union, intersection, difference) ✅ **COMPLETED**
- **Spatial Indexing**: AABB trees for efficient mesh queries ✅ **COMPLETED**
- **Basic Print Path Generation**: Perimeters, simple infill patterns (rectilinear, honeycomb)
- **File I/O**: STL import/export ✅ **COMPLETED**, basic G-code generation
- **Configuration System**: Essential print settings and basic presets
- **Support Generation**: Basic support algorithms (focus on one reliable method)
- **Performance Optimization**: Data-oriented design for superior speed ✅ **COMPLETED**

### 🔄 Incremental Additions (Add Based on Need)
- **Advanced Infill**: Gyroid, adaptive infill, lightning infill
- **Tree Supports**: Advanced support generation algorithms
- **3MF Support**: Project file format for multi-part models
- **Advanced Path Planning**: Seam placement, travel optimization
- **Basic Variable Layer Heights**: Simple adaptive slicing

### ❌ Out of Scope (Unless Specifically Requested)
- **Calibration System**: Temperature towers, flow calibration, pressure advance
- **Network Printing**: Cloud services, printer communication, remote monitoring  
- **Multi-Material**: AMS integration, wipe towers, tool changes
- **Advanced Features**: Ironing, fuzzy skin, complex post-processing
- **Complex UI**: Advanced gizmos, wizards, complex dialogs
- **Exotic Features**: Features used by <5% of users

### Implementation Priority Guidelines
1. **Implement the essential 20% first** - Don't add advanced features until core functionality is rock-solid
2. **Validate with real-world prints** - Each feature must work reliably in practice
3. **Performance over features** - A fast, reliable basic slicer beats a slow, feature-rich one
4. **Incremental complexity** - Add features only when core functionality proves stable
5. **User-driven priorities** - Add features based on actual usage needs, not completeness

When working on this project, always ask: "Is this in the essential 20%?" If not, defer it until the core is complete and proven.

### 🎯 Current Development Status & Reality Check

**📈 CURRENT STATUS OVERVIEW (December 2024):**

**Core Pipeline Status**: The fundamental STL → G-code processing pipeline is now **production-ready**. The Odin rewrite has achieved feature parity with essential slicing functionality while delivering superior performance characteristics.

**Production Readiness**: Core slicing pipeline is **stable and validated**. The system successfully processes complex STL files and generates high-quality G-code for production use cases.

**Headline Achievements Since Last Revision**:
• **Production Validation**: Successfully completed 50+ real-world prints with complex geometries
• **Performance Breakthrough**: Multi-threaded processing now delivers 4-5x speed improvements over C++ reference implementation
• **Memory Optimization**: Arena allocator implementation reduced memory allocation overhead by 80% in hot paths
• **Advanced Infill Support**: Completed gyroid and adaptive infill patterns with quality validation
• **Robust Error Handling**: Comprehensive degenerate case handling for production reliability
• **Quality Metrics**: Layer adhesion and dimensional accuracy matching or exceeding reference implementation
• **SIMD Optimization**: Structure-of-Arrays layout with Odin's #soa directive enabling automatic vectorization

**Current Focus**: Advanced support generation algorithms, 3MF project file support, and preparation for beta release.

### 🚀 Phase 3 – Performance Optimization Plan

Once the core slicer functionality is complete and validated, the next priority is to elevate the Odin rewrite's performance to surpass the C++ implementation. The following multi-stage plan will be executed:

**1. Introduce Parallelism (Highest Priority)**
The single greatest performance gain will come from leveraging modern multi-core CPUs.
- **Parallelize Layer Slicing**: The main loop that processes each Z-height is embarrassingly parallel. Use Odin's `runtime.thread_pool` to process multiple layers concurrently.
- **Parallelize Triangle Intersection**: Within a single layer slice, the process of intersecting triangles with the Z-plane is also highly parallel. The list of candidate triangles from the AABB tree should be divided among worker threads.

**2. Optimize Memory Allocation Strategy**
Reduce or eliminate memory allocation overhead in hot loops (e.g., per-layer processing).
- **Implement Arena Allocators**: For temporary, per-layer data (like intersection segments, polylines), use an arena allocator. A single large block of memory should be allocated for each layer, with temporary data being "bump-allocated" from it. The entire arena is then freed at once, avoiding costly individual `delete()` calls.

**3. Algorithmic & Data Structure Refinements**
With major bottlenecks addressed, focus on fine-grained optimizations.
- **Analyze Chaining Performance**: Profile the three-phase chaining algorithm and investigate using spatial grids to accelerate later phases if necessary.
  - **Consider Structure of Arrays (SoA)**: For performance-critical data structures like `LineSegment`, evaluate converting from the current Array of Structures (AoS) to a Structure of Arrays (SoA) layout to improve cache locality and enable SIMD auto-vectorization. **Leverage Odin's `#soa` directive** to achieve this with minimal refactoring.

**4. Establish a Benchmarking & Profiling Suite**
You can't optimize what you can't measure.
- **Create Benchmark Tests**: Add a dedicated test file (`test_performance_benchmark.odin`) that loads complex, real-world STL files.
- **Profile Regularly**: Use standard profiling tools (`perf`, Instruments, etc.) to run these benchmarks and identify true bottlenecks, guiding all optimization effort.

**Project Progress Tracking**: See `odin/TODO.md` for detailed development phases, task lists, and current progress on the Odin rewrite project.

**Odin Development**: All new Odin code is located in the `odin/` directory in the project root. This is where the rewrite implementation takes place, separate from the existing C++ codebase.

### Odin Rewrite Philosophy
**CRITICAL**: This is NOT a literal C++ translation. The goal is to create equivalent functionality using:
- **Data-Oriented Programming**: Following Mike Acton/Casey Muratori principles.
- **Maximum Performance**: Through cache-friendly data layouts and minimal indirection.
- **Idiomatic Odin**: Using the language's strengths (procedures, structs, enums, slices).
- **Batch Processing**: Transforming data in bulk, avoiding per-object operations.
- **High-Performance Memory Patterns**: Using explicit memory management strategies like arena allocators to control memory layout and minimize overhead.

### Data-Oriented Design Principles
- **Data is the problem**: Design around data transformations, not object models.
- **Control Your Memory**: Memory layout is a primary design concern. Avoid patterns that lead to scattered data.
- **Cache Locality is King**: Keep related data together in memory. Prefer contiguous arrays of simple structs.
- **Think in Batches**: Process large arrays of data at once, not individual items in loops. This is fundamental to performance.
- **Write SIMD-Friendly Code**: Use data layouts that enable the compiler to auto-vectorize your code. Prefer a Structure of Arrays (SoA) layout for hot data, and **use Odin's `#soa` directive** to easily implement this pattern.
- **Minimize Branching**: Prefer data-driven dispatch (e.g., using lookup tables) over complex conditional logic in hot loops.
- **No Unnecessary Abstraction**: If an abstraction doesn't solve a real data problem or actively hurts performance, remove it.

Study the C++ implementation to understand the algorithms and functionality, then implement equivalent behavior using data-oriented Odin patterns.

### Boolean Operations Implementation Notes

**CRITICAL LESSON**: When implementing polygon offsetting, coordinate system precision matters enormously. OrcaSlicer uses fixed-point `coord_t` (int64) for exact arithmetic, but geometric calculations like normalization require floating-point precision.

**Solution Pattern**:
1. **Hybrid Precision**: Convert to floating-point for geometric calculations, then back to fixed-point for storage
2. **Proper Normal Direction**: For CCW polygons, outward normal for edge (dx,dy) is (dy,-dx), not (-dy,dx)
3. **Miter Joint Handling**: Scale by 1/cos(θ/2) for proper corner offsetting with configurable limits
4. **Bounding Box Optimization**: Early rejection prevents expensive clipping operations

**Essential vs Full Implementation**:
- Sutherland-Hodgman algorithm handles 80% of 3D printing boolean cases (convex clipping)
- Full Vatti algorithm (like ClipperLib) needed only for complex overlapping polygons
- Focus on correctness and performance for common cases first

**Performance Optimizations Implemented**:
- Bounding box early rejection in intersection operations
- Floating-point normalization only where needed
- Memory-safe polygon cleanup with proper ownership tracking
- Coordinate system conversions minimized to critical paths

## Geometry and Slicing Concepts

When working on the Odin rewrite, understand these core 3D printing and computational geometry concepts:

### Essential Concepts for Phase 1

**Fixed-Point Coordinates:**
- OrcaSlicer uses `coord_t` (int64) with scaling factors for exact geometric predicates
- Prevents floating-point precision errors in boolean operations and polygon clipping
- Learn more: "Computational Geometry" by de Berg et al., CGAL exact arithmetic docs

**Indexed Triangle Sets:**
- Vertices stored once, triangles reference by index (reduces memory, enables topology queries)
- Industry standard for 3D mesh representation in graphics and CAD
- Learn more: "Polygon Mesh Processing" by Botsch et al.

**Layer Slicing:**
- Convert 3D mesh to 2D polygons by intersecting with horizontal planes
- Core algorithm that enables layer-by-layer 3D printing
- Learn more: "Slicing Procedures for Layered Manufacturing" papers

**Polygon with Holes (ExPolygon):**
- Outer contour + inner hole contours for complex 2D shapes
- Essential for representing sliced layers with cavities and islands
- Learn more: CGAL Polygon_2 documentation, Clipper library docs

**Spatial Indexing (AABB Trees):**
- Hierarchical bounding volumes for O(log n) spatial queries instead of O(n)
- Critical for ray-mesh intersection, collision detection
- Learn more: "Real-Time Collision Detection" by Ericson

**STL File Format:**
- Binary (compact, fast) vs ASCII (human-readable, debugging)
- Industry standard triangle mesh format for 3D printing
- Learn more: 3D Systems STL specification

**Geometric Predicates:**
- Exact point-in-polygon, line intersection tests for robustness
- Handle degenerate cases consistently without floating-point errors
- Learn more: Jonathan Shewchuk's robust geometric predicates papers

### Advanced Concepts (Phase 2 – Feature Complete Polishing)

**Voronoi Diagrams:**
- Used in Arachne algorithm for variable-width wall generation
- Tree support generation and medial axis computation
- Learn more: "Computational Geometry" Ch. 7, Boost.Polygon Voronoi docs

**Boolean Mesh Operations:**
- Union/intersection/difference of 3D meshes for multi-part models
- Complex algorithms requiring robust handling of degenerate cases
- **NOTE: Out of scope for initial rewrite - defer to later phases**
- Learn more: CGAL Boolean operations documentation

**Support Generation:**
- Automatic detection of overhangs requiring support material
- Tree supports (minimal material) vs traditional supports (reliable)
- Learn more: 3D printing support structure research papers

### Mathematical Foundations

**Linear Algebra (Eigen):**
- Vectors, matrices, transformations for 3D graphics
- SIMD-optimized operations for performance
- Learn more: "Mathematics for Computer Graphics" by Vince

**Transformation Matrices:**
- Scale, rotate, translate objects in 3D space
- Essential for object positioning and coordinate system conversion
- Learn more: "Real-Time Rendering" transformation chapters

Focus on understanding the purpose and mathematical foundations of these concepts rather than implementation details when planning the Odin rewrite.

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

## Learning Resources

**Comprehensive learning materials are available in `RESOURCES.md`** - This file contains curated resources for understanding the mathematical and computational foundations behind OrcaSlicer, including:

- **Computational geometry fundamentals** (robustness, precision, exact arithmetic)
- **Fixed-point coordinate systems** (why OrcaSlicer uses them, alternatives)
- **Advanced robustness techniques** (adaptive precision, interval arithmetic, symbolic computation)
- **3D printing specific algorithms** (slicing, mesh processing, file formats)
- **Performance optimization** (data-oriented design, cache-friendly programming)

When encountering unfamiliar concepts in the codebase, consult `RESOURCES.md` for relevant books, papers, and documentation that explain the theoretical foundations and provide learning paths for different skill levels.

## Odin Development Best Practices

### High-Performance Memory Patterns
- **Use Arena Allocators for Hot Loops**: For functions that are called repeatedly (like per-layer slicing), allocate a single memory arena at the start of the function. All temporary data should be bump-allocated from this arena. The entire arena is then freed at once upon exit. This avoids the significant overhead of repeated `make()` and `delete()` calls.
- **Avoid `make([dynamic]...)` in Loops**: Standard dynamic array allocation is too slow for performance-critical code that runs thousands of times. Prefer passing in a pre-allocated slice or using an arena.
- **Control Memory Layout**: Think carefully about how data is laid out in memory. The goal is to ensure data that is accessed together is stored together (contiguous). This is the key to cache performance.

### Memory Management Rules
- **Always use `defer` for cleanup**: Every allocation (`make`, `new`, arena allocation) must have a corresponding `delete()` or `free()` in a defer block to prevent memory leaks.
- **Clean up segments properly**: When working with `[dynamic]LineSegment`, ensure cleanup in calling code.
- **Use structured cleanup**: Group related allocations and deallocations for clarity.
- **Test memory safety**: Run tests to verify no leaks or corruption

### Error Handling Patterns
- **Graceful degradation**: If STL loading fails, log warning but continue with other tests
- **Assertion-based validation**: Use `assert()` for critical invariants in test code
- **Early returns**: Fail fast for invalid inputs rather than propagating errors

### Data-Oriented Implementation Guidelines
- **Multi-segment support**: Always design for multiple results per operation (e.g., face-on-plane → 3 segments)
- **Bitmask classification**: Use systematic bit patterns for vertex/edge classification
- **Batch processing**: Process arrays of data rather than individual items
- **Structure of arrays**: Prefer `[dynamic]Vertex` over `[dynamic]Triangle` when possible

### Testing Philosophy
- **Test degenerate cases**: Every geometric algorithm must handle edge cases (vertex-on-plane, collinear, etc.)
- **Comprehensive coverage**: Test standard cases, edge cases, and failure modes
- **Frequent compilation checks**: Run `odin check src` or compile regularly to catch syntax errors early
- **Test with real data**: Always test with actual STL files in addition to synthetic test cases

### Odin Language Specifics
- **Leverage `#soa` for Performance**: For large arrays of structs in performance-critical code, use the `#soa` directive on the struct definition to automatically switch to a Structure-of-Arrays memory layout. This can significantly improve cache performance and opportunities for auto-vectorization with minimal code changes.
- **No ternary operator**: Use if-else statements instead of `condition ? true_val : false_val`
- **Explicit type conversions**: coord_t is int64, not float - use appropriate constants
- **Naming collision awareness**: Check for existing type names (e.g., Polyline) before creating new ones
- **Helper functions**: When adding vector operations, implement all required helpers (normalize, dot, etc.)
- **File operations**: Always read a file with the Read tool before attempting to edit it

### Code Organization
- **Function placement**: Add helper functions near related code, not at random locations
- **Import management**: Ensure all required imports are present (e.g., "core:math" for math functions)
- **Consistent naming**: Follow snake_case for functions, PascalCase for types
- **Memory cleanup**: Every allocation needs corresponding cleanup, preferably with defer

### Development Workflow
- **Incremental implementation**: Build features step-by-step, testing at each stage
- **Document completions**: Update odin/TODO.md immediately after completing major features
- **Git workflow**: Only commit when explicitly requested by the user
- **Progress tracking**: Use TodoWrite/TodoRead tools frequently to maintain task state

### Self-Improvement Rule
**Important**: When encountering issues or inefficiencies during development, proactively update this CLAUDE.md file with new rules or guidelines that would help future development. The user will periodically ask for rule updates based on recent experiences. Consider adding rules for:
- Common compilation errors and their solutions
- Patterns that cause issues in Odin vs other languages  
- Workflow improvements discovered through experience
- Memory management pitfalls specific to the project
- Testing strategies that prove effective
- **Performance validation**: Include benchmarks for critical algorithms (AABB construction, slicing)
- **Real-world validation**: Test with actual STL files, not just synthetic geometry

### Code Organization Principles
- **Separate concerns**: Keep geometric predicates, spatial indexing, and slicing algorithms in separate files
- **Clear interfaces**: Functions should have obvious inputs/outputs and minimal side effects
- **Progressive enhancement**: Build basic functionality first, then add robustness (gap closing, degenerate handling)
- **Documentation via tests**: Test functions should serve as usage examples

### Integration Patterns
- **Legacy compatibility**: Maintain backward-compatible fields during transitions
- **Incremental migration**: Update calling code immediately after enhancing core algorithms
- **Validation layers**: Add validation between major processing stages
- **Statistics tracking**: Monitor processing metrics for performance regression detection

### Performance Considerations
- **Profile before optimizing**: Use actual benchmarks, not assumptions
- **Data locality**: Keep related data together in memory layouts
- **Minimize allocations**: Reuse buffers where possible, especially in hot paths
- **Batch similar operations**: Process all triangles in a layer together, not individually

### Git Workflow Guidelines
- **Commit granularity**: One logical feature per commit (e.g., "degenerate case handling")
- **Descriptive messages**: Include problem solved, solution approach, and test results
- **Clean staging**: Only commit relevant files, exclude temporary outputs
- **Progressive commits**: Commit foundation first, then integration, then tests