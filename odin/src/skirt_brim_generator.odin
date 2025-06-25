package main

import "core:fmt"
import "core:slice"
import "core:math"

// =============================================================================
// Skirt and Brim Generation
//
// This module generates skirt and brim features for 3D printing:
// - Skirt: Outline around the print for priming extruder and checking settings
// - Brim: Attached outline for better bed adhesion on difficult materials
//
// Both features help ensure successful prints by providing extruder priming
// and improved first layer adhesion.
// =============================================================================

// =============================================================================
// Skirt and Brim Configuration
// =============================================================================

// Type of bed adhesion feature
BedAdhesionType :: enum {
    NONE,   // No skirt or brim
    SKIRT,  // Skirt around print (not attached)
    BRIM,   // Brim attached to print
    RAFT,   // Full raft under print (not implemented)
}

// Skirt and brim settings
SkirtBrimSettings :: struct {
    // Type selection
    adhesion_type:      BedAdhesionType,
    
    // Skirt settings
    skirt_distance:     f64,    // Distance from print (mm)
    skirt_line_count:   u32,    // Number of skirt lines
    skirt_height:       u32,    // Number of layers for skirt
    skirt_minimal_length: f64,  // Minimum skirt length (mm)
    
    // Brim settings  
    brim_width:         f64,    // Width of brim (mm)
    brim_line_count:    u32,    // Number of brim lines
    brim_only_on_outside: bool, // Only generate brim on outside edges
    
    // Common settings
    line_width:         f64,    // Line width for skirt/brim (mm)
    speed:              f64,    // Print speed (mm/s)
    flow_ratio:         f64,    // Flow ratio (1.0 = normal)
    
    // Advanced settings
    corner_splitting:   bool,   // Split sharp corners for better adhesion
    gap_fill:          bool,    // Fill small gaps in brim
}

// Default skirt/brim settings
skirt_brim_settings_default :: proc() -> SkirtBrimSettings {
    return {
        adhesion_type = .SKIRT,
        
        // Skirt defaults
        skirt_distance = 6.0,
        skirt_line_count = 3,
        skirt_height = 1,
        skirt_minimal_length = 250.0,
        
        // Brim defaults
        brim_width = 8.0,
        brim_line_count = 0, // Auto-calculate from width
        brim_only_on_outside = false,
        
        // Common defaults
        line_width = 0.4,
        speed = 30.0,
        flow_ratio = 1.0,
        
        // Advanced defaults
        corner_splitting = true,
        gap_fill = false,
    }
}

// =============================================================================
// Skirt Generation
// =============================================================================

// Generate skirt around first layer
generate_skirt :: proc(first_layer: ^PrintLayer, settings: SkirtBrimSettings) -> [dynamic]PrintPath {
    skirt_paths := make([dynamic]PrintPath)
    
    if settings.adhesion_type != .SKIRT do return skirt_paths
    if len(first_layer.paths) == 0 do return skirt_paths
    
    fmt.printf("Generating skirt: %d lines, %.1fmm distance\n", 
               settings.skirt_line_count, settings.skirt_distance)
    
    // Find all perimeter polygons in first layer
    layer_polygons := extract_layer_polygons(first_layer)
    defer {
        for &poly in layer_polygons {
            polygon_destroy(&poly)
        }
        delete(layer_polygons)
    }
    
    if len(layer_polygons) == 0 do return skirt_paths
    
    // Create union of all polygons to get print outline
    print_outline := create_print_outline(layer_polygons)
    defer {
        for &poly in print_outline {
            polygon_destroy(&poly)
        }
        delete(print_outline)
    }
    
    // Generate multiple skirt lines at increasing distances
    for line_idx in 0..<settings.skirt_line_count {
        offset_distance := settings.skirt_distance + f64(line_idx) * settings.line_width
        
        skirt_polygons := generate_skirt_at_distance(print_outline, offset_distance)
        defer {
            for &poly in skirt_polygons {
                polygon_destroy(&poly)
            }
            delete(skirt_polygons)
        }
        
        // Convert skirt polygons to print paths
        for &poly in skirt_polygons {
            if len(poly.points) >= 3 {
                path := convert_polygon_to_skirt_path(&poly, settings, u32(line_idx))
                
                // Check minimum length requirement
                if path.total_length >= settings.skirt_minimal_length {
                    append(&skirt_paths, path)
                } else {
                    print_path_destroy(&path)
                }
            }
        }
    }
    
    fmt.printf("Generated %d skirt paths\n", len(skirt_paths))
    return skirt_paths
}

// Extract all perimeter polygons from layer
extract_layer_polygons :: proc(layer: ^PrintLayer) -> [dynamic]Polygon {
    polygons := make([dynamic]Polygon)
    
    for &path in layer.paths {
        if path.type == .PERIMETER_OUTER || path.type == .PERIMETER_INNER {
            poly := convert_path_to_polygon(&path)
            if len(poly.points) >= 3 {
                append(&polygons, poly)
            } else {
                polygon_destroy(&poly)
            }
        }
    }
    
    return polygons
}

// Create unified outline of all print polygons
create_print_outline :: proc(polygons: [dynamic]Polygon) -> [dynamic]Polygon {
    if len(polygons) == 0 do return make([dynamic]Polygon)
    if len(polygons) == 1 {
        outline := make([dynamic]Polygon)
        poly_copy := polygon_create()
        for point in polygons[0].points {
            polygon_add_point(&poly_copy, point)
        }
        append(&outline, poly_copy)
        return outline
    }
    
    // For multiple polygons, return them as separate outlines for now
    // TODO: Implement proper polygon union when boolean ops are fixed
    outline := make([dynamic]Polygon)
    for &poly in polygons {
        poly_copy := polygon_create()
        for point in poly.points {
            polygon_add_point(&poly_copy, point)
        }
        append(&outline, poly_copy)
    }
    
    return outline
}

// Generate skirt polygons at specified distance from outline
generate_skirt_at_distance :: proc(outline: [dynamic]Polygon, distance: f64) -> [dynamic]Polygon {
    skirt_polygons := make([dynamic]Polygon)
    
    for &poly in outline {
        // Use polygon offsetting to create skirt at distance
        input_polygons := []Polygon{poly}
        config := boolean_config_default()
        
        // Offset outward to create skirt
        offset_result := polygon_offset(input_polygons, distance, config)
        
        for &offset_poly in offset_result {
            if len(offset_poly.points) >= 3 {
                append(&skirt_polygons, offset_poly)
            } else {
                polygon_destroy(&offset_poly)
            }
        }
        
        delete(offset_result)
    }
    
    return skirt_polygons
}

// Convert polygon to skirt print path
convert_polygon_to_skirt_path :: proc(poly: ^Polygon, settings: SkirtBrimSettings, line_index: u32) -> PrintPath {
    path := print_path_create(.SKIRT, 0) // Skirt is always on layer 0
    path.is_closed = true
    
    if len(poly.points) < 2 do return path
    
    // Calculate extrusion rate
    extrusion_rate := calculate_extrusion_rate(
        settings.line_width,
        0.2, // TODO: Get layer height from print settings
        0.4, // TODO: Get nozzle diameter from settings
    ) * settings.flow_ratio
    
    // Create moves for all edges
    for i in 0..<len(poly.points) {
        start := poly.points[i]
        end := poly.points[(i + 1) % len(poly.points)]
        
        move := print_move_create(.EXTRUDE, start, end, f32(settings.speed),
                                f32(extrusion_rate), 0.2) // First layer height
        print_path_add_move(&path, move)
    }
    
    return path
}

// =============================================================================
// Brim Generation
// =============================================================================

// Generate brim attached to first layer
generate_brim :: proc(first_layer: ^PrintLayer, settings: SkirtBrimSettings) -> [dynamic]PrintPath {
    brim_paths := make([dynamic]PrintPath)
    
    if settings.adhesion_type != .BRIM do return brim_paths
    if len(first_layer.paths) == 0 do return brim_paths
    
    fmt.printf("Generating brim: %.1fmm width\n", settings.brim_width)
    
    // Find all perimeter polygons
    layer_polygons := extract_layer_polygons(first_layer)
    defer {
        for &poly in layer_polygons {
            polygon_destroy(&poly)
        }
        delete(layer_polygons)
    }
    
    if len(layer_polygons) == 0 do return brim_paths
    
    // Calculate number of brim lines from width if not specified
    line_count := settings.brim_line_count
    if line_count == 0 {
        line_count = u32(math.ceil_f64(settings.brim_width / settings.line_width))
    }
    
    fmt.printf("Generating %d brim lines\n", line_count)
    
    // Generate brim lines for each polygon
    for &poly in layer_polygons {
        poly_brim_paths := generate_brim_for_polygon(&poly, settings, line_count)
        
        for path in poly_brim_paths {
            append(&brim_paths, path)
        }
        
        delete(poly_brim_paths)
    }
    
    fmt.printf("Generated %d brim paths\n", len(brim_paths))
    return brim_paths
}

// Generate brim paths for a single polygon
generate_brim_for_polygon :: proc(poly: ^Polygon, settings: SkirtBrimSettings, line_count: u32) -> [dynamic]PrintPath {
    brim_paths := make([dynamic]PrintPath)
    
    if len(poly.points) < 3 do return brim_paths
    
    // Generate concentric brim lines outward from polygon
    for line_idx in 0..<line_count {
        offset_distance := f64(line_idx + 1) * settings.line_width
        
        // Offset polygon outward to create brim line
        input_polygons := []Polygon{poly^}
        config := boolean_config_default()
        
        offset_result := polygon_offset(input_polygons, offset_distance, config)
        defer {
            for &offset_poly in offset_result {
                polygon_destroy(&offset_poly)
            }
            delete(offset_result)
        }
        
        // Convert offset polygons to brim paths
        for &offset_poly in offset_result {
            if len(offset_poly.points) >= 3 {
                path := convert_polygon_to_brim_path(&offset_poly, settings, line_idx)
                append(&brim_paths, path)
            }
        }
    }
    
    return brim_paths
}

// Convert polygon to brim print path
convert_polygon_to_brim_path :: proc(poly: ^Polygon, settings: SkirtBrimSettings, line_index: u32) -> PrintPath {
    path := print_path_create(.BRIM, 0) // Brim is always on layer 0
    path.is_closed = true
    
    if len(poly.points) < 2 do return path
    
    // Calculate extrusion rate
    extrusion_rate := calculate_extrusion_rate(
        settings.line_width,
        0.2, // TODO: Get layer height from print settings
        0.4, // TODO: Get nozzle diameter from settings
    ) * settings.flow_ratio
    
    // Create moves for all edges
    for i in 0..<len(poly.points) {
        start := poly.points[i]
        end := poly.points[(i + 1) % len(poly.points)]
        
        move := print_move_create(.EXTRUDE, start, end, f32(settings.speed),
                                f32(extrusion_rate), 0.2) // First layer height
        print_path_add_move(&path, move)
    }
    
    return path
}

// =============================================================================
// Utility Functions
// =============================================================================

// Convert print path back to polygon (for skirt/brim generation)
convert_path_to_polygon :: proc(path: ^PrintPath) -> Polygon {
    poly := polygon_create()
    
    for &move in path.moves {
        if move.type == .EXTRUDE {
            polygon_add_point(&poly, move.start)
        }
    }
    
    // Ensure polygon is closed
    if len(poly.points) > 0 && path.is_closed {
        first_point := poly.points[0]
        last_point := poly.points[len(poly.points) - 1]
        
        if first_point.x != last_point.x || first_point.y != last_point.y {
            polygon_add_point(&poly, first_point)
        }
    }
    
    return poly
}

// Calculate total length of skirt/brim for material estimation
calculate_skirt_brim_length :: proc(paths: [dynamic]PrintPath) -> f64 {
    total_length: f64 = 0.0
    
    for &path in paths {
        total_length += path.total_length
    }
    
    return total_length
}

// Generate both skirt and brim based on settings
generate_bed_adhesion_features :: proc(first_layer: ^PrintLayer, settings: SkirtBrimSettings) -> [dynamic]PrintPath {
    adhesion_paths := make([dynamic]PrintPath)
    
    #partial switch settings.adhesion_type {
    case .SKIRT:
        skirt_paths := generate_skirt(first_layer, settings)
        for path in skirt_paths {
            append(&adhesion_paths, path)
        }
        delete(skirt_paths)
        
    case .BRIM:
        brim_paths := generate_brim(first_layer, settings)
        for path in brim_paths {
            append(&adhesion_paths, path)
        }
        delete(brim_paths)
        
    case .NONE:
        // No bed adhesion features
        break
    }
    
    return adhesion_paths
}

// =============================================================================
// Advanced Brim Features
// =============================================================================

// Generate brim with gap filling for better adhesion
generate_brim_with_gap_fill :: proc(first_layer: ^PrintLayer, settings: SkirtBrimSettings) -> [dynamic]PrintPath {
    brim_paths := generate_brim(first_layer, settings)
    
    if !settings.gap_fill do return brim_paths
    
    // TODO: Implement gap filling between brim lines
    // This would identify small gaps between brim lines and fill them
    // with additional material for better bed adhesion
    
    fmt.println("Note: Gap filling not yet implemented")
    return brim_paths
}

// Generate brim with corner splitting for sharp angles
generate_brim_with_corner_splitting :: proc(first_layer: ^PrintLayer, settings: SkirtBrimSettings) -> [dynamic]PrintPath {
    brim_paths := generate_brim(first_layer, settings)
    
    if !settings.corner_splitting do return brim_paths
    
    // TODO: Implement corner splitting
    // This would split sharp corners in the brim to reduce stress concentration
    // and improve adhesion on difficult geometries
    
    fmt.println("Note: Corner splitting not yet implemented")
    return brim_paths
}

// =============================================================================
// Analysis and Statistics
// =============================================================================

// Bed adhesion analysis results
BedAdhesionAnalysis :: struct {
    feature_type:       BedAdhesionType,
    total_length:       f64,    // Total extrusion length (mm)
    material_volume:    f64,    // Material volume (mm³)
    estimated_time:     f64,    // Print time estimate (seconds)
    line_count:         u32,    // Number of lines generated
    coverage_area:      f64,    // Area covered by features (mm²)
}

// Analyze bed adhesion features
analyze_bed_adhesion :: proc(paths: [dynamic]PrintPath, settings: SkirtBrimSettings) -> BedAdhesionAnalysis {
    analysis := BedAdhesionAnalysis{
        feature_type = settings.adhesion_type,
    }
    
    analysis.line_count = u32(len(paths))
    analysis.total_length = calculate_skirt_brim_length(paths)
    
    // Calculate material volume (simplified)
    layer_height: f64 = 0.2 // TODO: Get from print settings
    cross_sectional_area := settings.line_width * layer_height
    analysis.material_volume = analysis.total_length * cross_sectional_area
    
    // Estimate print time
    analysis.estimated_time = analysis.total_length / settings.speed
    
    // TODO: Calculate coverage area more accurately
    analysis.coverage_area = analysis.total_length * settings.line_width
    
    return analysis
}

// Print bed adhesion analysis summary
print_bed_adhesion_analysis :: proc(analysis: BedAdhesionAnalysis) {
    fmt.printf("Bed Adhesion Analysis (%v):\n", analysis.feature_type)
    fmt.printf("  Lines: %d\n", analysis.line_count)
    fmt.printf("  Total length: %.2f mm\n", analysis.total_length)
    fmt.printf("  Material volume: %.2f mm³\n", analysis.material_volume)
    fmt.printf("  Estimated time: %.1f seconds\n", analysis.estimated_time)
    fmt.printf("  Coverage area: %.2f mm²\n", analysis.coverage_area)
}