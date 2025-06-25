package main

import "core:fmt"
import "core:time"

// Stress test with larger, more complex geometry
test_stress_test :: proc() {
    fmt.println("=== Stress Test ===")
    
    // Create more complex geometry - multiple cubes to simulate real model
    stress_start := time.now()
    
    mesh := create_stress_test_geometry()
    defer mesh_destroy(&mesh)
    
    geometry_time := time.duration_milliseconds(time.diff(stress_start, time.now()))
    fmt.printf("Created complex geometry: %d vertices, %d triangles in %.2fms\n",
               len(mesh.its.vertices), len(mesh.its.indices), geometry_time)
    
    // Stress test settings - high resolution, complex infill
    settings := print_settings_default()
    settings.layer_height = 0.15  // Fine resolution
    settings.infill.density = 0.25  // 25% infill
    settings.infill.pattern = .HONEYCOMB
    settings.perimeter.wall_count = 3  // More walls
    
    fmt.printf("Stress test: %.2fmm layers, %d walls, %s %.0f%% infill\n",
               settings.layer_height, settings.perimeter.wall_count,
               settings.infill.pattern, settings.infill.density * 100)
    
    // Run complete pipeline
    pipeline_start := time.now()
    
    slice_result := slice_mesh(&mesh, f32(settings.layer_height))
    defer slice_result_destroy(&slice_result)
    
    job := print_job_create()
    defer print_job_destroy(&job)
    
    total_paths := 0
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
        total_paths += len(perimeter_paths)
        delete(perimeter_paths)
        
        // Generate infill  
        infill_paths := generate_layer_infill(layer.polygons[:], settings, 
                                            u32(layer_idx), layer.z_height)
        for path in infill_paths {
            print_layer_add_path(&print_layer, path)
        }
        total_paths += len(infill_paths)
        delete(infill_paths)
        
        append(&job.layers, print_layer)
    }
    
    // Calculate statistics
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
    
    pipeline_time := time.duration_milliseconds(time.diff(pipeline_start, time.now()))
    
    // Analysis
    analysis := analyze_gcode(gcode)
    
    fmt.printf("\n--- Stress Test Results ---\n")
    fmt.printf("Pipeline time: %.2fms\n", pipeline_time)
    fmt.printf("Layers processed: %d\n", len(slice_result.layers))
    fmt.printf("Paths generated: %d\n", total_paths)
    fmt.printf("G-code lines: %d\n", analysis.total_lines)
    fmt.printf("Output size: %dKB\n", len(gcode) / 1024)
    fmt.printf("Filament usage: %.1fm\n", job.total_filament / 1000.0)
    fmt.printf("Print time: %.1fmin\n", job.total_print_time / 60.0)
    
    fmt.printf("\n--- Performance Metrics ---\n")
    fmt.printf("Throughput: %.1f layers/sec\n", 
               f64(len(slice_result.layers)) * 1000.0 / pipeline_time)
    fmt.printf("Path generation: %.1f paths/ms\n", 
               f64(total_paths) / pipeline_time)
    fmt.printf("G-code generation: %.0f lines/ms\n", 
               f64(analysis.total_lines) / pipeline_time)
    
    // Save stress test result
    filename := "stress_test_result.gcode"
    success := save_gcode_to_file(gcode, filename)
    if success {
        fmt.printf("✓ Stress test G-code saved to %s\n", filename)
    }
    
    fmt.println("✓ Stress test completed successfully")
}

// Create more complex test geometry (multiple connected cubes)
create_stress_test_geometry :: proc() -> TriangleMesh {
    mesh := mesh_create()
    
    // Create a 3x3 grid of connected cubes
    cube_size: f32 = 3.0
    spacing: f32 = 3.5
    
    for x in 0..<3 {
        for y in 0..<3 {
            for z in 0..<2 {  // Two layers of cubes
                offset_x := f32(x) * spacing - spacing
                offset_y := f32(y) * spacing - spacing  
                offset_z := f32(z) * spacing
                
                add_cube_to_mesh(&mesh, 
                                Vec3f{offset_x, offset_y, offset_z}, 
                                cube_size)
            }
        }
    }
    
    return mesh
}

// Add a single cube to existing mesh
add_cube_to_mesh :: proc(mesh: ^TriangleMesh, center: Vec3f, size: f32) {
    half_size := size / 2.0
    
    // Cube vertices
    vertices := [8]Vec3f{
        {center.x - half_size, center.y - half_size, center.z - half_size},
        {center.x + half_size, center.y - half_size, center.z - half_size},
        {center.x + half_size, center.y + half_size, center.z - half_size},
        {center.x - half_size, center.y + half_size, center.z - half_size},
        {center.x - half_size, center.y - half_size, center.z + half_size},
        {center.x + half_size, center.y - half_size, center.z + half_size},
        {center.x + half_size, center.y + half_size, center.z + half_size},
        {center.x - half_size, center.y + half_size, center.z + half_size},
    }
    
    // Add vertices and get indices
    vertex_indices: [8]u32
    for i, vertex in vertices {
        vertex_indices[i] = its_add_vertex(&mesh.its, vertex)
    }
    
    // Cube triangles (12 triangles, 2 per face)
    triangle_indices := [12][3]u32{
        {0, 2, 1}, {0, 3, 2},  // Bottom
        {4, 5, 6}, {4, 6, 7},  // Top
        {0, 1, 5}, {0, 5, 4},  // Front
        {2, 7, 6}, {2, 3, 7},  // Back
        {0, 4, 7}, {0, 7, 3},  // Left
        {1, 2, 6}, {1, 6, 5},  // Right
    }
    
    // Add triangles
    for triangle in triangle_indices {
        its_add_triangle(&mesh.its, 
                        vertex_indices[triangle[0]], 
                        vertex_indices[triangle[1]], 
                        vertex_indices[triangle[2]])
    }
}