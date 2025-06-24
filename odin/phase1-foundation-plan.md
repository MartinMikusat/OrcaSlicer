# OrcaSlicer Odin Rewrite - Phase 1: Foundation Plan

## Overview

This document outlines Phase 1 of the OrcaSlicer Odin rewrite, focusing on understanding and implementing the core geometry features needed to match the C++ version's functionality. Phase 1 establishes the fundamental concepts and data structures required for 3D printing slicing operations.

**Phase 1 Goal:** Implement the essential geometry foundation that enables basic slicing operations - converting 3D triangle meshes to 2D layer polygons.

## Core Features Analysis

### 1. Fixed-Point Coordinate System

**What it is:** OrcaSlicer uses 64-bit integers (`coord_t`) for internal coordinates with a scaling factor (typically 1e-5) to convert from real-world millimeter measurements.

**Why it's needed:**
- **Exact arithmetic**: Prevents floating-point precision errors in geometric operations
- **Robust predicates**: Ensures consistent results for point-in-polygon, line intersection tests
- **Polygon operations**: Critical for reliable 2D polygon clipping (not 3D mesh booleans)

**Where it's used:**
- All internal polygon operations
- Layer slicing calculations  
- Support generation
- 2D polygon clipping operations

**C++ Implementation:**
```cpp
using coord_t = int64_t;
extern double SCALING_FACTOR;  // 1e-5 or 1e-6
#define scale_(val) ((val) / SCALING_FACTOR)
#define unscale_(val) ((val) * SCALING_FACTOR)
```

**Learning Resources:**
- "Computational Geometry: Algorithms and Applications" by de Berg et al. (Chapter 4 on robustness)
- Jonathan Shewchuk's "Robust Adaptive Floating-Point Geometric Predicates"
- CGAL documentation on exact arithmetic

**Phase 1 Priority:** **CRITICAL** - Foundation for all geometry operations

---

### 2. Point and Vector Types

**What it is:** Basic 2D and 3D point/vector types using both fixed-point (internal) and floating-point (external interface) representations.

**Why it's needed:**
- **2D Points**: For polygon vertices, layer contours, toolpaths
- **3D Vectors**: For mesh vertices, normals, transformations
- **Type safety**: Separate types prevent mixing coordinate systems

**Where it's used:**
- Polygon representation
- Mesh vertex storage
- Transformation operations
- Distance calculations

**C++ Implementation:**
```cpp
using Point = Vec2crd;  // 2D fixed-point
using Vec3f = Eigen::Matrix<float, 3, 1>;  // 3D float
using Vec3d = Eigen::Matrix<double, 3, 1>; // 3D double
```

**Learning Resources:**
- "Mathematics for Computer Graphics" by John Vince
- Eigen library documentation
- "Real-Time Rendering" vector math appendix

**Phase 1 Priority:** **CRITICAL** - Basic building blocks

---

### 3. Triangle Mesh Representation (Indexed Triangle Set)

**What it is:** A 3D mesh stored as an array of vertices and an array of triangles (each triangle contains 3 indices into the vertex array).

**Why it's needed:**
- **Memory efficiency**: Vertices shared between triangles are stored only once
- **Topology queries**: Can find adjacent faces, vertex neighbors
- **Standard format**: Industry standard representation for 3D meshes

**Where it's used:**
- STL file loading
- 3D model representation
- Slicing operations
- Mesh processing algorithms

**C++ Implementation:**
```cpp
struct indexed_triangle_set {
    std::vector<Vec3f> vertices;      // 3D positions
    std::vector<Vec3i32> indices;     // Triangle vertex indices
};

class TriangleMesh {
    indexed_triangle_set its;
    TriangleMeshStats stats;
};
```

**Learning Resources:**
- "Polygon Mesh Processing" by Mario Botsch et al.
- OpenMesh documentation
- "Real-Time Rendering" mesh data structures chapter

**Phase 1 Priority:** **CRITICAL** - Core 3D representation

---

### 4. STL File Format Support

**What it is:** Support for reading and writing STL files in both binary and ASCII formats.

**Why both formats exist:**
- **Binary STL**: Compact (50 bytes per triangle), fast parsing, industry standard
- **ASCII STL**: Human-readable, easier debugging, text-based workflows
- **Compatibility**: Different tools prefer different formats

**File format details:**
- **Binary**: 80-byte header + 4-byte triangle count + 50 bytes per triangle
- **ASCII**: Text format with "solid name", "facet normal", "vertex" entries

**Where it's used:**
- Primary input format for 3D models
- Export functionality
- File format conversion

**C++ Implementation:**
Found in `stl_io.cpp`, uses admesh library for robust parsing

**Learning Resources:**
- 3D Systems STL file format specification
- "STL File Format" Wikipedia article
- Admesh library documentation

**Phase 1 Priority:** **CRITICAL** - Primary input format

---

### 5. 3MF File Format Support

**What it is:** Microsoft's modern 3D file format, ZIP-based with XML structure supporting materials, colors, and metadata.

**Why it's better than STL:**
- **Units and scale**: Explicit unit specification
- **Materials**: Color, texture, and material properties
- **Transformations**: Object positioning and scaling
- **Metadata**: Build information, print settings

**Where it's used:**
- Modern slicing workflows
- Multi-material printing
- Project file storage with embedded settings

**C++ Implementation:**
Found in `Format/3mf.cpp`, uses miniz for ZIP handling and expat for XML parsing

**Learning Resources:**
- 3MF Consortium specification
- Microsoft 3MF documentation
- ZIP file format specification

**Phase 1 Priority:** **HIGH** - Increasingly important format

---

### 6. Layer Slicing Algorithm

**What it is:** The core algorithm that converts a 3D triangle mesh into 2D polygons by intersecting the mesh with horizontal planes at each layer height.

**How it works:**
1. For each layer height, create a horizontal cutting plane
2. Find all mesh triangles that intersect this plane
3. Calculate intersection line segments
4. Connect line segments to form closed polygon contours
5. Handle holes and multiple parts per layer

**Why it's needed:**
- **Core functionality**: The fundamental operation of any slicer
- **Layer-based printing**: Enables layer-by-layer fabrication
- **Toolpath generation**: Provides 2D shapes for path planning

**Where it's used:**
- Primary slicing operation
- Preview generation
- Support structure calculation

**C++ Implementation:**
Found in `TriangleMeshSlicer.cpp`

**Learning Resources:**
- "Slicing Procedures for Layered Manufacturing Techniques" by Kulkarni & Dutta
- 3D printing textbooks on slicing algorithms
- Research papers on mesh slicing

**Phase 1 Priority:** **CRITICAL** - Core slicing functionality

---

### 7. Polygon and ExPolygon Types

**What it is:** 
- **Polygon**: A simple closed contour (array of 2D points)
- **ExPolygon**: A polygon with holes (outer contour + multiple inner hole contours)

**Why ExPolygon is needed:**
- **Complex shapes**: Letters, parts with cavities, swiss cheese effects
- **Layer representation**: Each sliced layer can have holes and islands
- **2D polygon operations**: Result of 2D polygon union/intersection operations

**Where it's used:**
- Layer contour representation
- Infill boundary definition
- Support area calculation
- 2D polygon clipping operations

**C++ Implementation:**
```cpp
class Polygon : public MultiPoint {
    Points points;  // Closed contour
};

class ExPolygon {
    Polygon contour;    // Outer boundary (CCW)
    Polygons holes;     // Inner holes (CW)
};
```

**Learning Resources:**
- "Computational Geometry" by de Berg et al. (Chapter 3 on polygons)
- CGAL Polygon_2 documentation
- Clipper library documentation (used by OrcaSlicer)

**Phase 1 Priority:** **CRITICAL** - Essential for layer representation

---

### 8. Basic Spatial Indexing (AABB Trees)

**What it is:** Axis-Aligned Bounding Box trees - a hierarchical spatial data structure that enables fast spatial queries.

**Why it's needed:**
- **Performance**: O(log n) queries instead of O(n) brute force
- **Ray casting**: Find mesh intersections for mouse picking, support detection
- **Collision detection**: Check if objects overlap
- **Spatial queries**: Find nearest triangles, closest points

**How it works:**
1. Build a binary tree where each node contains a bounding box
2. Leaf nodes contain actual triangles/geometry
3. Query by traversing tree, pruning branches that don't intersect

**Where it's used:**
- Mouse interaction with 3D models
- Support generation (overhang detection)
- Collision detection between objects
- Ray-mesh intersection for various algorithms

**C++ Implementation:**
```cpp
class AABBMesh {
    std::unique_ptr<AABBImpl> m_aabb;
    // Ray casting, distance queries
};
```

**Learning Resources:**
- "Real-Time Collision Detection" by Christer Ericson
- "Real-Time Rendering" acceleration structures chapter
- CGAL AABB_tree documentation

**Phase 1 Priority:** **HIGH** - Important for interactive features

---

### 9. Basic Geometric Operations

**What it is:** Fundamental geometric calculations and predicates needed for robust slicing operations.

**Essential operations:**
- **Point-in-polygon testing**: Determine if a point lies inside a polygon
- **Line-line intersection**: Find where two line segments cross
- **Distance calculations**: Point-to-point, point-to-line distances
- **Orientation tests**: Determine if three points make a left or right turn
- **Area calculations**: Compute polygon areas

**Why robustness matters:**
- **Degenerate cases**: Handle edge cases consistently (collinear points, zero-area triangles)
- **Numerical precision**: Avoid floating-point errors that cause failures
- **Consistency**: Same input always produces same output

**Where it's used:**
- Slicing algorithm intersection calculations
- 2D polygon clipping operations
- Support generation
- Toolpath planning

**C++ Implementation:**
Uses exact integer arithmetic in `int128` namespace for critical predicates

**Learning Resources:**
- Jonathan Shewchuk's papers on robust geometric predicates
- "Computational Geometry" robustness chapters
- CGAL exact predicates documentation

**Phase 1 Priority:** **CRITICAL** - Foundation for reliable geometry

---

### 10. Basic Configuration System

**What it is:** A system for storing and managing print settings like layer height, infill density, and print speeds.

**Why it's needed:**
- **User settings**: Store layer height, wall thickness, infill patterns
- **Printer profiles**: Different printers have different capabilities
- **Material settings**: Temperature, speeds vary by material
- **Presets**: Save common setting combinations

**Basic requirements:**
- Key-value storage with different data types (float, int, string, bool)
- Default values and validation
- Simple serialization (save/load settings)

**Where it's used:**
- Slicing parameter input
- G-code generation settings
- User interface configuration
- Print quality control

**C++ Implementation:**
Complex system in `libslic3r/Config.hpp` with inheritance and validation

**Learning Resources:**
- Configuration management design patterns
- JSON/INI file format specifications
- Software architecture books on settings management

**Phase 1 Priority:** **MEDIUM** - Simple version sufficient initially

---

## Phase 1 Implementation Scope

### Must Have (Critical Path)
1. **Fixed-point coordinate system** with scaling factor management
2. **Point and vector types** (2D/3D, fixed/float)
3. **Triangle mesh data structure** (indexed triangle set)
4. **STL file I/O** (binary and ASCII reading/writing)
5. **Basic slicing algorithm** (3D mesh to 2D layers)
6. **Polygon types** (simple polygon and ExPolygon with holes)
7. **Essential geometric predicates** (point-in-polygon, orientation)
8. **Basic spatial indexing** (simple AABB tree for ray casting)

### Should Have (Important but not blocking)
1. **3MF file support** (reading basic mesh data)
2. **Mesh validation** (check for common issues)
3. **Basic configuration system** (key-value settings storage)
4. **Error handling** (robust file I/O and geometry operations)

### Could Have (Nice to have)
1. **ASCII STL optimization** (faster parsing)
2. **Large file handling** (streaming, progress reporting)
3. **Basic mesh repair** (fix simple issues automatically)
4. **Performance profiling** (identify bottlenecks)

### Explicitly Out of Scope for Phase 1
1. **Boolean mesh operations** (union, intersection, difference of 3D meshes)
2. **Multi-material support** (AMS, tool changes, wipe towers)
3. **Network printing** (cloud services, printer communication)
4. **Calibration features** (temperature towers, flow calibration)
5. **Advanced slicing features** (variable layer heights, ironing, fuzzy skin)
6. **Complex support algorithms** (focus on basic support detection only)
7. **Voronoi diagrams** (used in Arachne variable-width walls)
8. **Advanced mesh processing** (complex repair, smoothing, optimization)

## Learning Path and Resources

### Foundational Mathematics
1. **Linear Algebra**: "Mathematics for Computer Graphics" by John Vince
2. **Computational Geometry**: "Computational Geometry: Algorithms and Applications" by de Berg et al.
3. **Numerical Robustness**: Jonathan Shewchuk's geometric predicates papers

### 3D Graphics and Mesh Processing
1. **Mesh Algorithms**: "Polygon Mesh Processing" by Mario Botsch et al.
2. **Real-Time Graphics**: "Real-Time Rendering" by Möller, Haines & Hoffman
3. **Collision Detection**: "Real-Time Collision Detection" by Christer Ericson

### 3D Printing Specific
1. **Slicing Algorithms**: "Slicing Procedures for Layered Manufacturing" papers
2. **File Formats**: STL specification, 3MF consortium documentation
3. **Layer Processing**: Research papers on 3D printing path planning

### Implementation References
1. **CGAL Library**: Computational geometry algorithms library
2. **Clipper Library**: 2D polygon boolean operations
3. **Eigen Library**: Linear algebra template library

## Questions and Research Needed

### Technical Decisions
1. **Coordinate Precision**: When to use 1e-5 vs 1e-6 scaling factor?
2. **Memory Management**: Custom allocators vs default Odin allocator?
3. **Error Handling**: Exception-style vs Result types in Odin?
4. **Threading**: Single-threaded Phase 1 or design for concurrency?

### Algorithm Details
1. **Slicing Robustness**: How to handle mesh intersections with layer planes?
2. **Polygon Orientation**: When do we need CCW vs CW winding?
3. **Spatial Indexing**: AABB tree vs spatial hashing for different use cases?
4. **File Format Priority**: Start with STL only or include 3MF in Phase 1?

### Learning Gaps
1. **Mesh Topology**: Understanding manifold vs non-manifold meshes
2. **2D Polygon Clipping**: How 2D polygon boolean operations work (not 3D mesh booleans)
3. **Numerical Precision**: When fixed-point arithmetic is necessary
4. **Slicing Edge Cases**: Handling degenerate triangles, thin features
5. **Spatial Data Structures**: AABB tree construction and traversal algorithms

### Implementation Strategy
1. **Data Layout**: Array-of-structures vs structure-of-arrays trade-offs
2. **API Design**: Functional style vs object-oriented patterns in Odin
3. **Testing Strategy**: Unit tests vs integration tests vs property-based testing
4. **Performance**: When to optimize vs when to prioritize correctness

## Success Criteria

### Functional Requirements
- [ ] Load STL files (binary and ASCII) into triangle mesh
- [ ] Slice triangle mesh into 2D polygon layers
- [ ] Handle polygons with holes (ExPolygon)
- [ ] Export sliced layers back to STL format
- [ ] Basic spatial queries (ray-mesh intersection)
- [ ] Robust geometric predicates (no floating-point errors)

### Quality Requirements
- [ ] No memory leaks or undefined behavior
- [ ] Consistent results (same input = same output)
- [ ] Handle edge cases gracefully (degenerate triangles, etc.)
- [ ] Performance acceptable for small-to-medium models (< 1M triangles)

### Learning Objectives
- [ ] Understand coordinate systems and precision requirements
- [ ] Know mesh data structures and topology concepts
- [ ] Grasp slicing algorithm fundamentals
- [ ] Comprehend file format structures and parsing
- [ ] Learn spatial indexing and query optimization

This foundation will enable basic slicing functionality and provide the platform for more advanced features in subsequent phases.