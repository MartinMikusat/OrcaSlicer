package main

import "core:fmt"
import "core:time"

// Performance benchmark for complete slicer pipeline
test_performance_benchmark :: proc() {
    fmt.println("=== Performance Benchmark ===")
    
    // Create test geometry - larger cube for more realistic benchmark
    mesh := create_test_cube_mesh()
    defer mesh_destroy(&mesh)
    
    settings := print_settings_default()
    settings.layer_height = 0.1  // Finer layers for more processing
    settings.infill.density = 0.2
    settings.infill.pattern = .HONEYCOMB  // Most complex pattern
    
    fmt.printf("Benchmarking with %.1fmm layers, %s infill, %.0f%% density\n",
               settings.layer_height, settings.infill.pattern, settings.infill.density * 100)
    
    total_start := time.now()
    
    // 1. Slicing benchmark
    slice_start := time.now()
    slice_result := slice_mesh(&mesh, f32(settings.layer_height))
    defer slice_result_destroy(&slice_result)
    slice_time := time.duration_milliseconds(time.diff(slice_start, time.now()))
    
    fmt.printf("1. Slicing: %d layers in %.2fms (%.3fms/layer)\n",
               len(slice_result.layers), slice_time, slice_time / f64(len(slice_result.layers)))
    
    // 2. Path generation benchmark
    path_start := time.now()
    job := print_job_create()
    defer print_job_destroy(&job)
    
    total_perimeter_paths := 0
    total_infill_paths := 0
    
    for layer_idx in 0..<len(slice_result.layers) {
        layer := &slice_result.layers[layer_idx]
        if len(layer.polygons) == 0 do continue
        
        print_layer := print_layer_create(u32(layer_idx), layer.z_height)
        
        // Perimeter generation
        perimeter_paths := generate_layer_perimeters(layer.polygons[:], settings, 
                                                   u32(layer_idx), layer.z_height)
        for path in perimeter_paths {
            print_layer_add_path(&print_layer, path)
        }
        total_perimeter_paths += len(perimeter_paths)
        delete(perimeter_paths)
        
        // Infill generation
        infill_paths := generate_layer_infill(layer.polygons[:], settings, 
                                            u32(layer_idx), layer.z_height)
        for path in infill_paths {
            print_layer_add_path(&print_layer, path)
        }
        total_infill_paths += len(infill_paths)
        delete(infill_paths)
        
        append(&job.layers, print_layer)
    }
    
    path_time := time.duration_milliseconds(time.diff(path_start, time.now()))
    total_paths := total_perimeter_paths + total_infill_paths
    
    fmt.printf("2. Path generation: %d paths in %.2fms (%.3fms/path)\n",
               total_paths, path_time, path_time / f64(total_paths))
    fmt.printf("   - Perimeters: %d paths\n", total_perimeter_paths)
    fmt.printf("   - Infill: %d paths\n", total_infill_paths)
    
    // 3. Job statistics calculation
    stats_start := time.now()
    job.total_print_time = 0.0
    job.total_filament = 0.0
    for &layer in job.layers {
        job.total_print_time += layer.layer_time
        for &path in layer.paths {
            job.total_filament += path.total_length
        }
    }
    stats_time := time.duration_milliseconds(time.diff(stats_start, time.now()))
    
    fmt.printf("3. Statistics: %.2fms\n", stats_time)
    
    // 4. G-code generation benchmark
    gcode_start := time.now()
    gcode_settings := gcode_settings_default()
    gcode := generate_gcode(&job, gcode_settings)
    defer delete(gcode)
    gcode_time := time.duration_milliseconds(time.diff(gcode_start, time.now()))
    
    analysis := analyze_gcode(gcode)
    
    fmt.printf("4. G-code generation: %d lines in %.2fms (%.0f lines/ms)\n",
               analysis.total_lines, gcode_time, f64(analysis.total_lines) / gcode_time)
    
    // Total time
    total_time := time.duration_milliseconds(time.diff(total_start, time.now()))
    
    fmt.printf("\nTotal pipeline: %.2fms\n", total_time)
    fmt.printf("Output: %.1fm filament, %.1fmin print time, %dKB G-code\n",
               job.total_filament / 1000.0, job.total_print_time / 60.0, 
               len(gcode) / 1024)
    
    // Performance summary
    fmt.println("\n--- Performance Analysis ---")
    fmt.printf("Slicing speed: %.1f layers/ms\n", f64(len(slice_result.layers)) / slice_time)
    fmt.printf("Path generation: %.1f paths/ms\n", f64(total_paths) / path_time)
    fmt.printf("G-code output: %.0f lines/ms\n", f64(analysis.total_lines) / gcode_time)
    fmt.printf("Overall throughput: %.1f layers/sec\n", 
               f64(len(slice_result.layers)) * 1000.0 / total_time)
    
    fmt.println("✓ Performance benchmark completed")
}