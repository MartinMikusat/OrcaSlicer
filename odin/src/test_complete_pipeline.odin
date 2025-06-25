package main

import "core:fmt"

// Complete end-to-end pipeline test: STL → G-code
test_complete_pipeline :: proc() {
    fmt.println("=== Testing Complete STL to G-code Pipeline ===")
    
    // Step 1: Create test geometry (10x10x10mm cube)
    fmt.println("Step 1: Creating test geometry...")
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    fmt.printf("  Created cube: %d vertices, %d triangles\n", 
               len(mesh.its.vertices), len(mesh.its.indices))
    
    // Step 2: Slice into layers
    fmt.println("Step 2: Slicing geometry into layers...")
    settings := print_settings_default()
    settings.infill.angle = 0.0  // Use horizontal lines for predictable output
    
    slice_result := slice_mesh(&mesh, f32(settings.layer_height))
    defer slice_result_destroy(&slice_result)
    
    fmt.printf("  Sliced into %d layers\n", len(slice_result.layers))
    
    // Step 3: Create print job
    fmt.println("Step 3: Creating print job...")
    job := print_job_create()
    defer print_job_destroy(&job)
    
    // Step 4: Generate paths for each layer
    fmt.println("Step 4: Generating print paths...")
    total_perimeter_paths := 0
    total_infill_paths := 0
    
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
        total_perimeter_paths += len(perimeter_paths)
        delete(perimeter_paths)
        
        // Generate infill
        infill_paths := generate_layer_infill(layer.polygons[:], settings, 
                                            u32(layer_idx), layer.z_height)
        for path in infill_paths {
            print_layer_add_path(&print_layer, path)
        }
        total_infill_paths += len(infill_paths)
        delete(infill_paths)
        
        append(&job.layers, print_layer)
    }
    
    fmt.printf("  Generated %d perimeter paths, %d infill paths\n", 
               total_perimeter_paths, total_infill_paths)
    
    // Step 5: Calculate job statistics
    fmt.println("Step 5: Calculating print statistics...")
    job.total_print_time = 0.0
    job.total_filament = 0.0
    
    for &layer in job.layers {
        job.total_print_time += layer.layer_time
        for &path in layer.paths {
            job.total_filament += path.total_length
        }
    }
    
    fmt.printf("  Estimated print time: %.1f minutes\n", job.total_print_time / 60.0)
    fmt.printf("  Total filament: %.2f meters\n", job.total_filament / 1000.0)
    
    // Step 6: Generate G-code
    fmt.println("Step 6: Generating G-code...")
    gcode_settings := gcode_settings_default()
    gcode := generate_gcode(&job, gcode_settings)
    defer delete(gcode)
    
    // Step 7: Analyze G-code
    fmt.println("Step 7: Analyzing G-code...")
    analysis := analyze_gcode(gcode)
    print_gcode_analysis(analysis)
    
    // Step 8: Save G-code to file
    fmt.println("Step 8: Saving G-code...")
    output_filename := "test_cube.gcode"
    success := save_gcode_to_file(gcode, output_filename)
    
    if success {
        fmt.printf("  ✓ G-code saved to %s\n", output_filename)
        fmt.printf("  File contains %d lines of G-code\n", analysis.total_lines)
    } else {
        fmt.printf("  ✗ Failed to save G-code to %s\n", output_filename)
    }
    
    fmt.println("✓ Complete pipeline test completed")
}

// Note: Using create_test_cube_mesh() from main.odin