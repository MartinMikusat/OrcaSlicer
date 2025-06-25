package main

import "core:fmt"
import "core:slice"
import "core:math"

// =============================================================================
// Perimeter Generation - Core Print Path Generation
//
// This module generates perimeter (wall) paths from sliced layer polygons using
// the robust polygon offsetting implemented in Phase 1. It creates multiple
// concentric walls with proper spacing and ordering for optimal print quality.
//
// Architecture: Builds directly on boolean_ops.odin polygon offsetting
// =============================================================================

// =============================================================================
// Perimeter Generation Core Functions
// =============================================================================

// Generate all perimeter paths for a single layer
generate_layer_perimeters :: proc(layer_polygons: []ExPolygon, settings: PrintSettings, 
                                 layer_index: u32, z_height: f32) -> [dynamic]PrintPath {
    paths := make([dynamic]PrintPath)
    
    for &expoly in layer_polygons {
        // Generate perimeters for this ExPolygon (contour + holes)
        perimeter_paths := generate_expolygon_perimeters(&expoly, settings, layer_index, z_height)
        
        // Add to layer paths
        for path in perimeter_paths {
            append(&paths, path)
        }
        
        // Clean up temporary paths
        delete(perimeter_paths)
    }
    
    return paths
}

// Generate perimeter paths for a single ExPolygon (contour and holes)
generate_expolygon_perimeters :: proc(expoly: ^ExPolygon, settings: PrintSettings,
                                     layer_index: u32, z_height: f32) -> [dynamic]PrintPath {
    paths := make([dynamic]PrintPath)
    
    // Generate perimeters for main contour
    contour_paths := generate_polygon_perimeters(&expoly.contour, settings, layer_index, z_height, false)
    for path in contour_paths {
        append(&paths, path)
    }
    delete(contour_paths)
    
    // Generate perimeters for holes (reversed direction)
    for &hole in expoly.holes {
        hole_paths := generate_polygon_perimeters(&hole, settings, layer_index, z_height, true)
        for path in hole_paths {
            append(&paths, path)
        }
        delete(hole_paths)
    }
    
    return paths
}

// Generate multiple concentric perimeter paths for a single polygon
generate_polygon_perimeters :: proc(polygon: ^Polygon, settings: PrintSettings,
                                   layer_index: u32, z_height: f32, is_hole: bool) -> [dynamic]PrintPath {
    paths := make([dynamic]PrintPath)
    
    if len(polygon.points) < 3 do return paths
    
    // Ensure correct orientation (CCW for contours, CW for holes)
    working_poly := polygon_create()
    defer polygon_destroy(&working_poly)
    
    // Copy polygon points
    for point in polygon.points {
        polygon_add_point(&working_poly, point)
    }
    
    // Set correct orientation
    if is_hole {
        polygon_make_cw(&working_poly)
    } else {
        polygon_make_ccw(&working_poly)
    }
    
    // Calculate wall spacing
    wall_thickness := settings.perimeter.wall_thickness
    wall_count := settings.perimeter.wall_count
    
    // Generate perimeters from outside to inside
    current_polygons := make([dynamic]Polygon)
    defer {
        for &poly in current_polygons {
            polygon_destroy(&poly)
        }
        delete(current_polygons)
    }
    
    // Start with the original polygon
    poly_copy := polygon_create()
    for point in working_poly.points {
        polygon_add_point(&poly_copy, point)
    }
    append(&current_polygons, poly_copy)
    
    // Generate each perimeter wall
    for wall_index in 0..<wall_count {
        // Determine path type and settings
        path_type: PrintPathType
        print_speed: f32
        
        if wall_index == 0 {
            // Outer wall
            path_type = .PERIMETER_OUTER
            print_speed = settings.perimeter.outer_wall_speed
        } else {
            // Inner walls
            path_type = .PERIMETER_INNER
            print_speed = settings.perimeter.inner_wall_speed
        }
        
        // Convert current polygons to print paths
        for &poly in current_polygons {
            if len(poly.points) >= 3 {
                // Calculate extrusion rate based on line width and layer height
                extrusion_rate := calculate_extrusion_rate(
                    settings.perimeter.wall_line_width,
                    settings.layer_height,
                    settings.nozzle_diameter
                )
                
                path := polygon_to_print_path(&poly, path_type, layer_index, 
                                            print_speed, f32(extrusion_rate), z_height)
                append(&paths, path)
            }
        }
        
        // Generate next inner perimeter by offsetting inward
        if wall_index < wall_count - 1 {
            offset_distance := -wall_thickness // Negative for inward offset
            config := boolean_config_default()
            
            // Create array for offsetting
            offset_input := make([]Polygon, len(current_polygons))
            defer delete(offset_input)
            
            for i in 0..<len(current_polygons) {
                offset_input[i] = current_polygons[i]
            }
            
            // Perform offset operation
            next_polygons := polygon_offset(offset_input, offset_distance, config)
            
            // Clean up current polygons
            for &poly in current_polygons {
                polygon_destroy(&poly)
            }
            clear(&current_polygons)
            
            // Move next polygons to current
            for poly in next_polygons {
                append(&current_polygons, poly)
            }
            delete(next_polygons)
        }
    }
    
    return paths
}

// =============================================================================
// Perimeter Ordering and Optimization
// =============================================================================

// Optimize perimeter printing order to minimize travel moves
optimize_perimeter_order :: proc(paths: ^[dynamic]PrintPath) {
    if len(paths) <= 1 do return
    
    // Simple nearest-neighbor ordering for perimeters
    // TODO: Implement more sophisticated ordering algorithms
    
    optimized := make([dynamic]PrintPath)
    defer delete(optimized)
    
    used := make([]bool, len(paths))
    defer delete(used)
    
    // Start with first outer perimeter
    current_idx := find_outer_perimeter_start(paths[:])
    if current_idx >= 0 {
        append(&optimized, paths[current_idx])
        used[current_idx] = true
    }
    
    // Find nearest unvisited perimeter
    for len(optimized) < len(paths) {
        nearest_idx := -1
        nearest_distance: f64 = max(f64)
        
        if len(optimized) > 0 {
            last_path := &optimized[len(optimized) - 1]
            last_end := get_path_end_point(last_path)
            
            for i in 0..<len(paths) {
                if used[i] do continue
                
                path_start := get_path_start_point(&paths[i])
                distance := coord_to_mm(point_distance(last_end, path_start))
                
                if distance < nearest_distance {
                    nearest_distance = distance
                    nearest_idx = i
                }
            }
        }
        
        if nearest_idx >= 0 {
            append(&optimized, paths[nearest_idx])
            used[nearest_idx] = true
        } else {
            break // Shouldn't happen, but safety check
        }
    }
    
    // Replace original paths with optimized order
    clear(paths)
    for path in optimized {
        append(paths, path)
    }
}

// Find the best starting outer perimeter (bottommost, then leftmost)
find_outer_perimeter_start :: proc(paths: []PrintPath) -> int {
    best_idx := -1
    best_y := max(coord_t)
    best_x := max(coord_t)
    
    for i in 0..<len(paths) {
        path := &paths[i]
        if path.type == .PERIMETER_OUTER && len(path.moves) > 0 {
            start_point := path.moves[0].start
            
            if start_point.y < best_y || (start_point.y == best_y && start_point.x < best_x) {
                best_y = start_point.y
                best_x = start_point.x
                best_idx = i
            }
        }
    }
    
    return best_idx
}

// Get start point of a print path
get_path_start_point :: proc(path: ^PrintPath) -> Point2D {
    if len(path.moves) > 0 {
        return path.moves[0].start
    }
    return {0, 0}
}

// Get end point of a print path
get_path_end_point :: proc(path: ^PrintPath) -> Point2D {
    if len(path.moves) > 0 {
        return path.moves[len(path.moves) - 1].end
    }
    return {0, 0}
}

// =============================================================================
// Extrusion Calculation
// =============================================================================

// Calculate extrusion rate for given line width, layer height, and nozzle diameter
calculate_extrusion_rate :: proc(line_width: f64, layer_height: f64, nozzle_diameter: f64) -> f64 {
    // Cross-sectional area of extruded line (approximated as rectangle with rounded ends)
    if line_width <= 0 || layer_height <= 0 do return 0.0
    
    // For typical 3D printing, extrusion width is slightly larger than nozzle diameter
    effective_width := max(line_width, nozzle_diameter * 1.05)
    
    // Cross-sectional area calculation
    // Rectangular area + semicircular ends (for rounded profile)
    rect_area := effective_width * layer_height
    if effective_width > layer_height {
        // Wide, flat extrusion
        return rect_area
    } else {
        // Narrow extrusion with more rounded profile
        radius := layer_height / 2.0
        circle_area := math.PI * radius * radius
        return min(rect_area, circle_area)
    }
}

// Calculate volumetric extrusion rate (mm³/mm of filament)
calculate_volumetric_extrusion_rate :: proc(line_width: f64, layer_height: f64, 
                                           nozzle_diameter: f64, filament_diameter: f64) -> f64 {
    extrusion_area := calculate_extrusion_rate(line_width, layer_height, nozzle_diameter)
    filament_area := math.PI * (filament_diameter / 2.0) * (filament_diameter / 2.0)
    
    if filament_area <= 0 do return 0.0
    return extrusion_area / filament_area
}

// =============================================================================
// Debug and Statistics
// =============================================================================

// Print perimeter generation statistics
print_perimeter_stats :: proc(paths: []PrintPath) {
    outer_count := 0
    inner_count := 0
    total_length: f64 = 0.0
    
    for path in paths {
        #partial switch path.type {
        case .PERIMETER_OUTER:
            outer_count += 1
        case .PERIMETER_INNER:
            inner_count += 1
        }
        total_length += path.total_length
    }
    
    fmt.printf("Perimeter Stats: %d outer, %d inner, %.2fmm total\n",
               outer_count, inner_count, total_length)
}

// Validate perimeter generation (for debugging)
validate_perimeter_generation :: proc(original_polygons: []ExPolygon, 
                                     generated_paths: []PrintPath) -> bool {
    // Basic validation: check that we have reasonable number of paths
    expected_min_paths := len(original_polygons) // At least one path per polygon
    
    if len(generated_paths) < expected_min_paths {
        fmt.printf("Warning: Generated %d paths for %d polygons\n",
                   len(generated_paths), len(original_polygons))
        return false
    }
    
    // Check that all paths have valid moves
    for path in generated_paths {
        if len(path.moves) == 0 {
            fmt.printf("Warning: Found empty path\n")
            return false
        }
        
        for move in path.moves {
            if move.start.x == move.end.x && move.start.y == move.end.y {
                fmt.printf("Warning: Found zero-length move\n")
                return false
            }
        }
    }
    
    return true
}