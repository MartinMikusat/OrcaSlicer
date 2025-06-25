package main

import "core:fmt"
import "core:slice"
import "core:math"

// =============================================================================
// Print Path Optimization and Ordering
//
// This module optimizes print paths for better print quality and efficiency:
// - Path ordering to minimize travel time and reduce stringing
// - Seam placement for better surface quality
// - Speed optimization for corners and curves
// - Travel path optimization with retraction management
//
// Follows data-oriented design with batch processing of paths
// =============================================================================

// =============================================================================
// Path Optimization Configuration
// =============================================================================

// Path optimization settings
PathOptimizationSettings :: struct {
    // Travel optimization
    max_travel_distance:     f64,   // Maximum travel before retraction (mm)
    retraction_distance:     f64,   // Retraction distance (mm) 
    travel_speed:           f64,   // Travel speed (mm/s)
    
    // Seam placement
    seam_position:          SeamPosition,
    seam_corner_preference: f64,   // Preference for placing seams at corners (0-1)
    
    // Speed optimization
    max_acceleration:       f64,   // Maximum acceleration (mm/s²)
    junction_deviation:     f64,   // Junction deviation for speed calculation (mm)
    corner_speed_factor:    f64,   // Speed reduction factor for corners (0-1)
    
    // Print order optimization
    nearest_neighbor:       bool,  // Use nearest neighbor path ordering
    layer_start_position:   Point2D, // Preferred start position for each layer
}

// Seam position preference
SeamPosition :: enum {
    NEAREST,    // Nearest to layer start position
    ALIGNED,    // Aligned across layers (same XY position)
    RANDOM,     // Random position to hide seam
    SHARPEST,   // Sharpest corner (best for geometric shapes)
}

// Default optimization settings
path_optimization_settings_default :: proc() -> PathOptimizationSettings {
    return {
        max_travel_distance = 2.0,
        retraction_distance = 1.0,
        travel_speed = 120.0,
        
        seam_position = .SHARPEST,
        seam_corner_preference = 0.8,
        
        max_acceleration = 3000.0,
        junction_deviation = 0.05,
        corner_speed_factor = 0.6,
        
        nearest_neighbor = true,
        layer_start_position = {0, 0},
    }
}

// =============================================================================
// Path Analysis and Metrics
// =============================================================================

// Path analysis result
PathAnalysis :: struct {
    total_length:       f64,    // Total extrusion length (mm)
    total_travel:       f64,    // Total travel distance (mm)
    total_retractions:  u32,    // Number of retractions
    estimated_time:     f64,    // Estimated print time (seconds)
    path_count:         u32,    // Number of paths
    layer_count:        u32,    // Number of layers
}

// Analyze print job for optimization metrics
analyze_print_job :: proc(job: ^PrintJob) -> PathAnalysis {
    analysis := PathAnalysis{}
    
    for &layer in job.layers {
        analysis.layer_count += 1
        
        for &path in layer.paths {
            analysis.path_count += 1
            analysis.total_length += path.total_length
            
            for &move in path.moves {
                if move.type == .TRAVEL {
                    // Calculate travel distance from move
                    travel_distance := coord_to_mm(point_distance(move.start, move.end))
                    analysis.total_travel += travel_distance
                    
                    // Check if this is a retraction move (simplified check)
                    if move.extrusion_rate > 0.0 {
                        analysis.total_retractions += 1
                    }
                }
            }
        }
    }
    
    // Estimate print time (simplified)
    analysis.estimated_time = analysis.total_length / 30.0 + analysis.total_travel / 120.0 // Rough estimate
    
    return analysis
}

// =============================================================================
// Path Ordering Optimization
// =============================================================================

// Optimize layer path ordering using nearest neighbor heuristic
optimize_layer_path_order :: proc(layer: ^PrintLayer, settings: PathOptimizationSettings) {
    if len(layer.paths) <= 1 do return
    
    if !settings.nearest_neighbor do return
    
    // Create array of path indices and their start positions
    path_info := make([]PathOrderInfo, len(layer.paths))
    defer delete(path_info)
    
    for i in 0..<len(layer.paths) {
        path := &layer.paths[i]
        start_pos := get_path_start_position(path)
        
        path_info[i] = {
            index = u32(i),
            start_position = start_pos,
            visited = false,
        }
    }
    
    // Nearest neighbor algorithm
    ordered_paths := make([dynamic]PrintPath, 0, len(layer.paths))
    defer delete(ordered_paths)
    
    current_position := settings.layer_start_position
    
    for _ in 0..<len(layer.paths) {
        best_index := find_nearest_unvisited_path(path_info, current_position)
        if best_index == -1 do break
        
        path_info[best_index].visited = true
        path_copy := layer.paths[path_info[best_index].index]
        append(&ordered_paths, path_copy)
        
        // Update current position to end of selected path
        current_position = get_path_end_position(&path_copy)
    }
    
    // Replace layer paths with optimized order
    for i in 0..<len(ordered_paths) {
        layer.paths[i] = ordered_paths[i]
    }
}

// Path information for ordering
PathOrderInfo :: struct {
    index:          u32,
    start_position: Point2D,
    visited:        bool,
}

// Find nearest unvisited path to current position
find_nearest_unvisited_path :: proc(path_info: []PathOrderInfo, current_pos: Point2D) -> int {
    best_index := -1
    best_distance: coord_t = max(coord_t)
    
    for i in 0..<len(path_info) {
        if path_info[i].visited do continue
        
        distance := point_distance(current_pos, path_info[i].start_position)
        if distance < best_distance {
            best_distance = distance
            best_index = i
        }
    }
    
    return best_index
}

// Get start position of a path
get_path_start_position :: proc(path: ^PrintPath) -> Point2D {
    if len(path.moves) == 0 do return {0, 0}
    return path.moves[0].start
}

// Get end position of a path
get_path_end_position :: proc(path: ^PrintPath) -> Point2D {
    if len(path.moves) == 0 do return {0, 0}
    return path.moves[len(path.moves) - 1].end
}

// =============================================================================
// Seam Optimization
// =============================================================================

// Optimize seam placement for closed paths (perimeters)
optimize_seam_placement :: proc(path: ^PrintPath, settings: PathOptimizationSettings) {
    if !path.is_closed do return
    if len(path.moves) < 3 do return
    
    #partial switch settings.seam_position {
    case .SHARPEST:
        optimize_seam_to_sharpest_corner(path)
    case .NEAREST:
        optimize_seam_to_nearest_position(path, settings.layer_start_position)
    case .ALIGNED:
        optimize_seam_to_aligned_position(path, settings.layer_start_position)
    case .RANDOM:
        optimize_seam_to_random_position(path)
    }
}

// Find sharpest corner for seam placement
optimize_seam_to_sharpest_corner :: proc(path: ^PrintPath) {
    if len(path.moves) < 3 do return
    
    best_index := 0
    sharpest_angle: f64 = math.PI // Start with straight line (worst case)
    
    for i in 0..<len(path.moves) {
        prev_idx := (i - 1 + len(path.moves)) % len(path.moves)
        next_idx := (i + 1) % len(path.moves)
        
        // Calculate corner angle
        angle := calculate_corner_angle(path.moves[prev_idx].end, 
                                      path.moves[i].start, 
                                      path.moves[next_idx].end)
        
        if angle < sharpest_angle {
            sharpest_angle = angle
            best_index = i
        }
    }
    
    // Rotate path to start at best seam position
    if best_index != 0 {
        rotate_path_start(path, best_index)
    }
}

// Find nearest position to target for seam placement
optimize_seam_to_nearest_position :: proc(path: ^PrintPath, target: Point2D) {
    if len(path.moves) == 0 do return
    
    best_index := 0
    nearest_distance: coord_t = max(coord_t)
    
    for i in 0..<len(path.moves) {
        distance := point_distance(path.moves[i].start, target)
        if distance < nearest_distance {
            nearest_distance = distance
            best_index = i
        }
    }
    
    if best_index != 0 {
        rotate_path_start(path, best_index)
    }
}

// Align seam to consistent position (for aligned seams across layers)
optimize_seam_to_aligned_position :: proc(path: ^PrintPath, align_target: Point2D) {
    // For now, same as nearest position
    // TODO: Implement proper aligned seam tracking across layers
    optimize_seam_to_nearest_position(path, align_target)
}

// Randomize seam position
optimize_seam_to_random_position :: proc(path: ^PrintPath) {
    if len(path.moves) == 0 do return
    
    // Simple pseudo-random based on path position
    move_sum := path.moves[0].start.x + path.moves[0].start.y
    random_index := int(abs(move_sum / 1000)) % len(path.moves)
    
    if random_index != 0 {
        rotate_path_start(path, random_index)
    }
}

// Calculate corner angle at a point
calculate_corner_angle :: proc(prev: Point2D, current: Point2D, next: Point2D) -> f64 {
    // Vector from current to prev
    v1_x := coord_to_mm(prev.x - current.x)
    v1_y := coord_to_mm(prev.y - current.y)
    
    // Vector from current to next
    v2_x := coord_to_mm(next.x - current.x)
    v2_y := coord_to_mm(next.y - current.y)
    
    // Calculate angle between vectors
    dot := v1_x * v2_x + v1_y * v2_y
    len1 := math.sqrt_f64(v1_x * v1_x + v1_y * v1_y)
    len2 := math.sqrt_f64(v2_x * v2_x + v2_y * v2_y)
    
    if len1 < 1e-6 || len2 < 1e-6 do return math.PI
    
    cos_angle := dot / (len1 * len2)
    cos_angle = math.clamp(cos_angle, -1.0, 1.0)
    
    return math.acos_f64(cos_angle)
}

// Rotate path to start at specified move index
rotate_path_start :: proc(path: ^PrintPath, start_index: int) {
    if start_index == 0 || len(path.moves) == 0 do return
    
    // Create new move array starting at start_index
    new_moves := make([dynamic]PrintMove, 0, len(path.moves))
    defer {
        // Replace path moves
        delete(path.moves)
        path.moves = new_moves
    }
    
    // Copy moves starting from start_index
    for i in start_index..<len(path.moves) {
        append(&new_moves, path.moves[i])
    }
    
    // Copy remaining moves from beginning
    for i in 0..<start_index {
        append(&new_moves, path.moves[i])
    }
}

// =============================================================================
// Travel Optimization
// =============================================================================

// Optimize travel moves between paths
optimize_travel_moves :: proc(layer: ^PrintLayer, settings: PathOptimizationSettings) {
    if len(layer.paths) <= 1 do return
    
    for i in 0..<len(layer.paths)-1 {
        current_path := &layer.paths[i]
        next_path := &layer.paths[i + 1]
        
        current_end := get_path_end_position(current_path)
        next_start := get_path_start_position(next_path)
        
        // Calculate travel distance
        travel_distance := coord_to_mm(point_distance(current_end, next_start))
        
        // Add travel move with retraction if needed
        travel_move := create_travel_move(current_end, next_start, travel_distance, settings)
        print_path_add_move(current_path, travel_move)
    }
}

// Create optimized travel move
create_travel_move :: proc(start: Point2D, end: Point2D, distance: f64, settings: PathOptimizationSettings) -> PrintMove {
    needs_retraction := distance > settings.max_travel_distance
    
    return print_move_create(
        .TRAVEL,
        start,
        end,
        f32(settings.travel_speed),
        needs_retraction ? f32(settings.retraction_distance) : 0.0,
        0.0, // Z height handled elsewhere
    )
}

// =============================================================================
// Speed Optimization
// =============================================================================

// Optimize print speeds based on geometry
optimize_print_speeds :: proc(layer: ^PrintLayer, settings: PathOptimizationSettings) {
    for &path in layer.paths {
        optimize_path_speeds(&path, settings)
    }
}

// Optimize speeds for a single path
optimize_path_speeds :: proc(path: ^PrintPath, settings: PathOptimizationSettings) {
    if len(path.moves) <= 1 do return
    
    for i in 0..<len(path.moves) {
        move := &path.moves[i]
        
        if move.type != .EXTRUDE do continue
        
        // Calculate optimal speed based on geometry
        optimal_speed := calculate_optimal_speed_for_move(move, path, i, settings)
        move.speed = optimal_speed
    }
}

// Calculate optimal speed for a move based on geometry and constraints
calculate_optimal_speed_for_move :: proc(move: ^PrintMove, path: ^PrintPath, move_index: int, settings: PathOptimizationSettings) -> f32 {
    base_speed := move.speed
    
    // Check for sharp corners that need slower speeds
    if move_index > 0 && move_index < len(path.moves) - 1 {
        prev_move := &path.moves[move_index - 1]
        next_move := &path.moves[move_index + 1]
        
        // Calculate corner angle
        corner_angle := calculate_corner_angle(prev_move.start, move.start, next_move.end)
        
        // Reduce speed for sharp corners
        if corner_angle < math.PI * 0.5 { // 90 degrees
            speed_reduction := 1.0 - (math.PI * 0.5 - corner_angle) / (math.PI * 0.5) * (1.0 - settings.corner_speed_factor)
            base_speed *= f32(speed_reduction)
        }
    }
    
    // Apply acceleration limits
    // TODO: Implement proper acceleration/deceleration planning
    
    return base_speed
}

// =============================================================================
// Complete Layer Optimization
// =============================================================================

// Optimize complete layer with all optimization passes
optimize_layer :: proc(layer: ^PrintLayer, settings: PathOptimizationSettings) {
    fmt.printf("Optimizing layer %d with %d paths...\n", layer.layer_index, len(layer.paths))
    
    // 1. Optimize path ordering
    optimize_layer_path_order(layer, settings)
    
    // 2. Optimize seam placement
    for &path in layer.paths {
        optimize_seam_placement(&path, settings)
    }
    
    // 3. Optimize travel moves
    optimize_travel_moves(layer, settings)
    
    // 4. Optimize print speeds
    optimize_print_speeds(layer, settings)
    
    fmt.printf("Layer %d optimization completed\n", layer.layer_index)
}

// Optimize complete print job
optimize_print_job :: proc(job: ^PrintJob, settings: PathOptimizationSettings) -> PathAnalysis {
    fmt.printf("Optimizing print job with %d layers...\n", len(job.layers))
    
    // Analyze job before optimization
    before_analysis := analyze_print_job(job)
    
    // Optimize each layer
    for &layer in job.layers {
        optimize_layer(&layer, settings)
    }
    
    // Analyze job after optimization
    after_analysis := analyze_print_job(job)
    
    fmt.printf("Optimization completed:\n")
    fmt.printf("  Travel distance: %.2f mm -> %.2f mm (%.1f%% reduction)\n",
               before_analysis.total_travel, after_analysis.total_travel,
               (before_analysis.total_travel - after_analysis.total_travel) / before_analysis.total_travel * 100.0)
    fmt.printf("  Estimated time: %.1f s -> %.1f s (%.1f%% reduction)\n",
               before_analysis.estimated_time, after_analysis.estimated_time,
               (before_analysis.estimated_time - after_analysis.estimated_time) / before_analysis.estimated_time * 100.0)
    
    return after_analysis
}

// =============================================================================
// Path Optimization Utilities
// =============================================================================

// Print path optimization summary
print_path_optimization_summary :: proc(analysis: PathAnalysis) {
    fmt.printf("Path Optimization Summary:\n")
    fmt.printf("  Total extrusion: %.2f mm\n", analysis.total_length)
    fmt.printf("  Total travel: %.2f mm\n", analysis.total_travel)
    fmt.printf("  Retractions: %d\n", analysis.total_retractions)
    fmt.printf("  Estimated time: %.1f minutes\n", analysis.estimated_time / 60.0)
    fmt.printf("  Paths: %d across %d layers\n", analysis.path_count, analysis.layer_count)
}

// Validate optimized paths for correctness
validate_optimized_paths :: proc(job: ^PrintJob) -> bool {
    for &layer in job.layers {
        for &path in layer.paths {
            // Check path continuity
            if len(path.moves) > 1 {
                for i in 1..<len(path.moves) {
                    if path.moves[i-1].end != path.moves[i].start {
                        fmt.printf("ERROR: Path discontinuity in layer %d\n", layer.layer_index)
                        return false
                    }
                }
            }
        }
    }
    
    fmt.println("✓ Path optimization validation passed")
    return true
}