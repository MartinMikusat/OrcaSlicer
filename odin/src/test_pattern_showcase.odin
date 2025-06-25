package main

import "core:fmt"

// Generate G-code files showcasing different infill patterns
test_pattern_showcase :: proc() {
    fmt.println("=== Testing Pattern Showcase ===")
    
    // Create test geometry
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    // Base settings
    base_settings := print_settings_default()
    base_settings.infill.density = 0.2  // 20% infill for visibility
    
    patterns := []struct{
        name: string,
        pattern: InfillPattern,
        angle: f64,
    }{
        {"rectilinear_0deg", .RECTILINEAR, 0.0},
        {"rectilinear_45deg", .RECTILINEAR, 45.0},
        {"honeycomb", .HONEYCOMB, 0.0},
        {"grid", .GRID, 0.0},
    }
    
    for pattern_info in patterns {
        fmt.printf("Generating %s pattern...\n", pattern_info.name)
        
        // Configure settings for this pattern
        settings := base_settings
        settings.infill.pattern = pattern_info.pattern
        settings.infill.angle = pattern_info.angle
        
        // Slice and generate paths
        slice_result := slice_mesh(&mesh, f32(settings.layer_height))
        defer slice_result_destroy(&slice_result)
        
        job := print_job_create()
        defer print_job_destroy(&job)
        
        path_count := 0
        for layer_idx in 0..<len(slice_result.layers) {
            layer := &slice_result.layers[layer_idx]
            if len(layer.polygons) == 0 do continue
            
            print_layer := print_layer_create(u32(layer_idx), layer.z_height)
            
            // Generate perimeters
            perimeter_paths := generate_layer_perimeters(layer.polygons[:], settings, 
                                                       u32(layer_idx), layer.z_height)
            for path in perimeter_paths {
                print_layer_add_path(&print_layer, path)
            }
            path_count += len(perimeter_paths)
            delete(perimeter_paths)
            
            // Generate infill with this pattern
            infill_paths := generate_layer_infill(layer.polygons[:], settings, 
                                                u32(layer_idx), layer.z_height)
            for path in infill_paths {
                print_layer_add_path(&print_layer, path)
            }
            path_count += len(infill_paths)
            delete(infill_paths)
            
            append(&job.layers, print_layer)
        }
        
        // Calculate job statistics
        job.total_print_time = 0.0
        job.total_filament = 0.0
        for &layer in job.layers {
            job.total_print_time += layer.layer_time
            for &path in layer.paths {
                job.total_filament += path.total_length
            }
        }
        
        // Generate G-code
        gcode_settings := gcode_settings_default()
        gcode := generate_gcode(&job, gcode_settings)
        defer delete(gcode)
        
        // Save to file
        filename := fmt.aprintf("test_%s.gcode", pattern_info.name)
        defer delete(filename)
        
        success := save_gcode_to_file(gcode, filename)
        if success {
            analysis := analyze_gcode(gcode)
            fmt.printf("  ✓ %s: %d paths, %.1fmm filament, %d G-code lines → %s\n",
                       pattern_info.name, path_count, job.total_filament, 
                       analysis.total_lines, filename)
        } else {
            fmt.printf("  ✗ Failed to save %s\n", filename)
        }
    }
    
    fmt.println("✓ Pattern showcase completed")
}