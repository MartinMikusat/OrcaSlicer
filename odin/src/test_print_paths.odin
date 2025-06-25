package main

import "core:fmt"
import "core:os"

// Simple test program focused just on print path generation
simple_print_path_test :: proc() {
    fmt.println("=== Testing Print Path Generation Only ===")
    
    // Create a simple test square (5x5mm)
    fmt.println("Creating test geometry...")
    
    square := polygon_create()
    defer polygon_destroy(&square)
    
    polygon_add_point(&square, point2d_from_mm(0, 0))
    polygon_add_point(&square, point2d_from_mm(5, 0))
    polygon_add_point(&square, point2d_from_mm(5, 5))
    polygon_add_point(&square, point2d_from_mm(0, 5))
    
    polygon_make_ccw(&square)
    
    // Create ExPolygon
    expoly := expolygon_create()
    defer expolygon_destroy(&expoly)
    
    for point in square.points {
        polygon_add_point(&expoly.contour, point)
    }
    
    fmt.printf("Test geometry: %.2f mm² area\n", expolygon_area(&expoly))
    
    // Test perimeter generation
    fmt.println("Testing perimeter generation...")
    
    settings := print_settings_default()
    layer_polygons := []ExPolygon{expoly}
    
    perimeter_paths := generate_layer_perimeters(layer_polygons, settings, 0, 0.2)
    defer {
        for &path in perimeter_paths {
            print_path_destroy(&path)
        }
        delete(perimeter_paths)
    }
    
    fmt.printf("Generated %d perimeter paths\n", len(perimeter_paths))
    
    total_length: f64 = 0.0
    for path in perimeter_paths {
        total_length += path.total_length
        fmt.printf("  %v: %d moves, %.2fmm\n", path.type, len(path.moves), path.total_length)
    }
    
    fmt.printf("Total perimeter length: %.2fmm\n", total_length)
    
    // Test infill generation  
    fmt.println("Testing infill generation...")
    
    infill_paths := generate_layer_infill(layer_polygons, settings, 0, 0.2)
    defer {
        for &path in infill_paths {
            print_path_destroy(&path)
        }
        delete(infill_paths)
    }
    
    fmt.printf("Generated %d infill paths\n", len(infill_paths))
    
    infill_length: f64 = 0.0
    for path in infill_paths {
        infill_length += path.total_length
    }
    
    fmt.printf("Total infill length: %.2fmm\n", infill_length)
    
    // Test G-code generation
    fmt.println("Testing G-code generation...")
    
    layer := print_layer_create(0, 0.2)
    defer print_layer_destroy(&layer)
    
    // Add perimeter paths
    for path in perimeter_paths {
        path_copy := PrintPath{
            moves = make([dynamic]PrintMove),
            type = path.type,
            layer_index = path.layer_index,
            is_closed = path.is_closed,
            total_length = path.total_length,
        }
        for move in path.moves {
            append(&path_copy.moves, move)
        }
        print_layer_add_path(&layer, path_copy)
    }
    
    job := print_job_create()
    defer print_job_destroy(&job)
    
    print_job_add_layer(&job, layer)
    
    gcode_settings := gcode_settings_default()
    gcode := generate_gcode(&job, gcode_settings)
    defer delete(gcode)
    
    analysis := analyze_gcode(gcode)
    fmt.printf("G-code: %d lines, %d commands\n", analysis.total_lines, analysis.command_lines)
    
    // Save to file
    success := save_gcode_to_file(gcode, "simple_test.gcode")
    if success {
        fmt.println("G-code saved to simple_test.gcode")
    }
    
    fmt.println("✓ Print path generation test completed successfully!")
}