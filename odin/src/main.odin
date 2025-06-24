package main

import "core:fmt"
import "core:os"
import "core:math"

main :: proc() {
    fmt.println("=== OrcaSlicer Odin - Phase 1 Foundation ===")
    
    // Test all core components
    test_coordinates()
    test_geometry()
    test_mesh_creation()
    test_polygon_operations()
    
    // Test STL functionality if file provided
    if len(os.args) > 1 {
        test_stl_loading(os.args[1])
    }
    
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