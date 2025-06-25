package main

import "core:fmt"
import "core:slice"
import "core:math"

// =============================================================================
// Print Path Generation - Phase 2 of OrcaSlicer Odin Rewrite
//
// This module converts sliced 2D polygons into printable paths for 3D printing.
// It builds on the robust boolean operations foundation from Phase 1.
//
// Key components:
// - Perimeter generation using polygon offsetting
// - Infill pattern generation (rectilinear, honeycomb)
// - Print path optimization and ordering
// - G-code compatible path representation
// =============================================================================

// =============================================================================
// Print Path Data Structures
// =============================================================================

// Type of print path for different printing strategies
PrintPathType :: enum {
    PERIMETER_OUTER,     // Outer wall (visible surface)
    PERIMETER_INNER,     // Inner walls (structural)
    INFILL,              // Interior fill pattern
    SUPPORT,             // Support material paths
    SUPPORT_INTERFACE,   // Support interface layers
    SKIRT,               // Skirt around model base
    BRIM,                // Brim attached to model base
}

// Print movement type for G-code generation
PrintMoveType :: enum {
    TRAVEL,      // Non-printing move (G0)
    EXTRUDE,     // Printing move with extrusion (G1)
    RETRACT,     // Filament retraction
    UNRETRACT,   // Filament advance
}

// Individual print move with all required parameters
PrintMove :: struct {
    type:           PrintMoveType,
    start:          Point2D,       // Start point in coordinate units
    end:            Point2D,       // End point in coordinate units
    speed:          f32,           // Movement speed in mm/s
    extrusion_rate: f32,           // Extrusion amount (mm³/mm or relative)
    z_height:       f32,           // Layer height in mm
}

// A continuous sequence of print moves (like a perimeter loop)
PrintPath :: struct {
    moves:       [dynamic]PrintMove,
    type:        PrintPathType,
    layer_index: u32,
    is_closed:   bool,             // True for closed loops (perimeters)
    total_length: f64,             // Total path length in mm
}

// Complete layer with all print paths
PrintLayer :: struct {
    paths:        [dynamic]PrintPath,
    layer_index:  u32,
    z_height:     f32,              // Layer Z coordinate in mm
    layer_time:   f64,              // Estimated print time in seconds
}

// Complete print job with all layers
PrintJob :: struct {
    layers:           [dynamic]PrintLayer,
    total_print_time: f64,          // Total estimated time in seconds
    total_filament:   f64,          // Total filament usage in mm
    bounding_box:     BoundingBox2D,
}

// =============================================================================
// Print Settings Configuration
// =============================================================================

// Perimeter generation settings
PerimeterSettings :: struct {
    wall_count:              u32,   // Number of perimeter walls
    wall_thickness:          f64,   // Wall thickness in mm (nozzle diameter)
    outer_wall_speed:        f32,   // Outer wall print speed mm/s
    inner_wall_speed:        f32,   // Inner wall print speed mm/s
    wall_line_width:         f64,   // Line width for walls (usually = nozzle)
    outer_wall_inset:        f64,   // Inset for outer wall (usually wall_thickness/2)
}

// Infill generation settings  
InfillSettings :: struct {
    density:           f64,         // Fill density 0.0-1.0 (0% to 100%)
    pattern:           InfillPattern,
    line_width:        f64,         // Infill line width in mm
    speed:             f32,         // Infill print speed mm/s
    angle:             f64,         // Infill angle in degrees
    spacing:           f64,         // Line spacing in mm
}

// Supported infill patterns
InfillPattern :: enum {
    RECTILINEAR,     // Simple parallel lines
    HONEYCOMB,       // Hexagonal honeycomb pattern
    GRID,            // Perpendicular grid pattern
    TRIANGULAR,      // Triangular pattern
    CONCENTRIC,      // Concentric shells pattern
}

// Print speed and movement settings
PrintSettings :: struct {
    layer_height:        f64,       // Layer height in mm
    first_layer_height:  f64,       // First layer height in mm
    nozzle_diameter:     f64,       // Nozzle diameter in mm
    extrusion_width:     f64,       // Default extrusion width in mm
    travel_speed:        f32,       // Travel move speed mm/s
    retraction_distance: f64,       // Retraction distance in mm
    retraction_speed:    f32,       // Retraction speed mm/s
    perimeter:           PerimeterSettings,
    infill:              InfillSettings,
}

// Default print settings for testing
print_settings_default :: proc() -> PrintSettings {
    return {
        layer_height = 0.2,
        first_layer_height = 0.2,
        nozzle_diameter = 0.4,
        extrusion_width = 0.4,
        travel_speed = 150.0,
        retraction_distance = 1.5,
        retraction_speed = 25.0,
        perimeter = {
            wall_count = 2,
            wall_thickness = 0.4,
            outer_wall_speed = 50.0,
            inner_wall_speed = 60.0,
            wall_line_width = 0.4,
            outer_wall_inset = 0.2,
        },
        infill = {
            density = 0.2,
            pattern = .RECTILINEAR,
            line_width = 0.4,
            speed = 80.0,
            angle = 45.0,
            spacing = 2.0, // Will be calculated based on density
        },
    }
}

// =============================================================================
// Print Path Creation and Management
// =============================================================================

// Create empty print path
print_path_create :: proc(type: PrintPathType, layer_index: u32) -> PrintPath {
    return {
        moves = make([dynamic]PrintMove),
        type = type,
        layer_index = layer_index,
        is_closed = false,
        total_length = 0.0,
    }
}

// Destroy print path and free memory
print_path_destroy :: proc(path: ^PrintPath) {
    delete(path.moves)
}

// Add move to print path
print_path_add_move :: proc(path: ^PrintPath, move: PrintMove) {
    append(&path.moves, move)
    
    // Update total length for extrusion moves
    if move.type == .EXTRUDE {
        length := coord_to_mm(point_distance(move.start, move.end))
        path.total_length += length
    }
}

// Create print move
print_move_create :: proc(type: PrintMoveType, start, end: Point2D, speed: f32, 
                         extrusion_rate: f32 = 0.0, z_height: f32 = 0.0) -> PrintMove {
    return {
        type = type,
        start = start,
        end = end,
        speed = speed,
        extrusion_rate = extrusion_rate,
        z_height = z_height,
    }
}

// =============================================================================
// Print Layer Management
// =============================================================================

// Create empty print layer
print_layer_create :: proc(layer_index: u32, z_height: f32) -> PrintLayer {
    return {
        paths = make([dynamic]PrintPath),
        layer_index = layer_index,
        z_height = z_height,
        layer_time = 0.0,
    }
}

// Destroy print layer and free memory
print_layer_destroy :: proc(layer: ^PrintLayer) {
    for &path in layer.paths {
        print_path_destroy(&path)
    }
    delete(layer.paths)
}

// Add path to print layer
print_layer_add_path :: proc(layer: ^PrintLayer, path: PrintPath) {
    append(&layer.paths, path)
    
    // Update layer statistics
    layer.layer_time += calculate_path_time(path)
}

// Calculate estimated print time for a path
calculate_path_time :: proc(path: PrintPath) -> f64 {
    total_time: f64 = 0.0
    
    for move in path.moves {
        if move.type == .TRAVEL || move.type == .EXTRUDE {
            distance := coord_to_mm(point_distance(move.start, move.end))
            time := distance / f64(move.speed)
            total_time += time
        }
    }
    
    return total_time
}

// =============================================================================
// Print Job Management 
// =============================================================================

// Create empty print job
print_job_create :: proc() -> PrintJob {
    return {
        layers = make([dynamic]PrintLayer),
        total_print_time = 0.0,
        total_filament = 0.0,
        bounding_box = bbox2d_empty(),
    }
}

// Destroy print job and free memory
print_job_destroy :: proc(job: ^PrintJob) {
    for &layer in job.layers {
        print_layer_destroy(&layer)
    }
    delete(job.layers)
}

// Add layer to print job
print_job_add_layer :: proc(job: ^PrintJob, layer: PrintLayer) {
    append(&job.layers, layer)
    
    // Update job statistics
    job.total_print_time += layer.layer_time
    
    // Update bounding box from layer paths
    for path in layer.paths {
        for move in path.moves {
            bbox2d_include(&job.bounding_box, move.start)
            bbox2d_include(&job.bounding_box, move.end)
        }
    }
}

// Calculate total filament usage for print job
print_job_calculate_filament :: proc(job: ^PrintJob, filament_diameter: f64) -> f64 {
    total_volume: f64 = 0.0
    filament_area := math.PI * (filament_diameter/2.0) * (filament_diameter/2.0)
    
    for layer in job.layers {
        for path in layer.paths {
            for move in path.moves {
                if move.type == .EXTRUDE {
                    length := coord_to_mm(point_distance(move.start, move.end))
                    volume := length * f64(move.extrusion_rate)
                    total_volume += volume
                }
            }
        }
    }
    
    // Convert volume to linear filament length
    return total_volume / filament_area
}

// =============================================================================
// Helper Functions
// =============================================================================

// Convert polygon to closed print path
polygon_to_print_path :: proc(poly: ^Polygon, type: PrintPathType, layer_index: u32, 
                             speed: f32, extrusion_rate: f32, z_height: f32) -> PrintPath {
    path := print_path_create(type, layer_index)
    path.is_closed = true
    
    if len(poly.points) < 2 do return path
    
    // Add moves for each edge
    for i in 0..<len(poly.points) {
        start := poly.points[i]
        end := poly.points[(i + 1) % len(poly.points)]
        
        move := print_move_create(.EXTRUDE, start, end, speed, extrusion_rate, z_height)
        print_path_add_move(&path, move)
    }
    
    return path
}

// Print path statistics summary  
print_path_summary :: proc(path: PrintPath) -> string {
    return fmt.aprintf(
        "Path %v: %d moves, %.2fmm, %.1fs",
        path.type,
        len(path.moves),
        path.total_length,
        calculate_path_time(path)
    )
}