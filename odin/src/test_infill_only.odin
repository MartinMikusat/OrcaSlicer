package main

import "core:fmt"

// Simple test for infill generation only
test_infill_generation_only :: proc() {
    fmt.println("=== Testing Infill Generation Only ===")
    
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
    
    // Test infill generation with different patterns
    settings := print_settings_default()
    settings.infill.density = 0.2 // 20% infill
    settings.infill.pattern = .RECTILINEAR
    settings.infill.angle = 0.0  // Force horizontal lines for debugging
    settings.perimeter.wall_count = 1 // Reduce walls for more infill space
    settings.perimeter.wall_thickness = 0.4
    layer_polygons := []ExPolygon{expoly}
    
    fmt.printf("Settings: density=%.2f, pattern=%v, walls=%d, thickness=%.2f\n", 
               settings.infill.density, settings.infill.pattern, 
               settings.perimeter.wall_count, settings.perimeter.wall_thickness)
    
    fmt.println("Calling generate_layer_infill...")
    
    // Debug: Test infill region calculation directly
    infill_region := calculate_infill_region(&expoly, settings)
    fmt.printf("DEBUG: Infill region has %d polygons\n", len(infill_region))
    for i in 0..<len(infill_region) {
        poly := &infill_region[i]
        area := polygon_area(poly)
        fmt.printf("  Region %d: %.2f mm², %d points\n", i, abs(area), len(poly.points))
    }
    defer {
        for &poly in infill_region {
            polygon_destroy(&poly)
        }
        delete(infill_region)
    }
    
    // Debug: Test rectilinear pattern generation directly
    fmt.printf("DEBUG: Infill settings - angle=%.1f, density=%.2f, spacing=%.2f\n",
               settings.infill.angle, settings.infill.density, 
               settings.infill.line_width / settings.infill.density)
    
    pattern_lines := generate_rectilinear_pattern(infill_region, settings.infill, 0)
    fmt.printf("DEBUG: Rectilinear pattern generated %d lines\n", len(pattern_lines))
    defer {
        for &line in pattern_lines {
            delete(line.points)
        }
        delete(pattern_lines)
    }
    
    // Debug: Test line clipping
    fmt.println("DEBUG: Testing line clipping...")
    if len(pattern_lines) > 0 && len(infill_region) > 0 {
        test_line := &pattern_lines[0]
        test_poly := &infill_region[0]
        fmt.printf("  Test line: (%.1f,%.1f) to (%.1f,%.1f)\n", 
                   coord_to_mm(test_line.points[0].x), coord_to_mm(test_line.points[0].y),
                   coord_to_mm(test_line.points[1].x), coord_to_mm(test_line.points[1].y))
        
        // Test polygon bounds in mm for clarity
        bbox := polygon_bounding_box(test_poly)
        fmt.printf("  Polygon bounds: (%.1f,%.1f) to (%.1f,%.1f) mm\n", 
                   coord_to_mm(bbox.min.x), coord_to_mm(bbox.min.y), 
                   coord_to_mm(bbox.max.x), coord_to_mm(bbox.max.y))
        
        // Test intersections
        intersections := find_line_polygon_intersections(test_line.points[0], test_line.points[1], test_poly)
        fmt.printf("  Found %d intersections\n", len(intersections))
        delete(intersections)
    }
    
    clipped_lines := clip_infill_lines(pattern_lines, infill_region)
    fmt.printf("DEBUG: After clipping: %d lines\n", len(clipped_lines))
    defer {
        for &line in clipped_lines {
            delete(line.points)
        }
        delete(clipped_lines)
    }
    
    infill_paths := generate_layer_infill(layer_polygons, settings, 0, 0.2)
    defer {
        for &path in infill_paths {
            print_path_destroy(&path)
        }
        delete(infill_paths)
    }
    
    fmt.printf("Generated %d infill paths\n", len(infill_paths))
    
    total_length: f64 = 0.0
    for i in 0..<len(infill_paths) {
        path := &infill_paths[i]
        fmt.printf("Path %d: type=%v, %d moves, %.2fmm length\n", 
                   i, path.type, len(path.moves), path.total_length)
        total_length += path.total_length
    }
    
    fmt.printf("Total infill length: %.2fmm\n", total_length)
    
    // Test honeycomb pattern
    fmt.println("Testing honeycomb pattern...")
    settings.infill.pattern = .HONEYCOMB
    honeycomb_paths := generate_layer_infill(layer_polygons, settings, 0, 0.2)
    defer {
        for &path in honeycomb_paths {
            print_path_destroy(&path)
        }
        delete(honeycomb_paths)
    }
    
    fmt.printf("Generated %d honeycomb paths\n", len(honeycomb_paths))
    
    fmt.println("✓ Infill generation test completed")
}