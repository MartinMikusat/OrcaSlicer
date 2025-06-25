package main

import "core:fmt"
import "core:math"

// Test path optimization system
test_path_optimization :: proc() {
    fmt.println("\n=== Testing Path Optimization ===")
    
    // Create test print job with multiple paths
    fmt.println("Creating test print job...")
    
    job := create_test_print_job_for_optimization()
    defer print_job_destroy(&job)
    
    // Analyze job before optimization
    fmt.println("Analyzing job before optimization...")
    before_analysis := analyze_print_job(&job)
    print_path_optimization_summary(before_analysis)
    
    // Test path optimization
    fmt.println("\nTesting path optimization...")
    
    settings := path_optimization_settings_default()
    after_analysis := optimize_print_job(&job, settings)
    
    // Validate optimized paths
    validate_optimized_paths(&job)
    
    fmt.println("✓ Path optimization tests completed successfully!")
}

// Test seam optimization specifically
test_seam_optimization :: proc() {
    fmt.println("\n=== Testing Seam Optimization ===")
    
    // Create test perimeter path
    test_path := create_test_perimeter_path()
    defer print_path_destroy(&test_path)
    
    // Test different seam positions
    seam_positions := []SeamPosition{.SHARPEST, .NEAREST, .ALIGNED, .RANDOM}
    
    for position in seam_positions {
        fmt.printf("Testing seam position: %v\n", position)
        
        path_copy := copy_print_path(&test_path)
        defer print_path_destroy(&path_copy)
        
        settings := path_optimization_settings_default()
        settings.seam_position = position
        
        optimize_seam_placement(&path_copy, settings)
        
        fmt.printf("  Seam moved to start position: (%.2f, %.2f)\n",
                   coord_to_mm(get_path_start_position(&path_copy).x),
                   coord_to_mm(get_path_start_position(&path_copy).y))
    }
    
    fmt.println("✓ Seam optimization tests completed!")
}

// Test travel optimization
test_travel_optimization :: proc() {
    fmt.println("\n=== Testing Travel Optimization ===")
    
    // Create test layer with scattered paths
    layer := create_test_layer_with_scattered_paths()
    defer print_layer_destroy(&layer)
    
    fmt.printf("Before optimization: %d paths\n", len(layer.paths))
    
    // Calculate initial travel distance
    initial_travel := calculate_total_travel_distance(&layer)
    fmt.printf("Initial travel distance: %.2f mm\n", initial_travel)
    
    // Test path ordering optimization
    settings := path_optimization_settings_default()
    optimize_layer_path_order(&layer, settings)
    
    optimized_travel := calculate_total_travel_distance(&layer)
    fmt.printf("Optimized travel distance: %.2f mm\n", optimized_travel)
    
    if optimized_travel < initial_travel {
        reduction := (initial_travel - optimized_travel) / initial_travel * 100.0
        fmt.printf("Travel reduction: %.1f%%\n", reduction)
    }
    
    // Test travel move creation
    optimize_travel_moves(&layer, settings)
    
    fmt.println("✓ Travel optimization tests completed!")
}

// Test speed optimization
test_speed_optimization :: proc() {
    fmt.println("\n=== Testing Speed Optimization ===")
    
    // Create test path with corners
    path := create_test_path_with_corners()
    defer print_path_destroy(&path)
    
    fmt.printf("Test path with %d moves\n", len(path.moves))
    
    // Print speeds before optimization
    fmt.println("Speeds before optimization:")
    for i in 0..<len(path.moves) {
        move := path.moves[i]
        if move.type == .EXTRUDE {
            fmt.printf("  Move %d: %.1f mm/s\n", i, move.speed)
        }
    }
    
    // Optimize speeds
    settings := path_optimization_settings_default()
    optimize_path_speeds(&path, settings)
    
    // Print speeds after optimization
    fmt.println("Speeds after optimization:")
    for i in 0..<len(path.moves) {
        move := path.moves[i]
        if move.type == .EXTRUDE {
            fmt.printf("  Move %d: %.1f mm/s\n", i, move.speed)
        }
    }
    
    fmt.println("✓ Speed optimization tests completed!")
}

// =============================================================================
// Test Helper Functions
// =============================================================================

// Create test print job with multiple layers and paths
create_test_print_job_for_optimization :: proc() -> PrintJob {
    job := print_job_create()
    
    // Create 3 test layers
    for layer_idx in 0..<3 {
        layer := print_layer_create(u32(layer_idx), f32(layer_idx) * 0.2)
        
        // Add 3-4 paths per layer in scattered positions
        path_positions := []Point2D{
            point2d_from_mm(0.0, 0.0),
            point2d_from_mm(15.0, 5.0),
            point2d_from_mm(5.0, 15.0),
            point2d_from_mm(20.0, 20.0),
        }
        
        for i in 0..<len(path_positions) {
            if i >= 3 && layer_idx == 0 do break // Only 3 paths for first layer
            
            pos := path_positions[i]
            path := create_small_square_path(pos, .PERIMETER_OUTER, u32(layer_idx))
            print_layer_add_path(&layer, path)
        }
        
        print_job_add_layer(&job, layer)
    }
    
    return job
}

// Create test perimeter path for seam optimization
create_test_perimeter_path :: proc() -> PrintPath {
    path := print_path_create(.PERIMETER_OUTER, 0)
    path.is_closed = true
    
    // Create square perimeter with clear corners
    square_points := []Point2D{
        point2d_from_mm(0.0, 0.0),   // Bottom-left (sharp corner)
        point2d_from_mm(10.0, 0.0),  // Bottom-right
        point2d_from_mm(10.0, 10.0), // Top-right
        point2d_from_mm(0.0, 10.0),  // Top-left
        point2d_from_mm(0.0, 0.0),   // Close loop
    }
    
    for i in 0..<len(square_points)-1 {
        move := print_move_create(.EXTRUDE, square_points[i], square_points[i+1], 
                                50.0, 0.1, 0.2)
        print_path_add_move(&path, move)
    }
    
    return path
}

// Create test layer with scattered paths for travel optimization
create_test_layer_with_scattered_paths :: proc() -> PrintLayer {
    layer := print_layer_create(0, 0.2)
    
    // Create paths in non-optimal order (scattered positions)
    scattered_positions := []Point2D{
        point2d_from_mm(50.0, 50.0),  // Far corner
        point2d_from_mm(5.0, 5.0),    // Near origin
        point2d_from_mm(25.0, 75.0),  // Top middle
        point2d_from_mm(75.0, 25.0),  // Right middle
        point2d_from_mm(10.0, 40.0),  // Left middle
    }
    
    for pos in scattered_positions {
        path := create_small_square_path(pos, .PERIMETER_OUTER, 0)
        print_layer_add_path(&layer, path)
    }
    
    return layer
}

// Create test path with corners for speed optimization
create_test_path_with_corners :: proc() -> PrintPath {
    path := print_path_create(.PERIMETER_OUTER, 0)
    
    // Create zigzag pattern with sharp corners
    zigzag_points := []Point2D{
        point2d_from_mm(0.0, 0.0),
        point2d_from_mm(10.0, 0.0),   // Straight segment
        point2d_from_mm(5.0, 5.0),    // Sharp corner
        point2d_from_mm(15.0, 5.0),   // Straight segment  
        point2d_from_mm(10.0, 10.0),  // Sharp corner
        point2d_from_mm(20.0, 10.0),  // Straight segment
    }
    
    for i in 0..<len(zigzag_points)-1 {
        move := print_move_create(.EXTRUDE, zigzag_points[i], zigzag_points[i+1],
                                60.0, 0.1, 0.2)  // Start with uniform speed
        print_path_add_move(&path, move)
    }
    
    return path
}

// Create small square path at given position
create_small_square_path :: proc(center: Point2D, path_type: PrintPathType, layer_index: u32) -> PrintPath {
    path := print_path_create(path_type, layer_index)
    
    // 5x5mm square centered at position
    offset := mm_to_coord(2.5)
    
    square_points := []Point2D{
        {center.x - offset, center.y - offset},
        {center.x + offset, center.y - offset},
        {center.x + offset, center.y + offset},
        {center.x - offset, center.y + offset},
        {center.x - offset, center.y - offset}, // Close loop
    }
    
    for i in 0..<len(square_points)-1 {
        move := print_move_create(.EXTRUDE, square_points[i], square_points[i+1],
                                50.0, 0.1, f32(layer_index) * 0.2)
        print_path_add_move(&path, move)
    }
    
    path.is_closed = true
    return path
}

// Copy print path for testing
copy_print_path :: proc(original: ^PrintPath) -> PrintPath {
    copy := PrintPath{
        moves = make([dynamic]PrintMove),
        type = original.type,
        layer_index = original.layer_index,
        is_closed = original.is_closed,
        total_length = original.total_length,
    }
    
    for move in original.moves {
        append(&copy.moves, move)
    }
    
    return copy
}

// Calculate total travel distance for a layer
calculate_total_travel_distance :: proc(layer: ^PrintLayer) -> f64 {
    if len(layer.paths) <= 1 do return 0.0
    
    total_travel: f64 = 0.0
    
    for i in 0..<len(layer.paths)-1 {
        current_end := get_path_end_position(&layer.paths[i])
        next_start := get_path_start_position(&layer.paths[i+1])
        
        travel_distance := coord_to_mm(point_distance(current_end, next_start))
        total_travel += travel_distance
    }
    
    return total_travel
}

// Test complete path optimization workflow
test_complete_path_optimization_workflow :: proc() {
    fmt.println("\n=== Testing Complete Path Optimization Workflow ===")
    
    // Create comprehensive test job
    job := create_comprehensive_test_job()
    defer print_job_destroy(&job)
    
    // Run complete optimization
    fmt.println("Running complete path optimization...")
    
    settings := path_optimization_settings_default()
    analysis := optimize_print_job(&job, settings)
    
    // Print final analysis
    print_path_optimization_summary(analysis)
    
    // Validate final result
    if validate_optimized_paths(&job) {
        fmt.println("✓ Complete workflow optimization successful!")
    } else {
        fmt.println("✗ Complete workflow optimization failed validation!")
    }
}

// Create comprehensive test job with various path types
create_comprehensive_test_job :: proc() -> PrintJob {
    job := print_job_create()
    
    for layer_idx in 0..<5 {
        layer := print_layer_create(u32(layer_idx), f32(layer_idx) * 0.2)
        
        // Add outer perimeter
        outer_path := create_large_square_path(point2d_from_mm(25.0, 25.0), .PERIMETER_OUTER, u32(layer_idx))
        print_layer_add_path(&layer, outer_path)
        
        // Add inner perimeter
        inner_path := create_small_square_path(point2d_from_mm(25.0, 25.0), .PERIMETER_INNER, u32(layer_idx))
        print_layer_add_path(&layer, inner_path)
        
        // Add infill paths
        for i in 0..<3 {
            infill_pos := point2d_from_mm(15.0 + f64(i) * 10.0, 25.0)
            infill_path := create_line_path(infill_pos, .INFILL, u32(layer_idx))
            print_layer_add_path(&layer, infill_path)
        }
        
        print_job_add_layer(&job, layer)
    }
    
    return job
}

// Create large square path
create_large_square_path :: proc(center: Point2D, path_type: PrintPathType, layer_index: u32) -> PrintPath {
    path := print_path_create(path_type, layer_index)
    
    // 20x20mm square
    offset := mm_to_coord(10.0)
    
    square_points := []Point2D{
        {center.x - offset, center.y - offset},
        {center.x + offset, center.y - offset},
        {center.x + offset, center.y + offset},
        {center.x - offset, center.y + offset},
        {center.x - offset, center.y - offset},
    }
    
    for i in 0..<len(square_points)-1 {
        move := print_move_create(.EXTRUDE, square_points[i], square_points[i+1],
                                40.0, 0.15, f32(layer_index) * 0.2)
        print_path_add_move(&path, move)
    }
    
    path.is_closed = true
    return path
}

// Create line path for infill
create_line_path :: proc(start_pos: Point2D, path_type: PrintPathType, layer_index: u32) -> PrintPath {
    path := print_path_create(path_type, layer_index)
    
    end_pos := Point2D{start_pos.x, start_pos.y + mm_to_coord(15.0)}
    
    move := print_move_create(.EXTRUDE, start_pos, end_pos, 60.0, 0.1, f32(layer_index) * 0.2)
    print_path_add_move(&path, move)
    
    return path
}