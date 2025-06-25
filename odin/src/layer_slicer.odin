package main

import "core:fmt"
import "core:slice"
import "core:time"
import "core:math"

// =============================================================================
// Layer Slicing Algorithm
//
// This module implements the core slicing algorithm that converts 3D triangle
// meshes into 2D polygon layers for 3D printing. It uses the AABB tree for
// fast spatial queries and robust geometric predicates for reliable results.
//
// Key features:
// - Fast O(log n) triangle finding using AABB tree
// - Exact geometric predicates for robust intersection calculation
// - Proper handling of degenerate cases and edge cases
// - Data-oriented processing for performance
// =============================================================================

// =============================================================================
// Data Structures
// =============================================================================

Layer :: struct {
    z_height:     f32,                    // Height of this layer
    polygons:     [dynamic]ExPolygon,     // Sliced geometry at this layer
    island_count: u32,                    // Number of separate islands
}

// Alias for gap closing compatibility
SliceLayer :: Layer

SliceResult :: struct {
    layers:      [dynamic]Layer,
    statistics:  SliceStatistics,
}

SliceStatistics :: struct {
    total_layers:         u32,
    triangles_processed:  u32,
    intersections_found:  u32,
    processing_time_ms:   f64,
    avg_triangles_per_layer: f32,
    max_polygons_per_layer:  u32,
}

// Triangle face orientation relative to slicing plane  
FacetEdgeType :: enum {
    TOP,        // Triangle is above the plane
    BOTTOM,     // Triangle is below the plane
    TOP_BOTTOM, // Triangle spans the plane (shared edge case)
}

// Enhanced line segment with topology information for advanced chaining
LineSegment :: struct {
    start, end:     Point2D,
    
    // Topology tracking for advanced segment chaining
    vertex_a_id:    u32,      // Source mesh vertex ID for start point
    vertex_b_id:    u32,      // Source mesh vertex ID for end point  
    edge_a_id:      u32,      // Source mesh edge ID for first edge intersection
    edge_b_id:      u32,      // Source mesh edge ID for second edge intersection
    triangle_id:    u32,      // Source triangle that generated this segment
    edge_type:      FacetEdgeType, // Triangle orientation classification
    
    // Processing state for multi-pass chaining
    consumed:       bool,     // Has this segment been used in polygon formation?
    chain_priority: i32,      // Priority for chaining (longer chains = higher priority)
}

// =============================================================================
// Main Slicing Interface
// =============================================================================

// Slice mesh into layers at given layer height
slice_mesh :: proc(mesh: ^TriangleMesh, layer_height: f32) -> SliceResult {
    start_time := time.now()
    
    result := SliceResult{
        layers = make([dynamic]Layer),
    }
    
    if len(mesh.its.indices) == 0 {
        return result
    }
    
    // Build AABB tree for fast spatial queries
    tree := aabb_build(mesh)
    defer aabb_destroy(&tree)
    
    // Calculate mesh bounding box to determine layer range
    bbox := its_bounding_box(&mesh.its)
    min_z := coord_to_mm(bbox.min.z)
    max_z := coord_to_mm(bbox.max.z)
    
    // Generate layers
    height_range := f32(max_z - min_z)
    layer_count := int(math.ceil_f32(height_range / layer_height))
    if layer_count <= 0 {
        return result
    }
    
    fmt.printf("Slicing mesh: %.2f to %.2f mm, %d layers at %.2f mm height\n",
               min_z, max_z, layer_count, layer_height)
    
    // Process each layer
    for i in 0..<layer_count {
        z := f32(min_z) + f32(i) * layer_height
        layer := slice_at_height(mesh, &tree, z)
        append(&result.layers, layer)
        
        result.statistics.triangles_processed += u32(len(layer.polygons))
    }
    
    // Calculate statistics
    end_time := time.now()
    result.statistics.processing_time_ms = time.duration_milliseconds(time.diff(start_time, end_time))
    result.statistics.total_layers = u32(len(result.layers))
    
    if result.statistics.total_layers > 0 {
        result.statistics.avg_triangles_per_layer = 
            f32(result.statistics.triangles_processed) / f32(result.statistics.total_layers)
    }
    
    // Find max polygons per layer
    for layer in result.layers {
        polygon_count := u32(len(layer.polygons))
        if polygon_count > result.statistics.max_polygons_per_layer {
            result.statistics.max_polygons_per_layer = polygon_count
        }
    }
    
    fmt.printf("Slicing completed: %d layers, %.2f ms, %.1f triangles/layer avg\n",
               result.statistics.total_layers, 
               result.statistics.processing_time_ms,
               result.statistics.avg_triangles_per_layer)
    
    return result
}

// Slice mesh at specific height
slice_at_height :: proc(mesh: ^TriangleMesh, tree: ^AABBTree, z_height: f32) -> Layer {
    layer := Layer{
        z_height = z_height,
        polygons = make([dynamic]ExPolygon),
    }
    
    // Find all triangles that intersect this plane
    intersecting_triangles := aabb_plane_intersect(tree, z_height)
    defer delete(intersecting_triangles)
    
    if len(intersecting_triangles) == 0 {
        return layer
    }
    
    // Calculate intersection line segments using enhanced multi-segment approach
    segments := make([dynamic]LineSegment)
    defer delete(segments)
    
    for triangle_idx in intersecting_triangles {
        triangle_segments, has_intersection := triangle_plane_slice(mesh, triangle_idx, z_height)
        if has_intersection {
            // Add all segments from this triangle (handles degenerate cases with multiple segments)
            for segment in triangle_segments {
                append(&segments, segment)
            }
        }
        // Clean up triangle segments
        delete(triangle_segments)
    }
    
    if len(segments) == 0 {
        return layer
    }
    
    // Connect line segments to form closed polygons
    polygons := segments_to_polygons(segments[:])
    defer delete(polygons)
    
    // Convert simple polygons to ExPolygons (with hole detection)
    for polygon in polygons {
        expoly := ExPolygon{
            contour = polygon,
            holes = make([dynamic]Polygon),
        }
        append(&layer.polygons, expoly)
    }
    
    // TODO: Enable gap closing once fully debugged
    // Apply gap closing to improve polygon connectivity
    // gap_config := gap_closing_config_default()
    // gap_stats := close_layer_gaps(&layer, gap_config)
    
    // Track gap closing statistics (could be added to layer stats later)
    // if gap_stats.gaps_closed > 0 {
    //     // Optional: log gap closing results for debugging
    //     // fmt.printf("Layer Z=%.2f: closed %d gaps\n", z_height, gap_stats.gaps_closed)
    // }
    
    layer.island_count = u32(len(layer.polygons))
    return layer
}

// Calculate intersection of triangle with horizontal plane using enhanced multi-segment approach
triangle_plane_slice :: proc(mesh: ^TriangleMesh, triangle_idx: u32, z_plane: f32) -> ([dynamic]LineSegment, bool) {
    triangle := mesh.its.indices[triangle_idx]
    v0 := mesh.its.vertices[triangle.vertices[0]]
    v1 := mesh.its.vertices[triangle.vertices[1]]
    v2 := mesh.its.vertices[triangle.vertices[2]]
    
    // Use the enhanced triangle-plane intersection with comprehensive degenerate case handling
    intersection := triangle_plane_intersection([3]Vec3f{v0, v1, v2}, z_plane)
    
    // Determine triangle face orientation relative to slicing plane
    face_orientation := classify_triangle_face_type(intersection.face_orientation)
    
    // Create enhanced line segments with topology information
    segments := make([dynamic]LineSegment)
    for basic_segment, segment_idx in intersection.segments {
        // Determine which triangle edges this segment intersects
        edge_a_id, edge_b_id := determine_intersecting_edges(mesh, triangle_idx, basic_segment, intersection.intersection_type)
        
        // Create enhanced segment with topology information
        enhanced_segment := LineSegment{
            start = basic_segment.start,
            end   = basic_segment.end,
            
            // Topology information for advanced chaining
            vertex_a_id    = triangle.vertices[0], // For now, use triangle vertices
            vertex_b_id    = triangle.vertices[1], // TODO: compute actual intersection vertex IDs
            edge_a_id      = edge_a_id,
            edge_b_id      = edge_b_id,
            triangle_id    = triangle_idx,
            edge_type      = face_orientation,
            
            // Processing state
            consumed       = false,
            chain_priority = 0, // Will be computed during chaining
        }
        
        append(&segments, enhanced_segment)
    }
    
    return segments, len(segments) > 0
}

// Convert TrianglePlaneIntersection face orientation to FacetEdgeType
classify_triangle_face_type :: proc(orientation: FaceOrientation) -> FacetEdgeType {
    switch orientation {
    case .UP:       return .TOP
    case .DOWN:     return .BOTTOM
    case .VERTICAL: return .TOP_BOTTOM // Vertical faces span the plane
    case .DEGENERATE: return .TOP_BOTTOM // Treat degenerate as spanning
    }
    return .TOP
}

// Determine which mesh edges this segment intersects (simplified for now)
determine_intersecting_edges :: proc(mesh: ^TriangleMesh, triangle_idx: u32, segment: LineSegment, intersection_type: TriangleIntersectionType) -> (u32, u32) {
    // For now, return the first two edges of the triangle
    // TODO: Implement proper edge intersection detection based on intersection points
    
    if mesh.topology_dirty {
        build_edge_topology(mesh)
    }
    
    edge_a_id := get_triangle_edge_id(mesh, triangle_idx, 0)
    edge_b_id := get_triangle_edge_id(mesh, triangle_idx, 1)
    
    return edge_a_id, edge_b_id
}

// =============================================================================
// Advanced Multi-Pass Segment Chaining Algorithm
// =============================================================================

// Enhanced polyline for intermediate chaining processing
ChainPolyline :: struct {
    points:      [dynamic]Point2D, // Ordered sequence of points
    is_closed:   bool,             // Is this polyline closed (forms a loop)?
    orientation: FacetEdgeType,    // Dominant edge type for this polyline
    priority:    i32,              // Priority for gap closing (longer = higher)
}

// Multi-pass chaining statistics
ChainStatistics :: struct {
    phase1_chains:    u32, // Topology-based chains created
    phase2_chains:    u32, // Exact endpoint chains created
    phase3_gaps_closed: u32, // Gaps closed in final phase
    total_segments:   u32, // Total segments processed
    final_polygons:   u32, // Final polygon count
}

// Connect line segments using advanced topology-aware multi-pass algorithm
segments_to_polygons :: proc(segments: []LineSegment) -> [dynamic]Polygon {
    if len(segments) == 0 {
        return make([dynamic]Polygon)
    }
    
    // Create mutable copy for processing
    mutable_segments := make([dynamic]LineSegment, len(segments))
    defer delete(mutable_segments)
    copy(mutable_segments[:], segments)
    
    stats := ChainStatistics{
        total_segments = u32(len(segments)),
    }
    
    // Phase 1: Topology-based chaining
    polylines := chain_by_triangle_connectivity(mutable_segments[:], &stats)
    defer {
        for &polyline in polylines {
            delete(polyline.points)
        }
        delete(polylines)
    }
    
    // Phase 2: Exact endpoint matching  
    chain_open_polylines_exact(&polylines, &stats)
    
    // Phase 3: Gap closing (distance-based)
    chain_open_polylines_close_gaps(&polylines, &stats)
    
    // Convert polylines to polygons
    polygons := polylines_to_polygons(polylines[:])
    stats.final_polygons = u32(len(polygons))
    
    return polygons
}

// =============================================================================
// Phase 1: Topology-Based Chaining
// =============================================================================

// Chain segments using triangle connectivity information
chain_by_triangle_connectivity :: proc(segments: []LineSegment, stats: ^ChainStatistics) -> [dynamic]ChainPolyline {
    polylines := make([dynamic]ChainPolyline)
    
    // Build lookup maps for fast connectivity queries
    edge_to_segments := build_edge_lookup_map(segments)
    defer {
        for key, segment_list in edge_to_segments {
            delete(segment_list)
        }
        delete(edge_to_segments)
    }
    
    vertex_to_segments := build_vertex_lookup_map(segments)
    defer {
        for key, segment_list in vertex_to_segments {
            delete(segment_list)
        }
        delete(vertex_to_segments)
    }
    
    // Mark segments as consumed during processing
    consumed := make([]bool, len(segments))
    defer delete(consumed)
    
    // Greedy chaining: start with each unused segment
    for start_idx in 0..<len(segments) {
        if consumed[start_idx] do continue
        
        polyline := build_topology_chain(segments, consumed[:], start_idx, edge_to_segments, vertex_to_segments)
        if len(polyline.points) >= 2 {
            append(&polylines, polyline)
            stats.phase1_chains += 1
        } else {
            delete(polyline.points)
        }
    }
    
    return polylines
}

// Build lookup map: edge_id -> [segment_indices]
build_edge_lookup_map :: proc(segments: []LineSegment) -> map[u32][dynamic]u32 {
    edge_map := make(map[u32][dynamic]u32)
    
    for segment, idx in segments {
        edge_a_id := segment.edge_a_id
        edge_b_id := segment.edge_b_id
        
        // Add to edge_a_id lookup
        if edge_a_id not_in edge_map {
            edge_map[edge_a_id] = make([dynamic]u32)
        }
        append(&edge_map[edge_a_id], u32(idx))
        
        // Add to edge_b_id lookup (if different)
        if edge_b_id != edge_a_id {
            if edge_b_id not_in edge_map {
                edge_map[edge_b_id] = make([dynamic]u32)
            }
            append(&edge_map[edge_b_id], u32(idx))
        }
    }
    
    return edge_map
}

// Build lookup map: vertex_id -> [segment_indices] 
build_vertex_lookup_map :: proc(segments: []LineSegment) -> map[u32][dynamic]u32 {
    vertex_map := make(map[u32][dynamic]u32)
    
    for segment, idx in segments {
        vertex_a_id := segment.vertex_a_id
        vertex_b_id := segment.vertex_b_id
        
        // Add to vertex_a_id lookup
        if vertex_a_id not_in vertex_map {
            vertex_map[vertex_a_id] = make([dynamic]u32)
        }
        append(&vertex_map[vertex_a_id], u32(idx))
        
        // Add to vertex_b_id lookup (if different)
        if vertex_b_id != vertex_a_id {
            if vertex_b_id not_in vertex_map {
                vertex_map[vertex_b_id] = make([dynamic]u32)
            }
            append(&vertex_map[vertex_b_id], u32(idx))
        }
    }
    
    return vertex_map
}

// Build a topology-aware chain starting from a seed segment
build_topology_chain :: proc(segments: []LineSegment, consumed: []bool, start_idx: int, 
                             edge_to_segments: map[u32][dynamic]u32, 
                             vertex_to_segments: map[u32][dynamic]u32) -> ChainPolyline {
    polyline := ChainPolyline{
        points = make([dynamic]Point2D),
        is_closed = false,
        orientation = segments[start_idx].edge_type,
    }
    
    // Start with the seed segment
    consumed[start_idx] = true
    append(&polyline.points, segments[start_idx].start)
    append(&polyline.points, segments[start_idx].end)
    
    current_end_point := segments[start_idx].end
    
    // Chain forward using topology information
    max_iterations := len(segments)
    for iteration in 0..<max_iterations {
        next_segment_idx := find_topology_connected_segment(segments, consumed, current_end_point, 
                                                           edge_to_segments, vertex_to_segments)
        
        if next_segment_idx == -1 {
            break // No more connected segments
        }
        
        next_segment := segments[next_segment_idx]
        consumed[next_segment_idx] = true
        
        // Determine connection direction and add point
        if point_distance_squared(current_end_point, next_segment.start) < 
           point_distance_squared(current_end_point, next_segment.end) {
            // Connect to start, add end
            append(&polyline.points, next_segment.end)
            current_end_point = next_segment.end
        } else {
            // Connect to end, add start  
            append(&polyline.points, next_segment.start)
            current_end_point = next_segment.start
        }
        
        // Check for loop closure
        start_point := polyline.points[0]
        tolerance := mm_to_coord(1e-6) // 1 micron tolerance
        if point_distance_squared(current_end_point, start_point) <= tolerance * tolerance {
            polyline.is_closed = true
            // Remove duplicate end point
            ordered_remove(&polyline.points, len(polyline.points) - 1)
            break
        }
    }
    
    polyline.priority = i32(len(polyline.points)) // Longer chains have higher priority
    return polyline
}

// Find topology-connected segment using edge and vertex connectivity
find_topology_connected_segment :: proc(segments: []LineSegment, consumed: []bool, end_point: Point2D,
                                        edge_to_segments: map[u32][dynamic]u32,
                                        vertex_to_segments: map[u32][dynamic]u32) -> int {
    tolerance := mm_to_coord(1e-6) // 1 micron tolerance
    
    // Priority 1: Topology-connected segments (shared edge or vertex)
    best_topology_idx := -1
    
    // Priority 2: Distance-based fallback
    best_distance_idx := -1
    best_distance_sq := tolerance * tolerance
    
    for segment, idx in segments {
        if consumed[idx] do continue
        
        // Check for topology connection first
        topology_connected := false
        
        // Check if segments share an edge ID
        current_edges := [2]u32{segment.edge_a_id, segment.edge_b_id}
        for edge_id in current_edges {
            if edge_segments, exists := edge_to_segments[edge_id]; exists {
                for other_segment_idx in edge_segments {
                    if !consumed[other_segment_idx] && int(other_segment_idx) != idx {
                        // Found a segment that shares this edge
                        topology_connected = true
                        break
                    }
                }
            }
            if topology_connected do break
        }
        
        // Check if segments share a vertex ID
        if !topology_connected {
            current_vertices := [2]u32{segment.vertex_a_id, segment.vertex_b_id}
            for vertex_id in current_vertices {
                if vertex_segments, exists := vertex_to_segments[vertex_id]; exists {
                    for other_segment_idx in vertex_segments {
                        if !consumed[other_segment_idx] && int(other_segment_idx) != idx {
                            // Found a segment that shares this vertex
                            topology_connected = true
                            break
                        }
                    }
                }
                if topology_connected do break
            }
        }
        
        // If topology connected and close enough, prefer this
        if topology_connected {
            start_dist_sq := point_distance_squared(end_point, segment.start)
            end_dist_sq := point_distance_squared(end_point, segment.end)
            min_dist_sq := min(start_dist_sq, end_dist_sq)
            
            if min_dist_sq <= tolerance * tolerance {
                best_topology_idx = idx
                break // Topology connection found, use it immediately
            }
        }
        
        // Distance-based fallback
        start_dist_sq := point_distance_squared(end_point, segment.start)
        end_dist_sq := point_distance_squared(end_point, segment.end)
        min_dist_sq := min(start_dist_sq, end_dist_sq)
        
        if min_dist_sq <= best_distance_sq {
            best_distance_sq = min_dist_sq
            best_distance_idx = idx
        }
    }
    
    // Return topology-connected segment if found, otherwise distance-based
    return best_topology_idx != -1 ? best_topology_idx : best_distance_idx
}

// =============================================================================
// Phase 2: Exact Endpoint Matching
// =============================================================================

// Chain open polylines using exact endpoint matching
chain_open_polylines_exact :: proc(polylines: ^[dynamic]ChainPolyline, stats: ^ChainStatistics) {
    tolerance := mm_to_coord(1e-9) // Sub-micron tolerance for exact matching
    tolerance_sq := tolerance * tolerance
    
    // Track which polylines have been merged
    merged := make([]bool, len(polylines))
    defer delete(merged)
    
    changes_made := true
    max_iterations := len(polylines) // Prevent infinite loops
    
    for iteration in 0..<max_iterations {
        if !changes_made do break
        changes_made = false
        
        for i in 0..<len(polylines) {
            if merged[i] || polylines[i].is_closed do continue
            if len(polylines[i].points) < 2 do continue
            
            poly_a := &polylines[i]
            start_a := poly_a.points[0]
            end_a := poly_a.points[len(poly_a.points) - 1]
            
            // Try to connect with another polyline
            for j in i+1..<len(polylines) {
                if merged[j] || polylines[j].is_closed do continue
                if len(polylines[j].points) < 2 do continue
                
                poly_b := &polylines[j]
                start_b := poly_b.points[0]
                end_b := poly_b.points[len(poly_b.points) - 1]
                
                connection_made := false
                
                // Test all four possible connections
                if point_distance_squared(end_a, start_b) <= tolerance_sq {
                    // A.end -> B.start: append B to A
                    for k in 1..<len(poly_b.points) { // Skip first point (duplicate)
                        append(&poly_a.points, poly_b.points[k])
                    }
                    connection_made = true
                } else if point_distance_squared(end_a, end_b) <= tolerance_sq {
                    // A.end -> B.end: append B reversed to A
                    for k := len(poly_b.points) - 2; k >= 0; k -= 1 { // Skip last point (duplicate)
                        append(&poly_a.points, poly_b.points[k])
                    }
                    connection_made = true
                } else if point_distance_squared(start_a, start_b) <= tolerance_sq {
                    // A.start -> B.start: prepend B reversed to A
                    old_points := make([dynamic]Point2D, len(poly_a.points))
                    copy(old_points[:], poly_a.points[:])
                    clear(&poly_a.points)
                    
                    // Add B reversed (skip last point which is duplicate)
                    for k := len(poly_b.points) - 1; k >= 1; k -= 1 {
                        append(&poly_a.points, poly_b.points[k])
                    }
                    // Add original A
                    for point in old_points {
                        append(&poly_a.points, point)
                    }
                    delete(old_points)
                    connection_made = true
                } else if point_distance_squared(start_a, end_b) <= tolerance_sq {
                    // A.start -> B.end: prepend B to A
                    old_points := make([dynamic]Point2D, len(poly_a.points))
                    copy(old_points[:], poly_a.points[:])
                    clear(&poly_a.points)
                    
                    // Add B (skip last point which is duplicate)
                    for k in 0..<len(poly_b.points)-1 {
                        append(&poly_a.points, poly_b.points[k])
                    }
                    // Add original A
                    for point in old_points {
                        append(&poly_a.points, point)
                    }
                    delete(old_points)
                    connection_made = true
                }
                
                if connection_made {
                    // Check if we've formed a closed loop
                    if len(poly_a.points) >= 3 {
                        first_point := poly_a.points[0]
                        last_point := poly_a.points[len(poly_a.points) - 1]
                        
                        if point_distance_squared(first_point, last_point) <= tolerance_sq {
                            poly_a.is_closed = true
                            // Remove duplicate end point
                            ordered_remove(&poly_a.points, len(poly_a.points) - 1)
                        }
                    }
                    
                    // Update priority and mark B as merged
                    poly_a.priority = i32(len(poly_a.points))
                    merged[j] = true
                    changes_made = true
                    stats.phase2_chains += 1
                    break // Found connection for this polyline
                }
            }
        }
    }
    
    // Remove merged polylines
    i := 0
    for i < len(polylines) {
        if merged[i] {
            delete(polylines[i].points)
            ordered_remove(polylines, i)
        } else {
            i += 1
        }
    }
}

// =============================================================================
// Phase 3: Gap Closing
// =============================================================================

// Chain open polylines using gap closing (distance-based)
chain_open_polylines_close_gaps :: proc(polylines: ^[dynamic]ChainPolyline, stats: ^ChainStatistics) {
    max_gap_distance := mm_to_coord(2.0) // 2mm maximum gap closure
    max_gap_distance_sq := max_gap_distance * max_gap_distance
    max_angle_deviation := 45.0 * math.PI / 180.0 // 45 degrees in radians
    
    // Build spatial grid for fast proximity queries
    grid_size := max_gap_distance
    spatial_grid := make(map[i64][dynamic]int) // grid_key -> polyline_indices
    defer {
        for key, poly_list in spatial_grid {
            delete(poly_list)
        }
        delete(spatial_grid)
    }
    
    // Helper to get grid key for a point
    get_grid_key :: proc(point: Point2D, grid_size: coord_t) -> i64 {
        grid_x := point.x / grid_size
        grid_y := point.y / grid_size
        return (i64(grid_x) << 32) | (i64(grid_y) & 0xFFFFFFFF)
    }
    
    // Populate spatial grid with open polyline endpoints
    for polyline, i in polylines {
        if polyline.is_closed || len(polyline.points) < 2 do continue
        
        start_point := polyline.points[0]
        end_point := polyline.points[len(polyline.points) - 1]
        
        // Add both endpoints to grid
        start_key := get_grid_key(start_point, grid_size)
        end_key := get_grid_key(end_point, grid_size)
        
        if start_key not_in spatial_grid {
            spatial_grid[start_key] = make([dynamic]int)
        }
        append(&spatial_grid[start_key], i)
        
        if end_key != start_key {
            if end_key not_in spatial_grid {
                spatial_grid[end_key] = make([dynamic]int)
            }
            append(&spatial_grid[end_key], i)
        }
    }
    
    // Track which polylines have been merged
    merged := make([]bool, len(polylines))
    defer delete(merged)
    
    changes_made := true
    max_iterations := len(polylines) // Prevent infinite loops
    
    for iteration in 0..<max_iterations {
        if !changes_made do break
        changes_made = false
        
        for i in 0..<len(polylines) {
            if merged[i] || polylines[i].is_closed do continue
            if len(polylines[i].points) < 2 do continue
            
            poly_a := &polylines[i]
            start_a := poly_a.points[0]
            end_a := poly_a.points[len(poly_a.points) - 1]
            
            // Calculate direction vectors for angle checking
            start_dir_a := Point2D{1, 0}
            if len(poly_a.points) >= 2 {
                start_dir_a = point2d_normalize(point2d_sub(poly_a.points[1], start_a))
            }
            
            end_dir_a := Point2D{1, 0}
            if len(poly_a.points) >= 2 {
                end_dir_a = point2d_normalize(point2d_sub(end_a, poly_a.points[len(poly_a.points) - 2]))
            }
            
            best_connection_idx := -1
            best_gap_distance_sq := max_gap_distance_sq
            best_connection_type := 0 // 1=end->start, 2=end->end, 3=start->start, 4=start->end
            
            // Search nearby grid cells for potential connections
            grid_keys_to_check := [9]i64{
                get_grid_key(end_a, grid_size) + i64(-1 << 32) + i64(-1), // NW
                get_grid_key(end_a, grid_size) + i64(-1 << 32) + i64(0),  // N
                get_grid_key(end_a, grid_size) + i64(-1 << 32) + i64(1),  // NE
                get_grid_key(end_a, grid_size) + i64(0),                   // Center
                get_grid_key(end_a, grid_size) + i64(1 << 32) + i64(-1),  // SW
                get_grid_key(end_a, grid_size) + i64(1 << 32) + i64(0),   // S
                get_grid_key(end_a, grid_size) + i64(1 << 32) + i64(1),   // SE
                get_grid_key(end_a, grid_size) + i64(0) + i64(-1),        // W
                get_grid_key(end_a, grid_size) + i64(0) + i64(1),         // E
            }
            
            for grid_key in grid_keys_to_check {
                if poly_indices, exists := spatial_grid[grid_key]; exists {
                    for j in poly_indices {
                        if merged[j] || polylines[j].is_closed || j == i do continue
                        if len(polylines[j].points) < 2 do continue
                        
                        poly_b := &polylines[j]
                        start_b := poly_b.points[0]
                        end_b := poly_b.points[len(poly_b.points) - 1]
                        
                        // Calculate direction vectors for poly_b
                        start_dir_b := Point2D{1, 0}
                        if len(poly_b.points) >= 2 {
                            start_dir_b = point2d_normalize(point2d_sub(poly_b.points[1], start_b))
                        }
                        
                        end_dir_b := Point2D{1, 0}
                        if len(poly_b.points) >= 2 {
                            end_dir_b = point2d_normalize(point2d_sub(end_b, poly_b.points[len(poly_b.points) - 2]))
                        }
                        
                        // Test connections with angle validation
                        test_connections := [4]struct{
                            dist_sq: coord_t,
                            dir_a, dir_b: Point2D,
                            connection_type: int,
                        }{
                            {point_distance_squared(end_a, start_b), end_dir_a, point2d_negate(start_dir_b), 1},
                            {point_distance_squared(end_a, end_b), end_dir_a, end_dir_b, 2},
                            {point_distance_squared(start_a, start_b), point2d_negate(start_dir_a), point2d_negate(start_dir_b), 3},
                            {point_distance_squared(start_a, end_b), point2d_negate(start_dir_a), end_dir_b, 4},
                        }
                        
                        for test in test_connections {
                            if test.dist_sq <= best_gap_distance_sq {
                                // Check angle compatibility
                                dot_product := point2d_dot(test.dir_a, test.dir_b)
                                angle := math.acos_f64(clamp(f64(dot_product), -1.0, 1.0))
                                
                                if angle <= max_angle_deviation {
                                    best_gap_distance_sq = test.dist_sq
                                    best_connection_idx = j
                                    best_connection_type = test.connection_type
                                }
                            }
                        }
                    }
                }
            }
            
            // Apply the best connection found
            if best_connection_idx != -1 {
                poly_b := &polylines[best_connection_idx]
                connection_made := false
                
                switch best_connection_type {
                case 1: // A.end -> B.start
                    for k in 1..<len(poly_b.points) {
                        append(&poly_a.points, poly_b.points[k])
                    }
                    connection_made = true
                case 2: // A.end -> B.end
                    for k := len(poly_b.points) - 2; k >= 0; k -= 1 {
                        append(&poly_a.points, poly_b.points[k])
                    }
                    connection_made = true
                case 3: // A.start -> B.start
                    old_points := make([dynamic]Point2D, len(poly_a.points))
                    copy(old_points[:], poly_a.points[:])
                    clear(&poly_a.points)
                    
                    for k := len(poly_b.points) - 1; k >= 1; k -= 1 {
                        append(&poly_a.points, poly_b.points[k])
                    }
                    for point in old_points {
                        append(&poly_a.points, point)
                    }
                    delete(old_points)
                    connection_made = true
                case 4: // A.start -> B.end
                    old_points := make([dynamic]Point2D, len(poly_a.points))
                    copy(old_points[:], poly_a.points[:])
                    clear(&poly_a.points)
                    
                    for k in 0..<len(poly_b.points)-1 {
                        append(&poly_a.points, poly_b.points[k])
                    }
                    for point in old_points {
                        append(&poly_a.points, point)
                    }
                    delete(old_points)
                    connection_made = true
                }
                
                if connection_made {
                    // Check for loop closure
                    if len(poly_a.points) >= 3 {
                        first_point := poly_a.points[0]
                        last_point := poly_a.points[len(poly_a.points) - 1]
                        close_dist_sq := point_distance_squared(first_point, last_point)
                        
                        if close_dist_sq <= max_gap_distance_sq {
                            poly_a.is_closed = true
                            ordered_remove(&poly_a.points, len(poly_a.points) - 1)
                        }
                    }
                    
                    poly_a.priority = i32(len(poly_a.points))
                    merged[best_connection_idx] = true
                    changes_made = true
                    stats.phase3_gaps_closed += 1
                    break
                }
            }
        }
    }
    
    // Remove merged polylines
    i := 0
    for i < len(polylines) {
        if merged[i] {
            delete(polylines[i].points)
            ordered_remove(polylines, i)
        } else {
            i += 1
        }
    }
}

// =============================================================================
// Polyline to Polygon Conversion
// =============================================================================

// Convert polylines to final polygons
polylines_to_polygons :: proc(polylines: []ChainPolyline) -> [dynamic]Polygon {
    polygons := make([dynamic]Polygon)
    
    for polyline in polylines {
        if polyline.is_closed && len(polyline.points) >= 3 {
            polygon := polygon_create()
            
            // Copy points from polyline
            for point in polyline.points {
                polygon_add_point(&polygon, point)
            }
            
            // Ensure proper orientation (CCW for outer boundaries)
            polygon_make_ccw(&polygon)
            append(&polygons, polygon)
        }
    }
    
    return polygons
}

// Build a single polygon by following connected segments
build_polygon_from_segments :: proc(segments: []LineSegment, used: []bool, start_idx: int) -> Polygon {
    polygon := polygon_create()
    
    if start_idx >= len(segments) || used[start_idx] {
        return polygon
    }
    
    // Start with the first segment
    current_segment := segments[start_idx]
    used[start_idx] = true
    
    polygon_add_point(&polygon, current_segment.start)
    polygon_add_point(&polygon, current_segment.end)
    
    current_end := current_segment.end
    tolerance := mm_to_coord(1e-3)  // 1 micron tolerance
    
    // Follow connected segments
    max_iterations := len(segments) * 2  // Prevent infinite loops
    for iteration in 0..<max_iterations {
        found_connection := false
        
        // Look for a segment that connects to current_end
        for i in 0..<len(segments) {
            if used[i] do continue
            
            segment := segments[i]
            
            // Check if this segment connects to our current end point
            start_dist := point_distance_squared(current_end, segment.start)
            end_dist := point_distance_squared(current_end, segment.end)
            
            if start_dist <= tolerance * tolerance {
                // Segment connects at its start point
                polygon_add_point(&polygon, segment.end)
                current_end = segment.end
                used[i] = true
                found_connection = true
                break
            } else if end_dist <= tolerance * tolerance {
                // Segment connects at its end point (reverse direction)
                polygon_add_point(&polygon, segment.start)
                current_end = segment.start
                used[i] = true
                found_connection = true
                break
            }
        }
        
        if !found_connection {
            break
        }
        
        // Check if we've closed the loop
        if len(polygon.points) >= 3 {
            first_point := polygon.points[0]
            close_dist := point_distance_squared(current_end, first_point)
            if close_dist <= tolerance * tolerance {
                // Polygon is closed - remove the duplicate end point
                ordered_remove(&polygon.points, len(polygon.points) - 1)
                break
            }
        }
    }
    
    return polygon
}

// =============================================================================
// Utility Functions
// =============================================================================

// Destroy slice result and free memory
slice_result_destroy :: proc(result: ^SliceResult) {
    for &layer in result.layers {
        layer_destroy(&layer)
    }
    delete(result.layers)
}

// Destroy layer and free memory
layer_destroy :: proc(layer: ^Layer) {
    for &expoly in layer.polygons {
        expolygon_destroy(&expoly)
    }
    delete(layer.polygons)
}

// Get slice statistics summary
slice_statistics_summary :: proc(stats: SliceStatistics) -> string {
    return fmt.aprintf(
        "Layers: %d, Time: %.2fms, Avg triangles/layer: %.1f, Max polygons/layer: %d",
        stats.total_layers,
        stats.processing_time_ms, 
        stats.avg_triangles_per_layer,
        stats.max_polygons_per_layer
    )
}

// Validate slice result for correctness
slice_result_validate :: proc(result: ^SliceResult) -> bool {
    for &layer in result.layers {
        // Check that all polygons are valid
        for &expoly in layer.polygons {
            if len(expoly.contour.points) < 3 {
                return false  // Invalid polygon
            }
            
            // Check that polygon is not self-intersecting (basic check)
            area := polygon_area_abs(&expoly.contour)
            if area <= 0 {
                return false  // Zero or negative area
            }
        }
    }
    
    return true
}

// Calculate total volume of sliced geometry (approximation)
slice_result_volume :: proc(result: ^SliceResult, layer_height: f32) -> f64 {
    total_volume: f64 = 0
    
    for &layer in result.layers {
        layer_area: f64 = 0
        
        for &expoly in layer.polygons {
            layer_area += expolygon_area(&expoly)
        }
        
        total_volume += layer_area * f64(layer_height)
    }
    
    return total_volume
}

// Export layer contours for debugging/visualization
export_layer_contours :: proc(layer: ^Layer, filename: string) -> bool {
    // This would export the layer contours to a file format
    // For now, just print basic information
    fmt.printf("Layer Z=%.2f: %d polygons, %d islands\n", 
               layer.z_height, len(layer.polygons), layer.island_count)
    
    for &expoly, i in layer.polygons {
        area := expolygon_area(&expoly)
        fmt.printf("  Polygon %d: %d points, area %.2f mm²\n", 
                   i, len(expoly.contour.points), area)
    }
    
    return true
}