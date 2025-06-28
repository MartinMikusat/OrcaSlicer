package main

import "core:fmt"

// Test the core slicing pipeline end-to-end
test_core_slicing_pipeline :: proc() {
    fmt.println("\n=== Testing Core Slicing Pipeline ===")
    
    // Create a simple test cube
    fmt.println("1. Creating test geometry...")
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    stats := mesh_get_stats(&mesh)
    fmt.printf("   Test cube: %d vertices, %d triangles\n", stats.num_vertices, stats.num_triangles)
    
    // Slice mesh into layers
    fmt.println("2. Slicing mesh into layers...")
    layer_height: f32 = 2.0
    slice_result := slice_mesh(&mesh, layer_height)
    defer slice_result_destroy(&slice_result)
    
    fmt.printf("   Sliced into %d layers\n", len(slice_result.layers))
    
    // Test layer processing
    if len(slice_result.layers) > 2 {
        layer := &slice_result.layers[2] // Pick middle layer
        fmt.printf("3. Processing layer %d (Z=%.1f)...\n", 2, layer.z_height)
        fmt.printf("   Layer has %d polygons\n", len(layer.polygons))
        
        if len(layer.polygons) > 0 {
            expoly := &layer.polygons[0]
            area := expolygon_area(expoly)
            fmt.printf("   Main polygon area: %.2f mm²\n", area)
            
            // Test perimeter generation
            fmt.println("4. Generating perimeters...")
            settings := print_settings_default()
            
            perimeter_paths := generate_layer_perimeters(layer.polygons[:], settings, 2, layer.z_height)
            defer {
                for &path in perimeter_paths {
                    print_path_destroy(&path)
                }
                delete(perimeter_paths)
            }
            
            fmt.printf("   Generated %d perimeter paths\n", len(perimeter_paths))
            
            // Count path types
            outer_count := 0
            inner_count := 0
            for path in perimeter_paths {
                #partial switch path.type {
                case .PERIMETER_OUTER:
                    outer_count += 1
                case .PERIMETER_INNER:
                    inner_count += 1
                }
            }
            fmt.printf("   Path types: %d outer, %d inner\n", outer_count, inner_count)
            
            // Test infill generation
            fmt.println("5. Generating infill...")
            infill_paths := generate_layer_infill(layer.polygons[:], settings, 2, layer.z_height)
            defer {
                for &path in infill_paths {
                    print_path_destroy(&path)
                }
                delete(infill_paths)
            }
            
            fmt.printf("   Generated %d infill paths\n", len(infill_paths))
            
            // Test G-code generation for this layer
            fmt.println("6. Testing G-code generation...")
            
            // Create a simple print job with just this layer
            job := print_job_create()
            defer print_job_destroy(&job)
            
            print_layer := print_layer_create(2, layer.z_height)
            
            // Add perimeter paths
            for &path in perimeter_paths {
                path_copy := print_path_copy(&path)
                print_layer_add_path(&print_layer, path_copy)
            }
            
            // Add infill paths
            for &path in infill_paths {
                path_copy := print_path_copy(&path)
                print_layer_add_path(&print_layer, path_copy)
            }
            
            print_job_add_layer(&job, print_layer)
            
            // Generate G-code
            gcode_settings := gcode_settings_default()
            gcode := generate_gcode(&job, gcode_settings)
            defer delete(gcode)
            
            // Analyze G-code
            analysis := analyze_gcode(gcode)
            fmt.printf("   G-code: %d lines, %d commands\n", 
                      analysis.total_lines, analysis.command_lines)
            
            if analysis.total_lines > 10 {
                fmt.println("   ✓ Successfully generated G-code")
            } else {
                fmt.println("   ⚠ G-code seems too short")
            }
        }
    }
    
    fmt.println("✓ Core slicing pipeline test completed")
}

// Helper function to copy print path for testing
print_path_copy :: proc(src: ^PrintPath) -> PrintPath {
    copy := PrintPath{
        moves = make([dynamic]PrintMove),
        type = src.type,
        layer_index = src.layer_index,
        is_closed = src.is_closed,
        total_length = src.total_length,
    }
    
    for move in src.moves {
        append(&copy.moves, move)
    }
    
    return copy
}
