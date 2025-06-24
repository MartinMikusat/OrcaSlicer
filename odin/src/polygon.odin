package main

import "core:math"
import "core:slice"

// =============================================================================
// Polygon Types
// =============================================================================

// Simple polygon - closed contour of 2D points
Polygon :: struct {
    points: [dynamic]Point2D,
}

// Extended polygon - polygon with holes
ExPolygon :: struct {
    contour: Polygon,        // Outer boundary (counter-clockwise)
    holes:   [dynamic]Polygon, // Inner holes (clockwise)
}

// Polyline - open sequence of 2D points (not closed)
Polyline :: struct {
    points: [dynamic]Point2D,
}

// =============================================================================
// Polygon Creation and Management
// =============================================================================

// Create empty polygon
polygon_create :: proc() -> Polygon {
    return {points = make([dynamic]Point2D)}
}

// Destroy polygon and free memory
polygon_destroy :: proc(poly: ^Polygon) {
    delete(poly.points)
}

// Clear polygon points
polygon_clear :: proc(poly: ^Polygon) {
    clear(&poly.points)
}

// Add point to polygon
polygon_add_point :: proc(poly: ^Polygon, p: Point2D) {
    append(&poly.points, p)
}

// Create polygon from array of points
polygon_from_points :: proc(points: []Point2D) -> Polygon {
    poly := polygon_create()
    for point in points {
        append(&poly.points, point)
    }
    return poly
}

// =============================================================================
// ExPolygon Creation and Management
// =============================================================================

// Create empty ExPolygon
expolygon_create :: proc() -> ExPolygon {
    return {
        contour = polygon_create(),
        holes = make([dynamic]Polygon),
    }
}

// Destroy ExPolygon and free memory
expolygon_destroy :: proc(expoly: ^ExPolygon) {
    polygon_destroy(&expoly.contour)
    for &hole in expoly.holes {
        polygon_destroy(&hole)
    }
    delete(expoly.holes)
}

// Add hole to ExPolygon
expolygon_add_hole :: proc(expoly: ^ExPolygon, hole: Polygon) {
    append(&expoly.holes, hole)
}

// =============================================================================
// Geometric Predicates and Operations
// =============================================================================

// Test point orientation (cross product sign)
// Returns: > 0 for counter-clockwise, < 0 for clockwise, 0 for collinear
point_orientation :: proc(a, b, c: Point2D) -> coord_t {
    // Cross product: (b - a) × (c - a)
    return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
}

// Check if polygon is oriented counter-clockwise
polygon_is_ccw :: proc(poly: ^Polygon) -> bool {
    if len(poly.points) < 3 do return false
    
    // Find the bottom-most point (and leftmost if tie)
    bottom_idx := 0
    for i in 1..<len(poly.points) {
        p := poly.points[i]
        bottom := poly.points[bottom_idx]
        
        if p.y < bottom.y || (p.y == bottom.y && p.x < bottom.x) {
            bottom_idx = i
        }
    }
    
    // Check orientation at the bottom point
    prev_idx := (bottom_idx - 1 + len(poly.points)) % len(poly.points)
    next_idx := (bottom_idx + 1) % len(poly.points)
    
    return point_orientation(poly.points[prev_idx], 
                           poly.points[bottom_idx], 
                           poly.points[next_idx]) > 0
}

// Calculate polygon area (signed - positive for CCW, negative for CW)
polygon_area :: proc(poly: ^Polygon) -> f64 {
    if len(poly.points) < 3 do return 0
    
    area: coord_t = 0
    n := len(poly.points)
    
    for i in 0..<n {
        j := (i + 1) % n
        area += poly.points[i].x * poly.points[j].y
        area -= poly.points[j].x * poly.points[i].y
    }
    
    // Area is in coordinate units squared, need to convert to mm²
    // Since coordinate = mm * SCALING_FACTOR, coordinate² = mm² * SCALING_FACTOR²
    // So mm² = coordinate² / SCALING_FACTOR²
    area_mm_squared := f64(area) / (SCALING_FACTOR * SCALING_FACTOR)
    return area_mm_squared * 0.5
}

// Get absolute area
polygon_area_abs :: proc(poly: ^Polygon) -> f64 {
    return abs(polygon_area(poly))
}

// Calculate ExPolygon area (contour area minus hole areas)
expolygon_area :: proc(expoly: ^ExPolygon) -> f64 {
    area := polygon_area_abs(&expoly.contour)
    
    for &hole in expoly.holes {
        area -= polygon_area_abs(&hole)
    }
    
    return area
}

// =============================================================================
// Point-in-Polygon Tests
// =============================================================================

// Ray casting algorithm for point-in-polygon test
point_in_polygon :: proc(point: Point2D, poly: ^Polygon) -> bool {
    if len(poly.points) < 3 do return false
    
    inside := false
    n := len(poly.points)
    
    j := n - 1
    for i in 0..<n {
        pi := poly.points[i]
        pj := poly.points[j]
        
        if ((pi.y > point.y) != (pj.y > point.y)) &&
           (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
            inside = !inside
        }
        j = i
    }
    
    return inside
}

// Point-in-ExPolygon test (inside contour but not in any hole)
point_in_expolygon :: proc(point: Point2D, expoly: ^ExPolygon) -> bool {
    // Must be inside contour
    if !point_in_polygon(point, &expoly.contour) {
        return false
    }
    
    // Must not be inside any hole
    for &hole in expoly.holes {
        if point_in_polygon(point, &hole) {
            return false
        }
    }
    
    return true
}

// =============================================================================
// Polygon Utilities
// =============================================================================

// Calculate polygon bounding box
polygon_bounding_box :: proc(poly: ^Polygon) -> BoundingBox2D {
    if len(poly.points) == 0 {
        return bbox2d_empty()
    }
    
    bbox := BoundingBox2D{
        min = poly.points[0],
        max = poly.points[0],
    }
    
    for point in poly.points[1:] {
        bbox2d_include(&bbox, point)
    }
    
    return bbox
}

// Reverse polygon point order (CCW ↔ CW)
polygon_reverse :: proc(poly: ^Polygon) {
    slice.reverse(poly.points[:])
}

// Ensure polygon has correct orientation
polygon_make_ccw :: proc(poly: ^Polygon) {
    if !polygon_is_ccw(poly) {
        polygon_reverse(poly)
    }
}

polygon_make_cw :: proc(poly: ^Polygon) {
    if polygon_is_ccw(poly) {
        polygon_reverse(poly)
    }
}

// Fix ExPolygon orientation (contour CCW, holes CW)
expolygon_fix_orientation :: proc(expoly: ^ExPolygon) {
    polygon_make_ccw(&expoly.contour)
    for &hole in expoly.holes {
        polygon_make_cw(&hole)
    }
}

// =============================================================================
// Simple Polygon Operations
// =============================================================================

// Translate polygon by offset
polygon_translate :: proc(poly: ^Polygon, offset: Point2D) {
    for &point in poly.points {
        point = point2d_add(point, offset)
    }
}

// Scale polygon around origin
polygon_scale :: proc(poly: ^Polygon, factor: f64) {
    for &point in poly.points {
        point = point2d_scale(point, factor)
    }
}

// Create rectangle polygon
polygon_create_rectangle :: proc(min_x, min_y, max_x, max_y: f64) -> Polygon {
    poly := polygon_create()
    
    polygon_add_point(&poly, point2d_from_mm(min_x, min_y))
    polygon_add_point(&poly, point2d_from_mm(max_x, min_y))
    polygon_add_point(&poly, point2d_from_mm(max_x, max_y))
    polygon_add_point(&poly, point2d_from_mm(min_x, max_y))
    
    return poly
}

// Create circle polygon (approximated with line segments)
polygon_create_circle :: proc(center: Point2D, radius: f64, segments: int) -> Polygon {
    poly := polygon_create()
    
    radius_coord := mm_to_coord(radius)
    
    for i in 0..<segments {
        angle := f64(i) * 2.0 * math.PI / f64(segments)
        
        x := center.x + coord_t(f64(radius_coord) * math.cos_f64(angle))
        y := center.y + coord_t(f64(radius_coord) * math.sin_f64(angle))
        
        polygon_add_point(&poly, Point2D{x, y})
    }
    
    return poly
}