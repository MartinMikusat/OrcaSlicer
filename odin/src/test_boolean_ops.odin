package main

import "core:fmt"

// Test boolean operations to assess current state
test_boolean_operations_new :: proc() {
    fmt.println("\n--- Testing Boolean Operations ---")
    
    // Create two simple overlapping rectangles
    rect1 := polygon_create_rectangle(0, 0, 4, 2)  // 4mm x 2mm
    defer polygon_destroy(&rect1)
    
    rect2 := polygon_create_rectangle(2, 0, 6, 2)  // 4mm x 2mm, offset by 2mm
    defer polygon_destroy(&rect2)
    
    fmt.printf("Rectangle 1 area: %.3f mm²\n", polygon_area(&rect1))
    fmt.printf("Rectangle 2 area: %.3f mm²\n", polygon_area(&rect2))
    
    config := boolean_config_default()
    
    // Test union (should combine rectangles)
    fmt.println("  Testing union operation...")
    union_result, union_stats := polygon_boolean({rect1}, {rect2}, .UNION, config)
    defer boolean_result_destroy(&union_result)
    
    fmt.printf("    Union result: %d polygons\n", len(union_result))
    for i in 0..<len(union_result) {
        area := polygon_area(&union_result[i])
        fmt.printf("    Polygon %d area: %.3f mm²\n", i, area)
    }
    
    // Test intersection (should find overlapping area)
    fmt.println("  Testing intersection operation...")
    intersection_result, intersection_stats := polygon_boolean({rect1}, {rect2}, .INTERSECTION, config)
    defer boolean_result_destroy(&intersection_result)
    
    fmt.printf("    Intersection result: %d polygons\n", len(intersection_result))
    for i in 0..<len(intersection_result) {
        area := polygon_area(&intersection_result[i])
        fmt.printf("    Polygon %d area: %.3f mm²\n", i, area)
    }
    
    // Test polygon offsetting
    fmt.println("  Testing polygon offsetting...")
    offset_result := polygon_offset({rect1}, 0.5, config)  // Expand by 0.5mm
    defer boolean_result_destroy(&offset_result)
    
    fmt.printf("    Offset result: %d polygons\n", len(offset_result))
    for i in 0..<len(offset_result) {
        area := polygon_area(&offset_result[i])
        fmt.printf("    Offset polygon %d area: %.3f mm²\n", i, area)
        fmt.printf("    Expected area: %.3f mm² (original 8.0 + expansion)\n", 8.0 + 2*0.5*4 + 2*0.5*2 + 4*0.5*0.5)
    }
    
    // Test polygon difference (SAFELY)
    fmt.println("  Testing polygon difference...")
    
    // Create a simple case - rectangle minus smaller rectangle
    base_rect := polygon_create_rectangle(0, 0, 10, 10)  // 10x10mm
    defer polygon_destroy(&base_rect)
    
    hole_rect := polygon_create_rectangle(2, 2, 8, 8)   // 6x6mm hole in center
    defer polygon_destroy(&hole_rect)
    
    fmt.printf("    Base rectangle area: %.3f mm²\n", polygon_area(&base_rect))
    fmt.printf("    Hole rectangle area: %.3f mm²\n", polygon_area(&hole_rect))
    
    // Use safe memory management
    difference_result := polygon_difference({base_rect}, {hole_rect}, config)
    defer boolean_result_destroy(&difference_result)
    
    fmt.printf("    Difference result: %d polygons\n", len(difference_result))
    if len(difference_result) > 0 {
        result_area := polygon_area(&difference_result[0])
        expected_area := 100.0 - 36.0  // 10x10 - 6x6 = 64
        fmt.printf("    Result area: %.3f mm² (expected: %.3f mm²)\n", result_area, expected_area)
    }
    
    fmt.println("✓ Boolean operations tests completed")
}
