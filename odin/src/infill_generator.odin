package main

import "core:fmt"
import "core:slice"
import "core:math"

// =============================================================================
// Infill Pattern Generation - Interior Fill for 3D Printing
//
// This module generates infill patterns to fill the interior space of printed
// objects. It implements essential patterns (rectilinear, honeycomb) using
// data-oriented algorithms for optimal performance.
//
// Architecture: Works with polygon intersection from boolean_ops.odin
// =============================================================================

// =============================================================================
// Infill Generation Core Functions
// =============================================================================

// Generate infill paths for a single layer
generate_layer_infill :: proc(layer_polygons: []ExPolygon, settings: PrintSettings,
                             layer_index: u32, z_height: f32) -> [dynamic]PrintPath {
    paths := make([dynamic]PrintPath)
    
    if settings.infill.density <= 0.0 do return paths
    
    for &expoly in layer_polygons {
        // Calculate infill region (interior after perimeter offset)
        infill_region := calculate_infill_region(&expoly, settings)
        defer {
            for &poly in infill_region {
                polygon_destroy(&poly)
            }
            delete(infill_region)
        }
        
        if len(infill_region) == 0 do continue
        
        // Generate pattern lines based on infill type
        pattern_lines := generate_infill_pattern_lines(infill_region, settings, layer_index)
        defer {
            for &line in pattern_lines {
                delete(line.points)
            }
            delete(pattern_lines)
        }
        
        // Clip pattern lines against infill region
        clipped_lines := clip_infill_lines(pattern_lines, infill_region)
        defer {
            for &line in clipped_lines {
                delete(line.points)
            }
            delete(clipped_lines)
        }
        
        // Convert clipped lines to print paths
        for line in clipped_lines {
            if len(line.points) >= 2 {
                path := create_infill_print_path(line, settings, layer_index, z_height)
                append(&paths, path)
            }
        }
    }
    
    return paths
}

// Calculate the infill region by offsetting perimeter walls inward
calculate_infill_region :: proc(expoly: ^ExPolygon, settings: PrintSettings) -> [dynamic]Polygon {
    result := make([dynamic]Polygon)
    
    // Calculate total perimeter offset
    wall_count := f64(settings.perimeter.wall_count)
    wall_thickness := settings.perimeter.wall_thickness
    total_offset := -(wall_count * wall_thickness) // Negative for inward offset
    
    // Offset main contour inward
    contour_polys := []Polygon{expoly.contour}
    config := boolean_config_default()
    
    offset_contours := polygon_offset(contour_polys, total_offset, config)
    defer {
        for &poly in offset_contours {
            polygon_destroy(&poly)
        }
        delete(offset_contours)
    }
    
    // For each offset contour, subtract holes
    for &contour in offset_contours {
        if len(contour.points) < 3 do continue
        
        // Start with full contour
        current_regions := make([dynamic]Polygon)
        defer {
            for &poly in current_regions {
                polygon_destroy(&poly)
            }
            delete(current_regions)
        }
        
        // Copy contour
        contour_copy := polygon_create()
        for point in contour.points {
            polygon_add_point(&contour_copy, point)
        }
        append(&current_regions, contour_copy)
        
        // Subtract each hole
        for &hole in expoly.holes {
            if len(hole.points) < 3 do continue
            
            // Offset hole outward to account for perimeters
            hole_polys := []Polygon{hole}
            offset_holes := polygon_offset(hole_polys, -total_offset, config) // Positive for outward
            defer {
                for &poly in offset_holes {
                    polygon_destroy(&poly)
                }
                delete(offset_holes)
            }
            
            // Subtract offset holes from current regions
            for &offset_hole in offset_holes {
                if len(offset_hole.points) < 3 do continue
                
                // Convert to arrays for difference operation
                subject_polys := make([]Polygon, len(current_regions))
                defer delete(subject_polys)
                for i in 0..<len(current_regions) {
                    subject_polys[i] = current_regions[i]
                }
                
                clip_polys := []Polygon{offset_hole}
                
                difference_result := polygon_difference(subject_polys, clip_polys, config)
                
                // Clean up current regions and replace with difference result
                for &poly in current_regions {
                    polygon_destroy(&poly)
                }
                clear(&current_regions)
                
                for poly in difference_result {
                    append(&current_regions, poly)
                }
                delete(difference_result)
            }
        }
        
        // Move surviving regions to result
        for region in current_regions {
            append(&result, region)
        }
        clear(&current_regions)
    }
    
    return result
}

// =============================================================================
// Rectilinear Infill Pattern Generation
// =============================================================================

// Generate rectilinear (parallel lines) infill pattern
generate_rectilinear_pattern :: proc(infill_regions: [dynamic]Polygon, settings: InfillSettings,
                                    layer_index: u32) -> [dynamic]Polyline {
    lines := make([dynamic]Polyline)
    
    if len(infill_regions) == 0 do return lines
    
    // Calculate pattern parameters
    spacing := calculate_line_spacing(settings.density, settings.line_width)
    angle := settings.angle + f64(layer_index % 2) * 90.0 // Alternate direction each layer
    
    // Calculate bounding box of all infill regions
    bbox := bbox2d_empty()
    for &region in infill_regions {
        region_bbox := polygon_bounding_box(&region)
        if bbox.min.x == max(coord_t) { // First valid bbox
            bbox = region_bbox
        } else {
            if region_bbox.min.x < bbox.min.x do bbox.min.x = region_bbox.min.x
            if region_bbox.min.y < bbox.min.y do bbox.min.y = region_bbox.min.y
            if region_bbox.max.x > bbox.max.x do bbox.max.x = region_bbox.max.x
            if region_bbox.max.y > bbox.max.y do bbox.max.y = region_bbox.max.y
        }
    }
    
    if bbox.min.x == max(coord_t) do return lines // No valid regions
    
    // Generate parallel lines across bounding box
    pattern_lines := generate_parallel_lines(bbox, spacing, angle)
    defer {
        for &line in pattern_lines {
            delete(line.points)
        }
        delete(pattern_lines)
    }
    
    return pattern_lines
}

// Generate parallel lines across a bounding box
generate_parallel_lines :: proc(bbox: BoundingBox2D, spacing: f64, angle_degrees: f64) -> [dynamic]Polyline {
    lines := make([dynamic]Polyline)
    
    angle_rad := angle_degrees * math.PI / 180.0
    cos_angle := math.cos_f64(angle_rad)
    sin_angle := math.sin_f64(angle_rad)
    
    // Calculate bbox dimensions in mm
    bbox_width := coord_to_mm(bbox.max.x - bbox.min.x)
    bbox_height := coord_to_mm(bbox.max.y - bbox.min.y)
    
    // Calculate diagonal length for line extension
    diagonal := math.sqrt_f64(bbox_width * bbox_width + bbox_height * bbox_height)
    
    // Calculate spacing in coordinate units
    spacing_coord := mm_to_coord(spacing)
    
    // Generate lines perpendicular to angle direction
    // Transform to rotated coordinate system where lines are horizontal
    
    // Center point of bounding box
    center_x := coord_to_mm(bbox.min.x + (bbox.max.x - bbox.min.x) / 2)
    center_y := coord_to_mm(bbox.min.y + (bbox.max.y - bbox.min.y) / 2)
    
    // Number of lines needed
    line_count := int(diagonal / spacing) + 2
    start_offset := -f64(line_count / 2) * spacing
    
    for i in 0..<line_count {
        offset := start_offset + f64(i) * spacing
        
        // Line in rotated coordinate system (perpendicular to angle)
        // Rotate back to world coordinates
        line_start_x := center_x + offset * (-sin_angle) - diagonal * cos_angle
        line_start_y := center_y + offset * cos_angle - diagonal * sin_angle
        line_end_x := center_x + offset * (-sin_angle) + diagonal * cos_angle
        line_end_y := center_y + offset * cos_angle + diagonal * sin_angle
        
        // Convert to coordinate units
        start := point2d_from_mm(line_start_x, line_start_y)
        end := point2d_from_mm(line_end_x, line_end_y)
        
        // Create polyline
        line := Polyline{points = make([dynamic]Point2D)}
        append(&line.points, start)
        append(&line.points, end)
        
        append(&lines, line)
    }
    
    return lines
}

// =============================================================================
// Honeycomb Infill Pattern Generation  
// =============================================================================

// Generate honeycomb (hexagonal) infill pattern
generate_honeycomb_pattern :: proc(infill_regions: [dynamic]Polygon, settings: InfillSettings,
                                  layer_index: u32) -> [dynamic]Polyline {
    lines := make([dynamic]Polyline)
    
    if len(infill_regions) == 0 do return lines
    
    // Calculate pattern parameters
    spacing := calculate_line_spacing(settings.density, settings.line_width)
    
    // Calculate bounding box
    bbox := bbox2d_empty()
    for &region in infill_regions {
        region_bbox := polygon_bounding_box(&region)
        if bbox.min.x == max(coord_t) {
            bbox = region_bbox
        } else {
            if region_bbox.min.x < bbox.min.x do bbox.min.x = region_bbox.min.x
            if region_bbox.min.y < bbox.min.y do bbox.min.y = region_bbox.min.y
            if region_bbox.max.x > bbox.max.x do bbox.max.x = region_bbox.max.x
            if region_bbox.max.y > bbox.max.y do bbox.max.y = region_bbox.max.y
        }
    }
    
    if bbox.min.x == max(coord_t) do return lines
    
    // Generate hexagonal pattern lines
    honeycomb_lines := generate_hexagonal_lines(bbox, spacing)
    return honeycomb_lines
}

// Generate hexagonal pattern lines (three sets of parallel lines at 60° angles)
generate_hexagonal_lines :: proc(bbox: BoundingBox2D, spacing: f64) -> [dynamic]Polyline {
    lines := make([dynamic]Polyline)
    
    // Hexagonal pattern consists of three sets of parallel lines:
    // 0°, 60°, and 120° (or equivalently 0°, 60°, -60°)
    angles := [3]f64{0.0, 60.0, 120.0}
    
    for angle in angles {
        angle_lines := generate_parallel_lines(bbox, spacing, angle)
        
        for line in angle_lines {
            append(&lines, line)
        }
        
        delete(angle_lines)
    }
    
    return lines
}

// =============================================================================
// Infill Pattern Dispatch and Utilities
// =============================================================================

// Generate infill pattern lines based on pattern type
generate_infill_pattern_lines :: proc(infill_regions: [dynamic]Polygon, settings: PrintSettings,
                                     layer_index: u32) -> [dynamic]Polyline {
    
    #partial switch settings.infill.pattern {
    case .RECTILINEAR:
        return generate_rectilinear_pattern(infill_regions, settings.infill, layer_index)
    case .HONEYCOMB:
        return generate_honeycomb_pattern(infill_regions, settings.infill, layer_index)
    case .GRID:
        // Grid is rectilinear at 0° and 90° overlaid
        lines_0 := generate_parallel_lines(get_combined_bbox(infill_regions), 
                                         calculate_line_spacing(settings.infill.density, settings.infill.line_width), 0.0)
        lines_90 := generate_parallel_lines(get_combined_bbox(infill_regions),
                                          calculate_line_spacing(settings.infill.density, settings.infill.line_width), 90.0)
        
        // Combine both sets
        for line in lines_90 {
            append(&lines_0, line)
        }
        delete(lines_90)
        return lines_0
    case:
        // Default to rectilinear for unsupported patterns
        return generate_rectilinear_pattern(infill_regions, settings.infill, layer_index)
    }
}

// Calculate line spacing based on density and line width
calculate_line_spacing :: proc(density: f64, line_width: f64) -> f64 {
    if density <= 0.0 do return 1000.0 // Very sparse
    if density >= 1.0 do return line_width // Solid infill
    
    // For typical infill, spacing = line_width / density
    // This gives reasonable coverage based on density percentage
    return line_width / density
}

// Get combined bounding box for multiple polygons
get_combined_bbox :: proc(polygons: [dynamic]Polygon) -> BoundingBox2D {
    bbox := bbox2d_empty()
    
    for &poly in polygons {
        poly_bbox := polygon_bounding_box(&poly)
        if bbox.min.x == max(coord_t) {
            bbox = poly_bbox
        } else {
            if poly_bbox.min.x < bbox.min.x do bbox.min.x = poly_bbox.min.x
            if poly_bbox.min.y < bbox.min.y do bbox.min.y = poly_bbox.min.y
            if poly_bbox.max.x > bbox.max.x do bbox.max.x = poly_bbox.max.x
            if poly_bbox.max.y > bbox.max.y do bbox.max.y = poly_bbox.max.y
        }
    }
    
    return bbox
}

// =============================================================================
// Line Clipping and Print Path Creation
// =============================================================================

// Clip infill lines against infill regions to create valid print paths
clip_infill_lines :: proc(pattern_lines: [dynamic]Polyline, infill_regions: [dynamic]Polygon) -> [dynamic]Polyline {
    clipped_lines := make([dynamic]Polyline)
    
    for &line in pattern_lines {
        if len(line.points) < 2 do continue
        
        // Clip this line against all infill regions
        for &region in infill_regions {
            // Simple line-polygon intersection for each line segment
            for i in 0..<len(line.points)-1 {
                start := line.points[i]
                end := line.points[i + 1]
                
                // Find intersection points with polygon boundary
                intersections := find_line_polygon_intersections(start, end, &region)
                defer delete(intersections)
                
                // Create line segments inside the polygon
                segments := create_inside_segments(start, end, intersections, &region)
                defer {
                    for &segment in segments {
                        delete(segment.points)
                    }
                    delete(segments)
                }
                
                // Add valid segments to clipped lines
                for segment in segments {
                    if len(segment.points) >= 2 {
                        segment_copy := Polyline{points = make([dynamic]Point2D)}
                        for point in segment.points {
                            append(&segment_copy.points, point)
                        }
                        append(&clipped_lines, segment_copy)
                    }
                }
            }
        }
    }
    
    return clipped_lines
}

// Find intersections between a line segment and polygon boundary
find_line_polygon_intersections :: proc(line_start, line_end: Point2D, poly: ^Polygon) -> [dynamic]Point2D {
    intersections := make([dynamic]Point2D)
    
    for i in 0..<len(poly.points) {
        edge_start := poly.points[i]
        edge_end := poly.points[(i + 1) % len(poly.points)]
        
        result := line_segment_intersection(line_start, line_end, edge_start, edge_end)
        if result.type == .POINT {
            append(&intersections, result.point)
        }
    }
    
    return intersections
}

// Create line segments that are inside the polygon
create_inside_segments :: proc(line_start, line_end: Point2D, intersections: [dynamic]Point2D, 
                               poly: ^Polygon) -> [dynamic]Polyline {
    segments := make([dynamic]Polyline)
    
    // Collect all points along the line (start, intersections, end)
    all_points := make([dynamic]Point2D)
    defer delete(all_points)
    
    append(&all_points, line_start)
    for point in intersections {
        append(&all_points, point)
    }
    append(&all_points, line_end)
    
    // Sort points along the line direction
    sort_points_along_line(&all_points, line_start, line_end)
    
    // Create segments between consecutive points that are inside the polygon
    for i in 0..<len(all_points)-1 {
        start_point := all_points[i]
        end_point := all_points[i + 1]
        
        // Check if midpoint is inside polygon
        midpoint := Point2D{
            (start_point.x + end_point.x) / 2,
            (start_point.y + end_point.y) / 2,
        }
        
        if point_in_polygon(midpoint, poly) {
            segment := Polyline{points = make([dynamic]Point2D)}
            append(&segment.points, start_point)
            append(&segment.points, end_point)
            append(&segments, segment)
        }
    }
    
    return segments
}

// Sort points along a line from start to end
sort_points_along_line :: proc(points: ^[dynamic]Point2D, line_start, line_end: Point2D) {
    // Simple bubble sort based on distance from line start
    line_dir := point2d_sub(line_end, line_start)
    line_length_sq := f64(line_dir.x * line_dir.x + line_dir.y * line_dir.y)
    
    if line_length_sq <= 0 do return
    
    for i in 0..<len(points) {
        for j in 0..<len(points)-1-i {
            // Calculate projection of each point onto the line
            to_point1 := point2d_sub(points[j], line_start)
            to_point2 := point2d_sub(points[j+1], line_start)
            
            proj1 := f64(point2d_dot(to_point1, line_dir)) / line_length_sq
            proj2 := f64(point2d_dot(to_point2, line_dir)) / line_length_sq
            
            if proj1 > proj2 {
                // Swap
                temp := points[j]
                points[j] = points[j+1]
                points[j+1] = temp
            }
        }
    }
}

// Convert clipped infill line to print path
create_infill_print_path :: proc(line: Polyline, settings: PrintSettings, 
                                layer_index: u32, z_height: f32) -> PrintPath {
    path := print_path_create(.INFILL, layer_index)
    
    if len(line.points) < 2 do return path
    
    // Calculate extrusion rate
    extrusion_rate := calculate_extrusion_rate(
        settings.infill.line_width,
        settings.layer_height,
        settings.nozzle_diameter
    )
    
    // Add moves for each line segment
    for i in 0..<len(line.points)-1 {
        start := line.points[i]
        end := line.points[i + 1]
        
        move := print_move_create(.EXTRUDE, start, end, settings.infill.speed, 
                                 f32(extrusion_rate), z_height)
        print_path_add_move(&path, move)
    }
    
    return path
}