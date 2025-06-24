# Slicing Engine and Algorithms

## Overview

The OrcaSlicer slicing engine is the core component that transforms 3D models into printable layers. It implements sophisticated algorithms for layer generation, perimeter creation, infill pattern generation, and support structure placement. The engine supports both traditional and advanced techniques like Arachne variable-width paths and adaptive layer heights.

## Core Slicing Pipeline

### Print Processing Architecture
Implementation: `src/libslic3r/Print.cpp`, `src/libslic3r/PrintObject.cpp`

```cpp
class Print {
public:
    enum ProcessingStep {
        psSketchValidation = 0,
        psModelValidation,
        psSlicing,
        psPerimeters,
        psPrepareInfill,
        psInfill,
        psIroning,
        psSupportMaterial,
        psEstimateTime,
        psWipeTower,
        psGCodeExport,
        psCount
    };
    
    // Main processing pipeline
    void process() {
        this->set_status(0, L("Processing triangulated mesh"));
        for (PrintObject *obj : m_objects) {
            obj->slice();                    // Step 1: Generate layers
            obj->make_perimeters();          // Step 2: Create perimeters
            obj->infill();                   // Step 3: Generate infill
            obj->generate_support_material(); // Step 4: Support structures
        }
        
        this->make_wipe_tower();             // Step 5: Multi-material tower
        this->make_skirt();                  // Step 6: Skirt/brim
    }
    
private:
    std::vector<PrintObject*> m_objects;
    PrintConfig m_config;
    PlateDataPtrs m_plate_data_list;
};

class PrintObject {
public:
    // Core slicing operations
    void slice();
    void make_perimeters();
    void prepare_infill();
    void infill();
    void generate_support_material();
    void detect_surfaces_type();
    
    // Data structures
    std::vector<Layer*> m_layers;
    LayerPtrs m_support_layers;
    ModelObject* m_model_object;
    SlicingParameters m_slicing_params;
};
```

### Slicing Parameters System
Implementation: `src/libslic3r/SlicingParameters.hpp`

```cpp
struct SlicingParameters {
    // Layer height configuration
    coordf_t layer_height;              // Base layer height
    coordf_t first_print_layer_height;  // Initial layer height
    coordf_t object_print_z_min;        // Minimum Z coordinate
    coordf_t object_print_z_max;        // Maximum Z coordinate
    
    // Raft configuration
    bool has_raft() const { return raft_layers > 0; }
    int raft_layers;
    coordf_t raft_contact_distance;
    coordf_t raft_expansion;
    
    // Support configuration
    coordf_t support_material_extruder_1_layer_height;
    coordf_t support_material_extruder_2_layer_height;
    coordf_t support_material_contact_distance_type;
    
    // Adaptive layer height
    bool adaptive_slicing;
    coordf_t adaptive_layer_height_variation;
    coordf_t adaptive_layer_height_threshold;
    
    // Validation
    bool valid() const;
    static SlicingParameters create_from_config(
        const PrintObject &object, 
        const DynamicPrintConfig &config);
};
```

## Layer Generation System

### Adaptive Layer Height Algorithm
Implementation: `src/libslic3r/SlicingAdaptive.cpp`

```cpp
class SlicingAdaptive {
public:
    struct FacetSlope {
        float min_z, max_z;
        float slope_max;    // Maximum slope angle
        Vec3f normal;       // Face normal vector
    };
    
    // Main adaptive slicing algorithm
    void set_slicing_parameters(SlicingParameters params) {
        m_slicing_params = params;
        prepare_layers();
    }
    
    // Generate adaptive layer heights based on mesh curvature
    std::vector<coordf_t> generate_layer_heights(
        const TriangleMesh &mesh,
        const SlicingParameters &params) {
        
        // Step 1: Analyze mesh curvature
        std::vector<FacetSlope> facet_slopes = analyze_mesh_curvature(mesh);
        
        // Step 2: Calculate optimal layer heights
        std::vector<coordf_t> layer_heights;
        for (const auto &slope : facet_slopes) {
            coordf_t optimal_height = calculate_optimal_height(slope, params);
            layer_heights.push_back(optimal_height);
        }
        
        // Step 3: Smooth layer height profile
        smooth_layer_heights(layer_heights, params);
        
        return layer_heights;
    }
    
private:
    coordf_t calculate_optimal_height(const FacetSlope &slope, 
                                     const SlicingParameters &params) {
        // Quality factor based on surface angle
        double quality_factor = std::min(1.0, std::tan(slope.slope_max) / 
                                       params.adaptive_layer_height_threshold);
        
        // Interpolate between min and max layer height
        return params.layer_height * (1.0 - quality_factor * 
                                    params.adaptive_layer_height_variation);
    }
    
    void smooth_layer_heights(std::vector<coordf_t> &heights, 
                             const SlicingParameters &params);
    std::vector<FacetSlope> analyze_mesh_curvature(const TriangleMesh &mesh);
};
```

### TriangleMeshSlicer Algorithm
Implementation: `src/libslic3r/TriangleMeshSlicer.cpp`

```cpp
class TriangleMeshSlicer {
public:
    enum SlicingMode {
        SlicingMode_Regular = 0,
        SlicingMode_EvenOdd = 1,
        SlicingMode_Positive = 2,
        SlicingMode_PositiveLargestContour = 3
    };
    
    // Main slicing interface
    void slice(const std::vector<double> &z, 
               SlicingMode mode,
               std::vector<Polygons> *layers) const {
        
        layers->resize(z.size());
        
        // Parallel processing of layers
        tbb::parallel_for(tbb::blocked_range<size_t>(0, z.size()),
            [&](const tbb::blocked_range<size_t> &range) {
                for (size_t layer_idx = range.begin(); layer_idx != range.end(); ++layer_idx) {
                    (*layers)[layer_idx] = slice_plane(z[layer_idx], mode);
                }
            });
    }
    
private:
    const indexed_triangle_set *m_mesh;
    
    // Slice a single plane through the mesh
    Polygons slice_plane(double z, SlicingMode mode) const {
        std::vector<IntersectionLine> lines;
        
        // Find all triangle-plane intersections
        for (size_t facet_idx = 0; facet_idx < m_mesh->indices.size(); ++facet_idx) {
            const Vec3i &face = m_mesh->indices[facet_idx];
            const Vec3f &v0 = m_mesh->vertices[face.x()];
            const Vec3f &v1 = m_mesh->vertices[face.y()];
            const Vec3f &v2 = m_mesh->vertices[face.z()];
            
            // Check if triangle intersects the plane
            IntersectionLine line;
            if (triangle_plane_intersection(v0, v1, v2, z, line)) {
                lines.push_back(line);
            }
        }
        
        // Connect intersection lines into polygons
        return connect_lines_to_polygons(lines, mode);
    }
    
    bool triangle_plane_intersection(const Vec3f &v0, const Vec3f &v1, const Vec3f &v2,
                                   double z, IntersectionLine &line) const {
        // Compute signed distances from vertices to plane
        double d0 = v0.z() - z;
        double d1 = v1.z() - z;
        double d2 = v2.z() - z;
        
        // Check for intersection
        bool has_positive = (d0 > 0) || (d1 > 0) || (d2 > 0);
        bool has_negative = (d0 < 0) || (d1 < 0) || (d2 < 0);
        
        if (!has_positive || !has_negative) {
            return false; // No intersection
        }
        
        // Find intersection points
        std::vector<Vec2f> intersections;
        
        if ((d0 > 0) != (d1 > 0)) {
            // Edge v0-v1 intersects plane
            double t = d0 / (d0 - d1);
            Vec3f intersection = v0 + t * (v1 - v0);
            intersections.push_back(Vec2f(intersection.x(), intersection.y()));
        }
        
        if ((d1 > 0) != (d2 > 0)) {
            // Edge v1-v2 intersects plane
            double t = d1 / (d1 - d2);
            Vec3f intersection = v1 + t * (v2 - v1);
            intersections.push_back(Vec2f(intersection.x(), intersection.y()));
        }
        
        if ((d2 > 0) != (d0 > 0)) {
            // Edge v2-v0 intersects plane
            double t = d2 / (d2 - d0);
            Vec3f intersection = v2 + t * (v0 - v2);
            intersections.push_back(Vec2f(intersection.x(), intersection.y()));
        }
        
        if (intersections.size() == 2) {
            line.a = scale_(intersections[0].cast<double>());
            line.b = scale_(intersections[1].cast<double>());
            return true;
        }
        
        return false;
    }
};
```

## Perimeter Generation System

### Classic Perimeter Generation
Implementation: `src/libslic3r/PerimeterGenerator.cpp`

```cpp
class PerimeterGenerator {
public:
    // Configuration
    const PrintRegionConfig *config;
    const PrintObjectConfig *object_config;
    const PrintConfig *print_config;
    
    // Main generation algorithm
    void process() {
        // Step 1: Generate outer perimeter
        Polygons outer_perimeter = m_layer->slices.surfaces;
        
        // Step 2: Generate inner perimeters by offsetting
        Polygons current_perimeter = outer_perimeter;
        for (int i = 0; i < config->wall_loops.value - 1; ++i) {
            Polygons next_perimeter = offset(current_perimeter, 
                                           -config->line_width.value);
            
            if (!next_perimeter.empty()) {
                m_perimeter_paths.push_back(create_perimeter_path(next_perimeter, i));
                current_perimeter = next_perimeter;
            }
        }
        
        // Step 3: Handle gap fill
        if (config->gap_fill_target.value != gftNowhere) {
            generate_gap_fill(current_perimeter);
        }
        
        // Step 4: Apply seam hiding
        optimize_seam_placement();
    }
    
private:
    void generate_gap_fill(const Polygons &inner_perimeter) {
        // Find areas too small for another perimeter but large enough to fill
        Polygons gaps = difference(
            offset(inner_perimeter, config->line_width.value / 2),
            offset(inner_perimeter, -config->line_width.value / 2)
        );
        
        // Convert gaps to fill paths
        for (const Polygon &gap : gaps) {
            if (gap.area() > scale_(pow(config->line_width.value, 2))) {
                m_gap_fill_paths.push_back(create_gap_fill_path(gap));
            }
        }
    }
    
    void optimize_seam_placement() {
        SeamPlacer placer(*config);
        placer.plan_perimeter_seams(m_perimeter_paths, 
                                   config->seam_position.value);
    }
};
```

### Arachne Variable-Width Path Generation
Implementation: `src/libslic3r/Arachne/`

```cpp
class SkeletalTrapezoidation {
public:
    struct BeadingStrategy {
        double default_width;
        double min_width;
        double max_width;
        
        // Calculate optimal number of beads for given width
        int compute_bead_count(double width) const {
            return std::max(1, (int)std::round(width / default_width));
        }
        
        // Distribute width among beads
        std::vector<double> compute_bead_widths(double total_width, 
                                              int bead_count) const {
            std::vector<double> widths(bead_count);
            double base_width = total_width / bead_count;
            
            // Adjust for minimum/maximum constraints
            for (int i = 0; i < bead_count; ++i) {
                widths[i] = std::clamp(base_width, min_width, max_width);
            }
            
            return widths;
        }
    };
    
    struct SkeletalNode {
        Point location;
        double distance_to_boundary;
        std::vector<SkeletalEdge*> connected_edges;
        bool is_junction;
    };
    
    struct VariableWidthPath {
        std::vector<Point> points;
        std::vector<double> widths;
        ExtrusionEntityRole role;
        
        // Convert to traditional extrusion paths
        ExtrusionPaths to_extrusion_paths() const {
            ExtrusionPaths paths;
            for (size_t i = 0; i < points.size() - 1; ++i) {
                paths.emplace_back(
                    role,
                    widths[i] * height,
                    Polyline({points[i], points[i+1]})
                );
            }
            return paths;
        }
    };
    
    // Main algorithm
    std::vector<VariableWidthPath> generate_paths(const ExPolygons &regions) {
        // Step 1: Generate skeleton using Voronoi diagram
        auto skeleton = generate_skeleton(regions);
        
        // Step 2: Assign bead counts to skeleton edges
        assign_bead_counts(skeleton);
        
        // Step 3: Generate variable-width paths
        return generate_variable_width_paths(skeleton);
    }
    
private:
    VoronoiDiagram generate_skeleton(const ExPolygons &regions);
    void assign_bead_counts(VoronoiDiagram &skeleton);
    std::vector<VariableWidthPath> generate_variable_width_paths(
        const VoronoiDiagram &skeleton);
};
```

## Infill System and Algorithms

### Infill Pattern Algorithms
Implementation: `src/libslic3r/Fill/`

#### Lightning Infill
Implementation: `src/libslic3r/Fill/Lightning/`

```cpp
class LightningGenerator {
public:
    struct LightningTreeNode {
        Point location;
        std::vector<LightningTreeNode*> children;
        LightningTreeNode* parent;
        bool is_root;
        double distance_to_boundary;
    };
    
    // Generate lightning infill pattern
    Polylines generate(const ExPolygon &area, double density, 
                      double line_spacing) {
        // Step 1: Generate supporting points based on density
        Points support_points = generate_support_points(area, density);
        
        // Step 2: Build tree structure connecting support points
        std::vector<LightningTreeNode> tree = build_lightning_tree(
            support_points, area);
        
        // Step 3: Convert tree to polylines
        return tree_to_polylines(tree, line_spacing);
    }
    
private:
    Points generate_support_points(const ExPolygon &area, double density) {
        Points points;
        double area_size = area.area();
        int point_count = (int)(area_size * density / 1000000.0); // Scale factor
        
        // Generate random points within the polygon
        BoundingBox bbox = area.contour.bounding_box();
        std::random_device rd;
        std::mt19937 gen(rd());
        
        for (int i = 0; i < point_count; ++i) {
            Point candidate;
            do {
                candidate = Point(
                    gen() % (bbox.max.x() - bbox.min.x()) + bbox.min.x(),
                    gen() % (bbox.max.y() - bbox.min.y()) + bbox.min.y()
                );
            } while (!area.contains(candidate));
            
            points.push_back(candidate);
        }
        
        return points;
    }
    
    std::vector<LightningTreeNode> build_lightning_tree(
        const Points &support_points, const ExPolygon &area) {
        // Use minimum spanning tree algorithm with boundary considerations
        // Implementation details involve complex graph algorithms...
    }
};
```

#### Gyroid Infill
Implementation: `src/libslic3r/Fill/Gyroid.cpp`

```cpp
class GyroidInfill : public Fill {
public:
    // Gyroid is a triply periodic minimal surface (TPMS)
    // Mathematical equation: sin(x)cos(y) + sin(y)cos(z) + sin(z)cos(x) = 0
    
    Polylines fill_surface(const Surface &surface, 
                          const FillParams &params) override {
        
        const ExPolygon &area = surface.expolygon;
        double density = params.density;
        double spacing = params.line_spacing;
        double z = params.z;
        
        // Generate gyroid pattern
        Polylines gyroid_lines;
        
        BoundingBox bbox = area.contour.bounding_box();
        double scale_factor = spacing * M_PI / sqrt(3.0); // Optimal spacing
        
        // Sample the gyroid function across the layer
        for (coord_t x = bbox.min.x(); x <= bbox.max.x(); x += scale_(spacing/4)) {
            std::vector<Point> intersections;
            
            for (coord_t y = bbox.min.y(); y <= bbox.max.y(); y += scale_(spacing/4)) {
                double fx = unscale(x) / scale_factor;
                double fy = unscale(y) / scale_factor;
                double fz = z / scale_factor;
                
                // Evaluate gyroid function
                double gyroid_value = sin(fx) * cos(fy) + 
                                    sin(fy) * cos(fz) + 
                                    sin(fz) * cos(fx);
                
                // Check for zero crossing (surface intersection)
                if (std::abs(gyroid_value) < 0.1 * density) {
                    Point candidate(x, y);
                    if (area.contains(candidate)) {
                        intersections.push_back(candidate);
                    }
                }
            }
            
            // Connect intersection points into polylines
            if (intersections.size() >= 2) {
                gyroid_lines.push_back(Polyline(intersections));
            }
        }
        
        return gyroid_lines;
    }
};
```

#### Adaptive Cubic Infill
Implementation: `src/libslic3r/Fill/AdaptiveCubic.cpp`

```cpp
class AdaptiveCubicInfill : public Fill {
public:
    struct OctreeNode {
        BoundingBox3 bbox;
        std::vector<std::unique_ptr<OctreeNode>> children;
        bool is_leaf;
        double local_density;
        int subdivision_level;
    };
    
    Polylines fill_surface(const Surface &surface, 
                          const FillParams &params) override {
        
        // Step 1: Build octree based on surface complexity
        auto octree = build_adaptive_octree(surface, params);
        
        // Step 2: Generate cubic infill with varying density
        return generate_adaptive_cubic_pattern(octree, surface, params);
    }
    
private:
    std::unique_ptr<OctreeNode> build_adaptive_octree(
        const Surface &surface, const FillParams &params) {
        
        // Analyze surface complexity
        double curvature = analyze_surface_curvature(surface);
        double overhang_ratio = calculate_overhang_ratio(surface);
        
        // Create root node
        auto root = std::make_unique<OctreeNode>();
        root->bbox = get_surface_bbox_3d(surface);
        root->local_density = params.density;
        
        // Recursively subdivide based on complexity
        subdivide_node(root.get(), surface, curvature, overhang_ratio, 0);
        
        return root;
    }
    
    void subdivide_node(OctreeNode *node, const Surface &surface,
                       double curvature, double overhang_ratio, int level) {
        
        const int MAX_SUBDIVISION = 4;
        if (level >= MAX_SUBDIVISION) {
            node->is_leaf = true;
            return;
        }
        
        // Calculate local complexity
        double complexity_factor = curvature + overhang_ratio * 0.5;
        
        if (complexity_factor > 0.3) { // Threshold for subdivision
            // Create 8 child nodes
            Vec3d center = node->bbox.center();
            Vec3d size = node->bbox.size() * 0.5;
            
            for (int i = 0; i < 8; ++i) {
                auto child = std::make_unique<OctreeNode>();
                // Calculate child bbox based on octant
                child->bbox = calculate_octant_bbox(node->bbox, i);
                child->local_density = node->local_density * (1.0 + complexity_factor);
                
                subdivide_node(child.get(), surface, curvature, overhang_ratio, level + 1);
                node->children.push_back(std::move(child));
            }
        } else {
            node->is_leaf = true;
        }
    }
};
```

## Support Generation Systems

### Traditional Support Algorithm
Implementation: `src/libslic3r/SupportMaterial.cpp`

```cpp
class SupportMaterial {
public:
    struct SupportParams {
        double xy_distance;
        double z_distance;
        double pattern_spacing;
        SupportMaterialPattern pattern;
        SupportMaterialStyle style;
        double interface_layers;
        double raft_layers;
    };
    
    // Generate support structures
    void generate(PrintObject &object) {
        // Step 1: Detect overhangs requiring support
        std::vector<ExPolygons> overhang_regions = detect_overhangs(object);
        
        // Step 2: Generate support contact areas
        std::vector<ExPolygons> contact_areas = generate_contact_areas(
            overhang_regions, params);
        
        // Step 3: Generate support base areas
        std::vector<ExPolygons> base_areas = generate_base_areas(
            contact_areas, object, params);
        
        // Step 4: Create support layers
        generate_support_layers(object, base_areas, contact_areas);
    }
    
private:
    std::vector<ExPolygons> detect_overhangs(const PrintObject &object) {
        std::vector<ExPolygons> overhangs(object.layer_count());
        
        for (size_t layer_idx = 1; layer_idx < object.layer_count(); ++layer_idx) {
            const Layer *current_layer = object.layers()[layer_idx];
            const Layer *below_layer = object.layers()[layer_idx - 1];
            
            // Find areas of current layer not supported by layer below
            ExPolygons current_slices = current_layer->lslices;
            ExPolygons below_slices = below_layer->lslices;
            
            // Expand below layer to account for overhang angle
            double overhang_width = current_layer->height * 
                                  tan(deg2rad(params.support_material_threshold));
            ExPolygons supported_area = offset_ex(below_slices, overhang_width);
            
            // Calculate unsupported areas
            overhangs[layer_idx] = diff_ex(current_slices, supported_area);
            
            // Filter out small overhangs
            double min_area = scale_(pow(params.support_material_spacing, 2));
            overhangs[layer_idx].erase(
                std::remove_if(overhangs[layer_idx].begin(), overhangs[layer_idx].end(),
                    [min_area](const ExPolygon &poly) { 
                        return poly.area() < min_area; 
                    }),
                overhangs[layer_idx].end()
            );
        }
        
        return overhangs;
    }
};
```

### Tree Support System
Implementation: `src/libslic3r/TreeSupport.cpp`

```cpp
class TreeSupport {
public:
    struct SupportNode {
        Point location;
        coordf_t height;
        double radius;
        std::vector<SupportNode*> children;
        SupportNode* parent;
        
        // Collision detection
        bool has_collision;
        std::vector<ExPolygon> collision_areas;
        
        // Properties
        bool is_root() const { return parent == nullptr; }
        bool is_leaf() const { return children.empty(); }
        int depth() const {
            return parent ? parent->depth() + 1 : 0;
        }
    };
    
    // Main tree support generation
    void generate_tree_supports(PrintObject &object) {
        // Step 1: Identify overhang points requiring support
        std::vector<Point> support_points = identify_support_points(object);
        
        // Step 2: Build tree structure
        std::vector<SupportNode> tree_nodes = build_support_tree(
            support_points, object);
        
        // Step 3: Optimize tree structure
        optimize_tree_structure(tree_nodes, object);
        
        // Step 4: Generate actual support geometry
        generate_tree_geometry(tree_nodes, object);
    }
    
private:
    std::vector<SupportNode> build_support_tree(
        const std::vector<Point> &support_points,
        const PrintObject &object) {
        
        std::vector<SupportNode> nodes;
        
        // Create leaf nodes for each support point
        for (const Point &point : support_points) {
            SupportNode node;
            node.location = point;
            node.height = find_support_height(point, object);
            node.radius = params.tree_support_tip_diameter / 2.0;
            node.parent = nullptr;
            nodes.push_back(node);
        }
        
        // Build tree bottom-up
        while (nodes.size() > 1) {
            // Find pairs of nodes that can be merged
            auto merge_candidates = find_merge_candidates(nodes, object);
            
            for (const auto &pair : merge_candidates) {
                SupportNode parent_node = create_parent_node(
                    nodes[pair.first], nodes[pair.second], object);
                
                // Check for collisions
                if (!has_collision_at_location(parent_node, object)) {
                    nodes[pair.first].parent = &parent_node;
                    nodes[pair.second].parent = &parent_node;
                    parent_node.children = {&nodes[pair.first], &nodes[pair.second]};
                    nodes.push_back(parent_node);
                }
            }
            
            // Remove merged nodes
            remove_merged_nodes(nodes);
        }
        
        return nodes;
    }
    
    void optimize_tree_structure(std::vector<SupportNode> &nodes,
                                const PrintObject &object) {
        // Branch straightening
        for (auto &node : nodes) {
            if (!node.is_root() && node.children.size() == 1) {
                // Check if we can straighten this branch
                Vec2d parent_dir = (node.parent->location - node.location).cast<double>();
                Vec2d child_dir = (node.location - node.children[0]->location).cast<double>();
                
                double angle = std::acos(parent_dir.dot(child_dir) / 
                                       (parent_dir.norm() * child_dir.norm()));
                
                if (angle < deg2rad(15.0)) { // Small angle threshold
                    // Merge nodes to straighten branch
                    straighten_branch(node);
                }
            }
        }
        
        // Collision avoidance
        for (auto &node : nodes) {
            resolve_collisions(node, object);
        }
    }
};
```

## Multi-Material and Multi-Object Processing

### PrintRegion System
Implementation: `src/libslic3r/PrintRegion.cpp`

```cpp
class PrintRegion {
public:
    // Region-specific configuration
    PrintRegionConfig config;
    
    // Volumes assigned to this region
    std::vector<int> volume_ids;
    
    // Generated paths for this region
    ExtrusionEntityCollection perimeters;
    ExtrusionEntityCollection fills;
    ExtrusionEntityCollection ironing;
    
    // Process region-specific slicing
    void make_perimeters(const Layer &layer, 
                        const LayerRegion &layerm) {
        
        PerimeterGenerator generator(&layer, &layerm, &config);
        generator.process();
        
        // Assign results
        perimeters = generator.perimeters;
        fills.append(generator.gap_fill);
    }
    
    void make_fill(const Layer &layer, 
                   const LayerRegion &layerm) {
        
        // Select appropriate fill algorithm
        std::unique_ptr<Fill> fill_algorithm = create_fill_algorithm(
            config.fill_pattern.value);
        
        FillParams params;
        params.density = config.fill_density.value / 100.0;
        params.line_spacing = config.line_width.value / params.density;
        params.flow = layerm.flow(frInfill);
        
        // Generate fill paths
        for (const Surface &surface : layerm.fill_surfaces.surfaces) {
            Polylines fill_paths = fill_algorithm->fill_surface(surface, params);
            
            // Convert to extrusion paths
            ExtrusionPaths extrusion_paths = polylines_to_extrusion_paths(
                fill_paths, erInternalInfill, params.flow.mm3_per_mm(),
                params.flow.width(), surface.thickness());
            
            fills.append(extrusion_paths);
        }
    }
};

// Multi-material tool ordering
class ToolOrdering {
public:
    struct LayerTools {
        coordf_t print_z;
        bool has_object;
        bool has_support;
        bool has_wipe_tower;
        
        // Tool usage in this layer
        std::vector<unsigned int> extruders;
        
        // Wipe volumes between tools
        std::vector<std::vector<float>> wipe_volumes;
    };
    
    std::vector<LayerTools> layer_tools;
    
    // Calculate optimal tool ordering
    void calculate_tool_ordering(const Print &print) {
        for (coordf_t z : print.zs()) {
            LayerTools tools;
            tools.print_z = z;
            
            // Determine which extruders are needed at this layer
            std::set<unsigned int> layer_extruders;
            
            for (const PrintObject *object : print.objects()) {
                const Layer *layer = object->get_layer_at_z(z);
                if (layer) {
                    for (const LayerRegion &region : layer->regions()) {
                        layer_extruders.insert(region.region().config.extruder.value - 1);
                    }
                }
            }
            
            tools.extruders = std::vector<unsigned int>(
                layer_extruders.begin(), layer_extruders.end());
            
            // Calculate wipe volumes
            calculate_wipe_volumes(tools, print.config());
            
            layer_tools.push_back(tools);
        }
        
        // Optimize tool sequence to minimize changes
        optimize_tool_changes();
    }
    
private:
    void calculate_wipe_volumes(LayerTools &tools, 
                               const PrintConfig &config) {
        size_t n_extruders = tools.extruders.size();
        tools.wipe_volumes.resize(n_extruders, std::vector<float>(n_extruders, 0.0f));
        
        // Calculate volumes based on material properties
        for (size_t i = 0; i < n_extruders; ++i) {
            for (size_t j = 0; j < n_extruders; ++j) {
                if (i != j) {
                    tools.wipe_volumes[i][j] = calculate_wipe_volume(
                        tools.extruders[i], tools.extruders[j], config);
                }
            }
        }
    }
};
```

## Performance Optimization and Parallel Processing

### Threading Architecture
Implementation: Uses Intel TBB (Threading Building Blocks)

```cpp
// Parallel layer processing
void PrintObject::slice() {
    std::vector<coordf_t> z_values = generate_layer_z_values();
    std::vector<Polygons> layers(z_values.size());
    
    // Parallel slicing of all layers
    tbb::parallel_for(tbb::blocked_range<size_t>(0, z_values.size()),
        [&](const tbb::blocked_range<size_t> &range) {
            TriangleMeshSlicer slicer(&m_model_object->mesh());
            
            for (size_t layer_idx = range.begin(); 
                 layer_idx != range.end(); ++layer_idx) {
                layers[layer_idx] = slicer.slice_plane(
                    z_values[layer_idx], 
                    SlicingMode_Regular);
            }
        });
    
    // Convert polygons to layer objects
    convert_polygons_to_layers(layers, z_values);
}

// Parallel perimeter generation
void PrintObject::make_perimeters() {
    tbb::parallel_for(tbb::blocked_range<size_t>(0, m_layers.size()),
        [&](const tbb::blocked_range<size_t> &range) {
            for (size_t layer_idx = range.begin(); 
                 layer_idx != range.end(); ++layer_idx) {
                
                Layer *layer = m_layers[layer_idx];
                for (LayerRegion &region : layer->regions()) {
                    region.make_perimeters();
                }
            }
        });
}

// Memory management optimization
class SlicingMemoryPool {
private:
    tbb::scalable_allocator<char> allocator;
    std::vector<std::unique_ptr<char[]>> memory_blocks;
    
public:
    template<typename T>
    T* allocate(size_t count) {
        size_t size = sizeof(T) * count;
        auto block = std::make_unique<char[]>(size);
        T* ptr = reinterpret_cast<T*>(block.get());
        memory_blocks.push_back(std::move(block));
        return ptr;
    }
    
    void reset() {
        memory_blocks.clear();
    }
};
```

### Geometric Optimization
```cpp
// Polygon simplification for performance
class PolygonSimplifier {
public:
    static Polygons simplify_for_slicing(const Polygons &polygons,
                                        double tolerance) {
        Polygons simplified;
        
        for (const Polygon &poly : polygons) {
            // Douglas-Peucker simplification
            Polygon simplified_poly = douglas_peucker_simplify(poly, tolerance);
            
            // Only keep polygons above minimum area threshold
            if (simplified_poly.area() > scale_(tolerance * tolerance)) {
                simplified.push_back(simplified_poly);
            }
        }
        
        return simplified;
    }
    
private:
    static Polygon douglas_peucker_simplify(const Polygon &polygon,
                                          double tolerance) {
        if (polygon.points.size() <= 2) {
            return polygon;
        }
        
        // Find point with maximum distance to line segment
        double max_distance = 0;
        size_t max_index = 0;
        
        Line line(polygon.points.front(), polygon.points.back());
        
        for (size_t i = 1; i < polygon.points.size() - 1; ++i) {
            double distance = line.distance_to(polygon.points[i]);
            if (distance > max_distance) {
                max_distance = distance;
                max_index = i;
            }
        }
        
        // If max distance is below threshold, simplify to line
        if (max_distance < tolerance) {
            return Polygon({polygon.points.front(), polygon.points.back()});
        }
        
        // Recursively simplify segments
        Polygon first_half(polygon.points.begin(), 
                          polygon.points.begin() + max_index + 1);
        Polygon second_half(polygon.points.begin() + max_index,
                           polygon.points.end());
        
        Polygon simplified_first = douglas_peucker_simplify(first_half, tolerance);
        Polygon simplified_second = douglas_peucker_simplify(second_half, tolerance);
        
        // Combine results
        Polygon result;
        result.points.insert(result.points.end(),
                           simplified_first.points.begin(),
                           simplified_first.points.end() - 1);
        result.points.insert(result.points.end(),
                           simplified_second.points.begin(),
                           simplified_second.points.end());
        
        return result;
    }
};
```

## Integration Points and Data Flow

### Layer Processing Pipeline
```cpp
class LayerProcessor {
public:
    void process_layer(Layer *layer) {
        // 1. Surface detection
        detect_surfaces(layer);
        
        // 2. Bridge detection
        detect_bridges(layer);
        
        // 3. Perimeter generation
        for (LayerRegion &region : layer->regions()) {
            region.make_perimeters();
        }
        
        // 4. Infill preparation
        prepare_infill_surfaces(layer);
        
        // 5. Infill generation
        for (LayerRegion &region : layer->regions()) {
            region.make_fill();
        }
        
        // 6. Ironing (if enabled)
        if (layer->object()->config().ironing.value) {
            generate_ironing_paths(layer);
        }
    }
    
private:
    void detect_surfaces(Layer *layer) {
        // Classify surfaces as top, bottom, or internal
        const Layer *upper_layer = layer->upper_layer;
        const Layer *lower_layer = layer->lower_layer;
        
        for (LayerRegion &region : layer->regions()) {
            // Find top surfaces (no layer above or different geometry)
            ExPolygons top_surfaces;
            if (!upper_layer) {
                top_surfaces = region.slices;
            } else {
                top_surfaces = diff_ex(region.slices, 
                                     upper_layer->region(region.region_id()).slices);
            }
            
            // Find bottom surfaces (no layer below or different geometry)
            ExPolygons bottom_surfaces;
            if (!lower_layer) {
                bottom_surfaces = region.slices;
            } else {
                bottom_surfaces = diff_ex(region.slices,
                                        lower_layer->region(region.region_id()).slices);
            }
            
            // Internal surfaces are everything else
            ExPolygons internal_surfaces = diff_ex(
                diff_ex(region.slices, top_surfaces),
                bottom_surfaces);
            
            // Store classified surfaces
            region.fill_surfaces.set(top_surfaces, stTop);
            region.fill_surfaces.set(bottom_surfaces, stBottom);
            region.fill_surfaces.set(internal_surfaces, stInternal);
        }
    }
};
```

## Odin Rewrite Considerations

### Algorithm Preservation
The slicing algorithms are mathematically sound and should be preserved:
- **Triangle-plane intersection**: Core geometric algorithm
- **Adaptive layer heights**: Curvature analysis approach
- **Arachne skeletal trapezoidation**: Advanced variable-width generation
- **Lightning infill**: Tree-based minimal material algorithm

### Performance Improvements
Opportunities for Odin optimization:
- **SIMD Vectorization**: Parallel geometric operations
- **Memory Layout**: Structure-of-arrays for better cache performance
- **GPU Acceleration**: Parallel slicing on GPU
- **Lock-free Data Structures**: Reduced threading overhead

### Architectural Modernization
- **Pure Functions**: Immutable data structures where possible
- **Error Handling**: Explicit error types instead of exceptions
- **Type Safety**: Stronger typing for geometric operations
- **Memory Management**: Deterministic allocation patterns

### API Design
```odin
// Example Odin API design for slicing
Slicing_Parameters :: struct {
    layer_height: f64,
    adaptive_slicing: bool,
    support_threshold: f64,
    infill_density: f64,
    infill_pattern: Infill_Pattern,
}

slice_object :: proc(mesh: ^Triangle_Mesh, params: Slicing_Parameters) -> ([]Layer, Error) {
    // Implementation would follow similar logic but with Odin idioms
}

generate_perimeters :: proc(layer: ^Layer, config: ^Print_Region_Config) -> ([]Extrusion_Path, Error) {
    // Arachne or classic perimeter generation
}
```

The slicing engine represents the core intellectual property of OrcaSlicer, containing sophisticated algorithms that have been refined over years of development. A successful Odin rewrite would need to preserve these algorithmic innovations while modernizing the implementation for better performance and maintainability.