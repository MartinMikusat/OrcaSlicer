package main

import "core:fmt"
import "core:slice"
import "core:math"

// =============================================================================
// Support Generation - Tree and Traditional Support Structures
//
// This module generates support structures for overhanging geometry in 3D prints.
// It implements both tree supports (minimal material usage) and traditional
// supports (reliable but more material) using data-oriented algorithms.
//
// Architecture: Works with sliced layers and boolean operations from Phase 1
// =============================================================================

// =============================================================================
// Support Generation Types and Configuration
// =============================================================================

// Type of support structure
SupportType :: enum {
    TREE,           // Tree supports - minimal material, organic branching
    TRADITIONAL,    // Traditional supports - reliable vertical columns
    NONE,           // No supports generated
}

// Support generation settings
SupportSettings :: struct {
    // Support type and detection
    support_type:           SupportType,
    support_threshold:      f64,        // Overhang angle requiring support (degrees)
    support_interface:      bool,       // Generate interface layers
    
    // Tree support specific
    tree_branch_diameter:   f64,        // Branch diameter in mm
    tree_branch_angle:      f64,        // Maximum branch angle (degrees)
    tree_tip_diameter:      f64,        // Tip diameter in mm
    tree_collision_radius:  f64,        // Collision avoidance radius
    
    // Traditional support specific
    support_density:        f64,        // Support infill density (0.0-1.0)
    support_line_width:     f64,        // Support line width in mm
    support_wall_count:     u32,        // Support wall count
    
    // Interface settings
    interface_layers:       u32,        // Number of interface layers
    interface_density:      f64,        // Interface density (0.0-1.0)
    interface_offset:       f64,        // Interface offset from model
    
    // Spacing and clearance
    support_xy_distance:    f64,        // XY distance from model
    support_z_distance:     f64,        // Z distance from model
    support_bottom_layers:  u32,        // Bottom interface layers
    support_top_layers:     u32,        // Top interface layers
}

// Default support settings
support_settings_default :: proc() -> SupportSettings {
    return {
        support_type = .TREE,
        support_threshold = 45.0,       // 45° overhang threshold
        support_interface = true,
        
        // Tree support defaults
        tree_branch_diameter = 2.0,
        tree_branch_angle = 45.0,
        tree_tip_diameter = 0.4,
        tree_collision_radius = 0.5,
        
        // Traditional support defaults
        support_density = 0.15,
        support_line_width = 0.4,
        support_wall_count = 1,
        
        // Interface defaults
        interface_layers = 3,
        interface_density = 0.8,
        interface_offset = 0.2,
        
        // Spacing defaults
        support_xy_distance = 0.6,
        support_z_distance = 0.2,
        support_bottom_layers = 1,
        support_top_layers = 3,
    }
}

// =============================================================================
// Support Region Detection
// =============================================================================

// Support region for a single layer
SupportRegion :: struct {
    layer_index:     u32,
    z_height:        f32,
    regions:         [dynamic]Polygon,    // Areas requiring support
    support_type:    SupportType,
    contact_areas:   [dynamic]Polygon,    // Areas touching model
}

// Support region management
support_region_create :: proc(layer_index: u32, z_height: f32) -> SupportRegion {
    return {
        layer_index = layer_index,
        z_height = z_height,
        regions = make([dynamic]Polygon),
        support_type = .NONE,
        contact_areas = make([dynamic]Polygon),
    }
}

support_region_destroy :: proc(region: ^SupportRegion) {
    for &poly in region.regions {
        polygon_destroy(&poly)
    }
    delete(region.regions)
    
    for &poly in region.contact_areas {
        polygon_destroy(&poly)
    }
    delete(region.contact_areas)
}

// Detect support regions for all layers
detect_support_regions :: proc(slice_result: ^SliceResult, settings: SupportSettings) -> [dynamic]SupportRegion {
    support_regions := make([dynamic]SupportRegion)
    
    if settings.support_type == .NONE do return support_regions
    
    fmt.printf("Detecting support regions for %d layers...\n", len(slice_result.layers))
    
    // Process layers from top to bottom
    for layer_idx in 0..<len(slice_result.layers) {
        layer := &slice_result.layers[layer_idx]
        
        region := support_region_create(u32(layer_idx), layer.z_height)
        region.support_type = settings.support_type
        
        // Detect overhangs requiring support
        if layer_idx > 0 {
            prev_layer := &slice_result.layers[layer_idx - 1]
            overhangs := detect_overhangs(layer, prev_layer, settings)
            
            for overhang in overhangs {
                append(&region.regions, overhang)
            }
            
            delete(overhangs)
        }
        
        append(&support_regions, region)
    }
    
    // Propagate support regions downward
    propagate_support_regions(&support_regions, settings)
    
    return support_regions
}

// Detect overhanging areas between two layers
detect_overhangs :: proc(current_layer: ^Layer, prev_layer: ^Layer, settings: SupportSettings) -> [dynamic]Polygon {
    overhangs := make([dynamic]Polygon)
    
    // Convert layers to simple polygons for boolean operations
    current_polys := make([dynamic]Polygon)
    defer {
        for &poly in current_polys {
            polygon_destroy(&poly)
        }
        delete(current_polys)
    }
    
    prev_polys := make([dynamic]Polygon)
    defer {
        for &poly in prev_polys {
            polygon_destroy(&poly)
        }
        delete(prev_polys)
    }
    
    // Extract contours from current layer
    for &expoly in current_layer.polygons {
        poly_copy := polygon_create()
        for point in expoly.contour.points {
            polygon_add_point(&poly_copy, point)
        }
        append(&current_polys, poly_copy)
    }
    
    // Extract contours from previous layer
    for &expoly in prev_layer.polygons {
        poly_copy := polygon_create()
        for point in expoly.contour.points {
            polygon_add_point(&poly_copy, point)
        }
        append(&prev_polys, poly_copy)
    }
    
    // Find areas in current layer that are not supported by previous layer
    if len(current_polys) > 0 && len(prev_polys) > 0 {
        // TEMPORARY: Simple bounding box overlap check instead of full boolean operation
        // TODO: Fix the polygon_difference hanging issue and re-enable proper difference calculation
        
        for &current_poly in current_polys {
            current_bbox := polygon_bounding_box(&current_poly)
            has_support := false
            
            for &prev_poly in prev_polys {
                prev_bbox := polygon_bounding_box(&prev_poly)
                
                // Simple bounding box overlap test
                overlap := !(current_bbox.max.x < prev_bbox.min.x || 
                           current_bbox.min.x > prev_bbox.max.x ||
                           current_bbox.max.y < prev_bbox.min.y ||
                           current_bbox.min.y > prev_bbox.max.y)
                
                if overlap {
                    has_support = true
                    break
                }
            }
            
            // If no support found, add as overhang
            if !has_support {
                overhang_copy := polygon_create()
                for point in current_poly.points {
                    polygon_add_point(&overhang_copy, point)
                }
                append(&overhangs, overhang_copy)
                fmt.printf("    DEBUG: Added overhang region %.2f mm²\n", abs(polygon_area(&overhang_copy)))
            }
        }
    }
    
    return overhangs
}

// Propagate support regions from top layers down to build plate
propagate_support_regions :: proc(regions: ^[dynamic]SupportRegion, settings: SupportSettings) {
    if len(regions) <= 1 do return
    
    // Process from top to bottom
    for i := len(regions) - 2; i >= 0; i -= 1 {
        current := &regions[i]
        above := &regions[i + 1]
        
        // Propagate support regions from layer above
        for &support_region in above.regions {
            // Offset support region inward for collision avoidance
            offset_regions := []Polygon{support_region}
            config := boolean_config_default()
            
            propagated := polygon_offset(offset_regions, -settings.support_xy_distance, config)
            defer {
                for &poly in propagated {
                    polygon_destroy(&poly)
                }
                delete(propagated)
            }
            
            // Add propagated regions to current layer
            for prop_region in propagated {
                if len(prop_region.points) >= 3 {
                    region_copy := polygon_create()
                    for point in prop_region.points {
                        polygon_add_point(&region_copy, point)
                    }
                    append(&current.regions, region_copy)
                }
            }
        }
    }
}

// =============================================================================
// Tree Support Generation
// =============================================================================

// Tree support node for branching structure
TreeSupportNode :: struct {
    position:        Point2D,           // XY position
    layer_index:     u32,               // Z layer
    diameter:        f64,               // Branch diameter
    parent:          ^TreeSupportNode,  // Parent node (toward base)
    children:        [dynamic]^TreeSupportNode, // Child nodes (toward tips)
    is_tip:          bool,              // True for tip nodes
    support_area:    f64,               // Area this node supports
}

// Tree support structure
TreeSupport :: struct {
    nodes:           [dynamic]TreeSupportNode,
    root_nodes:      [dynamic]^TreeSupportNode, // Nodes touching build plate
    tip_nodes:       [dynamic]^TreeSupportNode, // Nodes touching model
}

// Generate tree support structure
generate_tree_supports :: proc(support_regions: []SupportRegion, settings: SupportSettings) -> TreeSupport {
    tree := TreeSupport{
        nodes = make([dynamic]TreeSupportNode),
        root_nodes = make([dynamic]^TreeSupportNode),
        tip_nodes = make([dynamic]^TreeSupportNode),
    }
    
    if len(support_regions) == 0 do return tree
    
    fmt.println("Generating tree support structure...")
    
    // Step 1: Create tip nodes from support regions
    create_tree_tips(&tree, support_regions, settings)
    
    // Step 2: Generate branches from tips to base
    generate_tree_branches(&tree, support_regions, settings)
    
    // Step 3: Optimize tree structure
    optimize_tree_structure(&tree, settings)
    
    fmt.printf("Generated tree support: %d nodes, %d tips, %d roots\n",
               len(tree.nodes), len(tree.tip_nodes), len(tree.root_nodes))
    
    return tree
}

// Create tip nodes from support regions
create_tree_tips :: proc(tree: ^TreeSupport, support_regions: []SupportRegion, settings: SupportSettings) {
    for &region in support_regions {
        if len(region.regions) == 0 do continue
        
        for &support_poly in region.regions {
            // Create tips at key points in support polygon
            tips := generate_support_tips(&support_poly, region.layer_index, settings)
            defer delete(tips)
            
            for tip_pos in tips {
                node := TreeSupportNode{
                    position = tip_pos,
                    layer_index = region.layer_index,
                    diameter = settings.tree_tip_diameter,
                    parent = nil,
                    children = make([dynamic]^TreeSupportNode),
                    is_tip = true,
                    support_area = polygon_area(&support_poly) / f64(len(tips)),
                }
                
                append(&tree.nodes, node)
                append(&tree.tip_nodes, &tree.nodes[len(tree.nodes) - 1])
            }
        }
    }
}

// Generate support tip positions within a polygon
generate_support_tips :: proc(poly: ^Polygon, layer_index: u32, settings: SupportSettings) -> [dynamic]Point2D {
    tips := make([dynamic]Point2D)
    
    if len(poly.points) < 3 do return tips
    
    // Simple strategy: place tips at polygon centroid
    centroid := calculate_polygon_centroid(poly)
    append(&tips, centroid)
    
    // For large areas, add additional tips
    area := polygon_area(poly)
    if abs(area) > 25.0 { // > 25 mm²
        // Add tips at key vertices
        for i in 0..<len(poly.points) {
            if i % 3 == 0 { // Every third vertex
                append(&tips, poly.points[i])
            }
        }
    }
    
    return tips
}

// Calculate polygon centroid
calculate_polygon_centroid :: proc(poly: ^Polygon) -> Point2D {
    if len(poly.points) == 0 do return {0, 0}
    
    cx: coord_t = 0
    cy: coord_t = 0
    
    for point in poly.points {
        cx += point.x
        cy += point.y
    }
    
    return {cx / coord_t(len(poly.points)), cy / coord_t(len(poly.points))}
}

// Generate branches from tips toward base
generate_tree_branches :: proc(tree: ^TreeSupport, support_regions: []SupportRegion, settings: SupportSettings) {
    // Process each tip node and create path to base
    for &tip_node in tree.tip_nodes {
        generate_branch_path(tree, tip_node, support_regions, settings)
    }
}

// Generate branch path from tip to base
generate_branch_path :: proc(tree: ^TreeSupport, tip_node: ^TreeSupportNode, 
                            support_regions: []SupportRegion, settings: SupportSettings) {
    current_node := tip_node
    target_layer := 0 // Build plate
    
    for current_node.layer_index > u32(target_layer) {
        next_layer := current_node.layer_index - 1
        
        // Calculate next position with branching constraints
        next_pos := calculate_next_branch_position(current_node, settings)
        
        // Create new node
        new_node := TreeSupportNode{
            position = next_pos,
            layer_index = next_layer,
            diameter = calculate_branch_diameter(current_node, settings),
            parent = current_node,
            children = make([dynamic]^TreeSupportNode),
            is_tip = false,
            support_area = current_node.support_area,
        }
        
        append(&tree.nodes, new_node)
        new_node_ptr := &tree.nodes[len(tree.nodes) - 1]
        
        // Link nodes
        append(&current_node.children, new_node_ptr)
        new_node_ptr.parent = current_node
        
        // Check if this is a root node
        if next_layer == 0 {
            append(&tree.root_nodes, new_node_ptr)
        }
        
        current_node = new_node_ptr
    }
}

// Calculate next branch position with angle constraints
calculate_next_branch_position :: proc(node: ^TreeSupportNode, settings: SupportSettings) -> Point2D {
    if node.parent == nil {
        // For tip nodes, grow slightly inward
        return node.position
    }
    
    // Calculate maximum horizontal movement based on layer height and angle
    layer_height: f64 = 0.2 // TODO: Get from print settings
    max_horizontal_movement := layer_height * math.tan_f64(settings.tree_branch_angle * math.PI / 180.0)
    
    // For now, simple vertical growth (can be enhanced with collision avoidance)
    max_offset := mm_to_coord(max_horizontal_movement)
    
    // Add small random offset for natural branching (deterministic based on position)
    offset_x := coord_t((node.position.x / 1000) % max_offset) - max_offset / 2
    offset_y := coord_t((node.position.y / 1000) % max_offset) - max_offset / 2
    
    return {
        node.position.x + offset_x,
        node.position.y + offset_y,
    }
}

// Calculate branch diameter based on support requirements
calculate_branch_diameter :: proc(node: ^TreeSupportNode, settings: SupportSettings) -> f64 {
    if node.is_tip {
        return settings.tree_tip_diameter
    }
    
    // Gradually increase diameter toward base
    base_diameter := settings.tree_branch_diameter
    tip_diameter := settings.tree_tip_diameter
    
    // Simple linear interpolation based on layer (can be enhanced)
    if node.layer_index == 0 {
        return base_diameter
    }
    
    // Interpolate between tip and base diameter
    layer_factor := f64(node.layer_index) / 50.0 // Assume ~50 layers
    return tip_diameter + (base_diameter - tip_diameter) * (1.0 - layer_factor)
}

// Optimize tree structure for better stability and material usage
optimize_tree_structure :: proc(tree: ^TreeSupport, settings: SupportSettings) {
    // TODO: Implement optimizations:
    // - Merge nearby branches
    // - Remove redundant supports
    // - Balance load distribution
    // - Collision avoidance with model
    
    fmt.println("Tree structure optimization: basic implementation")
}

// =============================================================================
// Traditional Support Generation
// =============================================================================

// Generate traditional grid-based supports
generate_traditional_supports :: proc(support_regions: []SupportRegion, settings: SupportSettings) -> [dynamic]PrintPath {
    paths := make([dynamic]PrintPath)
    
    if len(support_regions) == 0 do return paths
    
    fmt.println("Generating traditional support structure...")
    
    for &region in support_regions {
        if len(region.regions) == 0 do continue
        
        // Generate support infill for each region
        for &support_poly in region.regions {
            support_paths := generate_support_infill(&support_poly, region.layer_index, 
                                                   region.z_height, settings)
            
            for path in support_paths {
                append(&paths, path)
            }
            
            delete(support_paths)
        }
    }
    
    fmt.printf("Generated traditional supports: %d paths\n", len(paths))
    return paths
}

// Generate support infill for a single support region
generate_support_infill :: proc(support_poly: ^Polygon, layer_index: u32, z_height: f32, 
                              settings: SupportSettings) -> [dynamic]PrintPath {
    paths := make([dynamic]PrintPath)
    
    if len(support_poly.points) < 3 do return paths
    
    // Create rectilinear infill pattern for support
    print_settings := PrintSettings{
        layer_height = 0.2, // TODO: Get from global settings
        infill = InfillSettings{
            density = settings.support_density,
            pattern = .RECTILINEAR,
            line_width = settings.support_line_width,
            speed = 40.0, // Slower for supports
            angle = f64(layer_index % 2) * 90.0, // Alternate angle
            spacing = settings.support_line_width / settings.support_density,
        },
    }
    
    // Convert polygon to infill region
    infill_regions := make([dynamic]Polygon)
    defer {
        for &poly in infill_regions {
            polygon_destroy(&poly)
        }
        delete(infill_regions)
    }
    
    poly_copy := polygon_create()
    for point in support_poly.points {
        polygon_add_point(&poly_copy, point)
    }
    append(&infill_regions, poly_copy)
    
    // Generate infill pattern
    pattern_lines := generate_rectilinear_pattern(infill_regions, print_settings.infill, layer_index)
    defer {
        for &line in pattern_lines {
            delete(line.points)
        }
        delete(pattern_lines)
    }
    
    // Clip lines against support region
    clipped_lines := clip_infill_lines(pattern_lines, infill_regions)
    defer {
        for &line in clipped_lines {
            delete(line.points)
        }
        delete(clipped_lines)
    }
    
    // Convert to print paths with support type
    for line in clipped_lines {
        if len(line.points) >= 2 {
            path := print_path_create(.SUPPORT, layer_index)
            
            // Calculate extrusion rate for support
            extrusion_rate := calculate_extrusion_rate(
                settings.support_line_width,
                print_settings.layer_height,
                0.4, // TODO: Get nozzle diameter from settings
            )
            
            // Add moves for line segments
            for i in 0..<len(line.points)-1 {
                start := line.points[i]
                end := line.points[i + 1]
                
                move := print_move_create(.EXTRUDE, start, end, print_settings.infill.speed,
                                        f32(extrusion_rate), z_height)
                print_path_add_move(&path, move)
            }
            
            append(&paths, path)
        }
    }
    
    return paths
}

// =============================================================================
// Support Interface Generation
// =============================================================================

// Generate support interface layers for better surface quality
generate_support_interface :: proc(support_regions: []SupportRegion, settings: SupportSettings) -> [dynamic]PrintPath {
    interface_paths := make([dynamic]PrintPath)
    
    if !settings.support_interface do return interface_paths
    
    fmt.println("Generating support interface layers...")
    
    for &region in support_regions {
        // Generate interface only for layers near model contact
        if len(region.contact_areas) > 0 {
            for &contact_area in region.contact_areas {
                interface_path_set := generate_interface_for_area(&contact_area, region.layer_index,
                                                                region.z_height, settings)
                
                for path in interface_path_set {
                    append(&interface_paths, path)
                }
                
                delete(interface_path_set)
            }
        }
    }
    
    fmt.printf("Generated support interface: %d paths\n", len(interface_paths))
    return interface_paths
}

// Generate dense interface pattern for single contact area
generate_interface_for_area :: proc(area: ^Polygon, layer_index: u32, z_height: f32,
                                  settings: SupportSettings) -> [dynamic]PrintPath {
    paths := make([dynamic]PrintPath)
    
    if len(area.points) < 3 do return paths
    
    // Create dense rectilinear pattern for interface
    interface_settings := InfillSettings{
        density = settings.interface_density,
        pattern = .RECTILINEAR,
        line_width = settings.support_line_width * 0.8, // Slightly thinner for interface
        speed = 30.0, // Slower for interface quality
        angle = 0.0,  // Always same angle for interface
        spacing = settings.support_line_width * 0.8 / settings.interface_density,
    }
    
    // Convert polygon to infill region
    infill_regions := make([dynamic]Polygon)
    defer {
        for &poly in infill_regions {
            polygon_destroy(&poly)
        }
        delete(infill_regions)
    }
    
    poly_copy := polygon_create()
    for point in area.points {
        polygon_add_point(&poly_copy, point)
    }
    append(&infill_regions, poly_copy)
    
    // Generate dense interface pattern
    pattern_lines := generate_rectilinear_pattern(infill_regions, interface_settings, layer_index)
    defer {
        for &line in pattern_lines {
            delete(line.points)
        }
        delete(pattern_lines)
    }
    
    // Clip lines against interface area
    clipped_lines := clip_infill_lines(pattern_lines, infill_regions)
    defer {
        for &line in clipped_lines {
            delete(line.points)
        }
        delete(clipped_lines)
    }
    
    // Convert to print paths with interface type
    for line in clipped_lines {
        if len(line.points) >= 2 {
            path := print_path_create(.SUPPORT_INTERFACE, layer_index)
            
            // Calculate extrusion rate for interface
            extrusion_rate := calculate_extrusion_rate(
                interface_settings.line_width,
                0.2, // TODO: Get layer height from settings
                0.4, // TODO: Get nozzle diameter from settings
            )
            
            // Add moves for line segments
            for i in 0..<len(line.points)-1 {
                start := line.points[i]
                end := line.points[i + 1]
                
                move := print_move_create(.EXTRUDE, start, end, interface_settings.speed,
                                        f32(extrusion_rate), z_height)
                print_path_add_move(&path, move)
            }
            
            append(&paths, path)
        }
    }
    
    return paths
}

// =============================================================================
// Support Structure Analysis
// =============================================================================

// Analyze support requirements and provide statistics
analyze_support_requirements :: proc(support_regions: []SupportRegion) -> SupportAnalysis {
    analysis := SupportAnalysis{}
    
    for region in support_regions {
        analysis.total_layers += 1
        analysis.support_layers += len(region.regions) > 0 ? 1 : 0
        
        for &poly in region.regions {
            area := polygon_area(&poly)
            analysis.total_support_area += abs(area)
            analysis.support_region_count += 1
        }
    }
    
    if analysis.total_layers > 0 {
        analysis.support_percentage = f64(analysis.support_layers) / f64(analysis.total_layers) * 100.0
    }
    
    return analysis
}

// Support analysis results
SupportAnalysis :: struct {
    total_layers:          u32,
    support_layers:        u32,
    support_region_count:  u32,
    total_support_area:    f64,    // mm²
    support_percentage:    f64,    // Percentage of layers needing support
}

// Print support analysis summary
print_support_analysis :: proc(analysis: SupportAnalysis) {
    fmt.printf("Support Analysis:\n")
    fmt.printf("  Total layers: %d\n", analysis.total_layers)
    fmt.printf("  Layers needing support: %d (%.1f%%)\n", 
               analysis.support_layers, analysis.support_percentage)
    fmt.printf("  Support regions: %d\n", analysis.support_region_count)
    fmt.printf("  Total support area: %.2f mm²\n", analysis.total_support_area)
}

// Clean up tree support structure
tree_support_destroy :: proc(tree: ^TreeSupport) {
    for &node in tree.nodes {
        delete(node.children)
    }
    delete(tree.nodes)
    delete(tree.root_nodes)
    delete(tree.tip_nodes)
}