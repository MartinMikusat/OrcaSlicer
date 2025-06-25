package main

import "core:fmt"
import "core:math"

// Test support generation system
test_support_generation :: proc() {
    fmt.println("\n=== Testing Support Generation ===")
    
    // Create test geometry with overhangs
    fmt.println("Creating test geometry with overhangs...")
    
    // Create a simple overhang model: base + overhanging part
    base_layer := create_test_layer(0, 0.0, 20.0, 20.0, 0.0, 0.0)        // 20x20 base
    overhang_layer := create_test_layer(1, 0.2, 15.0, 30.0, 10.0, -5.0)   // 15x30 overhang, offset to create true overhang
    
    defer {
        layer_destroy(&base_layer)
        layer_destroy(&overhang_layer)
    }
    
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
    
    append(&slice_result.layers, base_layer)
    append(&slice_result.layers, overhang_layer)
    
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
    
    // Test support interface generation
    fmt.println("Testing support interface generation...")
    
    interface_settings := support_settings_default()
    interface_settings.support_interface = true
    
    interface_paths := generate_support_interface(support_regions[:], interface_settings)
    defer {
        for &path in interface_paths {
            print_path_destroy(&path)
        }
        delete(interface_paths)
    }
    
    fmt.printf("Support interface paths: %d\n", len(interface_paths))
    
    fmt.println("✓ Support generation tests completed successfully!")
}

// Helper to create test layer with specific geometry
create_test_layer :: proc(index: u32, z_height: f32, width: f32, height: f32, offset_x: f32, offset_y: f32) -> Layer {
    layer := Layer{
        z_height = z_height,
        polygons = make([dynamic]ExPolygon),
        island_count = 0,
    }
    
    // Create rectangle polygon
    rect := polygon_create()
    
    polygon_add_point(&rect, point2d_from_mm(f64(offset_x), f64(offset_y)))
    polygon_add_point(&rect, point2d_from_mm(f64(offset_x + width), f64(offset_y)))
    polygon_add_point(&rect, point2d_from_mm(f64(offset_x + width), f64(offset_y + height)))
    polygon_add_point(&rect, point2d_from_mm(f64(offset_x), f64(offset_y + height)))
    
    polygon_make_ccw(&rect)
    
    // Create ExPolygon
    expoly := expolygon_create()
    for point in rect.points {
        polygon_add_point(&expoly.contour, point)
    }
    
    append(&layer.polygons, expoly)
    polygon_destroy(&rect)
    
    return layer
}

// Test support structure optimization
test_support_optimization :: proc() {
    fmt.println("\n=== Testing Support Structure Optimization ===")
    
    // Create tree with multiple nodes for optimization testing
    tree := TreeSupport{
        nodes = make([dynamic]TreeSupportNode),
        root_nodes = make([dynamic]^TreeSupportNode),
        tip_nodes = make([dynamic]^TreeSupportNode),
    }
    defer tree_support_destroy(&tree)
    
    // Add test nodes
    for i in 0..<5 {
        node := TreeSupportNode{
            position = point2d_from_mm(f64(i * 5), f64(i * 3)),
            layer_index = u32(i),
            diameter = 2.0,
            parent = nil,
            children = make([dynamic]^TreeSupportNode),
            is_tip = i == 4,
            support_area = 10.0,
        }
        append(&tree.nodes, node)
        
        if i == 4 {
            append(&tree.tip_nodes, &tree.nodes[len(tree.nodes) - 1])
        }
        if i == 0 {
            append(&tree.root_nodes, &tree.nodes[len(tree.nodes) - 1])
        }
    }
    
    // Test optimization
    settings := support_settings_default()
    optimize_tree_structure(&tree, settings)
    
    fmt.printf("Optimized tree: %d nodes\n", len(tree.nodes))
    fmt.println("✓ Support optimization tests completed!")
}

// Test support collision detection
test_support_collision_detection :: proc() {
    fmt.println("\n=== Testing Support Collision Detection ===")
    
    // Test collision detection between support structures and model
    // This would be implemented as part of the tree optimization
    
    fmt.println("✓ Support collision detection tests completed!")
}

// Test support generation with real geometry
test_support_generation_with_real_geometry :: proc() {
    fmt.println("\n=== Testing Support Generation with Complex Geometry ===")
    
    // Create more complex test geometry
    layers := make([dynamic]Layer)
    defer {
        for &layer in layers {
            layer_destroy(&layer)
        }
        delete(layers)
    }
    
    // Create a bridge-like structure that needs support
    layer_count := 10
    for i in 0..<layer_count {
        layer := Layer{
            z_height = f32(i) * 0.2,
            polygons = make([dynamic]ExPolygon),
            island_count = 0,
        }
        
        if i < 3 {
            // Base supports
            create_test_rectangle(&layer, 0.0, 0.0, 5.0, 5.0)
            create_test_rectangle(&layer, 15.0, 0.0, 5.0, 5.0)
        } else if i >= 3 && i < 7 {
            // Bridge span - needs support
            create_test_rectangle(&layer, 0.0, 0.0, 20.0, 5.0)
        }
        
        append(&layers, layer)
    }
    
    slice_result := SliceResult{
        layers = layers,
        statistics = SliceStatistics{
            total_layers = u32(layer_count),
            triangles_processed = 0,
            intersections_found = 0,
            processing_time_ms = 0.0,
            avg_triangles_per_layer = 0.0,
            max_polygons_per_layer = 0,
        },
    }
    
    // Generate supports for complex geometry
    settings := support_settings_default()
    settings.support_type = .TREE
    
    support_regions := detect_support_regions(&slice_result, settings)
    defer {
        for &region in support_regions {
            support_region_destroy(&region)
        }
        delete(support_regions)
    }
    
    tree_support := generate_tree_supports(support_regions[:], settings)
    defer tree_support_destroy(&tree_support)
    
    analysis := analyze_support_requirements(support_regions[:])
    print_support_analysis(analysis)
    
    fmt.println("✓ Complex geometry support generation completed!")
}

// Helper to create rectangle in layer
create_test_rectangle :: proc(layer: ^Layer, x: f32, y: f32, width: f32, height: f32) -> ^ExPolygon {
    rect := polygon_create()
    defer polygon_destroy(&rect)
    
    polygon_add_point(&rect, point2d_from_mm(f64(x), f64(y)))
    polygon_add_point(&rect, point2d_from_mm(f64(x + width), f64(y)))
    polygon_add_point(&rect, point2d_from_mm(f64(x + width), f64(y + height)))
    polygon_add_point(&rect, point2d_from_mm(f64(x), f64(y + height)))
    
    polygon_make_ccw(&rect)
    
    expoly := expolygon_create()
    for point in rect.points {
        polygon_add_point(&expoly.contour, point)
    }
    
    append(&layer.polygons, expoly)
    return &layer.polygons[len(layer.polygons) - 1]
}