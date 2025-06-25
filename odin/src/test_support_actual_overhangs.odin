package main

import "core:fmt"

// Test support generation with actual overhangs
test_support_generation_with_actual_overhangs :: proc() {
    fmt.println("\n=== Testing Support Generation with Actual Overhangs ===")
    
    // Create test geometry with true overhangs (no bounding box overlap)
    fmt.println("Creating test geometry with true overhangs...")
    
    // Base layer: small pillar on one side
    base_layer := Layer{
        z_height = 0.0,
        polygons = make([dynamic]ExPolygon),
        island_count = 1,
    }
    defer layer_destroy(&base_layer)
    
    // Create small base (5x5mm on left side)
    base_rect := polygon_create()
    polygon_add_point(&base_rect, point2d_from_mm(0.0, 10.0))
    polygon_add_point(&base_rect, point2d_from_mm(5.0, 10.0))
    polygon_add_point(&base_rect, point2d_from_mm(5.0, 15.0))
    polygon_add_point(&base_rect, point2d_from_mm(0.0, 15.0))
    polygon_make_ccw(&base_rect)
    
    base_expoly := expolygon_create()
    for point in base_rect.points {
        polygon_add_point(&base_expoly.contour, point)
    }
    append(&base_layer.polygons, base_expoly)
    polygon_destroy(&base_rect)
    
    // Overhang layer: large platform (20x20mm)
    overhang_layer := Layer{
        z_height = 0.2,
        polygons = make([dynamic]ExPolygon),
        island_count = 1,
    }
    defer layer_destroy(&overhang_layer)
    
    // Create completely separate overhang (no overlap with base at all)
    overhang_rect := polygon_create()
    polygon_add_point(&overhang_rect, point2d_from_mm(10.0, 10.0))  // Completely separate from base
    polygon_add_point(&overhang_rect, point2d_from_mm(20.0, 10.0))
    polygon_add_point(&overhang_rect, point2d_from_mm(20.0, 15.0))
    polygon_add_point(&overhang_rect, point2d_from_mm(10.0, 15.0))
    polygon_make_ccw(&overhang_rect)
    
    overhang_expoly := expolygon_create()
    for point in overhang_rect.points {
        polygon_add_point(&overhang_expoly.contour, point)
    }
    append(&overhang_layer.polygons, overhang_expoly)
    polygon_destroy(&overhang_rect)
    
    // Create slice result
    slice_result := SliceResult{
        layers = make([dynamic]Layer),
        statistics = SliceStatistics{
            total_layers = 2,
            triangles_processed = 0,
            intersections_found = 0,
            processing_time_ms = 0.0,
            avg_triangles_per_layer = 0.0,
            max_polygons_per_layer = 0,
        },
    }
    defer {
        for &layer in slice_result.layers {
            layer_destroy(&layer)
        }
        delete(slice_result.layers)
    }
    
    // Make copies for slice_result (since we're managing base_layer and overhang_layer separately)
    base_copy := Layer{
        z_height = base_layer.z_height,
        polygons = make([dynamic]ExPolygon),
        island_count = base_layer.island_count,
    }
    
    for &expoly in base_layer.polygons {
        expoly_copy := expolygon_create()
        for point in expoly.contour.points {
            polygon_add_point(&expoly_copy.contour, point)
        }
        append(&base_copy.polygons, expoly_copy)
    }
    append(&slice_result.layers, base_copy)
    
    overhang_copy := Layer{
        z_height = overhang_layer.z_height,
        polygons = make([dynamic]ExPolygon),
        island_count = overhang_layer.island_count,
    }
    
    for &expoly in overhang_layer.polygons {
        expoly_copy := expolygon_create()
        for point in expoly.contour.points {
            polygon_add_point(&expoly_copy.contour, point)
        }
        append(&overhang_copy.polygons, expoly_copy)
    }
    append(&slice_result.layers, overhang_copy)
    
    // Test support detection
    fmt.println("Testing support region detection...")
    
    settings := support_settings_default()
    support_regions := detect_support_regions(&slice_result, settings)
    defer {
        for &region in support_regions {
            support_region_destroy(&region)
        }
        delete(support_regions)
    }
    
    fmt.printf("Detected support regions: %d layers\n", len(support_regions))
    
    // Analyze support requirements
    analysis := analyze_support_requirements(support_regions[:])
    print_support_analysis(analysis)
    
    // Test tree support generation
    if analysis.support_region_count > 0 {
        fmt.println("\nTesting tree support generation...")
        
        tree_settings := support_settings_default()
        tree_settings.support_type = .TREE
        
        tree_support := generate_tree_supports(support_regions[:], tree_settings)
        defer tree_support_destroy(&tree_support)
        
        fmt.printf("Tree support: %d nodes, %d tips, %d roots\n",
                   len(tree_support.nodes), len(tree_support.tip_nodes), len(tree_support.root_nodes))
        
        // Test traditional support generation
        fmt.println("Testing traditional support generation...")
        
        traditional_settings := support_settings_default()
        traditional_settings.support_type = .TRADITIONAL
        
        traditional_paths := generate_traditional_supports(support_regions[:], traditional_settings)
        defer {
            for &path in traditional_paths {
                print_path_destroy(&path)
            }
            delete(traditional_paths)
        }
        
        fmt.printf("Traditional support paths: %d\n", len(traditional_paths))
    } else {
        fmt.println("No supports needed - testing edge case handling")
    }
    
    fmt.println("✓ Support generation with actual overhangs test completed!")
}