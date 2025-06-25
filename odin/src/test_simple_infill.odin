package main

import "core:fmt"

// Simple infill test that bypasses complex clipping
test_simple_infill :: proc() {
    fmt.println("=== Testing Simple Infill Generation ===")
    
    // Create simple square region for infill
    square := polygon_create()
    defer polygon_destroy(&square)
    
    // 8x8mm square to ensure space after wall offset
    polygon_add_point(&square, point2d_from_mm(1, 1))
    polygon_add_point(&square, point2d_from_mm(9, 1)) 
    polygon_add_point(&square, point2d_from_mm(9, 9))
    polygon_add_point(&square, point2d_from_mm(1, 9))
    polygon_make_ccw(&square)
    
    // Test point-in-polygon for center point
    center := point2d_from_mm(5, 5)
    inside := point_in_polygon(center, &square)
    fmt.printf("Center point (5,5) inside square: %v\n", inside)
    
    // Create simple horizontal line across square
    line := Polyline{points = make([dynamic]Point2D)}
    defer delete(line.points)
    
    append(&line.points, point2d_from_mm(0, 5))  // Start outside
    append(&line.points, point2d_from_mm(10, 5)) // End outside
    
    fmt.printf("Test line: (%.1f,%.1f) to (%.1f,%.1f)\n",
               coord_to_mm(line.points[0].x), coord_to_mm(line.points[0].y),
               coord_to_mm(line.points[1].x), coord_to_mm(line.points[1].y))
    
    // Find intersections manually 
    intersections := find_line_polygon_intersections(line.points[0], line.points[1], &square)
    defer delete(intersections)
    
    fmt.printf("Found %d intersections\n", len(intersections))
    for i in 0..<len(intersections) {
        intersection := intersections[i]
        fmt.printf("  Intersection %d: (%.1f,%.1f)\n", 
                   i, coord_to_mm(intersection.x), coord_to_mm(intersection.y))
    }
    
    // Test creating segments manually
    segments := create_inside_segments(line.points[0], line.points[1], intersections, &square)
    defer {
        for &segment in segments {
            delete(segment.points)
        }
        delete(segments)
    }
    
    fmt.printf("Created %d inside segments\n", len(segments))
    for i in 0..<len(segments) {
        segment := segments[i]
        if len(segment.points) >= 2 {
            fmt.printf("  Segment %d: (%.1f,%.1f) to (%.1f,%.1f)\n", 
                       i,
                       coord_to_mm(segment.points[0].x), coord_to_mm(segment.points[0].y),
                       coord_to_mm(segment.points[1].x), coord_to_mm(segment.points[1].y))
        }
    }
    
    fmt.println("✓ Simple infill test completed")
}