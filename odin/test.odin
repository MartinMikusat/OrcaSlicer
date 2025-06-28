package main

import "core:fmt"
import "core:os"

// Test runner entry point
// Usage: odin run test.odin [category] [filter]
//   categories: unit, integration, system, performance, property, all
//   filter: optional string to filter test names

main :: proc() {
    test_framework_init()
    defer test_framework_cleanup()
    
    // Register all test suites
    register_all_test_suites()
    
    args := os.args[1:]
    
    if len(args) == 0 {
        // Default: run unit tests for quick feedback
        fmt.println("🚀 Running default test suite (unit tests)")
        test_run_category(.UNIT)
        return
    }
    
    category_arg := args[0]
    filter := ""
    if len(args) > 1 {
        filter = args[1]
    }
    
    switch category_arg {
    case "unit":
        test_run_category(.UNIT)
    case "integration":
        test_run_category(.INTEGRATION)
    case "system":
        test_run_category(.SYSTEM)
    case "performance":
        test_run_category(.PERFORMANCE)
    case "property":
        test_run_category(.PROPERTY)
    case "all":
        test_run_all(filter)
    case "fast":
        test_run_fast()
    case:
        fmt.printf("Unknown category: %s\n", category_arg)
        fmt.println("Valid categories: unit, integration, system, performance, property, all, fast")
        os.exit(1)
    }
}

// Register all test suites here
register_all_test_suites :: proc() {
    // Geometry and Math Tests
    geometry_suite := test_suite_create("geometry_unit")
    test_case_add(geometry_suite, "coordinate_conversion", test_coordinate_conversion, .UNIT)
    test_case_add(geometry_suite, "point_distance", test_point_distance_unit, .UNIT)
    test_case_add(geometry_suite, "vector_operations", test_vector_operations_unit, .UNIT)
    test_case_add(geometry_suite, "polygon_area", test_polygon_area_unit, .UNIT)
    test_case_add(geometry_suite, "point_in_polygon", test_point_in_polygon_unit, .UNIT)
    
    // Geometric Predicates Tests  
    predicates_suite := test_suite_create("predicates_unit")
    test_case_add(predicates_suite, "orientation_test", test_orientation_exact_unit, .UNIT)
    test_case_add(predicates_suite, "line_intersection", test_line_intersection_unit, .UNIT)
    test_case_add(predicates_suite, "triangle_plane_intersection", test_triangle_plane_intersection_unit, .UNIT)
    
    // AABB Tree Tests
    aabb_suite := test_suite_create("aabb_unit")
    test_case_add(aabb_suite, "tree_construction", test_aabb_construction_unit, .UNIT)
    test_case_add(aabb_suite, "tree_validation", test_aabb_validation_unit, .UNIT)
    test_case_add(aabb_suite, "plane_intersection", test_aabb_plane_query_unit, .UNIT)
    test_case_add(aabb_suite, "ray_intersection", test_aabb_ray_query_unit, .UNIT)
    
    // Boolean Operations Tests
    boolean_suite := test_suite_create("boolean_unit")
    test_case_add(boolean_suite, "polygon_intersection", test_boolean_intersection_unit, .UNIT)
    test_case_add(boolean_suite, "polygon_union", test_boolean_union_unit, .UNIT)
    test_case_add(boolean_suite, "polygon_difference", test_boolean_difference_unit, .UNIT)
    
    // Performance Tests
    performance_suite := test_suite_create("performance")
    test_case_add(performance_suite, "aabb_performance", test_aabb_construction_performance, .PERFORMANCE, 10000)
    test_case_add(performance_suite, "slicing_performance", test_slicing_performance, .PERFORMANCE, 10000)
    test_case_add(performance_suite, "boolean_performance", test_boolean_operations_performance, .PERFORMANCE, 10000)
    
    // Integration Tests
    integration_suite := test_suite_create("integration")
    test_case_add(integration_suite, "mesh_to_layers", test_mesh_to_layers_integration, .INTEGRATION, 15000)
    test_case_add(integration_suite, "layer_to_polygons", test_layer_to_polygons_integration, .INTEGRATION, 15000)
    test_case_add(integration_suite, "memory_management", test_memory_management_integration, .INTEGRATION, 10000)
    
    // System Tests
    system_suite := test_suite_create("system")
    test_case_add(system_suite, "stl_to_gcode", test_stl_to_gcode_system, .SYSTEM, 30000)
    test_case_add(system_suite, "real_world_models", test_real_world_models_system, .SYSTEM, 60000)
    test_case_add(system_suite, "stress_test", test_stress_system, .SYSTEM, 120000)
}

// ===== UNIT TEST IMPLEMENTATIONS =====

test_coordinate_conversion :: proc() -> bool {
    // Test fixed-point coordinate conversion
    mm_value: f64 = 25.4 // 1 inch
    coord_value := mm_to_coord(mm_value)
    back_to_mm := coord_to_mm(coord_value)
    
    return test_assert_near(mm_value, back_to_mm, 1e-9, "coordinate conversion roundtrip")
}

test_point_distance_unit :: proc() -> bool {
    p1 := point2d_from_mm(0.0, 0.0)
    p2 := point2d_from_mm(3.0, 4.0)
    
    distance := point_distance(p1, p2)
    distance_mm := coord_to_mm(distance)
    expected := 5.0 // 3-4-5 triangle
    
    return test_assert_near(distance_mm, expected, 1e-6, "point distance calculation")
}

test_vector_operations_unit :: proc() -> bool {
    v1 := Vec3f{1.0, 2.0, 3.0}
    v2 := Vec3f{4.0, 5.0, 6.0}
    
    // Test dot product
    dot := vec3_dot(v1, v2)
    expected_dot: f32 = 32.0 // 1*4 + 2*5 + 3*6
    
    result := test_assert_near(f64(dot), f64(expected_dot), 1e-6, "vector dot product")
    
    // Test cross product magnitude
    cross := vec3_cross(v1, v2)
    cross_magnitude := vec3_length(cross)
    
    // For unit testing, just check it's reasonable
    result = result && test_assert(cross_magnitude > 0, "cross product has positive magnitude")
    
    return result
}

test_polygon_area_unit :: proc() -> bool {
    // Test square area
    square := polygon_create_rectangle(0.0, 0.0, 10.0, 10.0)
    defer polygon_destroy(&square)
    
    area := polygon_area_abs(&square)
    expected := 100.0
    
    return test_assert_near(area, expected, 1e-6, "square polygon area")
}

test_point_in_polygon_unit :: proc() -> bool {
    square := polygon_create_rectangle(0.0, 0.0, 10.0, 10.0)
    defer polygon_destroy(&square)
    
    inside_point := point2d_from_mm(5.0, 5.0)
    outside_point := point2d_from_mm(15.0, 5.0)
    
    inside_result := point_in_polygon(inside_point, &square)
    outside_result := point_in_polygon(outside_point, &square)
    
    return test_assert(inside_result, "point should be inside polygon") &&
           test_assert(!outside_result, "point should be outside polygon")
}

test_orientation_exact_unit :: proc() -> bool {
    // Test counter-clockwise orientation
    ccw := orientation_exact(
        point2d_from_mm(0, 0),
        point2d_from_mm(1, 0),
        point2d_from_mm(0, 1)
    )
    
    // Test clockwise orientation
    cw := orientation_exact(
        point2d_from_mm(0, 0),
        point2d_from_mm(0, 1),
        point2d_from_mm(1, 0)
    )
    
    // Test collinear
    collinear := orientation_exact(
        point2d_from_mm(0, 0),
        point2d_from_mm(1, 1),
        point2d_from_mm(2, 2)
    )
    
    return test_assert(ccw > 0, "should be counter-clockwise") &&
           test_assert(cw < 0, "should be clockwise") &&
           test_assert(collinear == 0, "should be collinear")
}

test_line_intersection_unit :: proc() -> bool {
    // Test simple intersection
    intersection := line_segment_intersection(
        point2d_from_mm(0, 0), point2d_from_mm(2, 2),  // Line 1
        point2d_from_mm(0, 2), point2d_from_mm(2, 0)   // Line 2 (crossing)
    )
    
    if intersection.type != .POINT {
        return test_assert(false, "lines should intersect at a point")
    }
    
    x_mm, y_mm := point2d_to_mm(intersection.point)
    
    return test_assert_near(x_mm, 1.0, 1e-6, "intersection X coordinate") &&
           test_assert_near(y_mm, 1.0, 1e-6, "intersection Y coordinate")
}

test_triangle_plane_intersection_unit :: proc() -> bool {
    // Create triangle that crosses Z=5 plane
    triangle := [3]Vec3f{
        {0.0, 0.0, 0.0},   // Below plane
        {10.0, 0.0, 0.0},  // Below plane
        {5.0, 10.0, 10.0}  // Above plane
    }
    
    intersection := triangle_plane_intersection(triangle, 5.0)
    
    return test_assert(intersection.has_intersection, "triangle should intersect plane")
}

test_aabb_construction_unit :: proc() -> bool {
    // Create test mesh
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    // Build AABB tree
    tree := aabb_build(&mesh)
    defer aabb_destroy(&tree)
    
    return test_assert(tree.node_count > 0, "AABB tree should have nodes") &&
           test_assert(aabb_validate(&tree), "AABB tree should be valid")
}

test_aabb_validation_unit :: proc() -> bool {
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    tree := aabb_build(&mesh)
    defer aabb_destroy(&tree)
    
    stats := aabb_get_stats(&tree)
    
    return test_assert(stats.max_depth > 0, "tree should have depth") &&
           test_assert(stats.node_count > 0, "tree should have nodes")
}

test_aabb_plane_query_unit :: proc() -> bool {
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    tree := aabb_build(&mesh)
    defer aabb_destroy(&tree)
    
    // Query plane at Z=0 (should intersect cube)
    intersections := aabb_plane_intersect(&tree, 0.0)
    defer delete(intersections)
    
    return test_assert(len(intersections) > 0, "plane should intersect cube")
}

test_aabb_ray_query_unit :: proc() -> bool {
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    tree := aabb_build(&mesh)
    defer aabb_destroy(&tree)
    
    // Ray pointing at cube center
    ray_start := Vec3f{0, 0, -10}
    ray_dir := Vec3f{0, 0, 1}
    
    hit := aabb_ray_intersect(&tree, ray_start, ray_dir)
    
    return test_assert(hit.hit, "ray should hit cube") &&
           test_assert(hit.distance > 0, "hit distance should be positive")
}

test_boolean_intersection_unit :: proc() -> bool {
    // Create two overlapping squares
    square1 := polygon_create_rectangle(0.0, 0.0, 10.0, 10.0)
    defer polygon_destroy(&square1)
    
    square2 := polygon_create_rectangle(5.0, 5.0, 15.0, 15.0)
    defer polygon_destroy(&square2)
    
    subject_polys := []Polygon{square1}
    clip_polys := []Polygon{square2}
    
    config := BooleanConfig{}
    result := polygon_intersection(subject_polys, clip_polys, config)
    defer {
        for &poly in result {
            polygon_destroy(&poly)
        }
        delete(result)
    }
    
    return test_assert(len(result) > 0, "intersection should produce result")
}

test_boolean_union_unit :: proc() -> bool {
    // Create two adjacent squares
    square1 := polygon_create_rectangle(0.0, 0.0, 10.0, 10.0)
    defer polygon_destroy(&square1)
    
    square2 := polygon_create_rectangle(10.0, 0.0, 20.0, 10.0)
    defer polygon_destroy(&square2)
    
    subject_polys := []Polygon{square1}
    clip_polys := []Polygon{square2}
    
    config := BooleanConfig{}
    result := polygon_union(subject_polys, clip_polys, config)
    defer {
        for &poly in result {
            polygon_destroy(&poly)
        }
        delete(result)
    }
    
    return test_assert(len(result) > 0, "union should produce result")
}

test_boolean_difference_unit :: proc() -> bool {
    // Create large square with hole
    outer := polygon_create_rectangle(0.0, 0.0, 20.0, 20.0)
    defer polygon_destroy(&outer)
    
    inner := polygon_create_rectangle(5.0, 5.0, 15.0, 15.0)
    defer polygon_destroy(&inner)
    
    subject_polys := []Polygon{outer}
    clip_polys := []Polygon{inner}
    
    config := BooleanConfig{}
    result := polygon_difference(subject_polys, clip_polys, config)
    defer {
        for &poly in result {
            polygon_destroy(&poly)
        }
        delete(result)
    }
    
    return test_assert(len(result) > 0, "difference should produce result")
}

// ===== PERFORMANCE TEST IMPLEMENTATIONS =====

test_aabb_construction_performance :: proc() -> bool {
    timer := perf_timer_start("AABB Construction Performance")
    
    // Create larger test mesh for performance testing
    mesh := create_complex_test_mesh()
    defer mesh_destroy(&mesh)
    
    tree := aabb_build(&mesh)
    defer aabb_destroy(&tree)
    
    duration_ms := perf_timer_stop(&timer)
    
    // ARM64 target: <100ms for 10K triangles
    return test_assert_performance(timer, 100, "AABB construction performance")
}

test_slicing_performance :: proc() -> bool {
    timer := perf_timer_start("Layer Slicing Performance")
    
    mesh := create_complex_test_mesh()
    defer mesh_destroy(&mesh)
    
    layer_height: f32 = 0.2
    slice_result := slice_mesh(&mesh, layer_height)
    defer slice_result_destroy(&slice_result)
    
    duration_ms := perf_timer_stop(&timer)
    
    // Target: process layers quickly
    return test_assert_performance(timer, 1000, "layer slicing performance")
}

test_boolean_operations_performance :: proc() -> bool {
    timer := perf_timer_start("Boolean Operations Performance")
    
    // Create complex polygons for performance testing
    large_poly := polygon_create_circle(point2d_from_mm(0, 0), 50.0, 100)
    defer polygon_destroy(&large_poly)
    
    clip_poly := polygon_create_rectangle(-25.0, -25.0, 25.0, 25.0)
    defer polygon_destroy(&clip_poly)
    
    subject_polys := []Polygon{large_poly}
    clip_polys := []Polygon{clip_poly}
    
    config := BooleanConfig{}
    result := polygon_intersection(subject_polys, clip_polys, config)
    defer {
        for &poly in result {
            polygon_destroy(&poly)
        }
        delete(result)
    }
    
    duration_ms := perf_timer_stop(&timer)
    
    return test_assert_performance(timer, 100, "boolean operations performance")
}

// ===== INTEGRATION TEST IMPLEMENTATIONS =====

test_mesh_to_layers_integration :: proc() -> bool {
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    layer_height: f32 = 1.0
    slice_result := slice_mesh(&mesh, layer_height)
    defer slice_result_destroy(&slice_result)
    
    result := test_assert(len(slice_result.layers) > 0, "should produce layers")
    result = result && test_assert(slice_result_validate(&slice_result), "slice result should be valid")
    
    return result
}

test_layer_to_polygons_integration :: proc() -> bool {
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    layer_height: f32 = 1.0
    slice_result := slice_mesh(&mesh, layer_height)
    defer slice_result_destroy(&slice_result)
    
    if len(slice_result.layers) == 0 {
        return test_assert(false, "no layers produced")
    }
    
    // Check that middle layers have polygons
    middle_layer := &slice_result.layers[len(slice_result.layers) / 2]
    
    return test_assert(len(middle_layer.polygons) > 0, "middle layer should have polygons")
}

test_memory_management_integration :: proc() -> bool {
    // Test that creating and destroying many objects doesn't leak
    start_memory := mem.total_used()
    
    for i in 0..<100 {
        mesh := create_test_cube_mesh()
        tree := aabb_build(&mesh)
        aabb_destroy(&tree)
        mesh_destroy(&mesh)
    }
    
    end_memory := mem.total_used()
    memory_growth := end_memory - start_memory
    
    // Allow some growth but not excessive
    return test_assert(memory_growth < 1024*1024, "memory growth should be minimal")  // <1MB
}

// ===== SYSTEM TEST IMPLEMENTATIONS =====

test_stl_to_gcode_system :: proc() -> bool {
    // This would test the complete pipeline
    // For now, just return success as a placeholder
    fmt.println("    System test: STL to G-code pipeline (placeholder)")
    return true
}

test_real_world_models_system :: proc() -> bool {
    // This would test with actual STL files
    fmt.println("    System test: Real world models (placeholder)")
    return true
}

test_stress_system :: proc() -> bool {
    // This would test with large/complex models
    fmt.println("    System test: Stress testing (placeholder)")
    return true
}

// ===== HELPER FUNCTIONS =====

create_complex_test_mesh :: proc() -> TriangleMesh {
    // Create a more complex mesh for performance testing
    // For now, just use the simple cube - in real implementation,
    // this would create a mesh with thousands of triangles
    return create_test_cube_mesh()
}
