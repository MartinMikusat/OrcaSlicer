# Geometry and Mesh Processing Systems

## Overview

OrcaSlicer's geometry processing system forms the foundation of its 3D printing pipeline. Built on proven computational geometry libraries, it handles everything from basic 2D polygon operations to complex 3D mesh processing, spatial indexing, and boolean operations.

## Core Geometry Types

### Point Types
Implementation: `src/libslic3r/Point.hpp`

```cpp
// 2D Point with fixed-point coordinates
using Point = Eigen::Matrix<coord_t, 2, 1, Eigen::DontAlign>;
using Points = std::vector<Point>;

// 3D Point
using Point3 = Eigen::Matrix<coordf_t, 3, 1, Eigen::DontAlign>;
using Points3 = std::vector<Point3>;

// Coordinate types
using coord_t = int32_t;        // Fixed-point 2D coordinates
using coordf_t = double;        // Floating-point 3D coordinates
```

**Key Features**:
- **Fixed-Point 2D**: Uses scaled integers for numerical robustness
- **Floating-Point 3D**: Double precision for 3D operations
- **Eigen Integration**: Leverages Eigen for linear algebra operations
- **Memory Alignment**: DontAlign flag for optimal memory usage

### Polygon Types
Implementation: `src/libslic3r/Polygon.hpp`

```cpp
class Polygon {
public:
    Points points;
    
    // Core operations
    double area() const;
    bool is_clockwise() const;
    bool is_counter_clockwise() const;
    Point centroid() const;
    void reverse();
    void simplify(double tolerance);
    
    // Geometric queries
    bool contains(const Point &point) const;
    double distance_to(const Point &point) const;
    bool intersection(const Line &line, Point* intersection = nullptr) const;
};

class ExPolygon {
public:
    Polygon contour;           // Outer boundary
    Polygons holes;           // Inner holes
    
    // Area and validation
    double area() const;
    bool is_valid() const;
    void simplify(double tolerance);
    
    // Operations
    void scale(double factor);
    void translate(const Point &vector);
    void rotate(double angle);
};
```

**Design Principles**:
- **Explicit Hole Handling**: ExPolygon separates contour from holes
- **Orientation Consistency**: Clockwise contours, counter-clockwise holes
- **Validation**: Built-in checks for polygon validity
- **Transformation Support**: Scale, translate, rotate operations

### Line and Polyline Types
Implementation: `src/libslic3r/Line.hpp`, `src/libslic3r/Polyline.hpp`

```cpp
class Line {
public:
    Point a, b;
    
    // Geometric properties
    double length() const { return (b - a).cast<double>().norm(); }
    Vector normal() const;
    Vector direction() const;
    Point midpoint() const;
    
    // Intersection testing
    bool intersection(const Line &line, Point* intersection = nullptr) const;
    double distance_to(const Point &point) const;
    Point point_at(double t) const;  // Parametric point
};

class Polyline {
public:
    Points points;
    
    // Properties
    double length() const;
    bool is_closed() const { return points.front() == points.back(); }
    
    // Operations
    void append(const Point &point);
    void clip_end(double distance);
    void clip_start(double distance);
    void extend_end(double distance);
    void extend_start(double distance);
    void simplify(double tolerance);
    
    // Conversion
    Polygon polygon() const;  // Convert to closed polygon
};
```

## TriangleMesh System

### Core TriangleMesh Class
Implementation: `src/libslic3r/TriangleMesh.hpp`

```cpp
class TriangleMesh {
public:
    // Core data structures
    std::vector<stl_vertex> vertices;
    std::vector<stl_triangle_vertex_indices> faces;
    
    // Statistics and properties
    struct Statistics {
        int number_of_facets;
        int number_of_parts;
        float volume;
        Vec3f min, max;  // Bounding box
    };
    Statistics stats;
    
    // Core operations
    void scale(float factor);
    void scale(const Vec3f &versor);
    void translate(const Vec3f &displacement);
    void rotate(float angle, const Vec3f &axis);
    void mirror(const Axis &axis);
    void transform(const Transform3f &t);
    
    // Mesh analysis
    bool is_manifold() const;
    bool is_closed() const;
    bool has_degenerate_faces() const;
    Vec3f center() const;
    float volume() const;
    BoundingBoxf3 bounding_box() const;
    
    // Mesh repair
    void repair();
    void remove_degenerate_faces();
    void merge_vertices(double tolerance = 1e-6);
    void fill_holes();
    
    // Slicing support
    std::vector<IntersectionLine> slice(double z) const;
    void slice(const std::vector<double> &z, std::vector<Polygons> *layers) const;
    
    // File I/O
    bool load_stl(const std::string &input_file);
    bool save_stl(const std::string &output_file) const;
    bool load_obj(const std::string &input_file);
    
    // Conversion
    void from_other_mesh(const TriangleMesh &other);
    indexed_triangle_set to_indexed_triangle_set() const;
};
```

### Indexed Triangle Set
Implementation: `src/libslic3r/TriangleMesh.hpp`

```cpp
struct indexed_triangle_set {
    std::vector<Vec3f> vertices;
    std::vector<Vec3i> indices;  // Triangle vertex indices
    
    // Properties
    size_t num_vertices() const { return vertices.size(); }
    size_t num_faces() const { return indices.size(); }
    bool empty() const { return indices.empty(); }
    
    // Validation
    bool is_valid() const;
    void shrink_to_fit();
    
    // Operations
    void clear();
    void transform(const Transform3f &t);
    BoundingBoxf3 bounding_box() const;
};
```

**Design Benefits**:
- **Memory Efficiency**: Vertices stored once, referenced by index
- **Cache Friendly**: Better memory access patterns
- **GPU Compatible**: Suitable for GPU processing
- **Standard Format**: Compatible with graphics APIs

## Spatial Indexing System

### AABB (Axis-Aligned Bounding Box) Trees
Implementation: `src/libslic3r/AABBTreeIndirect.hpp`

```cpp
template<int Dimension>
class AABBTreeIndirect {
public:
    using BoundingBox = Eigen::AlignedBox<double, Dimension>;
    using VectorType = Eigen::Matrix<double, Dimension, 1>;
    
    // Tree construction
    void build(const std::vector<BoundingBox> &bboxes);
    void build_parallel(const std::vector<BoundingBox> &bboxes);
    
    // Spatial queries
    std::vector<size_t> query_intersecting(const BoundingBox &bbox) const;
    std::vector<size_t> query_intersecting_sphere(const VectorType &center, double radius) const;
    size_t query_closest_point(const VectorType &point) const;
    
    // Ray intersection
    struct Intersection {
        size_t primitive_id;
        double distance;
        VectorType point;
    };
    std::vector<Intersection> query_ray_intersections(
        const VectorType &origin, const VectorType &direction) const;
    
private:
    struct Node {
        BoundingBox bbox;
        union {
            struct {
                size_t left_child;
                size_t right_child;
            } internal;
            struct {
                size_t first_primitive;
                size_t num_primitives;
            } leaf;
        };
        bool is_leaf;
    };
    
    std::vector<Node> nodes;
    std::vector<size_t> primitive_indices;
    TBB_ALLOCATOR<Node> allocator;  // Thread-safe allocation
};
```

### AABBMesh Integration
Implementation: `src/libslic3r/AABBMesh.hpp`

```cpp
class AABBMesh {
public:
    AABBMesh(const indexed_triangle_set &its);
    
    // Ray-mesh intersection
    struct intersection_result {
        int face_id;
        Vec3f point;
        Vec3f normal;
        float distance;
    };
    
    std::optional<intersection_result> query_ray_intersection(
        const Vec3f &origin, const Vec3f &direction) const;
    
    // Distance queries
    float squared_distance_to_point(const Vec3f &point) const;
    Vec3f closest_point(const Vec3f &point) const;
    
    // Inside-outside testing
    bool is_inside(const Vec3f &point) const;
    
private:
    AABBTreeIndirect<3> tree;
    const indexed_triangle_set *mesh;
    std::vector<BoundingBoxf3> face_bboxes;
};
```

**Performance Characteristics**:
- **Build Time**: O(n log n) with parallel construction available
- **Query Time**: O(log n) for point queries, O(log n + k) for range queries
- **Memory Usage**: ~8 bytes per primitive + tree overhead
- **Thread Safety**: Read-only operations are thread-safe

## Geometry Algorithms

### Advanced Geometric Operations
Implementation: `src/libslic3r/Geometry/`

#### Voronoi Diagrams
Implementation: `src/libslic3r/Geometry/Voronoi.hpp`

```cpp
namespace Geometry {
    struct VoronoiDiagram {
        struct Site {
            Point point;
            size_t index;
        };
        
        struct Cell {
            std::vector<Point> vertices;
            std::vector<size_t> edges;
            Site site;
        };
        
        std::vector<Cell> cells;
        std::vector<Line> edges;
        
        // Construction
        static VoronoiDiagram construct(const Points &sites);
        static VoronoiDiagram construct_clipped(const Points &sites, const BoundingBox &clip_box);
        
        // Queries
        size_t nearest_site(const Point &query) const;
        std::vector<size_t> sites_in_range(const Point &center, double radius) const;
    };
}
```

#### Convex Hull
Implementation: `src/libslic3r/Geometry/ConvexHull.hpp`

```cpp
namespace Geometry {
    // 2D Convex Hull (Graham Scan)
    Polygon convex_hull(const Points &points);
    
    // 3D Convex Hull (QuickHull algorithm)
    indexed_triangle_set convex_hull_3d(const Points3 &points);
    
    // Convex hull with tolerance
    Polygon convex_hull_simplified(const Points &points, double tolerance);
}
```

#### Curve Fitting
Implementation: `src/libslic3r/Geometry/Curves.hpp`

```cpp
namespace Geometry {
    struct BezierCurve {
        std::vector<Point> control_points;
        
        Point evaluate(double t) const;
        Point derivative(double t) const;
        double length() const;
        Polyline tessellate(double tolerance) const;
    };
    
    struct BSpline {
        std::vector<Point> control_points;
        std::vector<double> knots;
        int degree;
        
        Point evaluate(double t) const;
        Polyline tessellate(double tolerance) const;
    };
    
    // Curve fitting
    BezierCurve fit_bezier(const Points &points, int degree = 3);
    BSpline fit_bspline(const Points &points, int degree = 3);
}
```

## Boolean Operations System

### Multi-Backend Architecture
Implementation: `src/libslic3r/MeshBoolean.hpp`

```cpp
enum class BooleanOperation {
    Union,
    Intersection,
    Difference,
    SymmetricDifference
};

enum class BooleanBackend {
    Auto,    // Automatic selection
    CGAL,    // Robust, slower
    MCUT,    // Fast, modern
    Libigl   // Academic, feature-rich
};

class MeshBoolean {
public:
    struct Result {
        indexed_triangle_set mesh;
        bool success;
        std::string error_message;
        
        // Statistics
        int input_faces_a, input_faces_b;
        int output_faces;
        double processing_time;
    };
    
    // Main interface
    static Result perform_operation(
        const indexed_triangle_set &mesh_a,
        const indexed_triangle_set &mesh_b,
        BooleanOperation operation,
        BooleanBackend backend = BooleanBackend::Auto
    );
    
    // Batch operations
    static Result union_multiple(const std::vector<indexed_triangle_set> &meshes);
    static Result difference_chain(const indexed_triangle_set &base, 
                                  const std::vector<indexed_triangle_set> &subtractors);
    
private:
    // Backend implementations
    static Result cgal_boolean(const indexed_triangle_set &a, const indexed_triangle_set &b, BooleanOperation op);
    static Result mcut_boolean(const indexed_triangle_set &a, const indexed_triangle_set &b, BooleanOperation op);
    static Result libigl_boolean(const indexed_triangle_set &a, const indexed_triangle_set &b, BooleanOperation op);
    
    // Validation
    static bool validate_input(const indexed_triangle_set &mesh);
    static Result repair_and_retry(const indexed_triangle_set &a, const indexed_triangle_set &b, BooleanOperation op);
};
```

### 2D Boolean Operations
Implementation: `src/libslic3r/ClipperUtils.hpp`

```cpp
namespace ClipperUtils {
    // Core operations using Clipper2 library
    Polygons union_ex(const Polygons &subject);
    Polygons union_ex(const Polygons &subject, const Polygons &clip);
    Polygons difference_ex(const Polygons &subject, const Polygons &clip);
    Polygons intersection_ex(const Polygons &subject, const Polygons &clip);
    Polygons xor_ex(const Polygons &subject, const Polygons &clip);
    
    // Offsetting (2D morphological operations)
    Polygons offset(const Polygons &polygons, double delta, 
                   ClipperLib::JoinType join_type = ClipperLib::jtRound,
                   double miter_limit = 3.0);
    
    // Simplification
    Polygons simplify_polygons(const Polygons &polygons, ClipperLib::PolyFillType fill_type);
    Polygons clean_polygons(const Polygons &polygons, double distance = 1.415);
    
    // Utilities
    double area(const Polygons &polygons);
    bool is_clockwise(const Polygon &polygon);
    Polygons reverse_polygons(const Polygons &polygons);
}
```

## Mesh Repair and Validation

### Validation System
Implementation: `src/libslic3r/TriangleMeshSlicer.hpp`

```cpp
class MeshValidator {
public:
    struct ValidationResult {
        bool is_valid;
        std::vector<std::string> errors;
        std::vector<std::string> warnings;
        
        // Specific issues
        bool has_degenerate_faces;
        bool has_duplicate_vertices;
        bool has_inverted_faces;
        bool is_manifold;
        bool is_closed;
        
        // Statistics
        int degenerate_face_count;
        int duplicate_vertex_count;
        int boundary_edge_count;
    };
    
    static ValidationResult validate(const indexed_triangle_set &mesh);
    static ValidationResult validate_topology(const indexed_triangle_set &mesh);
    static ValidationResult validate_geometry(const indexed_triangle_set &mesh, double tolerance = 1e-6);
    
private:
    static bool check_manifold_edges(const indexed_triangle_set &mesh);
    static bool check_consistent_orientation(const indexed_triangle_set &mesh);
    static std::vector<Vec3i> find_degenerate_faces(const indexed_triangle_set &mesh);
};
```

### Repair Algorithms
Implementation: `src/libslic3r/MeshRepair.hpp`

```cpp
class MeshRepair {
public:
    struct RepairOptions {
        bool remove_degenerate_faces = true;
        bool merge_duplicate_vertices = true;
        bool fill_holes = false;
        bool fix_orientation = true;
        double merge_tolerance = 1e-6;
        double hole_fill_max_area = 100.0;
    };
    
    struct RepairResult {
        indexed_triangle_set mesh;
        bool success;
        
        // Changes made
        int removed_degenerate_faces;
        int merged_vertices;
        int filled_holes;
        int flipped_faces;
    };
    
    static RepairResult repair(const indexed_triangle_set &input, const RepairOptions &options = {});
    
private:
    static RepairResult remove_degenerates(const indexed_triangle_set &mesh);
    static RepairResult merge_vertices(const indexed_triangle_set &mesh, double tolerance);
    static RepairResult fill_holes(const indexed_triangle_set &mesh, double max_area);
    static RepairResult fix_orientation(const indexed_triangle_set &mesh);
};
```

## Coordinate Systems and Transformations

### Scaling and Fixed-Point System
Implementation: `src/libslic3r/Point.hpp`

```cpp
// Scaling factors for coordinate conversion
constexpr double SCALING_FACTOR = 1000000.0;  // 1 unit = 1 micron
constexpr coord_t scale_(double val) { return coord_t(std::round(val * SCALING_FACTOR)); }
constexpr double unscale(coord_t val) { return double(val) / SCALING_FACTOR; }

// Point scaling operations
inline Point scale_(const Vec2d &point) {
    return Point(scale_(point.x()), scale_(point.y()));
}

inline Vec2d unscale(const Point &point) {
    return Vec2d(unscale(point.x()), unscale(point.y()));
}

// Vector scaling
inline Points scale_(const std::vector<Vec2d> &points) {
    Points result;
    result.reserve(points.size());
    for (const auto &p : points) {
        result.push_back(scale_(p));
    }
    return result;
}
```

### Transformation Matrices
Implementation: `src/libslic3r/Geometry.hpp`

```cpp
// 2D Transformations
class Transform2d {
public:
    Eigen::Matrix3d matrix;
    
    Transform2d() : matrix(Eigen::Matrix3d::Identity()) {}
    
    // Factory methods
    static Transform2d translation(const Vec2d &offset);
    static Transform2d rotation(double angle);
    static Transform2d scaling(double factor);
    static Transform2d scaling(const Vec2d &factors);
    static Transform2d reflection(const Vec2d &axis);
    
    // Operations
    Transform2d operator*(const Transform2d &other) const;
    Point transform_point(const Point &point) const;
    Polygon transform_polygon(const Polygon &polygon) const;
    
    // Properties
    bool is_identity() const;
    Transform2d inverse() const;
    double determinant() const;
};

// 3D Transformations
using Transform3d = Eigen::Transform<double, 3, Eigen::Affine>;
using Transform3f = Eigen::Transform<float, 3, Eigen::Affine>;
```

## External Library Integration

### CGAL Integration
Implementation: `src/libslic3r/CGALMesh.hpp`

```cpp
namespace CGALHelpers {
    // Type definitions for CGAL integration
    using K = CGAL::Exact_predicates_inexact_constructions_kernel;
    using Point_3 = K::Point_3;
    using Vector_3 = K::Vector_3;
    using Mesh = CGAL::Surface_mesh<Point_3>;
    
    // Conversion functions
    Mesh indexed_triangle_set_to_cgal_mesh(const indexed_triangle_set &its);
    indexed_triangle_set cgal_mesh_to_indexed_triangle_set(const Mesh &mesh);
    
    // CGAL-specific operations
    bool does_self_intersect(const indexed_triangle_set &mesh);
    indexed_triangle_set convex_hull(const indexed_triangle_set &mesh);
    std::vector<indexed_triangle_set> split_connected_components(const indexed_triangle_set &mesh);
    
    // Mesh quality
    double mesh_quality_score(const indexed_triangle_set &mesh);
    indexed_triangle_set improve_mesh_quality(const indexed_triangle_set &mesh);
}
```

### Boost.Geometry Integration
Implementation: `src/libslic3r/Geometry/BoostAdapter.hpp`

```cpp
// Boost.Geometry adaptations for OrcaSlicer types
BOOST_GEOMETRY_REGISTER_POINT_2D(Slic3r::Point, coord_t, cs::cartesian, x(), y())
BOOST_GEOMETRY_REGISTER_RING(Slic3r::Polygon)

namespace boost { namespace geometry { namespace traits {
    template<> struct tag<Slic3r::Point> { typedef point_tag type; };
    template<> struct coordinate_type<Slic3r::Point> { typedef coord_t type; };
    template<> struct coordinate_system<Slic3r::Point> { typedef cs::cartesian type; };
    template<> struct dimension<Slic3r::Point> : boost::mpl::int_<2> {};
}}}

namespace BoostGeometryHelpers {
    double distance(const Point &a, const Point &b);
    double area(const Polygon &polygon);
    bool intersects(const Polygon &a, const Polygon &b);
    Polygons intersection(const Polygon &a, const Polygon &b);
    Point centroid(const Polygon &polygon);
}
```

## Performance Considerations

### Memory Management
- **TBB Allocators**: Thread-safe memory allocation for parallel operations
- **Object Pooling**: Reuse of frequently allocated objects (Points, Polygons)
- **Lazy Evaluation**: Deferred computation of expensive properties
- **Cache Optimization**: Data structures optimized for cache locality

### Parallel Processing
```cpp
// Example of parallel mesh processing
void process_meshes_parallel(std::vector<indexed_triangle_set> &meshes) {
    tbb::parallel_for(tbb::blocked_range<size_t>(0, meshes.size()),
        [&](const tbb::blocked_range<size_t> &range) {
            for (size_t i = range.begin(); i != range.end(); ++i) {
                // Process each mesh in parallel
                meshes[i] = repair_mesh(meshes[i]);
            }
        }
    );
}
```

### SIMD Optimization
```cpp
// Vectorized distance calculations
#ifdef __AVX2__
inline void compute_distances_avx2(const Points &points, const Point &target, std::vector<double> &distances) {
    // AVX2 implementation for batch distance computation
    // 8 distances computed simultaneously
}
#endif
```

## Data Flow and Usage Patterns

### Typical Processing Pipeline
1. **Import**: Mesh loaded from file (STL, OBJ, 3MF)
2. **Validation**: Mesh checked for issues
3. **Repair**: Automatic fixing of common problems
4. **Transformation**: Scaling, rotation, translation as needed
5. **Spatial Indexing**: AABB tree built for fast queries
6. **Slicing**: 3D mesh sliced into 2D layers
7. **Boolean Operations**: Support generation, modifier application
8. **Export**: Final geometry exported for further processing

### Memory Usage Patterns
- **Streaming**: Large meshes processed in chunks
- **Caching**: Frequently accessed data cached in memory
- **Lazy Loading**: Expensive computations deferred until needed
- **Reference Counting**: Shared ownership of large mesh data

## Integration Points

### File Format Integration
- **STL**: Direct loading into TriangleMesh
- **3MF**: Complex geometry with materials and transformations
- **OBJ**: Mesh with optional materials
- **STEP**: CAD-quality geometry via OpenCASCADE

### Slicing Engine Integration
- **Layer Generation**: 3D mesh to 2D contours
- **Support Structures**: Geometric analysis for overhang detection
- **Infill Generation**: 2D polygon operations for infill patterns

### GUI Integration
- **Real-time Preview**: Efficient mesh rendering
- **Interactive Editing**: Gizmo-based transformations
- **Selection**: Spatial queries for picking operations

## Odin Rewrite Considerations

### Language Advantages
- **Memory Safety**: Eliminate buffer overflows and memory leaks
- **Performance**: Direct memory control without garbage collection overhead
- **Simplicity**: Reduced complexity compared to C++ template system
- **Parallelism**: Built-in support for parallel operations

### Architecture Preservation
The current geometry system architecture should be largely preserved:
- **Core Types**: Point, Polygon, TriangleMesh concepts
- **Spatial Indexing**: AABB tree structure and algorithms
- **Boolean Operations**: Multi-backend approach with fallbacks
- **Validation System**: Comprehensive mesh checking

### Modernization Opportunities
- **SIMD**: Better utilization of vector instructions
- **GPU Acceleration**: Parallel processing on GPU
- **Memory Layout**: Structure-of-arrays for better cache performance
- **API Design**: More consistent and discoverable interfaces

### External Dependencies
- **Geometry Libraries**: Consider pure Odin implementations
- **File I/O**: Native Odin parsers for mesh formats
- **Linear Algebra**: Efficient matrix/vector operations
- **Parallel Processing**: Leverage Odin's concurrency features

The geometry system represents one of the most stable and well-designed parts of OrcaSlicer, making it an excellent foundation for the Odin rewrite while offering opportunities for modernization and optimization.