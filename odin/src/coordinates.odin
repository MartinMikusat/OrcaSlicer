package main

import "core:math"

// Fixed-point coordinate system matching OrcaSlicer's approach
// Uses 64-bit integers with scaling factor for exact arithmetic

coord_t :: i64

// Scaling factor: 1 millimeter = 1e6 coordinate units
// This provides sub-micron precision (1e-6 mm = 1 nanometer)
SCALING_FACTOR :: 1e6

// Convert millimeters to coordinate units
mm_to_coord :: proc(mm: f64) -> coord_t {
    return coord_t(mm * SCALING_FACTOR)
}

// Convert coordinate units to millimeters  
coord_to_mm :: proc(coord: coord_t) -> f64 {
    return f64(coord) / SCALING_FACTOR
}

// Convert microns to coordinate units (commonly used in 3D printing)
micron_to_coord :: proc(micron: f64) -> coord_t {
    return coord_t(micron * (SCALING_FACTOR / 1000.0))
}

// Convert coordinate units to microns
coord_to_micron :: proc(coord: coord_t) -> f64 {
    return f64(coord) * (1000.0 / SCALING_FACTOR)
}

// Coordinate arithmetic helpers
coord_abs :: proc(coord: coord_t) -> coord_t {
    return coord >= 0 ? coord : -coord
}

coord_min :: proc(a, b: coord_t) -> coord_t {
    return a < b ? a : b
}

coord_max :: proc(a, b: coord_t) -> coord_t {
    return a > b ? a : b
}

// Square root for coordinate values (returns coordinate units)
coord_sqrt :: proc(coord: coord_t) -> coord_t {
    if coord <= 0 do return 0
    
    // coord represents distance^2 in (coordinate units)^2
    // We want sqrt(distance^2) in coordinate units
    // Since coordinate units = mm * SCALING_FACTOR
    // distance^2 in coord^2 = (mm * scale)^2 = mm^2 * scale^2
    // sqrt(distance^2) = mm * scale (what we want)
    // So sqrt(coord) directly gives us the right units
    return coord_t(math.sqrt_f64(f64(coord)))
}

// Distance squared in coordinate space (avoids square root for comparisons)
coord_distance_squared :: proc(dx, dy: coord_t) -> coord_t {
    // Need to be careful with overflow in multiplication
    // For typical 3D printing coordinates this should be safe
    return dx * dx + dy * dy
}

// 3D distance squared
coord_distance_squared_3d :: proc(dx, dy, dz: coord_t) -> coord_t {
    return dx * dx + dy * dy + dz * dz
}