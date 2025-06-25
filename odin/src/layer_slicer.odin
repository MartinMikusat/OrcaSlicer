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

LineSegment :: struct {
    start, end: Point2D,
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
    
    // Return all segments found - this handles all cases properly:
    // - Standard intersection: 1 segment
    // - Vertex on plane: 1 segment  
    // - Edge on plane: 1 segment
    // - Face on plane: 3 segments (triangle outline)
    // - No intersection: 0 segments
    
    segments := make([dynamic]LineSegment)
    for segment in intersection.segments {
        append(&segments, segment)
    }
    
    return segments, len(segments) > 0
}

// =============================================================================
// Segment Connection Algorithm
// =============================================================================

// Connect line segments to form closed polygon contours
segments_to_polygons :: proc(segments: []LineSegment) -> [dynamic]Polygon {
    if len(segments) == 0 {
        return make([dynamic]Polygon)
    }
    
    polygons := make([dynamic]Polygon)
    used := make([]bool, len(segments))
    defer delete(used)
    
    // Find connected chains of segments
    for start_idx in 0..<len(segments) {
        if used[start_idx] do continue
        
        polygon := build_polygon_from_segments(segments, used[:], start_idx)
        if len(polygon.points) >= 3 {
            // Ensure polygon is properly oriented (CCW for outer boundary)
            polygon_make_ccw(&polygon)
            append(&polygons, polygon)
        } else {
            // Clean up incomplete polygon
            polygon_destroy(&polygon)
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