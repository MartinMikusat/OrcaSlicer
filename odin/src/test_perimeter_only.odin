package main

import "core:fmt"

// Simple test for perimeter generation only
test_perimeter_generation_only :: proc() {
    fmt.println("=== Testing Perimeter Generation Only ===")
    
    // Create simple square
    square := polygon_create()
    defer polygon_destroy(&square)
    
    polygon_add_point(&square, point2d_from_mm(0, 0))
    polygon_add_point(&square, point2d_from_mm(10, 0))
    polygon_add_point(&square, point2d_from_mm(10, 10))
    polygon_add_point(&square, point2d_from_mm(0, 10))
    polygon_make_ccw(&square)
    
    // Create ExPolygon
    expoly := expolygon_create()
    defer expolygon_destroy(&expoly)
    
    for point in square.points {
        polygon_add_point(&expoly.contour, point)
    }
    
    fmt.println("Created test geometry")
    
    // Test perimeter generation
    settings := print_settings_default()
    layer_polygons := []ExPolygon{expoly}
    
    fmt.println("Calling generate_layer_perimeters...")
    perimeter_paths := generate_layer_perimeters(layer_polygons, settings, 0, 0.2)
    defer {
        for &path in perimeter_paths {
            print_path_destroy(&path)
        }
        delete(perimeter_paths)
    }
    
    fmt.printf("Generated %d perimeter paths\n", len(perimeter_paths))
    
    for i in 0..<len(perimeter_paths) {
        path := perimeter_paths[i]
        fmt.printf("Path %d: type=%v, %d moves, %.2fmm length\n", 
                   i, path.type, len(path.moves), path.total_length)
    }
    
    fmt.println("✓ Perimeter generation test completed")
}

// Moved to main.odin as a flag