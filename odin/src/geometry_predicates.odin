package main

import "core:fmt"
import "core:math"

// =============================================================================
// Robust Geometric Predicates
//
// This module provides robust geometric predicates for computational geometry
// operations. These predicates are designed to handle edge cases and provide
// consistent results even with floating-point precision issues.
//
// Key features:
// - Exact orientation tests using cross products
// - Robust point-in-polygon testing with multiple algorithms
// - Line intersection with proper degenerate case handling
// - Enhanced triangle-plane intersection with comprehensive degenerate handling
// =============================================================================

// =============================================================================
// Orientation Predicate
// =============================================================================

// Exact orientation test for three points
// Returns: +1 for counter-clockwise, -1 for clockwise, 0 for collinear
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

// Alternative ray casting implementation for comparison
point_in_polygon_raycast :: proc(point: Point2D, poly: ^Polygon) -> bool {
    if len(poly.points) < 3 do return false
    
    inside := false
    n := len(poly.points)
    j := n - 1
    
    for i in 0..<n {
        p1 := poly.points[j]
        p2 := poly.points[i]
        
        if ((p1.y > point.y) != (p2.y > point.y)) &&
           (point.x < (p2.x - p1.x) * (point.y - p1.y) / (p2.y - p1.y) + p1.x) {
            inside = !inside
        }
        
        j = i
    }
    
    return inside
}

// =============================================================================
// Line Intersection
// =============================================================================

// Types for line intersection results
IntersectionType :: enum {
    NONE,     // No intersection
    POINT,    // Single point intersection
    SEGMENT,  // Overlapping segments (collinear)
}

LineIntersectionResult :: struct {
    type:     IntersectionType,
    point:    Point2D,           // Intersection point (if type == POINT)
    segment:  [2]Point2D,        // Intersection segment (if type == SEGMENT)
}

// Compute intersection of two line segments
line_segment_intersection :: proc(p1, q1, p2, q2: Point2D) -> LineIntersectionResult {
    result := LineIntersectionResult{type = .NONE}
    
    // Find orientations of the four triplets
    o1 := orientation_exact(p1, q1, p2)
    o2 := orientation_exact(p1, q1, q2)
    o3 := orientation_exact(p2, q2, p1)
    o4 := orientation_exact(p2, q2, q1)
    
    // General case: segments intersect
    if o1 != o2 && o3 != o4 {
        result.type = .POINT
        result.point = compute_intersection_point(p1, q1, p2, q2)
        return result
    }
    
    // Special cases: collinear points
    if o1 == 0 && on_segment(p1, p2, q1) ||
       o2 == 0 && on_segment(p1, q2, q1) ||
       o3 == 0 && on_segment(p2, p1, q2) ||
       o4 == 0 && on_segment(p2, q1, q2) {
        
        result.type = .SEGMENT
        // For simplicity, return the overlapping part as a segment
        // In practice, you'd compute the exact overlap
        result.segment[0] = p1
        result.segment[1] = q1
        return result
    }
    
    return result
}

// Check if point q lies on line segment pr
on_segment :: proc(p, q, r: Point2D) -> bool {
    return q.x <= max(p.x, r.x) && q.x >= min(p.x, r.x) &&
           q.y <= max(p.y, r.y) && q.y >= min(p.y, r.y)
}

// Compute actual intersection point of two lines (assumes they intersect)
compute_intersection_point :: proc(p1, q1, p2, q2: Point2D) -> Point2D {
    // Use parametric form to find intersection
    // Line 1: p1 + t * (q1 - p1)
    // Line 2: p2 + s * (q2 - p2)
    
    d1_x := q1.x - p1.x
    d1_y := q1.y - p1.y
    d2_x := q2.x - p2.x
    d2_y := q2.y - p2.y
    
    denominator := d1_x * d2_y - d1_y * d2_x
    
    if abs(denominator) < 1000 { // Small value in coord_t space (microns)
        // Lines are parallel - return midpoint
        return Point2D{(p1.x + q1.x) / 2, (p1.y + q1.y) / 2}
    }
    
    numerator_t := (p2.x - p1.x) * d2_y - (p2.y - p1.y) * d2_x
    t := f64(numerator_t) / f64(denominator)
    
    // Calculate intersection point
    intersection_x := p1.x + coord_t(f64(d1_x) * t)
    intersection_y := p1.y + coord_t(f64(d1_y) * t)
    
    return Point2D{intersection_x, intersection_y}
}

// =============================================================================
// Triangle-Plane Intersection with Enhanced Degenerate Case Handling
// =============================================================================

// Triangle face orientation relative to slicing plane (based on OrcaSlicer C++)
FaceOrientation :: enum {
    UP,         // Z component of normal is positive (upward-facing)
    DOWN,       // Z component of normal is negative (downward-facing)  
    VERTICAL,   // Z component of normal is zero (vertical face)
    DEGENERATE, // Triangle is degenerate (zero area, undefined normal)
}

// Triangle intersection classification for systematic handling
TriangleIntersectionType :: enum {
    NONE,           // No intersection (all vertices same side)
    STANDARD,       // Normal case: plane intersects 2 edges
    VERTEX_ON_PLANE,// 1 vertex on plane + 1 edge intersection
    EDGE_ON_PLANE,  // Entire edge lies on plane (2 vertices on plane)
    FACE_ON_PLANE,  // Entire triangle lies on plane (3 vertices on plane)
    DEGENERATE,     // Degenerate triangle (zero area)
}

// Enhanced result structure supporting multiple segments per triangle
TrianglePlaneIntersection :: struct {
    intersection_type: TriangleIntersectionType,
    face_orientation:  FaceOrientation,
    segments:         [dynamic]LineSegment,  // Multiple segments for complex cases
    vertex_mask:      u8,                    // Bitmask: which vertices are on plane
    triangle_id:      u32,                   // For debugging/tracking
    
    // Legacy compatibility (to be removed after migration)
    has_intersection: bool,
    segment_start:    Point2D,
    segment_end:      Point2D,
    vertex_on_plane:  bool,
    edge_on_plane:    bool,
}

// Vertex classification for systematic case handling
VertexClassification :: struct {
    vertex_mask:   u8,     // Bit i set if vertex i is on plane
    above_count:   u8,     // Number of vertices above plane
    below_count:   u8,     // Number of vertices below plane
    on_count:      u8,     // Number of vertices on plane
    distances:     [3]f32, // Signed distances from each vertex to plane
}

// Enhanced triangle-plane intersection with comprehensive degenerate case handling
triangle_plane_intersection :: proc(tri: [3]Vec3f, z_plane: f32) -> TrianglePlaneIntersection {
    result := TrianglePlaneIntersection{
        segments = make([dynamic]LineSegment),
    }
    
    // Step 1: Classify triangle face orientation
    result.face_orientation = classify_triangle_orientation(tri)
    
    // Step 2: Classify vertices relative to plane
    classification := classify_vertices_to_plane(tri, z_plane)
    result.vertex_mask = classification.vertex_mask
    
    // Step 3: Determine intersection type based on vertex classification
    result.intersection_type = determine_intersection_type(classification)
    
    // Step 4: Handle each case systematically
    switch result.intersection_type {
    case .NONE:
        // No intersection - all vertices on same side
        
    case .STANDARD:
        // Normal intersection - plane cuts through 2 edges
        handle_standard_intersection(tri, classification, &result)
        
    case .VERTEX_ON_PLANE:
        // One vertex on plane, need one edge intersection
        handle_vertex_on_plane_intersection(tri, classification, &result)
        
    case .EDGE_ON_PLANE:
        // Entire edge on plane (2 vertices on plane)
        handle_edge_on_plane_intersection(tri, classification, &result)
        
    case .FACE_ON_PLANE:
        // Entire triangle on plane (3 vertices on plane)
        handle_face_on_plane_intersection(tri, classification, &result)
        
    case .DEGENERATE:
        // Degenerate triangle
        handle_degenerate_intersection(tri, classification, &result)
    }
    
    // Set legacy compatibility fields
    result.has_intersection = len(result.segments) > 0
    result.vertex_on_plane = result.intersection_type == .VERTEX_ON_PLANE
    result.edge_on_plane = result.intersection_type == .EDGE_ON_PLANE
    
    if len(result.segments) > 0 {
        result.segment_start = result.segments[0].start
        result.segment_end = result.segments[0].end
    }
    
    return result
}

// Classify triangle face orientation based on normal vector
classify_triangle_orientation :: proc(tri: [3]Vec3f) -> FaceOrientation {
    // Check for degenerate triangle (any two vertices identical)
    if tri[0] == tri[1] || tri[1] == tri[2] || tri[0] == tri[2] {
        return .DEGENERATE
    }
    
    // Calculate triangle normal using cross product
    edge1 := vec3_sub(tri[1], tri[0])
    edge2 := vec3_sub(tri[2], tri[0])
    normal := vec3_cross(edge1, edge2)
    
    // Check for zero-area triangle (collinear vertices)
    normal_length_sq := vec3_length_squared(normal)
    if normal_length_sq < 1e-12 { // Very small threshold for f32 precision
        return .DEGENERATE
    }
    
    // Classify based on Z component of normal
    epsilon: f32 = 1e-6
    if abs(normal.z) < epsilon {
        return .VERTICAL
    } else if normal.z > 0 {
        return .UP
    } else {
        return .DOWN
    }
}

// Classify vertices relative to the slicing plane
classify_vertices_to_plane :: proc(tri: [3]Vec3f, z_plane: f32) -> VertexClassification {
    classification := VertexClassification{}
    
    epsilon: f32 = 1e-6  // Tolerance for "on plane" test
    
    for i in 0..<3 {
        distance := tri[i].z - z_plane
        classification.distances[i] = distance
        
        if abs(distance) < epsilon {
            classification.vertex_mask |= (1 << u8(i))
            classification.on_count += 1
        } else if distance > 0 {
            classification.above_count += 1
        } else {
            classification.below_count += 1
        }
    }
    
    return classification
}

// Determine intersection type from vertex classification
determine_intersection_type :: proc(classification: VertexClassification) -> TriangleIntersectionType {
    switch classification.on_count {
    case 0:
        // No vertices on plane
        if classification.above_count == 3 || classification.below_count == 3 {
            return .NONE  // All vertices same side
        } else {
            return .STANDARD  // Normal intersection
        }
    case 1:
        return .VERTEX_ON_PLANE
    case 2:
        return .EDGE_ON_PLANE
    case 3:
        return .FACE_ON_PLANE
    case:
        return .NONE  // Should never happen
    }
}

// =============================================================================
// Specialized Intersection Handlers
// =============================================================================

// Handle standard intersection case (plane cuts through 2 edges)
handle_standard_intersection :: proc(tri: [3]Vec3f, classification: VertexClassification, result: ^TrianglePlaneIntersection) {
    intersections := [2]Vec3f{}
    intersection_count := 0
    
    // Find intersections on edges where vertices are on different sides of plane
    for i in 0..<3 {
        j := (i + 1) % 3
        d1 := classification.distances[i]
        d2 := classification.distances[j]
        
        // Check if edge crosses plane (vertices on different sides)
        if (d1 > 0) != (d2 > 0) && intersection_count < 2 {
            intersections[intersection_count] = interpolate_edge_plane(tri[i], tri[j], d1, d2)
            intersection_count += 1
        }
    }
    
    if intersection_count >= 2 {
        segment := LineSegment{
            start = Point2D{mm_to_coord(f64(intersections[0].x)), mm_to_coord(f64(intersections[0].y))},
            end   = Point2D{mm_to_coord(f64(intersections[1].x)), mm_to_coord(f64(intersections[1].y))},
        }
        append(&result.segments, segment)
    }
}

// Handle vertex-on-plane case (1 vertex on plane, 1 edge intersection)
handle_vertex_on_plane_intersection :: proc(tri: [3]Vec3f, classification: VertexClassification, result: ^TrianglePlaneIntersection) {
    // Find which vertex is on the plane
    on_plane_vertex := -1
    for i in 0..<3 {
        if (classification.vertex_mask & (1 << u8(i))) != 0 {
            on_plane_vertex = i
            break
        }
    }
    
    if on_plane_vertex == -1 do return
    
    // Find intersection on the opposite edge
    i := (on_plane_vertex + 1) % 3
    j := (on_plane_vertex + 2) % 3
    
    d1 := classification.distances[i]
    d2 := classification.distances[j]
    
    // Check if the opposite edge crosses the plane
    if (d1 > 0) != (d2 > 0) {
        intersection := interpolate_edge_plane(tri[i], tri[j], d1, d2)
        
        segment := LineSegment{
            start = Point2D{mm_to_coord(f64(tri[on_plane_vertex].x)), mm_to_coord(f64(tri[on_plane_vertex].y))},
            end   = Point2D{mm_to_coord(f64(intersection.x)), mm_to_coord(f64(intersection.y))},
        }
        append(&result.segments, segment)
    }
}

// Handle edge-on-plane case (entire edge lies on plane)
handle_edge_on_plane_intersection :: proc(tri: [3]Vec3f, classification: VertexClassification, result: ^TrianglePlaneIntersection) {
    // Find the two vertices that are on the plane
    on_plane_vertices := [2]int{-1, -1}
    vertex_count := 0
    
    for i in 0..<3 {
        if (classification.vertex_mask & (1 << u8(i))) != 0 {
            on_plane_vertices[vertex_count] = i
            vertex_count += 1
            if vertex_count == 2 do break
        }
    }
    
    if vertex_count == 2 {
        // Create segment from the edge that lies on the plane
        v1 := on_plane_vertices[0]
        v2 := on_plane_vertices[1]
        
        segment := LineSegment{
            start = Point2D{mm_to_coord(f64(tri[v1].x)), mm_to_coord(f64(tri[v1].y))},
            end   = Point2D{mm_to_coord(f64(tri[v2].x)), mm_to_coord(f64(tri[v2].y))},
        }
        append(&result.segments, segment)
    }
}

// Handle face-on-plane case (entire triangle lies on plane)
handle_face_on_plane_intersection :: proc(tri: [3]Vec3f, classification: VertexClassification, result: ^TrianglePlaneIntersection) {
    // For triangles lying completely on the plane, we output all three edges
    // This creates the triangle's outline as part of the slice contour
    
    for i in 0..<3 {
        j := (i + 1) % 3
        
        segment := LineSegment{
            start = Point2D{mm_to_coord(f64(tri[i].x)), mm_to_coord(f64(tri[i].y))},
            end   = Point2D{mm_to_coord(f64(tri[j].x)), mm_to_coord(f64(tri[j].y))},
        }
        
        // Check for zero-length segments (degenerate edges)
        if segment.start != segment.end {
            append(&result.segments, segment)
        }
    }
}

// Handle degenerate triangle case
handle_degenerate_intersection :: proc(tri: [3]Vec3f, classification: VertexClassification, result: ^TrianglePlaneIntersection) {
    // For degenerate triangles, check if any vertices lie on the plane
    // and output appropriate point or line segment
    
    if classification.on_count > 0 {
        // At least one vertex is on plane - could contribute to contour
        
        if classification.on_count == 1 {
            // Single point on plane - usually not useful for slicing
            // but could be important for connectivity in some cases
        } else if classification.on_count >= 2 {
            // Line segment on plane (collinear triangle with vertices on plane)
            on_plane_vertices := make([dynamic]int)
            defer delete(on_plane_vertices)
            
            for i in 0..<3 {
                if (classification.vertex_mask & (1 << u8(i))) != 0 {
                    append(&on_plane_vertices, i)
                }
            }
            
            if len(on_plane_vertices) >= 2 {
                v1 := on_plane_vertices[0]
                v2 := on_plane_vertices[1]
                
                segment := LineSegment{
                    start = Point2D{mm_to_coord(f64(tri[v1].x)), mm_to_coord(f64(tri[v1].y))},
                    end   = Point2D{mm_to_coord(f64(tri[v2].x)), mm_to_coord(f64(tri[v2].y))},
                }
                
                if segment.start != segment.end {
                    append(&result.segments, segment)
                }
            }
        }
    }
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
// Point-Line Distance Calculations
// =============================================================================

// Calculate squared distance from point to line segment (avoids sqrt for comparisons)
point_line_distance_squared :: proc(point: Point2D, line_start, line_end: Point2D) -> coord_t {
    // Vector from line_start to line_end
    line_vec := Point2D{line_end.x - line_start.x, line_end.y - line_start.y}
    
    // Vector from line_start to point
    point_vec := Point2D{point.x - line_start.x, point.y - line_start.y}
    
    // Calculate dot products using coord_t arithmetic
    line_length_sq := line_vec.x * line_vec.x + line_vec.y * line_vec.y
    
    if line_length_sq == 0 {
        // Degenerate line (point) - return distance to that point
        return point_distance_squared(point, line_start)
    } else {
        // Project point onto line
        dot_product := point_vec.x * line_vec.x + point_vec.y * line_vec.y
        
        // Calculate parameter t (but keep in coord_t space)
        t := f64(dot_product) / f64(line_length_sq)
        
        if t < 0.0 {
            // Closest point is line_start
            return point_distance_squared(point, line_start)
        } else if t > 1.0 {
            // Closest point is line_end
            return point_distance_squared(point, line_end)
        } else {
            // Closest point is on the line segment
            
            // closest_point = line_start + t * line_vec
            closest_x := line_start.x + coord_t(f64(line_vec.x) * t)
            closest_y := line_start.y + coord_t(f64(line_vec.y) * t)
            
            closest_point := Point2D{closest_x, closest_y}
            return point_distance_squared(point, closest_point)
        }
    }
}

// Calculate exact distance from point to line segment
point_line_distance :: proc(point: Point2D, line_start, line_end: Point2D) -> coord_t {
    return coord_sqrt(point_line_distance_squared(point, line_start, line_end))
}