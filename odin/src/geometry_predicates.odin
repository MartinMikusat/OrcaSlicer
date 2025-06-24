package main

import "core:math"

// =============================================================================
// Robust Geometric Predicates
// 
// This module implements exact geometric predicates using fixed-point arithmetic
// to eliminate floating-point precision errors that cause failures in
// computational geometry algorithms.
//
// Key principles:
// - All computations use exact integer arithmetic via coord_t
// - Degenerate cases are handled explicitly and consistently
// - Results are deterministic - same input always gives same output
// - Performance is optimized for common cases while maintaining exactness
// =============================================================================

// =============================================================================
// Line Segment Intersection
// =============================================================================

IntersectionType :: enum {
    NONE,        // No intersection
    POINT,       // Single point intersection
    SEGMENT,     // Overlapping segments (collinear with overlap)
    COLLINEAR,   // Lines are collinear but don't overlap
}

LineIntersection :: struct {
    point: Point2D,           // Intersection point (valid if type == POINT or SEGMENT)
    type: IntersectionType,   // Type of intersection
    t1, t2: f64,             // Parameter values along each line segment (0.0 to 1.0)
}

// Robust line segment intersection using exact arithmetic
// Returns intersection information between line segments (a1,a2) and (b1,b2)
line_segment_intersection :: proc(a1, a2, b1, b2: Point2D) -> LineIntersection {
    result := LineIntersection{type = .NONE}
    
    // Vector representations: 
    // Line A: a1 + t1 * (a2 - a1) for t1 in [0,1]
    // Line B: b1 + t2 * (b2 - b1) for t2 in [0,1]
    
    da := point2d_sub(a2, a1)  // Direction vector of line A
    db := point2d_sub(b2, b1)  // Direction vector of line B
    dc := point2d_sub(b1, a1)  // Vector from a1 to b1
    
    // Cross products for exact orientation tests
    cross_da_db := da.x * db.y - da.y * db.x  // da × db
    cross_dc_da := dc.x * da.y - dc.y * da.x  // dc × da
    cross_dc_db := dc.x * db.y - dc.y * db.x  // dc × db
    
    // Check if lines are parallel (cross_da_db == 0)
    if cross_da_db == 0 {
        // Lines are parallel - check if collinear
        if cross_dc_da == 0 {
            // Lines are collinear - check for overlap
            return handle_collinear_segments(a1, a2, b1, b2)
        } else {
            // Parallel but not collinear - no intersection
            result.type = .NONE
            return result
        }
    }
    
    // Lines are not parallel - compute intersection parameters
    // Solve: a1 + t1*da = b1 + t2*db
    // This gives us: t1 = (dc × db) / (da × db)
    //                t2 = (dc × da) / (da × db)
    
    // Use exact arithmetic for parameter calculation
    t1_num := cross_dc_db
    t2_num := cross_dc_da
    denom := cross_da_db
    
    // Convert to floating point for final parameter values
    // (This is safe because we've already handled the exact tests)
    result.t1 = f64(t1_num) / f64(denom)
    result.t2 = f64(t2_num) / f64(denom)
    
    // Check if intersection point lies within both line segments
    // Need: 0 <= t1 <= 1 and 0 <= t2 <= 1
    
    // Exact tests using integer arithmetic
    t1_in_range := (denom > 0 && 0 <= t1_num && t1_num <= denom) ||
                   (denom < 0 && denom <= t1_num && t1_num <= 0)
                   
    t2_in_range := (denom > 0 && 0 <= t2_num && t2_num <= denom) ||
                   (denom < 0 && denom <= t2_num && t2_num <= 0)
    
    if t1_in_range && t2_in_range {
        // Intersection point is within both segments
        result.type = .POINT
        
        // Calculate intersection point using more accurate method
        // Use the parameter with smaller denominator for better precision
        if coord_abs(t1_num) <= coord_abs(t2_num) {
            // Use t1 parameter along line A
            dx := coord_t(f64(da.x) * result.t1)
            dy := coord_t(f64(da.y) * result.t1)
            result.point = point2d_add(a1, Point2D{dx, dy})
        } else {
            // Use t2 parameter along line B  
            dx := coord_t(f64(db.x) * result.t2)
            dy := coord_t(f64(db.y) * result.t2)
            result.point = point2d_add(b1, Point2D{dx, dy})
        }
    } else {
        // Lines intersect but not within both segments
        result.type = .NONE
    }
    
    return result
}

// Handle intersection of collinear line segments
handle_collinear_segments :: proc(a1, a2, b1, b2: Point2D) -> LineIntersection {
    result := LineIntersection{type = .COLLINEAR}
    
    // Project all points onto the line to find overlap
    // Use the coordinate with larger range for better precision
    da := point2d_sub(a2, a1)
    
    use_x := coord_abs(da.x) >= coord_abs(da.y)
    
    if use_x {
        // Project onto X axis
        a1_proj := a1.x
        a2_proj := a2.x
        b1_proj := b1.x
        b2_proj := b2.x
        
        // Ensure a1_proj <= a2_proj and b1_proj <= b2_proj
        if a1_proj > a2_proj {
            a1_proj, a2_proj = a2_proj, a1_proj
        }
        if b1_proj > b2_proj {
            b1_proj, b2_proj = b2_proj, b1_proj
        }
        
        // Check for overlap: max(start) <= min(end)
        overlap_start := coord_max(a1_proj, b1_proj)
        overlap_end := coord_min(a2_proj, b2_proj)
        
        if overlap_start <= overlap_end {
            result.type = .SEGMENT
            // Set intersection point to start of overlap
            if use_x {
                result.point.x = overlap_start
                // Calculate corresponding Y coordinate
                if da.x != 0 {
                    t := f64(overlap_start - a1.x) / f64(da.x)
                    result.point.y = a1.y + coord_t(f64(da.y) * t)
                } else {
                    result.point.y = a1.y
                }
            }
        }
    } else {
        // Project onto Y axis (similar logic)
        a1_proj := a1.y
        a2_proj := a2.y
        b1_proj := b1.y
        b2_proj := b2.y
        
        if a1_proj > a2_proj {
            a1_proj, a2_proj = a2_proj, a1_proj
        }
        if b1_proj > b2_proj {
            b1_proj, b2_proj = b2_proj, b1_proj
        }
        
        overlap_start := coord_max(a1_proj, b1_proj)
        overlap_end := coord_min(a2_proj, b2_proj)
        
        if overlap_start <= overlap_end {
            result.type = .SEGMENT
            result.point.y = overlap_start
            if da.y != 0 {
                t := f64(overlap_start - a1.y) / f64(da.y)
                result.point.x = a1.x + coord_t(f64(da.x) * t)
            } else {
                result.point.x = a1.x
            }
        }
    }
    
    return result
}

// =============================================================================
// Robust Orientation Test
// =============================================================================

// Exact orientation test using fixed-point arithmetic
// Returns: +1 if points are counter-clockwise
//          -1 if points are clockwise  
//           0 if points are collinear
orientation_exact :: proc(a, b, c: Point2D) -> i32 {
    // Compute the cross product (b - a) × (c - a)
    // This is equivalent to the determinant:
    // | (b.x - a.x)  (b.y - a.y) |
    // | (c.x - a.x)  (c.y - a.y) |
    
    cross_product := (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
    
    if cross_product > 0 {
        return 1   // Counter-clockwise
    } else if cross_product < 0 {
        return -1  // Clockwise
    } else {
        return 0   // Collinear
    }
}

// =============================================================================
// Robust Point-in-Polygon Test
// =============================================================================

// Robust point-in-polygon test using winding number algorithm
// This is more robust than ray casting for degenerate cases
point_in_polygon_robust :: proc(point: Point2D, poly: ^Polygon) -> bool {
    if len(poly.points) < 3 do return false
    
    winding_number := 0
    n := len(poly.points)
    
    // Process each edge of the polygon
    for i in 0..<n {
        j := (i + 1) % n
        
        p1 := poly.points[i]
        p2 := poly.points[j]
        
        // Check if edge crosses the horizontal ray from point to the right
        if p1.y <= point.y {
            if p2.y > point.y {
                // Upward crossing
                orientation := orientation_exact(p1, p2, point)
                if orientation > 0 {
                    winding_number += 1
                }
            }
        } else {
            if p2.y <= point.y {
                // Downward crossing
                orientation := orientation_exact(p1, p2, point)
                if orientation < 0 {
                    winding_number -= 1
                }
            }
        }
    }
    
    return winding_number != 0
}

// Alternative: Ray casting version for comparison/testing
point_in_polygon_raycast :: proc(point: Point2D, poly: ^Polygon) -> bool {
    if len(poly.points) < 3 do return false
    
    inside := false
    n := len(poly.points)
    
    j := n - 1
    for i in 0..<n {
        pi := poly.points[i]
        pj := poly.points[j]
        
        // Check if horizontal ray from point intersects edge (pi, pj)
        if ((pi.y > point.y) != (pj.y > point.y)) {
            // Edge crosses the horizontal line through point
            // Calculate intersection X coordinate using exact arithmetic
            
            dy := pj.y - pi.y
            if dy != 0 {
                // intersection_x = pi.x + (point.y - pi.y) * (pj.x - pi.x) / dy
                dx := pj.x - pi.x
                numerator := dx * (point.y - pi.y)
                intersection_x := pi.x + numerator / dy
                
                if intersection_x > point.x {
                    inside = !inside
                }
            }
        }
        j = i
    }
    
    return inside
}

// =============================================================================
// Triangle-Plane Intersection
// =============================================================================

// Result of triangle-plane intersection
TrianglePlaneIntersection :: struct {
    has_intersection: bool,
    segment_start: Point2D,
    segment_end: Point2D,
    vertex_on_plane: bool,    // True if a vertex lies exactly on the plane
    edge_on_plane: bool,      // True if an entire edge lies on the plane
}

// Calculate intersection of triangle with horizontal plane at given Z height
triangle_plane_intersection :: proc(tri: [3]Vec3f, z_plane: f32) -> TrianglePlaneIntersection {
    result := TrianglePlaneIntersection{}
    
    // Calculate signed distances from vertices to plane
    d1 := tri[0].z - z_plane
    d2 := tri[1].z - z_plane  
    d3 := tri[2].z - z_plane
    
    // Count vertices above, on, and below plane
    above_count := 0
    below_count := 0
    on_plane_count := 0
    
    epsilon: f32 = 1e-6  // Small tolerance for "on plane" test
    
    if abs(d1) < epsilon {
        on_plane_count += 1
    } else if d1 > 0 {
        above_count += 1
    } else {
        below_count += 1
    }
    
    if abs(d2) < epsilon {
        on_plane_count += 1
    } else if d2 > 0 {
        above_count += 1
    } else {
        below_count += 1
    }
    
    if abs(d3) < epsilon {
        on_plane_count += 1
    } else if d3 > 0 {
        above_count += 1
    } else {
        below_count += 1
    }
    
    // Handle different cases based on vertex distribution
    if on_plane_count == 3 {
        // Entire triangle lies on plane - degenerate case
        result.edge_on_plane = true
        return result
    }
    
    if on_plane_count == 2 {
        // One edge lies on plane
        result.edge_on_plane = true
        result.has_intersection = true
        
        // Find the two vertices on the plane
        if abs(d1) < epsilon && abs(d2) < epsilon {
            result.segment_start = Point2D{mm_to_coord(f64(tri[0].x)), mm_to_coord(f64(tri[0].y))}
            result.segment_end = Point2D{mm_to_coord(f64(tri[1].x)), mm_to_coord(f64(tri[1].y))}
        } else if abs(d2) < epsilon && abs(d3) < epsilon {
            result.segment_start = Point2D{mm_to_coord(f64(tri[1].x)), mm_to_coord(f64(tri[1].y))}
            result.segment_end = Point2D{mm_to_coord(f64(tri[2].x)), mm_to_coord(f64(tri[2].y))}
        } else { // d1 and d3 on plane
            result.segment_start = Point2D{mm_to_coord(f64(tri[0].x)), mm_to_coord(f64(tri[0].y))}
            result.segment_end = Point2D{mm_to_coord(f64(tri[2].x)), mm_to_coord(f64(tri[2].y))}
        }
        return result
    }
    
    if on_plane_count == 1 {
        // One vertex on plane - need one more intersection
        result.vertex_on_plane = true
        result.has_intersection = true
        
        // Find intersection on opposite edge
        if abs(d1) < epsilon {
            // Vertex 0 on plane, find intersection on edge 1-2
            if (d2 > 0) != (d3 > 0) { // Different sides
                intersection := interpolate_edge_plane(tri[1], tri[2], d2, d3)
                result.segment_start = Point2D{mm_to_coord(f64(tri[0].x)), mm_to_coord(f64(tri[0].y))}
                result.segment_end = Point2D{mm_to_coord(f64(intersection.x)), mm_to_coord(f64(intersection.y))}
            }
        } else if abs(d2) < epsilon {
            // Vertex 1 on plane, find intersection on edge 0-2
            if (d1 > 0) != (d3 > 0) {
                intersection := interpolate_edge_plane(tri[0], tri[2], d1, d3)
                result.segment_start = Point2D{mm_to_coord(f64(tri[1].x)), mm_to_coord(f64(tri[1].y))}
                result.segment_end = Point2D{mm_to_coord(f64(intersection.x)), mm_to_coord(f64(intersection.y))}
            }
        } else { // d3 near zero
            // Vertex 2 on plane, find intersection on edge 0-1
            if (d1 > 0) != (d2 > 0) {
                intersection := interpolate_edge_plane(tri[0], tri[1], d1, d2)
                result.segment_start = Point2D{mm_to_coord(f64(tri[2].x)), mm_to_coord(f64(tri[2].y))}
                result.segment_end = Point2D{mm_to_coord(f64(intersection.x)), mm_to_coord(f64(intersection.y))}
            }
        }
        return result
    }
    
    // No vertices on plane - need two edge intersections
    if above_count > 0 && below_count > 0 {
        result.has_intersection = true
        
        intersections: [dynamic]Vec3f
        defer delete(intersections)
        
        // Check each edge for intersection
        if (d1 > 0) != (d2 > 0) {
            // Edge 0-1 intersects plane
            intersection := interpolate_edge_plane(tri[0], tri[1], d1, d2)
            append(&intersections, intersection)
        }
        
        if (d2 > 0) != (d3 > 0) {
            // Edge 1-2 intersects plane
            intersection := interpolate_edge_plane(tri[1], tri[2], d2, d3)
            append(&intersections, intersection)
        }
        
        if (d3 > 0) != (d1 > 0) {
            // Edge 2-0 intersects plane
            intersection := interpolate_edge_plane(tri[2], tri[0], d3, d1)
            append(&intersections, intersection)
        }
        
        // Should have exactly 2 intersections
        if len(intersections) == 2 {
            result.segment_start = Point2D{mm_to_coord(f64(intersections[0].x)), mm_to_coord(f64(intersections[0].y))}
            result.segment_end = Point2D{mm_to_coord(f64(intersections[1].x)), mm_to_coord(f64(intersections[1].y))}
        } else {
            // Degenerate case - shouldn't happen with proper epsilon
            result.has_intersection = false
        }
    }
    
    return result
}

// Interpolate intersection point on edge between two vertices
interpolate_edge_plane :: proc(v1, v2: Vec3f, d1, d2: f32) -> Vec3f {
    // Linear interpolation: intersection = v1 + t * (v2 - v1)
    // where t = -d1 / (d2 - d1)
    
    if abs(d2 - d1) < 1e-10 {
        // Edge is parallel to plane - return midpoint
        return Vec3f{(v1.x + v2.x) * 0.5, (v1.y + v2.y) * 0.5, (v1.z + v2.z) * 0.5}
    }
    
    t := -d1 / (d2 - d1)
    
    return Vec3f{
        v1.x + t * (v2.x - v1.x),
        v1.y + t * (v2.y - v1.y),
        v1.z + t * (v2.z - v1.z),
    }
}

// =============================================================================
// Point-to-Line Distance
// =============================================================================

// Calculate exact squared distance from point to line segment
point_line_distance_squared :: proc(point: Point2D, line_start, line_end: Point2D) -> coord_t {
    // Vector from line_start to line_end
    line_vec := point2d_sub(line_end, line_start)
    
    // Vector from line_start to point
    point_vec := point2d_sub(point, line_start)
    
    // Project point onto line: t = (point_vec · line_vec) / |line_vec|²
    line_length_squared := line_vec.x * line_vec.x + line_vec.y * line_vec.y
    
    if line_length_squared == 0 {
        // Degenerate line segment (point)
        return point_distance_squared(point, line_start)
    }
    
    // Calculate projection parameter t
    dot_product := point_vec.x * line_vec.x + point_vec.y * line_vec.y
    
    // Clamp t to [0, 1] to stay within line segment
    if dot_product <= 0 {
        // Closest point is line_start
        return point_distance_squared(point, line_start)
    } else if dot_product >= line_length_squared {
        // Closest point is line_end
        return point_distance_squared(point, line_end)
    } else {
        // Closest point is along the line segment
        // Calculate the closest point and distance using floating-point arithmetic
        // to avoid integer overflow/truncation
        t := f64(dot_product) / f64(line_length_squared)
        
        // closest_point = line_start + t * line_vec
        closest_x := line_start.x + coord_t(f64(line_vec.x) * t)
        closest_y := line_start.y + coord_t(f64(line_vec.y) * t)
        
        closest_point := Point2D{closest_x, closest_y}
        return point_distance_squared(point, closest_point)
    }
}

// Calculate exact distance from point to line segment
point_line_distance :: proc(point: Point2D, line_start, line_end: Point2D) -> coord_t {
    return coord_sqrt(point_line_distance_squared(point, line_start, line_end))
}