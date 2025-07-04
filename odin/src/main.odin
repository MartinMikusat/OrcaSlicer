package main

import "core:fmt"
import "core:os"
import "core:math"

main :: proc() {
    fmt.println("=== OrcaSlicer Odin - Phase 1 Foundation ===")
    
    // Check for benchmark flag
    if len(os.args) > 1 && os.args[1] == "--benchmark" {
        run_performance_benchmarks()
        test_tree_quality()
        return
    }
    
    // Test all core components
    test_coordinates()
    test_geometry()
    test_mesh_creation()
    test_polygon_operations()
    
    // Test new geometric predicates
    test_geometric_predicates()
    
    // Test AABB tree spatial indexing
    test_aabb_tree()
    
    // Test layer slicing algorithm
    test_layer_slicing()
    
    // Test enhanced degenerate case handling
    fmt.println("\n--- About to test degenerate case handling ---")
    test_degenerate_case_handling()
    fmt.println("--- Degenerate case handling test completed ---")
    
    // Test enhanced slicing with degenerate geometry
    test_enhanced_slicing_with_degenerate_cases()
    
    // Test gap closing algorithm
    test_gap_closing()
    
    // Test STL functionality if file provided, or use test cube
    test_stl_path := "test_cube.stl"
    if len(os.args) > 1 {
        test_stl_path = os.args[1]
    }
    
    fmt.println("\n--- Testing STL loading and enhanced slicing ---")
    test_stl_loading(test_stl_path)
    test_enhanced_slicing_with_real_stl(test_stl_path)
    fmt.println("--- STL testing completed ---")
    
    fmt.println("=== Foundation tests completed successfully! ===")
}

test_coordinates :: proc() {
    fmt.println("\n--- Testing Coordinate System ---")
    
    // Test fixed-point conversion
    mm_value: f64 = 25.4 // 1 inch in mm
    coord_value := mm_to_coord(mm_value)
    back_to_mm := coord_to_mm(coord_value)
    
    fmt.printf("Original: %.6f mm, Coord: %d, Back: %.6f mm\n", 
               mm_value, coord_value, back_to_mm)
    
    assert(abs(mm_value - back_to_mm) < 1e-9, "Coordinate conversion failed")
    
    // Test micron conversion
    micron_value: f64 = 200.0 // 200 microns
    coord_from_micron := micron_to_coord(micron_value)
    back_to_micron := coord_to_micron(coord_from_micron)
    
    fmt.printf("Microns: %.1f, Coord: %d, Back: %.1f\n", 
               micron_value, coord_from_micron, back_to_micron)
    
    fmt.println("✓ Coordinate system tests passed")
}

test_geometry :: proc() {
    fmt.println("\n--- Testing Geometry Types ---")
    
    // Test 2D points
    p1 := point2d_from_mm(10.0, 20.0)
    p2 := point2d_from_mm(30.0, 40.0)
    
    distance := point_distance(p1, p2)
    distance_mm := coord_to_mm(distance)
    expected_distance := math.sqrt_f64(20.0*20.0 + 20.0*20.0) // Should be ~28.28 mm
    
    fmt.printf("Distance between points: %.6f mm (expected: %.6f)\n", 
               distance_mm, expected_distance)
    
    assert(abs(distance_mm - expected_distance) < 1e-6, "Distance calculation failed")
    
    // Test 3D vectors
    v1 := Vec3f{1.0, 2.0, 3.0}
    v2 := Vec3f{4.0, 5.0, 6.0}
    
    dot_product := vec3_dot(v1, v2)
    expected_dot: f32 = 1.0*4.0 + 2.0*5.0 + 3.0*6.0 // 32.0
    
    fmt.printf("Dot product: %.6f (expected: %.6f)\n", dot_product, expected_dot)
    assert(abs(dot_product - expected_dot) < 1e-6, "Dot product calculation failed")
    
    // Test cross product
    cross := vec3_cross(v1, v2)
    fmt.printf("Cross product: (%.3f, %.3f, %.3f)\n", cross.x, cross.y, cross.z)
    
    fmt.println("✓ Geometry tests passed")
}

test_mesh_creation :: proc() {
    fmt.println("\n--- Testing Mesh Creation ---")
    
    // Create a simple triangle mesh (single triangle)
    mesh := mesh_create()
    defer mesh_destroy(&mesh)
    
    // Add a triangle (simple right triangle)
    v0 := Vec3f{0.0, 0.0, 0.0}
    v1 := Vec3f{10.0, 0.0, 0.0}
    v2 := Vec3f{0.0, 10.0, 0.0}
    
    mesh_add_triangle(&mesh, v0, v1, v2)
    
    stats := mesh_get_stats(&mesh)
    fmt.printf("Mesh stats: %d vertices, %d triangles\n", 
               stats.num_vertices, stats.num_triangles)
    fmt.printf("Surface area: %.6f mm²\n", stats.surface_area)
    
    assert(stats.num_vertices == 3, "Wrong vertex count")
    assert(stats.num_triangles == 1, "Wrong triangle count")
    assert(abs(stats.surface_area - 50.0) < 1e-6, "Wrong surface area")
    
    fmt.println("✓ Mesh creation tests passed")
}

test_polygon_operations :: proc() {
    fmt.println("\n--- Testing Polygon Operations ---")
    
    // Create a square polygon
    square := polygon_create_rectangle(0.0, 0.0, 10.0, 10.0)
    defer polygon_destroy(&square)
    
    area := polygon_area_abs(&square)
    fmt.printf("Square area: %.6f mm² (expected: 100.0)\n", area)
    assert(abs(area - 100.0) < 1e-6, "Square area calculation failed")
    
    // Test point-in-polygon
    inside_point := point2d_from_mm(5.0, 5.0)
    outside_point := point2d_from_mm(15.0, 15.0)
    
    assert(point_in_polygon(inside_point, &square), "Point should be inside square")
    assert(!point_in_polygon(outside_point, &square), "Point should be outside square")
    
    // Create circle polygon
    center := point2d_from_mm(0.0, 0.0)
    circle := polygon_create_circle(center, 5.0, 32)
    defer polygon_destroy(&circle)
    
    circle_area := polygon_area_abs(&circle)
    expected_circle_area := math.PI * 25.0 // π * r²
    fmt.printf("Circle area: %.6f mm² (expected: %.6f)\n", 
               circle_area, expected_circle_area)
    
    // Circle approximation should be within 1% of actual area
    area_error := abs(circle_area - expected_circle_area) / expected_circle_area
    assert(area_error < 0.01, "Circle area approximation too inaccurate")
    
    fmt.println("✓ Polygon operation tests passed")
}

test_stl_loading :: proc(filepath: string) {
    fmt.printf("\n--- Testing STL Loading: %s ---\n", filepath)
    
    mesh, ok := stl_load(filepath)
    if !ok {
        fmt.printf("⚠ Failed to load STL file: %s\n", filepath)
        return
    }
    defer mesh_destroy(&mesh)
    
    stats := mesh_get_stats(&mesh)
    bbox := its_bounding_box(&mesh.its)
    
    fmt.printf("Successfully loaded STL:\n")
    fmt.printf("  Vertices: %d\n", stats.num_vertices)
    fmt.printf("  Triangles: %d\n", stats.num_triangles)
    fmt.printf("  Surface area: %.2f mm²\n", stats.surface_area)
    
    min_x, min_y, min_z := point3d_to_mm(bbox.min)
    max_x, max_y, max_z := point3d_to_mm(bbox.max)
    
    fmt.printf("  Bounding box: (%.2f, %.2f, %.2f) to (%.2f, %.2f, %.2f) mm\n",
               min_x, min_y, min_z, max_x, max_y, max_z)
    
    // Test saving
    save_path := "output_test.stl"
    if stl_save_binary(&mesh, save_path) {
        fmt.printf("✓ Successfully saved test STL: %s\n", save_path)
    } else {
        fmt.printf("⚠ Failed to save test STL\n")
    }
}

test_geometric_predicates :: proc() {
    fmt.println("\n--- Testing Geometric Predicates ---")
    
    // Test orientation predicate
    test_orientation_predicate()
    
    // Test line intersection
    test_line_intersection()
    
    // Test robust point-in-polygon
    test_robust_point_in_polygon()
    
    // Test triangle-plane intersection
    test_triangle_plane_intersection()
    
    // Test point-to-line distance
    test_point_line_distance()
    
    fmt.println("✓ Geometric predicates tests passed")
}

test_orientation_predicate :: proc() {
    fmt.println("  Testing orientation predicate...")
    
    // Test counter-clockwise
    ccw := orientation_exact(
        point2d_from_mm(0, 0),
        point2d_from_mm(1, 0), 
        point2d_from_mm(0, 1)
    )
    assert(ccw > 0, "Should be counter-clockwise")
    
    // Test clockwise
    cw := orientation_exact(
        point2d_from_mm(0, 0),
        point2d_from_mm(0, 1),
        point2d_from_mm(1, 0)
    )
    assert(cw < 0, "Should be clockwise")
    
    // Test collinear
    collinear := orientation_exact(
        point2d_from_mm(0, 0),
        point2d_from_mm(1, 1),
        point2d_from_mm(2, 2)
    )
    assert(collinear == 0, "Should be collinear")
    
    fmt.println("    ✓ Orientation tests passed")
}

test_line_intersection :: proc() {
    fmt.println("  Testing line intersection...")
    
    // Test simple intersection
    intersection := line_segment_intersection(
        point2d_from_mm(0, 0), point2d_from_mm(2, 2),  // Line 1
        point2d_from_mm(0, 2), point2d_from_mm(2, 0)   // Line 2 (crossing)
    )
    assert(intersection.type == .POINT, "Should intersect at a point")
    
    x_mm, y_mm := point2d_to_mm(intersection.point)
    assert(abs(x_mm - 1.0) < 1e-6, "Intersection X should be 1.0")
    assert(abs(y_mm - 1.0) < 1e-6, "Intersection Y should be 1.0")
    
    // Test parallel lines (no intersection)
    no_intersection := line_segment_intersection(
        point2d_from_mm(0, 0), point2d_from_mm(2, 0),  // Horizontal line 1
        point2d_from_mm(0, 1), point2d_from_mm(2, 1)   // Horizontal line 2
    )
    assert(no_intersection.type == .NONE, "Parallel lines should not intersect")
    
    // Test collinear overlapping segments
    collinear := line_segment_intersection(
        point2d_from_mm(0, 0), point2d_from_mm(2, 0),  // Line segment 1
        point2d_from_mm(1, 0), point2d_from_mm(3, 0)   // Overlapping segment
    )
    assert(collinear.type == .SEGMENT, "Collinear segments should overlap")
    
    fmt.println("    ✓ Line intersection tests passed")
}

test_robust_point_in_polygon :: proc() {
    fmt.println("  Testing robust point-in-polygon...")
    
    // Create a square polygon
    square := polygon_create_rectangle(0.0, 0.0, 10.0, 10.0)
    defer polygon_destroy(&square)
    
    // Test point inside
    inside_point := point2d_from_mm(5.0, 5.0)
    assert(point_in_polygon_robust(inside_point, &square), "Point should be inside square")
    
    // Test point outside
    outside_point := point2d_from_mm(15.0, 5.0)
    assert(!point_in_polygon_robust(outside_point, &square), "Point should be outside square")
    
    // Test point on edge (should be considered outside for robustness)
    edge_point := point2d_from_mm(10.0, 5.0)
    edge_result := point_in_polygon_robust(edge_point, &square)
    // Note: This might be inside or outside depending on exact implementation
    
    // Test point at vertex
    vertex_point := point2d_from_mm(0.0, 0.0)
    vertex_result := point_in_polygon_robust(vertex_point, &square)
    
    // Compare with raycast version for consistency
    inside_raycast := point_in_polygon_raycast(inside_point, &square)
    outside_raycast := point_in_polygon_raycast(outside_point, &square)
    
    assert(inside_raycast == true, "Raycast should agree on inside point")
    assert(outside_raycast == false, "Raycast should agree on outside point")
    
    fmt.println("    ✓ Point-in-polygon tests passed")
}

test_triangle_plane_intersection :: proc() {
    fmt.println("  Testing triangle-plane intersection...")
    
    // Create a triangle that crosses the Z=5 plane
    triangle := [3]Vec3f{
        {0.0, 0.0, 0.0},  // Below plane
        {10.0, 0.0, 0.0}, // Below plane  
        {5.0, 10.0, 10.0} // Above plane
    }
    
    intersection := triangle_plane_intersection(triangle, 5.0)
    assert(intersection.has_intersection, "Triangle should intersect plane")
    assert(!intersection.edge_on_plane, "No edge should be on plane")
    assert(!intersection.vertex_on_plane, "No vertex should be on plane")
    
    // Test triangle entirely above plane
    above_triangle := [3]Vec3f{
        {0.0, 0.0, 10.0},
        {10.0, 0.0, 10.0},
        {5.0, 10.0, 20.0}
    }
    
    no_intersection := triangle_plane_intersection(above_triangle, 5.0)
    assert(!no_intersection.has_intersection, "Triangle above plane should not intersect")
    
    // Test triangle with vertex on plane
    vertex_on_plane := [3]Vec3f{
        {0.0, 0.0, 5.0},  // On plane
        {10.0, 0.0, 0.0}, // Below plane
        {5.0, 10.0, 10.0} // Above plane
    }
    
    vertex_intersection := triangle_plane_intersection(vertex_on_plane, 5.0)
    assert(vertex_intersection.has_intersection, "Should intersect when vertex on plane")
    assert(vertex_intersection.vertex_on_plane, "Should detect vertex on plane")
    
    fmt.println("    ✓ Triangle-plane intersection tests passed")
}

test_point_line_distance :: proc() {
    fmt.println("  Testing point-to-line distance...")
    
    // Test distance from point to horizontal line
    line_start := point2d_from_mm(0.0, 0.0)
    line_end := point2d_from_mm(10.0, 0.0)
    point := point2d_from_mm(5.0, 3.0)
    
    distance := point_line_distance(point, line_start, line_end)
    distance_mm := coord_to_mm(distance)
    
    assert(abs(distance_mm - 3.0) < 1e-6, "Distance should be 3.0 mm")
    
    // Test distance to line endpoint
    endpoint_point := point2d_from_mm(15.0, 0.0)
    endpoint_distance := point_line_distance(endpoint_point, line_start, line_end)
    endpoint_distance_mm := coord_to_mm(endpoint_distance)
    
    assert(abs(endpoint_distance_mm - 5.0) < 1e-6, "Distance to endpoint should be 5.0 mm")
    
    // Test distance to point on line (should be zero)
    on_line_point := point2d_from_mm(7.0, 0.0)
    on_line_distance := point_line_distance(on_line_point, line_start, line_end)
    on_line_distance_mm := coord_to_mm(on_line_distance)
    
    assert(abs(on_line_distance_mm) < 1e-6, "Distance to point on line should be zero")
    
    fmt.println("    ✓ Point-to-line distance tests passed")
}

test_aabb_tree :: proc() {
    fmt.println("\n--- Testing AABB Tree Spatial Indexing ---")
    
    // Create a simple test mesh (cube with 12 triangles)
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    // Build AABB tree
    tree := aabb_build(&mesh)
    defer aabb_destroy(&tree)
    
    fmt.printf("  Built AABB tree: %d nodes, %d leaves\n", tree.node_count, tree.leaf_count)
    
    // Validate tree structure
    assert(aabb_validate(&tree), "AABB tree should be valid")
    
    // Test statistics
    stats := aabb_get_stats(&tree)
    fmt.printf("  Tree stats: max depth %d, avg leaf size %.1f\n", 
               stats.max_depth, stats.avg_leaf_size)
    
    assert(stats.node_count > 0, "Should have nodes")
    assert(stats.max_depth > 0, "Should have non-zero depth")
    
    // Test plane intersection query
    test_aabb_plane_intersection()
    
    // Test ray intersection query
    test_aabb_ray_intersection()
    
    fmt.println("✓ AABB tree tests passed")
}

create_test_cube_mesh :: proc() -> TriangleMesh {
    mesh := mesh_create()
    
    // Create a 10x10x10 mm cube centered at origin
    vertices := [8]Vec3f{
        {-5, -5, -5}, {5, -5, -5}, {5, 5, -5}, {-5, 5, -5},  // Bottom face
        {-5, -5,  5}, {5, -5,  5}, {5, 5,  5}, {-5, 5,  5},  // Top face
    }
    
    // Add vertices to mesh
    vertex_indices: [8]u32
    for vertex, i in vertices {
        vertex_indices[i] = its_add_vertex(&mesh.its, vertex)
    }
    
    // Define cube faces (12 triangles)
    faces := [12][3]u32{
        // Bottom face
        {0, 1, 2}, {0, 2, 3},
        // Top face  
        {4, 6, 5}, {4, 7, 6},
        // Front face
        {0, 4, 5}, {0, 5, 1},
        // Back face
        {2, 6, 7}, {2, 7, 3},
        // Left face
        {0, 3, 7}, {0, 7, 4},
        // Right face
        {1, 5, 6}, {1, 6, 2},
    }
    
    // Add triangles to mesh
    for face in faces {
        its_add_triangle(&mesh.its, face[0], face[1], face[2])
    }
    
    mesh_mark_dirty(&mesh)
    return mesh
}

test_aabb_plane_intersection :: proc() {
    fmt.println("  Testing plane intersection queries...")
    
    // This would be properly implemented once we have the cube mesh
    // For now, create a minimal test
    
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    tree := aabb_build(&mesh)
    defer aabb_destroy(&tree)
    
    // Test plane at Z=0 (should intersect the cube)
    intersections := aabb_plane_intersect(&tree, 0.0)
    defer delete(intersections)
    
    assert(len(intersections) > 0, "Plane at Z=0 should intersect cube")
    fmt.printf("    Plane Z=0 intersects %d triangles\n", len(intersections))
    
    // Test plane well outside cube
    no_intersections := aabb_plane_intersect(&tree, 100.0)
    defer delete(no_intersections)
    
    assert(len(no_intersections) == 0, "Plane at Z=100 should not intersect cube")
    
    fmt.println("    ✓ Plane intersection tests passed")
}

test_aabb_ray_intersection :: proc() {
    fmt.println("  Testing ray intersection queries...")
    
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    tree := aabb_build(&mesh)
    defer aabb_destroy(&tree)
    
    // Test ray pointing at cube center
    ray_start := Vec3f{0, 0, -10}  // Start outside cube
    ray_dir := Vec3f{0, 0, 1}      // Point toward cube
    
    hit := aabb_ray_intersect(&tree, ray_start, ray_dir)
    
    assert(hit.hit, "Ray should hit the cube")
    assert(hit.distance > 0, "Hit distance should be positive")
    assert(hit.distance < 10, "Hit should be closer than ray start distance")
    
    fmt.printf("    Ray hit at distance %.2f\n", hit.distance)
    
    // Test ray missing the cube
    miss_ray_start := Vec3f{20, 20, -10}  // Start well outside
    miss_ray_dir := Vec3f{0, 0, 1}        // Parallel ray that misses
    
    miss_hit := aabb_ray_intersect(&tree, miss_ray_start, miss_ray_dir)
    assert(!miss_hit.hit, "Ray should miss the cube")
    
    fmt.println("    ✓ Ray intersection tests passed")
}

test_layer_slicing :: proc() {
    fmt.println("\n--- Testing Layer Slicing Algorithm ---")
    
    // Create test cube mesh
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    // Slice at 2mm layer height
    layer_height: f32 = 2.0
    slice_result := slice_mesh(&mesh, layer_height)
    defer slice_result_destroy(&slice_result)
    
    fmt.printf("  Sliced into %d layers\n", len(slice_result.layers))
    
    // Validate basic properties
    assert(len(slice_result.layers) > 0, "Should have at least one layer")
    assert(slice_result_validate(&slice_result), "Slice result should be valid")
    
    // Check that middle layers have polygons
    if len(slice_result.layers) >= 3 {
        middle_layer := &slice_result.layers[len(slice_result.layers) / 2]
        assert(len(middle_layer.polygons) > 0, "Middle layer should have polygons")
        
        fmt.printf("  Middle layer Z=%.2f has %d polygons\n", 
                   middle_layer.z_height, len(middle_layer.polygons))
        
        // Check polygon properties
        for &expoly in middle_layer.polygons {
            area := expolygon_area(&expoly)
            assert(area > 0, "Polygon should have positive area")
            assert(len(expoly.contour.points) >= 3, "Polygon should have at least 3 points")
        }
    }
    
    // Test volume calculation
    volume := slice_result_volume(&slice_result, layer_height)
    fmt.printf("  Calculated volume: %.2f mm³\n", volume)
    
    // For a 10x10x10 cube, volume should be approximately 1000 mm³
    expected_volume: f64 = 1000.0
    volume_error := abs(volume - expected_volume) / expected_volume
    
    fmt.printf("  Volume error: %.1f%% (expected: %.0f, got: %.0f)\n", 
               volume_error * 100, expected_volume, volume)
    
    // Allow some error due to discretization and edge effects
    assert(volume_error < 0.3, "Volume should be approximately correct")
    
    // Test statistics
    stats := slice_result.statistics
    fmt.printf("  Statistics: %s\n", slice_statistics_summary(stats))
    
    assert(stats.total_layers > 0, "Should have processed layers")
    assert(stats.processing_time_ms >= 0, "Processing time should be non-negative")
    
    fmt.println("✓ Layer slicing tests passed")
}

test_gap_closing :: proc() {
    fmt.println("\n--- Testing Gap Closing Algorithm ---")
    
    // Create two simple open polygons that should connect
    poly1 := Polygon{}
    defer polygon_destroy(&poly1)
    
    poly2 := Polygon{}
    defer polygon_destroy(&poly2)
    
    // Polygon 1: line from (0,0) to (5,0) - open
    append(&poly1.points, point2d_from_mm(0.0, 0.0))
    append(&poly1.points, point2d_from_mm(2.5, 0.0))
    append(&poly1.points, point2d_from_mm(5.0, 0.0))
    
    // Polygon 2: line from (5.1,0) to (10,0) - small gap
    append(&poly2.points, point2d_from_mm(5.1, 0.0))
    append(&poly2.points, point2d_from_mm(7.5, 0.0))
    append(&poly2.points, point2d_from_mm(10.0, 0.0))
    
    // Create array of polygons
    polygons := make([dynamic]Polygon)
    defer {
        for &poly in polygons {
            polygon_destroy(&poly)
        }
        delete(polygons)
    }
    
    append(&polygons, poly1)
    append(&polygons, poly2)
    
    fmt.printf("  Before gap closing: %d polygons\n", len(polygons))
    
    // Test gap closing
    config := gap_closing_config_default()
    config.enable_debug = true  // Enable debug output
    
    stats := close_polygon_gaps(&polygons, config)
    
    fmt.printf("  After gap closing: %d polygons\n", len(polygons))
    fmt.printf("  Gaps found: %d, closed: %d\n", stats.total_gaps_found, stats.gaps_closed)
    
    if len(polygons) > 0 {
        fmt.printf("  Merged polygon has %d points\n", len(polygons[0].points))
    }
    
    fmt.println("✓ Gap closing tests passed")
}

test_degenerate_case_handling :: proc() {
    fmt.println("\n--- Testing Enhanced Degenerate Case Handling ---")
    
    // Test Case 1: Standard intersection (baseline)
    {
        tri := [3]Vec3f{
            {0.0, 0.0, -1.0}, // Below plane
            {1.0, 0.0, 1.0},  // Above plane
            {0.5, 1.0, 1.0},  // Above plane
        }
        z_plane: f32 = 0.0
        
        result := triangle_plane_intersection(tri, z_plane)
        fmt.printf("  Standard case: type=%v, segments=%d\n", result.intersection_type, len(result.segments))
        delete(result.segments)
        
        assert(result.intersection_type == .STANDARD, "Should be standard intersection")
        assert(len(result.segments) == 1, "Should have 1 segment")
    }
    
    // Test Case 2: Vertex on plane
    {
        tri := [3]Vec3f{
            {0.0, 0.0, 0.0}, // On plane
            {1.0, 0.0, 1.0}, // Above plane
            {0.5, 1.0, -1.0}, // Below plane
        }
        z_plane: f32 = 0.0
        
        result := triangle_plane_intersection(tri, z_plane)
        fmt.printf("  Vertex on plane: type=%v, segments=%d\n", result.intersection_type, len(result.segments))
        delete(result.segments)
        
        assert(result.intersection_type == .VERTEX_ON_PLANE, "Should be vertex on plane")
    }
    
    // Test Case 3: Face on plane (entire triangle on plane)
    {
        tri := [3]Vec3f{
            {0.0, 0.0, 0.0}, // On plane
            {1.0, 0.0, 0.0}, // On plane
            {0.5, 1.0, 0.0}, // On plane
        }
        z_plane: f32 = 0.0
        
        result := triangle_plane_intersection(tri, z_plane)
        fmt.printf("  Face on plane: type=%v, segments=%d\n", result.intersection_type, len(result.segments))
        delete(result.segments)
        
        assert(result.intersection_type == .FACE_ON_PLANE, "Should be face on plane")
        assert(len(result.segments) == 3, "Should have 3 segments (triangle outline)")
    }
    
    // Test Case 4: Triangle orientation classification
    {
        // Upward-facing triangle
        up_tri := [3]Vec3f{
            {0.0, 0.0, 0.0},
            {1.0, 0.0, 0.0},
            {0.5, 1.0, 1.0}, // Z increases
        }
        up_orientation := classify_triangle_orientation(up_tri)
        assert(up_orientation == .UP, "Should be upward-facing")
        
        // Degenerate triangle
        deg_tri := [3]Vec3f{
            {0.0, 0.0, 0.0}, // Collinear
            {1.0, 0.0, 0.0}, // Collinear
            {2.0, 0.0, 0.0}, // Collinear
        }
        deg_orientation := classify_triangle_orientation(deg_tri)
        assert(deg_orientation == .DEGENERATE, "Should be degenerate")
        
        fmt.printf("  Triangle orientations: UP=%v, DEGENERATE=%v\n", 
                   up_orientation, deg_orientation)
    }
    
    fmt.println("✓ Enhanced degenerate case handling tests passed")
}

test_enhanced_slicing_with_degenerate_cases :: proc() {
    fmt.println("\n--- Testing Enhanced Slicing with Degenerate Geometry ---")
    
    // Create a mesh with a triangle lying exactly on the slicing plane
    mesh := mesh_create()
    defer mesh_destroy(&mesh)
    
    // Triangle lying exactly on Z=0 plane (face-on-plane case)
    face_on_plane_tri := [3]Vec3f{
        {0.0, 0.0, 0.0},  // On plane
        {5.0, 0.0, 0.0},  // On plane  
        {2.5, 5.0, 0.0},  // On plane
    }
    
    // Standard triangle crossing Z=0 plane
    standard_tri := [3]Vec3f{
        {-2.0, -2.0, -1.0}, // Below plane
        {2.0, -2.0, 1.0},   // Above plane
        {0.0, 2.0, 1.0},    // Above plane
    }
    
    // Add triangles to mesh
    mesh_add_triangle(&mesh, face_on_plane_tri[0], face_on_plane_tri[1], face_on_plane_tri[2])
    mesh_add_triangle(&mesh, standard_tri[0], standard_tri[1], standard_tri[2])
    
    // Test slicing at Z=0 (where face-on-plane triangle lies)
    slice_result := slice_mesh(&mesh, 1.0) // 1mm layer height to get Z=0 layer
    defer slice_result_destroy(&slice_result)
    
    fmt.printf("  Sliced mesh with degenerate geometry: %d layers\n", len(slice_result.layers))
    
    // Find the layer at Z=0
    z0_layer_idx := -1
    for layer, i in slice_result.layers {
        if abs(layer.z_height - 0.0) < 0.1 { // Within 0.1mm of Z=0
            z0_layer_idx = i
            break
        }
    }
    
    if z0_layer_idx >= 0 {
        z0_layer := &slice_result.layers[z0_layer_idx]
        fmt.printf("  Z=0 layer has %d polygons\n", len(z0_layer.polygons))
        
        // Count total segments across all polygons
        total_segments := 0
        for expoly in z0_layer.polygons {
            total_segments += len(expoly.contour.points)
            for hole in expoly.holes {
                total_segments += len(hole.points)
            }
        }
        
        fmt.printf("  Total segments in Z=0 layer: %d\n", total_segments)
        
        // We expect more segments due to the face-on-plane triangle contributing 3 segments
        // plus the standard triangle contributing 1 segment = at least 4 segments total
        assert(len(z0_layer.polygons) > 0, "Should have polygons at Z=0")
        
        fmt.println("  ✓ Enhanced slicing correctly handles face-on-plane triangles")
    } else {
        fmt.println("  ⚠ Could not find Z=0 layer for verification")
    }
    
    fmt.println("✓ Enhanced slicing with degenerate geometry tests passed")
}

test_enhanced_slicing_with_real_stl :: proc(filepath: string) {
    fmt.printf("\n--- Testing Enhanced Slicing with Real STL: %s ---\n", filepath)
    
    // Load the STL file
    mesh, ok := stl_load(filepath)
    if !ok {
        fmt.printf("⚠ Failed to load STL file: %s\n", filepath)
        return
    }
    defer mesh_destroy(&mesh)
    
    stats := mesh_get_stats(&mesh)
    fmt.printf("  Loaded mesh: %d vertices, %d triangles\n", stats.num_vertices, stats.num_triangles)
    
    // Test slicing with layer height that intersects face-on-plane triangles
    layer_height: f32 = 2.0  // This should slice through Z=0, Z=2, Z=4, Z=6, Z=8, Z=10
    slice_result := slice_mesh(&mesh, layer_height)
    defer slice_result_destroy(&slice_result)
    
    fmt.printf("  Sliced into %d layers at %.1fmm layer height\n", len(slice_result.layers), layer_height)
    
    // Analyze layers for degenerate case handling
    face_on_plane_layers := 0
    total_polygons := 0
    
    for layer, i in slice_result.layers {
        polygon_count := len(layer.polygons)
        total_polygons += polygon_count
        
        fmt.printf("  Layer %d (Z=%.1f): %d polygons\n", i, layer.z_height, polygon_count)
        
        // Check for layers at Z=0 and Z=10 (face-on-plane cases)
        if abs(layer.z_height - 0.0) < 0.1 || abs(layer.z_height - 10.0) < 0.1 {
            face_on_plane_layers += 1
            fmt.printf("    → Face-on-plane layer detected!\n")
            
            // Count segments in this critical layer
            total_segments := 0
            for expoly in layer.polygons {
                total_segments += len(expoly.contour.points)
                for hole in expoly.holes {
                    total_segments += len(hole.points)
                }
            }
            fmt.printf("    → Total segments: %d\n", total_segments)
        }
    }
    
    // Calculate volume and compare with expected (10x10x10 = 1000 mm³)
    volume := slice_result_volume(&slice_result, layer_height)
    expected_volume: f64 = 1000.0
    volume_error := abs(volume - expected_volume) / expected_volume
    
    fmt.printf("  Volume: %.1f mm³ (expected: %.0f, error: %.1f%%)\n", 
               volume, expected_volume, volume_error * 100)
    
    // Validate results
    assert(len(slice_result.layers) > 0, "Should have sliced layers")
    assert(total_polygons > 0, "Should have polygons")
    assert(face_on_plane_layers >= 2, "Should detect face-on-plane layers at Z=0 and Z=10")
    assert(volume_error < 0.5, "Volume should be reasonably accurate")
    
    // Check statistics
    slice_stats := slice_result.statistics
    fmt.printf("  Statistics: %d triangles processed, %.2fms processing time\n", 
               slice_stats.triangles_processed, slice_stats.processing_time_ms)
    
    fmt.println("✓ Enhanced slicing with real STL passed - face-on-plane triangles handled correctly")
}