package main

import "core:slice"
import "core:fmt"
import "core:math"

// =============================================================================
// Gap Closing Algorithm
//
// This module implements gap closing for polygon chains during slicing.
// When slicing 3D meshes, floating-point precision and mesh topology issues
// can leave small gaps between polygon segments that should connect.
//
// The algorithm:
// 1. Identifies open polygon endpoints
// 2. Builds spatial index for fast proximity queries
// 3. Finds candidate gap connections within max_gap_distance
// 4. Scores gaps by distance and angle deviation
// 5. Connects best candidate pairs and merges polygons
//
// Data-oriented design: operates on arrays of endpoints and connections
// rather than individual polygon objects for cache efficiency.
// =============================================================================

// Configuration for gap closing behavior
GapClosingConfig :: struct {
    max_gap_distance:    f64,     // Maximum gap to close (default: 2.0mm)
    max_angle_deviation: f64,     // Maximum angle deviation (default: 45°)
    enable_debug:        bool,    // Enable debug output
}

// Default gap closing configuration
gap_closing_config_default :: proc() -> GapClosingConfig {
    return GapClosingConfig{
        max_gap_distance    = 2.0,    // 2mm maximum gap
        max_angle_deviation = 45.0,   // 45 degree maximum angle
        enable_debug        = false,
    }
}

// Endpoint information for gap detection
PolygonEndpoint :: struct {
    point:         Point2D,      // Endpoint coordinate
    polygon_idx:   u32,          // Index into polygon array
    is_start:      bool,         // True if start point, false if end point
    direction:     Vec2f,        // Normalized direction vector at endpoint
    used:          bool,         // Whether this endpoint has been connected
}

// Gap connection candidate
GapCandidate :: struct {
    endpoint_a:    u32,          // Index of first endpoint
    endpoint_b:    u32,          // Index of second endpoint
    distance:      f64,          // Gap distance in mm
    angle_cost:    f64,          // Angle deviation cost [0,1]
    total_cost:    f64,          // Combined cost for ranking
}

// Gap closing statistics
GapClosingStats :: struct {
    total_gaps_found:     u32,
    gaps_closed:          u32,
    gaps_too_far:         u32,
    gaps_bad_angle:       u32,
    avg_gap_distance:     f64,
    max_gap_distance:     f64,
}

// =============================================================================
// Gap Detection
// =============================================================================

// Find all open polygon endpoints in a layer
find_polygon_endpoints :: proc(polygons: []Polygon) -> [dynamic]PolygonEndpoint {
    endpoints := make([dynamic]PolygonEndpoint)
    
    for &polygon, poly_idx in polygons {
        if len(polygon.points) < 2 do continue
        
        // Check if polygon is closed
        start_point := polygon.points[0]
        end_point := polygon.points[len(polygon.points) - 1]
        
        gap_distance := point_distance(start_point, end_point)
        gap_distance_mm := coord_to_mm(gap_distance)
        
        // Debug output (only if enabled and requested)
        // if len(endpoints) == 0 {  // Only on first polygon to avoid spam
        //     fmt.printf("    Polygon %d: start=(%.3f,%.3f), end=(%.3f,%.3f), gap=%.3fmm\n",
        //                poly_idx,
        //                coord_to_mm(start_point.x), coord_to_mm(start_point.y),
        //                coord_to_mm(end_point.x), coord_to_mm(end_point.y),
        //                gap_distance_mm)
        // }
        
        // If gap is larger than tolerance, consider it open
        if gap_distance_mm > 0.001 {  // 1 micron tolerance
            // Calculate direction vectors at endpoints
            start_dir := calculate_endpoint_direction(&polygon, true)
            end_dir := calculate_endpoint_direction(&polygon, false)
            
            // Add start endpoint
            append(&endpoints, PolygonEndpoint{
                point       = start_point,
                polygon_idx = u32(poly_idx),
                is_start    = true,
                direction   = start_dir,
                used        = false,
            })
            
            // Add end endpoint
            append(&endpoints, PolygonEndpoint{
                point       = end_point,
                polygon_idx = u32(poly_idx),
                is_start    = false,
                direction   = end_dir,
                used        = false,
            })
        }
    }
    
    return endpoints
}

// Calculate normalized direction vector at polygon endpoint
calculate_endpoint_direction :: proc(polygon: ^Polygon, is_start: bool) -> Vec2f {
    if len(polygon.points) < 2 do return {1.0, 0.0}
    
    if is_start {
        // Direction from first to second point
        p1 := polygon.points[0]
        p2 := polygon.points[1]
        return point2d_direction_normalized(p1, p2)
    } else {
        // Direction from second-to-last to last point
        p1 := polygon.points[len(polygon.points) - 2]
        p2 := polygon.points[len(polygon.points) - 1]
        return point2d_direction_normalized(p1, p2)
    }
}

// Convert Point2D direction to normalized Vec2f
point2d_direction_normalized :: proc(p1, p2: Point2D) -> Vec2f {
    dx := coord_to_mm(p2.x - p1.x)
    dy := coord_to_mm(p2.y - p1.y)
    
    length := math.sqrt_f64(dx*dx + dy*dy)
    if length == 0 do return {1.0, 0.0}
    
    return {f32(dx / length), f32(dy / length)}
}

// =============================================================================
// Spatial Indexing for Gap Detection
// =============================================================================

// Simple spatial grid for fast endpoint proximity queries
EndpointGrid :: struct {
    grid_size:    f64,           // Cell size in mm
    bounds:       BoundingBox2D, // Grid bounds
    cells:        [dynamic][dynamic]u32, // Grid cells containing endpoint indices
    grid_width:   u32,
    grid_height:  u32,
}

// Build spatial grid for endpoint queries
build_endpoint_grid :: proc(endpoints: []PolygonEndpoint, max_gap_distance: f64) -> EndpointGrid {
    if len(endpoints) == 0 {
        return EndpointGrid{}
    }
    
    // Calculate bounding box of all endpoints
    bounds := BoundingBox2D{
        min = endpoints[0].point,
        max = endpoints[0].point,
    }
    
    for endpoint in endpoints[1:] {
        bbox2d_include(&bounds, endpoint.point)
    }
    
    // Expand bounds by max gap distance
    gap_coord := mm_to_coord(max_gap_distance)
    bounds.min.x -= gap_coord
    bounds.min.y -= gap_coord
    bounds.max.x += gap_coord
    bounds.max.y += gap_coord
    
    // Use grid cell size = max_gap_distance for optimal performance
    grid_size := max_gap_distance
    
    width_mm := coord_to_mm(bounds.max.x - bounds.min.x)
    height_mm := coord_to_mm(bounds.max.y - bounds.min.y)
    
    grid_width := u32(math.ceil_f64(width_mm / grid_size)) + 1
    grid_height := u32(math.ceil_f64(height_mm / grid_size)) + 1
    
    grid := EndpointGrid{
        grid_size   = grid_size,
        bounds      = bounds,
        grid_width  = grid_width,
        grid_height = grid_height,
        cells       = make([dynamic][dynamic]u32, grid_width * grid_height),
    }
    
    // Populate grid cells
    for endpoint, idx in endpoints {
        cell_x, cell_y := endpoint_to_grid_cell(&grid, endpoint.point)
        cell_index := cell_y * grid_width + cell_x
        
        if int(cell_index) < len(grid.cells) {
            append(&grid.cells[cell_index], u32(idx))
        }
    }
    
    return grid
}

// Convert endpoint position to grid cell coordinates
endpoint_to_grid_cell :: proc(grid: ^EndpointGrid, point: Point2D) -> (u32, u32) {
    x_mm := coord_to_mm(point.x - grid.bounds.min.x)
    y_mm := coord_to_mm(point.y - grid.bounds.min.y)
    
    cell_x := u32(math.floor_f64(x_mm / grid.grid_size))
    cell_y := u32(math.floor_f64(y_mm / grid.grid_size))
    
    cell_x = min(cell_x, grid.grid_width - 1)
    cell_y = min(cell_y, grid.grid_height - 1)
    
    return cell_x, cell_y
}

// Find endpoint candidates within max_gap_distance
find_gap_candidates :: proc(endpoints: []PolygonEndpoint, grid: ^EndpointGrid, 
                           config: GapClosingConfig) -> [dynamic]GapCandidate {
    candidates := make([dynamic]GapCandidate)
    
    for endpoint_a, idx_a in endpoints {
        if endpoint_a.used do continue
        
        // Search neighboring grid cells
        nearby_endpoints := query_nearby_endpoints(grid, endpoint_a.point, config.max_gap_distance)
        defer delete(nearby_endpoints)
        
        for endpoint_b_idx in nearby_endpoints {
            idx_b := int(endpoint_b_idx)
            if idx_b <= int(idx_a) do continue  // Avoid duplicate pairs
            
            endpoint_b := endpoints[idx_b]
            if endpoint_b.used do continue
            if endpoint_b.polygon_idx == endpoint_a.polygon_idx do continue  // Same polygon
            
            // Calculate gap distance
            distance_coord := point_distance(endpoint_a.point, endpoint_b.point)
            distance_mm := coord_to_mm(distance_coord)
            
            if distance_mm > config.max_gap_distance do continue
            
            // Calculate angle cost
            angle_cost := calculate_angle_cost(endpoint_a, endpoint_b, config.max_angle_deviation)
            if angle_cost > 1.0 do continue  // Exceeds max angle deviation
            
            // Combined cost (distance normalized + angle cost)
            distance_cost := distance_mm / config.max_gap_distance
            total_cost := 0.6 * distance_cost + 0.4 * angle_cost
            
            append(&candidates, GapCandidate{
                endpoint_a = u32(idx_a),
                endpoint_b = u32(idx_b),
                distance   = distance_mm,
                angle_cost = angle_cost,
                total_cost = total_cost,
            })
        }
    }
    
    // Sort candidates by total cost (best first)
    slice.sort_by(candidates[:], proc(a, b: GapCandidate) -> bool {
        return a.total_cost < b.total_cost
    })
    
    return candidates
}

// Query endpoints within distance of a point
query_nearby_endpoints :: proc(grid: ^EndpointGrid, point: Point2D, max_distance: f64) -> [dynamic]u32 {
    nearby := make([dynamic]u32)
    
    center_x, center_y := endpoint_to_grid_cell(grid, point)
    
    // Calculate search radius in grid cells
    search_radius := u32(math.ceil_f64(max_distance / grid.grid_size))
    
    // Search surrounding cells
    start_x := center_x - min(center_x, search_radius)
    end_x := min(center_x + search_radius + 1, grid.grid_width)
    start_y := center_y - min(center_y, search_radius)
    end_y := min(center_y + search_radius + 1, grid.grid_height)
    
    for y in start_y..<end_y {
        for x in start_x..<end_x {
            cell_index := y * grid.grid_width + x
            if int(cell_index) < len(grid.cells) {
                for endpoint_idx in grid.cells[cell_index] {
                    append(&nearby, endpoint_idx)
                }
            }
        }
    }
    
    return nearby
}

// =============================================================================
// Gap Quality Metrics
// =============================================================================

// Calculate angle deviation cost between two endpoints
calculate_angle_cost :: proc(endpoint_a, endpoint_b: PolygonEndpoint, max_angle_degrees: f64) -> f64 {
    // Calculate gap direction vector
    gap_direction := point2d_direction_normalized(endpoint_a.point, endpoint_b.point)
    
    // Calculate angle between gap direction and endpoint directions
    // Both directions should align with the gap direction for a good connection
    
    dir_a := endpoint_a.direction
    dir_b := endpoint_b.direction
    
    angle_a := vec2f_angle_between(dir_a, gap_direction)
    angle_b := vec2f_angle_between(dir_b, gap_direction)
    
    angle_a_deg := angle_a * 180.0 / math.PI
    angle_b_deg := angle_b * 180.0 / math.PI
    
    // Use worst angle deviation
    max_angle_rad := angle_a > angle_b ? angle_a : angle_b
    max_angle_deg := max_angle_rad * 180.0 / math.PI
    
    if max_angle_deg > max_angle_degrees {
        return 2.0  // Exceeds limit
    }
    
    // Normalize to [0,1] range
    return max_angle_deg / max_angle_degrees
}

// Calculate angle between two 2D vectors
vec2f_angle_between :: proc(a, b: Vec2f) -> f64 {
    dot_product := f64(a.x * b.x + a.y * b.y)
    
    // Clamp to avoid numerical errors with acos
    if dot_product < -1.0 do dot_product = -1.0
    if dot_product > 1.0 do dot_product = 1.0
    
    return math.acos_f64(dot_product)
}

// Negate a 2D vector
vec2f_negate :: proc(v: Vec2f) -> Vec2f {
    return {-v.x, -v.y}
}

// =============================================================================
// Gap Connection Implementation
// =============================================================================

// Close gaps between polygons using best candidates
close_polygon_gaps :: proc(polygons: ^[dynamic]Polygon, config: GapClosingConfig) -> GapClosingStats {
    stats := GapClosingStats{}
    
    if len(polygons) == 0 do return stats
    
    // Find all open endpoints
    endpoints := find_polygon_endpoints(polygons[:])
    defer delete(endpoints)
    
    if len(endpoints) == 0 do return stats
    
    // Build spatial index
    grid := build_endpoint_grid(endpoints[:], config.max_gap_distance)
    defer {
        for &cell in grid.cells {
            delete(cell)
        }
        delete(grid.cells)
    }
    
    // Find gap candidates
    candidates := find_gap_candidates(endpoints[:], &grid, config)
    defer delete(candidates)
    
    stats.total_gaps_found = u32(len(candidates))
    
    if config.enable_debug {
        fmt.printf("Gap closing: found %d endpoints, %d candidates\n", len(endpoints), len(candidates))
    }
    
    // Process candidates in order of quality
    merged_polygons := make(map[u32]u32)  // Maps old polygon index to new merged index
    defer delete(merged_polygons)
    
    for candidate in candidates {
        endpoint_a := &endpoints[candidate.endpoint_a]
        endpoint_b := &endpoints[candidate.endpoint_b]
        
        // Skip if endpoints already used
        if endpoint_a.used || endpoint_b.used do continue
        
        // Apply quality filters
        if candidate.distance > config.max_gap_distance {
            stats.gaps_too_far += 1
            continue
        }
        
        if candidate.angle_cost > 1.0 {
            stats.gaps_bad_angle += 1
            continue
        }
        
        // Connect the gap
        success := connect_polygon_gap(polygons, endpoint_a, endpoint_b, &merged_polygons)
        if success {
            endpoint_a.used = true
            endpoint_b.used = true
            stats.gaps_closed += 1
            
            stats.avg_gap_distance = (stats.avg_gap_distance * f64(stats.gaps_closed - 1) + candidate.distance) / f64(stats.gaps_closed)
            stats.max_gap_distance = max(stats.max_gap_distance, candidate.distance)
            
            if config.enable_debug {
                fmt.printf("  Closed gap %.3fmm between polygons %d and %d\n", 
                          candidate.distance, endpoint_a.polygon_idx, endpoint_b.polygon_idx)
            }
        }
    }
    
    // Remove merged polygons (marked as empty)
    remove_empty_polygons(polygons)
    
    if config.enable_debug {
        fmt.printf("Gap closing complete: %d/%d gaps closed\n", stats.gaps_closed, stats.total_gaps_found)
    }
    
    return stats
}

// Connect two polygon endpoints by merging the polygons
connect_polygon_gap :: proc(polygons: ^[dynamic]Polygon, endpoint_a, endpoint_b: ^PolygonEndpoint, 
                           merged_polygons: ^map[u32]u32) -> bool {
    
    poly_a_idx := int(endpoint_a.polygon_idx)
    poly_b_idx := int(endpoint_b.polygon_idx)
    
    if poly_a_idx >= len(polygons) || poly_b_idx >= len(polygons) do return false
    
    poly_a := &polygons[poly_a_idx]
    poly_b := &polygons[poly_b_idx]
    
    if len(poly_a.points) == 0 || len(poly_b.points) == 0 do return false
    
    // Create merged polygon
    merged := Polygon{}
    reserve(&merged.points, len(poly_a.points) + len(poly_b.points) + 2)
    
    // Determine connection order based on endpoints
    if endpoint_a.is_start && endpoint_b.is_start {
        // Connect start of A to start of B: reverse A + B
        append_polygon_reversed(&merged, poly_a)
        append_polygon_forward(&merged, poly_b)
    } else if endpoint_a.is_start && !endpoint_b.is_start {
        // Connect start of A to end of B: B + A
        append_polygon_forward(&merged, poly_b)
        append_polygon_forward(&merged, poly_a)
    } else if !endpoint_a.is_start && endpoint_b.is_start {
        // Connect end of A to start of B: A + B
        append_polygon_forward(&merged, poly_a)
        append_polygon_forward(&merged, poly_b)
    } else {
        // Connect end of A to end of B: A + reverse B
        append_polygon_forward(&merged, poly_a)
        append_polygon_reversed(&merged, poly_b)
    }
    
    // Replace polygon A with merged result
    polygon_destroy(poly_a)
    polygons[poly_a_idx] = merged
    
    // Mark polygon B as empty (will be removed later)
    polygon_destroy(poly_b)
    polygons[poly_b_idx] = Polygon{}
    
    // Track the merge
    merged_polygons[endpoint_b.polygon_idx] = endpoint_a.polygon_idx
    
    return true
}

// Append polygon points in forward order
append_polygon_forward :: proc(dest: ^Polygon, src: ^Polygon) {
    for point in src.points {
        append(&dest.points, point)
    }
}

// Append polygon points in reverse order
append_polygon_reversed :: proc(dest: ^Polygon, src: ^Polygon) {
    for i := len(src.points) - 1; i >= 0; i -= 1 {
        append(&dest.points, src.points[i])
    }
}

// Remove empty polygons from the array
remove_empty_polygons :: proc(polygons: ^[dynamic]Polygon) {
    write_idx := 0
    
    for read_idx in 0..<len(polygons) {
        if len(polygons[read_idx].points) > 0 {
            if write_idx != read_idx {
                polygons[write_idx] = polygons[read_idx]
            }
            write_idx += 1
        }
    }
    
    // Resize array to remove empty slots
    resize(polygons, write_idx)
}

// =============================================================================
// Integration with Layer Slicer
// =============================================================================

// Close gaps in a slice layer
close_layer_gaps :: proc(layer: ^SliceLayer, config: GapClosingConfig) -> GapClosingStats {
    if len(layer.polygons) == 0 do return GapClosingStats{}
    
    // Extract polygons as simple arrays for gap closing
    simple_polygons := make([dynamic]Polygon)
    defer {
        for &poly in simple_polygons {
            polygon_destroy(&poly)
        }
        delete(simple_polygons)
    }
    
    for &expoly in layer.polygons {
        // Convert ExPolygon contour to simple Polygon
        simple_poly := Polygon{}
        reserve(&simple_poly.points, len(expoly.contour.points))
        
        for point in expoly.contour.points {
            append(&simple_poly.points, point)
        }
        
        append(&simple_polygons, simple_poly)
    }
    
    // Close gaps
    stats := close_polygon_gaps(&simple_polygons, config)
    
    // Convert back to ExPolygons (simplified - assumes no holes)
    clear(&layer.polygons)
    for &poly in simple_polygons {
        if len(poly.points) >= 3 {
            expoly := ExPolygon{
                contour = poly,  // Take ownership
                holes   = make([dynamic]Polygon),
            }
            append(&layer.polygons, expoly)
        }
    }
    
    return stats
}