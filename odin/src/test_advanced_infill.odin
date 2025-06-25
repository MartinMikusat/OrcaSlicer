package main

import "core:fmt"

// Test advanced infill patterns with rotation
test_advanced_infill_patterns :: proc() {
    fmt.println("=== Testing Advanced Infill Patterns ===")
    
    // Create test geometry
    square := polygon_create()
    defer polygon_destroy(&square)
    
    polygon_add_point(&square, point2d_from_mm(0, 0))
    polygon_add_point(&square, point2d_from_mm(10, 0))
    polygon_add_point(&square, point2d_from_mm(10, 10))
    polygon_add_point(&square, point2d_from_mm(0, 10))
    polygon_make_ccw(&square)
    
    expoly := expolygon_create()
    defer expolygon_destroy(&expoly)
    
    for point in square.points {
        polygon_add_point(&expoly.contour, point)
    }
    
    layer_polygons := []ExPolygon{expoly}
    
    // Test rectilinear at 45 degrees
    fmt.println("Testing rectilinear infill at 45°...")
    settings_45 := print_settings_default()
    settings_45.infill.pattern = .RECTILINEAR
    settings_45.infill.angle = 45.0
    settings_45.infill.density = 0.15
    
    paths_45 := generate_layer_infill(layer_polygons, settings_45, 0, 0.2)
    defer {
        for &path in paths_45 {
            print_path_destroy(&path)
        }
        delete(paths_45)
    }
    
    fmt.printf("  45° rectilinear: %d paths\n", len(paths_45))
    
    // Test honeycomb pattern  
    fmt.println("Testing honeycomb infill...")
    settings_hex := print_settings_default()
    settings_hex.infill.pattern = .HONEYCOMB
    settings_hex.infill.density = 0.15
    
    paths_hex := generate_layer_infill(layer_polygons, settings_hex, 0, 0.2)
    defer {
        for &path in paths_hex {
            print_path_destroy(&path)
        }
        delete(paths_hex)
    }
    
    fmt.printf("  Honeycomb: %d paths\n", len(paths_hex))
    
    // Test grid pattern
    fmt.println("Testing grid infill...")
    settings_grid := print_settings_default()
    settings_grid.infill.pattern = .GRID
    settings_grid.infill.density = 0.15
    
    paths_grid := generate_layer_infill(layer_polygons, settings_grid, 0, 0.2)
    defer {
        for &path in paths_grid {
            print_path_destroy(&path)
        }
        delete(paths_grid)
    }
    
    fmt.printf("  Grid: %d paths\n", len(paths_grid))
    
    // Calculate total lengths
    total_45: f64 = 0
    for path in paths_45 {
        total_45 += path.total_length
    }
    
    total_hex: f64 = 0
    for path in paths_hex {
        total_hex += path.total_length
    }
    
    total_grid: f64 = 0
    for path in paths_grid {
        total_grid += path.total_length
    }
    
    fmt.printf("Total lengths: 45°=%.1fmm, honeycomb=%.1fmm, grid=%.1fmm\n", 
               total_45, total_hex, total_grid)
    
    // Verify all patterns generated reasonable amounts of infill
    success := len(paths_45) > 0 && len(paths_hex) > 0 && len(paths_grid) > 0
    if success {
        fmt.println("✓ All advanced infill patterns working")
    } else {
        fmt.println("✗ Some infill patterns failed")
    }
    
    fmt.println("✓ Advanced infill pattern test completed")
}