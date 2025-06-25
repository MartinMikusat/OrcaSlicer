package main

import "core:fmt"

// Test skirt and brim generation system
test_skirt_brim_generation :: proc() {
    fmt.println("\n=== Testing Skirt and Brim Generation ===")
    
    // Create test first layer with perimeters
    fmt.println("Creating test first layer...")
    
    first_layer := create_test_first_layer()
    defer print_layer_destroy(&first_layer)
    
    fmt.printf("Test layer has %d paths\n", len(first_layer.paths))
    
    // Test skirt generation
    test_skirt_generation(&first_layer)
    
    // Test brim generation
    test_brim_generation(&first_layer)
    
    // Test bed adhesion feature selection
    test_bed_adhesion_feature_selection(&first_layer)
    
    fmt.println("✓ Skirt and brim generation tests completed successfully!")
}

// Test skirt generation specifically
test_skirt_generation :: proc(first_layer: ^PrintLayer) {
    fmt.println("\n--- Testing Skirt Generation ---")
    
    settings := skirt_brim_settings_default()
    settings.adhesion_type = .SKIRT
    settings.skirt_line_count = 3
    settings.skirt_distance = 5.0
    
    skirt_paths := generate_skirt(first_layer, settings)
    defer {
        for &path in skirt_paths {
            print_path_destroy(&path)
        }
        delete(skirt_paths)
    }
    
    fmt.printf("Generated %d skirt paths\n", len(skirt_paths))
    
    // Analyze skirt
    analysis := analyze_bed_adhesion(skirt_paths, settings)
    print_bed_adhesion_analysis(analysis)
    
    // Validate skirt properties
    for i in 0..<len(skirt_paths) {
        path := &skirt_paths[i]
        if path.type != .SKIRT {
            fmt.printf("ERROR: Skirt path %d has wrong type: %v\n", i, path.type)
        }
        
        if !path.is_closed {
            fmt.printf("WARNING: Skirt path %d is not closed\n", i)
        }
        
        if path.total_length < 10.0 {
            fmt.printf("WARNING: Skirt path %d is very short: %.2fmm\n", i, path.total_length)
        }
    }
    
    fmt.println("✓ Skirt generation test completed")
}

// Test brim generation specifically
test_brim_generation :: proc(first_layer: ^PrintLayer) {
    fmt.println("\n--- Testing Brim Generation ---")
    
    settings := skirt_brim_settings_default()
    settings.adhesion_type = .BRIM
    settings.brim_width = 6.0
    settings.line_width = 0.4
    
    brim_paths := generate_brim(first_layer, settings)
    defer {
        for &path in brim_paths {
            print_path_destroy(&path)
        }
        delete(brim_paths)
    }
    
    fmt.printf("Generated %d brim paths\n", len(brim_paths))
    
    // Analyze brim
    analysis := analyze_bed_adhesion(brim_paths, settings)
    print_bed_adhesion_analysis(analysis)
    
    // Validate brim properties
    for i in 0..<len(brim_paths) {
        path := &brim_paths[i]
        if path.type != .BRIM {
            fmt.printf("ERROR: Brim path %d has wrong type: %v\n", i, path.type)
        }
        
        if !path.is_closed {
            fmt.printf("WARNING: Brim path %d is not closed\n", i)
        }
    }
    
    // Test brim width calculation
    expected_lines := u32(settings.brim_width / settings.line_width)
    if len(brim_paths) > 0 {
        fmt.printf("Expected ~%d brim lines for %.1fmm width\n", expected_lines, settings.brim_width)
    }
    
    fmt.println("✓ Brim generation test completed")
}

// Test bed adhesion feature selection
test_bed_adhesion_feature_selection :: proc(first_layer: ^PrintLayer) {
    fmt.println("\n--- Testing Bed Adhesion Feature Selection ---")
    
    adhesion_types := []BedAdhesionType{.NONE, .SKIRT, .BRIM}
    
    for adhesion_type in adhesion_types {
        fmt.printf("Testing adhesion type: %v\n", adhesion_type)
        
        settings := skirt_brim_settings_default()
        settings.adhesion_type = adhesion_type
        
        adhesion_paths := generate_bed_adhesion_features(first_layer, settings)
        defer {
            for &path in adhesion_paths {
                print_path_destroy(&path)
            }
            delete(adhesion_paths)
        }
        
        expected_count := 0
        #partial switch adhesion_type {
        case .NONE:
            expected_count = 0
        case .SKIRT:
            expected_count = int(settings.skirt_line_count)
        case .BRIM:
            expected_count = int(settings.brim_width / settings.line_width)
        }
        
        fmt.printf("  Generated %d paths (expected ~%d)\n", len(adhesion_paths), expected_count)
        
        // Validate path types
        for &path in adhesion_paths {
            expected_type: PrintPathType
            #partial switch adhesion_type {
            case .SKIRT:
                expected_type = .SKIRT
            case .BRIM:
                expected_type = .BRIM
            case .NONE:
                // Should not have any paths
                fmt.printf("ERROR: Got path when none expected\n")
            }
            
            if adhesion_type != .NONE && path.type != expected_type {
                fmt.printf("ERROR: Wrong path type. Expected %v, got %v\n", expected_type, path.type)
            }
        }
    }
    
    fmt.println("✓ Bed adhesion feature selection test completed")
}

// Test advanced brim features
test_advanced_brim_features :: proc() {
    fmt.println("\n=== Testing Advanced Brim Features ===")
    
    // Create test layer
    first_layer := create_test_first_layer_complex()
    defer print_layer_destroy(&first_layer)
    
    // Test gap filling brim
    fmt.println("Testing brim with gap filling...")
    settings := skirt_brim_settings_default()
    settings.adhesion_type = .BRIM
    settings.gap_fill = true
    
    gap_fill_paths := generate_brim_with_gap_fill(&first_layer, settings)
    defer {
        for &path in gap_fill_paths {
            print_path_destroy(&path)
        }
        delete(gap_fill_paths)
    }
    
    fmt.printf("Generated %d gap-filling brim paths\n", len(gap_fill_paths))
    
    // Test corner splitting brim
    fmt.println("Testing brim with corner splitting...")
    settings.corner_splitting = true
    
    corner_split_paths := generate_brim_with_corner_splitting(&first_layer, settings)
    defer {
        for &path in corner_split_paths {
            print_path_destroy(&path)
        }
        delete(corner_split_paths)
    }
    
    fmt.printf("Generated %d corner-splitting brim paths\n", len(corner_split_paths))
    
    fmt.println("✓ Advanced brim features test completed")
}

// Test skirt minimal length requirement
test_skirt_minimal_length :: proc() {
    fmt.println("\n=== Testing Skirt Minimal Length ===")
    
    // Create very small test layer
    small_layer := create_small_test_layer()
    defer print_layer_destroy(&small_layer)
    
    settings := skirt_brim_settings_default()
    settings.adhesion_type = .SKIRT
    settings.skirt_minimal_length = 100.0 // Require 100mm minimum
    
    skirt_paths := generate_skirt(&small_layer, settings)
    defer {
        for &path in skirt_paths {
            print_path_destroy(&path)
        }
        delete(skirt_paths)
    }
    
    fmt.printf("Generated %d skirt paths with %.1fmm minimum length requirement\n", 
               len(skirt_paths), settings.skirt_minimal_length)
    
    for i in 0..<len(skirt_paths) {
        path := &skirt_paths[i]
        if path.total_length < settings.skirt_minimal_length {
            fmt.printf("WARNING: Skirt path %d (%.2fmm) below minimum length\n", 
                       i, path.total_length)
        }
    }
    
    fmt.println("✓ Skirt minimal length test completed")
}

// Test material calculation accuracy
test_material_calculations :: proc() {
    fmt.println("\n=== Testing Material Calculations ===")
    
    first_layer := create_test_first_layer()
    defer print_layer_destroy(&first_layer)
    
    settings := skirt_brim_settings_default()
    settings.adhesion_type = .BRIM
    settings.brim_width = 8.0
    settings.line_width = 0.4
    settings.flow_ratio = 1.1 // 10% overextrusion
    
    brim_paths := generate_brim(&first_layer, settings)
    defer {
        for &path in brim_paths {
            print_path_destroy(&path)
        }
        delete(brim_paths)
    }
    
    analysis := analyze_bed_adhesion(brim_paths, settings)
    
    fmt.printf("Material analysis with %.1f flow ratio:\n", settings.flow_ratio)
    fmt.printf("  Total length: %.2f mm\n", analysis.total_length)
    fmt.printf("  Material volume: %.2f mm³\n", analysis.material_volume)
    fmt.printf("  Print time: %.1f seconds\n", analysis.estimated_time)
    
    // Validate material calculations make sense
    if analysis.material_volume <= 0 {
        fmt.println("ERROR: Material volume should be positive")
    }
    
    if analysis.estimated_time <= 0 {
        fmt.println("ERROR: Print time should be positive")
    }
    
    expected_volume := analysis.total_length * settings.line_width * 0.2 // layer height
    volume_ratio := analysis.material_volume / expected_volume
    
    fmt.printf("Volume calculation check: %.2f (expected ~1.0)\n", volume_ratio)
    
    fmt.println("✓ Material calculations test completed")
}

// =============================================================================
// Test Helper Functions
// =============================================================================

// Create test first layer with perimeters
create_test_first_layer :: proc() -> PrintLayer {
    layer := print_layer_create(0, 0.2)
    
    // Add outer perimeter (20x20mm square)
    outer_path := create_square_perimeter_path(point2d_from_mm(10.0, 10.0), 20.0, .PERIMETER_OUTER)
    print_layer_add_path(&layer, outer_path)
    
    // Add inner perimeter (16x16mm square)
    inner_path := create_square_perimeter_path(point2d_from_mm(10.0, 10.0), 16.0, .PERIMETER_INNER)
    print_layer_add_path(&layer, inner_path)
    
    return layer
}

// Create complex test layer with multiple objects
create_test_first_layer_complex :: proc() -> PrintLayer {
    layer := print_layer_create(0, 0.2)
    
    // Add multiple separate objects
    positions := []Point2D{
        point2d_from_mm(10.0, 10.0),
        point2d_from_mm(30.0, 10.0),
        point2d_from_mm(10.0, 30.0),
    }
    
    for pos in positions {
        outer_path := create_square_perimeter_path(pos, 8.0, .PERIMETER_OUTER)
        print_layer_add_path(&layer, outer_path)
    }
    
    return layer
}

// Create small test layer for minimal length testing
create_small_test_layer :: proc() -> PrintLayer {
    layer := print_layer_create(0, 0.2)
    
    // Very small 5x5mm square
    small_path := create_square_perimeter_path(point2d_from_mm(2.5, 2.5), 5.0, .PERIMETER_OUTER)
    print_layer_add_path(&layer, small_path)
    
    return layer
}

// Create square perimeter path at given center and size
create_square_perimeter_path :: proc(center: Point2D, size: f64, path_type: PrintPathType) -> PrintPath {
    path := print_path_create(path_type, 0)
    path.is_closed = true
    
    half_size := size / 2.0
    offset := mm_to_coord(half_size)
    
    square_points := []Point2D{
        {center.x - offset, center.y - offset},
        {center.x + offset, center.y - offset},
        {center.x + offset, center.y + offset},
        {center.x - offset, center.y + offset},
        {center.x - offset, center.y - offset}, // Close the loop
    }
    
    for i in 0..<len(square_points)-1 {
        move := print_move_create(.EXTRUDE, square_points[i], square_points[i+1],
                                40.0, 0.12, 0.2)
        print_path_add_move(&path, move)
    }
    
    return path
}

// Test complete skirt and brim workflow
test_complete_skirt_brim_workflow :: proc() {
    fmt.println("\n=== Testing Complete Skirt/Brim Workflow ===")
    
    // Create realistic test case
    first_layer := create_realistic_first_layer()
    defer print_layer_destroy(&first_layer)
    
    // Test complete workflow with different settings
    test_cases := []struct {
        name: string,
        settings: SkirtBrimSettings,
    }{
        {
            name = "Standard Skirt",
            settings = {
                adhesion_type = .SKIRT,
                skirt_distance = 6.0,
                skirt_line_count = 3,
                line_width = 0.4,
                speed = 30.0,
                flow_ratio = 1.0,
                skirt_minimal_length = 150.0,
                corner_splitting = false,
                gap_fill = false,
            },
        },
        {
            name = "Wide Brim",
            settings = {
                adhesion_type = .BRIM,
                brim_width = 10.0,
                line_width = 0.4,
                speed = 25.0,
                flow_ratio = 1.05,
                brim_only_on_outside = false,
                corner_splitting = true,
                gap_fill = true,
            },
        },
        {
            name = "Minimal Skirt",
            settings = {
                adhesion_type = .SKIRT,
                skirt_distance = 3.0,
                skirt_line_count = 1,
                line_width = 0.6,
                speed = 40.0,
                flow_ratio = 0.95,
                skirt_minimal_length = 50.0,
                corner_splitting = false,
                gap_fill = false,
            },
        },
    }
    
    for test_case in test_cases {
        fmt.printf("\n--- Testing: %s ---\n", test_case.name)
        
        adhesion_paths := generate_bed_adhesion_features(&first_layer, test_case.settings)
        defer {
            for &path in adhesion_paths {
                print_path_destroy(&path)
            }
            delete(adhesion_paths)
        }
        
        analysis := analyze_bed_adhesion(adhesion_paths, test_case.settings)
        print_bed_adhesion_analysis(analysis)
        
        // Validate results
        validate_adhesion_paths(adhesion_paths, test_case.settings)
    }
    
    fmt.println("✓ Complete skirt/brim workflow test completed")
}

// Create realistic first layer for comprehensive testing
create_realistic_first_layer :: proc() -> PrintLayer {
    layer := print_layer_create(0, 0.2)
    
    // Main object - larger square with hole
    main_outer := create_square_perimeter_path(point2d_from_mm(25.0, 25.0), 30.0, .PERIMETER_OUTER)
    print_layer_add_path(&layer, main_outer)
    
    main_inner := create_square_perimeter_path(point2d_from_mm(25.0, 25.0), 20.0, .PERIMETER_INNER)
    print_layer_add_path(&layer, main_inner)
    
    // Secondary object - small separate part
    secondary := create_square_perimeter_path(point2d_from_mm(50.0, 15.0), 8.0, .PERIMETER_OUTER)
    print_layer_add_path(&layer, secondary)
    
    return layer
}

// Validate generated adhesion paths
validate_adhesion_paths :: proc(paths: [dynamic]PrintPath, settings: SkirtBrimSettings) {
    error_count := 0
    
    for i in 0..<len(paths) {
        path := &paths[i]
        // Check path type
        expected_type: PrintPathType
        #partial switch settings.adhesion_type {
        case .SKIRT:
            expected_type = .SKIRT
        case .BRIM:
            expected_type = .BRIM
        case .NONE:
            fmt.printf("ERROR: Path %d exists when adhesion_type is NONE\n", i)
            error_count += 1
            continue
        }
        
        if path.type != expected_type {
            fmt.printf("ERROR: Path %d has type %v, expected %v\n", i, path.type, expected_type)
            error_count += 1
        }
        
        // Check path is closed
        if !path.is_closed {
            fmt.printf("WARNING: Path %d is not closed\n", i)
        }
        
        // Check layer index
        if path.layer_index != 0 {
            fmt.printf("ERROR: Path %d on layer %d, should be layer 0\n", i, path.layer_index)
            error_count += 1
        }
        
        // Check path length
        if path.total_length <= 0 {
            fmt.printf("ERROR: Path %d has zero or negative length\n", i)
            error_count += 1
        }
        
        // Check moves
        if len(path.moves) == 0 {
            fmt.printf("ERROR: Path %d has no moves\n", i)
            error_count += 1
        }
        
        for j in 0..<len(path.moves) {
            move := &path.moves[j]
            if move.type != .EXTRUDE {
                fmt.printf("WARNING: Path %d move %d is not EXTRUDE type\n", i, j)
            }
            
            if move.extrusion_rate <= 0 {
                fmt.printf("ERROR: Path %d move %d has zero/negative extrusion\n", i, j)
                error_count += 1
            }
        }
    }
    
    if error_count == 0 {
        fmt.println("✓ All adhesion paths validated successfully")
    } else {
        fmt.printf("✗ Found %d validation errors\n", error_count)
    }
}